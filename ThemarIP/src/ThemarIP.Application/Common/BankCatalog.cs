using System;
using System.Collections.Generic;
using System.Linq;

namespace ThemarIP.Application.Common;

/// <summary>
/// Single source of truth for the banks shown to customers. Any variation of a bank name/code
/// (legacy per-pattern rule names such as "Bank Muscat - Credit Card" or "BM-Credit Card")
/// resolves to the canonical (Code, Name) pair used by the mobile app's bank list.
/// </summary>
public static class BankCatalog
{
    public sealed record Bank(string Code, string Name, string[] Aliases);

    public static readonly IReadOnlyList<Bank> All = new List<Bank>
    {
        new("BANK_MUSCAT",   "Bank Muscat",           new[] { "bank muscat", "bankmuscat", "bm", "bm-", "bank_muscat" }),
        new("NBO",           "National Bank of Oman", new[] { "national bank of oman", "nbo" }),
        new("BANK_DHOFAR",   "Bank Dhofar",           new[] { "bank dhofar", "bankdhofar", "dhofar" }),
        new("OAB",           "Oman Arab Bank",        new[] { "oman arab bank", "oab" }),
        new("SOHAR_INTL",    "Sohar International",   new[] { "sohar international", "sohar" }),
        new("AHLI_BANK",     "Ahli Bank Oman",        new[] { "ahli bank oman", "ahli bank", "ahli" }),
        new("BANK_NIZWA",    "Bank Nizwa",            new[] { "bank nizwa", "nizwa" }),
        new("ALIZZ_ISLAMIC", "Alizz Islamic Bank",    new[] { "alizz islamic bank", "alizz" }),
    };

    /// <summary>Resolves a bank from a code and/or name. Returns null when it is not a known bank.</summary>
    public static Bank? Find(string? codeOrName, string? name = null)
    {
        foreach (var raw in new[] { codeOrName, name })
        {
            var t = (raw ?? string.Empty).Trim();
            if (t.Length == 0) continue;

            var exact = All.FirstOrDefault(b =>
                string.Equals(b.Code, t, StringComparison.OrdinalIgnoreCase) ||
                string.Equals(b.Name, t, StringComparison.OrdinalIgnoreCase) ||
                b.Aliases.Any(a => string.Equals(a, t, StringComparison.OrdinalIgnoreCase)));
            if (exact != null) return exact;

            var lower = t.ToLowerInvariant().Replace('_', ' ');
            // Prefix match handles legacy names like "Bank Muscat - Credit Card", "BM-Credit Card", "BANK_MUSCAT_DEBIT".
            var prefix = All.FirstOrDefault(b =>
                lower.StartsWith(b.Name.ToLowerInvariant()) ||
                lower.StartsWith(b.Code.ToLowerInvariant().Replace('_', ' ')) ||
                b.Aliases.Any(a => a.EndsWith("-") && lower.StartsWith(a)));
            if (prefix != null) return prefix;
        }
        return null;
    }

    /// <summary>Canonical (code, name). Unknown banks keep their own name with a derived code.</summary>
    public static (string Code, string Name) Canonical(string? code, string? name)
    {
        var b = Find(code, name);
        if (b != null) return (b.Code, b.Name);
        var n = string.IsNullOrWhiteSpace(name) ? (code ?? "Bank Muscat").Trim() : name.Trim();
        var c = string.IsNullOrWhiteSpace(code) ? n.ToUpperInvariant().Replace(' ', '_') : code.Trim();
        return (c, n);
    }

    /// <summary>Splits a user's stored selection ("Bank Muscat, National Bank of Oman") into canonical banks.</summary>
    public static List<(string Code, string Name)> ParseSelection(string? csv) =>
        (csv ?? string.Empty)
            .Split(new[] { ',', ';' }, StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries)
            .Select(s => Canonical(null, s))
            .GroupBy(b => b.Code, StringComparer.OrdinalIgnoreCase)
            .Select(g => g.First())
            .ToList();

    /// <summary>True when a rule (by its code/name) belongs to one of the selected canonical bank codes.</summary>
    public static bool IsSelected(string? ruleCode, string? ruleName, IEnumerable<(string Code, string Name)> selection)
    {
        var rc = Canonical(ruleCode, ruleName).Code;
        return selection.Any(s => string.Equals(s.Code, rc, StringComparison.OrdinalIgnoreCase));
    }
}
