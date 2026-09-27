using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using Microsoft.EntityFrameworkCore;
using ThemarIP.Application.Common.Interfaces;
using ThemarIP.Application.DTOs;

namespace ThemarIP.Application.Services;

public interface ITransactionService
{
    Task<List<TransactionDto>> GetUserTransactionsAsync(Guid userId, CancellationToken cancellationToken = default);
    Task<TransactionSummaryDto> GetUserTransactionSummaryAsync(Guid userId, CancellationToken cancellationToken = default);
    Task<List<CategorySummaryDto>> GetUserTransactionCategoriesAsync(Guid userId, CancellationToken cancellationToken = default);
}

public class TransactionService : ITransactionService
{
    private readonly IApplicationDbContext _context;

    public TransactionService(IApplicationDbContext context)
    {
        _context = context;
    }

    public async Task<List<TransactionDto>> GetUserTransactionsAsync(Guid userId, CancellationToken cancellationToken = default)
    {
        var transactions = await _context.Transactions
            .Where(t => t.UserId == userId)
            .Select(t => new TransactionDto(
                t.Id,
                t.StatementUploadId,
                t.UserId,
                t.TransactionDate,
                t.Amount,
                t.Currency,
                t.Category,
                t.Description,
                t.MccCode
            ))
            .ToListAsync(cancellationToken);

        return transactions.OrderByDescending(t => t.TransactionDate).ToList();
    }

    public async Task<TransactionSummaryDto> GetUserTransactionSummaryAsync(Guid userId, CancellationToken cancellationToken = default)
    {
        var userTransactions = await _context.Transactions
            .Where(t => t.UserId == userId)
            .ToListAsync(cancellationToken);

        var topCategories = userTransactions
            .GroupBy(t => t.Category)
            .Select(g => new CategorySummaryDto(
                g.Key,
                g.Sum(x => x.Amount),
                g.Count()
            ))
            .OrderByDescending(c => c.TotalAmount)
            .ToList();

        var totalAmount = userTransactions.Sum(t => t.Amount);

        return new TransactionSummaryDto(
            userTransactions.Count,
            totalAmount,
            userTransactions.FirstOrDefault()?.Currency ?? "OMR",
            topCategories
        );
    }

    public async Task<List<CategorySummaryDto>> GetUserTransactionCategoriesAsync(Guid userId, CancellationToken cancellationToken = default)
    {
        var userTransactions = await _context.Transactions
            .Where(t => t.UserId == userId)
            .ToListAsync(cancellationToken);

        return userTransactions
            .GroupBy(t => t.Category)
            .Select(g => new CategorySummaryDto(
                g.Key,
                g.Sum(x => x.Amount),
                g.Count()
            ))
            .OrderByDescending(c => c.TotalAmount)
            .ToList();
    }
}
