-- =============================================================================
-- STEP 6: FIVE SAMPLE QUERIES AGAINST THE SEED DATA
-- Test User: 99999999-9999-4999-8999-999999999999 (budget.demo@themar.ip)
-- =============================================================================

.headers on
.mode column

-- -----------------------------------------------------------------------------
-- QUERY 1: Top-Level Dashboard for the Current Open Period (Nov 2026)
-- Shows BaseTotal, RolledAmount, EffectiveTotalBudget, NormalSpent,
-- CommittedSpending, RemainingTotal, DaysRemaining, and DailyAllowance.
-- -----------------------------------------------------------------------------
SELECT '=== QUERY 1: Current Period Top-Level Dashboard ===' AS QueryTitle;
SELECT
    PeriodStart,
    PeriodEnd,
    Status,
    Currency,
    BaseTotal AS BaseBaisa,
    printf('%.3f', BaseTotal / 1000.0) AS BaseOMR,
    RolledAmount AS RolledBaisa,
    printf('%.3f', RolledAmount / 1000.0) AS RolledOMR,
    EffectiveTotalBudgetBaisa AS EffectiveBaisa,
    printf('%.3f', EffectiveTotalBudgetBaisa / 1000.0) AS EffectiveOMR,
    NormalSpentBaisa,
    printf('%.3f', NormalSpentBaisa / 1000.0) AS NormalSpentOMR,
    CommittedSpendingBaisa AS CommittedBaisa,
    printf('%.3f', CommittedSpendingBaisa / 1000.0) AS CommittedOMR,
    RemainingTotalBaisa AS RemainingBaisa,
    printf('%.3f', RemainingTotalBaisa / 1000.0) AS RemainingOMR,
    DaysRemaining,
    DailyAllowanceBaisa,
    printf('%.3f', DailyAllowanceBaisa / 1000.0) AS DailyAllowanceOMR
FROM vw_budget_period_overview
WHERE UserId = '99999999-9999-4999-8999-999999999999'
  AND Status = 'open';

-- -----------------------------------------------------------------------------
-- QUERY 2: "What's Left in Eating Out?" (Including Subcategory Roll-Up)
-- Shows how the parent category "Eating out" (Base 95.000 + Rolled 15.000 = 110.000 OMR)
-- automatically aggregates direct Eating out spend (20.000 OMR) + child subcategory
-- "Restaurants & Cafes" spend (12.500 OMR) = 32.500 OMR spent, leaving 77.500 OMR.
-- -----------------------------------------------------------------------------
SELECT '=== QUERY 2: What is Left in Eating Out (with Subcategory Roll-up) ===' AS QueryTitle;
SELECT
    CategoryName,
    BaseAmount AS BaseBaisa,
    printf('%.3f', BaseAmount / 1000.0) AS BaseOMR,
    RolledAmount AS RolledBaisa,
    printf('%.3f', RolledAmount / 1000.0) AS RolledOMR,
    EffectiveBudgetBaisa AS EffectiveBaisa,
    printf('%.3f', EffectiveBudgetBaisa / 1000.0) AS EffectiveOMR,
    SpentBaisa,
    printf('%.3f', SpentBaisa / 1000.0) AS SpentOMR,
    CommittedSpentBaisa AS CommittedBaisa,
    RemainingBaisa,
    printf('%.3f', RemainingBaisa / 1000.0) AS RemainingOMR
FROM vw_budget_period_category_summary
WHERE UserId = '99999999-9999-4999-8999-999999999999'
  AND PeriodStatus = 'open'
  AND CategoryName = 'Eating out';

-- -----------------------------------------------------------------------------
-- QUERY 3: Full Per-Category Breakdown for the Current Open Period (5 Categories)
-- Ordered by EffectiveBudget descending.
-- -----------------------------------------------------------------------------
SELECT '=== QUERY 3: All 5 Budget Categories Breakdown (Current Period) ===' AS QueryTitle;
SELECT
    CategoryName,
    BaseAmount AS BaseBaisa,
    RolledAmount AS RolledBaisa,
    EffectiveBudgetBaisa AS EffectiveBaisa,
    SpentBaisa AS NormalSpentBaisa,
    CommittedSpentBaisa AS CommittedBaisa,
    RemainingBaisa,
    printf('%.3f OMR', RemainingBaisa / 1000.0) AS RemainingFormatted,
    ROUND((CAST(SpentBaisa AS REAL) / NULLIF(EffectiveBudgetBaisa, 0)) * 100.0, 1) AS PctUsed
FROM vw_budget_period_category_summary
WHERE UserId = '99999999-9999-4999-8999-999999999999'
  AND PeriodStatus = 'open'
ORDER BY EffectiveBudgetBaisa DESC;

-- -----------------------------------------------------------------------------
-- QUERY 4: Committed (Recurring) Spending vs. Excluded Transactions Audit
-- Lists recurring bills/subscriptions tracked separately and excluded transfers.
-- -----------------------------------------------------------------------------
SELECT '=== QUERY 4: Committed (Recurring) & Excluded Transactions in Current Period ===' AS QueryTitle;
SELECT
    TxDate,
    Narration,
    RootCategoryName AS ParentCategory,
    LeafCategoryName AS LeafCategory,
    AmountBaisa,
    printf('%.3f OMR', AmountBaisa / 1000.0) AS AmountOMR,
    TransactionType,
    CASE
        WHEN IsExcluded = 1 THEN 'EXCLUDED_CATEGORY'
        WHEN TransactionType = 'Credit' THEN 'IGNORED_CREDIT'
        WHEN IsRecurring = 1 THEN 'COMMITTED_RECURRING'
        ELSE 'NORMAL_BUDGET_SPEND'
    END AS BudgetClassification
FROM vw_budget_resolved_transactions
WHERE UserId = '99999999-9999-4999-8999-999999999999'
  AND TxDate >= '2026-11-01'
  AND TxDate < '2026-12-01'
ORDER BY TxDate ASC, TransactionDate ASC;

-- -----------------------------------------------------------------------------
-- QUERY 5: Period-over-Period Rollover Verification (Period 1 Closed -> Period 2 Open)
-- Verifies that Period 1's (BaseAmount + RolledAmount - SpentAmount) equals
-- Period 2's RolledAmount for every parent category.
-- -----------------------------------------------------------------------------
SELECT '=== QUERY 5: Period 1 -> Period 2 Rollover Verification ===' AS QueryTitle;
SELECT
    p1.CategoryName,
    p1.BaseAmount AS P1_BaseBaisa,
    p1.SpentBaisa AS P1_FinalSpentBaisa,
    p1.RemainingBaisa AS P1_LeftoverOrOverspendBaisa,
    p2.BaseAmount AS P2_BaseBaisa,
    p2.RolledAmount AS P2_RolledInBaisa,
    p2.EffectiveBudgetBaisa AS P2_EffectiveBudgetBaisa,
    CASE
        WHEN p1.RemainingBaisa = p2.RolledAmount THEN 'MATCH'
        ELSE 'MISMATCH'
    END AS RolloverIntegrity
FROM vw_budget_period_category_summary p1
JOIN vw_budget_period_category_summary p2
    ON p2.UserId = p1.UserId
   AND p2.CategoryId = p1.CategoryId
WHERE p1.UserId = '99999999-9999-4999-8999-999999999999'
  AND p1.PeriodStart = '2026-10-01'
  AND p2.PeriodStart = '2026-11-01'
ORDER BY p1.BaseAmount DESC;
