using System;
using ThemarIP.Domain.Enums;

namespace ThemarIP.Domain.Entities;

public class AuditLog
{
    public Guid Id { get; set; } = Guid.NewGuid();
    
    public Guid AdminUserId { get; set; }
    public User? AdminUser { get; set; }
    
    public Guid TargetUserId { get; set; }
    public User? TargetUser { get; set; }
    
    public AuditActionType ActionType { get; set; }
    
    public AccessReasonCode? ReasonCode { get; set; }
    public string? ReasonNote { get; set; }
    
    public DateTimeOffset CreatedAt { get; set; } = DateTimeOffset.UtcNow;
}
