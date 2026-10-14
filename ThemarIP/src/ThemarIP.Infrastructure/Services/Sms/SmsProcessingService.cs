using System;
using System.Collections.Generic;
using System.Linq;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using System.Threading.Tasks;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using ThemarIP.Application.Common.Interfaces;
using ThemarIP.Application.DTOs.Sms;
using ThemarIP.Application.DTOs.Statements;
using ThemarIP.Application.Interfaces.Statements;
using ThemarIP.Domain.Entities.Sms;

namespace ThemarIP.Infrastructure.Services.Sms;

public class SmsProcessingService : ISmsProcessingService
{
    private static readonly JsonSerializerOptions Json = new(JsonSerializerDefaults.Web);

    private readonly IApplicationDbContext _db;
    private readonly IBankNotificationParserService _notifications;
    private readonly ILogger<SmsProcessingService> _log;

    public SmsProcessingService(IApplicationDbContext db, IBankNotificationParserService notifications, ILogger<SmsProcessingService> log)
    {
        _db = db;
        _notifications = notifications;
        _log = log;
    }

    // ───────────────────────── Ingestion ─────────────────────────

    public async Task<SmsIngestResultDto> IngestAsync(Guid userId, SmsIngestRequestDto request)
    {
        var sender = (request.Sender ?? string.Empty).Trim();
        var message = SmsParsingEngine.Normalize(request.Message);
        var received = request.ReceivedAtMs.HasValue
            ? DateTimeOffset.FromUnixTimeMilliseconds(request.ReceivedAtMs.Value)
            : DateTimeOffset.UtcNow;

        var entry = new SmsProcessingLog
        {
            UserId = userId,
            Sender = Truncate(sender, 64),
            RawMessage = Truncate(message, 2000),
            MessageHash = Hash(userId, sender, message),
            ReceivedAt = received
        };

        try
        {
            if (sender.Length == 0 || message.Length == 0)
                return await Finish(entry, "ValidationFailed", "Sender and message are required.");
            if (message.Length > 2000)
                return await Finish(entry, "ValidationFailed", "Message too long.");

            // Exact-duplicate guard (device retries, re-delivered broadcasts).
            if (await _db.SmsProcessingLogs.AnyAsync(l => l.UserId == userId && l.MessageHash == entry.MessageHash && l.Status == "Saved"))
                return await Finish(entry, "Duplicate", "This SMS was already processed.");

            var rules = (await _db.BankSmsRules.Where(r => r.IsActive).ToListAsync())
                .Where(r => SenderMatches(r.SenderIds, sender))
                .OrderByDescending(r => r.UpdatedAt)
                .ToList();

            if (rules.Count == 0)
                return await Finish(entry, "NoRule", $"No active rule for sender '{sender}'.");

            BankSmsRule? used = null;
            SmsRuleTestResultDto? parsed = null;
            foreach (var r in rules)
            {
                var res = SmsParsingEngine.Run(ToDto(r), message, received);
                if (res.Matched) { used = r; parsed = res; break; }
            }

            if (used == null || parsed?.Extracted == null)
                return await Finish(entry, "NoMatch", "Message did not match any active rule for this sender.");

            entry.RuleId = used.Id;
            entry.RuleVersion = used.Version;
            entry.ExtractedJson = JsonSerializer.Serialize(parsed.Extracted, Json);
            entry.Reference = Truncate(parsed.Extracted.Reference, 128);

            var invalid = SmsParsingEngine.Validate(parsed.Extracted);
            if (invalid != null)
                return await Finish(entry, "ValidationFailed", invalid, parsed.Extracted);

            var ex = parsed.Extracted;

            // Reference-based duplicate (same bank reference already saved for this user/rule).
            if (!string.IsNullOrEmpty(ex.Reference) &&
                await _db.SmsProcessingLogs.AnyAsync(l => l.UserId == userId && l.RuleId == used.Id && l.Reference == ex.Reference && l.Status == "Saved"))
                return await Finish(entry, "Duplicate", $"Reference {ex.Reference} already processed.", ex);

            var (merchantId, narration) = await MatchMerchantAsync(ex, message);

            var txId = await _notifications.ConfirmAndSaveNotificationAsync(new ConfirmNotificationRequestDto
            {
                UserId = userId,
                Transaction = new ParsedNotificationResultDto
                {
                    BankName = used.BankName,
                    SourceType = "SMS",
                    Amount = ex.Amount,
                    Currency = ex.Currency,
                    Direction = ex.Type,
                    Narration = narration,
                    TransactionDate = ex.Date ?? received,
                    BalanceAfter = ex.Balance,
                    MatchedMerchantId = merchantId
                }
            });

            // The shared save path defaults bank fields; stamp the real bank on the row we just created.
            var tx = await _db.PfmTransactions.FirstOrDefaultAsync(t => t.Id == txId);
            if (tx != null)
            {
                tx.BankName = used.BankName;
                if (!string.IsNullOrWhiteSpace(used.BankCode)) tx.BankCode = used.BankCode;
                await _db.SaveChangesAsync();
            }

            entry.TransactionId = txId;
            return await Finish(entry, "Saved", "Transaction saved.", ex, txId);
        }
        catch (Exception e)
        {
            _log.LogError(e, "SMS ingest failed for user {UserId}", userId);
            return await Finish(entry, "Error", "Processing error: " + e.Message);
        }
    }

