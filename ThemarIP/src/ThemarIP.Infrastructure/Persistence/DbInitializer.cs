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
                new() { Keyword = "STARBUCKS", Category = "Coffee Shops", MccCode = "5814", Priority = 95 },
                new() { Keyword = "COSTA", Category = "Coffee Shops", MccCode = "5814", Priority = 95 },
                new() { Keyword = "LULU", Category = "Groceries", MccCode = "5411", Priority = 95 },
                new() { Keyword = "CARREFOUR", Category = "Groceries", MccCode = "5411", Priority = 95 },
                new() { Keyword = "SHELL", Category = "Fuel", MccCode = "5541", Priority = 95 },
                new() { Keyword = "OMAN OIL", Category = "Fuel", MccCode = "5541", Priority = 95 },
                new() { Keyword = "NETFLIX", Category = "Subscriptions", MccCode = "4899", Priority = 95 },
                new() { Keyword = "SPOTIFY", Category = "Subscriptions", MccCode = "4899", Priority = 95 },
                new() { Keyword = "APPLE", Category = "Subscriptions", MccCode = "5734", Priority = 90 },
                new() { Keyword = "GOOGLE", Category = "Subscriptions", MccCode = "5734", Priority = 90 },
                new() { Keyword = "TALABAT", Category = "Fast Food", MccCode = "5812", Priority = 95 },
                new() { Keyword = "TM DONE", Category = "Fast Food", MccCode = "5812", Priority = 95 },
                new() { Keyword = "OMANTEL", Category = "Telecom", MccCode = "4814", Priority = 95 },
                new() { Keyword = "OOREDOO", Category = "Telecom", MccCode = "4814", Priority = 95 },
                new() { Keyword = "SALARY", Category = "Income", MccCode = "6012", Priority = 95 },
                new() { Keyword = "ATM", Category = "ATM Withdrawal", MccCode = "6011", Priority = 90 },
                new() { Keyword = "TRANSFER", Category = "Internal Transfer", MccCode = "4829", Priority = 85 },
            };

            context.CategoryRules.AddRange(defaultRules);
            await context.SaveChangesAsync();
        }

        // Seed all PFM reference data (idempotent — skips if rows exist)
        await PfmDataSeeder.SeedAsync(context);

        // Normalize category icons, merchant default subcategories, and legacy rule category mappings
        try
        {
            await context.Database.ExecuteSqlRawAsync(@"
                UPDATE PfmCategories SET Icon = 'briefcase', DisplayOrder = 11 WHERE Name = 'Business' AND ParentId IS NULL AND Icon = 'Work';
                UPDATE PfmCategories SET DisplayOrder = 2 WHERE Name = 'Groceries' AND ParentId IS NOT NULL AND DisplayOrder = 99;
                DELETE FROM PfmMerchantAliases WHERE upper(AliasText) IN ('SALA');

                UPDATE CategoryRules SET Category = 'Coffee Shops', Priority = 95 WHERE Category = 'Coffee';
                UPDATE CategoryRules SET Category = 'Fast Food', Priority = 95 WHERE Category = 'Food Delivery';
                UPDATE CategoryRules SET Category = 'Internal Transfer', Priority = 85 WHERE Category = 'Bank Transfer';
                UPDATE CategoryRules SET Category = 'Subscriptions', Priority = 90 WHERE Category = 'Digital Services';
                UPDATE CategoryRules SET Category = 'ATM Withdrawal', Priority = 90 WHERE Category = 'Cash Withdrawal';
                DELETE FROM UserProfiles WHERE UserId NOT IN (SELECT Id FROM Users);
            ");
        }
        catch
        {
            // Ignore if any table not yet created
        }

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
            ("ALIZZ_ISLAMIC", "Alizz Islamic Bank", "Alizz,Alizz Islamic,ALIZZ", "Your Alizz Card was used for OMR 15.000 at OMAN OIL on 16/10/2026. Avl Bal OMR 510.000"),
            ("AMWAL_PAY", "AmwalPay", "AmwalPay,Amwal,AMWAL", "Your AmwalPay wallet was debited by OMR 5.200 at VOX CINEMAS on 16/10/2026. Avl Bal OMR 45.000"),
            ("OMPAY", "OMPay", "OMPay,OM Pay,OMPAY", "Your OMPay wallet paid OMR 2.500 at STARBUCKS on 16/10/2026. Avl Bal OMR 38.500"),
            ("THAWANI", "Thawani", "Thawani,Thawani Pay,THAWANI", "Your Thawani wallet was used for OMR 7.000 at LULU HYPERMARKET on 16/10/2026. Avl Bal OMR 82.000"),
            ("WALITII", "Walitii", "Walitii,Waliti,WALITII", "Your Walitii account paid OMR 4.000 at TALABAT on 16/10/2026. Avl Bal OMR 25.000"),
            ("PAYMOB", "Paymob", "Paymob,PayMob,PAYMOB", "Your Paymob payment of OMR 18.000 at ZARA on 16/10/2026 was successful. Avl Bal OMR 120.000")
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

        // ── Create & Seed Bank Transaction Message Parser Tables (Additive, Preserves All Existing Records) ──
        try
        {
            await context.Database.ExecuteSqlRawAsync(@"
                CREATE TABLE IF NOT EXISTS BankMessageParserRules (
                    Id TEXT NOT NULL PRIMARY KEY,
                    BankCode TEXT NOT NULL,
                    BankName TEXT NOT NULL,
                    SenderIds TEXT NOT NULL,
                    RuleName TEXT NOT NULL,
                    TransactionType TEXT NOT NULL,
                    Direction TEXT NOT NULL,
                    RegexPattern TEXT NOT NULL,
                    DescriptionTemplate TEXT NOT NULL,
                    FallbackDescription TEXT NOT NULL,
                    SampleMessage TEXT NOT NULL,
                    Priority INTEGER NOT NULL DEFAULT 10,
                    BaseConfidence INTEGER NOT NULL DEFAULT 95,
                    CleanCounterparty INTEGER NOT NULL DEFAULT 1,
                    IsActive INTEGER NOT NULL DEFAULT 1,
                    CreatedAt TEXT NOT NULL,
                    UpdatedAt TEXT NOT NULL
                );

                CREATE INDEX IF NOT EXISTS IX_BankMessageParserRules_BankCode ON BankMessageParserRules (BankCode);

                CREATE TABLE IF NOT EXISTS ParsedTransactionMessages (
                    Id TEXT NOT NULL PRIMARY KEY,
                    TransactionId TEXT NULL,
                    SmsLogId TEXT NULL,
                    UserId TEXT NULL,
                    OriginalMessage TEXT NOT NULL,
                    GeneratedDescription TEXT NOT NULL,
                    BankCode TEXT NOT NULL,
                    BankName TEXT NOT NULL,
                    TransactionType TEXT NOT NULL,
                    Direction TEXT NOT NULL,
                    Amount NUMERIC NOT NULL,
                    Currency TEXT NOT NULL,
                    CounterpartyName TEXT NULL,
                    RawCounterparty TEXT NULL,
                    TransactionDate TEXT NULL,
                    AccountNumberMasked TEXT NULL,
                    TransactionReference TEXT NULL,
                    BalanceAfter NUMERIC NULL,
                    ConfidenceScore INTEGER NOT NULL DEFAULT 100,
                    ReviewStatus TEXT NOT NULL DEFAULT 'AUTO_APPROVED',
                    MatchedRuleId TEXT NULL,
                    MatchedRuleName TEXT NULL,
                    DeduplicationKey TEXT NOT NULL,
                    CreatedAt TEXT NOT NULL,
                    UpdatedAt TEXT NOT NULL
                );

                CREATE INDEX IF NOT EXISTS IX_ParsedTransactionMessages_TransactionId ON ParsedTransactionMessages (TransactionId);
                CREATE INDEX IF NOT EXISTS IX_ParsedTransactionMessages_DeduplicationKey ON ParsedTransactionMessages (DeduplicationKey);
            ");
        }
        catch
        {
            // Ignore if already exists
        }

        if (!await context.BankMessageParserRules.AnyAsync())
        {
            var now = DateTimeOffset.UtcNow;
            var parserRules = new List<ThemarIP.Domain.Entities.Sms.BankMessageParserRule>
            {
                // 1. Bank Muscat — Mobile Payment Sent (SMS)
                new()
                {
                    BankCode = "BANK_MUSCAT",
                    BankName = "Bank Muscat",
                    SenderIds = "BankMuscat,bank muscat,BM-ALERT",
                    RuleName = "BM SMS — Mobile Payment Sent",
                    TransactionType = "TRANSFER_SENT",
                    Direction = "DEBIT",
                    RegexPattern = @"You have sent\s+(?<currency>[A-Z]{3})\s*(?<amount>\d+(?:[.,]\d+)?)\s+to\s+(?<counterparty>.+?)\s+from your a/c\s+(?<account>[0-9X*#]+)(?:\s+on\s+(?<date>\d{1,2}[/-]\d{1,2}[/-]\d{2,4}(?:\s+\d{1,2}:\d{2}(?::\d{2})?)?))?.*?(?:Txn Id\s+(?<reference>[A-Z0-9]+))?.*?(?:(?:Avl Bal|Available Balance)\s+(?:[A-Z]{3}\s*)?(?<balance>\d+(?:[.,]\d+)?))?",
                    DescriptionTemplate = "Money sent to {Counterparty}",
                    FallbackDescription = "Money sent",
                    SampleMessage = "Dear Customer, You have sent OMR 100.000 to ALI #######################AHRI from your a/c 0468XXXXXXXX0033 on 26/10/2026 18:25:24 using Mobile Payment services. Txn Id BMCT015840785480. Avl Bal OMR 11.711.",
                    Priority = 1,
                    BaseConfidence = 98,
                    CleanCounterparty = true,
                    IsActive = true,
                    CreatedAt = now,
                    UpdatedAt = now
                },
                // 2. Bank Muscat — Mobile Payment Received (SMS)
                new()
                {
                    BankCode = "BANK_MUSCAT",
                    BankName = "Bank Muscat",
                    SenderIds = "BankMuscat,bank muscat,BM-ALERT",
                    RuleName = "BM SMS — Mobile Payment Received",
                    TransactionType = "TRANSFER_RECEIVED",
                    Direction = "CREDIT",
                    RegexPattern = @"You have received\s+(?<currency>[A-Z]{3})\s*(?<amount>\d+(?:[.,]\d+)?)\s+from\s+(?<counterparty>.+?)(?:\s+in your a/c\s+(?<account>[0-9X*#]+)|\.\.\.|$)(?:.*?(?:on\s+(?<date>\d{1,2}[/-]\d{1,2}[/-]\d{2,4}(?:\s+\d{1,2}:\d{2}(?::\d{2})?)?)))?.*?(?:Txn Id\s+(?<reference>[A-Z0-9]+))?.*?(?:(?:Avl Bal|Available Balance)\s+(?:[A-Z]{3}\s*)?(?<balance>\d+(?:[.,]\d+)?))?",
                    DescriptionTemplate = "Money received from {Counterparty}",
                    FallbackDescription = "Money received",
                    SampleMessage = "Dear Customer, You have received OMR 0.100 from TURKI ALI SULAIMAN AL BAHRI in your a/c 0312XXXXXXXX0014 using Mobile Payment services . Txn Id BMCT015700338903. Avl Bal OMR 2521.281.",
                    Priority = 2,
                    BaseConfidence = 98,
                    CleanCounterparty = true,
                    IsActive = true,
                    CreatedAt = now,
                    UpdatedAt = now
                },
                // 3. Bank Muscat — Credit / Debit Card Payment at Merchant (SMS)
                new()
                {
                    BankCode = "BANK_MUSCAT",
                    BankName = "Bank Muscat",
                    SenderIds = "BankMuscat,bank muscat,BM-ALERT",
                    RuleName = "BM SMS — Card Payment at Merchant",
                    TransactionType = "CARD_PAYMENT",
                    Direction = "DEBIT",
                    RegexPattern = @"Card(?:\s+of\s+a/c)?\s+(?<account>[0-9X*#]+)\s+used for\s+(?<currency>[A-Z]{3})\s*(?<amount>\d+(?:[.,]\d+)?)\s+at\s+(?<counterparty>.+?)(?:\s+on\s+(?<date>\d{1,2}[/-]\d{1,2}[/-]\d{2,4}(?:\s+\d{1,2}:\d{2}(?::\d{2})?)?)|\.\.\.|$).*?(?:(?:Available limit|Avl Bal|Available Balance)\s+(?:[A-Z]{3}\s*)?(?<balance>\d+(?:[.,]\d+)?))?",
                    DescriptionTemplate = "Card payment at {Counterparty}",
                    FallbackDescription = "Card payment",
                    SampleMessage = "Card 420460******0292 used for OMR 3.160 at COFFEE STORE on 15/10/2026 08:24:35. Available limit OMR 875.250.",
                    Priority = 3,
                    BaseConfidence = 98,
                    CleanCounterparty = true,
                    IsActive = true,
                    CreatedAt = now,
                    UpdatedAt = now
                },
                // 4. Bank Muscat — Cash Withdrawal (ATM SMS)
                new()
                {
                    BankCode = "BANK_MUSCAT",
                    BankName = "Bank Muscat",
                    SenderIds = "BankMuscat,bank muscat,BM-ALERT",
                    RuleName = "BM SMS — ATM Cash Withdrawal",
                    TransactionType = "CASH_WITHDRAWAL",
                    Direction = "DEBIT",
                    RegexPattern = @"(?:(?<currency>[A-Z]{3})\s*(?<amount>\d+(?:[.,]\d+)?)\s+(?:is\s+|has\s+been\s+)?withdrawn|Cash\s+withdrawal(?:\s+of\s+(?<currency2>[A-Z]{3})\s*(?<amount2>\d+(?:[.,]\d+)?))?|ATM\s+Withdrawal).*?(?:(?:Card|a/c|A/C)\s+(?<account>[0-9X*#]+))?.*?(?:on\s+(?<date>\d{1,2}[/-]\d{1,2}[/-]\d{2,4}(?:\s+\d{1,2}:\d{2}(?::\d{2})?)?))?.*?(?:(?:Avl Bal|Available Balance)\s+(?:[A-Z]{3}\s*)?(?<balance>\d+(?:[.,]\d+)?))?",
                    DescriptionTemplate = "Cash withdrawal",
                    FallbackDescription = "Cash withdrawal",
                    SampleMessage = "OMR 50.000 withdrawn from ATM AL KHUWAIR using Card 420460******0292 on 16/10/2026 14:20:00. Avl Bal OMR 825.250.",
                    Priority = 4,
                    BaseConfidence = 97,
                    CleanCounterparty = true,
                    IsActive = true,
                    CreatedAt = now,
                    UpdatedAt = now
                },
                // 5. Bank Muscat — Internal Account-to-Account Transfer (SMS)
                new()
                {
                    BankCode = "BANK_MUSCAT",
                    BankName = "Bank Muscat",
                    SenderIds = "BankMuscat,bank muscat,BM-ALERT",
                    RuleName = "BM SMS — Internal Account Transfer",
                    TransactionType = "INTERNAL_TRANSFER",
                    Direction = "DEBIT",
                    RegexPattern = @"(?<currency>[A-Z]{3})\s*(?<amount>\d+(?:[.,]\d+)?)\s+is debited from your\s+[Aa]/[Cc]\s+(?<account>[0-9X*#]+)\s+and credited to your\s+[Aa]/[Cc]\s+(?<counterparty>[0-9X*#]+)(?:\s+on\s+(?<date>\d{1,2}[/-]\d{1,2}[/-]\d{2,4}(?:\s+\d{1,2}:\d{2}(?::\d{2})?)?))?",
                    DescriptionTemplate = "Transfer to own account",
                    FallbackDescription = "Transfer between accounts",
                    SampleMessage = "OMR 1035.680 is debited from your A/C 0312XXXXXXXX0014 and credited to your A/C 0312XXXXXXXX0038 on 16/10/2026 09:53:32.",
                    Priority = 5,
                    BaseConfidence = 98,
                    CleanCounterparty = false,
                    IsActive = true,
                    CreatedAt = now,
                    UpdatedAt = now
                },
                // 6. Bank Muscat — Account Credited / Salary / Deposit (SMS)
                new()
                {
                    BankCode = "BANK_MUSCAT",
                    BankName = "Bank Muscat",
                    SenderIds = "BankMuscat,bank muscat,BM-ALERT",
                    RuleName = "BM SMS — Account Credit / Deposit",
                    TransactionType = "ACCOUNT_CREDIT",
                    Direction = "CREDIT",
                    RegexPattern = @"(?<currency>[A-Z]{3})\s*(?<amount>\d+(?:[.,]\d+)?)\s+has been credited to your\s+[Aa]/[Cc]\s+(?<account>[0-9X*#]+)(?:\s+from\s+(?<counterparty>.+?))?(?:\s+on\s+(?<date>\d{1,2}[/-]\d{1,2}[/-]\d{2,4}(?:\s+\d{1,2}:\d{2}(?::\d{2})?)?))?.*?(?:(?:New Available Balance is|Avl Bal|Available Balance)\s+(?:[A-Z]{3}\s*)?(?<balance>\d+(?:[.,]\d+)?))?",
                    DescriptionTemplate = "Money received from {Counterparty}",
                    FallbackDescription = "Money credited to account",
                    SampleMessage = "OMR 1035.680 has been credited to your a/c 0312XXXXXXXX0014 on 16/10/2026 09:40:48. New Available Balance is OMR 3557.061.",
                    Priority = 6,
                    BaseConfidence = 97,
                    CleanCounterparty = true,
                    IsActive = true,
                    CreatedAt = now,
                    UpdatedAt = now
                },
                // 7. Bank Muscat — Statement Mobile Payment Sent ("Mobile Payment for BMCT... NAME FT...")
                new()
                {
                    BankCode = "BANK_MUSCAT",
                    BankName = "Bank Muscat",
                    SenderIds = "BankMuscat,bank muscat",
                    RuleName = "BM Statement — Mobile Payment Sent",
                    TransactionType = "TRANSFER_SENT",
                    Direction = "DEBIT",
                    RegexPattern = @"^Mobile Payment for\s+(?<reference>BMCT\d+)\s+(?<counterparty>.+?)(?:\s+FT\d+)?$",
                    DescriptionTemplate = "Money sent to {Counterparty}",
                    FallbackDescription = "Money sent",
                    SampleMessage = "Mobile Payment for BMCT014706782281 IBRAHIM MOHAMED ELNABAWI FT26200081709810",
                    Priority = 7,
                    BaseConfidence = 96,
                    CleanCounterparty = true,
                    IsActive = true,
                    CreatedAt = now,
                    UpdatedAt = now
                },
                // 8. Bank Muscat — Statement Mobile Payment Received ("Mobile Payment from BMCT... BM FT...")
                new()
                {
                    BankCode = "BANK_MUSCAT",
                    BankName = "Bank Muscat",
                    SenderIds = "BankMuscat,bank muscat",
                    RuleName = "BM Statement — Mobile Payment Received",
                    TransactionType = "TRANSFER_RECEIVED",
                    Direction = "CREDIT",
                    RegexPattern = @"^Mobile Payment from\s+(?<reference>BMCT\d+)\s+(?<counterparty>.+?)(?:\s+FT\d+)?$",
                    DescriptionTemplate = "Money received from {Counterparty}",
                    FallbackDescription = "Money received via Mobile Payment",
                    SampleMessage = "Mobile Payment from BMCT014355165409 BM FT26168136980160",
                    Priority = 8,
                    BaseConfidence = 95,
                    CleanCounterparty = true,
                    IsActive = true,
                    CreatedAt = now,
                    UpdatedAt = now
                },
                // 9. Bank Muscat — Statement Bank Transfer ("Transfer NAME LFT...")
                new()
                {
                    BankCode = "BANK_MUSCAT",
                    BankName = "Bank Muscat",
                    SenderIds = "BankMuscat,bank muscat",
                    RuleName = "BM Statement — Outgoing Bank Transfer",
                    TransactionType = "TRANSFER_SENT",
                    Direction = "DEBIT",
                    RegexPattern = @"^Transfer\s+(?<counterparty>.+?)\s+(?<reference>(?:L?FT|BMCT)[A-Z0-9]+)$",
                    DescriptionTemplate = "Money sent to {Counterparty}",
                    FallbackDescription = "Money sent",
                    SampleMessage = "Transfer QABS ALI SULAIMAN AL BAHRI LFT26202QZHGP9YF",
                    Priority = 9,
                    BaseConfidence = 96,
                    CleanCounterparty = true,
                    IsActive = true,
                    CreatedAt = now,
                    UpdatedAt = now
                },
                // 10. Bank Muscat — Statement POS Card Purchase ("POS 733017-ARABICA CAFE PO BOX 73 MUSC POS2622807BJJ8VCB")
                new()
                {
                    BankCode = "BANK_MUSCAT",
                    BankName = "Bank Muscat",
                    SenderIds = "BankMuscat,bank muscat",
                    RuleName = "BM Statement — POS Card Payment",
                    TransactionType = "CARD_PAYMENT",
                    Direction = "DEBIT",
                    RegexPattern = @"^POS\s+(?:\d+-)?(?<counterparty>.+?)(?:\s+(?<reference>POS[A-Z0-9]+)|\s+\d+[.,]\d+@\S+)?$",
                    DescriptionTemplate = "Card payment at {Counterparty}",
                    FallbackDescription = "Card payment",
                    SampleMessage = "POS 733017-ARABICA CAFE PO BOX 73 MUSC POS2622807BJJ8VCB",
                    Priority = 10,
                    BaseConfidence = 96,
                    CleanCounterparty = true,
                    IsActive = true,
                    CreatedAt = now,
                    UpdatedAt = now
                },
                // 11. Extensible Omani Banks — NBO Card Payment
                new()
                {
                    BankCode = "NBO",
                    BankName = "National Bank of Oman",
                    SenderIds = "NBO,National Bank of Oman,NBO-ALERT",
                    RuleName = "NBO SMS — Card Payment",
                    TransactionType = "CARD_PAYMENT",
                    Direction = "DEBIT",
                    RegexPattern = @"Card(?:\s+ending)?\s+(?<account>[0-9X*#]+)\s+(?:was\s+)?used for\s+(?<currency>[A-Z]{3})\s*(?<amount>\d+(?:[.,]\d+)?)\s+at\s+(?<counterparty>.+?)(?:\s+on\s+(?<date>\d{1,2}[/-]\d{1,2}[/-]\d{2,4}(?:\s+\d{1,2}:\d{2}(?::\d{2})?)?)|\.\s*Avl|$).*?(?:(?:Avl Bal|Available Balance)\s+(?:[A-Z]{3}\s*)?(?<balance>\d+(?:[.,]\d+)?))?",
                    DescriptionTemplate = "Card payment at {Counterparty}",
                    FallbackDescription = "Card payment",
                    SampleMessage = "Your NBO Card ending 1234 was used for OMR 5.200 at CARREFOUR on 16/10/2026. Avl Bal OMR 340.100",
                    Priority = 20,
                    BaseConfidence = 95,
                    CleanCounterparty = true,
                    IsActive = true,
                    CreatedAt = now,
                    UpdatedAt = now
                },
                // 12. Extensible Omani Banks — Bank Dhofar Card Payment
                new()
                {
                    BankCode = "BANK_DHOFAR",
                    BankName = "Bank Dhofar",
                    SenderIds = "Bank Dhofar,BankDhofar,BANKDHOFAR",
                    RuleName = "Bank Dhofar SMS — Card Payment",
                    TransactionType = "CARD_PAYMENT",
                    Direction = "DEBIT",
                    RegexPattern = @"Card(?:\s+(?<account>[0-9X*#]+))?\s+(?:was\s+)?used for\s+(?<currency>[A-Z]{3})\s*(?<amount>\d+(?:[.,]\d+)?)\s+at\s+(?<counterparty>.+?)(?:\s+on\s+(?<date>\d{1,2}[/-]\d{1,2}[/-]\d{2,4}(?:\s+\d{1,2}:\d{2}(?::\d{2})?)?)|\.\s*Avl|$).*?(?:(?:Avl Bal|Available Balance)\s+(?:[A-Z]{3}\s*)?(?<balance>\d+(?:[.,]\d+)?))?",
                    DescriptionTemplate = "Card payment at {Counterparty}",
                    FallbackDescription = "Card payment",
                    SampleMessage = "Your Bank Dhofar Card was used for OMR 4.800 at SHELL on 16/10/2026. Avl Bal OMR 195.400",
                    Priority = 21,
                    BaseConfidence = 95,
                    CleanCounterparty = true,
                    IsActive = true,
                    CreatedAt = now,
                    UpdatedAt = now
                }
            };

            context.BankMessageParserRules.AddRange(parserRules);
            await context.SaveChangesAsync();
        }

        // Ensure Budgeting schema & views exist (idempotent)
        await EnsureBudgetingSchemaAsync(context);
    }

    private static async Task EnsureBudgetingSchemaAsync(ApplicationDbContext context)
    {
        try
        {
            await context.Database.ExecuteSqlRawAsync(@"
                CREATE TABLE IF NOT EXISTS ""budget_settings"" (
                    ""Id"" TEXT NOT NULL CONSTRAINT ""PK_budget_settings"" PRIMARY KEY,
                    ""UserId"" TEXT NOT NULL,
                    ""TotalMonthlyBudget"" BIGINT NOT NULL DEFAULT 0,
                    ""PeriodStartDay"" INTEGER NOT NULL DEFAULT 1,
                    ""RolloverEnabled"" INTEGER NOT NULL DEFAULT 1,
                    ""Currency"" TEXT NOT NULL DEFAULT 'OMR',
                    ""CreatedAt"" TEXT NOT NULL,
                    ""UpdatedAt"" TEXT NOT NULL,
                    CONSTRAINT ""FK_budget_settings_Users_UserId"" FOREIGN KEY (""UserId"") REFERENCES ""Users"" (""Id"") ON DELETE CASCADE,
                    CONSTRAINT ""CK_budget_settings_TotalMonthlyBudget"" CHECK (""TotalMonthlyBudget"" >= 0),
                    CONSTRAINT ""CK_budget_settings_PeriodStartDay"" CHECK (""PeriodStartDay"" BETWEEN 1 AND 28),
                    CONSTRAINT ""CK_budget_settings_RolloverEnabled"" CHECK (""RolloverEnabled"" IN (0, 1))
                );
                CREATE UNIQUE INDEX IF NOT EXISTS ""UX_budget_settings_UserId"" ON ""budget_settings"" (""UserId"");

                CREATE TABLE IF NOT EXISTS ""budget_categories"" (
                    ""Id"" TEXT NOT NULL CONSTRAINT ""PK_budget_categories"" PRIMARY KEY,
                    ""UserId"" TEXT NOT NULL,
                    ""CategoryId"" TEXT NOT NULL,
                    ""BudgetAmount"" BIGINT NOT NULL,
                    ""EffectiveFrom"" TEXT NOT NULL,
                    ""EffectiveTo"" TEXT NULL,
                    ""CreatedAt"" TEXT NOT NULL,
                    ""UpdatedAt"" TEXT NOT NULL,
                    CONSTRAINT ""FK_budget_categories_Users_UserId"" FOREIGN KEY (""UserId"") REFERENCES ""Users"" (""Id"") ON DELETE CASCADE,
                    CONSTRAINT ""FK_budget_categories_PfmCategories_CategoryId"" FOREIGN KEY (""CategoryId"") REFERENCES ""PfmCategories"" (""Id"") ON DELETE RESTRICT,
                    CONSTRAINT ""CK_budget_categories_BudgetAmount"" CHECK (""BudgetAmount"" >= 0),
                    CONSTRAINT ""CK_budget_categories_EffectiveRange"" CHECK (""EffectiveTo"" IS NULL OR ""EffectiveTo"" >= ""EffectiveFrom"")
                );
                CREATE UNIQUE INDEX IF NOT EXISTS ""UX_budget_categories_Active"" ON ""budget_categories"" (""UserId"", ""CategoryId"") WHERE ""EffectiveTo"" IS NULL;
                CREATE UNIQUE INDEX IF NOT EXISTS ""UX_budget_categories_User_Cat_From"" ON ""budget_categories"" (""UserId"", ""CategoryId"", ""EffectiveFrom"");
                CREATE INDEX IF NOT EXISTS ""IX_budget_categories_CategoryId"" ON ""budget_categories"" (""CategoryId"");

                CREATE TABLE IF NOT EXISTS ""budget_excluded_categories"" (
                    ""Id"" TEXT NOT NULL CONSTRAINT ""PK_budget_excluded_categories"" PRIMARY KEY,
                    ""UserId"" TEXT NOT NULL,
                    ""CategoryId"" TEXT NOT NULL,
                    ""CreatedAt"" TEXT NOT NULL,
                    ""UpdatedAt"" TEXT NOT NULL,
                    CONSTRAINT ""FK_budget_excluded_categories_Users_UserId"" FOREIGN KEY (""UserId"") REFERENCES ""Users"" (""Id"") ON DELETE CASCADE,
                    CONSTRAINT ""FK_budget_excluded_categories_PfmCategories_CategoryId"" FOREIGN KEY (""CategoryId"") REFERENCES ""PfmCategories"" (""Id"") ON DELETE CASCADE
                );
                CREATE UNIQUE INDEX IF NOT EXISTS ""UX_budget_excluded_categories_User_Cat"" ON ""budget_excluded_categories"" (""UserId"", ""CategoryId"");

                CREATE TABLE IF NOT EXISTS ""budget_periods"" (
                    ""Id"" TEXT NOT NULL CONSTRAINT ""PK_budget_periods"" PRIMARY KEY,
                    ""UserId"" TEXT NOT NULL,
                    ""PeriodStart"" TEXT NOT NULL,
                    ""PeriodEnd"" TEXT NOT NULL,
                    ""BaseTotal"" BIGINT NOT NULL DEFAULT 0,
                    ""RolledAmount"" BIGINT NOT NULL DEFAULT 0,
                    ""SpentTotalSnapshot"" BIGINT NULL,
                    ""CommittedTotalSnapshot"" BIGINT NULL,
                    ""Status"" TEXT NOT NULL DEFAULT 'open',
                    ""ClosedAt"" TEXT NULL,
                    ""CreatedAt"" TEXT NOT NULL,
                    ""UpdatedAt"" TEXT NOT NULL,
                    CONSTRAINT ""FK_budget_periods_Users_UserId"" FOREIGN KEY (""UserId"") REFERENCES ""Users"" (""Id"") ON DELETE CASCADE,
                    CONSTRAINT ""CK_budget_periods_BaseTotal"" CHECK (""BaseTotal"" >= 0),
                    CONSTRAINT ""CK_budget_periods_PeriodOrder"" CHECK (""PeriodEnd"" > ""PeriodStart""),
                    CONSTRAINT ""CK_budget_periods_Status"" CHECK (""Status"" IN ('open', 'closed'))
                );
                CREATE UNIQUE INDEX IF NOT EXISTS ""UX_budget_periods_User_Start"" ON ""budget_periods"" (""UserId"", ""PeriodStart"");
                CREATE UNIQUE INDEX IF NOT EXISTS ""UX_budget_periods_OneOpenPerUser"" ON ""budget_periods"" (""UserId"") WHERE ""Status"" = 'open';
                CREATE INDEX IF NOT EXISTS ""IX_budget_periods_User_Dates"" ON ""budget_periods"" (""UserId"", ""PeriodStart"", ""PeriodEnd"");

                CREATE TABLE IF NOT EXISTS ""budget_period_categories"" (
                    ""Id"" TEXT NOT NULL CONSTRAINT ""PK_budget_period_categories"" PRIMARY KEY,
                    ""BudgetPeriodId"" TEXT NOT NULL,
                    ""CategoryId"" TEXT NOT NULL,
                    ""BaseAmount"" BIGINT NOT NULL DEFAULT 0,
                    ""RolledAmount"" BIGINT NOT NULL DEFAULT 0,
                    ""SpentAmount"" BIGINT NULL,
                    ""CreatedAt"" TEXT NOT NULL,
                    ""UpdatedAt"" TEXT NOT NULL,
                    CONSTRAINT ""FK_budget_period_categories_budget_periods_BudgetPeriodId"" FOREIGN KEY (""BudgetPeriodId"") REFERENCES ""budget_periods"" (""Id"") ON DELETE CASCADE,
                    CONSTRAINT ""FK_budget_period_categories_PfmCategories_CategoryId"" FOREIGN KEY (""CategoryId"") REFERENCES ""PfmCategories"" (""Id"") ON DELETE RESTRICT,
                    CONSTRAINT ""CK_budget_period_categories_BaseAmount"" CHECK (""BaseAmount"" >= 0),
                    CONSTRAINT ""CK_budget_period_categories_SpentAmount"" CHECK (""SpentAmount"" IS NULL OR ""SpentAmount"" >= 0)
                );
                CREATE UNIQUE INDEX IF NOT EXISTS ""UX_budget_period_categories_Period_Cat"" ON ""budget_period_categories"" (""BudgetPeriodId"", ""CategoryId"");
                CREATE INDEX IF NOT EXISTS ""IX_budget_period_categories_CategoryId"" ON ""budget_period_categories"" (""CategoryId"");
            ");
        }
        catch
        {
            // Ignore if already initialized
        }
    }
}
