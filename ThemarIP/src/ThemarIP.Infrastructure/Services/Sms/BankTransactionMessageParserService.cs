using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Security.Cryptography;
using System.Text;
using System.Text.RegularExpressions;
using System.Threading.Tasks;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using ThemarIP.Application.Common;
using ThemarIP.Application.Common.Interfaces;
using ThemarIP.Application.DTOs.Sms;
using ThemarIP.Domain.Entities.Sms;

namespace ThemarIP.Infrastructure.Services.Sms;

public class BankTransactionMessageParserService : IBankTransactionMessageParserService
{
    private static readonly TimeSpan RegexTimeout = TimeSpan.FromSeconds(1.5);

    private static readonly string[] SupportedDateFormats =
    {
        "dd/MM/yyyy HH:mm:ss",
        "dd/MM/yyyy HH:mm",
        "d/M/yyyy HH:mm:ss",
        "d/M/yyyy HH:mm",
        "dd/MM/yy HH:mm:ss",
        "dd/MM/yy HH:mm",
        "dd-MM-yyyy HH:mm:ss",
        "dd-MM-yyyy HH:mm",
        "dd/MM/yyyy",
        "dd-MM-yyyy",
        "dd-MMM-yyyy HH:mm:ss",
        "dd-MMM-yyyy HH:mm",
        "dd-MMM-yyyy",
        "yyyy-MM-dd HH:mm:ss",
        "yyyy-MM-dd"
    };

    private static readonly Dictionary<string, string> MaskedFirstNameExpansions = new(StringComparer.OrdinalIgnoreCase)
    {
        ["SULA"] = "Sulaiman",
        ["TURK"] = "Turki",
        ["IBRA"] = "Ibrahim",
        ["MOHA"] = "Mohammed",
        ["MOHD"] = "Mohammed",
        ["AHME"] = "Ahmed",
        ["AHMD"] = "Ahmed",
        ["ABDU"] = "Abdul",
        ["KHAL"] = "Khalid",
        ["SALI"] = "Salim",
        ["SALE"] = "Saleh",
        ["HAMD"] = "Hamad",
        ["HAMA"] = "Hamad",
        ["NASS"] = "Nasser",
        ["SAID"] = "Said",
        ["RASH"] = "Rashid",
        ["YOUS"] = "Yousuf",
        ["FATI"] = "Fatima",
        ["MARY"] = "Maryam",
        ["AISH"] = "Aisha",
        ["QABS"] = "Qabs",
        ["ABSA"] = "Absa"
    };

    private readonly IApplicationDbContext _db;
    private readonly ILogger<BankTransactionMessageParserService> _logger;

    public BankTransactionMessageParserService(
        IApplicationDbContext db,
        ILogger<BankTransactionMessageParserService> logger)
    {
        _db = db;
        _logger = logger;
    }

    public async Task<ParsedTransactionMessageDto> ParseMessageAsync(ParseBankMessageRequestDto request)
    {
        var raw = (request.RawMessage ?? string.Empty).Trim();
        var normalized = Regex.Replace(raw, @"\s+", " ").Trim();
        var canonicalBank = BankCatalog.Canonical(request.BankCode, request.Sender);

        var dto = new ParsedTransactionMessageDto
        {
            OriginalMessage = raw,
            BankCode = canonicalBank.Code,
            BankName = canonicalBank.Name,
            Currency = string.IsNullOrWhiteSpace(request.FallbackCurrency) ? "OMR" : request.FallbackCurrency!.ToUpperInvariant(),
            Amount = request.FallbackAmount ?? 0m,
            Direction = string.IsNullOrWhiteSpace(request.FallbackDirection) ? "DEBIT" : request.FallbackDirection!.ToUpperInvariant(),
            TransactionDate = request.FallbackDate
        };

        if (string.IsNullOrWhiteSpace(normalized))
        {
            dto.GeneratedDescription = "Unknown transaction";
            dto.ConfidenceScore = 0;
            dto.ReviewStatus = "NEEDS_REVIEW";
            dto.Warnings.Add("Empty transaction message.");
            return dto;
        }

        // Check for promotional or OTP messages
        if (IsPromoOrOtp(normalized))
        {
            dto.TransactionType = "IGNORED_PROMO_OTP";
            dto.GeneratedDescription = "Non-transaction message (OTP / Promo)";
            dto.ConfidenceScore = 0;
            dto.ReviewStatus = "NEEDS_REVIEW";
            dto.Warnings.Add("Detected promotional offer or OTP verification message.");
            return dto;
        }

        // Load candidate rules
        var rulesToEvaluate = new List<BankMessageParserRuleDto>();
        if (request.InlineRule != null && !string.IsNullOrWhiteSpace(request.InlineRule.RegexPattern))
        {
            rulesToEvaluate.Add(request.InlineRule);
        }
        else
        {
            var dbRules = await _db.BankMessageParserRules
                .Where(r => r.IsActive)
                .OrderBy(r => r.Priority)
                .ThenByDescending(r => r.BaseConfidence)
                .ToListAsync();

            if (request.RuleIdToTest.HasValue)
            {
                dbRules = dbRules.Where(r => r.Id == request.RuleIdToTest.Value).ToList();
            }
            else
            {
                // Prefer rules matching bankCode or sender first, then general active rules
                var bankSpecific = dbRules.Where(r =>
                    string.Equals(r.BankCode, canonicalBank.Code, StringComparison.OrdinalIgnoreCase) ||
                    SenderMatches(r.SenderIds, request.Sender)).ToList();
                var otherRules = dbRules.Except(bankSpecific).ToList();
                dbRules = bankSpecific.Concat(otherRules).ToList();
            }

            rulesToEvaluate = dbRules.Select(ToRuleDto).ToList();
        }

        foreach (var rule in rulesToEvaluate)
        {
            if (TryEvaluateRule(rule, normalized, request, out var matchedDto))
            {
                return matchedDto;
            }
        }

        // Heuristic fallback when no explicit database rule matched (low confidence -> flagged for manual review)
        return BuildHeuristicFallback(normalized, canonicalBank, request);
    }

