using ThemarIP.Domain.Entities;

namespace ThemarIP.Domain.Entities.Pfm;

/// <summary>
/// An insight generated for a specific user when an intelligence rule fires.
/// Stored for the consumer app to display in the insights feed.
/// </summary>
public class PfmIntelligenceAlert
{
    public Guid Id { get; set; } = Guid.NewGuid();

    public Guid RuleId { get; set; }
    public PfmIntelligenceRule? Rule { get; set; }

    /// <summary>The user this alert was generated for.</summary>
    public Guid UserId { get; set; }
    public User? User { get; set; }

    /// <summary>The transaction that triggered this alert (if applicable).</summary>
    public Guid? TransactionId { get; set; }
    public PfmTransaction? Transaction { get; set; }

    /// <summary>Fully resolved insight text (template variables substituted).</summary>
    public string AlertText { get; set; } = string.Empty;

    public bool IsRead { get; set; }

    public DateTimeOffset TriggeredAt { get; set; } = DateTimeOffset.UtcNow;
}
