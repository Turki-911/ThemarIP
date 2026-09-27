using System;

namespace ThemarIP.Domain.Entities;

public class SystemLog
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public string LogLevel { get; set; } = "Information";
    public string Message { get; set; } = string.Empty;
    public string? Exception { get; set; }
    public string? Source { get; set; }
    public DateTimeOffset CreatedAt { get; set; } = DateTimeOffset.UtcNow;
}
