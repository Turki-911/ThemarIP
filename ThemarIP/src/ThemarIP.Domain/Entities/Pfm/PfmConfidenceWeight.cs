using ThemarIP.Domain.Enums.Pfm;

namespace ThemarIP.Domain.Entities.Pfm;

/// <summary>
/// Admin-configurable weight for one categorization signal.
/// There are exactly 5 rows (one per <see cref="ConfidenceSignal"/>).
/// All five <see cref="WeightPercent"/> values must sum to 100.
///
/// The engine reads these rows to calculate the composite confidence
/// score — the formula lives in the engine, the numbers live here.
/// </summary>
public class PfmConfidenceWeight
{
    public Guid Id { get; set; } = Guid.NewGuid();

    /// <summary>The signal this weight applies to.</summary>
    public ConfidenceSignal Signal { get; set; }

    /// <summary>Human-readable signal name for the portal UI.</summary>
    public string DisplayLabel { get; set; } = string.Empty;

    /// <summary>
    /// Weight as an integer percentage (0–100).
    /// All five rows must sum to 100 — enforced by the portal on save.
    /// </summary>
    public int WeightPercent { get; set; }

    /// <summary>Hex color used to render this signal in the visual weight bar.</summary>
    public string Color { get; set; } = "#94A3B8";

    public DateTimeOffset UpdatedAt { get; set; } = DateTimeOffset.UtcNow;
}
