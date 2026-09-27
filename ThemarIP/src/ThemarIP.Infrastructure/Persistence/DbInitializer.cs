using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using Microsoft.EntityFrameworkCore;
using ThemarIP.Application.Common.Interfaces;
using ThemarIP.Domain.Entities;
using ThemarIP.Domain.Enums;

namespace ThemarIP.Infrastructure.Persistence;

public static class DbInitializer
{
    public static async Task SeedAsync(ApplicationDbContext context, IPasswordHasher passwordHasher)
    {
        await context.Database.MigrateAsync();

        if (!await context.Users.AnyAsync())
        {
            // Seed 1 Admin User
            var adminUser = new User
            {
                Id = Guid.Parse("11111111-1111-1111-1111-111111111111"),
                Email = "admin@themar.ip",
                FullName = "System Administrator",
                PasswordHash = passwordHasher.HashPassword("AdminPassword123!"),
                Role = UserRole.Admin,
                CreatedAt = DateTimeOffset.UtcNow
            };

            var adminSubscription = new Subscription
            {
                Id = Guid.NewGuid(),
                UserId = adminUser.Id,
                Tier = SubscriptionTier.Enterprise,
                Status = SubscriptionStatus.Active,
                StartDate = DateTimeOffset.UtcNow,
                EndDate = DateTimeOffset.UtcNow.AddYears(10),
                Price = 0.00m,
                CreatedAt = DateTimeOffset.UtcNow
            };

            context.Users.Add(adminUser);
            context.Subscriptions.Add(adminSubscription);
            await context.SaveChangesAsync();
        }

        // Seed Default Category Rules if empty
        if (!await context.CategoryRules.AnyAsync())
        {
            var defaultRules = new List<CategoryRule>
            {
                new() { Keyword = "STARBUCKS", Category = "Coffee", MccCode = "5814", Priority = 1 },
                new() { Keyword = "COSTA", Category = "Coffee", MccCode = "5814", Priority = 1 },
                new() { Keyword = "LULU", Category = "Groceries", MccCode = "5411", Priority = 1 },
                new() { Keyword = "CARREFOUR", Category = "Groceries", MccCode = "5411", Priority = 1 },
                new() { Keyword = "SHELL", Category = "Fuel", MccCode = "5541", Priority = 1 },
                new() { Keyword = "OMAN OIL", Category = "Fuel", MccCode = "5541", Priority = 1 },
                new() { Keyword = "NETFLIX", Category = "Subscriptions", MccCode = "4899", Priority = 1 },
                new() { Keyword = "SPOTIFY", Category = "Subscriptions", MccCode = "4899", Priority = 1 },
                new() { Keyword = "APPLE", Category = "Subscriptions", MccCode = "5734", Priority = 1 },
                new() { Keyword = "GOOGLE", Category = "Digital Services", MccCode = "5734", Priority = 1 },
                new() { Keyword = "TALABAT", Category = "Food Delivery", MccCode = "5812", Priority = 1 },
                new() { Keyword = "TM DONE", Category = "Food Delivery", MccCode = "5812", Priority = 1 },
                new() { Keyword = "OMANTEL", Category = "Telecom", MccCode = "4814", Priority = 1 },
                new() { Keyword = "OOREDOO", Category = "Telecom", MccCode = "4814", Priority = 1 },
                new() { Keyword = "SALARY", Category = "Income", MccCode = "6012", Priority = 1 },
                new() { Keyword = "ATM", Category = "Cash Withdrawal", MccCode = "6011", Priority = 1 },
                new() { Keyword = "TRANSFER", Category = "Bank Transfer", MccCode = "4829", Priority = 1 },
            };

            context.CategoryRules.AddRange(defaultRules);
            await context.SaveChangesAsync();
        }

        // Seed all PFM reference data (idempotent — skips if rows exist)
        await PfmDataSeeder.SeedAsync(context);
    }
}
