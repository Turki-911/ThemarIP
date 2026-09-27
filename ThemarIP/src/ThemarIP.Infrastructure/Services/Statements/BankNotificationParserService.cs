using System;
using System.IO;
using System.Linq;
using System.Text.RegularExpressions;
using System.Threading.Tasks;
using Microsoft.EntityFrameworkCore;
using ThemarIP.Application.Common.Interfaces;
using ThemarIP.Application.DTOs.Statements;
using ThemarIP.Application.Interfaces.Statements;
using ThemarIP.Domain.Entities.Pfm;
using ThemarIP.Domain.Enums.Pfm;

namespace ThemarIP.Infrastructure.Services.Statements;

public class BankNotificationParserService : IBankNotificationParserService
{
    private readonly IApplicationDbContext _context;

    public BankNotificationParserService(IApplicationDbContext context)
    {
        _context = context;
    }

    public async Task<ParsedNotificationResultDto> ParseNotificationAsync(IngestNotificationRequestDto request)
    {
        var rawText = request.RawMessage ?? string.Empty;
        if (request.IsHtml || Regex.IsMatch(rawText, @"<[^>]+>"))
        {
            rawText = StripHtml(rawText);
        }

        var fullContext = $"{request.EmailSubject} {request.EmailSender} {rawText}".Trim();
        var result = new ParsedNotificationResultDto
        {
            SourceType = request.SourceType?.ToUpperInvariant() == "EMAIL" ? "EMAIL" : "SMS"
        };

        // 1. Detect Bank
        result.BankName = DetectBank(fullContext, request.EmailSender);

        // 2. Extract Amount & Currency
        var (amount, currency) = ExtractAmountAndCurrency(fullContext);
        result.Amount = amount;
        result.Currency = currency;

        // 3. Extract Direction (Debit vs Credit)
        result.Direction = DetectDirection(fullContext);

        // 4. Extract Date & Time
        result.TransactionDate = ExtractTransactionDate(fullContext);

        // 5. Extract Balance After
        result.BalanceAfter = ExtractBalance(fullContext);

        // 6. Extract Account / Card Reference
        result.AccountReference = ExtractAccountReference(fullContext);

        // 7. Extract Narration / Merchant
        result.Narration = ExtractNarration(fullContext, result.Direction, result.BankName);

        // 8. Match Merchant & Category
        await MatchMerchantAndCategoryAsync(result);

        // 9. Validation & Deduplication
        await ValidateAndDeduplicateAsync(result, request.UserId);

        // 10. Auto-Confirm if requested and valid
        if (request.AutoConfirm && !result.IsDuplicate && result.Amount > 0)
        {
            var confirmReq = new ConfirmNotificationRequestDto
            {
                UserId = request.UserId,
                Transaction = result
            };
            result.SavedTransactionId = await ConfirmAndSaveNotificationAsync(confirmReq);
            result.ValidationMessage = "Auto-ingested and saved to themarip.db";
        }

        return result;
    }

    public async Task<Guid> ConfirmAndSaveNotificationAsync(ConfirmNotificationRequestDto request)
    {
        ThemarIP.Domain.Entities.User? user = null;
        if (request.UserId.HasValue)
        {
            user = await _context.Users.FirstOrDefaultAsync(u => u.Id == request.UserId.Value);
        }
        if (user == null)
        {
            user = await _context.Users.FirstOrDefaultAsync();
            if (user == null) throw new Exception("No users found in themarip.db to link transaction.");
        }

        var tx = request.Transaction;
        var isCredit = string.Equals(tx.Direction, "CREDIT", StringComparison.OrdinalIgnoreCase);

        var pfmTx = new PfmTransaction
        {
            Id = Guid.NewGuid(),
            UserId = user.Id,
            MerchantId = tx.MatchedMerchantId,
            TransactionDate = tx.TransactionDate,
            Narration = string.IsNullOrWhiteSpace(tx.Narration) ? $"{tx.BankName} {tx.Direction}" : tx.Narration,
            Amount = tx.Amount,
            Currency = string.IsNullOrWhiteSpace(tx.Currency) ? "OMR" : tx.Currency,
            TransactionType = isCredit ? TransactionType.Credit : TransactionType.Debit,
            BalanceAfter = tx.BalanceAfter,
            Status = tx.MatchedMerchantId.HasValue ? TransactionStatus.Categorized : TransactionStatus.Uncategorized,
            CreatedAt = DateTimeOffset.UtcNow,
            UpdatedAt = DateTimeOffset.UtcNow
        };

        _context.PfmTransactions.Add(pfmTx);
        await _context.SaveChangesAsync();

        return pfmTx.Id;
    }

