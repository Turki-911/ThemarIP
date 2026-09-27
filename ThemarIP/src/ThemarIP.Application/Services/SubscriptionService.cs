using System;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using Microsoft.EntityFrameworkCore;
using ThemarIP.Application.Common.Interfaces;
using ThemarIP.Application.DTOs;
using ThemarIP.Domain.Enums;

namespace ThemarIP.Application.Services;

public interface ISubscriptionService
{
    Task<SubscriptionDto?> GetCurrentSubscriptionForUserAsync(Guid userId, CancellationToken cancellationToken = default);
}

public class SubscriptionService : ISubscriptionService
{
    private readonly IApplicationDbContext _context;

    public SubscriptionService(IApplicationDbContext context)
    {
        _context = context;
    }

    public async Task<SubscriptionDto?> GetCurrentSubscriptionForUserAsync(Guid userId, CancellationToken cancellationToken = default)
    {
        var subscriptions = await _context.Subscriptions
            .Where(s => s.UserId == userId && s.Status == SubscriptionStatus.Active)
            .Select(s => new SubscriptionDto(
                s.Id,
                s.UserId,
                s.Tier,
                s.Status,
                s.StartDate,
                s.EndDate,
                s.Price
            ))
            .ToListAsync(cancellationToken);

        return subscriptions.OrderByDescending(s => s.StartDate).FirstOrDefault();
    }
}
