using System;
using System.IO;
using System.Linq;
using System.Threading.Tasks;
using Microsoft.EntityFrameworkCore;
using ThemarIP.Application.Common.Interfaces;
using ThemarIP.Application.DTOs.Statements;
using ThemarIP.Application.Interfaces.Statements;
using ThemarIP.Domain.Entities.Pfm;

namespace ThemarIP.Infrastructure.Services.Statements;

public class StatementExtractionService : IStatementExtractionService
{
    private readonly IBankMuscatPdfParser _parser;
    private readonly IApplicationDbContext _context;

    public StatementExtractionService(IBankMuscatPdfParser parser, IApplicationDbContext context)
    {
        _parser = parser;
        _context = context;
    }

    public async Task<StatementResultDto> ProcessUploadAsync(Stream pdfStream)
    {
        // 1. Parse the PDF
        var result = _parser.ParsePdf(pdfStream);
        
        // 2. Identify the User based on Account Number (Schema Rule)
        Guid? userId = null;
        if (!string.IsNullOrEmpty(result.Header.AccountNumber))
        {
            var user = await _context.Users
                .FirstOrDefaultAsync(u => u.AccountNumber == result.Header.AccountNumber);
            if (user != null) userId = user.Id;
        }

        // 3. Check for duplicates in application logic (since we can't alter schema for UNIQUE constraints)
        if (userId.HasValue && result.Transactions.Any())
        {
            var existingTxns = await _context.PfmTransactions
                .Where(t => t.UserId == userId.Value)
                .Select(t => new { t.TransactionDate, t.Amount, t.BalanceAfter })
                .ToListAsync();

            foreach (var tx in result.Transactions)
            {
                var dtOffset = new DateTimeOffset(tx.PostDate, TimeSpan.Zero);
                var amount = tx.Amount > 0 ? tx.Amount : (tx.Debit ?? tx.Credit ?? 0);
                var balance = tx.Balance;

                bool exists = existingTxns.Any(e => 
                    e.TransactionDate.Date == dtOffset.Date && 
                    e.Amount == amount && 
                    e.BalanceAfter == balance);

                if (exists)
                {
                    tx.IsDuplicate = true;
                    tx.ValidationMessage = "Duplicate transaction found in database.";
                }
            }
        }

        return result;
    }

    public async Task<bool> ConfirmAndImportAsync(ConfirmStatementRequestDto request)
    {
        // Lookup user by explicit UserId if provided, otherwise by AccountNumber
        ThemarIP.Domain.Entities.User? user = null;
        if (request.UserId.HasValue)
        {
            user = await _context.Users.FirstOrDefaultAsync(u => u.Id == request.UserId.Value);
        }
        if (user == null && !string.IsNullOrWhiteSpace(request.Header.AccountNumber))
        {
            user = await _context.Users.FirstOrDefaultAsync(u => u.AccountNumber == request.Header.AccountNumber);
        }
        if (user == null) 
        {
            user = await _context.Users.FirstOrDefaultAsync();
            if (user == null) throw new Exception("No users found in database to link transactions.");
        }

        var validTransactions = request.Transactions
            .Where(t => t.IsBalanceValid && !t.IsDuplicate && t.ExtractionStatus != "FAILED")
            .ToList();

        var activeMerchants = await _context.PfmMerchants
            .Include(m => m.Aliases)
            .Where(m => m.IsActive)
            .ToListAsync();
        
        foreach (var tx in validTransactions)
        {
            var txDate = new DateTimeOffset(tx.PostDate, TimeSpan.Zero);
            var txAmount = tx.Amount > 0 ? tx.Amount : (tx.Debit ?? tx.Credit ?? 0);
            var txNarration = tx.Narration;

            // Application-level deduplication check against the live database
            bool alreadyExists = await _context.PfmTransactions.AnyAsync(t =>
                t.UserId == user.Id &&
                t.Narration == txNarration &&
                t.Amount == txAmount &&
                t.BalanceAfter == tx.Balance &&
                t.TransactionDate == txDate);

            if (alreadyExists)
            {
                continue; // Skip duplicate
            }

            var isCredit = string.Equals(tx.Direction, "CREDIT", StringComparison.OrdinalIgnoreCase) ||
                           (tx.Credit.HasValue && !tx.Debit.HasValue);

            Guid? matchedMerchantId = null;
            foreach (var m in activeMerchants)
            {
                if ((!string.IsNullOrWhiteSpace(m.Name) && txNarration.Contains(m.Name, StringComparison.OrdinalIgnoreCase)) ||
                    m.Aliases.Any(a => !string.IsNullOrWhiteSpace(a.AliasText) && txNarration.Contains(a.AliasText, StringComparison.OrdinalIgnoreCase)))
                {
                    matchedMerchantId = m.Id;
                    break;
                }
            }

            var pfmTx = new PfmTransaction
            {
                Id = Guid.NewGuid(),
                UserId = user.Id,
                MerchantId = matchedMerchantId,
                TransactionDate = txDate,
                Narration = txNarration,
                Amount = txAmount,
                TransactionType = isCredit ? ThemarIP.Domain.Enums.Pfm.TransactionType.Credit : ThemarIP.Domain.Enums.Pfm.TransactionType.Debit,
                BalanceAfter = tx.Balance,
                Currency = string.IsNullOrWhiteSpace(request.Header.Currency) ? "OMR" : request.Header.Currency,
                Status = matchedMerchantId.HasValue ? ThemarIP.Domain.Enums.Pfm.TransactionStatus.Categorized : ThemarIP.Domain.Enums.Pfm.TransactionStatus.Uncategorized,
                CreatedAt = DateTimeOffset.UtcNow,
                UpdatedAt = DateTimeOffset.UtcNow
            };
            
            _context.PfmTransactions.Add(pfmTx);
        }

        await _context.SaveChangesAsync();
        return true;
    }
}
