using Microsoft.EntityFrameworkCore;
using ThemarIP.Domain.Entities.Pfm;
using ThemarIP.Domain.Enums.Pfm;

namespace ThemarIP.Infrastructure.Persistence;

/// <summary>
/// Seeds all PFM reference data into the database on first run.
/// Data mirrors the admin portal's Oman-specific seed data exactly so the
/// portal works out-of-the-box. Admin can edit everything after seeding.
/// </summary>
public static class PfmDataSeeder
{
    public static async Task SeedAsync(ApplicationDbContext context)
    {
        // Run all seed steps in dependency order
        var categories    = await SeedCategoriesAsync(context);
        var subcategories = await SeedSubcategoriesAsync(context, categories);
        var merchants     = await SeedMerchantsAsync(context, categories, subcategories);
        await SeedMerchantAliasesAsync(context, merchants);
        await SeedCategorizationRulesAsync(context, categories, subcategories);
        await SeedConfidenceBandsAsync(context);
        await SeedConfidenceWeightsAsync(context);
        await SeedIntelligenceRulesAsync(context);
    }

    // ────────────────────────────────────────────────────────────────────
    // 1. Categories
    // ────────────────────────────────────────────────────────────────────
    private static async Task<Dictionary<string, PfmCategory>> SeedCategoriesAsync(ApplicationDbContext ctx)
    {
        if (await ctx.PfmCategories.AnyAsync())
            return await ctx.PfmCategories.ToDictionaryAsync(c => c.Name);

        var cats = new List<PfmCategory>
        {
            new() { Name = "Food",          Icon = "utensils",     Color = "#F97316", DisplayOrder = 1  },
            new() { Name = "Transport",     Icon = "car",          Color = "#3B82F6", DisplayOrder = 2  },
            new() { Name = "Shopping",      Icon = "shopping-bag", Color = "#8B5CF6", DisplayOrder = 3  },
            new() { Name = "Bills",         Icon = "file-text",    Color = "#F59E0B", DisplayOrder = 4  },
            new() { Name = "Telecom",       Icon = "wifi",         Color = "#06B6D4", DisplayOrder = 5  },
            new() { Name = "Entertainment", Icon = "tv",           Color = "#EC4899", DisplayOrder = 6  },
            new() { Name = "Health",        Icon = "heart-pulse",  Color = "#10B981", DisplayOrder = 7  },
            new() { Name = "Income",        Icon = "trending-up",  Color = "#34D399", DisplayOrder = 8  },
            new() { Name = "Transfers",     Icon = "repeat",       Color = "#64748B", DisplayOrder = 9  },
            new() { Name = "Other",         Icon = "tag",          Color = "#94A3B8", DisplayOrder = 10 },
        };

        ctx.PfmCategories.AddRange(cats);
        await ctx.SaveChangesAsync();
        return cats.ToDictionary(c => c.Name);
    }

