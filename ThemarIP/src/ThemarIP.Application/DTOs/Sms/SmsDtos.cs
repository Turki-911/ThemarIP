using System;
using System.Collections.Generic;
using System.Threading.Tasks;

namespace ThemarIP.Application.DTOs.Sms;

public class SmsIngestRequestDto
{
    public string Sender { get; set; } = string.Empty;
    public string Message { get; set; } = string.Empty;
    /// <summary>Device receive time, epoch milliseconds (optional).</summary>
    public long? ReceivedAtMs { get; set; }
}

public class SmsExtractedDto
{
    public decimal Amount { get; set; }
    public string Currency { get; set; } = "OMR";
    public string Type { get; set; } = string.Empty; // DEBIT | CREDIT
    public string? Merchant { get; set; }
    public string? Narration { get; set; }
    public string? Reference { get; set; }
    public DateTimeOffset? Date { get; set; }
    public decimal? Balance { get; set; }
}

public class SmsIngestResultDto
{
    public string Status { get; set; } = string.Empty;
    public string Message { get; set; } = string.Empty;
    public Guid? TransactionId { get; set; }
    public SmsExtractedDto? Extracted { get; set; }
}

public class BankSmsRuleDto
{
    public Guid? Id { get; set; }
    public string BankName { get; set; } = string.Empty;
    public string BankCode { get; set; } = string.Empty;
    public string SenderIds { get; set; } = string.Empty;
    public string Pattern { get; set; } = string.Empty;
    public Dictionary<string, string> FieldMappings { get; set; } = new();
    public string DebitKeywords { get; set; } = "debited,withdrawn,purchase,spent,paid";
    public string CreditKeywords { get; set; } = "credited,received,deposit,refund";
    public string DefaultType { get; set; } = string.Empty;
    public string DefaultCurrency { get; set; } = "OMR";
    public string DateFormats { get; set; } = string.Empty;
    public string SampleMessage { get; set; } = string.Empty;
    /// <summary>All message patterns grouped under this bank. The first one mirrors Pattern / FieldMappings / SampleMessage.</summary>
    public List<SmsPatternDto> Patterns { get; set; } = new();
    public bool IsActive { get; set; } = true;
    public int Version { get; set; }
    public DateTimeOffset? UpdatedAt { get; set; }
    public string? UpdatedBy { get; set; }
}

/// <summary>One message format (e.g. "Credit Card", "Transfer Received") inside a bank rule.</summary>
public class SmsPatternDto
{
    public string Name { get; set; } = string.Empty;
    public string SampleMessage { get; set; } = string.Empty;
    public string Pattern { get; set; } = string.Empty;
    public Dictionary<string, string> FieldMappings { get; set; } = new();
    /// <summary>DEBIT / CREDIT, or empty to use the bank's default type.</summary>
    public string DefaultType { get; set; } = string.Empty;
}

public class SmsRuleTestRequestDto
{
    /// <summary>Rule definition to test (need not be saved).</summary>
    public BankSmsRuleDto Rule { get; set; } = new();
    public string SampleMessage { get; set; } = string.Empty;
}

public class SmsRuleTestResultDto
{
    public bool PatternValid { get; set; }
    public bool Matched { get; set; }
    public List<string> Errors { get; set; } = new();
    public Dictionary<string, string?> Groups { get; set; } = new();
    public SmsExtractedDto? Extracted { get; set; }
}

public class SmsLogDto
{
    public Guid Id { get; set; }
    public Guid? UserId { get; set; }
    public string? UserEmail { get; set; }
    public string Sender { get; set; } = string.Empty;
    public string RawMessage { get; set; } = string.Empty;
    public string Status { get; set; } = string.Empty;
    public string Details { get; set; } = string.Empty;
    public string? ExtractedJson { get; set; }
    public Guid? RuleId { get; set; }
    public int? RuleVersion { get; set; }
    public Guid? TransactionId { get; set; }
    public DateTimeOffset CreatedAt { get; set; }
}

public class SmsReprocessResultDto
{
    public int Total { get; set; }
    public int Saved { get; set; }
    public int Skipped { get; set; }
    public int NoMatch { get; set; }
    public int Errors { get; set; }
    public List<string> Details { get; set; } = new();
}

public interface ISmsProcessingService
{
    Task<SmsIngestResultDto> IngestAsync(Guid userId, SmsIngestRequestDto request);
    Task<List<string>> GetActiveSenderIdsAsync(Guid? userId = null);
    SmsRuleTestResultDto Test(SmsRuleTestRequestDto request);
    Task<List<BankSmsRuleDto>> ListRulesAsync();
    Task<BankSmsRuleDto> SaveRuleAsync(Guid? id, BankSmsRuleDto dto, string? changedBy);
    Task<bool> SetActiveAsync(Guid id, bool active, string? changedBy);
    Task<bool> DeleteRuleAsync(Guid id);
    Task<List<SmsLogDto>> GetLogsAsync(int take);
    Task<SmsReprocessResultDto> ReprocessLogsAsync(Guid? logId = null);
}