    private string DetectBank(string text, string? sender)
    {
        var combined = $"{sender} {text}".ToLowerInvariant();
        if (combined.Contains("bank muscat") || combined.Contains("bankmuscat") || combined.Contains("bm ")) return "Bank Muscat";
        if (combined.Contains("national bank of oman") || combined.Contains("nbo")) return "National Bank of Oman";
        if (combined.Contains("bank dhofar") || combined.Contains("dhofar")) return "Bank Dhofar";
        if (combined.Contains("sohar international") || combined.Contains("sohar")) return "Sohar International";
        if (combined.Contains("ahli bank") || combined.Contains("ahlibank")) return "Ahli Bank";
        if (combined.Contains("meethaq")) return "Meethaq Islamic";
        if (combined.Contains("alizz")) return "Alizz Islamic Bank";
        if (combined.Contains("ompay") || combined.Contains("thawani")) return "Oman PSP / Wallet";

        return "Bank Muscat"; // Default in Oman context if currency is OMR
    }

    private (decimal Amount, string Currency) ExtractAmountAndCurrency(string text)
    {
        string currency = "OMR";
        if (Regex.IsMatch(text, @"\bUSD\b", RegexOptions.IgnoreCase)) currency = "USD";
        else if (Regex.IsMatch(text, @"\bAED\b", RegexOptions.IgnoreCase)) currency = "AED";

        // Patterns: OMR 28.655 | 28.655 OMR | RO 15.000 | 15.000 RO
        var m = Regex.Match(text, @"(?:OMR|RO|R\.O\.)\s*([0-9]+(?:\.[0-9]{1,3})?)", RegexOptions.IgnoreCase);
        if (m.Success && decimal.TryParse(m.Groups[1].Value, out var val1))
        {
            return (val1, currency);
        }

        m = Regex.Match(text, @"([0-9]+(?:\.[0-9]{1,3})?)\s*(?:OMR|RO|R\.O\.)", RegexOptions.IgnoreCase);
        if (m.Success && decimal.TryParse(m.Groups[1].Value, out var val2))
        {
            return (val2, currency);
        }

        // Generic keyword with amount: debited by 28.655 | paid 10.500 | amount: 4.200
        m = Regex.Match(text, @"(?:debited\s+by|credited\s+with|paid|spent|amount(?:\s+is)?(?:\s*:)?)\s*([0-9]+(?:\.[0-9]{1,3})?)", RegexOptions.IgnoreCase);
        if (m.Success && decimal.TryParse(m.Groups[1].Value, out var val3))
        {
            return (val3, currency);
        }

        return (0m, currency);
    }

    private string DetectDirection(string text)
    {
        var lower = text.ToLowerInvariant();
        if (lower.Contains("credited") || lower.Contains("credit alert") || lower.Contains("deposit") || 
            lower.Contains("salary") || lower.Contains("refund") || lower.Contains("received") || lower.Contains("transfer from"))
        {
            return "CREDIT";
        }
        return "DEBIT";
    }

