using System;
using ThemarIP.Domain.Enums;

namespace ThemarIP.Application.DTOs;

public record RegisterRequestDto(
    string Email,
    string Password,
    string FullName,
    string? Otp = null
);

public record SignupOtpRequestDto(
    string Email
);

public record LoginRequestDto(
    string Email,
    string Password
);

public record ForgotPasswordRequestDto(
    string Email
);

public record ResetPasswordRequestDto(
    string Email,
    string Otp,
    string NewPassword
);

public record OtpResponseDto(
    string Message,
    string? PreviewOtp = null,
    bool EmailSent = false,
    bool RequirePasswordReset = false
);

public record CompletePasswordResetRequestDto(
    string Email,
    string NewPassword,
    string ConfirmPassword
);

public record AuthResponseDto(
    Guid UserId,
    string Email,
    string FullName,
    UserRole Role,
    string Token,
    string? AccountNumber,
    bool RequirePasswordReset = false
);

public record SetAccountNumberRequestDto(string AccountNumber);
