using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Text.RegularExpressions;
using ThemarIP.Application.DTOs.Sms;

namespace ThemarIP.Infrastructure.Services.Sms;

/// <summary>
/// Pure, stateless rule-driven extraction. No bank formats live in code:
/// the regex, group mapping, keywords and date formats all come from a rule.
/// </summary>
public static class SmsParsingEngine
{
    private static readonly TimeSpan RegexTimeout = TimeSpan.FromSeconds(1);

    public static readonly string[] Fields = { "amount", "type", "merchant", "narration", "reference", "date", "balance", "currency" };

    public static bool TryCompile(string pattern, out Regex? regex, out string? error)
    {
        regex = null; error = null;
        if (string.IsNullOrWhiteSpace(pattern)) { error = "Pattern is required."; return false; }
        try
        {
            regex = new Regex(pattern, RegexOptions.IgnoreCase | RegexOptions.CultureInvariant | RegexOptions.Singleline, RegexTimeout);
            return true;
        }
        catch (ArgumentException ex) { error = "Invalid regex: " + ex.Message; return false; }
    }

    public static string Normalize(string s) => Regex.Replace(s ?? string.Empty, @"\s+", " ").Trim();

    public static SmsRuleTestResultDto Run(BankSmsRuleDto rule, string message, DateTimeOffset? fallbackDate = null)
    {
        var result = new SmsRuleTestResultDto();
        if (!TryCompile(rule.Pattern, out var regex, out var err)) { result.Errors.Add(err!); return result; }
        result.PatternValid = true;

        // Mappings must refer to groups that exist in the pattern.
        var groupNames = regex!.GetGroupNames();
        foreach (var kv in rule.FieldMappings.Where(kv => !string.IsNullOrWhiteSpace(kv.Value)))
        {
            if (!Fields.Contains(kv.Key.ToLowerInvariant())) result.Errors.Add($"Unknown field '{kv.Key}'.");
            else if (!groupNames.Contains(kv.Value)) result.Errors.Add($"Field '{kv.Key}' maps to group '{kv.Value}' which is not defined in the pattern.");
        }

        Match m;
        var text = Normalize(message);
        try { m = regex.Match(text); }
        catch (RegexMatchTimeoutException) { result.Errors.Add("Pattern timed out (too expensive)."); return result; }

        if (!m.Success) return result;
        result.Matched = true;

        foreach (var name in groupNames.Where(n => !int.TryParse(n, out _)))
            result.Groups[name] = m.Groups[name].Success ? m.Groups[name].Value : null;

        string? G(string field)
        {
            if (!rule.FieldMappings.TryGetValue(field, out var grp) || string.IsNullOrWhiteSpace(grp)) return null;
            var g = m.Groups[grp];
            return g.Success && !string.IsNullOrWhiteSpace(g.Value) ? g.Value.Trim() : null;
        }

        var ex = new SmsExtractedDto
        {
            Currency = (G("currency") ?? rule.DefaultCurrency ?? "OMR").ToUpperInvariant(),
            Merchant = G("merchant")?.TrimEnd('.', ',', ' '),
            Narration = G("narration")?.TrimEnd('.', ',', ' '),
            Reference = G("reference"),
        };

        var amountRaw = G("amount");
        if (amountRaw != null && TryDecimal(amountRaw, out var amt)) ex.Amount = amt;
        else if (amountRaw != null) result.Errors.Add($"Could not read amount '{amountRaw}'.");

        var balRaw = G("balance");
        if (balRaw != null && TryDecimal(balRaw, out var bal)) ex.Balance = bal;

        ex.Type = ResolveType(rule, G("type") ?? text);
        ex.Date = ParseDate(G("date"), rule.DateFormats) ?? fallbackDate;

        result.Extracted = ex;
        return result;
    }

    /// <summary>
    /// Tries every pattern grouped under the rule (in order) and returns the first match,
    /// together with the pattern that matched. Returns (null, null) when nothing matches.
    /// </summary>
    public static (SmsRuleTestResultDto? Result, SmsPatternDto? Pattern) RunAny(BankSmsRuleDto rule, string message, DateTimeOffset? fallbackDate = null)
    {
        foreach (var p in EffectivePatterns(rule))
        {
            var res = Run(ForPattern(rule, p), message, fallbackDate);
            if (res.Matched) return (res, p);
        }
        return (null, null);
    }

