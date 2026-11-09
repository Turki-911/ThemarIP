-- =============================================================================
-- UP MIGRATION: Budgeting Schema, Read-Side Views & Rollover Support
-- Database: SQLite (themarip.db) / EF Core 10
-- Money Convention: All monetary values stored as INTEGER in baisa (1 OMR = 1,000 baisa)
-- =============================================================================

PRAGMA foreign_keys = ON;

-- -----------------------------------------------------------------------------
-- 1. budget_settings (One row per user)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS "budget_settings" (
    "Id"                    TEXT    NOT NULL CONSTRAINT "PK_budget_settings" PRIMARY KEY,
    "UserId"                TEXT    NOT NULL,
    "TotalMonthlyBudget"    BIGINT  NOT NULL DEFAULT 0,
    "PeriodStartDay"        INTEGER NOT NULL DEFAULT 1,
    "RolloverEnabled"       INTEGER NOT NULL DEFAULT 1,
    "Currency"              TEXT    NOT NULL DEFAULT 'OMR',
    "CreatedAt"             TEXT    NOT NULL,
    "UpdatedAt"             TEXT    NOT NULL,
    CONSTRAINT "FK_budget_settings_Users_UserId"
        FOREIGN KEY ("UserId") REFERENCES "Users" ("Id") ON DELETE CASCADE,
    CONSTRAINT "CK_budget_settings_TotalMonthlyBudget"
        CHECK ("TotalMonthlyBudget" >= 0),
    CONSTRAINT "CK_budget_settings_PeriodStartDay"
        CHECK ("PeriodStartDay" BETWEEN 1 AND 28),
    CONSTRAINT "CK_budget_settings_RolloverEnabled"
        CHECK ("RolloverEnabled" IN (0, 1))
);

CREATE UNIQUE INDEX IF NOT EXISTS "UX_budget_settings_UserId"
    ON "budget_settings" ("UserId");

-- -----------------------------------------------------------------------------
-- 2. budget_categories (Per-user, per-category budget rules over effective months)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS "budget_categories" (
    "Id"                    TEXT    NOT NULL CONSTRAINT "PK_budget_categories" PRIMARY KEY,
    "UserId"                TEXT    NOT NULL,
    "CategoryId"            TEXT    NOT NULL,
    "BudgetAmount"          BIGINT  NOT NULL,
    "EffectiveFrom"         TEXT    NOT NULL, -- ISO date YYYY-MM-01 (or period start date)
    "EffectiveTo"           TEXT    NULL,     -- NULL = currently active indefinitely
    "CreatedAt"             TEXT    NOT NULL,
    "UpdatedAt"             TEXT    NOT NULL,
    CONSTRAINT "FK_budget_categories_Users_UserId"
        FOREIGN KEY ("UserId") REFERENCES "Users" ("Id") ON DELETE CASCADE,
    CONSTRAINT "FK_budget_categories_PfmCategories_CategoryId"
        FOREIGN KEY ("CategoryId") REFERENCES "PfmCategories" ("Id") ON DELETE RESTRICT,
    CONSTRAINT "CK_budget_categories_BudgetAmount"
        CHECK ("BudgetAmount" >= 0),
    CONSTRAINT "CK_budget_categories_EffectiveRange"
        CHECK ("EffectiveTo" IS NULL OR "EffectiveTo" >= "EffectiveFrom")
);

-- Enforce one active open-ended budget per (UserId, CategoryId)
CREATE UNIQUE INDEX IF NOT EXISTS "UX_budget_categories_Active"
    ON "budget_categories" ("UserId", "CategoryId")
    WHERE "EffectiveTo" IS NULL;

-- Enforce one budget per (UserId, CategoryId, EffectiveFrom)
CREATE UNIQUE INDEX IF NOT EXISTS "UX_budget_categories_User_Cat_From"
    ON "budget_categories" ("UserId", "CategoryId", "EffectiveFrom");

CREATE INDEX IF NOT EXISTS "IX_budget_categories_CategoryId"
    ON "budget_categories" ("CategoryId");

