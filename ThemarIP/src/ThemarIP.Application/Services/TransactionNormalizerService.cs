using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Text.RegularExpressions;
using System.Threading;
using System.Threading.Tasks;
using Microsoft.EntityFrameworkCore;
using ThemarIP.Application.Common.Interfaces;
using ThemarIP.Domain.Entities;

namespace ThemarIP.Application.Services;

public interface ITransactionNormalizerService
{
    DateTimeOffset NormalizeDate(string rawDate);
    decimal NormalizeAmount(string rawAmount);
    string ExtractMerchant(string rawDescription);
    Task<(string category, string mccCode)> CategorizeAsync(string merchant, string description, CancellationToken cancellationToken = default);
}

public class TransactionNormalizerService : ITransactionNormalizerService
{
    private readonly IApplicationDbContext _context;

    private static readonly string[] DateFormats = new[]
    {
        "dd MMM yyyy", "dd-MMM-yyyy", "dd/MM/yyyy", "dd/MM/yy",
        "yyyy-MM-dd", "dd-MM-yyyy", "dd.MM.yyyy", "yyyy/MM/dd"
    };

    public TransactionNormalizerService(IApplicationDbContext context)
    {
        _context = context;
    }

    public DateTimeOffset NormalizeDate(string rawDate)
    {
        if (string.IsNullOrWhiteSpace(rawDate)) return DateTimeOffset.UtcNow;
        var cleaned = rawDate.Trim();

        if (DateTimeOffset.TryParseExact(cleaned, DateFormats, CultureInfo.InvariantCulture, DateTimeStyles.AssumeUniversal, out var parsedExact))
        {
            return parsedExact;
        }

        if (DateTimeOffset.TryParse(cleaned, CultureInfo.InvariantCulture, DateTimeStyles.AssumeUniversal, out var parsedAny))
        {
            return parsedAny;
        }

        return DateTimeOffset.UtcNow;
    }

    public decimal NormalizeAmount(string rawAmount)
    {
        if (string.IsNullOrWhiteSpace(rawAmount)) return 0.0m;

        // Strip OMR, USD, AED, currency symbols, and commas
        var cleaned = Regex.Replace(rawAmount, @"[^\d.-]", "").Trim();

        if (decimal.TryParse(cleaned, NumberStyles.Any, CultureInfo.InvariantCulture, out var amount))
        {
            return Math.Abs(amount);
        }

        return 0.0m;
    }

    public string ExtractMerchant(string rawDescription)
    {
        if (string.IsNullOrWhiteSpace(rawDescription)) return "Merchant Transaction";

        var upper = rawDescription.ToUpper().Trim();

        // Common location/suffix cleanups
        string[] suffixes = new[]
        {
            " MUSCAT", " AL KHUWAIR", " SEEB", " RUWI", " QURUM", " HYPERMARKET",
            " SUPERMARKET", " SERVICE STATION", " ONLINE", " STORE", " OMAN", " BRANCH"
        };

        foreach (var suffix in suffixes)
        {
            if (upper.EndsWith(suffix))
            {
                upper = upper.Substring(0, upper.Length - suffix.Length).Trim();
            }
        }

        return upper;
    }

    public async Task<(string category, string mccCode)> CategorizeAsync(string merchant, string description, CancellationToken cancellationToken = default)
    {
        var rules = await _context.CategoryRules
            .Where(r => r.IsActive)
            .OrderBy(r => r.Priority)
            .ToListAsync(cancellationToken);

        var searchText = $"{merchant} {description}".ToUpper();

        foreach (var rule in rules)
        {
            if (searchText.Contains(rule.Keyword.ToUpper()))
            {
                return (rule.Category, rule.MccCode ?? "5311");
            }
        }

        return ("Other", "5311");
    }
}
