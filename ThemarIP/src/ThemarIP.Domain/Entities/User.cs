using System;
using System.Collections.Generic;
using ThemarIP.Domain.Enums;

namespace ThemarIP.Domain.Entities;

public class User
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public string Email { get; set; } = string.Empty;
    public string PasswordHash { get; set; } = string.Empty;
    public string FullName { get; set; } = string.Empty;
    public UserRole Role { get; set; } = UserRole.User;
    public DateTimeOffset CreatedAt { get; set; } = DateTimeOffset.UtcNow;
    public string? AccountNumber { get; set; }
    
    // User Management Enhancements
    public AccessStatus AccessStatus { get; set; } = AccessStatus.Pending;
    public AccessReasonCode? AccessReasonCode { get; set; }
    public string? AccessReasonNote { get; set; }
    public int TrustScore { get; set; } = 0;

    // Navigation properties
    public ICollection<Subscription> Subscriptions { get; set; } = new List<Subscription>();
    public ICollection<StatementUpload> StatementUploads { get; set; } = new List<StatementUpload>();
    public ICollection<Transaction> Transactions { get; set; } = new List<Transaction>();
    public ICollection<AiQuery> AiQueries { get; set; } = new List<AiQuery>();
    
    public ICollection<KycSubmission> KycSubmissions { get; set; } = new List<KycSubmission>();
    public ICollection<AuditLog> AdminAuditLogs { get; set; } = new List<AuditLog>(); // Logs where user is the admin
    public ICollection<AuditLog> TargetAuditLogs { get; set; } = new List<AuditLog>(); // Logs where user is the target
}
