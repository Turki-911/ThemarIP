using ThemarIP.Domain.Entities;
using ThemarIP.Domain.Enums.Pfm;

namespace ThemarIP.Domain.Entities.Pfm;

/// <summary>
/// A correction submitted by a consumer user disagreeing with the engine's
/// category assignment. Admin reviews these in the "User Corrections" portal view.
///
/// On approval, the admin chooses a scope:
///   - UserOnly  → applies only to the correcting user going forward
///   - Global    → promotes the correction to a new <see cref="PfmCategorizationRule"/>
/// </summary>
public class PfmUserCorrection
{
    public Guid Id { get; set; } = Guid.NewGuid();

    public Guid TransactionId { get; set; }
    public PfmTransaction? Transaction { get; set; }

    /// <summary>The user who submitted this correction.</summary>
    public Guid UserId { get; set; }
    public User? User { get; set; }

    // ── Original engine result ────────────────────────────────
    public Guid? OriginalCategoryId { get; set; }
    public PfmCategory? OriginalCategory { get; set; }

    public Guid? OriginalSubcategoryId { get; set; }
    public PfmSubcategory? OriginalSubcategory { get; set; }

    public int OriginalConfidence { get; set; }

    // ── User's correction ─────────────────────────────────────
    public Guid? CorrectedCategoryId { get; set; }
    public PfmCategory? CorrectedCategory { get; set; }

    public Guid? CorrectedSubcategoryId { get; set; }
    public PfmSubcategory? CorrectedSubcategory { get; set; }

    public DateTimeOffset CorrectionDate { get; set; } = DateTimeOffset.UtcNow;

    // ── Admin review ──────────────────────────────────────────
    public CorrectionStatus Status { get; set; } = CorrectionStatus.Pending;

    /// <summary>
    /// Set by admin on approval: whether the correction applies globally
    /// (creates a new rule) or just for this user.
    /// </summary>
    public CorrectionScope? Scope { get; set; }

    public Guid? ReviewedByAdminId { get; set; }
    public User? ReviewedByAdmin { get; set; }

    public DateTimeOffset? ReviewedAt { get; set; }

    /// <summary>
    /// FK to the rule created if Scope = Global.
    /// Null for UserOnly corrections.
    /// </summary>
    public Guid? GeneratedRuleId { get; set; }
    public PfmCategorizationRule? GeneratedRule { get; set; }

    public string? AdminNote { get; set; }
}