    private bool TryEvaluateRule(
        BankMessageParserRuleDto rule,
        string normalizedMessage,
        ParseBankMessageRequestDto request,
        out ParsedTransactionMessageDto result)
    {
        result = new ParsedTransactionMessageDto();
        if (string.IsNullOrWhiteSpace(rule.RegexPattern)) return false;

        Regex regex;
        try
        {
            regex = new Regex(
                rule.RegexPattern,
                RegexOptions.IgnoreCase | RegexOptions.CultureInvariant | RegexOptions.Singleline,
                RegexTimeout);
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Invalid regex in BankMessageParserRule {RuleName}", rule.RuleName);
            return false;
        }

        Match match;
        try
        {
            match = regex.Match(normalizedMessage);
        }
        catch (RegexMatchTimeoutException)
        {
            return false;
        }

        if (!match.Success) return false;

        string? GroupVal(params string[] names)
        {
            foreach (var name in names)
            {
                var g = match.Groups[name];
                if (g != null && g.Success && !string.IsNullOrWhiteSpace(g.Value))
                {
                    return g.Value.Trim();
                }
            }
            return null;
        }

        var canonicalBank = BankCatalog.Canonical(rule.BankCode, rule.BankName);
        var currency = (GroupVal("currency", "currency2") ?? request.FallbackCurrency ?? "OMR").ToUpperInvariant();

        decimal amount = request.FallbackAmount ?? 0m;
        var amountStr = GroupVal("amount", "amount2");
        if (!string.IsNullOrWhiteSpace(amountStr) && TryParseDecimal(amountStr, out var parsedAmt))
        {
            amount = parsedAmt;
        }

        decimal? balanceAfter = null;
        var balanceStr = GroupVal("balance", "limit");
        if (!string.IsNullOrWhiteSpace(balanceStr) && TryParseDecimal(balanceStr, out var parsedBal))
        {
            balanceAfter = parsedBal;
        }
        else
        {
            // Secondary safe extraction of balance if present in message
            balanceAfter = ExtractSafeBalance(normalizedMessage);
        }

        var rawCounterparty = GroupVal("counterparty", "merchant", "recipient", "sender");
        var cleanedCounterparty = rule.CleanCounterparty
            ? CleanCounterpartyName(rawCounterparty, rule.TransactionType)
            : rawCounterparty?.Trim();

        var accountMasked = GroupVal("account", "card") ?? ExtractMaskedAccountOrCard(normalizedMessage);
        var reference = GroupVal("reference", "txnId", "ref") ?? ExtractTransactionReference(normalizedMessage);

        var dateRaw = GroupVal("date", "datetime");
        var parsedDate = ParseTransactionDate(dateRaw) ?? ExtractTransactionDateFromText(normalizedMessage) ?? request.FallbackDate;

        var direction = !string.IsNullOrWhiteSpace(rule.Direction)
            ? rule.Direction.ToUpperInvariant()
            : (request.FallbackDirection?.ToUpperInvariant() ?? "DEBIT");

        var generatedDesc = FormatDescription(
            rule.DescriptionTemplate,
            rule.FallbackDescription,
            rule.TransactionType,
            cleanedCounterparty,
            accountMasked,
            amount,
            currency,
            canonicalBank.Name,
            reference);

        // Calculate confidence score (0-100)
        int confidence = rule.BaseConfidence;
        var warnings = new List<string>();

        if (amount <= 0m)
        {
            confidence -= 25;
            warnings.Add("Transaction amount was not found in message text (used fallback or 0).");
        }
        if (string.IsNullOrWhiteSpace(cleanedCounterparty) &&
            rule.DescriptionTemplate.Contains("{Counterparty}", StringComparison.OrdinalIgnoreCase))
        {
            confidence -= 15;
            warnings.Add("Counterparty / merchant name was empty or masked; used fallback description.");
        }
        if (!string.IsNullOrWhiteSpace(reference))
        {
            confidence = Math.Min(100, confidence + 3);
        }
        if (!string.IsNullOrWhiteSpace(accountMasked))
        {
            confidence = Math.Min(100, confidence + 2);
        }

        confidence = Math.Clamp(confidence, 10, 100);
        var reviewStatus = confidence >= 75 ? "AUTO_APPROVED" : "NEEDS_REVIEW";

        result = new ParsedTransactionMessageDto
        {
            OriginalMessage = request.RawMessage.Trim(),
            GeneratedDescription = generatedDesc,
            BankCode = canonicalBank.Code,
            BankName = canonicalBank.Name,
            TransactionType = rule.TransactionType,
            Direction = direction,
            Amount = amount,
            Currency = currency,
            CounterpartyName = string.IsNullOrWhiteSpace(cleanedCounterparty) ? null : cleanedCounterparty,
            RawCounterparty = rawCounterparty,
            TransactionDate = parsedDate,
            AccountNumberMasked = accountMasked,
            TransactionReference = reference,
            BalanceAfter = balanceAfter,
            ConfidenceScore = confidence,
            ReviewStatus = reviewStatus,
            MatchedRuleId = rule.Id,
            MatchedRuleName = rule.RuleName,
            Warnings = warnings
        };

        result.DeduplicationKey = BuildDeduplicationKey(null, result);
        return true;
    }

