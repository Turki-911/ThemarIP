using ThemarIP.Domain.Enums.Pfm;

namespace ThemarIP.Domain.Entities.Pfm;

/// <summary>
/// A pattern detected by the system suggesting that the engine's default
/// category for a merchant (or narration pattern) might be wrong.
/// Generated automatically when enough user corrections share the same
/// original→corrected category pair.
///
/// Shown in the "Suggested Rules" tab. Admin approves (creates a rule)
/// or rejects (pattern is dismissed).
/// </summary>
public class PfmLearningSuggestion
{
    public Guid Id { get; set; } = Guid.NewGuid();

    /// <summary>The merchant name or narration pattern that triggered this suggestion.</summary>
    public string Pattern { get; set; } = string.Empty;

    // ── What the engine currently assigns ─────────────────────
    public Guid? CurrentCategoryId { get; set; }
    public PfmCategory? CurrentCategory { get; set; }

    public Guid? CurrentSubcategoryId { get; set; }
    public PfmSubcategory? CurrentSubcategory { get; set; }

    // ── What users consistently correct to ───────────────────
    public Guid? SuggestedCategoryId { get; set; }
    public PfmCategory? SuggestedCategory { get; set; }

    public Guid? SuggestedSubcategoryId { get; set; }
    public PfmSubcategory? SuggestedSubcategory { get; set; }

    /// <summary>Number of user corrections that contributed to this suggestion.</summary>
    public int OccurrenceCount { get; set; }

    /// <summary>Confidence score proposed for the new rule if approved.</summary>
    public int SuggestedConfidence { get; set; } = 85;

    public SuggestionStatus Status { get; set; } = SuggestionStatus.Pending;

    /// <summary>FK to the rule created if this suggestion was approved.</summary>
    public Guid? GeneratedRuleId { get; set; }
    public PfmCategorizationRule? GeneratedRule { get; set; }

    public DateTimeOffset DetectedAt { get; set; } = DateTimeOffset.UtcNow;
    public DateTimeOffset UpdatedAt { get; set; } = DateTimeOffset.UtcNow;
}