    private async Task<SmsIngestResultDto> Finish(SmsProcessingLog entry, string status, string details, SmsExtractedDto? ex = null, Guid? txId = null)
    {
        entry.Status = status;
        entry.Details = Truncate(details, 1000) ?? string.Empty;
        _db.SmsProcessingLogs.Add(entry);
        try { await _db.SaveChangesAsync(); } catch (Exception e) { _log.LogError(e, "Could not write SMS log"); }
        return new SmsIngestResultDto { Status = status, Message = details, Extracted = ex, TransactionId = txId };
    }

    private async Task<(Guid? Id, string Narration)> MatchMerchantAsync(SmsExtractedDto ex, string rawMessage)
    {
        var text = ex.Merchant;
        var narration = !string.IsNullOrWhiteSpace(ex.Narration)
            ? ex.Narration
            : (!string.IsNullOrWhiteSpace(rawMessage) ? rawMessage : (!string.IsNullOrWhiteSpace(text) ? text : (ex.Type == "CREDIT" ? "SMS Credit" : "SMS Debit")));
        narration = Truncate(narration, 512) ?? string.Empty;

        var merchants = await _db.PfmMerchants.Include(m => m.Aliases).Where(m => m.IsActive).ToListAsync();

        // 1. Try matching against extracted merchant
        if (!string.IsNullOrWhiteSpace(text))
        {
            foreach (var m in merchants)
            {
                if ((!string.IsNullOrWhiteSpace(m.Name) && text.Contains(m.Name, StringComparison.OrdinalIgnoreCase)) ||
                    m.Aliases.Any(a => !string.IsNullOrWhiteSpace(a.AliasText) && text.Contains(a.AliasText, StringComparison.OrdinalIgnoreCase)))
                    return (m.Id, narration);
            }
        }

        // 2. Try matching against full raw message
        if (!string.IsNullOrWhiteSpace(rawMessage))
        {
            foreach (var m in merchants)
            {
                if ((!string.IsNullOrWhiteSpace(m.Name) && rawMessage.Contains(m.Name, StringComparison.OrdinalIgnoreCase)) ||
                    m.Aliases.Any(a => !string.IsNullOrWhiteSpace(a.AliasText) && rawMessage.Contains(a.AliasText, StringComparison.OrdinalIgnoreCase)))
                    return (m.Id, narration);
            }
        }

        return (null, narration);
    }

    // ───────────────────────── Senders / test ─────────────────────────

