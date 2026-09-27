using System;
using ThemarIP.Domain.Enums;

namespace ThemarIP.Application.DTOs;

public record SubscriptionDto(
    Guid Id,
    Guid UserId,
    SubscriptionTier Tier,
    SubscriptionStatus Status,
    DateTimeOffset StartDate,
    DateTimeOffset EndDate,
    decimal Price
);
