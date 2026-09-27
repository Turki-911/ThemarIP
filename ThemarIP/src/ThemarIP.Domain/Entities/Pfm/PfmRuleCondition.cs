using ThemarIP.Domain.Enums.Pfm;

namespace ThemarIP.Domain.Entities.Pfm;

/// <summary>
/// One condition row inside a <see cref="PfmCategorizationRule"/>.
///
/// Example row:
///   Field=Narration  Operator=Contains  Value="STARBUCKS"  Logic=And  Order=0
///   Field=Amount     Operator=LessThan  Value="20"          Logic=And  Order=1
///
/// The engine evaluates all conditions of a rule in ascending <see cref="OrderIndex"/>
/// and combines them using the <see cref="LogicOperator"/> on each condition.
/// </summary>
public class PfmRuleCondition
{
    public Guid Id { get; set; } = Guid.NewGuid();

    public Guid RuleId { get; set; }
    public PfmCategorizationRule? Rule { get; set; }

    public RuleConditionField Field { get; set; }
    public RuleConditionOperator Operator { get; set; }

    /// <summary>
    /// String representation of the comparison value.
    /// For Between, this is "min|max" (pipe-separated).
    /// </summary>
    public string Value { get; set; } = string.Empty;

    /// <summary>
    /// How this condition is combined with the NEXT condition in the list.
    /// The last condition's logic operator is ignored by the engine.
    /// </summary>
    public RuleConditionLogic LogicOperator { get; set; } = RuleConditionLogic.And;

    /// <summary>Zero-based evaluation order within the parent rule.</summary>
    public int OrderIndex { get; set; }
}
