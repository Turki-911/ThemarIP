-- =============================================================================
-- DOWN MIGRATION: Rollback Budgeting Schema, Views, Triggers & Indexes
-- Database: SQLite (themarip.db) / EF Core 10
-- =============================================================================

PRAGMA foreign_keys = ON;

-- 1. Drop Read-Side Views
DROP VIEW IF EXISTS "vw_budget_period_overview";
DROP VIEW IF EXISTS "vw_budget_period_category_summary";
DROP VIEW IF EXISTS "vw_budget_resolved_transactions";

-- 2. Drop Triggers
DROP TRIGGER IF EXISTS "TR_budget_period_categories_NoSubcategoryRollover_Update";
DROP TRIGGER IF EXISTS "TR_budget_period_categories_NoSubcategoryRollover_Insert";
DROP TRIGGER IF EXISTS "TR_budget_categories_NoOverlap_Insert";

-- 3. Drop Additive Read-Path Indexes on Existing Tables
DROP INDEX IF EXISTS "IX_PfmTransactionCategories_Tx_Cat_Sub";
DROP INDEX IF EXISTS "IX_PfmTransactions_BudgetReadPath";

-- 4. Drop Budgeting Tables (Child-to-Parent Order)
DROP TABLE IF EXISTS "budget_period_categories";
DROP TABLE IF EXISTS "budget_periods";
DROP TABLE IF EXISTS "budget_excluded_categories";
DROP TABLE IF EXISTS "budget_categories";
DROP TABLE IF EXISTS "budget_settings";
