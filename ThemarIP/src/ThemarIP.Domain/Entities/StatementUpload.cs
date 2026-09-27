using System;
using System.Collections.Generic;
using ThemarIP.Domain.Enums;

namespace ThemarIP.Domain.Entities;

public class StatementUpload
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public Guid UserId { get; set; }
    public User? User { get; set; }

    public string FileName { get; set; } = string.Empty;
    public long FileSize { get; set; }
    public StatementStatus Status { get; set; } = StatementStatus.Pending;
    public string? DetectedBank { get; set; }
    public long ProcessingDurationMs { get; set; }
    public string? ValidationWarnings { get; set; }
    public string? Logs { get; set; }
    public DateTimeOffset UploadedAt { get; set; } = DateTimeOffset.UtcNow;
    public string? AccountNumber { get; set; }
    public string Source { get; set; } = "FILE_UPLOAD";

    public ICollection<Transaction> Transactions { get; set; } = new List<Transaction>();
}