    // ────────────────────────────────────────────────────────────────────
    // 2. Subcategories
    // ────────────────────────────────────────────────────────────────────
    private static async Task<Dictionary<string, PfmSubcategory>> SeedSubcategoriesAsync(
        ApplicationDbContext ctx,
        Dictionary<string, PfmCategory> cats)
    {
        if (await ctx.PfmSubcategories.AnyAsync())
            return await ctx.PfmSubcategories.ToDictionaryAsync(s => $"{s.CategoryId}:{s.Name}");

        var subs = new List<PfmSubcategory>
        {
            // Food
            new() { CategoryId = cats["Food"].Id,          Name = "Fast Food",        DisplayOrder = 1 },
            new() { CategoryId = cats["Food"].Id,          Name = "Coffee Shops",     DisplayOrder = 2 },
            new() { CategoryId = cats["Food"].Id,          Name = "Restaurants",      DisplayOrder = 3 },
            new() { CategoryId = cats["Food"].Id,          Name = "Food Delivery",    DisplayOrder = 4 },
            new() { CategoryId = cats["Food"].Id,          Name = "Groceries",        DisplayOrder = 5 },
            // Transport
            new() { CategoryId = cats["Transport"].Id,     Name = "Fuel",             DisplayOrder = 1 },
            new() { CategoryId = cats["Transport"].Id,     Name = "Parking",          DisplayOrder = 2 },
            new() { CategoryId = cats["Transport"].Id,     Name = "Public Transit",   DisplayOrder = 3 },
            new() { CategoryId = cats["Transport"].Id,     Name = "Taxi & Ride",      DisplayOrder = 4 },
            // Shopping
            new() { CategoryId = cats["Shopping"].Id,      Name = "Clothing",         DisplayOrder = 1 },
            new() { CategoryId = cats["Shopping"].Id,      Name = "Electronics",      DisplayOrder = 2 },
            new() { CategoryId = cats["Shopping"].Id,      Name = "Online Shopping",  DisplayOrder = 3 },
            new() { CategoryId = cats["Shopping"].Id,      Name = "Pharmacy",         DisplayOrder = 4 },
            // Bills
            new() { CategoryId = cats["Bills"].Id,         Name = "Electricity",      DisplayOrder = 1 },
            new() { CategoryId = cats["Bills"].Id,         Name = "Water",            DisplayOrder = 2 },
            new() { CategoryId = cats["Bills"].Id,         Name = "Internet",         DisplayOrder = 3 },
            new() { CategoryId = cats["Bills"].Id,         Name = "Subscriptions",    DisplayOrder = 4 },
            // Telecom
            new() { CategoryId = cats["Telecom"].Id,       Name = "Mobile",           DisplayOrder = 1 },
            new() { CategoryId = cats["Telecom"].Id,       Name = "Landline",         DisplayOrder = 2 },
            // Entertainment
            new() { CategoryId = cats["Entertainment"].Id, Name = "Streaming",        DisplayOrder = 1 },
            new() { CategoryId = cats["Entertainment"].Id, Name = "Gaming",           DisplayOrder = 2 },
            new() { CategoryId = cats["Entertainment"].Id, Name = "Events & Cinema",  DisplayOrder = 3 },
            // Health
            new() { CategoryId = cats["Health"].Id,        Name = "Pharmacy",         DisplayOrder = 1 },
            new() { CategoryId = cats["Health"].Id,        Name = "Hospital & Clinic",DisplayOrder = 2 },
            new() { CategoryId = cats["Health"].Id,        Name = "Fitness",          DisplayOrder = 3 },
            // Income
            new() { CategoryId = cats["Income"].Id,        Name = "Salary",           DisplayOrder = 1 },
            new() { CategoryId = cats["Income"].Id,        Name = "Freelance",        DisplayOrder = 2 },
            new() { CategoryId = cats["Income"].Id,        Name = "Refund",           DisplayOrder = 3 },
            new() { CategoryId = cats["Income"].Id,        Name = "Investment",       DisplayOrder = 4 },
            // Transfers
            new() { CategoryId = cats["Transfers"].Id,     Name = "Internal Transfer",DisplayOrder = 1 },
            new() { CategoryId = cats["Transfers"].Id,     Name = "Savings",          DisplayOrder = 2 },
            new() { CategoryId = cats["Transfers"].Id,     Name = "ATM Withdrawal",   DisplayOrder = 3 },
            // Other
            new() { CategoryId = cats["Other"].Id,         Name = "Uncategorized",    DisplayOrder = 1 },
            new() { CategoryId = cats["Other"].Id,         Name = "Miscellaneous",    DisplayOrder = 2 },
        };

        ctx.PfmSubcategories.AddRange(subs);
        await ctx.SaveChangesAsync();
        return subs.ToDictionary(s => $"{s.CategoryId}:{s.Name}");
    }

