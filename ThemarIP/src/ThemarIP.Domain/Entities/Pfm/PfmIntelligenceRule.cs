using ThemarIP.Domain.Enums.Pfm;

namespace ThemarIP.Domain.Entities.Pfm;

/// <summary>
/// A financial intelligence rule that generates insights for consumer users.
/// Examples: "You spent more than X OMR on coffee this month"
///           "Unusual transaction detected — 3× your normal amount"
///
/// All threshold values and template variables live in related
/// <see cref="PfmIntelligenceRuleParam"/> rows — never in code.
/// </summary>
public class PfmIntelligenceRule
{
    public Guid Id { get; set; } = Guid.NewGuid();

    public string Name { get; set; } = string.Empty;

    public IntelligenceRuleType RuleType { get; set; }

    public IntelligenceRuleStatus Status { get; set; } = IntelligenceRuleStatus.Active;

    /// <summary>
    /// Mustache-style template for the insight message.
    /// Variables like {threshold}, {currency}, {categoryName} are resolved
    /// at runtime from the params rows.
    /// </summary>
    public string InsightTemplate { get; set; } = string.Empty;

    /// <summary>Lucide icon name for the portal card.</summary>
    public string Icon { get; set; } = "zap";

    /// <summary>Hex color for the icon background.</summary>
    public string IconColor { get; set; } = "#3B82F6";

    /// <summary>Running count of times this rule fired across all users.</summary>
    public int FireCount { get; set; }

    public DateTimeOffset? LastFiredAt { get; set; }
    public DateTimeOffset CreatedAt { get; set; } = DateTimeOffset.UtcNow;
    public DateTimeOffset UpdatedAt { get; set; } = DateTimeOffset.UtcNow;

    // Navigation
    public ICollection<PfmIntelligenceRuleParam> Params { get; set; } = new List<PfmIntelligenceRuleParam>();
    public ICollection<PfmIntelligenceAlert> Alerts { get; set; } = new List<PfmIntelligenceAlert>();
}
