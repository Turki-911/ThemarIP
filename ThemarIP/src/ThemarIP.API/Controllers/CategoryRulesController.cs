using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using ThemarIP.Application.Common.Interfaces;
using ThemarIP.Domain.Entities;

namespace ThemarIP.API.Controllers;

[ApiController]
[Authorize(Roles = "Admin")]
[Route("api/admin/category-rules")]
public class CategoryRulesController : ControllerBase
{
    private readonly IApplicationDbContext _context;

    public CategoryRulesController(IApplicationDbContext context)
    {
        _context = context;
    }

    public record CreateCategoryRuleRequest(string Keyword, string Category, string? MccCode, int Priority = 10);

    /// <summary>
    /// Get all admin category engine rules
    /// </summary>
    [HttpGet]
    public async Task<ActionResult<List<CategoryRule>>> GetRules(CancellationToken cancellationToken)
    {
        var rules = await _context.CategoryRules
            .OrderBy(r => r.Priority)
            .ThenBy(r => r.Keyword)
            .ToListAsync(cancellationToken);
        return Ok(rules);
    }

    /// <summary>
    /// Add or update a category engine rule
    /// </summary>
    [HttpPost]
    public async Task<ActionResult<CategoryRule>> CreateRule([FromBody] CreateCategoryRuleRequest request, CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(request.Keyword) || string.IsNullOrWhiteSpace(request.Category))
        {
            return BadRequest(new { message = "Keyword and Category are required." });
        }

        var rule = new CategoryRule
        {
            Id = Guid.NewGuid(),
            Keyword = request.Keyword.Trim().ToUpper(),
            Category = request.Category.Trim(),
            MccCode = request.MccCode?.Trim(),
            Priority = request.Priority,
            IsActive = true,
            CreatedAt = DateTimeOffset.UtcNow
        };

        _context.CategoryRules.Add(rule);
        await _context.SaveChangesAsync(cancellationToken);

        return CreatedAtAction(nameof(GetRules), new { id = rule.Id }, rule);
    }

    /// <summary>
    /// Delete a category engine rule by ID
    /// </summary>
    [HttpDelete("{id:guid}")]
    public async Task<IActionResult> DeleteRule(Guid id, CancellationToken cancellationToken)
    {
        var rule = await _context.CategoryRules.FindAsync(new object[] { id }, cancellationToken);
        if (rule == null)
        {
            return NotFound(new { message = "Category rule not found." });
        }

        _context.CategoryRules.Remove(rule);
        await _context.SaveChangesAsync(cancellationToken);

        return NoContent();
    }
}