    // ────────────────────────────────────────────────────────────────────
    // 3. Merchants
    // ────────────────────────────────────────────────────────────────────
    private static async Task<Dictionary<string, PfmMerchant>> SeedMerchantsAsync(
        ApplicationDbContext ctx,
        Dictionary<string, PfmCategory> cats,
        Dictionary<string, PfmSubcategory> subs)
    {
        if (await ctx.PfmMerchants.AnyAsync())
            return await ctx.PfmMerchants.ToDictionaryAsync(m => m.Name);

        Guid FoodId        = cats["Food"].Id;
        Guid TransportId   = cats["Transport"].Id;
        Guid ShoppingId    = cats["Shopping"].Id;
        Guid BillsId       = cats["Bills"].Id;
        Guid TelecomId     = cats["Telecom"].Id;
        Guid EntId         = cats["Entertainment"].Id;
        Guid TransfersId   = cats["Transfers"].Id;

        PfmSubcategory Sub(string catName, string subName) =>
            subs[$"{cats[catName].Id}:{subName}"];

        var merchants = new List<PfmMerchant>
        {
            new() { Name = "Starbucks",      MccCode = "5814", DefaultCategoryId = FoodId,      DefaultSubcategoryId = Sub("Food","Coffee Shops").Id,     DefaultConfidence = 99 },
            new() { Name = "Costa Coffee",   MccCode = "5814", DefaultCategoryId = FoodId,      DefaultSubcategoryId = Sub("Food","Coffee Shops").Id,     DefaultConfidence = 98 },
            new() { Name = "Talabat",        MccCode = "5812", DefaultCategoryId = FoodId,      DefaultSubcategoryId = Sub("Food","Food Delivery").Id,    DefaultConfidence = 98 },
            new() { Name = "KFC",            MccCode = "5814", DefaultCategoryId = FoodId,      DefaultSubcategoryId = Sub("Food","Fast Food").Id,        DefaultConfidence = 98 },
            new() { Name = "Pizza Hut",      MccCode = "5814", DefaultCategoryId = FoodId,      DefaultSubcategoryId = Sub("Food","Fast Food").Id,        DefaultConfidence = 97 },
            new() { Name = "Lulu Hypermarket",MccCode = "5411",DefaultCategoryId = FoodId,      DefaultSubcategoryId = Sub("Food","Groceries").Id,        DefaultConfidence = 97 },
            new() { Name = "Carrefour",      MccCode = "5411", DefaultCategoryId = FoodId,      DefaultSubcategoryId = Sub("Food","Groceries").Id,        DefaultConfidence = 96 },
            new() { Name = "Shell",          MccCode = "5541", DefaultCategoryId = TransportId, DefaultSubcategoryId = Sub("Transport","Fuel").Id,        DefaultConfidence = 98 },
            new() { Name = "Oman Oil",       MccCode = "5541", DefaultCategoryId = TransportId, DefaultSubcategoryId = Sub("Transport","Fuel").Id,        DefaultConfidence = 97 },
            new() { Name = "Ooredoo",        MccCode = "4814", DefaultCategoryId = TelecomId,   DefaultSubcategoryId = Sub("Telecom","Mobile").Id,        DefaultConfidence = 99 },
            new() { Name = "Omantel",        MccCode = "4814", DefaultCategoryId = TelecomId,   DefaultSubcategoryId = Sub("Telecom","Mobile").Id,        DefaultConfidence = 99 },
            new() { Name = "Netflix",        MccCode = "4899", DefaultCategoryId = EntId,       DefaultSubcategoryId = Sub("Entertainment","Streaming").Id,DefaultConfidence = 99 },
            new() { Name = "Amazon",         MccCode = "5999", DefaultCategoryId = ShoppingId,  DefaultSubcategoryId = Sub("Shopping","Online Shopping").Id,DefaultConfidence = 92 },
            new() { Name = "Aster Pharmacy", MccCode = "5912", DefaultCategoryId = ShoppingId,  DefaultSubcategoryId = Sub("Shopping","Pharmacy").Id,     DefaultConfidence = 96 },
            new() { Name = "Majan Electricity",MccCode= "4911",DefaultCategoryId = BillsId,     DefaultSubcategoryId = Sub("Bills","Electricity").Id,     DefaultConfidence = 99 },
            new() { Name = "Bank Muscat ATM",MccCode = "6011", DefaultCategoryId = TransfersId, DefaultSubcategoryId = Sub("Transfers","ATM Withdrawal").Id,DefaultConfidence = 95 },
            new() { Name = "Muscat Grand Mall",MccCode = "5651",DefaultCategoryId = ShoppingId, DefaultSubcategoryId = Sub("Shopping","Clothing").Id,     DefaultConfidence = 82 },
        };

        ctx.PfmMerchants.AddRange(merchants);
        await ctx.SaveChangesAsync();
        return merchants.ToDictionary(m => m.Name);
    }

