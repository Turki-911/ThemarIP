using System;
using System.Collections.Generic;
using System.Text.Json.Serialization;
using System.Threading;
using System.Threading.Tasks;

namespace ThemarIP.Application.Services;

public interface INboApiService
{
    Task<NboStatementResponse> FetchAccountStatementAsync(string accountNumber, string fromDate, string toDate, CancellationToken ct);
}

// NBO API Response Models

public class NboTokenResponse
{
    [JsonPropertyName("access_token")]
    public string AccessToken { get; set; } = string.Empty;

    [JsonPropertyName("expires_in")]
    public int ExpiresIn { get; set; } = 3600;
}

public class NboStatementResponse
{
    public NboResponseWrapper Response { get; set; } = new();
}

public class NboResponseWrapper
{
    public NboResultInfo ResultInfo { get; set; } = new();
    public NboBody Body { get; set; } = new();
}

public class NboResultInfo
{
    public string ResponseStatus { get; set; } = string.Empty;
    public string ResponseCode { get; set; } = string.Empty;
}

public class NboBody
{
    public List<NboTransaction> AccountStatement { get; set; } = new();
}

public class NboTransaction
{
    public string AccountNumber { get; set; } = string.Empty;
    public string OpeningBalance { get; set; } = string.Empty;
    public string TransactionCode { get; set; } = string.Empty;
    public string TransactionCurrency { get; set; } = string.Empty;
    public string TransactionAmount { get; set; } = string.Empty;
    public string PostingDate { get; set; } = string.Empty;
    public string ValueDate { get; set; } = string.Empty;
    public string DocNumber { get; set; } = string.Empty;
    public string Narration1 { get; set; } = string.Empty;
    public string Narration2 { get; set; } = string.Empty;
    public string Narration3 { get; set; } = string.Empty;
    public string Narration4 { get; set; } = string.Empty;
    public string TransactionCodeDesc { get; set; } = string.Empty;
    public string TransactionType { get; set; } = string.Empty;
}
