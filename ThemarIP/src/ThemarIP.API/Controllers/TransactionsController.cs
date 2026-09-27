using System;
using System.Collections.Generic;
using System.Security.Claims;
using System.Threading;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using ThemarIP.Application.DTOs;
using ThemarIP.Application.Services;

namespace ThemarIP.API.Controllers;

[ApiController]
[Authorize]
[Route("api/[controller]")]
public class TransactionsController : ControllerBase
{
    private readonly ITransactionService _transactionService;

    public TransactionsController(ITransactionService transactionService)
    {
        _transactionService = transactionService;
    }

    private Guid CurrentUserId => Guid.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);

    /// <summary>
    /// Get all transactions for the current user
    /// </summary>
    [HttpGet]
    public async Task<ActionResult<List<TransactionDto>>> GetTransactions(CancellationToken cancellationToken)
    {
        var transactions = await _transactionService.GetUserTransactionsAsync(CurrentUserId, cancellationToken);
        return Ok(transactions);
    }

    /// <summary>
    /// Get overall transaction summary for the current user
    /// </summary>
    [HttpGet("summary")]
    public async Task<ActionResult<TransactionSummaryDto>> GetSummary(CancellationToken cancellationToken)
    {
        var summary = await _transactionService.GetUserTransactionSummaryAsync(CurrentUserId, cancellationToken);
        return Ok(summary);
    }

    /// <summary>
    /// Get spending breakdown by category for the current user
    /// </summary>
    [HttpGet("categories")]
    public async Task<ActionResult<List<CategorySummaryDto>>> GetCategories(CancellationToken cancellationToken)
    {
        var categories = await _transactionService.GetUserTransactionCategoriesAsync(CurrentUserId, cancellationToken);
        return Ok(categories);
    }
}
