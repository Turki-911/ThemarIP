using ThemarIP.Domain.Enums.Pfm;

namespace ThemarIP.Domain.Entities.Pfm;

/// <summary>
/// Top-level spending category (e.g. "Food", "Transport").
/// Admin-managed: name, icon, color and order are all editable in the portal.
/// </summary>
public class PfmCategory
{
    public Guid Id { get; set; } = Guid.NewGuid();

    /// <summary>Display name — the only place this string is stored.</summary>
    public string Name { get; set; } = string.Empty;

    /// <summary>Lucide icon name, e.g. "utensils", "car".</summary>
    public string Icon { get; set; } = "tag";

    /// <summary>Hex color for UI rendering, e.g. "#10B981".</summary>
    public string Color { get; set; } = "#94A3B8";

    /// <summary>Controls sort position in the portal tree view.</summary>
    public int DisplayOrder { get; set; }

    /// <summary>NULL for top-level category; points to parent category for subcategories.</summary>
    public Guid? ParentId { get; set; }
    public PfmCategory? Parent { get; set; }
    public ICollection<PfmCategory> Children { get; set; } = new List<PfmCategory>();

    public bool IsEnabled { get; set; } = true;
    public DateTimeOffset CreatedAt { get; set; } = DateTimeOffset.UtcNow;
    public DateTimeOffset UpdatedAt { get; set; } = DateTimeOffset.UtcNow;

    // Navigation
    public ICollection<PfmSubcategory> Subcategories { get; set; } = new List<PfmSubcategory>();
    public ICollection<PfmMerchant> MerchantsAsDefault { get; set; } = new List<PfmMerchant>();
    public ICollection<PfmCategorizationRule> Rules { get; set; } = new List<PfmCategorizationRule>();
    public ICollection<PfmTransactionCategory> TransactionCategories { get; set; } = new List<PfmTransactionCategory>();
    public ICollection<PfmUserCorrection> OriginalCategoryCorrections { get; set; } = new List<PfmUserCorrection>();
    public ICollection<PfmUserCorrection> CorrectedCategoryCorrections { get; set; } = new List<PfmUserCorrection>();
    public ICollection<PfmLearningSuggestion> SuggestionsAsCurrent { get; set; } = new List<PfmLearningSuggestion>();
    public ICollection<PfmLearningSuggestion> SuggestionsAsSuggested { get; set; } = new List<PfmLearningSuggestion>();
}
