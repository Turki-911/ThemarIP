using System;
using ThemarIP.Domain.Enums;

namespace ThemarIP.Application.DTOs;

public record FetchNboStatementRequestDto(string AccountNumber, string FromDate, string ToDate);

public record UploadStatementRequestDto(
    string FileName,
    long FileSize,
    string? FilePath = null
);

public record StatementUploadDto(
    Guid Id,
    Guid UserId,
    string FileName,
    long FileSize,
    StatementStatus Status,
    DateTimeOffset UploadedAt,
    int TransactionCount,
    string? DetectedBank = null,
    long ProcessingDurationMs = 0,
    string? ValidationWarnings = null,
    string? Logs = null,
    string? AccountNumber = null,
    string? Source = null
);
