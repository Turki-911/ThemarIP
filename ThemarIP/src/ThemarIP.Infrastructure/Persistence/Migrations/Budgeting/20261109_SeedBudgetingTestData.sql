-- =============================================================================
-- STEP 5: SEED DATA FOR ONE TEST USER (5 CATEGORIES, 2 PERIODS)
-- =============================================================================
-- Budget Averages (OMR -> Baisa, 1 OMR = 1,000 baisa):
--   * Total Monthly Budget : 400.000 OMR = 400,000 baisa
--   * Bills                : 120.000 OMR = 120,000 baisa
--   * Business             :  60.000 OMR =  60,000 baisa
--   * Eating out           :  95.000 OMR =  95,000 baisa
--   * Entertainment        :  30.000 OMR =  30,000 baisa
--   * Charity              :  10.000 OMR =  10,000 baisa
--   * Transfers            : Excluded from budget tracking
--
-- Two Periods:
--   * Period 1 (CLOSED): 2026-10-01 to 2026-11-01
--       - Bills:         90,000 normal spent + 15,000 committed = 105,000 -> +30,000 leftover (normal)
--       - Business:      70,000 normal spent                    =  70,000 -> -10,000 overspend
--       - Eating out:    80,000 normal spent (incl. Coffee sub) =  80,000 -> +15,000 leftover
--       - Entertainment: 25,000 normal spent +  5,000 committed =  30,000 ->  +5,000 leftover (normal)
--       - Charity:       10,000 normal spent                    =  10,000 ->       0 leftover
--       - Total P1 Normal Spent: 275,000 baisa | Committed: 20,000 baisa
--       - Total P1 Rollover into Period 2: 400,000 - (275,000 + 20,000) = +105,000 baisa (105.000 OMR)
--
--   * Period 2 (OPEN - Current Period): 2026-11-01 to 2026-12-01
--       - BaseTotal: 400,000 | RolledAmount: +105,000 | EffectiveTotal: 505,000 baisa (505.000 OMR)
--       - Bills:         Base 120,000 + Rolled +30,000 = 150,000 | Normal Spent: 45,000 | Committed: 15,000
--       - Business:      Base  60,000 + Rolled -10,000 =  50,000 | Normal Spent: 20,000 | Committed:      0
--       - Eating out:    Base  95,000 + Rolled +15,000 = 110,000 | Normal Spent: 32,500 | Committed:      0
--                        (20,000 direct on Eating out + 12,500 on Coffee Spot subcategory)
--       - Entertainment: Base  30,000 + Rolled  +5,000 =  35,000 | Normal Spent: 12,000 | Committed:  5,000
--       - Charity:       Base  10,000 + Rolled       0 =  10,000 | Normal Spent:  5,000 | Committed:      0
--       - Transfers:     50,000 spent (EXCLUDED from budget via budget_excluded_categories)
-- =============================================================================

PRAGMA foreign_keys = ON;
BEGIN TRANSACTION;

-- 1. Ensure Test User exists
INSERT OR IGNORE INTO "Users" (
    "Id", "Email", "FullName", "PasswordHash", "Role", "AccessStatus", "TrustScore", "CreatedAt"
) VALUES (
    '99999999-9999-4999-8999-999999999999',
    'budget.demo@themar.ip',
    'Budgeting Demo User',
    '$2a$11$DemoPasswordHashForBudgetingSeedUser0000000000000000000',
    'User',
    'Approved',
    95,
    '2026-10-01T00:00:00+00:00'
);