    // ────────────────────────────────────────────────────────────────────
    // 4. Merchant Aliases
    // ────────────────────────────────────────────────────────────────────
    private static async Task SeedMerchantAliasesAsync(
        ApplicationDbContext ctx,
        Dictionary<string, PfmMerchant> merchants)
    {
        if (await ctx.PfmMerchantAliases.AnyAsync()) return;

        var aliases = new List<(string Merchant, string[] Aliases)>
        {
            ("Starbucks",       new[] { "STARBUCKS", "STARBUCKS MUSCAT", "STARBUCKS QURUM", "SBUX", "STARBUCKS AL KHUWAIR" }),
            ("Costa Coffee",    new[] { "COSTA", "COSTA COFFEE", "COSTA MUSCAT" }),
            ("Talabat",         new[] { "TALABAT", "TALABAT OMAN", "TLB" }),
            ("KFC",             new[] { "KFC", "KFC AL KHUWAIR", "KFC QURUM BRANCH", "KENTUCKY FRIED CHICKEN" }),
            ("Pizza Hut",       new[] { "PIZZA HUT", "PIZZA HUT MUSCAT", "PIZZAHUT" }),
            ("Lulu Hypermarket",new[] { "LULU", "LULU HYPERMARKET", "LULU MUSCAT", "LULU HYPERMARKET MUSCAT" }),
            ("Carrefour",       new[] { "CARREFOUR", "CARREFOUR OMAN", "CARREFOUR AL QURUM" }),
            ("Shell",           new[] { "SHELL", "SHELL PETROL", "SHELL STATION", "SHELL GAS" }),
            ("Oman Oil",        new[] { "OMAN OIL", "OMANOIL", "OMAN OIL STATION" }),
            ("Ooredoo",         new[] { "OOREDOO", "OOREDOO OMAN", "NAWRAS" }),
            ("Omantel",         new[] { "OMANTEL", "OMAN TELECOMMUNICATIONS" }),
            ("Netflix",         new[] { "NETFLIX", "NETFLIX.COM", "NETFLIX SUBSCRIPTION" }),
            ("Amazon",          new[] { "AMAZON", "AMZN", "AMAZON.COM", "AMAZON PRIME" }),
            ("Aster Pharmacy",  new[] { "ASTER", "ASTER PHARMACY", "ASTER MUSCAT" }),
            ("Majan Electricity",new[] { "MAJAN", "MAJAN ELECTRICITY", "MAJAN ELECTRICITY BILL" }),
            ("Bank Muscat ATM", new[] { "ATM WITHDRAWAL BANK MUSCAT", "BANK MUSCAT ATM", "BM ATM" }),
            ("Muscat Grand Mall",new[] { "GRAND MALL", "MUSCAT GRAND MALL", "GRAND MALL MUSCAT" }),
        };

        var rows = new List<PfmMerchantAlias>();
        foreach (var (name, aliasList) in aliases)
        {
            if (!merchants.TryGetValue(name, out var merchant)) continue;
            foreach (var alias in aliasList)
            {
                rows.Add(new PfmMerchantAlias
                {
                    MerchantId = merchant.Id,
                    AliasText  = alias.ToUpperInvariant().Trim()
                });
            }
        }

        ctx.PfmMerchantAliases.AddRange(rows);
        await ctx.SaveChangesAsync();
    }

