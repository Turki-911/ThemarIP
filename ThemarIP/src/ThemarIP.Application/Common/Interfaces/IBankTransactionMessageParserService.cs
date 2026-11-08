using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using ThemarIP.Application.DTOs.Sms;

namespace ThemarIP.Application.Common.Interfaces;

public interface IBankTransactionMessageParserService
{
    /// <summary>Parses a raw bank SMS or transaction narration into structured fields + user-friendly description.</summary>
    Task<ParsedTransactionMessageDto> ParseMessageAsync(ParseBankMessageRequestDto request);

    /// <summary>Parses and persists the structured record in ParsedTransactionMessages, with deduplication and review queue support.</summary>
    Task<ParsedTransactionMessageDto> ParseAndStoreAsync(
        ParseBankMessageRequestDto request,
        Guid? userId = null,
        Guid? transactionId = null,
        Guid? smsLogId = null);

    /// <summary>Backfills / refreshes ParsedTransactionMessages for all existing PfmTransactions without altering original records.</summary>
    Task<ParserBackfillSummaryDto> BackfillExistingTransactionsAsync();

    /// <summary>Lists all database-stored bank message parser rules.</summary>
    Task<List<BankMessageParserRuleDto>> GetRulesAsync(string? bankCode = null);

    /// <summary>Creates or updates a bank message parser rule in the database.</summary>
    Task<BankMessageParserRuleDto> SaveRuleAsync(Guid? id, BankMessageParserRuleDto dto);

    /// <summary>Deletes a bank message parser rule.</summary>
    Task<bool> DeleteRuleAsync(Guid id);

    /// <summary>Lists parsed transaction messages (with optional filter by reviewStatus or bankCode).</summary>
    Task<List<ParsedTransactionMessageDto>> GetParsedMessagesAsync(string? reviewStatus = null, string? bankCode = null, int take = 250);

    /// <summary>Manually approves/updates a parsed transaction message in the review queue.</summary>
    Task<ParsedTransactionMessageDto?> ReviewMessageAsync(Guid id, ManualReviewUpdateDto dto);

    /// <summary>Lookup dictionary of TransactionId -> ParsedTransactionMessageDto for enriching transaction lists.</summary>
    Task<Dictionary<Guid, ParsedTransactionMessageDto>> GetParsedLookupByTransactionIdsAsync(IEnumerable<Guid> transactionIds);
}