-- 2. Ensure the 5 parent categories (+ 1 subcategory under Eating out) exist in PfmCategories
--    Existing categories in themarip.db:
--      Bills:         67cbe620-6139-4c0d-aaba-5e00b2ba8045
--      Business:      b2f82d4f-bbfc-462b-bf62-5e5b3ab46f9b
--      Entertainment: 7ced4f02-a42e-42ec-8f3d-1e4c1deeef42
--      Transfers:     f0270d2e-be00-4fc9-b7dd-72ec2be15add
--    Insert Eating out, Charity, and a subcategory "Restaurants & Cafes" under Eating out if not present:
INSERT OR IGNORE INTO "PfmCategories" (
    "Id", "ParentId", "Name", "Icon", "Color", "DisplayOrder", "IsEnabled", "CreatedAt", "UpdatedAt"
) VALUES
    ('e1a71000-0000-4000-8000-000000000001', NULL, 'Eating out', 'utensils', '#F97316', 12, 1, '2026-10-01T00:00:00+00:00', '2026-10-01T00:00:00+00:00'),
    ('c4a71000-0000-4000-8000-000000000002', NULL, 'Charity', 'heart', '#14B8A6', 13, 1, '2026-10-01T00:00:00+00:00', '2026-10-01T00:00:00+00:00'),
    ('e1a71000-0000-4000-8000-000000000011', 'e1a71000-0000-4000-8000-000000000001', 'Restaurants & Cafes', 'coffee', '#FB923C', 1, 1, '2026-10-01T00:00:00+00:00', '2026-10-01T00:00:00+00:00');

-- 3. Upsert budget_settings for Test User (Total = 400.000 OMR = 400,000 baisa)
INSERT OR REPLACE INTO "budget_settings" (
    "Id", "UserId", "TotalMonthlyBudget", "PeriodStartDay", "RolloverEnabled", "Currency", "CreatedAt", "UpdatedAt"
) VALUES (
    'b5000000-0000-4000-8000-000000000001',
    '99999999-9999-4999-8999-999999999999',
    400000,
    1,
    1,
    'OMR',
    '2026-10-01T00:00:00+00:00',
    '2026-11-01T00:00:00+00:00'
);

-- 4. Upsert budget_categories for the 5 Categories
DELETE FROM "budget_categories" WHERE "UserId" = '99999999-9999-4999-8999-999999999999';
INSERT INTO "budget_categories" (
    "Id", "UserId", "CategoryId", "BudgetAmount", "EffectiveFrom", "EffectiveTo", "CreatedAt", "UpdatedAt"
) VALUES
    -- Bills: 120.000 OMR = 120,000 baisa
    ('bc000000-0000-4000-8000-000000000001', '99999999-9999-4999-8999-999999999999', '67cbe620-6139-4c0d-aaba-5e00b2ba8045', 120000, '2026-10-01', NULL, '2026-10-01T00:00:00+00:00', '2026-10-01T00:00:00+00:00'),
    -- Business: 60.000 OMR = 60,000 baisa
    ('bc000000-0000-4000-8000-000000000002', '99999999-9999-4999-8999-999999999999', 'b2f82d4f-bbfc-462b-bf62-5e5b3ab46f9b',  60000, '2026-10-01', NULL, '2026-10-01T00:00:00+00:00', '2026-10-01T00:00:00+00:00'),
    -- Eating out: 95.000 OMR = 95,000 baisa
    ('bc000000-0000-4000-8000-000000000003', '99999999-9999-4999-8999-999999999999', 'e1a71000-0000-4000-8000-000000000001',  95000, '2026-10-01', NULL, '2026-10-01T00:00:00+00:00', '2026-10-01T00:00:00+00:00'),
    -- Entertainment: 30.000 OMR = 30,000 baisa
    ('bc000000-0000-4000-8000-000000000004', '99999999-9999-4999-8999-999999999999', '7ced4f02-a42e-42ec-8f3d-1e4c1deeef42',  30000, '2026-10-01', NULL, '2026-10-01T00:00:00+00:00', '2026-10-01T00:00:00+00:00'),
    -- Charity: 10.000 OMR = 10,000 baisa
    ('bc000000-0000-4000-8000-000000000005', '99999999-9999-4999-8999-999999999999', 'c4a71000-0000-4000-8000-000000000002',  10000, '2026-10-01', NULL, '2026-10-01T00:00:00+00:00', '2026-10-01T00:00:00+00:00');

