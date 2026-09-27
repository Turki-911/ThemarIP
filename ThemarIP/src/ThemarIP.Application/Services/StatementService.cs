using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using Microsoft.EntityFrameworkCore;
using ThemarIP.Application.Common.Interfaces;
using ThemarIP.Application.DTOs;
using ThemarIP.Domain.Entities;
using ThemarIP.Domain.Enums;

namespace ThemarIP.Application.Services;

public interface IStatementService
{
    Task<StatementUploadDto> UploadStatementAsync(Guid userId, UploadStatementRequestDto request, CancellationToken cancellationToken = default);
    Task<List<StatementUploadDto>> GetStatementsForUserAsync(Guid userId, CancellationToken cancellationToken = default);
    Task<StatementUploadDto?> GetStatementByIdAsync(Guid userId, Guid statementId, CancellationToken cancellationToken = default);
    Task<StatementUploadDto> FetchFromNboAsync(Guid userId, FetchNboStatementRequestDto request, CancellationToken cancellationToken = default);
}

public class StatementService : IStatementService
{
    private readonly IApplicationDbContext _context;
    private readonly IPdfExtractorService _pdfExtractor;
    private readonly IBankDetectorService _bankDetector;
    private readonly ITransactionNormalizerService _normalizer;
    private readonly INboApiService _nboApiService;

    public StatementService(
        IApplicationDbContext context,
        IPdfExtractorService pdfExtractor,
        IBankDetectorService bankDetector,
        ITransactionNormalizerService normalizer,
        INboApiService nboApiService)
    {
        _context = context;
        _pdfExtractor = pdfExtractor;
        _bankDetector = bankDetector;
        _normalizer = normalizer;
        _nboApiService = nboApiService;
    }

    public async Task<StatementUploadDto> UploadStatementAsync(Guid userId, UploadStatementRequestDto request, CancellationToken cancellationToken = default)
    {
        var stopwatch = Stopwatch.StartNew();

        var userExists = await _context.Users.AnyAsync(u => u.Id == userId, cancellationToken);
        if (!userExists)
        {
            throw new KeyNotFoundException("User account not found. Please log out and sign in again.");
        }

        var statement = new StatementUpload
        {
            UserId = userId,
            FileName = request.FileName,
            FileSize = request.FileSize,
            Status = StatementStatus.Pending,
            UploadedAt = DateTimeOffset.UtcNow
        };

        _context.StatementUploads.Add(statement);
        await _context.SaveChangesAsync(cancellationToken);

        var logEntries = new List<string>();
        logEntries.Add($"[{DateTimeOffset.UtcNow:yyyy-MM-dd HH:mm:ss}] Started processing statement document: {request.FileName}");

        // 1. Extract Text Lines (Line-by-line exact extraction, No AI)
        List<string> lines;
        var ext = Path.GetExtension(request.FileName).ToLower();

        if (ext == ".pdf" && !string.IsNullOrEmpty(request.FilePath))
        {
            lines = _pdfExtractor.ExtractLines(request.FilePath);
            logEntries.Add($"[{DateTimeOffset.UtcNow:yyyy-MM-dd HH:mm:ss}] PDF Text Extractor extracted {lines.Count} exact lines.");
        }
        else if (!string.IsNullOrEmpty(request.FilePath) && File.Exists(request.FilePath))
        {
            lines = (await File.ReadAllLinesAsync(request.FilePath, cancellationToken)).ToList();
            logEntries.Add($"[{DateTimeOffset.UtcNow:yyyy-MM-dd HH:mm:ss}] File Reader extracted {lines.Count} lines.");
        }
        else
        {
            lines = new List<string>();
            logEntries.Add($"[{DateTimeOffset.UtcNow:yyyy-MM-dd HH:mm:ss}] No physical file attached or file content empty.");
        }

        // 2. Detect Bank Format
        var detectedBank = await _bankDetector.DetectBankFormatAsync(lines, cancellationToken);
        statement.DetectedBank = detectedBank;
        logEntries.Add($"[{DateTimeOffset.UtcNow:yyyy-MM-dd HH:mm:ss}] Detected Bank Format: {detectedBank}");

        // 3. Extract & Normalize Transactions using DB Category Engine Rules
        var parsedTransactions = await ProcessAndCategorizeLinesAsync(statement.Id, userId, lines, logEntries, cancellationToken);

        if (parsedTransactions.Count > 0)
        {
            _context.Transactions.AddRange(parsedTransactions);
            statement.Status = StatementStatus.Processed;
            logEntries.Add($"[{DateTimeOffset.UtcNow:yyyy-MM-dd HH:mm:ss}] Successfully extracted {parsedTransactions.Count} transactions into database.");
        }
        else
        {
            statement.Status = StatementStatus.Processed;
            statement.ValidationWarnings = "No transactions were detected in this document.";
            logEntries.Add($"[{DateTimeOffset.UtcNow:yyyy-MM-dd HH:mm:ss}] WARNING: No valid transactions extracted from document. Zero fake or sample records generated.");
        }

        stopwatch.Stop();
        statement.ProcessingDurationMs = stopwatch.ElapsedMilliseconds;
        statement.Logs = string.Join("\n", logEntries);

        await _context.SaveChangesAsync(cancellationToken);

        return new StatementUploadDto(
            statement.Id,
            statement.UserId,
            statement.FileName,
            statement.FileSize,
            statement.Status,
            statement.UploadedAt,
            parsedTransactions.Count,
            statement.DetectedBank,
            statement.ProcessingDurationMs,
            statement.ValidationWarnings,
            statement.Logs,
            statement.AccountNumber,
            statement.Source
        );
    }

