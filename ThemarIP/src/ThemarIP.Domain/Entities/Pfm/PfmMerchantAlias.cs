namespace ThemarIP.Domain.Entities.Pfm;

/// <summary>
/// One normalized string that the engine checks against incoming transaction
/// narrations to identify the parent <see cref="PfmMerchant"/>.
/// Stored uppercase and trimmed so matching is O(1) via index.
/// Admin can add or remove aliases in the Merchants view.
/// </summary>
public class PfmMerchantAlias
{
    public Guid Id { get; set; } = Guid.NewGuid();

    public Guid MerchantId { get; set; }
    public PfmMerchant? Merchant { get; set; }

    /// <summary>
    /// Normalized alias text — stored as UPPER(TRIM(input)).
    /// Unique per merchant to prevent duplicate matching.
    /// </summary>
    public string AliasText { get; set; } = string.Empty;

    public DateTimeOffset CreatedAt { get; set; } = DateTimeOffset.UtcNow;
}
