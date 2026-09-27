using System.Collections.Generic;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using Microsoft.EntityFrameworkCore;
using ThemarIP.Application.Common.Interfaces;
using ThemarIP.Application.DTOs;
using ThemarIP.Domain.Entities;
using ThemarIP.Domain.Enums;

namespace ThemarIP.Application.Services;

public interface IAdminService
{
    Task<AdminDashboardDto> GetDashboardStatsAsync(CancellationToken cancellationToken = default);
    Task<List<UserDto>> GetAllUsersAsync(CancellationToken cancellationToken = default);
    Task<List<StatementUploadDto>> GetAllUploadsAsync(CancellationToken cancellationToken = default);
    Task<List<SubscriptionDto>> GetAllSubscriptionsAsync(CancellationToken cancellationToken = default);
    Task<UserDetailDto?> GetUserDetailAsync(Guid userId, CancellationToken cancellationToken = default);
    Task<bool> UpdateAccessStatusAsync(Guid adminId, Guid targetUserId, AccessUpdateDto dto, CancellationToken cancellationToken = default);
    Task<bool> UpdateKycStatusAsync(Guid adminId, Guid targetUserId, KycUpdateDto dto, CancellationToken cancellationToken = default);
}

public class AdminService : IAdminService
{
    private readonly IApplicationDbContext _context;

    public AdminService(IApplicationDbContext context)
    {
        _context = context;
    }

    public async Task<AdminDashboardDto> GetDashboardStatsAsync(CancellationToken cancellationToken = default)
    {
        var totalUsers = await _context.Users.CountAsync(cancellationToken);
        var totalUploads = await _context.StatementUploads.CountAsync(cancellationToken);
        var totalTransactions = await _context.Transactions.CountAsync(cancellationToken);
        var activeSubscriptions = await _context.Subscriptions.CountAsync(s => s.Status == SubscriptionStatus.Active, cancellationToken);
        var totalRevenue = await _context.Subscriptions.Where(s => s.Status == SubscriptionStatus.Active).SumAsync(s => s.Price, cancellationToken);

        return new AdminDashboardDto(
            totalUsers,
            totalUploads,
            totalTransactions,
            activeSubscriptions,
            totalRevenue
        );
    }

    public async Task<List<UserDto>> GetAllUsersAsync(CancellationToken cancellationToken = default)
    {
        var users = await _context.Users
            .Select(u => new UserDto(
                u.Id,
                u.Email,
                u.FullName,
                u.Role,
                u.CreatedAt,
                u.AccessStatus,
                u.TrustScore
            ))
            .ToListAsync(cancellationToken);

        return users.OrderByDescending(u => u.CreatedAt).ToList();
    }

    public async Task<UserDetailDto?> GetUserDetailAsync(Guid userId, CancellationToken cancellationToken = default)
    {
        var user = await _context.Users
            .Include(u => u.KycSubmissions)
            .Include(u => u.TargetAuditLogs)
            .FirstOrDefaultAsync(u => u.Id == userId, cancellationToken);

        if (user == null) return null;

        var kycDtos = user.KycSubmissions.OrderByDescending(k => k.SubmittedAt).Select(k => new KycSubmissionDto(
            k.Id, k.Status, k.SubmittedAt, k.ReviewedAt, k.ReviewedByAdminId, k.ReasonCode, k.ReasonNote, k.DocumentReferences
        )).ToList();

        var auditDtos = user.TargetAuditLogs.OrderByDescending(a => a.CreatedAt).Select(a => new AuditLogDto(
            a.Id, a.AdminUserId, a.ActionType, a.ReasonCode, a.ReasonNote, a.CreatedAt
        )).ToList();

        return new UserDetailDto(
            user.Id, user.Email, user.FullName, user.Role, user.CreatedAt,
            user.AccessStatus, user.AccessReasonCode, user.AccessReasonNote, user.TrustScore,
            kycDtos, auditDtos
        );
    }