    public async Task<List<string>> GetActiveSenderIdsAsync()
    {
        var all = await _db.BankSmsRules.Where(r => r.IsActive).Select(r => r.SenderIds).ToListAsync();
        return all.SelectMany(SplitSenders).Distinct(StringComparer.OrdinalIgnoreCase).OrderBy(s => s).ToList();
    }

    public SmsRuleTestResultDto Test(SmsRuleTestRequestDto request) =>
        SmsParsingEngine.Run(request.Rule, SmsParsingEngine.Normalize(request.SampleMessage), DateTimeOffset.UtcNow);

    // ───────────────────────── Rule admin ─────────────────────────

    public async Task<List<BankSmsRuleDto>> ListRulesAsync() =>
        (await _db.BankSmsRules.OrderBy(r => r.BankName).ToListAsync()).Select(ToDto).ToList();

    public async Task<BankSmsRuleDto> SaveRuleAsync(Guid? id, BankSmsRuleDto dto, string? changedBy)
    {
        if (string.IsNullOrWhiteSpace(dto.BankName)) throw new ArgumentException("Bank name is required.");
        if (SplitSenders(dto.SenderIds).Count == 0) throw new ArgumentException("At least one sender ID is required.");
        if (!SmsParsingEngine.TryCompile(dto.Pattern, out var regex, out var err)) throw new ArgumentException(err);

        var names = regex!.GetGroupNames();
        foreach (var kv in dto.FieldMappings.Where(kv => !string.IsNullOrWhiteSpace(kv.Value)))
        {
            if (!SmsParsingEngine.Fields.Contains(kv.Key.ToLowerInvariant())) throw new ArgumentException($"Unknown field '{kv.Key}'.");
            if (!names.Contains(kv.Value)) throw new ArgumentException($"Field '{kv.Key}' maps to group '{kv.Value}' which is not in the pattern.");
        }
        if (!dto.FieldMappings.TryGetValue("amount", out var amountGroup) || string.IsNullOrWhiteSpace(amountGroup))
            throw new ArgumentException("An 'amount' field mapping is required.");

        BankSmsRule? rule = id.HasValue ? await _db.BankSmsRules.FirstOrDefaultAsync(r => r.Id == id.Value) : null;
        if (id.HasValue && rule == null) throw new KeyNotFoundException("Rule not found.");

        var isNew = rule == null;
        rule ??= new BankSmsRule();

        var changed = isNew || rule.Pattern != dto.Pattern ||
                      rule.FieldMappings != JsonSerializer.Serialize(dto.FieldMappings, Json) ||
                      rule.DebitKeywords != dto.DebitKeywords || rule.CreditKeywords != dto.CreditKeywords ||
                      rule.DefaultType != dto.DefaultType || rule.DateFormats != dto.DateFormats ||
                      rule.SenderIds != dto.SenderIds || rule.DefaultCurrency != dto.DefaultCurrency;

        rule.BankName = dto.BankName.Trim();
        rule.BankCode = string.IsNullOrWhiteSpace(dto.BankCode)
            ? rule.BankName.ToUpperInvariant().Replace(' ', '_') : dto.BankCode.Trim();
        rule.SenderIds = string.Join(",", SplitSenders(dto.SenderIds));
        rule.Pattern = dto.Pattern;
        rule.FieldMappings = JsonSerializer.Serialize(dto.FieldMappings, Json);
        rule.DebitKeywords = dto.DebitKeywords ?? string.Empty;
        rule.CreditKeywords = dto.CreditKeywords ?? string.Empty;
        rule.DefaultType = (dto.DefaultType ?? string.Empty).Trim().ToUpperInvariant();
        rule.DefaultCurrency = string.IsNullOrWhiteSpace(dto.DefaultCurrency) ? "OMR" : dto.DefaultCurrency.Trim().ToUpperInvariant();
        rule.DateFormats = dto.DateFormats ?? string.Empty;
        rule.SampleMessage = dto.SampleMessage ?? string.Empty;
        rule.IsActive = dto.IsActive;
        rule.UpdatedAt = DateTimeOffset.UtcNow;
        rule.UpdatedBy = changedBy;

        if (isNew) { rule.Version = 1; rule.CreatedAt = DateTimeOffset.UtcNow; _db.BankSmsRules.Add(rule); }
        else if (changed) rule.Version += 1;

        if (changed) _db.BankSmsRuleVersions.Add(Snapshot(rule, changedBy));
        await _db.SaveChangesAsync();
        return ToDto(rule);
    }