-- 5. Exclude "Transfers" category from budget tracking for this user
INSERT OR REPLACE INTO "budget_excluded_categories" (
    "Id", "UserId", "CategoryId", "CreatedAt", "UpdatedAt"
) VALUES (
    'be000000-0000-4000-8000-000000000001',
    '99999999-9999-4999-8999-999999999999',
    'f0270d2e-be00-4fc9-b7dd-72ec2be15add', -- Transfers
    '2026-10-01T00:00:00+00:00',
    '2026-10-01T00:00:00+00:00'
);

-- 6. Seed Two Budget Periods (Period 1 = Closed Oct 2026, Period 2 = Open Nov 2026)
DELETE FROM "budget_period_categories" WHERE "BudgetPeriodId" IN (
    'bp000000-0000-4000-8000-000000000001',
    'bp000000-0000-4000-8000-000000000002'
);
DELETE FROM "budget_periods" WHERE "UserId" = '99999999-9999-4999-8999-999999999999';

INSERT INTO "budget_periods" (
    "Id", "UserId", "PeriodStart", "PeriodEnd", "BaseTotal", "RolledAmount",
    "SpentTotalSnapshot", "CommittedTotalSnapshot", "Status", "ClosedAt", "CreatedAt", "UpdatedAt"
) VALUES
    -- Period 1 (Closed): October 2026
    (
        'bp000000-0000-4000-8000-000000000001',
        '99999999-9999-4999-8999-999999999999',
        '2026-10-01',
        '2026-11-01',
        400000,
        0,
        275000,
        20000,
        'closed',
        '2026-11-01T00:00:05+00:00',
        '2026-10-01T00:00:00+00:00',
        '2026-11-01T00:00:05+00:00'
    ),
    -- Period 2 (Open): November 2026 (Carries +105,000 baisa rolled over from Period 1)
    (
        'bp000000-0000-4000-8000-000000000002',
        '99999999-9999-4999-8999-999999999999',
        '2026-11-01',
        '2026-12-01',
        400000,
        105000,
        NULL,
        NULL,
        'open',
        NULL,
        '2026-11-01T00:00:05+00:00',
        '2026-11-01T00:00:05+00:00'
    );

-- 7. Seed budget_period_categories for Period 1 (Closed, with SpentAmount snapshot) and Period 2 (Open, with RolledAmount)
INSERT INTO "budget_period_categories" (
    "Id", "BudgetPeriodId", "CategoryId", "BaseAmount", "RolledAmount", "SpentAmount", "CreatedAt", "UpdatedAt"
) VALUES
    -- Period 1 Categories (Closed snapshots)
    ('bpc10000-0000-4000-8000-000000000001', 'bp000000-0000-4000-8000-000000000001', '67cbe620-6139-4c0d-aaba-5e00b2ba8045', 120000,      0,  90000, '2026-10-01T00:00:00+00:00', '2026-11-01T00:00:05+00:00'), -- Bills
    ('bpc10000-0000-4000-8000-000000000002', 'bp000000-0000-4000-8000-000000000001', 'b2f82d4f-bbfc-462b-bf62-5e5b3ab46f9b',  60000,      0,  70000, '2026-10-01T00:00:00+00:00', '2026-11-01T00:00:05+00:00'), -- Business (overspent by 10,000)
    ('bpc10000-0000-4000-8000-000000000003', 'bp000000-0000-4000-8000-000000000001', 'e1a71000-0000-4000-8000-000000000001',  95000,      0,  80000, '2026-10-01T00:00:00+00:00', '2026-11-01T00:00:05+00:00'), -- Eating out
    ('bpc10000-0000-4000-8000-000000000004', 'bp000000-0000-4000-8000-000000000001', '7ced4f02-a42e-42ec-8f3d-1e4c1deeef42',  30000,      0,  25000, '2026-10-01T00:00:00+00:00', '2026-11-01T00:00:05+00:00'), -- Entertainment
    ('bpc10000-0000-4000-8000-000000000005', 'bp000000-0000-4000-8000-000000000001', 'c4a71000-0000-4000-8000-000000000002',  10000,      0,  10000, '2026-10-01T00:00:00+00:00', '2026-11-01T00:00:05+00:00'), -- Charity

    -- Period 2 Categories (Open, RolledAmount = P1 EffectiveBudget - P1 NormalSpent)
    ('bpc20000-0000-4000-8000-000000000001', 'bp000000-0000-4000-8000-000000000002', '67cbe620-6139-4c0d-aaba-5e00b2ba8045', 120000,  30000,   NULL, '2026-11-01T00:00:05+00:00', '2026-11-01T00:00:05+00:00'), -- Bills (120k + 30k = 150k)
    ('bpc20000-0000-4000-8000-000000000002', 'bp000000-0000-4000-8000-000000000002', 'b2f82d4f-bbfc-462b-bf62-5e5b3ab46f9b',  60000, -10000,   NULL, '2026-11-01T00:00:05+00:00', '2026-11-01T00:00:05+00:00'), -- Business (60k - 10k = 50k)
    ('bpc20000-0000-4000-8000-000000000003', 'bp000000-0000-4000-8000-000000000002', 'e1a71000-0000-4000-8000-000000000001',  95000,  15000,   NULL, '2026-11-01T00:00:05+00:00', '2026-11-01T00:00:05+00:00'), -- Eating out (95k + 15k = 110k)
    ('bpc20000-0000-4000-8000-000000000004', 'bp000000-0000-4000-8000-000000000002', '7ced4f02-a42e-42ec-8f3d-1e4c1deeef42',  30000,   5000,   NULL, '2026-11-01T00:00:05+00:00', '2026-11-01T00:00:05+00:00'), -- Entertainment (30k + 5k = 35k)
    ('bpc20000-0000-4000-8000-000000000005', 'bp000000-0000-4000-8000-000000000002', 'c4a71000-0000-4000-8000-000000000002',  10000,      0,   NULL, '2026-11-01T00:00:05+00:00', '2026-11-01T00:00:05+00:00'); -- Charity (10k + 0 = 10k)