    public async Task<bool> UpdateAccessStatusAsync(Guid adminId, Guid targetUserId, AccessUpdateDto dto, CancellationToken cancellationToken = default)
    {
        var user = await _context.Users.FindAsync(new object[] { targetUserId }, cancellationToken);
        if (user == null) return false;

        user.AccessStatus = dto.Status;
        user.AccessReasonCode = dto.ReasonCode;
        user.AccessReasonNote = dto.ReasonNote;

        var audit = new AuditLog
        {
            AdminUserId = adminId,
            TargetUserId = targetUserId,
            ActionType = dto.Status == AccessStatus.Approved ? AuditActionType.ApproveAccess : AuditActionType.RejectAccess,
            ReasonCode = dto.ReasonCode,
            ReasonNote = dto.ReasonNote
        };

        _context.AuditLogs.Add(audit);
        await _context.SaveChangesAsync(cancellationToken);
        return true;
    }

    public async Task<bool> UpdateKycStatusAsync(Guid adminId, Guid targetUserId, KycUpdateDto dto, CancellationToken cancellationToken = default)
    {
        var user = await _context.Users
            .Include(u => u.KycSubmissions)
            .FirstOrDefaultAsync(u => u.Id == targetUserId, cancellationToken);
            
        if (user == null) return false;

        // Find pending KYC or create one for tracking if none exists
        var kyc = user.KycSubmissions.OrderByDescending(k => k.SubmittedAt).FirstOrDefault();
        if (kyc == null)
        {
            kyc = new KycSubmission { UserId = targetUserId, SubmittedAt = System.DateTimeOffset.UtcNow };
            _context.KycSubmissions.Add(kyc);
        }

        kyc.Status = dto.Status;
        kyc.ReviewedAt = System.DateTimeOffset.UtcNow;
        kyc.ReviewedByAdminId = adminId;
        kyc.ReasonCode = dto.ReasonCode;
        kyc.ReasonNote = dto.ReasonNote;

        // If KYC is rejected, automatically reject access
        if (dto.Status == KycStatus.Rejected)
        {
            user.AccessStatus = AccessStatus.Rejected;
            user.AccessReasonCode = dto.ReasonCode ?? AccessReasonCode.KycNotClear;
            user.AccessReasonNote = dto.ReasonNote;
        }

        // Update Trust Score naively for now
        user.TrustScore = dto.Status == KycStatus.Verified ? 100 : 0;

        var audit = new AuditLog
        {
            AdminUserId = adminId,
            TargetUserId = targetUserId,
            ActionType = dto.Status == KycStatus.Verified ? AuditActionType.ApproveKyc : AuditActionType.RejectKyc,
            ReasonCode = dto.ReasonCode,
            ReasonNote = dto.ReasonNote
        };

        _context.AuditLogs.Add(audit);
        await _context.SaveChangesAsync(cancellationToken);
        return true;
    }

    public async Task<List<StatementUploadDto>> GetAllUploadsAsync(CancellationToken cancellationToken = default)
    {
        var uploads = await _context.StatementUploads
            .Select(s => new StatementUploadDto(
                s.Id,
                s.UserId,
                s.FileName,
                s.FileSize,
                s.Status,
                s.UploadedAt,
                s.Transactions.Count,
                s.DetectedBank,
                s.ProcessingDurationMs,
                s.ValidationWarnings,
                s.Logs
            ))
            .ToListAsync(cancellationToken);

        return uploads.OrderByDescending(s => s.UploadedAt).ToList();
    }

    public async Task<List<SubscriptionDto>> GetAllSubscriptionsAsync(CancellationToken cancellationToken = default)
    {
        var subscriptions = await _context.Subscriptions
            .Select(s => new SubscriptionDto(
                s.Id,
                s.UserId,
                s.Tier,
                s.Status,
                s.StartDate,
                s.EndDate,
                s.Price
            ))
            .ToListAsync(cancellationToken);

        return subscriptions.OrderByDescending(s => s.StartDate).ToList();
    }
}
