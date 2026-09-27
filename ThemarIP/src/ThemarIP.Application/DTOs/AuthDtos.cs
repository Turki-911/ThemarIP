using System;
using ThemarIP.Domain.Enums;

namespace ThemarIP.Application.DTOs;

public record RegisterRequestDto(
    string Email,
    string Password,
    string FullName
);

public record LoginRequestDto(
    string Email,
    string Password
);

public record AuthResponseDto(
    Guid UserId,
    string Email,
    string FullName,
    UserRole Role,
    string Token,
    string? AccountNumber
);

public record SetAccountNumberRequestDto(string AccountNumber);