-- 8. Seed Sample Transactions & Categorizations for the Test User (Period 1 & Period 2)
DELETE FROM "PfmTransactionCategories" WHERE "TransactionId" LIKE '99990000-0000-4000-8000-%';
DELETE FROM "PfmTransactions" WHERE "UserId" = '99999999-9999-4999-8999-999999999999';

INSERT INTO "PfmTransactions" (
    "Id", "UserId", "MerchantId", "Narration", "Amount", "Currency", "TransactionType",
    "BalanceAfter", "TransactionDate", "IsRecurring", "IsEssential", "Status",
    "BankCode", "BankName", "CreatedAt", "UpdatedAt"
) VALUES
    -- Period 1 (October 2026) Transactions
    ('99990000-0000-4000-8000-000000000101', '99999999-9999-4999-8999-999999999999', NULL, 'Nama Electricity & Water Bill', '90.000', 'OMR', 'Debit', '910.000', '2026-10-05T10:00:00+04:00', 0, 1, 'Categorized', 'BANK_MUSCAT', 'Bank Muscat', '2026-10-05T10:00:00+04:00', '2026-10-05T10:00:00+04:00'),
    ('99990000-0000-4000-8000-000000000102', '99999999-9999-4999-8999-999999999999', NULL, 'Omantel Fiber Home Internet (Recurring)', '15.000', 'OMR', 'Debit', '895.000', '2026-10-06T09:00:00+04:00', 1, 1, 'Categorized', 'BANK_MUSCAT', 'Bank Muscat', '2026-10-06T09:00:00+04:00', '2026-10-06T09:00:00+04:00'),
    ('99990000-0000-4000-8000-000000000103', '99999999-9999-4999-8999-999999999999', NULL, 'Office Supplies & Printing', '70.000', 'OMR', 'Debit', '825.000', '2026-10-10T14:20:00+04:00', 0, 0, 'Categorized', 'BANK_MUSCAT', 'Bank Muscat', '2026-10-10T14:20:00+04:00', '2026-10-10T14:20:00+04:00'),
    ('99990000-0000-4000-8000-000000000104', '99999999-9999-4999-8999-999999999999', NULL, 'Fine Dining Muscat', '55.000', 'OMR', 'Debit', '770.000', '2026-10-14T20:15:00+04:00', 0, 0, 'Categorized', 'BANK_MUSCAT', 'Bank Muscat', '2026-10-14T20:15:00+04:00', '2026-10-14T20:15:00+04:00'),
    ('99990000-0000-4000-8000-000000000105', '99999999-9999-4999-8999-999999999999', NULL, 'Arabica Cafe Al Mouj (Subcategory)', '25.000', 'OMR', 'Debit', '745.000', '2026-10-18T17:30:00+04:00', 0, 0, 'Categorized', 'BANK_MUSCAT', 'Bank Muscat', '2026-10-18T17:30:00+04:00', '2026-10-18T17:30:00+04:00'),
    ('99990000-0000-4000-8000-000000000106', '99999999-9999-4999-8999-999999999999', NULL, 'VOX Cinemas Mall of Oman', '25.000', 'OMR', 'Debit', '720.000', '2026-10-21T21:00:00+04:00', 0, 0, 'Categorized', 'BANK_MUSCAT', 'Bank Muscat', '2026-10-21T21:00:00+04:00', '2026-10-21T21:00:00+04:00'),
    ('99990000-0000-4000-8000-000000000107', '99999999-9999-4999-8999-999999999999', NULL, 'Netflix Monthly Subscription (Recurring)', '5.000', 'OMR', 'Debit', '715.000', '2026-10-22T08:00:00+04:00', 1, 0, 'Categorized', 'BANK_MUSCAT', 'Bank Muscat', '2026-10-22T08:00:00+04:00', '2026-10-22T08:00:00+04:00'),
    ('99990000-0000-4000-8000-000000000108', '99999999-9999-4999-8999-999999999999', NULL, 'Oman Charitable Organization Sadaqah', '10.000', 'OMR', 'Debit', '705.000', '2026-10-25T12:00:00+04:00', 0, 0, 'Categorized', 'BANK_MUSCAT', 'Bank Muscat', '2026-10-25T12:00:00+04:00', '2026-10-25T12:00:00+04:00'),

    -- Period 2 (November 2026 - Open) Transactions
    ('99990000-0000-4000-8000-000000000201', '99999999-9999-4999-8999-999999999999', NULL, 'Nama Electricity Bill Nov', '45.000', 'OMR', 'Debit', '660.000', '2026-11-02T11:15:00+04:00', 0, 1, 'Categorized', 'BANK_MUSCAT', 'Bank Muscat', '2026-11-02T11:15:00+04:00', '2026-11-02T11:15:00+04:00'),
    ('99990000-0000-4000-8000-000000000202', '99999999-9999-4999-8999-999999999999', NULL, 'Omantel Fiber Home Internet (Recurring)', '15.000', 'OMR', 'Debit', '645.000', '2026-11-03T09:00:00+04:00', 1, 1, 'Categorized', 'BANK_MUSCAT', 'Bank Muscat', '2026-11-03T09:00:00+04:00', '2026-11-03T09:00:00+04:00'),
    ('99990000-0000-4000-8000-000000000203', '99999999-9999-4999-8999-999999999999', NULL, 'Cloud Hosting & Domain Renewal', '20.000', 'OMR', 'Debit', '625.000', '2026-11-04T15:40:00+04:00', 0, 0, 'Categorized', 'BANK_MUSCAT', 'Bank Muscat', '2026-11-04T15:40:00+04:00', '2026-11-04T15:40:00+04:00'),
    ('99990000-0000-4000-8000-000000000204', '99999999-9999-4999-8999-999999999999', NULL, 'Bait Al Luban Muttrah Dinner', '20.000', 'OMR', 'Debit', '605.000', '2026-11-05T20:30:00+04:00', 0, 0, 'Categorized', 'BANK_MUSCAT', 'Bank Muscat', '2026-11-05T20:30:00+04:00', '2026-11-05T20:30:00+04:00'),
    ('99990000-0000-4000-8000-000000000205', '99999999-9999-4999-8999-999999999999', NULL, 'Specialty Coffee Roasters (Subcategory)', '12.500', 'OMR', 'Debit', '592.500', '2026-11-06T18:10:00+04:00', 0, 0, 'Categorized', 'BANK_MUSCAT', 'Bank Muscat', '2026-11-06T18:10:00+04:00', '2026-11-06T18:10:00+04:00'),
    ('99990000-0000-4000-8000-000000000206', '99999999-9999-4999-8999-999999999999', NULL, 'Bowling & Arcade Night', '12.000', 'OMR', 'Debit', '580.500', '2026-11-07T19:45:00+04:00', 0, 0, 'Categorized', 'BANK_MUSCAT', 'Bank Muscat', '2026-11-07T19:45:00+04:00', '2026-11-07T19:45:00+04:00'),
    ('99990000-0000-4000-8000-000000000207', '99999999-9999-4999-8999-999999999999', NULL, 'Netflix Monthly Subscription (Recurring)', '5.000', 'OMR', 'Debit', '575.500', '2026-11-08T08:00:00+04:00', 1, 0, 'Categorized', 'BANK_MUSCAT', 'Bank Muscat', '2026-11-08T08:00:00+04:00', '2026-11-08T08:00:00+04:00'),
    ('99990000-0000-4000-8000-000000000208', '99999999-9999-4999-8999-999999999999', NULL, 'Dar Al Atta Charity Donation', '5.000', 'OMR', 'Debit', '570.500', '2026-11-08T13:00:00+04:00', 0, 0, 'Categorized', 'BANK_MUSCAT', 'Bank Muscat', '2026-11-08T13:00:00+04:00', '2026-11-08T13:00:00+04:00'),
    ('99990000-0000-4000-8000-000000000209', '99999999-9999-4999-8999-999999999999', NULL, 'Transfer to Savings Account (Excluded Category)', '50.000', 'OMR', 'Debit', '520.500', '2026-11-08T16:00:00+04:00', 0, 0, 'Categorized', 'BANK_MUSCAT', 'Bank Muscat', '2026-11-08T16:00:00+04:00', '2026-11-08T16:00:00+04:00'),
    ('99990000-0000-4000-8000-000000000210', '99999999-9999-4999-8999-999999999999', NULL, 'Cashback Reward Credit (Ignored by Debit-Only Spend)', '10.000', 'OMR', 'Credit', '530.500', '2026-11-08T17:00:00+04:00', 0, 0, 'Categorized', 'BANK_MUSCAT', 'Bank Muscat', '2026-11-08T17:00:00+04:00', '2026-11-08T17:00:00+04:00');