    private async Task<List<Transaction>> ProcessAndCategorizeLinesAsync(
        Guid statementId,
        Guid userId,
        List<string> lines,
        List<string> logs,
        CancellationToken cancellationToken)
    {
        var transactions = new List<Transaction>();
        var now = DateTimeOffset.UtcNow;

        foreach (var line in lines)
        {
            if (string.IsNullOrWhiteSpace(line) || line.StartsWith("Date", StringComparison.OrdinalIgnoreCase))
                continue;

            var parts = line.Split(new[] { ',', '\t', ';' }, StringSplitOptions.RemoveEmptyEntries);
            if (parts.Length >= 3)
            {
                var rawDate = parts[0].Trim();
                var rawDesc = parts.Length > 2 ? parts[1].Trim() : "Card Transaction";
                var rawAmount = parts[parts.Length - 1].Trim();

                var normDate = _normalizer.NormalizeDate(rawDate);
                var normAmount = _normalizer.NormalizeAmount(rawAmount);
                var merchant = _normalizer.ExtractMerchant(rawDesc);

                if (normAmount > 0)
                {
                    var (category, mcc) = await _normalizer.CategorizeAsync(merchant, rawDesc, cancellationToken);

                    transactions.Add(new Transaction
                    {
                        Id = Guid.NewGuid(),
                        StatementUploadId = statementId,
                        UserId = userId,
                        TransactionDate = normDate,
                        Amount = normAmount,
                        Currency = "OMR",
                        Category = category,
                        Description = merchant,
                        MccCode = mcc,
                        CreatedAt = now
                    });
                }
                else
                {
                    logs.Add($"[{DateTimeOffset.UtcNow:yyyy-MM-dd HH:mm:ss}] Skipped line due to invalid amount (0.00): '{line}'");
                }
            }
        }

        // STRICT REGULATED FINTECH COMPLIANCE:
        // Do NOT generate sample / fake transactions if 0 transactions were parsed!
        return transactions;
    }

    public async Task<List<StatementUploadDto>> GetStatementsForUserAsync(Guid userId, CancellationToken cancellationToken = default)
    {
        var statements = await _context.StatementUploads
            .Where(s => s.UserId == userId)
            .Select(s => new StatementUploadDto(
                s.Id,
                s.UserId,
                s.FileName,
                s.FileSize,
                s.Status,
                s.UploadedAt,
                s.Transactions.Count,
                s.DetectedBank,
                s.ProcessingDurationMs,
                s.ValidationWarnings,
                s.Logs,
                s.AccountNumber,
                s.Source
            ))
            .ToListAsync(cancellationToken);

        return statements.OrderByDescending(s => s.UploadedAt).ToList();
    }

    public async Task<StatementUploadDto?> GetStatementByIdAsync(Guid userId, Guid statementId, CancellationToken cancellationToken = default)
    {
        return await _context.StatementUploads
            .Where(s => s.Id == statementId && s.UserId == userId)
            .Select(s => new StatementUploadDto(
                s.Id,
                s.UserId,
                s.FileName,
                s.FileSize,
                s.Status,
                s.UploadedAt,
                s.Transactions.Count,
                s.DetectedBank,
                s.ProcessingDurationMs,
                s.ValidationWarnings,
                s.Logs,
                s.AccountNumber,
                s.Source
            ))
            .FirstOrDefaultAsync(cancellationToken);
    }