    private ParsedTransactionMessageDto BuildHeuristicFallback(
        string normalizedMessage,
        (string Code, string Name) canonicalBank,
        ParseBankMessageRequestDto request)
    {
        // Strip balance/limit/fee phrases BEFORE looking for any amount so we never confuse balance/fee/ref with amount!
        var sanitizedForAmount = StripBalanceAndFeeClauses(normalizedMessage);

        decimal amount = request.FallbackAmount ?? 0m;
        string currency = request.FallbackCurrency ?? "OMR";

        var amtMatch = Regex.Match(
            sanitizedForAmount,
            @"\b(?<curr>OMR|RO|USD|AED|SAR|EUR|GBP|BHD|KWD|QAR)\s*(?<amt>\d{1,9}(?:,\d{3})*(?:\.\d{1,3})?)\b",
            RegexOptions.IgnoreCase);
        if (amtMatch.Success && TryParseDecimal(amtMatch.Groups["amt"].Value, out var parsedAmt))
        {
            currency = amtMatch.Groups["curr"].Value.ToUpperInvariant();
            if (currency == "RO") currency = "OMR";
            amount = parsedAmt;
        }

        var balanceAfter = ExtractSafeBalance(normalizedMessage);
        var accountMasked = ExtractMaskedAccountOrCard(normalizedMessage);
        var reference = ExtractTransactionReference(normalizedMessage);
        var txDate = ExtractTransactionDateFromText(normalizedMessage) ?? request.FallbackDate;

        string direction = request.FallbackDirection?.ToUpperInvariant() ?? "DEBIT";
        string txType = "OTHER";
        string? rawCounterparty = null;
        string generatedDesc;
        int confidence = 55;

        if (Regex.IsMatch(normalizedMessage, @"\b(?:cash\s+withdrawal|atm\s+withdrawal|withdrawn\s+from\s+atm)\b", RegexOptions.IgnoreCase))
        {
            txType = "CASH_WITHDRAWAL";
            direction = "DEBIT";
            generatedDesc = "Cash withdrawal";
            confidence = 80;
        }
        else if (Regex.IsMatch(normalizedMessage, @"\b(?:you\s+have\s+sent|transfer\s+to|transferred\s+to|paid\s+to)\b", RegexOptions.IgnoreCase))
        {
            txType = "TRANSFER_SENT";
            direction = "DEBIT";
            var m = Regex.Match(normalizedMessage, @"\b(?:to)\s+(?<cp>[A-Za-z0-9#*.\-\s]{2,40}?)(?:\s+from|\s+on|\s+using|\s+Txn|\.|$)", RegexOptions.IgnoreCase);
            rawCounterparty = m.Success ? m.Groups["cp"].Value : null;
            var cleanCp = CleanCounterpartyName(rawCounterparty, txType);
            generatedDesc = !string.IsNullOrWhiteSpace(cleanCp) ? $"Money sent to {cleanCp}" : "Money sent";
            confidence = !string.IsNullOrWhiteSpace(cleanCp) ? 72 : 60;
        }
        else if (Regex.IsMatch(normalizedMessage, @"\b(?:you\s+have\s+received|received\s+from|credited.*from)\b", RegexOptions.IgnoreCase))
        {
            txType = "TRANSFER_RECEIVED";
            direction = "CREDIT";
            var m = Regex.Match(normalizedMessage, @"\b(?:from)\s+(?<cp>[A-Za-z0-9#*.\-\s]{2,40}?)(?:\s+in\s+your|\s+on|\s+using|\s+Txn|\.|$)", RegexOptions.IgnoreCase);
            rawCounterparty = m.Success ? m.Groups["cp"].Value : null;
            var cleanCp = CleanCounterpartyName(rawCounterparty, txType);
            generatedDesc = !string.IsNullOrWhiteSpace(cleanCp) ? $"Money received from {cleanCp}" : "Money received";
            confidence = !string.IsNullOrWhiteSpace(cleanCp) ? 72 : 60;
        }
        else if (Regex.IsMatch(normalizedMessage, @"\b(?:used\s+for|purchase\s+at|payment\s+at|pos)\b", RegexOptions.IgnoreCase))
        {
            txType = "CARD_PAYMENT";
            direction = "DEBIT";
            var m = Regex.Match(normalizedMessage, @"\b(?:at)\s+(?<cp>.+?)(?:\s+on\s+\d|\.\s*Available|\.\s*Avl|\.\.\.|$)", RegexOptions.IgnoreCase);
            rawCounterparty = m.Success ? m.Groups["cp"].Value : null;
            var cleanCp = CleanCounterpartyName(rawCounterparty, txType);
            generatedDesc = !string.IsNullOrWhiteSpace(cleanCp) ? $"Card payment at {cleanCp}" : "Card payment";
            confidence = !string.IsNullOrWhiteSpace(cleanCp) ? 72 : 60;
        }
        else if (Regex.IsMatch(normalizedMessage, @"\bhas\s+been\s+credited\b", RegexOptions.IgnoreCase))
        {
            txType = "ACCOUNT_CREDIT";
            direction = "CREDIT";
            generatedDesc = "Money credited to account";
            confidence = 75;
        }
        else
        {
            // Clean up any raw narration as best-effort
            rawCounterparty = normalizedMessage;
            var cleanCp = CleanCounterpartyName(normalizedMessage, "CARD_PAYMENT");
            if (!string.IsNullOrWhiteSpace(cleanCp) && normalizedMessage.Length <= 35 && direction == "DEBIT")
            {
                txType = "CARD_PAYMENT";
                generatedDesc = $"Card payment at {cleanCp}";
                confidence = 68;
            }
            else
            {
                generatedDesc = !string.IsNullOrWhiteSpace(cleanCp) ? cleanCp : "Bank transaction";
                confidence = 45;
            }
        }

        var cleanedCounterparty = CleanCounterpartyName(rawCounterparty, txType);

        var dto = new ParsedTransactionMessageDto
        {
            OriginalMessage = request.RawMessage.Trim(),
            GeneratedDescription = generatedDesc,
            BankCode = canonicalBank.Code,
            BankName = canonicalBank.Name,
            TransactionType = txType,
            Direction = direction,
            Amount = amount,
            Currency = currency,
            CounterpartyName = string.IsNullOrWhiteSpace(cleanedCounterparty) ? null : cleanedCounterparty,
            RawCounterparty = rawCounterparty,
            TransactionDate = txDate,
            AccountNumberMasked = accountMasked,
            TransactionReference = reference,
            BalanceAfter = balanceAfter,
            ConfidenceScore = confidence,
            ReviewStatus = confidence >= 75 ? "AUTO_APPROVED" : "NEEDS_REVIEW",
            Warnings = new List<string> { "No exact bank pattern matched; parsed using heuristic fallback." }
        };
        dto.DeduplicationKey = BuildDeduplicationKey(null, dto);
        return dto;
    }

