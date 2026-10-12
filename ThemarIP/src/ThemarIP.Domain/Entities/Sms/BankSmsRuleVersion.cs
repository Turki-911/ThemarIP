namespace ThemarIP.Domain.Entities.Sms;

/// <summary>Immutable snapshot of a rule at a given version (audit / rollback reference).</summary>
public class BankSmsRuleVersion
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public Guid RuleId { get; set; }
    public int Version { get; set; }

    /// <summary>JSON snapshot of the rule at this version.</summary>
    public string Snapshot { get; set; } = "{}";

    public string? ChangedBy { get; set; }
    public DateTimeOffset CreatedAt { get; set; } = DateTimeOffset.UtcNow;
}