    public async Task<bool> SetActiveAsync(Guid id, bool active, string? changedBy)
    {
        var rule = await _db.BankSmsRules.FirstOrDefaultAsync(r => r.Id == id);
        if (rule == null) return false;
        rule.IsActive = active;
        rule.UpdatedAt = DateTimeOffset.UtcNow;
        rule.UpdatedBy = changedBy;
        await _db.SaveChangesAsync();
        return true;
    }

    public async Task<bool> DeleteRuleAsync(Guid id)
    {
        var rule = await _db.BankSmsRules.FirstOrDefaultAsync(r => r.Id == id);
        if (rule == null) return false;
        _db.BankSmsRules.Remove(rule);
        await _db.SaveChangesAsync();
        return true;
    }

    public async Task<List<SmsLogDto>> GetLogsAsync(int take)
    {
        take = Math.Clamp(take, 1, 500);
        var rows = await _db.SmsProcessingLogs.ToListAsync();
        return rows.OrderByDescending(l => l.CreatedAt).Take(take).Select(l => new SmsLogDto
        {
            Id = l.Id, Sender = l.Sender, RawMessage = l.RawMessage, Status = l.Status, Details = l.Details,
            ExtractedJson = l.ExtractedJson, RuleId = l.RuleId, RuleVersion = l.RuleVersion,
            TransactionId = l.TransactionId, CreatedAt = l.CreatedAt
        }).ToList();
    }

    public async Task<SmsReprocessResultDto> ReprocessLogsAsync(Guid? logId = null)
    {
        var result = new SmsReprocessResultDto();
        var query = _db.SmsProcessingLogs.AsQueryable();
        if (logId.HasValue)
        {
            query = query.Where(l => l.Id == logId.Value);
        }
        else
        {
            query = query.Where(l => l.Status != "Saved");
        }

        var logs = await query.OrderBy(l => l.ReceivedAt).ToListAsync();
        result.Total = logs.Count;

        var allRules = await _db.BankSmsRules.Where(r => r.IsActive).ToListAsync();

        foreach (var entry in logs)
        {
            try
            {
                var sender = (entry.Sender ?? string.Empty).Trim();
                var message = SmsParsingEngine.Normalize(entry.RawMessage);
                var received = entry.ReceivedAt;

                var rules = allRules
                    .Where(r => SenderMatches(r.SenderIds, sender))
                    .OrderByDescending(r => r.UpdatedAt)
                    .ToList();

                if (rules.Count == 0)
                {
                    entry.Status = "NoRule";
                    entry.Details = $"No active rule for sender '{sender}'.";
                    result.Skipped++;
                    continue;
                }

                BankSmsRule? used = null;
                SmsRuleTestResultDto? parsed = null;
                foreach (var r in rules)
                {
                    var res = SmsParsingEngine.Run(ToDto(r), message, received);
                    if (res.Matched) { used = r; parsed = res; break; }
                }

                if (used == null || parsed?.Extracted == null)
                {
                    entry.Status = "NoMatch";
                    entry.Details = "Message did not match any active rule for this sender.";
                    result.NoMatch++;
                    continue;
                }

                var ex = parsed.Extracted;
                var invalid = SmsParsingEngine.Validate(ex);
                if (invalid != null)
                {
                    entry.Status = "ValidationFailed";
                    entry.Details = invalid;
                    result.Errors++;
                    continue;
                }

                entry.RuleId = used.Id;
                entry.RuleVersion = used.Version;
                entry.ExtractedJson = JsonSerializer.Serialize(ex, Json);
                entry.Reference = Truncate(ex.Reference, 128);

                // Duplicate check
                if (!string.IsNullOrEmpty(ex.Reference) &&
                    await _db.SmsProcessingLogs.AnyAsync(l => l.UserId == entry.UserId && l.RuleId == used.Id && l.Reference == ex.Reference && l.Status == "Saved" && l.Id != entry.Id))
                {
                    entry.Status = "Duplicate";
                    entry.Details = $"Reference {ex.Reference} already processed.";
                    result.Skipped++;
                    continue;
                }

                var (merchantId, narration) = await MatchMerchantAsync(ex, message);

                var txId = await _notifications.ConfirmAndSaveNotificationAsync(new ConfirmNotificationRequestDto
                {
                    UserId = entry.UserId,
                    Transaction = new ParsedNotificationResultDto
                    {
                        BankName = used.BankName,
                        SourceType = "SMS",
                        Amount = ex.Amount,
                        Currency = ex.Currency,
                        Direction = ex.Type,
                        Narration = narration,
                        TransactionDate = ex.Date ?? received,
                        BalanceAfter = ex.Balance,
                        MatchedMerchantId = merchantId
                    }
                });

                var tx = await _db.PfmTransactions.FirstOrDefaultAsync(t => t.Id == txId);
                if (tx != null)
                {
                    tx.BankName = used.BankName;
                    if (!string.IsNullOrWhiteSpace(used.BankCode)) tx.BankCode = used.BankCode;
                    await _db.SaveChangesAsync();
                }

                entry.TransactionId = txId;
                entry.Status = "Saved";
                entry.Details = "Transaction saved (reprocessed).";
                result.Saved++;
                result.Details.Add($"Log {entry.Id}: Saved as transaction {txId} ({ex.Amount} {ex.Currency} at {narration}).");
            }
            catch (Exception e)
            {
                entry.Status = "Error";
                entry.Details = "Reprocess error: " + e.Message;
                result.Errors++;
                result.Details.Add($"Log {entry.Id} error: {e.Message}");
            }
        }

        await _db.SaveChangesAsync();
        return result;
    }

