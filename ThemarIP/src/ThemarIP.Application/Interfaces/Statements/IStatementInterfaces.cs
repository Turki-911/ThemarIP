using System.IO;
using System.Threading.Tasks;
using ThemarIP.Application.DTOs.Statements;

namespace ThemarIP.Application.Interfaces.Statements;

public interface IBankMuscatPdfParser
{
    StatementResultDto ParsePdf(Stream pdfStream);
}

public interface IStatementExtractionService
{
    Task<StatementResultDto> ProcessUploadAsync(Stream pdfStream);
    Task<bool> ConfirmAndImportAsync(ConfirmStatementRequestDto request);
}

public interface IBankNotificationParserService
{
    Task<ParsedNotificationResultDto> ParseNotificationAsync(IngestNotificationRequestDto request);
    Task<Guid> ConfirmAndSaveNotificationAsync(ConfirmNotificationRequestDto request);
}

public interface IMailboxPullerService
{
    Task<PullMailboxResultDto> PullAndIngestEmailsAsync(PullMailboxRequestDto request);
}
