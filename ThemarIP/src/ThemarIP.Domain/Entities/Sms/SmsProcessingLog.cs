namespace ThemarIP.Domain.Entities.Sms;

/// <summary>One row per SMS received from a device — outcome, extraction and linkage.</summary>
public class SmsProcessingLog
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public Guid? UserId { get; set; }
    public string Sender { get; set; } = string.Empty;
    public string RawMessage { get; set; } = string.Empty;

    /// <summary>SHA-256 of userId + normalized sender + normalized message — exact-duplicate guard.</summary>
    public string MessageHash { get; set; } = string.Empty;

    public Guid? RuleId { get; set; }
    public int? RuleVersion { get; set; }

    /// <summary>Saved | Duplicate | NoRule | NoMatch | ValidationFailed | Error</summary>
    public string Status { get; set; } = string.Empty;
    public string Details { get; set; } = string.Empty;

    /// <summary>JSON of extracted fields (amount, type, merchant, reference, date, balance, currency).</summary>
    public string? ExtractedJson { get; set; }

    /// <summary>Bank reference extracted from the SMS, used for reference-based duplicate detection.</summary>
    public string? Reference { get; set; }

    public Guid? TransactionId { get; set; }
    public DateTimeOffset ReceivedAt { get; set; } = DateTimeOffset.UtcNow;
    public DateTimeOffset CreatedAt { get; set; } = DateTimeOffset.UtcNow;
}
