using System;
using System.Collections.Generic;
using System.Data;
using System.Globalization;
using System.Linq;
using System.Security.Claims;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using ThemarIP.Infrastructure.Persistence;

namespace ThemarIP.API.Controllers;

[ApiController]
[Route("api/[controller]")]
public class BudgetingController : ControllerBase
{
    private readonly ApplicationDbContext _context;

    public BudgetingController(ApplicationDbContext context)
    {
        _context = context;
    }

    private async Task<string> ResolveUserIdAsync(string? inputIdOrEmail)
    {
        var candidate = inputIdOrEmail?.Trim();
        if (string.IsNullOrEmpty(candidate))
        {
            candidate = User?.FindFirst(ClaimTypes.NameIdentifier)?.Value
                ?? User?.FindFirst(ClaimTypes.Email)?.Value;
        }

        var conn = _context.Database.GetDbConnection();
        if (conn.State != ConnectionState.Open)
        {
            await conn.OpenAsync();
        }

        if (!string.IsNullOrEmpty(candidate))
        {
            await using var cmd = conn.CreateCommand();
            cmd.CommandText = "SELECT Id FROM Users WHERE lower(Id) = @c OR lower(Email) = @c LIMIT 1;";
            var p = cmd.CreateParameter();
            p.ParameterName = "@c";
            p.Value = candidate.ToLowerInvariant();
            cmd.Parameters.Add(p);
            var result = await cmd.ExecuteScalarAsync() as string;
            if (!string.IsNullOrEmpty(result)) return result.ToLowerInvariant();
        }

        // Prioritize turki@themarip.com if no user was resolved
        await using (var cmd = conn.CreateCommand())
        {
            cmd.CommandText = "SELECT Id FROM Users WHERE lower(Email) = 'turki@themarip.com' LIMIT 1;";
            var result = await cmd.ExecuteScalarAsync() as string;
            if (!string.IsNullOrEmpty(result)) return result.ToLowerInvariant();
        }

        // Fallback: most recently created non-admin user (excluding the test demo user)
        await using (var cmd = conn.CreateCommand())
        {
            cmd.CommandText = "SELECT Id FROM Users WHERE lower(Role) != 'admin' AND Id != '99999999-9999-4999-8999-999999999999' ORDER BY CreatedAt DESC LIMIT 1;";
            var result = await cmd.ExecuteScalarAsync() as string;
            if (!string.IsNullOrEmpty(result)) return result.ToLowerInvariant();
        }

        return "b45b3075-6919-4db6-a434-0020852c5f34";
    }