    // ────────────────────────────────────────────────────────────────────
    // 5. Categorization Rules (with conditions)
    // ────────────────────────────────────────────────────────────────────
    private static async Task SeedCategorizationRulesAsync(
        ApplicationDbContext ctx,
        Dictionary<string, PfmCategory> cats,
        Dictionary<string, PfmSubcategory> subs)
    {
        if (await ctx.PfmCategorizationRules.AnyAsync()) return;

        PfmSubcategory Sub(string catName, string subName) =>
            subs[$"{cats[catName].Id}:{subName}"];

        // Each entry: (ruleName, catName, subName, confidence, priority, conditions[])
        // Condition tuple: (field, op, value, logic)
        var ruleDefs = new List<(string Name, string Cat, string Sub, int Conf, int Pri, (RuleConditionField F, RuleConditionOperator O, string V, RuleConditionLogic L)[] Conditions)>
        {
            ("Starbucks Purchase", "Food", "Coffee Shops", 99, 100,
                new[] { (RuleConditionField.Narration, RuleConditionOperator.Contains, "STARBUCKS", RuleConditionLogic.And) }),

            ("Costa Coffee Purchase", "Food", "Coffee Shops", 98, 99,
                new[] { (RuleConditionField.Narration, RuleConditionOperator.Contains, "COSTA", RuleConditionLogic.And) }),

            ("KFC Purchase", "Food", "Fast Food", 98, 99,
                new[] { (RuleConditionField.Narration, RuleConditionOperator.Contains, "KFC", RuleConditionLogic.And) }),

            ("Pizza Hut Purchase", "Food", "Fast Food", 97, 98,
                new[] { (RuleConditionField.Narration, RuleConditionOperator.Contains, "PIZZA HUT", RuleConditionLogic.And) }),

            ("Talabat Order", "Food", "Food Delivery", 98, 100,
                new[] { (RuleConditionField.Narration, RuleConditionOperator.Contains, "TALABAT", RuleConditionLogic.And) }),

            ("Lulu Hypermarket", "Food", "Groceries", 97, 97,
                new[] { (RuleConditionField.Narration, RuleConditionOperator.Contains, "LULU", RuleConditionLogic.And) }),

            ("Carrefour Grocery", "Food", "Groceries", 95, 96,
                new[] { (RuleConditionField.Narration, RuleConditionOperator.Contains, "CARREFOUR", RuleConditionLogic.And) }),

            ("Shell Fuel", "Transport", "Fuel", 98, 98,
                new[] { (RuleConditionField.Narration, RuleConditionOperator.Contains, "SHELL", RuleConditionLogic.And),
                        (RuleConditionField.TransactionType, RuleConditionOperator.Equals, "Debit", RuleConditionLogic.And) }),

            ("Oman Oil Fuel", "Transport", "Fuel", 97, 97,
                new[] { (RuleConditionField.Narration, RuleConditionOperator.Contains, "OMAN OIL", RuleConditionLogic.And) }),

            ("Ooredoo Telecom", "Telecom", "Mobile", 99, 99,
                new[] { (RuleConditionField.Narration, RuleConditionOperator.Contains, "OOREDOO", RuleConditionLogic.And) }),

            ("Omantel Telecom", "Telecom", "Mobile", 99, 99,
                new[] { (RuleConditionField.Narration, RuleConditionOperator.Contains, "OMANTEL", RuleConditionLogic.And) }),

            ("Netflix Subscription", "Entertainment", "Streaming", 99, 100,
                new[] { (RuleConditionField.Narration, RuleConditionOperator.Contains, "NETFLIX", RuleConditionLogic.And) }),

            ("Majan Electricity Bill", "Bills", "Electricity", 99, 100,
                new[] { (RuleConditionField.Narration, RuleConditionOperator.Contains, "MAJAN", RuleConditionLogic.And) }),

            ("Salary Credit", "Income", "Salary", 97, 95,
                new[] { (RuleConditionField.Narration, RuleConditionOperator.Contains, "SALARY", RuleConditionLogic.And),
                        (RuleConditionField.TransactionType, RuleConditionOperator.Equals, "Credit", RuleConditionLogic.And) }),

            ("ATM Withdrawal", "Transfers", "ATM Withdrawal", 92, 90,
                new[] { (RuleConditionField.Narration, RuleConditionOperator.Contains, "ATM WITHDRAWAL", RuleConditionLogic.And) }),

            ("Savings Transfer", "Transfers", "Savings", 88, 85,
                new[] { (RuleConditionField.Narration, RuleConditionOperator.Contains, "TRANSFER TO SAVINGS", RuleConditionLogic.And) }),
        };

        foreach (var (name, catName, subName, conf, pri, conditions) in ruleDefs)
        {
            var rule = new PfmCategorizationRule
            {
                Name        = name,
                CategoryId  = cats[catName].Id,
                SubcategoryId = Sub(catName, subName).Id,
                Confidence  = conf,
                Priority    = pri,
                Status      = RuleStatus.Active,
            };

            for (int i = 0; i < conditions.Length; i++)
            {
                var (f, o, v, l) = conditions[i];
                rule.Conditions.Add(new PfmRuleCondition
                {
                    Field         = f,
                    Operator      = o,
                    Value         = v,
                    LogicOperator = l,
                    OrderIndex    = i
                });
            }

            ctx.PfmCategorizationRules.Add(rule);
        }

        await ctx.SaveChangesAsync();
    }

