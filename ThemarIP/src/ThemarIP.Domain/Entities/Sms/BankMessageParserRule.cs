using System;

namespace ThemarIP.Domain.Entities.Sms;

/// <summary>
/// Database-driven bank transaction message parser rule.
/// Extracts structured fields (bank, type, direction, amount, currency, counterparty,
/// date, masked account, reference, balance) and generates a clean user-friendly description
/// (e.g., "Money sent to Ali", "Money received from Ibrahim", "Card payment at Carrefour", "Cash withdrawal").
/// Extensible to any Omani bank without modifying application code.
/// </summary>
public class BankMessageParserRule
{
    public Guid Id { get; set; } = Guid.NewGuid();

    /// <summary>Canonical bank code (e.g. BANK_MUSCAT, NBO, BANK_DHOFAR, OAB, SOHAR_INTL).</summary>
    public string BankCode { get; set; } = "BANK_MUSCAT";

    /// <summary>Display name of the bank (e.g. Bank Muscat).</summary>
    public string BankName { get; set; } = "Bank Muscat";

    /// <summary>Comma-separated SMS sender IDs (e.g. BankMuscat,bank muscat,BM-ALERT).</summary>
    public string SenderIds { get; set; } = "BankMuscat,bank muscat,BM-ALERT";

    /// <summary>Human-readable rule title (e.g. "BM Mobile Payment Sent").</summary>
    public string RuleName { get; set; } = string.Empty;

    /// <summary>
    /// Normalized transaction type code:
    /// TRANSFER_SENT, TRANSFER_RECEIVED, CARD_PAYMENT, CASH_WITHDRAWAL,
    /// ACCOUNT_CREDIT, INTERNAL_TRANSFER, BILL_PAYMENT, OTHER
    /// </summary>
    public string TransactionType { get; set; } = "CARD_PAYMENT";

    /// <summary>DEBIT or CREDIT.</summary>
    public string Direction { get; set; } = "DEBIT";

    /// <summary>
    /// Regular expression with named capture groups:
    /// (?&lt;currency&gt;...), (?&lt;amount&gt;...), (?&lt;counterparty&gt;...), (?&lt;account&gt;...),
    /// (?&lt;date&gt;...), (?&lt;reference&gt;...), (?&lt;balance&gt;...)
    /// </summary>
    public string RegexPattern { get; set; } = string.Empty;

    /// <summary>
    /// Template for generating clean user-friendly descriptions.
    /// Placeholders: {Counterparty}, {Account}, {Amount}, {Currency}, {BankName}, {Reference}
    /// Examples:
    /// - "Money sent to {Counterparty}"
    /// - "Money received from {Counterparty}"
    /// - "Card payment at {Counterparty}"
    /// - "Cash withdrawal"
    /// </summary>
    public string DescriptionTemplate { get; set; } = string.Empty;

    /// <summary>Fallback description if {Counterparty} is empty or missing.</summary>
    public string FallbackDescription { get; set; } = "Bank transaction";

    /// <summary>Example raw bank SMS or narration used to verify this rule.</summary>
    public string SampleMessage { get; set; } = string.Empty;

    /// <summary>Lower number = higher priority when evaluating rules for a bank.</summary>
    public int Priority { get; set; } = 10;

    /// <summary>Base confidence score (0-100) awarded when this pattern matches.</summary>
    public int BaseConfidence { get; set; } = 95;

    /// <summary>Whether to clean masked bank names/POS codes on the extracted counterparty.</summary>
    public bool CleanCounterparty { get; set; } = true;

    public bool IsActive { get; set; } = true;

    public DateTimeOffset CreatedAt { get; set; } = DateTimeOffset.UtcNow;
    public DateTimeOffset UpdatedAt { get; set; } = DateTimeOffset.UtcNow;
}
