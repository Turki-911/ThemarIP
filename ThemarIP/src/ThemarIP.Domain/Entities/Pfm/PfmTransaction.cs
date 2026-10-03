using ThemarIP.Domain.Entities;
using ThemarIP.Domain.Enums.Pfm;

namespace ThemarIP.Domain.Entities.Pfm;

/// <summary>
/// A financial transaction ingested from an external PSP / NBO API.
/// Raw transaction data is stored here exactly as received.
/// Category information is NOT stored directly on this entity —
/// it lives in the related <see cref="PfmTransactionCategory"/> record
/// so the engine can re-categorize without touching raw data.
/// </summary>
public class PfmTransaction
{
    public Guid Id { get; set; } = Guid.NewGuid();

    /// <summary>The user this transaction belongs to.</summary>
    public Guid UserId { get; set; }
    public User? User { get; set; }

    /// <summary>
    /// Resolved merchant FK — null if the engine could not identify a known merchant.
    /// Populated by the engine during ingestion via alias matching.
    /// </summary>
    public Guid? MerchantId { get; set; }
    public PfmMerchant? Merchant { get; set; }

    /// <summary>Raw narration string from the PSP (e.g. "KFC AL KHUWAIR POS").</summary>
    public string Narration { get; set; } = string.Empty;

    public decimal Amount { get; set; }
    public string Currency { get; set; } = "OMR";

    public TransactionType TransactionType { get; set; } = TransactionType.Debit;

    /// <summary>Account balance immediately after this transaction.</summary>
    public decimal? BalanceAfter { get; set; }

    public DateTimeOffset TransactionDate { get; set; }

    /// <summary>True when the engine detects a recurring pattern for this transaction.</summary>
    public bool IsRecurring { get; set; }

    /// <summary>True for essential categories: Bills, Income.</summary>
    public bool IsEssential { get; set; }

    public TransactionStatus Status { get; set; } = TransactionStatus.Uncategorized;

    /// <summary>Raw MCC code from the PSP, if available.</summary>
    public string? MccCode { get; set; }

    /// <summary>Originating financial institution identifier (e.g. BANK_MUSCAT, NBO, BANK_DHOFAR).</summary>
    public string BankCode { get; set; } = "BANK_MUSCAT";

    /// <summary>Display name of originating bank (e.g. Bank Muscat, National Bank of Oman).</summary>
    public string BankName { get; set; } = "Bank Muscat";

    public DateTimeOffset CreatedAt { get; set; } = DateTimeOffset.UtcNow;
    public DateTimeOffset UpdatedAt { get; set; } = DateTimeOffset.UtcNow;

    // Navigation — engine output is a separate record
    public PfmTransactionCategory? Category { get; set; }
    public ICollection<PfmUserCorrection> Corrections { get; set; } = new List<PfmUserCorrection>();
}
