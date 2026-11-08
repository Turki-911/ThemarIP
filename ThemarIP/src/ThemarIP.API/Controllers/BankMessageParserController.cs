using System;
using System.Linq;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using ThemarIP.Application.Common.Interfaces;
using ThemarIP.Application.DTOs.Sms;

namespace ThemarIP.API.Controllers;

[ApiController]
[Route("api/message-parser")]
public class BankMessageParserController : ControllerBase
{
    private readonly IBankTransactionMessageParserService _parser;
    private readonly IApplicationDbContext _db;

    public BankMessageParserController(
        IBankTransactionMessageParserService parser,
        IApplicationDbContext db)
    {
        _parser = parser;
        _db = db;
    }

    [HttpGet("overview")]
    public async Task<IActionResult> GetOverview()
    {
        var rules = await _db.BankMessageParserRules.ToListAsync();
        var messages = await _db.ParsedTransactionMessages.ToListAsync();

        var totalRules = rules.Count;
        var activeRules = rules.Count(r => r.IsActive);
        var supportedBanks = rules.Where(r => r.IsActive).Select(r => r.BankName).Distinct(StringComparer.OrdinalIgnoreCase).ToList();

        var totalMessages = messages.Count;
        var autoApproved = messages.Count(m => m.ReviewStatus == "AUTO_APPROVED");
        var needsReview = messages.Count(m => m.ReviewStatus == "NEEDS_REVIEW");
        var manuallyReviewed = messages.Count(m => m.ReviewStatus == "MANUALLY_REVIEWED");
        var avgConfidence = totalMessages > 0 ? Math.Round(messages.Average(m => m.ConfidenceScore), 1) : 100.0;

        return Ok(new
        {
            totalRules,
            activeRules,
            supportedBanksCount = supportedBanks.Count,
            supportedBanks,
            totalMessages,
            autoApproved,
            needsReview,
            manuallyReviewed,
            avgConfidence
        });
    }

    [HttpGet("rules")]
    public async Task<IActionResult> GetRules([FromQuery] string? bankCode)
    {
        var rules = await _parser.GetRulesAsync(bankCode);
        return Ok(rules);
    }

    [HttpPost("rules")]
    public async Task<IActionResult> CreateRule([FromBody] BankMessageParserRuleDto dto)
    {
        try
        {
            var saved = await _parser.SaveRuleAsync(null, dto);
            return Ok(saved);
        }
        catch (ArgumentException ex)
        {
            return BadRequest(new { message = ex.Message });
        }
    }

    [HttpPut("rules/{id:guid}")]
    public async Task<IActionResult> UpdateRule(Guid id, [FromBody] BankMessageParserRuleDto dto)
    {
        try
        {
            var saved = await _parser.SaveRuleAsync(id, dto);
            return Ok(saved);
        }
        catch (ArgumentException ex)
        {
            return BadRequest(new { message = ex.Message });
        }
    }

    [HttpDelete("rules/{id:guid}")]
    public async Task<IActionResult> DeleteRule(Guid id)
    {
        var ok = await _parser.DeleteRuleAsync(id);
        return ok ? Ok(new { deleted = true }) : NotFound(new { message = "Rule not found." });
    }

    [HttpPost("parse-test")]
    public async Task<IActionResult> ParseTest([FromBody] ParseBankMessageRequestDto request)
    {
        if (request == null || string.IsNullOrWhiteSpace(request.RawMessage))
            return BadRequest(new { message = "RawMessage is required." });

        var result = await _parser.ParseMessageAsync(request);
        return Ok(result);
    }

    [HttpGet("messages")]
    public async Task<IActionResult> GetParsedMessages(
        [FromQuery] string? reviewStatus = null,
        [FromQuery] string? bankCode = null,
        [FromQuery] int take = 250)
    {
        var list = await _parser.GetParsedMessagesAsync(reviewStatus, bankCode, take);
        return Ok(list);
    }

    [HttpPut("messages/{id:guid}/review")]
    public async Task<IActionResult> ReviewMessage(Guid id, [FromBody] ManualReviewUpdateDto dto)
    {
        var updated = await _parser.ReviewMessageAsync(id, dto);
        if (updated == null) return NotFound(new { message = "Parsed message not found." });
        return Ok(updated);
    }

    [HttpPost("backfill")]
    public async Task<IActionResult> BackfillExisting()
    {
        var summary = await _parser.BackfillExistingTransactionsAsync();
        return Ok(summary);
    }
}