    public async Task<StatementUploadDto> FetchFromNboAsync(Guid userId, FetchNboStatementRequestDto request, CancellationToken cancellationToken = default)
    {
        var stopwatch = Stopwatch.StartNew();

        var userExists = await _context.Users.AnyAsync(u => u.Id == userId, cancellationToken);
        if (!userExists)
        {
            throw new KeyNotFoundException("User account not found. Please log out and sign in again.");
        }

        var statement = new StatementUpload
        {
            UserId = userId,
            FileName = $"NBO_Fetch_{request.AccountNumber}_{request.FromDate}_{request.ToDate}",
            FileSize = 0,
            Status = StatementStatus.Pending,
            UploadedAt = DateTimeOffset.UtcNow,
            Source = "NBO_API",
            DetectedBank = "NBO",
            AccountNumber = request.AccountNumber
        };

        _context.StatementUploads.Add(statement);
        await _context.SaveChangesAsync(cancellationToken);

        var logEntries = new List<string>();
        logEntries.Add($"[{DateTimeOffset.UtcNow:yyyy-MM-dd HH:mm:ss}] Started fetching from NBO API for account {request.AccountNumber}");

        try
        {
            var response = await _nboApiService.FetchAccountStatementAsync(request.AccountNumber, request.FromDate, request.ToDate, cancellationToken);
            var nboTransactions = response.Response?.Body?.AccountStatement;

            var transactions = new List<Transaction>();
            var now = DateTimeOffset.UtcNow;

            if (nboTransactions != null && nboTransactions.Count > 0)
            {
                foreach (var nboTx in nboTransactions)
                {
                    if (!DateTimeOffset.TryParseExact(nboTx.PostingDate, "ddMMyyyy", null, System.Globalization.DateTimeStyles.None, out var postingDate))
                    {
                        postingDate = now; // Fallback
                    }

                    // NBO amounts are fixed-width integers with 3 implied decimal places (OMR uses 3)
                    // E.g., " 0000000000050000000" = 50000.000, "-0000000000000019056" = -19.056
                    var amountStr = nboTx.TransactionAmount.Trim();
                    if (!long.TryParse(amountStr, out var amountRaw))
                    {
                        logEntries.Add($"[{DateTimeOffset.UtcNow:yyyy-MM-dd HH:mm:ss}] Skipped transaction due to invalid amount: {nboTx.TransactionAmount}");
                        continue;
                    }
                    var amount = (decimal)amountRaw / 1000m; // 3 decimal places for OMR

                    var rawDesc = $"{nboTx.Narration1} {nboTx.Narration2}".Trim();
                    if (string.IsNullOrEmpty(rawDesc)) rawDesc = nboTx.TransactionCodeDesc;
                    if (nboTx.TransactionType == "C") rawDesc = "(Credit) " + rawDesc;

                    var merchant = _normalizer.ExtractMerchant(rawDesc);
                    var (category, mcc) = await _normalizer.CategorizeAsync(merchant, rawDesc, cancellationToken);

                    transactions.Add(new Transaction
                    {
                        Id = Guid.NewGuid(),
                        StatementUploadId = statement.Id,
                        UserId = userId,
                        TransactionDate = postingDate,
                        Amount = amount,
                        Currency = string.IsNullOrEmpty(nboTx.TransactionCurrency) ? "OMR" : nboTx.TransactionCurrency,
                        Category = category,
                        Description = rawDesc,
                        MccCode = mcc,
                        CreatedAt = now
                    });
                }

                _context.Transactions.AddRange(transactions);
                statement.Status = StatementStatus.Processed;
                logEntries.Add($"[{DateTimeOffset.UtcNow:yyyy-MM-dd HH:mm:ss}] Successfully extracted {transactions.Count} transactions from NBO API.");
            }
            else
            {
                statement.Status = StatementStatus.Processed;
                statement.ValidationWarnings = "No transactions were found in the specified date range.";
                logEntries.Add($"[{DateTimeOffset.UtcNow:yyyy-MM-dd HH:mm:ss}] WARNING: No transactions returned by NBO API.");
            }
            
            stopwatch.Stop();
            statement.ProcessingDurationMs = stopwatch.ElapsedMilliseconds;
            statement.Logs = string.Join("\n", logEntries);
            
            await _context.SaveChangesAsync(cancellationToken);
            
            return new StatementUploadDto(
                statement.Id, statement.UserId, statement.FileName, statement.FileSize, statement.Status,
                statement.UploadedAt, transactions.Count, statement.DetectedBank, statement.ProcessingDurationMs,
                statement.ValidationWarnings, statement.Logs, statement.AccountNumber, statement.Source
            );
        }
        catch (Exception ex)
        {
            statement.Status = StatementStatus.Failed;
            statement.ValidationWarnings = "Failed to fetch from NBO API.";
            logEntries.Add($"[{DateTimeOffset.UtcNow:yyyy-MM-dd HH:mm:ss}] ERROR: {ex.Message}");
            stopwatch.Stop();
            statement.ProcessingDurationMs = stopwatch.ElapsedMilliseconds;
            statement.Logs = string.Join("\n", logEntries);
            await _context.SaveChangesAsync(cancellationToken);
            throw;
        }
    }
}
