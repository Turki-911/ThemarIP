using System;

namespace ThemarIP.Application.DTOs;

public record NboApiConfigDto(
    Guid Id,
    string BaseUrl,
    string ClientId,
    string ClientSecret,
    string ClientCode,
    DateTimeOffset UpdatedAt
);

public record UpdateNboApiConfigDto(
    string BaseUrl,
    string ClientId,
    string ClientSecret,
    string ClientCode
);
