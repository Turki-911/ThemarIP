using System;

namespace ThemarIP.Application.DTOs.Statements;

public class IngestNotificationRequestDto
{
    public string SourceType { get; set; } = "SMS"; // SMS or EMAIL
    public string RawMessage { get; set; } = string.Empty;
    public string? EmailSender { get; set; }
    public string? EmailSubject { get; set; }
    public bool IsHtml { get; set; }
    public Guid? UserId { get; set; }
    public bool AutoConfirm { get; set; } = false;
}

public class ParsedNotificationResultDto
{
    public string BankName { get; set; } = "Unknown Bank";
    public string SourceType { get; set; } = "SMS";
    public decimal Amount { get; set; }
    public string Currency { get; set; } = "OMR";
    public string Direction { get; set; } = "DEBIT"; // DEBIT or CREDIT
    public string Narration { get; set; } = string.Empty;
    public DateTimeOffset TransactionDate { get; set; } = DateTimeOffset.UtcNow;
    public string AccountReference { get; set; } = string.Empty;
    public decimal? BalanceAfter { get; set; }
    
    public string? MatchedMerchant { get; set; }
    public Guid? MatchedMerchantId { get; set; }
    public string? Category { get; set; }
    public string? Subcategory { get; set; }
    
    public int Confidence { get; set; } = 100;
    public bool IsDuplicate { get; set; } = false;
    public string ValidationMessage { get; set; } = "Valid";
    public Guid? SavedTransactionId { get; set; }
}

public class ConfirmNotificationRequestDto
{
    public Guid? UserId { get; set; }
    public ParsedNotificationResultDto Transaction { get; set; } = new();
}