    public async Task<ParsedTransactionMessageDto> ParseAndStoreAsync(
        ParseBankMessageRequestDto request,
        Guid? userId = null,
        Guid? transactionId = null,
        Guid? smsLogId = null)
    {
        var parsed = await ParseMessageAsync(request);
        parsed.UserId = userId;
        parsed.TransactionId = transactionId;
        parsed.SmsLogId = smsLogId;
        parsed.DeduplicationKey = BuildDeduplicationKey(userId, parsed);

        // Check if we already have a ParsedTransactionMessage for this TransactionId
        if (transactionId.HasValue)
        {
            var existingByTx = await _db.ParsedTransactionMessages
                .FirstOrDefaultAsync(p => p.TransactionId == transactionId.Value);
            if (existingByTx != null)
            {
                // Preserve manual review edits if an admin already reviewed it
                if (existingByTx.ReviewStatus != "MANUALLY_REVIEWED")
                {
                    ApplyDtoToEntity(parsed, existingByTx);
                    await _db.SaveChangesAsync();
                }
                parsed.Id = existingByTx.Id;
                parsed.GeneratedDescription = existingByTx.GeneratedDescription;
                parsed.ReviewStatus = existingByTx.ReviewStatus;
                return parsed;
            }
        }

        // Check reference-based or signature-based duplicate for new incoming messages
        if (!string.IsNullOrWhiteSpace(parsed.TransactionReference))
        {
            var dupByRef = await _db.ParsedTransactionMessages.FirstOrDefaultAsync(p =>
                p.BankCode == parsed.BankCode &&
                p.TransactionReference == parsed.TransactionReference &&
                (!userId.HasValue || p.UserId == userId.Value) &&
                (!transactionId.HasValue || p.TransactionId != transactionId.Value));

            if (dupByRef != null && !transactionId.HasValue)
            {
                parsed.IsDuplicate = true;
                parsed.Warnings.Add($"Duplicate transaction reference detected: {parsed.TransactionReference}");
                return parsed;
            }
        }

        var entity = new ParsedTransactionMessage();
        ApplyDtoToEntity(parsed, entity);
        entity.CreatedAt = DateTimeOffset.UtcNow;
        entity.UpdatedAt = DateTimeOffset.UtcNow;

        _db.ParsedTransactionMessages.Add(entity);
        await _db.SaveChangesAsync();

        parsed.Id = entity.Id;
        return parsed;
    }

    public async Task<ParserBackfillSummaryDto> BackfillExistingTransactionsAsync()
    {
        var summary = new ParserBackfillSummaryDto();
        var allTransactions = await _db.PfmTransactions.ToListAsync();
        var existingParsed = await _db.ParsedTransactionMessages.ToListAsync();
        var byTxId = existingParsed
            .Where(p => p.TransactionId.HasValue)
            .GroupBy(p => p.TransactionId!.Value)
            .ToDictionary(g => g.Key, g => g.First());

        summary.TotalScanned = allTransactions.Count;

        foreach (var tx in allTransactions)
        {
            var req = new ParseBankMessageRequestDto
            {
                BankCode = tx.BankCode,
                Sender = tx.BankName,
                RawMessage = tx.Narration ?? string.Empty,
                FallbackAmount = tx.Amount,
                FallbackCurrency = tx.Currency,
                FallbackDirection = tx.TransactionType == ThemarIP.Domain.Enums.Pfm.TransactionType.Credit ? "CREDIT" : "DEBIT",
                FallbackDate = tx.TransactionDate
            };

            var parsed = await ParseMessageAsync(req);
            parsed.UserId = tx.UserId;
            parsed.TransactionId = tx.Id;
            if (!parsed.BalanceAfter.HasValue && tx.BalanceAfter.HasValue)
            {
                parsed.BalanceAfter = tx.BalanceAfter;
            }
            if (parsed.TransactionDate.HasValue && parsed.TransactionDate.Value.TimeOfDay != TimeSpan.Zero && tx.TransactionDate.TimeOfDay == TimeSpan.Zero)
            {
                tx.TransactionDate = parsed.TransactionDate.Value;
            }
            parsed.DeduplicationKey = BuildDeduplicationKey(tx.UserId, parsed);

            if (byTxId.TryGetValue(tx.Id, out var existing))
            {
                if (existing.ReviewStatus != "MANUALLY_REVIEWED")
                {
                    ApplyDtoToEntity(parsed, existing);
                    summary.Updated++;
                }
            }
            else
            {
                var entity = new ParsedTransactionMessage();
                ApplyDtoToEntity(parsed, entity);
                entity.CreatedAt = tx.CreatedAt;
                entity.UpdatedAt = DateTimeOffset.UtcNow;
                _db.ParsedTransactionMessages.Add(entity);
                summary.NewlyParsed++;
            }

            if (parsed.ConfidenceScore >= 75) summary.HighConfidenceCount++;
            else summary.NeedsReviewCount++;
        }

        await _db.SaveChangesAsync();
        return summary;
    }

    public async Task<List<BankMessageParserRuleDto>> GetRulesAsync(string? bankCode = null)
    {
        var query = _db.BankMessageParserRules.AsQueryable();
        if (!string.IsNullOrWhiteSpace(bankCode) && !string.Equals(bankCode, "ALL", StringComparison.OrdinalIgnoreCase))
        {
            query = query.Where(r => r.BankCode == bankCode);
        }
        var list = await query
            .OrderBy(r => r.Priority)
            .ThenBy(r => r.BankName)
            .ThenBy(r => r.RuleName)
            .ToListAsync();
        return list.Select(ToRuleDto).ToList();
    }