-- Trigger to prevent overlapping effective date ranges for the same (UserId, CategoryId)
CREATE TRIGGER IF NOT EXISTS "TR_budget_categories_NoOverlap_Insert"
BEFORE INSERT ON "budget_categories"
FOR EACH ROW
WHEN EXISTS (
    SELECT 1 FROM "budget_categories" existing
    WHERE existing."UserId" = NEW."UserId"
      AND existing."CategoryId" = NEW."CategoryId"
      AND existing."Id" != NEW."Id"
      AND substr(NEW."EffectiveFrom", 1, 10) <= COALESCE(substr(existing."EffectiveTo", 1, 10), '9999-12-31')
      AND COALESCE(substr(NEW."EffectiveTo", 1, 10), '9999-12-31') >= substr(existing."EffectiveFrom", 1, 10)
)
BEGIN
    SELECT RAISE(ABORT, 'Overlapping effective period for this user and category in budget_categories.');
END;

-- -----------------------------------------------------------------------------
-- 3. budget_excluded_categories (Categories excluded from budget tracking)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS "budget_excluded_categories" (
    "Id"                    TEXT    NOT NULL CONSTRAINT "PK_budget_excluded_categories" PRIMARY KEY,
    "UserId"                TEXT    NOT NULL,
    "CategoryId"            TEXT    NOT NULL,
    "CreatedAt"             TEXT    NOT NULL,
    "UpdatedAt"             TEXT    NOT NULL,
    CONSTRAINT "FK_budget_excluded_categories_Users_UserId"
        FOREIGN KEY ("UserId") REFERENCES "Users" ("Id") ON DELETE CASCADE,
    CONSTRAINT "FK_budget_excluded_categories_PfmCategories_CategoryId"
        FOREIGN KEY ("CategoryId") REFERENCES "PfmCategories" ("Id") ON DELETE CASCADE
);

CREATE UNIQUE INDEX IF NOT EXISTS "UX_budget_excluded_categories_User_Cat"
    ON "budget_excluded_categories" ("UserId", "CategoryId");

-- -----------------------------------------------------------------------------
-- 4. budget_periods (One row per user and period)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS "budget_periods" (
    "Id"                        TEXT    NOT NULL CONSTRAINT "PK_budget_periods" PRIMARY KEY,
    "UserId"                    TEXT    NOT NULL,
    "PeriodStart"               TEXT    NOT NULL, -- ISO YYYY-MM-DD (inclusive)
    "PeriodEnd"                 TEXT    NOT NULL, -- ISO YYYY-MM-DD (exclusive end boundary, e.g. next period start)
    "BaseTotal"                 BIGINT  NOT NULL DEFAULT 0,
    "RolledAmount"              BIGINT  NOT NULL DEFAULT 0, -- May be negative (overspend) or positive (leftover)
    "SpentTotalSnapshot"        BIGINT  NULL,               -- Populated when Status = 'closed'
    "CommittedTotalSnapshot"    BIGINT  NULL,               -- Populated when Status = 'closed'
    "Status"                    TEXT    NOT NULL DEFAULT 'open',
    "ClosedAt"                  TEXT    NULL,
    "CreatedAt"                 TEXT    NOT NULL,
    "UpdatedAt"                 TEXT    NOT NULL,
    CONSTRAINT "FK_budget_periods_Users_UserId"
        FOREIGN KEY ("UserId") REFERENCES "Users" ("Id") ON DELETE CASCADE,
    CONSTRAINT "CK_budget_periods_BaseTotal"
        CHECK ("BaseTotal" >= 0),
    CONSTRAINT "CK_budget_periods_PeriodOrder"
        CHECK ("PeriodEnd" > "PeriodStart"),
    CONSTRAINT "CK_budget_periods_Status"
        CHECK ("Status" IN ('open', 'closed'))
);

-- Prevent duplicate periods for the same user
CREATE UNIQUE INDEX IF NOT EXISTS "UX_budget_periods_User_Start"
    ON "budget_periods" ("UserId", "PeriodStart");

-- Prevent more than one open period per user at a time
CREATE UNIQUE INDEX IF NOT EXISTS "UX_budget_periods_OneOpenPerUser"
    ON "budget_periods" ("UserId")
    WHERE "Status" = 'open';

