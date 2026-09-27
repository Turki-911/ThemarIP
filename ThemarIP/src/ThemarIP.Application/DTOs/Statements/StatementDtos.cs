using System;
using System.Collections.Generic;

namespace ThemarIP.Application.DTOs.Statements;

public class ParsedTransactionDto
{
    public DateTime PostDate { get; set; }
    public DateTime ValueDate { get; set; }
    public string Narration { get; set; } = string.Empty;
    public decimal Amount { get; set; }
    public string Direction { get; set; } = "DEBIT"; // DEBIT or CREDIT
    public decimal? Debit { get; set; }
    public decimal? Credit { get; set; }
    public decimal Balance { get; set; }
    public decimal? PreviousBalance { get; set; }
    public decimal? ExpectedBalance { get; set; }
    
    // Extraction Integrity & Validation metadata
    public int ExtractionConfidence { get; set; } = 100;
    public string ExtractionStatus { get; set; } = "PASS"; // PASS, EXTRACTION_REVIEW_REQUIRED, FAILED
    public bool IsBalanceValid { get; set; } = true;
    public bool IsDuplicate { get; set; } = false;
    public string ValidationMessage { get; set; } = string.Empty;
}

public class StatementHeaderDto
{
    public string AccountName { get; set; } = string.Empty;
    public string AccountNumber { get; set; } = string.Empty;
    public string Iban { get; set; } = string.Empty;
    public string Currency { get; set; } = string.Empty;
    public string StatementCycle { get; set; } = string.Empty;
    public string StatementDate { get; set; } = string.Empty;
}

public class StatementResultDto
{
    public string TempFileId { get; set; } = string.Empty;
    public StatementHeaderDto Header { get; set; } = new();
    public List<ParsedTransactionDto> Transactions { get; set; } = new();
    public int ExtractionConfidence { get; set; } = 100;
    public string ReconciliationStatus { get; set; } = "RECONCILED";
    public int ValidCount { get; set; }
    public int TotalCount { get; set; }
    public bool HasValidationErrors { get; set; }
    public string? ErrorMessage { get; set; }
}

public class ConfirmStatementRequestDto
{
    public Guid? UserId { get; set; }
    public string TempFileId { get; set; } = string.Empty;
    public StatementHeaderDto Header { get; set; } = new();
    public List<ParsedTransactionDto> Transactions { get; set; } = new();
}

public class SaveMerchantRequestDto
{
    public string Name { get; set; } = string.Empty;
    public string? Mcc { get; set; }
    public Guid? DefaultCategoryId { get; set; }
    public Guid? DefaultSubcategoryId { get; set; }
    public int? DefaultConfidence { get; set; } = 90;
    public string? Status { get; set; } = "active";
    public List<string>? Aliases { get; set; }
}

