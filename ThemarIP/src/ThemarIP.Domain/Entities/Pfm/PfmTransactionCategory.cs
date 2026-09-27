using ThemarIP.Domain.Enums.Pfm;

namespace ThemarIP.Domain.Entities.Pfm;

/// <summary>
/// The categorization engine's output for one <see cref="PfmTransaction"/>.
/// Stored as a 1:1 side-table so raw transaction data is never mutated.
///
/// Score breakdown columns record each signal's contribution so the portal
/// can display the "Why was this categorized?" breakdown to the admin.
/// The five score columns should sum to the final <see cref="Confidence"/> value.
/// </summary>
public class PfmTransactionCategory
{
    public Guid Id { get; set; } = Guid.NewGuid();

    public Guid TransactionId { get; set; }
    public PfmTransaction? Transaction { get; set; }

    // ── Engine decision ───────────────────────────────────────
    public Guid? CategoryId { get; set; }
    public PfmCategory? Category { get; set; }

    public Guid? SubcategoryId { get; set; }
    public PfmSubcategory? Subcategory { get; set; }

    /// <summary>Final confidence score (0–100) computed by the engine.</summary>
    public int Confidence { get; set; }

    /// <summary>Which signal produced this categorization.</summary>
    public CategorizationSource Source { get; set; } = CategorizationSource.Uncategorized;

    /// <summary>The rule that fired, if source is Rule or UserRule.</summary>
    public Guid? MatchedRuleId { get; set; }
    public PfmCategorizationRule? MatchedRule { get; set; }

    // ── Score breakdown — one column per signal ───────────────
    /// <summary>Points contributed by merchant alias match (0–max configured weight).</summary>
    public int ScoreMerchantMatch { get; set; }

    /// <summary>Points contributed by MCC code match.</summary>
    public int ScoreMccMatch { get; set; }

    /// <summary>Points contributed by narration keyword match.</summary>
    public int ScoreNarrationMatch { get; set; }

    /// <summary>Points contributed by historical pattern match.</summary>
    public int ScoreHistoricalMatch { get; set; }

    /// <summary>Points contributed by amount pattern recognition.</summary>
    public int ScoreAmountPattern { get; set; }

    public DateTimeOffset CategorizedAt { get; set; } = DateTimeOffset.UtcNow;
}
