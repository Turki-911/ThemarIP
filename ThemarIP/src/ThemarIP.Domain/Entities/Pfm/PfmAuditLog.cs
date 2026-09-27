using ThemarIP.Domain.Entities;
using ThemarIP.Domain.Enums.Pfm;

namespace ThemarIP.Domain.Entities.Pfm;

/// <summary>
/// Immutable audit log for all admin actions in the PFM portal.
/// Every Create, Update, Delete, Approve, Reject, or Toggle action writes a row here.
/// Old and new values are stored as JSON snapshots for full auditability.
/// </summary>
public class PfmAuditLog
{
    public Guid Id { get; set; } = Guid.NewGuid();

    /// <summary>The admin who performed the action.</summary>
    public Guid AdminUserId { get; set; }
    public User? AdminUser { get; set; }

    public PfmAuditAction ActionType { get; set; }

    /// <summary>Entity type name (e.g. "PfmCategorizationRule", "PfmMerchant").</summary>
    public string EntityType { get; set; } = string.Empty;

    /// <summary>String representation of the affected entity's PK.</summary>
    public string EntityId { get; set; } = string.Empty;

    /// <summary>Human-readable description shown in the portal audit log.</summary>
    public string Description { get; set; } = string.Empty;

    /// <summary>JSON snapshot of the entity before the change. Null for Create actions.</summary>
    public string? OldValueJson { get; set; }

    /// <summary>JSON snapshot of the entity after the change. Null for Delete actions.</summary>
    public string? NewValueJson { get; set; }

    public DateTimeOffset Timestamp { get; set; } = DateTimeOffset.UtcNow;
}
