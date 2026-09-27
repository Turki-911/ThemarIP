using System;
using System.Collections.Generic;

namespace ThemarIP.Application.DTOs;

public record TransactionDto(
    Guid Id,
    Guid StatementUploadId,
    Guid UserId,
    DateTimeOffset TransactionDate,
    decimal Amount,
    string Currency,
    string Category,
    string Description,
    string? MccCode
);

public record CategorySummaryDto(
    string Category,
    decimal TotalAmount,
    int TransactionCount
);

public record TransactionSummaryDto(
    int TotalTransactions,
    decimal TotalAmount,
    string Currency,
    List<CategorySummaryDto> TopCategories
);
