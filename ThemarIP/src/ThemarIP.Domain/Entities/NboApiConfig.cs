using System;

namespace ThemarIP.Domain.Entities;

public class NboApiConfig
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public string BaseUrl { get; set; } = "https://apisandbox.nbogateway.om:9443/nbo/nbo-gateway/v1";
    public string ClientId { get; set; } = string.Empty;
    public string ClientSecret { get; set; } = string.Empty;
    public string ClientCode { get; set; } = string.Empty;
    public DateTimeOffset UpdatedAt { get; set; } = DateTimeOffset.UtcNow;
}
