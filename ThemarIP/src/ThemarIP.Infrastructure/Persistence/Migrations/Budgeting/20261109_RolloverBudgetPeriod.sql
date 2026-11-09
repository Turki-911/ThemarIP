-- =============================================================================
-- STEP 4: IDEMPOTENT PERIOD CLOSE & ROLLOVER SQL PROCEDURE / TRANSACTION
-- =============================================================================
-- Purpose:
--   Closes a target period (e.g. Period 1) and opens/populates the next period
--   (e.g. Period 2) for a given user.
--
-- Rollover Rules Enforced:
--   1. Idempotent:
--      * Only computes and locks the final SpentAmount snapshot if the old period
--        is not yet closed (or if SpentAmount is NULL).
--      * Uses INSERT INTO ... ON CONFLICT DO UPDATE (UPSERT) keyed on
--        (UserId, PeriodStart) for budget_periods and (BudgetPeriodId, CategoryId)
--        for budget_period_categories so running this script 1 time or 10 times
--        produces the exact same rolled_amount and never double-counts.
--   2. Parent vs. Subcategory Rollover:
--      * Rollover applies ONLY to the total budget and parent categories
--        (c.ParentId IS NULL) when budget_settings.RolloverEnabled = 1.
--      * Subcategories (c.ParentId IS NOT NULL) always receive RolledAmount = 0.
--   3. Overspend & Leftover:
--      * Leftover (> 0) increases the next period's available budget.
--      * Overspend (< 0) reduces the next period's available budget (negative RolledAmount).
-- =============================================================================

PRAGMA foreign_keys = ON;
BEGIN IMMEDIATE TRANSACTION;

-- -----------------------------------------------------------------------------
-- Step 4.1: Snapshot final per-category normal spending on the period being closed
-- (Only updates rows where the period is still 'open', making it idempotent)
-- -----------------------------------------------------------------------------
UPDATE "budget_period_categories"
SET
    "SpentAmount" = (
        SELECT s."SpentBaisa"
        FROM "vw_budget_period_category_summary" s
        WHERE s."BudgetPeriodCategoryId" = "budget_period_categories"."Id"
    ),
    "UpdatedAt" = strftime('%Y-%m-%dT%H:%M:%S+00:00', 'now')
WHERE "BudgetPeriodId" = 'bp000000-0000-4000-8000-000000000001'
  AND EXISTS (
      SELECT 1 FROM "budget_periods" bp
      WHERE bp."Id" = "budget_period_categories"."BudgetPeriodId"
        AND bp."Status" = 'open'
  );

-- -----------------------------------------------------------------------------
-- Step 4.2: Snapshot total normal & committed spend and mark the old period 'closed'
-- (WHERE Status = 'open' guarantees a second run is a safe no-op)
-- -----------------------------------------------------------------------------
UPDATE "budget_periods"
SET
    "SpentTotalSnapshot" = (
        SELECT o."NormalSpentBaisa"
        FROM "vw_budget_period_overview" o
        WHERE o."BudgetPeriodId" = "budget_periods"."Id"
    ),
    "CommittedTotalSnapshot" = (
        SELECT o."CommittedSpendingBaisa"
        FROM "vw_budget_period_overview" o
        WHERE o."BudgetPeriodId" = "budget_periods"."Id"
    ),
    "Status" = 'closed',
    "ClosedAt" = COALESCE("ClosedAt", strftime('%Y-%m-%dT%H:%M:%S+00:00', 'now')),
    "UpdatedAt" = strftime('%Y-%m-%dT%H:%M:%S+00:00', 'now')
WHERE "Id" = 'bp000000-0000-4000-8000-000000000001'
  AND "Status" = 'open';

-- -----------------------------------------------------------------------------
-- Step 4.3: Open (or deterministically update) the next period in budget_periods
-- Computes RolledAmount directly from the closed period's immutable snapshot:
--   RolledAmount = (BaseTotal + RolledAmount) - SpentTotalSnapshot - CommittedTotalSnapshot
--   (or 0 if budget_settings.RolloverEnabled = 0)
-- -----------------------------------------------------------------------------
INSERT INTO "budget_periods" (
    "Id",
    "UserId",
    "PeriodStart",
    "PeriodEnd",
    "BaseTotal",
    "RolledAmount",
    "SpentTotalSnapshot",
    "CommittedTotalSnapshot",
    "Status",
    "ClosedAt",
    "CreatedAt",
    "UpdatedAt"
)
SELECT
    'bp000000-0000-4000-8000-000000000002' AS "Id",
    prev."UserId",
    prev."PeriodEnd" AS "PeriodStart",
    date(prev."PeriodEnd", '+1 month') AS "PeriodEnd",
    bs."TotalMonthlyBudget" AS "BaseTotal",
    CASE
        WHEN bs."RolloverEnabled" = 1 THEN
            (prev."BaseTotal" + prev."RolledAmount")
            - COALESCE(prev."SpentTotalSnapshot", 0)
            - COALESCE(prev."CommittedTotalSnapshot", 0)
        ELSE 0
    END AS "RolledAmount",
    NULL AS "SpentTotalSnapshot",
    NULL AS "CommittedTotalSnapshot",
    'open' AS "Status",
    NULL AS "ClosedAt",
    strftime('%Y-%m-%dT%H:%M:%S+00:00', 'now') AS "CreatedAt",
    strftime('%Y-%m-%dT%H:%M:%S+00:00', 'now') AS "UpdatedAt"
