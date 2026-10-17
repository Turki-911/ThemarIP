namespace ThemarIP.Domain.Entities.Sms;

/// <summary>
/// Admin-configurable parsing rule for one bank's SMS format.
/// Nothing about a bank's message layout is hardcoded — everything lives here.
/// </summary>
public class BankSmsRule
{
    public Guid Id { get; set; } = Guid.NewGuid();

    public string BankName { get; set; } = string.Empty;

    /// <summary>Originating bank code stored on the resulting transaction (e.g. BANK_MUSCAT).</summary>
    public string BankCode { get; set; } = string.Empty;

    /// <summary>Comma-separated SMS sender IDs this rule applies to (case-insensitive).</summary>
    public string SenderIds { get; set; } = string.Empty;

    /// <summary>Regex with named groups used to extract fields from the message.</summary>
    public string Pattern { get; set; } = string.Empty;

    /// <summary>
    /// JSON map of field -> named regex group, e.g.
    /// {"amount":"amount","type":"type","merchant":"merchant","reference":"ref","date":"date","balance":"balance","currency":"currency"}
    /// </summary>
    public string FieldMappings { get; set; } = "{}";

    /// <summary>Comma-separated keywords that mean DEBIT when found in the "type" group (or whole message if unmapped).</summary>
    public string DebitKeywords { get; set; } = "debited,withdrawn,purchase,spent,paid";

    /// <summary>Comma-separated keywords that mean CREDIT.</summary>
    public string CreditKeywords { get; set; } = "credited,received,deposit,refund";

    /// <summary>Used when no type group/keyword resolves: DEBIT or CREDIT. Empty = fail validation.</summary>
    public string DefaultType { get; set; } = string.Empty;

    public string DefaultCurrency { get; set; } = "OMR";

    /// <summary>Optional .NET date format(s), pipe-separated, for the "date" group (e.g. dd/MM/yyyy HH:mm|dd-MMM-yyyy).</summary>
    public string DateFormats { get; set; } = string.Empty;

    public string SampleMessage { get; set; } = string.Empty;

    /// <summary>
    /// Optional JSON array of message patterns grouped under this bank rule, e.g.
    /// [{"name":"Credit Card","sampleMessage":"...","pattern":"...","fieldMappings":{"amount":"amount"},"defaultType":"DEBIT"}].
    /// When empty, the single <see cref="Pattern"/> / <see cref="FieldMappings"/> / <see cref="SampleMessage"/> are used.
    /// The first entry is always mirrored into those columns for backward compatibility.
    /// </summary>
    public string? Patterns { get; set; }

    public bool IsActive { get; set; } = true;

    /// <summary>Incremented on every change to pattern/mappings; history in <see cref="BankSmsRuleVersion"/>.</summary>
    public int Version { get; set; } = 1;

    public DateTimeOffset CreatedAt { get; set; } = DateTimeOffset.UtcNow;
    public DateTimeOffset UpdatedAt { get; set; } = DateTimeOffset.UtcNow;
    public string? UpdatedBy { get; set; }
}