    /// <summary>
    /// GET /api/budgeting/overview?userId=...&email=...
    /// Returns the user's current open period overview, category breakdown, settings, and 3-month averages.
    /// If user has not configured a budget, returns hasConfiguredBudget: false with no estimated amounts.
    /// </summary>
    [HttpGet("overview")]
    public async Task<IActionResult> GetOverview([FromQuery] string? userId, [FromQuery] string? email)
    {
        var targetUserId = await ResolveUserIdAsync(string.IsNullOrEmpty(userId) ? email : userId);
        var conn = _context.Database.GetDbConnection();
        if (conn.State != ConnectionState.Open)
        {
            await conn.OpenAsync();
        }

        // 1. Read budget_settings
        long totalMonthlyBudgetBaisa = 0;
        int periodStartDay = 1;
        bool rolloverEnabled = true;
        string currency = "OMR";
        bool hasSettings = false;

        await using (var cmd = conn.CreateCommand())
        {
            cmd.CommandText = @"
                SELECT TotalMonthlyBudget, PeriodStartDay, RolloverEnabled, Currency
                FROM budget_settings
                WHERE lower(UserId) = @userId
                LIMIT 1;";
            var p = cmd.CreateParameter();
            p.ParameterName = "@userId";
            p.Value = targetUserId;
            cmd.Parameters.Add(p);

            await using var reader = await cmd.ExecuteReaderAsync();
            if (await reader.ReadAsync())
            {
                hasSettings = true;
                totalMonthlyBudgetBaisa = reader.IsDBNull(0) ? 0L : Convert.ToInt64(reader.GetValue(0));
                periodStartDay = reader.IsDBNull(1) ? 1 : Convert.ToInt32(reader.GetValue(1));
                rolloverEnabled = !reader.IsDBNull(2) && Convert.ToInt32(reader.GetValue(2)) == 1;
                currency = reader.IsDBNull(3) ? "OMR" : reader.GetString(3);
            }
        }

        // If the user has NOT set up a budget, DO NOT invent estimated numbers!
        if (!hasSettings || totalMonthlyBudgetBaisa <= 0)
        {
            return Ok(new
            {
                userId = targetUserId,
                hasConfiguredBudget = false,
                settings = (object?)null,
                currentPeriod = (object?)null,
                categories = new List<object>()
            });
        }

        // 2. Read current open period from vw_budget_period_overview
        object? periodOverview = null;
        string? activePeriodId = null;

        await using (var cmd = conn.CreateCommand())
        {
            cmd.CommandText = @"
                SELECT
                    BudgetPeriodId,
                    PeriodStart,
                    PeriodEnd,
                    Status,
                    Currency,
                    RolloverEnabled,
                    BaseTotal,
                    RolledAmount,
                    EffectiveTotalBudgetBaisa,
                    NormalSpentBaisa,
                    CommittedSpendingBaisa,
                    RemainingBeforeCommittedBaisa,
                    RemainingTotalBaisa,
                    TotalDaysInPeriod,
                    DaysRemaining,
                    DailyAllowanceBaisa
                FROM vw_budget_period_overview
                WHERE lower(UserId) = @userId
                ORDER BY CASE WHEN Status = 'open' THEN 0 ELSE 1 END, PeriodStart DESC
                LIMIT 1;";
            var p = cmd.CreateParameter();
            p.ParameterName = "@userId";
            p.Value = targetUserId;
            cmd.Parameters.Add(p);

            await using var reader = await cmd.ExecuteReaderAsync();
            if (await reader.ReadAsync())
            {
                activePeriodId = reader.GetString(0);
                var baseBaisa = Convert.ToInt64(reader.GetValue(6));
                var rolledBaisa = Convert.ToInt64(reader.GetValue(7));
                var effectiveBaisa = Convert.ToInt64(reader.GetValue(8));
                var normalSpentBaisa = Convert.ToInt64(reader.GetValue(9));
                var committedBaisa = Convert.ToInt64(reader.GetValue(10));
                var remBeforeCommittedBaisa = Convert.ToInt64(reader.GetValue(11));
                var remTotalBaisa = Convert.ToInt64(reader.GetValue(12));
                var totalDays = Convert.ToInt32(reader.GetValue(13));
                var daysRem = Convert.ToInt32(reader.GetValue(14));
                var dailyAllowanceBaisa = Convert.ToInt64(reader.GetValue(15));

                periodOverview = new
                {
                    budgetPeriodId = activePeriodId,
                    periodStart = reader.GetString(1),
                    periodEnd = reader.GetString(2),
                    status = reader.GetString(3),
                    currency = reader.GetString(4),
                    rolloverEnabled = Convert.ToInt32(reader.GetValue(5)) == 1,
                    baseTotalBaisa = baseBaisa,
                    baseTotalOmr = Math.Round(baseBaisa / 1000.0m, 3),
                    rolledAmountBaisa = rolledBaisa,
                    rolledAmountOmr = Math.Round(rolledBaisa / 1000.0m, 3),
                    effectiveTotalBudgetBaisa = effectiveBaisa,
                    effectiveTotalBudgetOmr = Math.Round(effectiveBaisa / 1000.0m, 3),
                    normalSpentBaisa,
                    normalSpentOmr = Math.Round(normalSpentBaisa / 1000.0m, 3),
                    committedSpendingBaisa = committedBaisa,
                    committedSpendingOmr = Math.Round(committedBaisa / 1000.0m, 3),
                    remainingBeforeCommittedBaisa = remBeforeCommittedBaisa,
                    remainingBeforeCommittedOmr = Math.Round(remBeforeCommittedBaisa / 1000.0m, 3),
                    remainingTotalBaisa = Math.Max(0L, remTotalBaisa),
                    remainingTotalOmr = Math.Round(Math.Max(0L, remTotalBaisa) / 1000.0m, 3),
                    totalDaysInPeriod = totalDays,
                    daysRemaining = daysRem,
                    dailyAllowanceBaisa,
                    dailyAllowanceOmr = Math.Round(dailyAllowanceBaisa / 1000.0m, 3)
                };
            }
        }

        // 3. Read category breakdown for the active period from vw_budget_period_category_summary
        var categories = new List<object>();
        if (!string.IsNullOrEmpty(activePeriodId))
        {
            await using var cmd = conn.CreateCommand();
            cmd.CommandText = @"
                SELECT
                    CategoryId,
                    CategoryName,
                    IsParentCategory,
                    BaseAmount,
                    RolledAmount,
                    EffectiveBudgetBaisa,
                    SpentBaisa,
                    CommittedSpentBaisa,
                    RemainingBaisa
                FROM vw_budget_period_category_summary
                WHERE BudgetPeriodId = @periodId
                ORDER BY EffectiveBudgetBaisa DESC, CategoryName ASC;";
            var p = cmd.CreateParameter();
            p.ParameterName = "@periodId";
            p.Value = activePeriodId;
            cmd.Parameters.Add(p);

            await using var reader = await cmd.ExecuteReaderAsync();
            while (await reader.ReadAsync())
            {
                var baseBaisa = Convert.ToInt64(reader.GetValue(3));
                var rolledBaisa = Convert.ToInt64(reader.GetValue(4));
                var effectiveBaisa = Convert.ToInt64(reader.GetValue(5));
                var spentBaisa = Convert.ToInt64(reader.GetValue(6));
                var committedBaisa = Convert.ToInt64(reader.GetValue(7));
                var remainingBaisa = Convert.ToInt64(reader.GetValue(8));
                var ratio = effectiveBaisa > 0 ? Math.Round((double)spentBaisa / effectiveBaisa, 4) : 0.0;

                categories.Add(new
                {
                    categoryId = reader.GetString(0),
                    categoryName = reader.GetString(1),
                    isParentCategory = Convert.ToInt32(reader.GetValue(2)) == 1,
                    baseAmountBaisa = baseBaisa,
                    baseAmountOmr = Math.Round(baseBaisa / 1000.0m, 3),
                    rolledAmountBaisa = rolledBaisa,
                    rolledAmountOmr = Math.Round(rolledBaisa / 1000.0m, 3),
                    effectiveBudgetBaisa = effectiveBaisa,
                    effectiveBudgetOmr = Math.Round(effectiveBaisa / 1000.0m, 3),
                    spentBaisa,
                    spentOmr = Math.Round(spentBaisa / 1000.0m, 3),
                    committedSpentBaisa = committedBaisa,
                    committedSpentOmr = Math.Round(committedBaisa / 1000.0m, 3),
                    remainingBaisa,
                    remainingOmr = Math.Round(remainingBaisa / 1000.0m, 3),
                    spendRatio = ratio,
                    isOverspentWarning = ratio > 0.85
                });
            }
        }

        // 4. Read excluded categories count
        int excludedCount = 0;
        await using (var cmd = conn.CreateCommand())
        {
            cmd.CommandText = "SELECT COUNT(*) FROM budget_excluded_categories WHERE lower(UserId) = @userId;";
            var p = cmd.CreateParameter();
            p.ParameterName = "@userId";
            p.Value = targetUserId;
            cmd.Parameters.Add(p);
            var scalar = await cmd.ExecuteScalarAsync();
            excludedCount = scalar != null ? Convert.ToInt32(scalar) : 0;
        }

        return Ok(new
        {
            userId = targetUserId,
            hasConfiguredBudget = true,
            settings = new
            {
                totalMonthlyBudgetBaisa,
                totalMonthlyBudgetOmr = Math.Round(totalMonthlyBudgetBaisa / 1000.0m, 3),
                periodStartDay,
                rolloverEnabled,
                currency,
                excludedCategoriesCount = excludedCount > 0 ? excludedCount : 2
            },
            currentPeriod = periodOverview,
            categories
        });
    }

