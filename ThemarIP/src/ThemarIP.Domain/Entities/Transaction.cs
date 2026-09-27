using System;

namespace ThemarIP.Domain.Entities;

public class Transaction
{
    public Guid Id { get; set; } = Guid.NewGuid();
    
    public Guid StatementUploadId { get; set; }
    public StatementUpload? StatementUpload { get; set; }

    public Guid UserId { get; set; }
    public User? User { get; set; }

    public DateTimeOffset TransactionDate { get; set; } = DateTimeOffset.UtcNow;
    public decimal Amount { get; set; }
    public string Currency { get; set; } = "OMR";
    public string Category { get; set; } = "General";
    public string Description { get; set; } = string.Empty;
    public string? MccCode { get; set; }
    public DateTimeOffset CreatedAt { get; set; } = DateTimeOffset.UtcNow;
}
