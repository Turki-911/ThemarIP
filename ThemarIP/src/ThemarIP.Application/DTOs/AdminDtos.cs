using System;
using System.Collections.Generic;
using ThemarIP.Domain.Enums;

namespace ThemarIP.Application.DTOs;

public record UserDto(
    Guid Id,
    string Email,
    string FullName,
    UserRole Role,
    DateTimeOffset CreatedAt,
    AccessStatus AccessStatus,
    int TrustScore
);

public record AdminDashboardDto(
    int TotalUsers,
    int TotalStatementUploads,
    int TotalTransactions,
    int ActiveSubscriptions,
    decimal TotalRevenue
);

public record UserDetailDto(
    Guid Id,
    string Email,
    string FullName,
    UserRole Role,
    DateTimeOffset CreatedAt,
    AccessStatus AccessStatus,
    AccessReasonCode? AccessReasonCode,
    string? AccessReasonNote,
    int TrustScore,
    List<KycSubmissionDto> KycSubmissions,
    List<AuditLogDto> AuditLogs
);

public record KycSubmissionDto(
    Guid Id,
    KycStatus Status,
    DateTimeOffset SubmittedAt,
    DateTimeOffset? ReviewedAt,
    Guid? ReviewedByAdminId,
    AccessReasonCode? ReasonCode,
    string? ReasonNote,
    string? DocumentReferences
);

public record AuditLogDto(
    Guid Id,
    Guid AdminUserId,
    AuditActionType ActionType,
    AccessReasonCode? ReasonCode,
    string? ReasonNote,
    DateTimeOffset CreatedAt
);

public record AccessUpdateDto(
    AccessStatus Status,
    AccessReasonCode? ReasonCode,
    string? ReasonNote
);

public record KycUpdateDto(
    KycStatus Status,
    AccessReasonCode? ReasonCode,
    string? ReasonNote
);