CREATE INDEX IF NOT EXISTS "IX_budget_periods_User_Dates"
    ON "budget_periods" ("UserId", "PeriodStart", "PeriodEnd");

-- -----------------------------------------------------------------------------
-- 5. budget_period_categories (Per-category figures for each period)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS "budget_period_categories" (
    "Id"                    TEXT    NOT NULL CONSTRAINT "PK_budget_period_categories" PRIMARY KEY,
    "BudgetPeriodId"        TEXT    NOT NULL,
    "CategoryId"            TEXT    NOT NULL,
    "BaseAmount"            BIGINT  NOT NULL DEFAULT 0,
    "RolledAmount"          BIGINT  NOT NULL DEFAULT 0, -- Rollover applies ONLY to parent categories (0 for subcategories)
    "SpentAmount"           BIGINT  NULL,               -- Final spent snapshot populated when period is closed
    "CreatedAt"             TEXT    NOT NULL,
    "UpdatedAt"             TEXT    NOT NULL,
    CONSTRAINT "FK_budget_period_categories_budget_periods_BudgetPeriodId"
        FOREIGN KEY ("BudgetPeriodId") REFERENCES "budget_periods" ("Id") ON DELETE CASCADE,
    CONSTRAINT "FK_budget_period_categories_PfmCategories_CategoryId"
        FOREIGN KEY ("CategoryId") REFERENCES "PfmCategories" ("Id") ON DELETE RESTRICT,
    CONSTRAINT "CK_budget_period_categories_BaseAmount"
        CHECK ("BaseAmount" >= 0),
    CONSTRAINT "CK_budget_period_categories_SpentAmount"
        CHECK ("SpentAmount" IS NULL OR "SpentAmount" >= 0)
);

CREATE UNIQUE INDEX IF NOT EXISTS "UX_budget_period_categories_Period_Cat"
    ON "budget_period_categories" ("BudgetPeriodId", "CategoryId");

CREATE INDEX IF NOT EXISTS "IX_budget_period_categories_CategoryId"
    ON "budget_period_categories" ("CategoryId");

-- Trigger to enforce: Rollover applies to parent categories ONLY, NOT to subcategories
CREATE TRIGGER IF NOT EXISTS "TR_budget_period_categories_NoSubcategoryRollover_Insert"
BEFORE INSERT ON "budget_period_categories"
FOR EACH ROW
WHEN NEW."RolledAmount" != 0 AND EXISTS (
    SELECT 1 FROM "PfmCategories" c
    WHERE c."Id" = NEW."CategoryId" AND c."ParentId" IS NOT NULL
)
BEGIN
    SELECT RAISE(ABORT, 'Subcategories cannot carry a non-zero RolledAmount.');
END;

CREATE TRIGGER IF NOT EXISTS "TR_budget_period_categories_NoSubcategoryRollover_Update"
BEFORE UPDATE OF "RolledAmount", "CategoryId" ON "budget_period_categories"
FOR EACH ROW
WHEN NEW."RolledAmount" != 0 AND EXISTS (
    SELECT 1 FROM "PfmCategories" c
    WHERE c."Id" = NEW."CategoryId" AND c."ParentId" IS NOT NULL
)
BEGIN
    SELECT RAISE(ABORT, 'Subcategories cannot carry a non-zero RolledAmount.');
END;

-- -----------------------------------------------------------------------------
-- 6. Read-Path Composite Indexes on Existing Tables (Additive Only)
-- -----------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS "IX_PfmTransactions_BudgetReadPath"
    ON "PfmTransactions" ("UserId", "TransactionType", "IsRecurring", "TransactionDate");

CREATE INDEX IF NOT EXISTS "IX_PfmTransactionCategories_Tx_Cat_Sub"
    ON "PfmTransactionCategories" ("TransactionId", "CategoryId", "SubcategoryId");

-- =============================================================================
-- STEP 3: READ-SIDE VIEWS
-- =============================================================================