    public async Task<BankMessageParserRuleDto> SaveRuleAsync(Guid? id, BankMessageParserRuleDto dto)
    {
        if (string.IsNullOrWhiteSpace(dto.RuleName))
            throw new ArgumentException("Rule name is required.");
        if (string.IsNullOrWhiteSpace(dto.RegexPattern))
            throw new ArgumentException("Regex pattern is required.");

        // Validate regex syntax before saving
        try
        {
            _ = new Regex(dto.RegexPattern, RegexOptions.IgnoreCase | RegexOptions.CultureInvariant, RegexTimeout);
        }
        catch (ArgumentException ex)
        {
            throw new ArgumentException($"Invalid regular expression: {ex.Message}");
        }

        var canonical = BankCatalog.Canonical(dto.BankCode, dto.BankName);
        BankMessageParserRule? entity = null;
        if (id.HasValue && id.Value != Guid.Empty)
        {
            entity = await _db.BankMessageParserRules.FirstOrDefaultAsync(r => r.Id == id.Value);
        }

        bool isNew = entity == null;
        entity ??= new BankMessageParserRule { Id = Guid.NewGuid(), CreatedAt = DateTimeOffset.UtcNow };

        entity.BankCode = canonical.Code;
        entity.BankName = canonical.Name;
        entity.SenderIds = string.IsNullOrWhiteSpace(dto.SenderIds) ? canonical.Name : dto.SenderIds.Trim();
        entity.RuleName = dto.RuleName.Trim();
        entity.TransactionType = string.IsNullOrWhiteSpace(dto.TransactionType) ? "CARD_PAYMENT" : dto.TransactionType.Trim().ToUpperInvariant();
        entity.Direction = string.Equals(dto.Direction, "CREDIT", StringComparison.OrdinalIgnoreCase) ? "CREDIT" : "DEBIT";
        entity.RegexPattern = dto.RegexPattern.Trim();
        entity.DescriptionTemplate = string.IsNullOrWhiteSpace(dto.DescriptionTemplate) ? "{Counterparty}" : dto.DescriptionTemplate.Trim();
        entity.FallbackDescription = string.IsNullOrWhiteSpace(dto.FallbackDescription) ? "Bank transaction" : dto.FallbackDescription.Trim();
        entity.SampleMessage = (dto.SampleMessage ?? string.Empty).Trim();
        entity.Priority = dto.Priority > 0 ? dto.Priority : 10;
        entity.BaseConfidence = Math.Clamp(dto.BaseConfidence, 10, 100);
        entity.CleanCounterparty = dto.CleanCounterparty;
        entity.IsActive = dto.IsActive;
        entity.UpdatedAt = DateTimeOffset.UtcNow;

        if (isNew)
        {
            _db.BankMessageParserRules.Add(entity);
        }

        await _db.SaveChangesAsync();
        return ToRuleDto(entity);
    }

    public async Task<bool> DeleteRuleAsync(Guid id)
    {
        var entity = await _db.BankMessageParserRules.FirstOrDefaultAsync(r => r.Id == id);
        if (entity == null) return false;
        _db.BankMessageParserRules.Remove(entity);
        await _db.SaveChangesAsync();
        return true;
    }

    public async Task<List<ParsedTransactionMessageDto>> GetParsedMessagesAsync(
        string? reviewStatus = null,
        string? bankCode = null,
        int take = 250)
    {
        take = Math.Clamp(take, 1, 1000);
        var query = _db.ParsedTransactionMessages.AsQueryable();

        if (!string.IsNullOrWhiteSpace(reviewStatus) && !string.Equals(reviewStatus, "ALL", StringComparison.OrdinalIgnoreCase))
        {
            query = query.Where(p => p.ReviewStatus == reviewStatus);
        }
        if (!string.IsNullOrWhiteSpace(bankCode) && !string.Equals(bankCode, "ALL", StringComparison.OrdinalIgnoreCase))
        {
            query = query.Where(p => p.BankCode == bankCode);
        }

        var items = await query.ToListAsync();
        return items
            .OrderByDescending(p => p.TransactionDate ?? p.CreatedAt)
            .Take(take)
            .Select(ToParsedDto)
            .ToList();
    }

    public async Task<ParsedTransactionMessageDto?> ReviewMessageAsync(Guid id, ManualReviewUpdateDto dto)
    {
        var entity = await _db.ParsedTransactionMessages.FirstOrDefaultAsync(p => p.Id == id);
        if (entity == null) return null;

        if (!string.IsNullOrWhiteSpace(dto.GeneratedDescription))
            entity.GeneratedDescription = dto.GeneratedDescription.Trim();
        if (!string.IsNullOrWhiteSpace(dto.TransactionType))
            entity.TransactionType = dto.TransactionType.Trim().ToUpperInvariant();
        if (!string.IsNullOrWhiteSpace(dto.Direction))
            entity.Direction = dto.Direction.Trim().ToUpperInvariant();
        if (dto.Amount.HasValue && dto.Amount.Value > 0)
            entity.Amount = dto.Amount.Value;
        if (!string.IsNullOrWhiteSpace(dto.Currency))
            entity.Currency = dto.Currency.Trim().ToUpperInvariant();
        if (dto.CounterpartyName != null)
            entity.CounterpartyName = string.IsNullOrWhiteSpace(dto.CounterpartyName) ? null : dto.CounterpartyName.Trim();
        if (dto.AccountNumberMasked != null)
            entity.AccountNumberMasked = string.IsNullOrWhiteSpace(dto.AccountNumberMasked) ? null : dto.AccountNumberMasked.Trim();
        if (dto.TransactionReference != null)
            entity.TransactionReference = string.IsNullOrWhiteSpace(dto.TransactionReference) ? null : dto.TransactionReference.Trim();

        entity.ReviewStatus = string.IsNullOrWhiteSpace(dto.ReviewStatus) ? "MANUALLY_REVIEWED" : dto.ReviewStatus.Trim().ToUpperInvariant();
        entity.ConfidenceScore = 100;
        entity.UpdatedAt = DateTimeOffset.UtcNow;

        await _db.SaveChangesAsync();
        return ToParsedDto(entity);
    }

    public async Task<Dictionary<Guid, ParsedTransactionMessageDto>> GetParsedLookupByTransactionIdsAsync(IEnumerable<Guid> transactionIds)
    {
        var idSet = transactionIds.Distinct().ToList();
        if (idSet.Count == 0) return new Dictionary<Guid, ParsedTransactionMessageDto>();

        var rows = await _db.ParsedTransactionMessages
            .Where(p => p.TransactionId.HasValue && idSet.Contains(p.TransactionId.Value))
            .ToListAsync();

        var dict = new Dictionary<Guid, ParsedTransactionMessageDto>();
        foreach (var r in rows)
        {
            if (r.TransactionId.HasValue && !dict.ContainsKey(r.TransactionId.Value))
            {
                dict[r.TransactionId.Value] = ToParsedDto(r);
            }
        }
        return dict;
    }

