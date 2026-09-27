using ThemarIP.Domain.Entities;
using ThemarIP.Domain.Enums.Pfm;

namespace ThemarIP.Domain.Entities.Pfm;

/// <summary>
/// An admin-defined rule that the categorization engine evaluates against
/// every incoming transaction. Multiple <see cref="PfmRuleCondition"/> rows
/// express the IF clause; <see cref="CategoryId"/>/<see cref="SubcategoryId"/>
/// and <see cref="Confidence"/> are the THEN clause.
///
/// Rules are evaluated in descending <see cref="Priority"/> order; the first
/// match wins. Conditions within a rule are evaluated with the logic operator
/// stored on each condition row — no hardcoded AND/OR in code.
/// </summary>
public class PfmCategorizationRule
{
    public Guid Id { get; set; } = Guid.NewGuid();

    public string Name { get; set; } = string.Empty;

    // ── THEN clause ───────────────────────────────────────────
    public Guid? CategoryId { get; set; }
    public PfmCategory? Category { get; set; }

    public Guid? SubcategoryId { get; set; }
    public PfmSubcategory? Subcategory { get; set; }

    /// <summary>Confidence (0–100) assigned to a transaction matched by this rule.</summary>
    public int Confidence { get; set; } = 85;

    /// <summary>Higher priority wins when multiple rules match the same transaction.</summary>
    public int Priority { get; set; } = 50;

    public RuleStatus Status { get; set; } = RuleStatus.Active;

    /// <summary>Running count of transactions categorized by this rule.</summary>
    public int MatchCount { get; set; }

    /// <summary>
    /// When true, this rule was auto-generated from a user correction approval.
    /// Shown with a distinct badge in the portal.
    /// </summary>
    public bool IsLearnedFromCorrection { get; set; }

    /// <summary>Admin who created this rule (null for seeded/system rules).</summary>
    public Guid? CreatedByAdminId { get; set; }
    public User? CreatedByAdmin { get; set; }

    public DateTimeOffset CreatedAt { get; set; } = DateTimeOffset.UtcNow;
    public DateTimeOffset UpdatedAt { get; set; } = DateTimeOffset.UtcNow;

    // Navigation
    public ICollection<PfmRuleCondition> Conditions { get; set; } = new List<PfmRuleCondition>();
    public ICollection<PfmTransactionCategory> TransactionCategories { get; set; } = new List<PfmTransactionCategory>();
}
