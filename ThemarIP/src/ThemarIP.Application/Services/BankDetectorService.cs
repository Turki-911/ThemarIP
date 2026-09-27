using System;
using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;
using ThemarIP.Application.Common.Interfaces;
using ThemarIP.Domain.Entities;

namespace ThemarIP.Application.Services;

public interface IBankDetectorService
{
    Task<string> DetectBankFormatAsync(List<string> lines, CancellationToken cancellationToken = default);
}

public class BankDetectorService : IBankDetectorService
{
    private readonly IApplicationDbContext _context;

    public BankDetectorService(IApplicationDbContext context)
    {
        _context = context;
    }

    public async Task<string> DetectBankFormatAsync(List<string> lines, CancellationToken cancellationToken = default)
    {
        var fullContent = string.Join(" ", lines).ToLower();

        if (fullContent.Contains("bank muscat") || fullContent.Contains("bm"))
        {
            return "Bank Muscat";
        }
        if (fullContent.Contains("national bank of oman") || fullContent.Contains("nbo"))
        {
            return "NBO";
        }
        if (fullContent.Contains("sohar international") || fullContent.Contains("bank sohar"))
        {
            return "Sohar International";
        }
        if (fullContent.Contains("bank dhofar") || fullContent.Contains("dhofar"))
        {
            return "Bank Dhofar";
        }
        if (fullContent.Contains("ahli bank") || fullContent.Contains("ahlibank"))
        {
            return "Ahli Bank";
        }
        if (fullContent.Contains("oman arab bank") || fullContent.Contains("oab"))
        {
            return "OAB";
        }

        // Unknown bank format - Log system warning
        var log = new SystemLog
        {
            LogLevel = "Warning",
            Message = "Unknown bank statement format detected. Continuing with generic fallback statement parser.",
            Source = nameof(BankDetectorService),
            CreatedAt = DateTimeOffset.UtcNow
        };
        _context.SystemLogs.Add(log);
        await _context.SaveChangesAsync(cancellationToken);

        return "Unknown";
    }
}