    // ───────────────────────── Smart Formatting & Extraction Helpers ─────────────────────────

    public static string CleanCounterpartyName(string? raw, string transactionType)
    {
        if (string.IsNullOrWhiteSpace(raw)) return string.Empty;

        var s = raw.Trim().Trim('.', ',', ';', ':', '-', '_');

        // Remove trailing ellipsis from truncated SMS ("NEW TAIBA P...", "TURKI ALI S...")
        s = Regex.Replace(s, @"\.{2,}$", "").Trim();

        // Remove trailing reference codes (e.g., POS261760ZZW1N45R, FT26200081709810, LFT26202QZHGP9YF, BMCT015151257131)
        s = Regex.Replace(s, @"\b(?:POS\d{5,}[A-Z0-9]*|L?FT\d{5,}[A-Z0-9]*|BMCT\d{6,}[A-Z0-9]*)\b", "", RegexOptions.IgnoreCase).Trim();

        // Remove exchange rate / FX suffixes like "512.5,240.000@0.00100000"
        s = Regex.Replace(s, @"\s+\d+[.,\d]*@\d+[.,\d]*$", "").Trim();

        // Remove P.O. Box phrases ("PO BOX 73 MUSC", "P O BOX 1837 PC MUSC")
        s = Regex.Replace(s, @"\bP\.?\s*O\.?\s*BOX\s*\d+(?:\s+PC\s*\d*)?", "", RegexOptions.IgnoreCase).Trim();

        // Strip leading store/terminal numbers on card payments ("7202 OMAN OIL", "576892-OMAN OIL", "5231 OMAN OIL")
        if (string.Equals(transactionType, "CARD_PAYMENT", StringComparison.OrdinalIgnoreCase))
        {
            s = Regex.Replace(s, @"^\d{3,8}\s*[-–]?\s*", "").Trim();
            // Fix glued city suffixes from 16-char POS fields (e.g. "NORTHMUSC" -> "NORTH", "NORTHMCT" -> "NORTH", "INVESTMENTAL H" -> "INVESTMENT")
            s = Regex.Replace(s, @"NORTH(?:MUSC|MCT)\b", "NORTH", RegexOptions.IgnoreCase);
            s = Regex.Replace(s, @"(\w{5,})(?:MUSC|MCT)\b", "$1", RegexOptions.IgnoreCase);
            // Strip trailing truncated city/type codes at end of POS strings (" AL H", " AL M", " AL A", " MUSC", " MCT", " MABE", " LLC", " O", " H")
            s = Regex.Replace(s, @"\s+(?:MUSC|MCT|MABE|LLC|AL\s+[A-Z]|O|H|P|TE)$", "", RegexOptions.IgnoreCase).Trim();
            // Clean domain suffixes like "talabat.com" -> "Talabat"
            s = Regex.Replace(s, @"\.(?:com|om|net|org)\b", "", RegexOptions.IgnoreCase).Trim();
        }

        // Handle Bank Muscat masked person names:
        // Examples:
        // "ALI #######################AHRI" -> "Ali"
        // "SULA#### ALI" -> "Sulaiman Ali"
        // "TURKXXXXXXAHRI" -> "Turki"
        // "QABS###################AHRI" -> "Qabs"
        // "ABSA#####SAIN" -> "Absa"
        if (s.Contains('#') || Regex.IsMatch(s, @"X{3,}|\*{3,}"))
        {
            var rawTokens = s.Split(' ', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);
            var cleanWords = new List<string>();

            foreach (var token in rawTokens)
            {
                if (token.Contains('#') || Regex.IsMatch(token, @"X{3,}|\*{3,}"))
                {
                    // Extract letters before the mask (non-greedy so X-masks like TURKXXXXXXAHRI capture TURK)
                    var prefixMatch = Regex.Match(token, @"^(?<prefix>[A-Za-z]{2,}?)[#X*]{2,}");
                    if (prefixMatch.Success)
                    {
                        var prefix = prefixMatch.Groups["prefix"].Value;
                        if (MaskedFirstNameExpansions.TryGetValue(prefix, out var expanded))
                        {
                            cleanWords.Add(expanded);
                        }
                        else
                        {
                            cleanWords.Add(ToTitleCaseWord(prefix));
                        }
                    }
                    // If the mask is at the beginning (like "#######################AHRI"), drop that surname fragment when we already have a first name
                }
                else
                {
                    cleanWords.Add(ToTitleCaseWord(token));
                }
            }

            if (cleanWords.Count > 0)
            {
                return string.Join(" ", cleanWords.Take(2));
            }
        }

        // If counterparty is just "BM" (from "Mobile Payment from BMCT... BM FT..."), return empty so fallback "Money received via Mobile Payment" is used
        if (string.Equals(s, "BM", StringComparison.OrdinalIgnoreCase))
        {
            return string.Empty;
        }

        // Normalize spacing around hyphens
        s = Regex.Replace(s, @"\s*-\s*", " - ").Trim(' ', '-');
        s = Regex.Replace(s, @"\s+", " ").Trim();

        // For person transfers with long 4-6 word full names (e.g. "TURKI ALI SULAIMAN AL BAHRI", "IBRAHIM MOHAMED ELNABAWI"),
        // keep first 2 names (or first name if second is long) for clean, readable descriptions ("Money received from Turki Ali", "Money sent to Ibrahim Mohamed")
        var words = s.Split(' ', StringSplitOptions.RemoveEmptyEntries);
        if ((string.Equals(transactionType, "TRANSFER_SENT", StringComparison.OrdinalIgnoreCase) ||
             string.Equals(transactionType, "TRANSFER_RECEIVED", StringComparison.OrdinalIgnoreCase)) &&
            words.Length > 2)
        {
            // If word[0] is "MD" or "ABDUL" or "AL", keep 3 words if needed, otherwise 2 words
            int takeCount = (string.Equals(words[0], "ABDUL", StringComparison.OrdinalIgnoreCase) ||
                             string.Equals(words[0], "MD", StringComparison.OrdinalIgnoreCase))
                ? Math.Min(2, words.Length)
                : 2;
            words = words.Take(takeCount).ToArray();
        }

        return string.Join(" ", words.Select(ToTitleCaseWord));
    }

