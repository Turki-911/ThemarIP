using System;
using System.Collections.Generic;
using System.Net.Http;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using Microsoft.Extensions.Configuration;
using ThemarIP.Application.Services;

namespace ThemarIP.Infrastructure.ExternalApis;

public class NboApiService : INboApiService
{
    private readonly IHttpClientFactory _httpClientFactory;
    private readonly INboConfigService _nboConfigService;
    
    private string? _cachedToken;
    private DateTimeOffset _tokenExpiry = DateTimeOffset.MinValue;
    
    public NboApiService(IHttpClientFactory httpClientFactory, INboConfigService nboConfigService)
    {
        _httpClientFactory = httpClientFactory;
        _nboConfigService = nboConfigService;
    }

    private async Task<string> GetTokenAsync(HttpClient client, CancellationToken ct)
    {
        if (!string.IsNullOrEmpty(_cachedToken) && DateTimeOffset.UtcNow < _tokenExpiry)
        {
            return _cachedToken;
        }

        var config = await _nboConfigService.GetConfigAsync(ct);
        var baseUrl = config.BaseUrl;
        var tokenUrl = $"{baseUrl}/oauth2/token";
        var clientId = config.ClientId;
        var clientSecret = config.ClientSecret;

        if (string.IsNullOrEmpty(clientId) || string.IsNullOrEmpty(clientSecret))
        {
            throw new InvalidOperationException("NBO API credentials are not configured.");
        }

        var request = new HttpRequestMessage(HttpMethod.Post, tokenUrl);
        // NBO requires X-IBM-Client-Id and X-IBM-Client-Secret headers for OAuth2
        request.Headers.Add("X-IBM-Client-Id", clientId);
        request.Headers.Add("X-IBM-Client-Secret", clientSecret);
        
        request.Content = new FormUrlEncodedContent(new Dictionary<string, string>
        {
            { "grant_type", "client_credentials" },
            { "scope", "read" }
        });

        var response = await client.SendAsync(request, ct);
        var rawJson = await response.Content.ReadAsStringAsync(ct);

        if (!response.IsSuccessStatusCode)
        {
            throw new InvalidOperationException($"NBO OAuth token request failed with HTTP {(int)response.StatusCode}. Response: {rawJson}");
        }

        // Parse the standard OAuth2 token response
        var tokenResponse = System.Text.Json.JsonSerializer.Deserialize<NboTokenResponse>(rawJson, new System.Text.Json.JsonSerializerOptions
        {
            PropertyNameCaseInsensitive = true
        });

        if (tokenResponse == null || string.IsNullOrEmpty(tokenResponse.AccessToken))
        {
            throw new InvalidOperationException($"Failed to parse NBO OAuth token. Response: {rawJson}");
        }

        _cachedToken = tokenResponse.AccessToken;
        // Token expires in `expires_in` seconds, subtract 60s buffer
        _tokenExpiry = DateTimeOffset.UtcNow.AddSeconds(tokenResponse.ExpiresIn > 60 ? tokenResponse.ExpiresIn - 60 : tokenResponse.ExpiresIn);

        return _cachedToken;
    }

    public async Task<NboStatementResponse> FetchAccountStatementAsync(string accountNumber, string fromDate, string toDate, CancellationToken ct)
    {
        var client = _httpClientFactory.CreateClient("NboApi");
        var token = await GetTokenAsync(client, ct);

        var config = await _nboConfigService.GetConfigAsync(ct);
        var baseUrl = config.BaseUrl;
        var statementUrl = $"{baseUrl}/account/services/statement/fetch";
        var clientId = config.ClientId;
        var clientCode = config.ClientCode;

        var currentDate = DateTime.Now.ToString("ddMMyyyy");
        var currentTime = DateTime.Now.ToString("HHmmssfff");
        var reference = $"THEMAR-{Guid.NewGuid().ToString().Substring(0, 8)}";

        var requestBody = new
        {
            Request = new
            {
                Header = new
                {
                    ClientCode = clientCode,
                    TransactionDate = currentDate,
                    TransactionTime = currentTime,
                    TransactionReference = reference,
                    EndUserIdentifier = ""
                },
                Body = new
                {
                    AccountStatement = new
                    {
                        AccountNumber = accountNumber,
                        FromDate = fromDate,
                        ToDate = toDate,
                        NumberofTxn = "",
                        PageSize = "",
                        BlockStatus = "",
                        BlockResendRef = ""
                    }
                }
            }
        };

        var request = new HttpRequestMessage(HttpMethod.Post, statementUrl);
        request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", token);
        if (!string.IsNullOrEmpty(clientId))
        {
            request.Headers.Add("X-IBM-Client-Id", clientId);
        }
        request.Content = JsonContent.Create(requestBody, options: new System.Text.Json.JsonSerializerOptions
        {
            PropertyNamingPolicy = null // Force PascalCase to match NBO API expectations
        });

        var response = await client.SendAsync(request, ct);

        // Handle 401 — token may have expired, retry once
        if (response.StatusCode == System.Net.HttpStatusCode.Unauthorized)
        {
            _cachedToken = null;
            token = await GetTokenAsync(client, ct);
            request = new HttpRequestMessage(HttpMethod.Post, statementUrl)
            {
                Content = JsonContent.Create(requestBody, options: new System.Text.Json.JsonSerializerOptions
                {
                    PropertyNamingPolicy = null
                })
            };
            request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", token);
            if (!string.IsNullOrEmpty(clientId))
            {
                request.Headers.Add("X-IBM-Client-Id", clientId);
            }
            response = await client.SendAsync(request, ct);
        }

        var rawJson = await response.Content.ReadAsStringAsync(ct);

        if (!response.IsSuccessStatusCode)
        {
            throw new InvalidOperationException($"NBO API request failed with HTTP {(int)response.StatusCode}. Response: {rawJson}");
        }

        var statementResponse = System.Text.Json.JsonSerializer.Deserialize<NboStatementResponse>(rawJson, new System.Text.Json.JsonSerializerOptions
        {
            PropertyNameCaseInsensitive = true
        });

        if (statementResponse == null)
        {
            throw new InvalidOperationException($"Failed to parse NBO statement response. Raw: {rawJson}");
        }

        // Check NBO-level response status
        var resultInfo = statementResponse.Response?.ResultInfo;
        if (resultInfo != null && resultInfo.ResponseStatus == "E")
        {
            throw new InvalidOperationException($"NBO API error: {resultInfo.ResponseCode}");
        }

        return statementResponse;
    }
}
