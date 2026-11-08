using System;
using System.Collections.Generic;

namespace ThemarIP.Application.DTOs.Sms;

public class BankMessageParserRuleDto
{
    public Guid? Id { get; set; }
    public string BankCode { get; set; } = "BANK_MUSCAT";
    public string BankName { get; set; } = "Bank Muscat";
    public string SenderIds { get; set; } = "BankMuscat,bank muscat,BM-ALERT";
    public string RuleName { get; set; } = string.Empty;
    public string TransactionType { get; set; } = "CARD_PAYMENT";
    public string Direction { get; set; } = "DEBIT";
    public string RegexPattern { get; set; } = string.Empty;
    public string DescriptionTemplate { get; set; } = "Card payment at {Counterparty}";
    public string FallbackDescription { get; set; } = "Card payment";
    public string SampleMessage { get; set; } = string.Empty;
    public int Priority { get; set; } = 10;
    public int BaseConfidence { get; set; } = 95;
    public bool CleanCounterparty { get; set; } = true;
    public bool IsActive { get; set; } = true;
    public DateTimeOffset? UpdatedAt { get; set; }
}

public class ParseBankMessageRequestDto
{
    public string? BankCode { get; set; }
    public string? Sender { get; set; }
    public string RawMessage { get; set; } = string.Empty;
    public decimal? FallbackAmount { get; set; }
    public string? FallbackCurrency { get; set; }
    public string? FallbackDirection { get; set; }
    public DateTimeOffset? FallbackDate { get; set; }
    public Guid? RuleIdToTest { get; set; }
    public BankMessageParserRuleDto? InlineRule { get; set; }
}

public class ParsedTransactionMessageDto
{
    public Guid? Id { get; set; }
    public Guid? TransactionId { get; set; }
    public Guid? SmsLogId { get; set; }
    public Guid? UserId { get; set; }
    public string OriginalMessage { get; set; } = string.Empty;
    public string GeneratedDescription { get; set; } = string.Empty;
    public string BankCode { get; set; } = "BANK_MUSCAT";
    public string BankName { get; set; } = "Bank Muscat";
    public string TransactionType { get; set; } = "OTHER";
    public string Direction { get; set; } = "DEBIT";
    public decimal Amount { get; set; }
    public string Currency { get; set; } = "OMR";
    public string? CounterpartyName { get; set; }
    public string? RawCounterparty { get; set; }
    public DateTimeOffset? TransactionDate { get; set; }
    public string? AccountNumberMasked { get; set; }
    public string? TransactionReference { get; set; }
    public decimal? BalanceAfter { get; set; }
    public int ConfidenceScore { get; set; }
    public string ReviewStatus { get; set; } = "AUTO_APPROVED";
    public Guid? MatchedRuleId { get; set; }
    public string? MatchedRuleName { get; set; }
    public string DeduplicationKey { get; set; } = string.Empty;
    public bool IsDuplicate { get; set; }
    public List<string> Warnings { get; set; } = new();
    public DateTimeOffset? CreatedAt { get; set; }
}

public class ManualReviewUpdateDto
{
    public string GeneratedDescription { get; set; } = string.Empty;
    public string? TransactionType { get; set; }
    public string? Direction { get; set; }
    public decimal? Amount { get; set; }
    public string? Currency { get; set; }
    public string? CounterpartyName { get; set; }
    public string? AccountNumberMasked { get; set; }
    public string? TransactionReference { get; set; }
    public string ReviewStatus { get; set; } = "MANUALLY_REVIEWED";
}

public class ParserBackfillSummaryDto
{
    public int TotalScanned { get; set; }
    public int NewlyParsed { get; set; }
    public int Updated { get; set; }
    public int HighConfidenceCount { get; set; }
    public int NeedsReviewCount { get; set; }
    public int DuplicatesSkipped { get; set; }
}
