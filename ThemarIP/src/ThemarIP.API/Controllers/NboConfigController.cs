using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using System.Threading.Tasks;
using ThemarIP.Application.DTOs;
using ThemarIP.Application.Services;

namespace ThemarIP.API.Controllers;

[ApiController]
[Route("api/admin/nbo-config")]
// [Authorize(Roles = "Admin")] // Uncomment if roles are fully implemented, for now require any auth or we can skip for sandbox
public class NboConfigController : ControllerBase
{
    private readonly INboConfigService _nboConfigService;

    public NboConfigController(INboConfigService nboConfigService)
    {
        _nboConfigService = nboConfigService;
    }

    [HttpGet]
    public async Task<ActionResult<NboApiConfigDto>> GetConfig()
    {
        var config = await _nboConfigService.GetConfigAsync();
        return Ok(config);
    }

    [HttpPut]
    public async Task<ActionResult<NboApiConfigDto>> UpdateConfig([FromBody] UpdateNboApiConfigDto request)
    {
        var config = await _nboConfigService.UpdateConfigAsync(request);
        return Ok(config);
    }
}