    // ────────────────────────────────────────────────────────────────────
    // 6. Confidence Bands (3 rows)
    // ────────────────────────────────────────────────────────────────────
    private static async Task SeedConfidenceBandsAsync(ApplicationDbContext ctx)
    {
        if (await ctx.PfmConfidenceBands.AnyAsync()) return;

        ctx.PfmConfidenceBands.AddRange(
            new PfmConfidenceBand
            {
                BandName     = ConfidenceBandName.High,
                DisplayLabel = "High Confidence",
                MinThreshold = 90,
                MaxThreshold = 100,
                Action       = ConfidenceBandAction.AutoCategorize,
                ActionLabel  = "Auto-categorize silently"
            },
            new PfmConfidenceBand
            {
                BandName     = ConfidenceBandName.Medium,
                DisplayLabel = "Medium Confidence",
                MinThreshold = 70,
                MaxThreshold = 89,
                Action       = ConfidenceBandAction.CategorizAndMonitor,
                ActionLabel  = "Categorize & flag for review"
            },
            new PfmConfidenceBand
            {
                BandName     = ConfidenceBandName.Low,
                DisplayLabel = "Low Confidence",
                MinThreshold = 0,
                MaxThreshold = 69,
                Action       = ConfidenceBandAction.SendToReview,
                ActionLabel  = "Send to manual review queue"
            }
        );

        await ctx.SaveChangesAsync();
    }

    // ────────────────────────────────────────────────────────────────────
    // 7. Confidence Weights (5 rows — must sum to 100)
    // ────────────────────────────────────────────────────────────────────
    private static async Task SeedConfidenceWeightsAsync(ApplicationDbContext ctx)
    {
        if (await ctx.PfmConfidenceWeights.AnyAsync()) return;

        ctx.PfmConfidenceWeights.AddRange(
            new PfmConfidenceWeight { Signal = ConfidenceSignal.MerchantMatch,    DisplayLabel = "Merchant Match",    WeightPercent = 40, Color = "#3B82F6" },
            new PfmConfidenceWeight { Signal = ConfidenceSignal.MccMatch,         DisplayLabel = "MCC Code Match",    WeightPercent = 30, Color = "#8B5CF6" },
            new PfmConfidenceWeight { Signal = ConfidenceSignal.NarrationMatch,   DisplayLabel = "Narration Match",   WeightPercent = 15, Color = "#06B6D4" },
            new PfmConfidenceWeight { Signal = ConfidenceSignal.HistoricalMatch,  DisplayLabel = "Historical Match",  WeightPercent = 10, Color = "#10B981" },
            new PfmConfidenceWeight { Signal = ConfidenceSignal.AmountPattern,    DisplayLabel = "Amount Pattern",    WeightPercent = 5,  Color = "#F59E0B" }
        );

        await ctx.SaveChangesAsync();
    }