INSERT INTO "PfmTransactionCategories" (
    "Id", "TransactionId", "CategoryId", "SubcategoryId", "Confidence", "Source", "CategorizedAt"
) VALUES
    -- Period 1 Categorizations
    ('99991111-0000-4000-8000-000000000101', '99990000-0000-4000-8000-000000000101', '67cbe620-6139-4c0d-aaba-5e00b2ba8045', '9f36d46e-3067-4eeb-bb0a-bf1da4e7c5f5', 98, 'Rule', '2026-10-05T10:00:00+04:00'),
    ('99991111-0000-4000-8000-000000000102', '99990000-0000-4000-8000-000000000102', '67cbe620-6139-4c0d-aaba-5e00b2ba8045', 'd95b9fe8-9bf5-4417-87e6-7f27f1a26597', 99, 'Rule', '2026-10-06T09:00:00+04:00'),
    ('99991111-0000-4000-8000-000000000103', '99990000-0000-4000-8000-000000000103', 'b2f82d4f-bbfc-462b-bf62-5e5b3ab46f9b', NULL, 95, 'Rule', '2026-10-10T14:20:00+04:00'),
    ('99991111-0000-4000-8000-000000000104', '99990000-0000-4000-8000-000000000104', 'e1a71000-0000-4000-8000-000000000001', NULL, 95, 'Rule', '2026-10-14T20:15:00+04:00'),
    ('99991111-0000-4000-8000-000000000105', '99990000-0000-4000-8000-000000000105', 'e1a71000-0000-4000-8000-000000000001', 'e1a71000-0000-4000-8000-000000000011', 96, 'Merchant', '2026-10-18T17:30:00+04:00'),
    ('99991111-0000-4000-8000-000000000106', '99990000-0000-4000-8000-000000000106', '7ced4f02-a42e-42ec-8f3d-1e4c1deeef42', '69697c10-9d79-4b3b-91a1-203a96f648c7', 97, 'Merchant', '2026-10-21T21:00:00+04:00'),
    ('99991111-0000-4000-8000-000000000107', '99990000-0000-4000-8000-000000000107', '7ced4f02-a42e-42ec-8f3d-1e4c1deeef42', '4a14a47c-6e07-4cfc-8b06-aae825000424', 99, 'Merchant', '2026-10-22T08:00:00+04:00'),
    ('99991111-0000-4000-8000-000000000108', '99990000-0000-4000-8000-000000000108', 'c4a71000-0000-4000-8000-000000000002', NULL, 95, 'Rule', '2026-10-25T12:00:00+04:00'),

    -- Period 2 Categorizations
    ('99991111-0000-4000-8000-000000000201', '99990000-0000-4000-8000-000000000201', '67cbe620-6139-4c0d-aaba-5e00b2ba8045', '9f36d46e-3067-4eeb-bb0a-bf1da4e7c5f5', 98, 'Rule', '2026-11-02T11:15:00+04:00'),
    ('99991111-0000-4000-8000-000000000202', '99990000-0000-4000-8000-000000000202', '67cbe620-6139-4c0d-aaba-5e00b2ba8045', 'd95b9fe8-9bf5-4417-87e6-7f27f1a26597', 99, 'Rule', '2026-11-03T09:00:00+04:00'),
    ('99991111-0000-4000-8000-000000000203', '99990000-0000-4000-8000-000000000203', 'b2f82d4f-bbfc-462b-bf62-5e5b3ab46f9b', NULL, 95, 'Rule', '2026-11-04T15:40:00+04:00'),
    ('99991111-0000-4000-8000-000000000204', '99990000-0000-4000-8000-000000000204', 'e1a71000-0000-4000-8000-000000000001', NULL, 95, 'Rule', '2026-11-05T20:30:00+04:00'),
    ('99991111-0000-4000-8000-000000000205', '99990000-0000-4000-8000-000000000205', 'e1a71000-0000-4000-8000-000000000001', 'e1a71000-0000-4000-8000-000000000011', 96, 'Merchant', '2026-11-06T18:10:00+04:00'),
    ('99991111-0000-4000-8000-000000000206', '99990000-0000-4000-8000-000000000206', '7ced4f02-a42e-42ec-8f3d-1e4c1deeef42', '69697c10-9d79-4b3b-91a1-203a96f648c7', 97, 'Merchant', '2026-11-07T19:45:00+04:00'),
    ('99991111-0000-4000-8000-000000000207', '99990000-0000-4000-8000-000000000207', '7ced4f02-a42e-42ec-8f3d-1e4c1deeef42', '4a14a47c-6e07-4cfc-8b06-aae825000424', 99, 'Merchant', '2026-11-08T08:00:00+04:00'),
    ('99991111-0000-4000-8000-000000000208', '99990000-0000-4000-8000-000000000208', 'c4a71000-0000-4000-8000-000000000002', NULL, 95, 'Rule', '2026-11-08T13:00:00+04:00'),
    ('99991111-0000-4000-8000-000000000209', '99990000-0000-4000-8000-000000000209', 'f0270d2e-be00-4fc9-b7dd-72ec2be15add', '76fc09dc-f145-4e0c-b41a-1e503186da95', 99, 'Rule', '2026-11-08T16:00:00+04:00'),
    ('99991111-0000-4000-8000-000000000210', '99990000-0000-4000-8000-000000000210', 'ea5594a5-e011-4447-a1b7-66102aec9395', 'c9786017-2e99-42f1-9b23-a5a04a3e34c2', 99, 'Rule', '2026-11-08T17:00:00+04:00');

COMMIT;
