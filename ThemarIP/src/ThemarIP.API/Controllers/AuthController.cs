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
[Route("api/[controller]")]
public class AuthController : ControllerBase
{
    private readonly IAuthService _authService;

    public AuthController(IAuthService authService)
    {
        _authService = authService;
    }

    /// <summary>
    /// Request an OTP verification code for sign-up
    /// </summary>
    [HttpPost("request-signup-otp")]
    public async Task<IActionResult> RequestSignupOtp([FromBody] SignupOtpRequestDto request, CancellationToken cancellationToken)
    {
        try
        {
            var response = await _authService.RequestSignupOtpAsync(request, cancellationToken);
            return Ok(response);
        }
        catch (ArgumentException ex)
        {
            return BadRequest(new { message = ex.Message });
        }
        catch (InvalidOperationException ex)
        {
            return BadRequest(new { message = ex.Message });
        }
    }

    /// <summary>
    /// Register a new user account (Requires valid OTP)
    /// </summary>
    [HttpPost("register")]
    public async Task<ActionResult<AuthResponseDto>> Register([FromBody] RegisterRequestDto request, CancellationToken cancellationToken)
    {
        try
        {
            var response = await _authService.RegisterAsync(request, cancellationToken);
            return Ok(response);
        }
        catch (ArgumentException ex)
        {
            return BadRequest(new { message = ex.Message });
        }
        catch (InvalidOperationException ex)
        {
            return BadRequest(new { message = ex.Message });
        }
    }

    /// <summary>
    /// Authenticate user and obtain JWT token
    /// </summary>
    [HttpPost("login")]
    public async Task<ActionResult<AuthResponseDto>> Login([FromBody] LoginRequestDto request, CancellationToken cancellationToken)
    {
        try
        {
            var response = await _authService.LoginAsync(request, cancellationToken);
            return Ok(response);
        }
        catch (UnauthorizedAccessException ex)
        {
            return Unauthorized(new { message = ex.Message });
        }
    }

    /// <summary>
    /// Request an OTP verification code for password reset
    /// </summary>
    [HttpPost("forgot-password")]
    public async Task<IActionResult> ForgotPassword([FromBody] ForgotPasswordRequestDto request, CancellationToken cancellationToken)
    {
        try
        {
            var response = await _authService.RequestPasswordResetOtpAsync(request, cancellationToken);
            return Ok(response);
        }
        catch (ArgumentException ex)
        {
            return BadRequest(new { message = ex.Message });
        }
        catch (KeyNotFoundException ex)
        {
            return NotFound(new { message = ex.Message });
        }
    }

    /// <summary>
    /// Verify OTP and reset password to a new password
    /// </summary>
    [HttpPost("reset-password")]
    public async Task<IActionResult> ResetPassword([FromBody] ResetPasswordRequestDto request, CancellationToken cancellationToken)
    {
        try
        {
            var response = await _authService.ResetPasswordAsync(request, cancellationToken);
            return Ok(new { message = response });
        }
        catch (ArgumentException ex)
        {
            return BadRequest(new { message = ex.Message });
        }
        catch (InvalidOperationException ex)
        {
            return BadRequest(new { message = ex.Message });
        }
        catch (KeyNotFoundException ex)
        {
            return NotFound(new { message = ex.Message });
        }
    }

    /// <summary>
    /// Complete password reset with new password & confirmation (Admin-triggered or direct reset)
    /// </summary>
    [HttpPost("complete-password-reset")]
    public async Task<IActionResult> CompletePasswordReset([FromBody] CompletePasswordResetRequestDto request, CancellationToken cancellationToken)
    {
        try
        {
            var response = await _authService.CompletePasswordResetAsync(request, cancellationToken);
            return Ok(new { message = response });
        }
        catch (ArgumentException ex)
        {
            return BadRequest(new { message = ex.Message });
        }
        catch (KeyNotFoundException ex)
        {
            return NotFound(new { message = ex.Message });
        }
    }

    /// <summary>
    /// Check if user account requires a mandatory password reset
    /// </summary>
    [HttpGet("user-status")]
    public async Task<IActionResult> GetUserStatus(
        [FromQuery] Guid? userId,
        [FromQuery] string? email,
        [FromServices] ThemarIP.Application.Common.Interfaces.IApplicationDbContext context)
    {
        ThemarIP.Domain.Entities.User? user = null;
        if (userId.HasValue && userId.Value != Guid.Empty)
        {
            user = await context.Users.FindAsync(userId.Value);
        }
        else if (!string.IsNullOrWhiteSpace(email))
        {
            var norm = email.Trim().ToLowerInvariant();
            user = await Microsoft.EntityFrameworkCore.EntityFrameworkQueryableExtensions.FirstOrDefaultAsync(
                context.Users, u => u.Email.ToLower() == norm);
        }

        if (user == null)
            return NotFound(new { message = "User not found." });

        var requireReset = string.Equals(user.AccessReasonNote, "RESET_PASSWORD_REQUIRED", StringComparison.OrdinalIgnoreCase);
        return Ok(new
        {
            userId = user.Id,
            email = user.Email,
            requirePasswordReset = requireReset,
            accessStatus = user.AccessStatus.ToString()
        });
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
