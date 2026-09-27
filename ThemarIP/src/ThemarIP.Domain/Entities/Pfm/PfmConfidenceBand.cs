using ThemarIP.Domain.Enums.Pfm;

namespace ThemarIP.Domain.Entities.Pfm;

/// <summary>
/// Admin-configurable confidence band. There are exactly 3 rows
/// (High / Medium / Low). Thresholds and actions are all editable
/// in the portal — zero hardcoded values in C# code.
///
/// The engine reads these rows at runtime to decide what to do
/// with a transaction's confidence score.
/// </summary>
public class PfmConfidenceBand
{
    public Guid Id { get; set; } = Guid.NewGuid();

    /// <summary>Enum name for programmatic comparison (High / Medium / Low).</summary>
    public ConfidenceBandName BandName { get; set; }

    /// <summary>Human-readable label shown in the portal (e.g. "High Confidence").</summary>
    public string DisplayLabel { get; set; } = string.Empty;

    /// <summary>Minimum score (inclusive) for this band.</summary>
    public int MinThreshold { get; set; }

    /// <summary>Maximum score (inclusive) for this band.</summary>
    public int MaxThreshold { get; set; }

    /// <summary>What the engine does when a transaction falls in this band.</summary>
    public ConfidenceBandAction Action { get; set; }

    /// <summary>
    /// Human-readable description of the action shown in the portal
    /// (e.g. "Auto-categorize silently").
    /// </summary>
    public string ActionLabel { get; set; } = string.Empty;

    public DateTimeOffset UpdatedAt { get; set; } = DateTimeOffset.UtcNow;
}