    /// <summary>The rule's pattern list, or its single legacy pattern when the list is empty.</summary>
    public static List<SmsPatternDto> EffectivePatterns(BankSmsRuleDto rule)
    {
        var list = (rule.Patterns ?? new()).Where(p => !string.IsNullOrWhiteSpace(p.Pattern)).ToList();
        if (list.Count > 0) return list;
        return new List<SmsPatternDto>
        {
            new() { Name = string.Empty, Pattern = rule.Pattern, FieldMappings = rule.FieldMappings ?? new(), SampleMessage = rule.SampleMessage, DefaultType = string.Empty }
        };
    }

    /// <summary>A single-pattern copy of the rule (bank-level keywords, currency and date formats are shared).</summary>
    public static BankSmsRuleDto ForPattern(BankSmsRuleDto rule, SmsPatternDto p) => new()
    {
        Id = rule.Id, BankName = rule.BankName, BankCode = rule.BankCode, SenderIds = rule.SenderIds,
        Pattern = p.Pattern, FieldMappings = p.FieldMappings ?? new(), SampleMessage = p.SampleMessage,
        DebitKeywords = rule.DebitKeywords, CreditKeywords = rule.CreditKeywords,
        DefaultType = string.IsNullOrWhiteSpace(p.DefaultType) ? rule.DefaultType : p.DefaultType,
        DefaultCurrency = rule.DefaultCurrency, DateFormats = rule.DateFormats,
        IsActive = rule.IsActive, Version = rule.Version
    };

    /// <summary>Validation of an extraction. Returns error text or null if OK.</summary>
    public static string? Validate(SmsExtractedDto? ex)
    {
        if (ex == null) return "Nothing extracted.";
        if (ex.Amount <= 0) return "Amount missing or not positive.";
        if (ex.Amount > 100_000_000m) return "Amount is implausibly large.";
        if (ex.Type != "DEBIT" && ex.Type != "CREDIT") return "Could not determine debit/credit.";
        return null;
    }

    private static string ResolveType(BankSmsRuleDto rule, string source)
    {
        // The earliest keyword in the text wins when both debit and credit words appear.
        var d = FirstIndex(rule.DebitKeywords, source);
        var c = FirstIndex(rule.CreditKeywords, source);
        if (d >= 0 && (c < 0 || d <= c)) return "DEBIT";
        if (c >= 0) return "CREDIT";

        var def = (rule.DefaultType ?? string.Empty).Trim().ToUpperInvariant();
        return def is "DEBIT" or "CREDIT" ? def : string.Empty;
    }

    private static int FirstIndex(string csv, string text)
    {
        var best = -1;
        foreach (var k in (csv ?? string.Empty).Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries))
        {
            var i = text.IndexOf(k, StringComparison.OrdinalIgnoreCase);
            if (i >= 0 && (best < 0 || i < best)) best = i;
        }
        return best;
    }

    private static bool TryDecimal(string raw, out decimal value)
    {
        var s = Regex.Replace(raw, @"[^\d.,\-]", "");
        // 1,234.500 -> thousands comma; 12,500 (3 decimals, no dot) is treated as thousands too (OMR uses '.').
        s = s.Replace(",", "");
        return decimal.TryParse(s, NumberStyles.Number, CultureInfo.InvariantCulture, out value);
    }

    private static DateTimeOffset? ParseDate(string? raw, string formats)
    {
        if (string.IsNullOrWhiteSpace(raw)) return null;
        var fmts = (formats ?? string.Empty).Split('|', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);
        if (fmts.Length > 0 &&
            DateTime.TryParseExact(raw.Trim(), fmts, CultureInfo.InvariantCulture, DateTimeStyles.AssumeLocal, out var exact))
            return new DateTimeOffset(exact);
        if (DateTime.TryParse(raw.Trim(), CultureInfo.InvariantCulture, DateTimeStyles.AssumeLocal, out var loose))
            return new DateTimeOffset(loose);
        return null;
    }
}
