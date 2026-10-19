using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using ThemarIP.Application.DTOs.Sms;

namespace ThemarIP.API.Controllers;

/// <summary>Device-facing SMS endpoints (any authenticated app user).</summary>
[ApiController]
[Route("api/sms")]
[Authorize]
public class SmsController : ControllerBase
{
    private readonly ISmsProcessingService _sms;
    public SmsController(ISmsProcessingService sms) => _sms = sms;

    /// <summary>Sender IDs the device should forward — only for the banks this user selected. Messages from any other sender never leave the phone.</summary>
    [HttpGet("senders")]
    public async Task<IActionResult> Senders()
    {
        Guid? userId = Guid.TryParse(User.FindFirst(ClaimTypes.NameIdentifier)?.Value, out var id) ? id : null;
        return Ok(await _sms.GetActiveSenderIdsAsync(userId));
    }

    [HttpPost("ingest")]
    public async Task<IActionResult> Ingest([FromBody] SmsIngestRequestDto dto)
    {
        if (!Guid.TryParse(User.FindFirst(ClaimTypes.NameIdentifier)?.Value, out var userId))
            return Unauthorized();
        if (dto == null) return BadRequest(new { message = "Body required." });
        return Ok(await _sms.IngestAsync(userId, dto));
    }
}

/// <summary>Admin portal: Bank SMS Configuration page.</summary>
[ApiController]
[Route("api/admin/sms-rules")]
[Authorize(Roles = "Admin")]
public class AdminSmsRulesController : ControllerBase
{
    private readonly ISmsProcessingService _sms;
    public AdminSmsRulesController(ISmsProcessingService sms) => _sms = sms;

    private string? Who => User.FindFirst(ClaimTypes.Name)?.Value ?? User.FindFirst(ClaimTypes.NameIdentifier)?.Value;

    [HttpGet]
    public async Task<IActionResult> List() => Ok(await _sms.ListRulesAsync());

    [HttpPost]
    public Task<IActionResult> Create([FromBody] BankSmsRuleDto dto) => Save(null, dto);

    [HttpPut("{id:guid}")]
    public Task<IActionResult> Update(Guid id, [FromBody] BankSmsRuleDto dto) => Save(id, dto);

    private async Task<IActionResult> Save(Guid? id, BankSmsRuleDto dto)
    {
        try { return Ok(await _sms.SaveRuleAsync(id, dto, Who)); }
        catch (ArgumentException e) { return BadRequest(new { message = e.Message }); }
        catch (KeyNotFoundException e) { return NotFound(new { message = e.Message }); }
    }

    [HttpPost("{id:guid}/active")]
    public async Task<IActionResult> SetActive(Guid id, [FromQuery] bool value) =>
        await _sms.SetActiveAsync(id, value, Who) ? Ok() : NotFound();

    [HttpDelete("{id:guid}")]
    public async Task<IActionResult> Delete(Guid id) => await _sms.DeleteRuleAsync(id) ? Ok() : NotFound();

    [HttpPost("test")]
    public IActionResult Test([FromBody] SmsRuleTestRequestDto dto) => Ok(_sms.Test(dto));

    [HttpGet("logs")]
    public async Task<IActionResult> Logs([FromQuery] int take = 100) => Ok(await _sms.GetLogsAsync(take));

    [HttpPost("logs/reprocess")]
    public async Task<IActionResult> Reprocess([FromQuery] Guid? logId = null) =>
        Ok(await _sms.ReprocessLogsAsync(logId));
}