-- -----------------------------------------------------------------------------
-- View 1: vw_budget_resolved_transactions
-- Resolves every PfmTransaction's Amount in integer baisa, its leaf CategoryId
-- (from PfmTransactionCategories first, then MerchantId defaultsubcategory/category),
-- its RootCategoryId (parent category), and whether its category or parent is excluded.
-- -----------------------------------------------------------------------------
DROP VIEW IF EXISTS "vw_budget_resolved_transactions";
CREATE VIEW "vw_budget_resolved_transactions" AS
WITH RawMapped AS (
    SELECT
        t."Id" AS "TransactionId",
        t."UserId",
        t."Narration",
        CAST(ROUND(CAST(t."Amount" AS REAL) * 1000.0) AS BIGINT) AS "AmountBaisa",
        t."Currency",
        t."TransactionType",
        substr(t."TransactionDate", 1, 10) AS "TxDate",
        t."TransactionDate",
        t."IsRecurring",
        COALESCE(
            tc."SubcategoryId",
            tc."CategoryId",
            m."DefaultSubcategoryId",
            m."DefaultCategoryId"
        ) AS "LeafCategoryId"
    FROM "PfmTransactions" t
    LEFT JOIN "PfmTransactionCategories" tc ON tc."TransactionId" = t."Id"
    LEFT JOIN "PfmMerchants" m ON m."Id" = t."MerchantId"
)
SELECT
    rm."TransactionId",
    rm."UserId",
    rm."Narration",
    rm."AmountBaisa",
    rm."Currency",
    rm."TransactionType",
    rm."TxDate",
    rm."TransactionDate",
    rm."IsRecurring",
    rm."LeafCategoryId",
    COALESCE(c."ParentId", c."Id") AS "RootCategoryId",
    c."Name" AS "LeafCategoryName",
     COALESCE(p."Name", c."Name") AS "RootCategoryName",
    CASE
        WHEN EXISTS (
            SELECT 1 FROM "budget_excluded_categories" ex
            WHERE ex."UserId" = rm."UserId"
              AND (ex."CategoryId" = rm."LeafCategoryId" OR ex."CategoryId" = COALESCE(c."ParentId", c."Id"))
        ) THEN 1
        ELSE 0
    END AS "IsExcluded"
FROM RawMapped rm
LEFT JOIN "PfmCategories" c ON c."Id" = rm."LeafCategoryId"
LEFT JOIN "PfmCategories" p ON p."Id" = c."ParentId";

