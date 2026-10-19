using System.Security.Claims;
using System.Threading;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using ThemarIP.Application.DTOs;
using ThemarIP.Application.Services;

namespace ThemarIP.API.Controllers;

[ApiController]
[Route("api/[controller]")]
public class AuthController : ControllerBase
{
    private readonly IAuthService _authService;

    public AuthController(IAuthService authService)
    {
        _authService = authService;
    }

    /// <summary>
    /// Register a new user account
    /// </summary>
    [HttpPost("register")]
    public async Task<ActionResult<AuthResponseDto>> Register([FromBody] RegisterRequestDto request, CancellationToken cancellationToken)
    {
        var response = await _authService.RegisterAsync(request, cancellationToken);
        return Ok(response);
    }

    /// <summary>
    /// Authenticate user and obtain JWT token
    /// </summary>
    [HttpPost("login")]
    public async Task<ActionResult<AuthResponseDto>> Login([FromBody] LoginRequestDto request, CancellationToken cancellationToken)
    {
        var response = await _authService.LoginAsync(request, cancellationToken);
        return Ok(response);
    }

    /// <summary>
    /// Set the user's NBO account number
    /// </summary>
    [HttpPost("set-account-number")]
    [Authorize]
    public async Task<ActionResult<AuthResponseDto>> SetAccountNumber(
        [FromBody] SetAccountNumberRequestDto request,
        CancellationToken cancellationToken)
    {
        var userId = System.Guid.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);
        var response = await _authService.SetAccountNumberAsync(userId, request, cancellationToken);
        return Ok(response);
    }

    /// <summary>
    /// Generate a persistent token and iOS Shortcuts setup config for the authenticated user
    /// </summary>
    [HttpGet("shortcuts-config")]
    [Authorize]
    public async Task<IActionResult> GetShortcutsConfig(
        [FromServices] ThemarIP.Application.Common.Interfaces.IApplicationDbContext context,
        [FromServices] ThemarIP.Application.Common.Interfaces.IJwtTokenGenerator tokenGen)
    {
        if (!System.Guid.TryParse(User.FindFirstValue(ClaimTypes.NameIdentifier), out var userId))
            return Unauthorized();

        var user = await context.Users.FindAsync(userId);
        if (user == null) return NotFound("User not found.");

        var token = tokenGen.GenerateLongLivedToken(user, 365);
        return Ok(new
        {
            endpoint = "https://themarip.up.railway.app/api/sms/ingest",
            apiKey = token,
            bearerToken = $"Bearer {token}",
            userId = user.Id,
            email = user.Email,
            method = "POST",
            headers = new
            {
                Authorization = $"Bearer {token}",
                ContentType = "application/json"
            },
            bodyTemplate = new
            {
                sender = "Shortcut Input (Sender)",
                message = "Shortcut Input (Message Content)"
            }
        });
    }
}