    private DateTimeOffset ExtractTransactionDate(string text)
    {
        // 06-09-2026 or 06/09/2026
        var m = Regex.Match(text, @"\b([0-3]?[0-9])[-/]([0-1]?[0-9])[-/](20\d{2})\b");
        if (m.Success && 
            int.TryParse(m.Groups[1].Value, out var day) && 
            int.TryParse(m.Groups[2].Value, out var month) && 
            int.TryParse(m.Groups[3].Value, out var year))
        {
            try { return new DateTimeOffset(new DateTime(year, month, day), TimeSpan.Zero); } catch { }
        }

        // 06-SEP-2026 or 06-Sep-26
        m = Regex.Match(text, @"\b([0-3]?[0-9])[-/ ]([A-Za-z]{3})[-/ ](20\d{2}|\d{2})\b");
        if (m.Success && DateTime.TryParse(m.Value, out var parsedDt))
        {
            return new DateTimeOffset(parsedDt, TimeSpan.Zero);
        }

        return DateTimeOffset.UtcNow;
    }

    private decimal? ExtractBalance(string text)
    {
        // Avail Bal: OMR 40.992 | Available Balance: 120.500 | Bal: OMR 38.792
        var m = Regex.Match(text, @"(?:avail(?:able)?\s*bal(?:ance)?|avl\s*bal|bal(?:\s*after)?)\s*(?::|is)?\s*(?:OMR|RO)?\s*([0-9]+(?:\.[0-9]{1,3})?)", RegexOptions.IgnoreCase);
        if (m.Success && decimal.TryParse(m.Groups[1].Value, out var bal))
        {
            return bal;
        }

        m = Regex.Match(text, @"(?:OMR|RO)\s*([0-9]+(?:\.[0-9]{1,3})?)\s*(?:avail|bal)", RegexOptions.IgnoreCase);
        if (m.Success && decimal.TryParse(m.Groups[1].Value, out var bal2))
        {
            return bal2;
        }

        return null;
    }

    private string ExtractAccountReference(string text)
    {
        var m = Regex.Match(text, @"(?:A/C|Acct|Account|Card)\s*(?:ending\s*(?:in)?)?\s*[:.]?\s*([X*]{2,}\d{3,4}|\d{4})", RegexOptions.IgnoreCase);
        if (m.Success)
        {
            return m.Groups[1].Value;
        }
        return string.Empty;
    }

    private string ExtractNarration(string text, string direction, string bankName)
    {
        // Pattern 1: at [MERCHANT] (e.g. at LULU HYPERMARKET on ...)
        var m = Regex.Match(text, @"\bat\s+([A-Za-z0-9\s&'.-]{2,40}?)(?:\.|\s+on\b|\s+avail|\s+bal|\s+at\b|$)", RegexOptions.IgnoreCase);
        if (m.Success)
        {
            var clean = CleanNarration(m.Groups[1].Value);
            if (!string.IsNullOrWhiteSpace(clean)) return clean;
        }

        // Pattern 2: for POS purchase at [MERCHANT]
        m = Regex.Match(text, @"(?:for|via)\s+(?:POS|purchase|transfer)?\s*(?:at)?\s*([A-Za-z0-9\s&'.-]{2,40}?)(?:\.|\s+on\b|\s+avail|\s+bal|$)", RegexOptions.IgnoreCase);
        if (m.Success)
        {
            var clean = CleanNarration(m.Groups[1].Value);
            if (!string.IsNullOrWhiteSpace(clean)) return clean;
        }

        // Pattern 3: Transfer from [NAME]
        m = Regex.Match(text, @"(?:transfer\s+from|by\s+transfer\s+from)\s+([A-Za-z0-9\s&'.-]{2,40}?)(?:\.|\s+on\b|\s+avail|\s+bal|$)", RegexOptions.IgnoreCase);
        if (m.Success)
        {
            return $"Transfer {CleanNarration(m.Groups[1].Value)}";
        }

        // Pattern 4: ATM withdrawal
        if (text.IndexOf("ATM", StringComparison.OrdinalIgnoreCase) >= 0)
        {
            return $"{bankName} ATM Withdrawal";
        }

        return direction == "CREDIT" ? "Credit Transfer Received" : "Debit Card Purchase";
    }

