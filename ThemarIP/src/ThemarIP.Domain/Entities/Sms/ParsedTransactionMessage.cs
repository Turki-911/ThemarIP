using System;

namespace ThemarIP.Domain.Entities.Sms;

/// <summary>
/// Stores the structured fields extracted by the Bank Transaction Message Parser,
/// the clean generated user-friendly description, and the original raw SMS/narration
/// separately for troubleshooting, audit, and manual review of unrecognized messages.
/// </summary>
public class ParsedTransactionMessage
{
    public Guid Id { get; set; } = Guid.NewGuid();

    /// <summary>Optional link to the PfmTransaction record.</summary>
    public Guid? TransactionId { get; set; }

    /// <summary>Optional link to the SmsProcessingLog record.</summary>
    public Guid? SmsLogId { get; set; }

    /// <summary>User who owns the transaction/message.</summary>
    public Guid? UserId { get; set; }

    /// <summary>Original raw bank SMS or statement narration kept intact for troubleshooting.</summary>
    public string OriginalMessage { get; set; } = string.Empty;

    /// <summary>
    /// Clean, user-friendly description displayed in transaction lists:
    /// e.g. "Money sent to Ali", "Money received from Ibrahim", "Card payment at Carrefour", "Cash withdrawal"
    /// </summary>
    public string GeneratedDescription { get; set; } = string.Empty;

    public string BankCode { get; set; } = "BANK_MUSCAT";
    public string BankName { get; set; } = "Bank Muscat";

    /// <summary>
    /// TRANSFER_SENT, TRANSFER_RECEIVED, CARD_PAYMENT, CASH_WITHDRAWAL,
    /// ACCOUNT_CREDIT, INTERNAL_TRANSFER, BILL_PAYMENT, OTHER
    /// </summary>
    public string TransactionType { get; set; } = "OTHER";

    /// <summary>DEBIT or CREDIT.</summary>
    public string Direction { get; set; } = "DEBIT";

    public decimal Amount { get; set; }
    public string Currency { get; set; } = "OMR";

    /// <summary>Cleaned sender, recipient, or merchant name (e.g. "Ali", "Ibrahim", "Carrefour").</summary>
    public string? CounterpartyName { get; set; }

    /// <summary>Raw extracted counterparty string before mask cleanup.</summary>
    public string? RawCounterparty { get; set; }

    public DateTimeOffset? TransactionDate { get; set; }

    /// <summary>Masked account or card number (e.g. "0312XXXXXXXX0014", "420460******0292").</summary>
    public string? AccountNumberMasked { get; set; }

    /// <summary>Unique bank transaction reference (e.g. "BMCT015840785480", "FT26200081709810").</summary>
    public string? TransactionReference { get; set; }

    /// <summary>Available balance / limit after transaction, isolated from transaction amount.</summary>
    public decimal? BalanceAfter { get; set; }

    /// <summary>Confidence score (0-100).</summary>
    public int ConfidenceScore { get; set; } = 100;

    /// <summary>AUTO_APPROVED, NEEDS_REVIEW, MANUALLY_REVIEWED, DUPLICATE_SKIPPED</summary>
    public string ReviewStatus { get; set; } = "AUTO_APPROVED";

    public Guid? MatchedRuleId { get; set; }
    public string? MatchedRuleName { get; set; }

    /// <summary>Deduplication key derived from bank + reference or composite transaction signature.</summary>
    public string DeduplicationKey { get; set; } = string.Empty;

    public DateTimeOffset CreatedAt { get; set; } = DateTimeOffset.UtcNow;
    public DateTimeOffset UpdatedAt { get; set; } = DateTimeOffset.UtcNow;
}