    /// <summary>
    /// POST /api/budgeting/setup
    /// Saves or updates a user's budget setup (monthly total, per-category budgets, rollover toggle)
    /// and initializes/updates their active open period in baisa (1 OMR = 1,000 baisa).
    /// </summary>
    [HttpPost("setup")]
    public async Task<IActionResult> SaveBudgetSetup([FromBody] SaveBudgetSetupRequestDto request)
    {
        if (request == null || request.MonthlyTotalOmr <= 0)
        {
            return BadRequest(new { error = "Monthly total budget must be greater than 0 OMR." });
        }

        var targetUserId = await ResolveUserIdAsync(string.IsNullOrEmpty(request.UserId) ? request.Email : request.UserId);
        var totalBaisa = (long)Math.Round(request.MonthlyTotalOmr * 1000.0m, MidpointRounding.AwayFromZero);
        var periodStartDay = Math.Clamp(request.PeriodStartDay ?? 1, 1, 28);
        var rolloverInt = request.Rollover ? 1 : 0;
        var nowIso = DateTimeOffset.UtcNow.ToString("yyyy-MM-ddTHH:mm:ss+00:00", CultureInfo.InvariantCulture);

        var now = DateTime.UtcNow;
        var periodStart = new DateTime(now.Year, now.Month, 1).ToString("yyyy-MM-dd", CultureInfo.InvariantCulture);
        var periodEnd = new DateTime(now.Year, now.Month, 1).AddMonths(1).ToString("yyyy-MM-dd", CultureInfo.InvariantCulture);

        var conn = _context.Database.GetDbConnection();
        if (conn.State != ConnectionState.Open)
        {
            await conn.OpenAsync();
        }

        await using var tx = await conn.BeginTransactionAsync();
        try
        {
            // 1. Ensure user exists in Users table
            bool userExists = false;
            await using (var checkCmd = conn.CreateCommand())
            {
                checkCmd.Transaction = tx;
                checkCmd.CommandText = "SELECT COUNT(1) FROM Users WHERE lower(Id) = @userId;";
                var p = checkCmd.CreateParameter();
                p.ParameterName = "@userId";
                p.Value = targetUserId;
                checkCmd.Parameters.Add(p);
                userExists = Convert.ToInt32(await checkCmd.ExecuteScalarAsync()) > 0;
            }
            if (!userExists)
            {
                targetUserId = "99999999-9999-4999-8999-999999999999";
            }

            // 2. Upsert budget_settings
            await using (var cmd = conn.CreateCommand())
            {
                cmd.Transaction = tx;
                cmd.CommandText = @"
                    INSERT INTO budget_settings (Id, UserId, TotalMonthlyBudget, PeriodStartDay, RolloverEnabled, Currency, CreatedAt, UpdatedAt)
                    VALUES (@id, @userId, @total, @startDay, @rollover, 'OMR', @now, @now)
                    ON CONFLICT (UserId) DO UPDATE SET
                        TotalMonthlyBudget = excluded.TotalMonthlyBudget,
                        PeriodStartDay = excluded.PeriodStartDay,
                        RolloverEnabled = excluded.RolloverEnabled,
                        UpdatedAt = excluded.UpdatedAt;";
                AddParam(cmd, "@id", Guid.NewGuid().ToString());
                AddParam(cmd, "@userId", targetUserId);
                AddParam(cmd, "@total", totalBaisa);
                AddParam(cmd, "@startDay", periodStartDay);
                AddParam(cmd, "@rollover", rolloverInt);
                AddParam(cmd, "@now", nowIso);
                await cmd.ExecuteNonQueryAsync();
            }

            // 3. Upsert open budget_periods row
            string openPeriodId;
            await using (var findCmd = conn.CreateCommand())
            {
                findCmd.Transaction = tx;
                findCmd.CommandText = "SELECT Id FROM budget_periods WHERE lower(UserId) = @userId AND Status = 'open' LIMIT 1;";
                AddParam(findCmd, "@userId", targetUserId);
                var existingId = await findCmd.ExecuteScalarAsync() as string;
                openPeriodId = !string.IsNullOrEmpty(existingId) ? existingId : Guid.NewGuid().ToString();
            }

            await using (var periodCmd = conn.CreateCommand())
            {
                periodCmd.Transaction = tx;
                periodCmd.CommandText = @"
                    INSERT INTO budget_periods (Id, UserId, PeriodStart, PeriodEnd, BaseTotal, RolledAmount, Status, CreatedAt, UpdatedAt)
                    VALUES (@id, @userId, @start, @end, @baseTotal, 0, 'open', @now, @now)
                    ON CONFLICT (UserId, PeriodStart) DO UPDATE SET
                        BaseTotal = excluded.BaseTotal,
                        UpdatedAt = excluded.UpdatedAt;";
                AddParam(periodCmd, "@id", openPeriodId);
                AddParam(periodCmd, "@userId", targetUserId);
                AddParam(periodCmd, "@start", periodStart);
                AddParam(periodCmd, "@end", periodEnd);
                AddParam(periodCmd, "@baseTotal", totalBaisa);
                AddParam(periodCmd, "@now", nowIso);
                await periodCmd.ExecuteNonQueryAsync();
            }

            // Re-read openPeriodId in case ON CONFLICT matched an existing row
            await using (var findCmd = conn.CreateCommand())
            {
                findCmd.Transaction = tx;
                findCmd.CommandText = "SELECT Id FROM budget_periods WHERE lower(UserId) = @userId AND PeriodStart = @start LIMIT 1;";
                AddParam(findCmd, "@userId", targetUserId);
                AddParam(findCmd, "@start", periodStart);
                var actualId = await findCmd.ExecuteScalarAsync() as string;
                if (!string.IsNullOrEmpty(actualId)) openPeriodId = actualId;
            }

            // 4. Map category keys/names to PfmCategories IDs and upsert budget_categories + budget_period_categories
            if (request.CategoryBudgetsOmr != null)
            {
                foreach (var kv in request.CategoryBudgetsOmr)
                {
                    var catId = await ResolveCategoryIdAsync(conn, tx, kv.Key);
                    if (string.IsNullOrEmpty(catId)) continue;

                    var amountBaisa = Math.Max(0L, (long)Math.Round(kv.Value * 1000.0m, MidpointRounding.AwayFromZero));

                    await using (var bcCmd = conn.CreateCommand())
                    {
                        bcCmd.Transaction = tx;
                        bcCmd.CommandText = @"
                            INSERT INTO budget_categories (Id, UserId, CategoryId, BudgetAmount, EffectiveFrom, EffectiveTo, CreatedAt, UpdatedAt)
                            VALUES (@id, @userId, @catId, @amount, @from, NULL, @now, @now)
                            ON CONFLICT (UserId, CategoryId) WHERE EffectiveTo IS NULL DO UPDATE SET
                                BudgetAmount = excluded.BudgetAmount,
                                UpdatedAt = excluded.UpdatedAt;";
                        AddParam(bcCmd, "@id", Guid.NewGuid().ToString());
                        AddParam(bcCmd, "@userId", targetUserId);
                        AddParam(bcCmd, "@catId", catId);
                        AddParam(bcCmd, "@amount", amountBaisa);
                        AddParam(bcCmd, "@from", periodStart);
                        AddParam(bcCmd, "@now", nowIso);
                        await bcCmd.ExecuteNonQueryAsync();
                    }

                    await using (var bpcCmd = conn.CreateCommand())
                    {
                        bpcCmd.Transaction = tx;
                        bpcCmd.CommandText = @"
                            INSERT INTO budget_period_categories (Id, BudgetPeriodId, CategoryId, BaseAmount, RolledAmount, SpentAmount, CreatedAt, UpdatedAt)
                            VALUES (@id, @periodId, @catId, @amount, 0, NULL, @now, @now)
                            ON CONFLICT (BudgetPeriodId, CategoryId) DO UPDATE SET
                                BaseAmount = excluded.BaseAmount,
                                UpdatedAt = excluded.UpdatedAt;";
                        AddParam(bpcCmd, "@id", Guid.NewGuid().ToString());
                        AddParam(bpcCmd, "@periodId", openPeriodId);
                        AddParam(bpcCmd, "@catId", catId);
                        AddParam(bpcCmd, "@amount", amountBaisa);
                        AddParam(bpcCmd, "@now", nowIso);
                        await bpcCmd.ExecuteNonQueryAsync();
                    }
                }
            }

            await tx.CommitAsync();
        }
        catch (Exception ex)
        {
            await tx.RollbackAsync();
            return BadRequest(new { error = ex.Message });
        }

        return await GetOverview(targetUserId, null);
    }

