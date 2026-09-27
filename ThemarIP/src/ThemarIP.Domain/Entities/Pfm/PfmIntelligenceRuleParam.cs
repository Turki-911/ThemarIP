using ThemarIP.Domain.Enums.Pfm;

namespace ThemarIP.Domain.Entities.Pfm;

/// <summary>
/// One parameter for a <see cref="PfmIntelligenceRule"/>.
/// Stored as typed key/value rows so new parameters can be added
/// to a rule without schema changes.
///
/// Example rows for a "HighSpending" rule:
///   Key="threshold"    Value="50"       Type=Number
///   Key="currency"     Value="OMR"      Type=String
///   Key="categoryName" Value="Coffee"   Type=String
///   Key="period"       Value="monthly"  Type=String
/// </summary>
public class PfmIntelligenceRuleParam
{
    public Guid Id { get; set; } = Guid.NewGuid();

    public Guid RuleId { get; set; }
    public PfmIntelligenceRule? Rule { get; set; }

    /// <summary>
    /// Parameter key — matches the template variable name in
    /// <see cref="PfmIntelligenceRule.InsightTemplate"/>.
    /// </summary>
    public string ParamKey { get; set; } = string.Empty;

    /// <summary>String representation of the parameter value.</summary>
    public string ParamValue { get; set; } = string.Empty;

    /// <summary>How to interpret ParamValue at runtime.</summary>
    public IntelligenceRuleParamType ParamType { get; set; } = IntelligenceRuleParamType.String;

    public DateTimeOffset UpdatedAt { get; set; } = DateTimeOffset.UtcNow;
}
