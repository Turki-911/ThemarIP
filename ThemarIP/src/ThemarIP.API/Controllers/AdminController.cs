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
[Authorize(Roles = "Admin")]
[Route("api/[controller]")]
public class AdminController : ControllerBase
{
    private readonly IAdminService _adminService;

    public AdminController(IAdminService adminService)
    {
        _adminService = adminService;
    }

    /// <summary>
    /// Get high-level admin metrics and system summary
    /// </summary>
    [HttpGet("dashboard")]
    public async Task<ActionResult<AdminDashboardDto>> GetDashboard(CancellationToken cancellationToken)
    {
        var stats = await _adminService.GetDashboardStatsAsync(cancellationToken);
        return Ok(stats);
    }

    /// <summary>
    /// Get all registered users in the system
    /// </summary>
    [HttpGet("users")]
    public async Task<ActionResult<List<UserDto>>> GetUsers(CancellationToken cancellationToken)
    {
        var users = await _adminService.GetAllUsersAsync(cancellationToken);
        return Ok(users);
    }

    /// <summary>
    /// Get all statement uploads across all users
    /// </summary>
    [HttpGet("uploads")]
    public async Task<ActionResult<List<StatementUploadDto>>> GetUploads(CancellationToken cancellationToken)
    {
        var uploads = await _adminService.GetAllUploadsAsync(cancellationToken);
        return Ok(uploads);
    }

    /// <summary>
    /// Get all user subscriptions in the system
    /// </summary>
    [HttpGet("subscriptions")]
    public async Task<ActionResult<List<SubscriptionDto>>> GetSubscriptions(CancellationToken cancellationToken)
    {
        var subscriptions = await _adminService.GetAllSubscriptionsAsync(cancellationToken);
        return Ok(subscriptions);
    }

    /// <summary>
    /// Get detailed user profile including KYC and Audit history
    /// </summary>
    [HttpGet("users/{userId}/details")]
    public async Task<ActionResult<UserDetailDto>> GetUserDetail(System.Guid userId, CancellationToken cancellationToken)
    {
        var detail = await _adminService.GetUserDetailAsync(userId, cancellationToken);
        if (detail == null) return NotFound();
        return Ok(detail);
    }

    /// <summary>
    /// Update user's access status
    /// </summary>
    [HttpPost("users/{userId}/access")]
    public async Task<ActionResult> UpdateAccessStatus(System.Guid userId, [FromBody] AccessUpdateDto dto, CancellationToken cancellationToken)
    {
        var adminIdStr = User.FindFirstValue(System.Security.Claims.ClaimTypes.NameIdentifier);
        if (!System.Guid.TryParse(adminIdStr, out var adminId)) return Unauthorized();

        var success = await _adminService.UpdateAccessStatusAsync(adminId, userId, dto, cancellationToken);
        if (!success) return NotFound();
        return Ok();
    }

    /// <summary>
    /// Update user's KYC status
    /// </summary>
    [HttpPost("users/{userId}/kyc")]
    public async Task<ActionResult> UpdateKycStatus(System.Guid userId, [FromBody] KycUpdateDto dto, CancellationToken cancellationToken)
    {
        var adminIdStr = User.FindFirstValue(System.Security.Claims.ClaimTypes.NameIdentifier);
        if (!System.Guid.TryParse(adminIdStr, out var adminId)) return Unauthorized();

        var success = await _adminService.UpdateKycStatusAsync(adminId, userId, dto, cancellationToken);
        if (!success) return NotFound();
        return Ok();
    }
}
