namespace ThemarIP.Domain.Entities.Pfm;

/// <summary>
/// Second-level category under a <see cref="PfmCategory"/>.
/// e.g. Category="Food" → Subcategory="Fast Food", "Coffee Shops".
/// </summary>
public class PfmSubcategory
{
    public Guid Id { get; set; } = Guid.NewGuid();

    public Guid CategoryId { get; set; }
    public PfmCategory? Category { get; set; }

    public string Name { get; set; } = string.Empty;
    public int DisplayOrder { get; set; }
    public bool IsEnabled { get; set; } = true;
    public DateTimeOffset CreatedAt { get; set; } = DateTimeOffset.UtcNow;
    public DateTimeOffset UpdatedAt { get; set; } = DateTimeOffset.UtcNow;

    // Navigation
    public ICollection<PfmMerchant> MerchantsAsDefault { get; set; } = new List<PfmMerchant>();
    public ICollection<PfmCategorizationRule> Rules { get; set; } = new List<PfmCategorizationRule>();
    public ICollection<PfmTransactionCategory> TransactionCategories { get; set; } = new List<PfmTransactionCategory>();
    public ICollection<PfmUserCorrection> OriginalSubcategoryCorrections { get; set; } = new List<PfmUserCorrection>();
    public ICollection<PfmUserCorrection> CorrectedSubcategoryCorrections { get; set; } = new List<PfmUserCorrection>();
    public ICollection<PfmLearningSuggestion> SuggestionsAsCurrent { get; set; } = new List<PfmLearningSuggestion>();
    public ICollection<PfmLearningSuggestion> SuggestionsAsSuggested { get; set; } = new List<PfmLearningSuggestion>();
}