    private static string ToTitleCaseWord(string word)
    {
        if (string.IsNullOrWhiteSpace(word)) return string.Empty;
        if (word == "-") return "-";
        // Keep known acronyms uppercase if 2-3 chars like NBO, OAB, ROP
        if (word.Equals("ROP", StringComparison.OrdinalIgnoreCase) ||
            word.Equals("NBO", StringComparison.OrdinalIgnoreCase) ||
            word.Equals("OAB", StringComparison.OrdinalIgnoreCase) ||
            word.Equals("ATM", StringComparison.OrdinalIgnoreCase))
        {
            return word.ToUpperInvariant();
        }
        var lower = word.ToLowerInvariant();
        return char.ToUpperInvariant(lower[0]) + (lower.Length > 1 ? lower[1..] : string.Empty);
    }

    private static string FormatDescription(
        string template,
        string fallback,
        string transactionType,
        string? counterparty,
        string? accountMasked,
        decimal amount,
        string currency,
        string bankName,
        string? reference)
    {
        if (string.Equals(transactionType, "CASH_WITHDRAWAL", StringComparison.OrdinalIgnoreCase))
        {
            return string.IsNullOrWhiteSpace(template) ? "Cash withdrawal" : template.Replace("{Counterparty}", counterparty ?? "").Trim();
        }

        if (string.IsNullOrWhiteSpace(counterparty) &&
            template.Contains("{Counterparty}", StringComparison.OrdinalIgnoreCase))
        {
            return !string.IsNullOrWhiteSpace(fallback) ? fallback : "Bank transaction";
        }

        var result = string.IsNullOrWhiteSpace(template) ? fallback : template;
        result = result
            .Replace("{Counterparty}", counterparty ?? string.Empty, StringComparison.OrdinalIgnoreCase)
            .Replace("{Account}", accountMasked ?? string.Empty, StringComparison.OrdinalIgnoreCase)
            .Replace("{Amount}", amount.ToString("0.000", CultureInfo.InvariantCulture), StringComparison.OrdinalIgnoreCase)
            .Replace("{Currency}", currency, StringComparison.OrdinalIgnoreCase)
            .Replace("{BankName}", bankName, StringComparison.OrdinalIgnoreCase)
            .Replace("{Reference}", reference ?? string.Empty, StringComparison.OrdinalIgnoreCase);

        return Regex.Replace(result, @"\s+", " ").Trim();
    }

    private static string StripBalanceAndFeeClauses(string message)
    {
        var s = message;
        // Strip Available Balance / Avl Bal / Available limit clauses so their OMR amounts are never mistaken for transaction amounts
        s = Regex.Replace(s, @"(?:New\s+)?(?:Available\s+Balance(?:\s+is)?|Avl\.?\s*Bal\.?|Available\s+limit|Bal(?:ance)?)\s*:?\s*(?:[A-Z]{3}\s*)?\d+(?:[.,]\d+)?", "", RegexOptions.IgnoreCase);
        // Strip Fee / Charge clauses
        s = Regex.Replace(s, @"(?:Fee|Charges?|VAT)\s*:?\s*(?:[A-Z]{3}\s*)?\d+(?:[.,]\d+)?", "", RegexOptions.IgnoreCase);
        // Strip Txn Id / Reference clauses
        s = Regex.Replace(s, @"(?:Txn\s*Id|Ref(?:erence)?(?:\s*No)?)\s*:?\s*[A-Z0-9]+", "", RegexOptions.IgnoreCase);
        return s;
    }

    private static decimal? ExtractSafeBalance(string message)
    {
        var m = Regex.Match(
            message,
            @"(?:New\s+Available\s+Balance\s+is|Avl\.?\s*Bal\.?|Available\s+Balance|Available\s+limit)\s*:?\s*(?:[A-Z]{3}\s*)?(?<bal>\d{1,9}(?:,\d{3})*(?:\.\d{1,3})?)",
            RegexOptions.IgnoreCase);
        if (m.Success && TryParseDecimal(m.Groups["bal"].Value, out var bal))
        {
            return bal;
        }
        return null;
    }

    private static string? ExtractMaskedAccountOrCard(string message)
    {
        var m = Regex.Match(
            message,
            @"(?:\b(?:a/c|account|card)\s+(?:no\.?\s*)?)(?<acc>\d{4}[0-9X*#]{4,12}\d{2,4})\b",
            RegexOptions.IgnoreCase);
        if (m.Success) return m.Groups["acc"].Value.Trim();

        var m2 = Regex.Match(message, @"\b(?<acc>\d{4}[X*]{4,10}\d{4})\b");
        return m2.Success ? m2.Groups["acc"].Value.Trim() : null;
    }

    private static string? ExtractTransactionReference(string message)
    {
        var m = Regex.Match(
            message,
            @"(?:Txn\s*Id\s*:?\s*(?<ref>[A-Z0-9]{6,24})|\b(?<ref2>BMCT\d{8,18}|L?FT\d{6,18}[A-Z0-9]*|POS\d{6,18}[A-Z0-9]*)\b)",
            RegexOptions.IgnoreCase);
        if (!m.Success) return null;
        return (m.Groups["ref"].Success ? m.Groups["ref"].Value : m.Groups["ref2"].Value).Trim();
    }

    private static DateTimeOffset? ExtractTransactionDateFromText(string message)
    {
        var m = Regex.Match(
            message,
            @"\bon\s+(?<dt>\d{1,2}[/-]\d{1,2}[/-]\d{2,4}(?:\s+\d{1,2}:\d{2}(?::\d{2})?)?)",
            RegexOptions.IgnoreCase);
        return m.Success ? ParseTransactionDate(m.Groups["dt"].Value) : null;
    }