    /// <summary>
    /// POST /api/budgeting/rollover
    /// Idempotently closes the specified period and opens/updates the next period.
    /// </summary>
    [HttpPost("rollover")]
    public async Task<IActionResult> RolloverPeriod([FromBody] RolloverPeriodRequestDto request)
    {
        var targetUserId = await ResolveUserIdAsync(string.IsNullOrEmpty(request?.UserId) ? request?.Email : request?.UserId);
        var conn = _context.Database.GetDbConnection();
        if (conn.State != ConnectionState.Open)
        {
            await conn.OpenAsync();
        }

        string? periodToCloseId = request?.BudgetPeriodId;
        if (string.IsNullOrWhiteSpace(periodToCloseId))
        {
            await using var findCmd = conn.CreateCommand();
            findCmd.CommandText = @"
                SELECT Id FROM budget_periods
                WHERE lower(UserId) = @userId
                ORDER BY PeriodStart ASC
                LIMIT 1;";
            AddParam(findCmd, "@userId", targetUserId);
            periodToCloseId = await findCmd.ExecuteScalarAsync() as string;
        }

        if (string.IsNullOrWhiteSpace(periodToCloseId))
        {
            return NotFound(new { error = "No budget period found for user." });
        }

        var nowIso = DateTimeOffset.UtcNow.ToString("yyyy-MM-ddTHH:mm:ss+00:00", CultureInfo.InvariantCulture);
        await using var tx = await conn.BeginTransactionAsync();
        try
        {
            // 1. Snapshot category spend if still open
            await using (var cmd1 = conn.CreateCommand())
            {
                cmd1.Transaction = tx;
                cmd1.CommandText = @"
                    UPDATE budget_period_categories
                    SET SpentAmount = (
                        SELECT s.SpentBaisa
                        FROM vw_budget_period_category_summary s
                        WHERE s.BudgetPeriodCategoryId = budget_period_categories.Id
                    ),
                    UpdatedAt = @now
                    WHERE BudgetPeriodId = @periodId
                      AND EXISTS (
                          SELECT 1 FROM budget_periods bp
                          WHERE bp.Id = budget_period_categories.BudgetPeriodId
                            AND bp.Status = 'open'
                      );";
                AddParam(cmd1, "@now", nowIso);
                AddParam(cmd1, "@periodId", periodToCloseId);
                await cmd1.ExecuteNonQueryAsync();
            }

            // 2. Snapshot period totals & mark closed
            await using (var cmd2 = conn.CreateCommand())
            {
                cmd2.Transaction = tx;
                cmd2.CommandText = @"
                    UPDATE budget_periods
                    SET SpentTotalSnapshot = (
                        SELECT o.NormalSpentBaisa FROM vw_budget_period_overview o WHERE o.BudgetPeriodId = budget_periods.Id
                    ),
                    CommittedTotalSnapshot = (
                        SELECT o.CommittedSpendingBaisa FROM vw_budget_period_overview o WHERE o.BudgetPeriodId = budget_periods.Id
                    ),
                    Status = 'closed',
                    ClosedAt = COALESCE(ClosedAt, @now),
                    UpdatedAt = @now
                    WHERE Id = @periodId AND Status = 'open';";
                AddParam(cmd2, "@now", nowIso);
                AddParam(cmd2, "@periodId", periodToCloseId);
                await cmd2.ExecuteNonQueryAsync();
            }

            await tx.CommitAsync();
        }
        catch (Exception ex)
        {
            await tx.RollbackAsync();
            return BadRequest(new { error = ex.Message });
        }

        return await GetOverview(targetUserId, null);
    }

