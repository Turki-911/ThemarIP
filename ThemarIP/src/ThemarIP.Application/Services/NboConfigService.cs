using System;
using System.Threading;
using System.Threading.Tasks;
using Microsoft.EntityFrameworkCore;
using ThemarIP.Application.Common.Interfaces;
using ThemarIP.Application.DTOs;
using ThemarIP.Domain.Entities;

namespace ThemarIP.Application.Services;

public interface INboConfigService
{
    Task<NboApiConfigDto> GetConfigAsync(CancellationToken cancellationToken = default);
    Task<NboApiConfigDto> UpdateConfigAsync(UpdateNboApiConfigDto dto, CancellationToken cancellationToken = default);
}

public class NboConfigService : INboConfigService
{
    private readonly IApplicationDbContext _context;

    public NboConfigService(IApplicationDbContext context)
    {
        _context = context;
    }

    public async Task<NboApiConfigDto> GetConfigAsync(CancellationToken cancellationToken = default)
    {
        var config = await _context.NboApiConfigs.FirstOrDefaultAsync(cancellationToken);
        if (config == null)
        {
            config = new NboApiConfig();
            _context.NboApiConfigs.Add(config);
            await _context.SaveChangesAsync(cancellationToken);
        }

        return new NboApiConfigDto(
            config.Id,
            config.BaseUrl,
            config.ClientId,
            config.ClientSecret,
            config.ClientCode,
            config.UpdatedAt
        );
    }

    public async Task<NboApiConfigDto> UpdateConfigAsync(UpdateNboApiConfigDto dto, CancellationToken cancellationToken = default)
    {
        var config = await _context.NboApiConfigs.FirstOrDefaultAsync(cancellationToken);
        if (config == null)
        {
            config = new NboApiConfig();
            _context.NboApiConfigs.Add(config);
        }

        config.BaseUrl = dto.BaseUrl;
        config.ClientId = dto.ClientId;
        config.ClientSecret = dto.ClientSecret;
        config.ClientCode = dto.ClientCode;
        config.UpdatedAt = DateTimeOffset.UtcNow;

        await _context.SaveChangesAsync(cancellationToken);

        return new NboApiConfigDto(
            config.Id,
            config.BaseUrl,
            config.ClientId,
            config.ClientSecret,
            config.ClientCode,
            config.UpdatedAt
        );
    }
}