    // ────────────────────────────────────────────────────────────────────
    // 8. Intelligence Rules (with typed params)
    // ────────────────────────────────────────────────────────────────────
    private static async Task SeedIntelligenceRulesAsync(ApplicationDbContext ctx)
    {
        if (await ctx.PfmIntelligenceRules.AnyAsync()) return;

        var rules = new List<(PfmIntelligenceRule Rule, (string Key, string Value, IntelligenceRuleParamType Type)[] Params)>
        {
            (
                new PfmIntelligenceRule
                {
                    Name            = "High Coffee Spending",
                    RuleType        = IntelligenceRuleType.HighSpending,
                    Status          = IntelligenceRuleStatus.Active,
                    InsightTemplate = "You've spent more than {threshold} {currency} on {categoryName} this {period}.",
                    Icon            = "coffee",
                    IconColor       = "#F97316",
                    FireCount       = 24,
                },
                new[]
                {
                    ("threshold",    "50",       IntelligenceRuleParamType.Number),
                    ("currency",     "OMR",      IntelligenceRuleParamType.String),
                    ("categoryName", "Coffee",   IntelligenceRuleParamType.String),
                    ("period",       "monthly",  IntelligenceRuleParamType.String),
                }
            ),
            (
                new PfmIntelligenceRule
                {
                    Name            = "Unusual Transaction Amount",
                    RuleType        = IntelligenceRuleType.UnusualSpending,
                    Status          = IntelligenceRuleStatus.Active,
                    InsightTemplate = "Unusual transaction: {multiplier}× your average for this merchant.",
                    Icon            = "alert-triangle",
                    IconColor       = "#F43F5E",
                    FireCount       = 11,
                },
                new[]
                {
                    ("multiplier", "3",   IntelligenceRuleParamType.Number),
                    ("lookbackDays","30", IntelligenceRuleParamType.Number),
                }
            ),
            (
                new PfmIntelligenceRule
                {
                    Name            = "Low Balance Alert",
                    RuleType        = IntelligenceRuleType.LowBalance,
                    Status          = IntelligenceRuleStatus.Active,
                    InsightTemplate = "Your balance has dropped below {threshold} {currency}.",
                    Icon            = "wallet",
                    IconColor       = "#F59E0B",
                    FireCount       = 7,
                },
                new[]
                {
                    ("threshold", "100", IntelligenceRuleParamType.Number),
                    ("currency",  "OMR", IntelligenceRuleParamType.String),
                }
            ),
            (
                new PfmIntelligenceRule
                {
                    Name            = "Monthly Spending Increase",
                    RuleType        = IntelligenceRuleType.SpendingIncrease,
                    Status          = IntelligenceRuleStatus.Active,
                    InsightTemplate = "Your spending is {increasePercent}% higher than last month.",
                    Icon            = "trending-up",
                    IconColor       = "#8B5CF6",
                    FireCount       = 15,
                },
                new[]
                {
                    ("increasePercent", "20", IntelligenceRuleParamType.Number),
                }
            ),
            (
                new PfmIntelligenceRule
                {
                    Name            = "Recurring Payment Detected",
                    RuleType        = IntelligenceRuleType.Recurring,
                    Status          = IntelligenceRuleStatus.Active,
                    InsightTemplate = "Recurring payment detected — same merchant, similar amount, ~{intervalDays}-day interval.",
                    Icon            = "repeat",
                    IconColor       = "#3B82F6",
                    FireCount       = 18,
                },
                new[]
                {
                    ("intervalDays",     "30", IntelligenceRuleParamType.Number),
                    ("tolerancePercent", "10", IntelligenceRuleParamType.Number),
                    ("minOccurrences",   "2",  IntelligenceRuleParamType.Number),
                }
            ),
            (
                new PfmIntelligenceRule
                {
                    Name            = "High Food Delivery Spending",
                    RuleType        = IntelligenceRuleType.HighSpending,
                    Status          = IntelligenceRuleStatus.Active,
                    InsightTemplate = "You've spent more than {threshold} {currency} on food delivery this month.",
                    Icon            = "bike",
                    IconColor       = "#F97316",
                    FireCount       = 9,
                },
                new[]
                {
                    ("threshold",    "80",            IntelligenceRuleParamType.Number),
                    ("currency",     "OMR",           IntelligenceRuleParamType.String),
                    ("categoryName", "Food Delivery", IntelligenceRuleParamType.String),
                    ("period",       "monthly",       IntelligenceRuleParamType.String),
                }
            ),
        };

        foreach (var (rule, paramDefs) in rules)
        {
            foreach (var (key, value, type) in paramDefs)
            {
                rule.Params.Add(new PfmIntelligenceRuleParam
                {
                    ParamKey   = key,
                    ParamValue = value,
                    ParamType  = type
                });
            }
            ctx.PfmIntelligenceRules.Add(rule);
        }

        await ctx.SaveChangesAsync();
    }
}