-- -----------------------------------------------------------------------------
-- View 2: vw_budget_period_category_summary
-- Computes per-category figures for each user and period:
--   * DirectSpentBaisa: normal debit spending directly on this category (excluding excluded & recurring)
--   * SubcategoriesSpentBaisa: normal debit spending on child subcategories (for parent categories)
--   * SpentBaisa: for closed periods uses the final SpentAmount snapshot if present;
--                 otherwise includes DirectSpent + SubcategoriesSpent (parent categories include subcategory totals)
--   * CommittedBaisa: recurring/committed debit spending in this category (including child subcategories)
--   * EffectiveBudgetBaisa: BaseAmount + RolledAmount (for parents; subcategories have RolledAmount = 0)
--   * RemainingBaisa: EffectiveBudgetBaisa - SpentBaisa
-- -----------------------------------------------------------------------------
DROP VIEW IF EXISTS "vw_budget_period_category_summary";
CREATE VIEW "vw_budget_period_category_summary" AS
WITH LiveCategorySpend AS (
    SELECT
        bp."Id" AS "BudgetPeriodId",
        bpc."Id" AS "BudgetPeriodCategoryId",
        bp."UserId",
        bp."PeriodStart",
        bp."PeriodEnd",
        bp."Status" AS "PeriodStatus",
        bpc."CategoryId",
        c."ParentId",
        c."Name" AS "CategoryName",
        CASE WHEN c."ParentId" IS NULL THEN 1 ELSE 0 END AS "IsParentCategory",
        bpc."BaseAmount",
        CASE WHEN c."ParentId" IS NULL THEN bpc."RolledAmount" ELSE 0 END AS "RolledAmount",
        bpc."SpentAmount" AS "SnapshotSpentAmount",
        -- Normal spending (Debits only, excluding excluded categories, excluding committed/recurring items)
        -- Parent categories automatically include all transactions where RootCategoryId = CategoryId (parent + all its subcategories)
        COALESCE((
            SELECT SUM(vt."AmountBaisa")
            FROM "vw_budget_resolved_transactions" vt
            WHERE vt."UserId" = bp."UserId"
              AND vt."TransactionType" = 'Debit'
              AND vt."IsRecurring" = 0
              AND vt."IsExcluded" = 0
              AND vt."TxDate" >= substr(bp."PeriodStart", 1, 10)
              AND vt."TxDate" < substr(bp."PeriodEnd", 1, 10)
              AND (
                  (c."ParentId" IS NULL AND vt."RootCategoryId" = c."Id")
                  OR (c."ParentId" IS NOT NULL AND vt."LeafCategoryId" = c."Id")
              )
        ), 0) AS "LiveSpentBaisa",
        -- Committed (recurring) spending for this category (tracked separately from normal spending)
        COALESCE((
            SELECT SUM(vt."AmountBaisa")
            FROM "vw_budget_resolved_transactions" vt
            WHERE vt."UserId" = bp."UserId"
              AND vt."TransactionType" = 'Debit'
              AND vt."IsRecurring" = 1
              AND vt."IsExcluded" = 0
              AND vt."TxDate" >= substr(bp."PeriodStart", 1, 10)
              AND vt."TxDate" < substr(bp."PeriodEnd", 1, 10)
              AND (
                  (c."ParentId" IS NULL AND vt."RootCategoryId" = c."Id")
                  OR (c."ParentId" IS NOT NULL AND vt."LeafCategoryId" = c."Id")
              )
        ), 0) AS "CommittedSpentBaisa"
    FROM "budget_period_categories" bpc
    JOIN "budget_periods" bp ON bp."Id" = bpc."BudgetPeriodId"
    JOIN "PfmCategories" c ON c."Id" = bpc."CategoryId"
)
SELECT
    "BudgetPeriodId",
    "BudgetPeriodCategoryId",
    "UserId",
    "PeriodStart",
    "PeriodEnd",
    "PeriodStatus",
    "CategoryId",
    "ParentId",
    "CategoryName",
    "IsParentCategory",
    "BaseAmount",
    "RolledAmount",
    ("BaseAmount" + "RolledAmount") AS "EffectiveBudgetBaisa",
    CASE
        WHEN "PeriodStatus" = 'closed' AND "SnapshotSpentAmount" IS NOT NULL THEN "SnapshotSpentAmount"
        ELSE "LiveSpentBaisa"
    END AS "SpentBaisa",
    "CommittedSpentBaisa",
    ("BaseAmount" + "RolledAmount") - (
        CASE
            WHEN "PeriodStatus" = 'closed' AND "SnapshotSpentAmount" IS NOT NULL THEN "SnapshotSpentAmount"
            ELSE "LiveSpentBaisa"
        END
    ) AS "RemainingBaisa"
FROM LiveCategorySpend;