    // ───────────────────────── helpers ─────────────────────────

    private static BankSmsRuleVersion Snapshot(BankSmsRule r, string? by) => new()
    {
        RuleId = r.Id, Version = r.Version, ChangedBy = by,
        Snapshot = JsonSerializer.Serialize(ToDto(r), Json)
    };

    private static BankSmsRuleDto ToDto(BankSmsRule r)
    {
        Dictionary<string, string> map;
        try { map = JsonSerializer.Deserialize<Dictionary<string, string>>(r.FieldMappings, Json) ?? new(); }
        catch { map = new(); }
        return new BankSmsRuleDto
        {
            Id = r.Id, BankName = r.BankName, BankCode = r.BankCode, SenderIds = r.SenderIds, Pattern = r.Pattern,
            FieldMappings = map, DebitKeywords = r.DebitKeywords, CreditKeywords = r.CreditKeywords,
            DefaultType = r.DefaultType, DefaultCurrency = r.DefaultCurrency, DateFormats = r.DateFormats,
            SampleMessage = r.SampleMessage, IsActive = r.IsActive, Version = r.Version,
            UpdatedAt = r.UpdatedAt, UpdatedBy = r.UpdatedBy
        };
    }

    private static List<string> SplitSenders(string csv) =>
        (csv ?? string.Empty).Split(new[] { ',', ';', '\n' }, StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries)
            .Distinct(StringComparer.OrdinalIgnoreCase).ToList();

    private static bool SenderMatches(string csv, string sender) =>
        SplitSenders(csv).Any(s => string.Equals(s, sender, StringComparison.OrdinalIgnoreCase));

    private static string Hash(Guid userId, string sender, string message)
    {
        var bytes = SHA256.HashData(Encoding.UTF8.GetBytes($"{userId}|{sender.Trim().ToLowerInvariant()}|{message}"));
        return Convert.ToHexString(bytes);
    }

    private static string? Truncate(string? s, int max) => s == null ? null : (s.Length <= max ? s : s[..max]);
}