    private static DateTimeOffset? ParseTransactionDate(string? raw)
    {
        if (string.IsNullOrWhiteSpace(raw)) return null;
        var clean = raw.Trim().TrimEnd('.');
        if (DateTime.TryParseExact(clean, SupportedDateFormats, CultureInfo.InvariantCulture, DateTimeStyles.AssumeLocal, out var exact))
        {
            return new DateTimeOffset(exact);
        }
        if (DateTime.TryParse(clean, CultureInfo.InvariantCulture, DateTimeStyles.AssumeLocal, out var loose))
        {
            return new DateTimeOffset(loose);
        }
        return null;
    }

    private static bool TryParseDecimal(string raw, out decimal value)
    {
        var clean = Regex.Replace(raw ?? string.Empty, @"[^\d.,\-]", "").Replace(",", "");
        return decimal.TryParse(clean, NumberStyles.Number, CultureInfo.InvariantCulture, out value);
    }

    private static bool IsPromoOrOtp(string message)
    {
        return message.Contains("% off", StringComparison.OrdinalIgnoreCase)
            || message.Contains("UNSUB", StringComparison.OrdinalIgnoreCase)
            || message.Contains("Valid until", StringComparison.OrdinalIgnoreCase)
            || message.Contains("T&Cs Apply", StringComparison.OrdinalIgnoreCase)
            || Regex.IsMatch(message, @"\b(?:OTP|verification\s+code|one\s+time\s+password)\b", RegexOptions.IgnoreCase);
    }

    private static bool SenderMatches(string? senderIdsCsv, string? sender)
    {
        if (string.IsNullOrWhiteSpace(senderIdsCsv) || string.IsNullOrWhiteSpace(sender)) return false;
        var tokens = senderIdsCsv.Split(new[] { ',', ';' }, StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);
        return tokens.Any(t => string.Equals(t, sender.Trim(), StringComparison.OrdinalIgnoreCase) ||
                               sender.Contains(t, StringComparison.OrdinalIgnoreCase));
    }

    private static string BuildDeduplicationKey(Guid? userId, ParsedTransactionMessageDto dto)
    {
        var userPart = userId?.ToString() ?? "GLOBAL";
        if (!string.IsNullOrWhiteSpace(dto.TransactionReference))
        {
            return $"REF|{userPart}|{dto.BankCode}|{dto.TransactionReference.ToUpperInvariant()}";
        }

        var datePart = dto.TransactionDate?.ToString("yyyyMMddHHmm") ?? "NODATE";
        var rawSig = $"{userPart}|{dto.BankCode}|{dto.Direction}|{dto.Amount:0.000}|{datePart}|{dto.AccountNumberMasked ?? ""}|{dto.CounterpartyName ?? dto.GeneratedDescription}";
        var hash = Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(rawSig)))[..24];
        return $"SIG|{hash}";
    }

    private static void ApplyDtoToEntity(ParsedTransactionMessageDto dto, ParsedTransactionMessage entity)
    {
        entity.TransactionId = dto.TransactionId;
        entity.SmsLogId = dto.SmsLogId;
        entity.UserId = dto.UserId;
        entity.OriginalMessage = dto.OriginalMessage;
        entity.GeneratedDescription = dto.GeneratedDescription;
        entity.BankCode = dto.BankCode;
        entity.BankName = dto.BankName;
        entity.TransactionType = dto.TransactionType;
        entity.Direction = dto.Direction;
        entity.Amount = dto.Amount;
        entity.Currency = dto.Currency;
        entity.CounterpartyName = dto.CounterpartyName;
        entity.RawCounterparty = dto.RawCounterparty;
        entity.TransactionDate = dto.TransactionDate;
        entity.AccountNumberMasked = dto.AccountNumberMasked;
        entity.TransactionReference = dto.TransactionReference;
        entity.BalanceAfter = dto.BalanceAfter;
        entity.ConfidenceScore = dto.ConfidenceScore;
        entity.ReviewStatus = dto.ReviewStatus;
        entity.MatchedRuleId = dto.MatchedRuleId;
        entity.MatchedRuleName = dto.MatchedRuleName;
        entity.DeduplicationKey = dto.DeduplicationKey;
        entity.UpdatedAt = DateTimeOffset.UtcNow;
    }

    private static BankMessageParserRuleDto ToRuleDto(BankMessageParserRule r) => new()
    {
        Id = r.Id,
        BankCode = r.BankCode,
        BankName = r.BankName,
        SenderIds = r.SenderIds,
        RuleName = r.RuleName,
        TransactionType = r.TransactionType,
        Direction = r.Direction,
        RegexPattern = r.RegexPattern,
        DescriptionTemplate = r.DescriptionTemplate,
        FallbackDescription = r.FallbackDescription,
        SampleMessage = r.SampleMessage,
        Priority = r.Priority,
        BaseConfidence = r.BaseConfidence,
        CleanCounterparty = r.CleanCounterparty,
        IsActive = r.IsActive,
        UpdatedAt = r.UpdatedAt
    };

    private static ParsedTransactionMessageDto ToParsedDto(ParsedTransactionMessage p) => new()
    {
        Id = p.Id,
        TransactionId = p.TransactionId,
        SmsLogId = p.SmsLogId,
        UserId = p.UserId,
        OriginalMessage = p.OriginalMessage,
        GeneratedDescription = p.GeneratedDescription,
        BankCode = p.BankCode,
        BankName = p.BankName,
        TransactionType = p.TransactionType,
        Direction = p.Direction,
        Amount = p.Amount,
        Currency = p.Currency,
        CounterpartyName = p.CounterpartyName,
        RawCounterparty = p.RawCounterparty,
        TransactionDate = p.TransactionDate,
        AccountNumberMasked = p.AccountNumberMasked,
        TransactionReference = p.TransactionReference,
        BalanceAfter = p.BalanceAfter,
        ConfidenceScore = p.ConfidenceScore,
        ReviewStatus = p.ReviewStatus,
        MatchedRuleId = p.MatchedRuleId,
        MatchedRuleName = p.MatchedRuleName,
        DeduplicationKey = p.DeduplicationKey,
        CreatedAt = p.CreatedAt
    };
}