-- -----------------------------------------------------------------------------
-- View 3: vw_budget_period_overview
-- Computes the top-level dashboard metrics for a user and period:
--   * BaseTotal, RolledAmount, EffectiveTotalBudgetBaisa (BaseTotal + RolledAmount)
--   * NormalSpentBaisa (debits only, excluding excluded categories, excluding committed/recurring items)
--   * CommittedSpendingBaisa (recurring debits in the period, shown separately from normal spending)
--   * RemainingTotalBaisa (EffectiveTotalBudgetBaisa - NormalSpentBaisa - CommittedSpendingBaisa)
--   * RemainingNormalPoolBaisa (EffectiveTotalBudgetBaisa - NormalSpentBaisa)
--   * DaysRemaining (inclusive of today within [PeriodStart, PeriodEnd))
--   * DailyAllowanceBaisa (amount left divided by days remaining in the period; 0 if <= 0)
-- -----------------------------------------------------------------------------
DROP VIEW IF EXISTS "vw_budget_period_overview";
CREATE VIEW "vw_budget_period_overview" AS
WITH PeriodAgg AS (
    SELECT
        bp."Id" AS "BudgetPeriodId",
        bp."UserId",
        COALESCE(bs."Currency", 'OMR') AS "Currency",
        COALESCE(bs."RolloverEnabled", 1) AS "RolloverEnabled",
        bp."PeriodStart",
        bp."PeriodEnd",
        bp."Status",
        bp."BaseTotal",
        bp."RolledAmount",
        (bp."BaseTotal" + bp."RolledAmount") AS "EffectiveTotalBudgetBaisa",
        CASE
            WHEN bp."Status" = 'closed' AND bp."SpentTotalSnapshot" IS NOT NULL THEN bp."SpentTotalSnapshot"
            ELSE COALESCE((
                SELECT SUM(vt."AmountBaisa")
                FROM "vw_budget_resolved_transactions" vt
                WHERE vt."UserId" = bp."UserId"
                  AND vt."TransactionType" = 'Debit'
                  AND vt."IsRecurring" = 0
                  AND vt."IsExcluded" = 0
                  AND vt."TxDate" >= substr(bp."PeriodStart", 1, 10)
                  AND vt."TxDate" < substr(bp."PeriodEnd", 1, 10)
            ), 0)
        END AS "NormalSpentBaisa",
        CASE
            WHEN bp."Status" = 'closed' AND bp."CommittedTotalSnapshot" IS NOT NULL THEN bp."CommittedTotalSnapshot"
            ELSE COALESCE((
                SELECT SUM(vt."AmountBaisa")
                FROM "vw_budget_resolved_transactions" vt
                WHERE vt."UserId" = bp."UserId"
                  AND vt."TransactionType" = 'Debit'
                  AND vt."IsRecurring" = 1
                  AND vt."IsExcluded" = 0
                  AND vt."TxDate" >= substr(bp."PeriodStart", 1, 10)
                  AND vt."TxDate" < substr(bp."PeriodEnd", 1, 10)
            ), 0)
        END AS "CommittedSpendingBaisa",
        CAST(
            julianday(substr(bp."PeriodEnd", 1, 10)) -
            julianday(substr(bp."PeriodStart", 1, 10))
        AS INTEGER) AS "TotalDaysInPeriod",
        CASE
            WHEN bp."Status" = 'closed' THEN 0
            WHEN date('now') >= substr(bp."PeriodEnd", 1, 10) THEN 0
            WHEN date('now') < substr(bp."PeriodStart", 1, 10) THEN
                CAST(julianday(substr(bp."PeriodEnd", 1, 10)) - julianday(substr(bp."PeriodStart", 1, 10)) AS INTEGER)
            ELSE
                CAST(julianday(substr(bp."PeriodEnd", 1, 10)) - julianday(date('now')) AS INTEGER)
        END AS "DaysRemaining"
    FROM "budget_periods" bp
    LEFT JOIN "budget_settings" bs ON bs."UserId" = bp."UserId"
)
SELECT
    "BudgetPeriodId",
    "UserId",
    "Currency",
    "RolloverEnabled",
    "PeriodStart",
    "PeriodEnd",
    "Status",
    "BaseTotal",
    "RolledAmount",
    "EffectiveTotalBudgetBaisa",
    "NormalSpentBaisa",
    "CommittedSpendingBaisa",
    ("EffectiveTotalBudgetBaisa" - "NormalSpentBaisa") AS "RemainingBeforeCommittedBaisa",
    ("EffectiveTotalBudgetBaisa" - "NormalSpentBaisa" - "CommittedSpendingBaisa") AS "RemainingTotalBaisa",
    "TotalDaysInPeriod",
    "DaysRemaining",
    CASE
        WHEN "DaysRemaining" <= 0 THEN 0
        WHEN ("EffectiveTotalBudgetBaisa" - "NormalSpentBaisa" - "CommittedSpendingBaisa") <= 0 THEN 0
        ELSE CAST(("EffectiveTotalBudgetBaisa" - "NormalSpentBaisa" - "CommittedSpendingBaisa") / "DaysRemaining" AS BIGINT)
    END AS "DailyAllowanceBaisa"
FROM PeriodAgg;