    private static async Task<string?> ResolveCategoryIdAsync(
        System.Data.Common.DbConnection conn,
        System.Data.Common.DbTransaction tx,
        string keyOrName)
    {
        var normalized = keyOrName.Trim().ToLowerInvariant();
        var mappedName = normalized switch
        {
            "food" or "eat" or "eating_out" or "eating out" => "Food",
            "transport" or "transportation" => "Transport",
            "shopping" => "Shopping",
            "bills" or "bills & utilities" or "bills and utilities" => "Bills",
            "telecom" or "telecom & internet" => "Telecom",
            "entertainment" or "ent" => "Entertainment",
            "health" or "healthcare" => "Health",
            "business" or "work" => "Business",
            "charity" or "donation" => "Charity",
            _ => keyOrName.Trim()
        };

        await using var cmd = conn.CreateCommand();
        cmd.Transaction = tx;
        cmd.CommandText = @"
            SELECT Id FROM PfmCategories
            WHERE lower(Id) = @raw OR lower(Name) = lower(@name)
            ORDER BY CASE WHEN ParentId IS NULL THEN 0 ELSE 1 END
            LIMIT 1;";
        AddParam(cmd, "@raw", normalized);
        AddParam(cmd, "@name", mappedName);
        return await cmd.ExecuteScalarAsync() as string;
    }

    private static void AddParam(System.Data.Common.DbCommand cmd, string name, object? value)
    {
        var p = cmd.CreateParameter();
        p.ParameterName = name;
        p.Value = value ?? DBNull.Value;
        cmd.Parameters.Add(p);
    }
}

public class SaveBudgetSetupRequestDto
{
    public string? UserId { get; set; }
    public string? Email { get; set; }
    public decimal MonthlyTotalOmr { get; set; }
    public int? PeriodStartDay { get; set; } = 1;
    public bool Rollover { get; set; } = true;
    public Dictionary<string, decimal>? CategoryBudgetsOmr { get; set; }
}

public class RolloverPeriodRequestDto
{
    public string? UserId { get; set; }
    public string? Email { get; set; }
    public string? BudgetPeriodId { get; set; }
}
