using System;
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
public class SubscriptionsController : ControllerBase
{
    private readonly ISubscriptionService _subscriptionService;

    public SubscriptionsController(ISubscriptionService subscriptionService)
    {
        _subscriptionService = subscriptionService;
    }

    private Guid CurrentUserId => Guid.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);

    /// <summary>
    /// Get the current active subscription for the logged-in user
    /// </summary>
    [HttpGet("current")]
    public async Task<ActionResult<SubscriptionDto>> GetCurrentSubscription(CancellationToken cancellationToken)
    {
        var subscription = await _subscriptionService.GetCurrentSubscriptionForUserAsync(CurrentUserId, cancellationToken);
        if (subscription == null)
        {
            return NotFound(new { message = "No active subscription found." });
        }
        return Ok(subscription);
    }
}
