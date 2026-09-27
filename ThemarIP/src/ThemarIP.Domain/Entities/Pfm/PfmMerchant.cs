namespace ThemarIP.Domain.Entities.Pfm;

/// <summary>
/// Known merchant (e.g. "Starbucks"). Holds the default categorization
/// assignment used by the engine when a transaction matches this merchant.
/// Correction rate is recomputed and stored to power the portal alerts.
/// </summary>
public class PfmMerchant
{
    public Guid Id { get; set; } = Guid.NewGuid();

    /// <summary>Canonical merchant name.</summary>
    public string Name { get; set; } = string.Empty;

    /// <summary>ISO 18245 Merchant Category Code, nullable.</summary>
    public string? MccCode { get; set; }

    // Default categorization assigned by admin — both nullable so a merchant
    // can exist before being assigned a category.
    public Guid? DefaultCategoryId { get; set; }
    public PfmCategory? DefaultCategory { get; set; }

    public Guid? DefaultSubcategoryId { get; set; }
    public PfmSubcategory? DefaultSubcategory { get; set; }

    /// <summary>Confidence score (0–100) that the engine uses for this merchant match.</summary>
    public int DefaultConfidence { get; set; } = 90;

    public bool IsActive { get; set; } = true;

    /// <summary>Running count of transactions linked to this merchant.</summary>
    public int TransactionCount { get; set; }

    /// <summary>Percentage of transactions that were user-corrected (0.00–100.00).</summary>
    public decimal CorrectionRate { get; set; }

    public DateTimeOffset CreatedAt { get; set; } = DateTimeOffset.UtcNow;
    public DateTimeOffset UpdatedAt { get; set; } = DateTimeOffset.UtcNow;

    // Navigation
    public ICollection<PfmMerchantAlias> Aliases { get; set; } = new List<PfmMerchantAlias>();
    public ICollection<PfmTransaction> Transactions { get; set; } = new List<PfmTransaction>();
}