FROM "budget_periods" prev
JOIN "budget_settings" bs ON bs."UserId" = prev."UserId"
WHERE prev."Id" = 'bp000000-0000-4000-8000-000000000001'
  AND prev."Status" = 'closed'
ON CONFLICT ("UserId", "PeriodStart") DO UPDATE SET
    "BaseTotal" = excluded."BaseTotal",
    "RolledAmount" = excluded."RolledAmount",
    "UpdatedAt" = excluded."UpdatedAt";

-- -----------------------------------------------------------------------------
-- Step 4.4: Populate (or deterministically update) budget_period_categories
-- for the new period from active budget_categories + parent rollover from prev period.
-- Rollover applies ONLY to parent categories (c.ParentId IS NULL) and NEVER to subcategories.
-- -----------------------------------------------------------------------------
INSERT INTO "budget_period_categories" (
    "Id",
    "BudgetPeriodId",
    "CategoryId",
    "BaseAmount",
    "RolledAmount",
    "SpentAmount",
    "CreatedAt",
    "UpdatedAt"
)
SELECT
    COALESCE(
        (SELECT existing."Id"
         FROM "budget_period_categories" existing
         WHERE existing."BudgetPeriodId" = next_bp."Id"
           AND existing."CategoryId" = bc."CategoryId"),
        lower(hex(randomblob(4)) || '-' || hex(randomblob(2)) || '-4' || substr(hex(randomblob(2)),2) || '-8' || substr(hex(randomblob(2)),2) || '-' || hex(randomblob(6)))
    ) AS "Id",
    next_bp."Id" AS "BudgetPeriodId",
    bc."CategoryId",
    bc."BudgetAmount" AS "BaseAmount",
    CASE
        WHEN bs."RolloverEnabled" = 1
             AND c."ParentId" IS NULL
             AND prev_bpc."Id" IS NOT NULL
        THEN (prev_bpc."BaseAmount" + prev_bpc."RolledAmount") - COALESCE(prev_bpc."SpentAmount", 0)
        ELSE 0
    END AS "RolledAmount",
    NULL AS "SpentAmount",
    strftime('%Y-%m-%dT%H:%M:%S+00:00', 'now') AS "CreatedAt",
    strftime('%Y-%m-%dT%H:%M:%S+00:00', 'now') AS "UpdatedAt"
FROM "budget_periods" prev_bp
JOIN "budget_periods" next_bp
    ON next_bp."UserId" = prev_bp."UserId"
   AND next_bp."PeriodStart" = prev_bp."PeriodEnd"
JOIN "budget_settings" bs
    ON bs."UserId" = prev_bp."UserId"
JOIN "budget_categories" bc
    ON bc."UserId" = prev_bp."UserId"
   AND substr(bc."EffectiveFrom", 1, 10) <= substr(next_bp."PeriodStart", 1, 10)
   AND (bc."EffectiveTo" IS NULL OR substr(bc."EffectiveTo", 1, 10) >= substr(next_bp."PeriodEnd", 1, 10))
JOIN "PfmCategories" c
    ON c."Id" = bc."CategoryId"
LEFT JOIN "budget_period_categories" prev_bpc
    ON prev_bpc."BudgetPeriodId" = prev_bp."Id"
   AND prev_bpc."CategoryId" = bc."CategoryId"
WHERE prev_bp."Id" = 'bp000000-0000-4000-8000-000000000001'
  AND prev_bp."Status" = 'closed'
ON CONFLICT ("BudgetPeriodId", "CategoryId") DO UPDATE SET
    "BaseAmount" = excluded."BaseAmount",
    "RolledAmount" = excluded."RolledAmount",
    "UpdatedAt" = excluded."UpdatedAt";

COMMIT;
