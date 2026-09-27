using System;
using ThemarIP.Domain.Enums;

namespace ThemarIP.Domain.Entities;

public class KycSubmission
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public Guid UserId { get; set; }
    public User? User { get; set; }
    
    public KycStatus Status { get; set; } = KycStatus.Pending;
    public DateTimeOffset SubmittedAt { get; set; } = DateTimeOffset.UtcNow;
    
    public DateTimeOffset? ReviewedAt { get; set; }
    public Guid? ReviewedByAdminId { get; set; }
    public User? ReviewedByAdmin { get; set; }
    
    public AccessReasonCode? ReasonCode { get; set; }
    public string? ReasonNote { get; set; }
    
    public string? DocumentReferences { get; set; } 
}
