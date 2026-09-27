using System;

namespace ThemarIP.Domain.Entities;

public class CategoryRule
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public string Keyword { get; set; } = string.Empty;
    public string Category { get; set; } = string.Empty;
    public string? MccCode { get; set; }
    public int Priority { get; set; } = 10;
    public bool IsActive { get; set; } = true;
    public DateTimeOffset CreatedAt { get; set; } = DateTimeOffset.UtcNow;
}