    private string CleanNarration(string input)
    {
        if (string.IsNullOrWhiteSpace(input)) return string.Empty;
        var s = input.Trim().TrimEnd('.', ',', ';', '-');
        // Remove trailing date markers
        s = Regex.Replace(s, @"\s+on\s*$", "", RegexOptions.IgnoreCase);
        return s.Trim();
    }

    private async Task MatchMerchantAndCategoryAsync(ParsedNotificationResultDto result)
    {
        var activeMerchants = await _context.PfmMerchants
            .Include(m => m.Aliases)
            .Include(m => m.DefaultCategory)
            .Include(m => m.DefaultSubcategory)
            .Where(m => m.IsActive)
            .ToListAsync();

        var textToMatch = result.Narration;

        foreach (var m in activeMerchants)
        {
            if ((!string.IsNullOrWhiteSpace(m.Name) && textToMatch.Contains(m.Name, StringComparison.OrdinalIgnoreCase)) ||
                m.Aliases.Any(a => !string.IsNullOrWhiteSpace(a.AliasText) && textToMatch.Contains(a.AliasText, StringComparison.OrdinalIgnoreCase)))
            {
                result.MatchedMerchant = m.Name;
                result.MatchedMerchantId = m.Id;
                result.Category = m.DefaultCategory?.Name ?? "Shopping";
                result.Subcategory = m.DefaultSubcategory?.Name ?? m.Name;
                return;
            }
        }

        // Fallback: Check Active Category Rules
        var rules = await _context.CategoryRules.Where(r => r.IsActive).ToListAsync();
        foreach (var r in rules)
        {
            if (!string.IsNullOrEmpty(r.Keyword) && textToMatch.Contains(r.Keyword, StringComparison.OrdinalIgnoreCase))
            {
                result.Category = r.Category;
                result.Subcategory = r.Category;
                return;
            }
        }

        result.Category = result.Direction == "CREDIT" ? "Income" : "General";
    }

    private async Task ValidateAndDeduplicateAsync(ParsedNotificationResultDto result, Guid? userId)
    {
        if (result.Amount <= 0)
        {
            result.Confidence = 30;
            result.ValidationMessage = "Could not extract a valid transaction amount.";
            return;
        }

        // Deduplication query against PfmTransactions in themarip.db
        var query = _context.PfmTransactions.AsQueryable();
        if (userId.HasValue) query = query.Where(t => t.UserId == userId.Value);

        var startOfDay = new DateTimeOffset(result.TransactionDate.Date, TimeSpan.Zero);
        var endOfDay = startOfDay.AddDays(1);
        var existing = await query
            .Where(t => t.Amount == result.Amount && t.TransactionDate >= startOfDay && t.TransactionDate < endOfDay)
            .FirstOrDefaultAsync();

        if (existing != null)
        {
            if (result.BalanceAfter.HasValue && existing.BalanceAfter.HasValue && 
                result.BalanceAfter.Value == existing.BalanceAfter.Value)
            {
                result.IsDuplicate = true;
                result.ValidationMessage = "Exact duplicate found in database with matching amount, date, and balance.";
                return;
            }

            if (existing.Narration.Equals(result.Narration, StringComparison.OrdinalIgnoreCase))
            {
                result.IsDuplicate = true;
                result.ValidationMessage = "Duplicate transaction already logged in themarip.db.";
                return;
            }
        }

        result.IsDuplicate = false;
        result.Confidence = result.BalanceAfter.HasValue ? 98 : 90;
        result.ValidationMessage = "Extraction validated and ready to feed database.";
    }

    private string StripHtml(string html)
    {
        if (string.IsNullOrWhiteSpace(html)) return string.Empty;
        // Replace <td> and <br> with space to preserve separation
        var formatted = Regex.Replace(html, @"(?i)<(td|th|br|p|div|tr)[^>]*>", " ");
        var text = Regex.Replace(formatted, @"<[^>]+>", " ");
        text = System.Net.WebUtility.HtmlDecode(text);
        return Regex.Replace(text, @"\s+", " ").Trim();
    }
}
