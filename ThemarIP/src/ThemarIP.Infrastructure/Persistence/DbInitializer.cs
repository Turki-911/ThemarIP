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
        try
        {
            await context.Database.ExecuteSqlRawAsync("ALTER TABLE BankSmsRules ADD COLUMN Patterns TEXT;");
        }
        catch
        {
            // Column already exists
        }

        // Normalize any legacy SMS rule/pattern names stored on PfmTransactions to the canonical BankName & BankCode
        try
        {
            await context.Database.ExecuteSqlRawAsync(@"
                UPDATE PfmTransactions
                SET BankName = 'Bank Muscat', BankCode = 'BANK_MUSCAT'
                WHERE (BankName LIKE 'Bank Muscat%' OR BankName LIKE 'BM-%' OR BankCode LIKE 'BANK_MUSCAT%' OR BankCode LIKE 'BM-%')
                  AND (BankName != 'Bank Muscat' OR BankCode != 'BANK_MUSCAT');

                UPDATE PfmTransactions
                SET TransactionType = 'Credit'
                WHERE Narration LIKE '%has been credited%' AND Narration NOT LIKE '%is debited%' AND TransactionType != 'Credit';
            ");
        }
        catch
        {
            // Ignore if table not yet created
        }

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

        // Ensure all Omani banks have an active BankSmsRule entry so non-Bank Muscat users (NBO, Ahli Bank, Dhofar, OAB, Sohar, Nizwa, Alizz) are never rejected with NoRule
        var existingBankCodes = await context.BankSmsRules.Select(r => r.BankCode).ToListAsync();
        var defaultBankRules = new (string Code, string Name, string Senders, string Sample)[]
        {
            ("NBO", "National Bank of Oman", "NBO,National Bank of Oman,NBO-ALERT", "Your NBO Card ending 1234 was used for OMR 5.200 at STARBUCKS on 16/10/2026. Avl Bal OMR 340.100"),
            ("AHLI_BANK", "Ahli Bank Oman", "Ahli Bank,AhliBank,AHLIBANK,Ahli Bank Oman", "Your Ahli Bank Card was used for OMR 12.500 at LULU HYPERMARKET on 16/10/2026. Avl Bal OMR 210.000"),
            ("BANK_DHOFAR", "Bank Dhofar", "Bank Dhofar,BankDhofar,BANKDHOFAR", "Your Bank Dhofar Card was used for OMR 4.800 at SHELL on 16/10/2026. Avl Bal OMR 195.400"),
            ("OAB", "Oman Arab Bank", "OAB,Oman Arab Bank,OmanArabBank", "Your OAB Card was used for OMR 8.000 at CARREFOUR on 16/10/2026. Avl Bal OMR 412.000"),
            ("SOHAR_INTL", "Sohar International", "SoharInt,Sohar International,SOHAR", "Your Sohar Card was used for OMR 6.300 at TALABAT on 16/10/2026. Avl Bal OMR 150.250"),
            ("BANK_NIZWA", "Bank Nizwa", "Bank Nizwa,BankNizwa,BANKNIZWA", "Your Bank Nizwa Card was used for OMR 3.100 at COSTA COFFEE on 16/10/2026. Avl Bal OMR 280.000"),
            ("ALIZZ_ISLAMIC", "Alizz Islamic Bank", "Alizz,Alizz Islamic,ALIZZ", "Your Alizz Card was used for OMR 15.000 at OMAN OIL on 16/10/2026. Avl Bal OMR 510.000")
        };

        var genericPattern = @"(?:used\s+for|debited\s+(?:by|with|for)|spent|paid|amount)\s*(?:(?<currency>[A-Z]{2,3})\s*)?(?<amount>[\d,]+(?:\.\d+)?)(?:.*?\bat\s+(?<merchant>(?:(?!\s+on\s+\d|\s+Avl|\.\s*Avl).)+?))?(?:\s+on\s+(?<date>\d{1,2}[/-]\d{1,2}[/-]\d{2,4}(?:\s+\d{1,2}:\d{2}(?::\d{2})?)?))?(?:.*?(?:Avl\s*Bal(?:ance)?|Available\s+(?:limit|balance))\s*(?:[A-Z]{2,3}\s*)?(?<balance>[\d,]+(?:\.\d+)?))?";
        var genericMappings = "{\"amount\":\"amount\",\"merchant\":\"merchant\",\"date\":\"date\",\"balance\":\"balance\",\"currency\":\"currency\"}";

        bool addedAnyBankRule = false;
        foreach (var b in defaultBankRules)
        {
            if (!existingBankCodes.Any(c => string.Equals(c, b.Code, StringComparison.OrdinalIgnoreCase)))
            {
                context.BankSmsRules.Add(new ThemarIP.Domain.Entities.Sms.BankSmsRule
                {
                    Id = Guid.NewGuid(),
                    BankCode = b.Code,
                    BankName = b.Name,
                    SenderIds = b.Senders,
                    Pattern = genericPattern,
                    FieldMappings = genericMappings,
                    SampleMessage = b.Sample,
                    Patterns = $"[{{\"name\":\"Card / Account Transaction\",\"sampleMessage\":\"{b.Sample}\",\"pattern\":{System.Text.Json.JsonSerializer.Serialize(genericPattern)},\"fieldMappings\":{genericMappings},\"defaultType\":\"DEBIT\"}}]",
                    DebitKeywords = "used,debited,withdrawn,purchase,spent,paid,sent",
                    CreditKeywords = "credited,received,deposit,refund,salary",
                    DefaultType = "DEBIT",
                    DefaultCurrency = "OMR",
                    DateFormats = "dd/MM/yyyy HH:mm:ss|dd/MM/yy HH:mm:ss|dd/MM/yyyy HH:mm|dd/MM/yy HH:mm|dd/MM/yyyy|dd/MM/yy",
                    IsActive = true,
                    Version = 1,
                    UpdatedAt = DateTimeOffset.UtcNow,
                    UpdatedBy = "System Seeder"
                });
                addedAnyBankRule = true;
            }
        }
        if (addedAnyBankRule)
        {
            await context.SaveChangesAsync();
        }
    }
}
