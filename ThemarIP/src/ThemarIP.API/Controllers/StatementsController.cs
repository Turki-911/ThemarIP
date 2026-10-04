using System.Threading.Tasks;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using ThemarIP.Application.DTOs.Statements;
using ThemarIP.Application.Interfaces.Statements;

namespace ThemarIP.API.Controllers;

[ApiController]
[Route("api/[controller]")]
public class StatementsController : ControllerBase
{
    private readonly IStatementExtractionService _extractionService;
    private readonly IBankNotificationParserService _notificationParser;
    private readonly IMailboxPullerService _mailboxPuller;

    public StatementsController(
        IStatementExtractionService extractionService,
        IBankNotificationParserService notificationParser,
        IMailboxPullerService mailboxPuller)
    {
        _extractionService = extractionService;
        _notificationParser = notificationParser;
        _mailboxPuller = mailboxPuller;
    }

    [HttpPost("parse")]
    public async Task<IActionResult> ParseStatement(IFormFile file, [FromQuery] string? bankCode, [FromForm] string? bank)
    {
        if (file == null || file.Length == 0)
            return BadRequest("No file uploaded.");

        if (file.ContentType != "application/pdf")
            return BadRequest("File must be a PDF.");

        var selectedBank = !string.IsNullOrWhiteSpace(bankCode) ? bankCode : (!string.IsNullOrWhiteSpace(bank) ? bank : "BANK_MUSCAT");

        using var stream = file.OpenReadStream();
        var result = await _extractionService.ProcessUploadAsync(stream, selectedBank);

        return Ok(result);
    }

    [HttpPost("confirm")]
    public async Task<IActionResult> ConfirmStatement([FromBody] ConfirmStatementRequestDto request)
    {
        if (request == null)
            return BadRequest("Invalid payload.");

        try
        {
            var success = await _extractionService.ConfirmAndImportAsync(request);
            if (success) return Ok(new { message = "Statement imported successfully." });
            return BadRequest("Import failed.");
        }
        catch (System.Exception ex)
        {
            return BadRequest(new { error = ex.Message });
        }
    }

    [HttpGet("transactions")]
    public async Task<IActionResult> GetTransactions(
        [FromQuery] System.Guid? userId,
        [FromServices] ThemarIP.Application.Common.Interfaces.IApplicationDbContext context)
    {
        var query = context.PfmTransactions.AsQueryable();
        if (userId.HasValue)
        {
            query = query.Where(t => t.UserId == userId.Value);
        }
        var txns = await Microsoft.EntityFrameworkCore.EntityFrameworkQueryableExtensions.ToListAsync(query);
        return Ok(txns);
    }

    [HttpGet("users")]
    public async Task<IActionResult> GetUsers([FromServices] ThemarIP.Application.Common.Interfaces.IApplicationDbContext context)
    {
        var users = await Microsoft.EntityFrameworkCore.EntityFrameworkQueryableExtensions.ToListAsync(context.Users);
        var txList = await Microsoft.EntityFrameworkCore.EntityFrameworkQueryableExtensions.ToListAsync(
            context.PfmTransactions
                .Select(t => new { UserId = t.UserId, BankCode = t.BankCode, BankName = t.BankName })
        );

        var txByUser = txList
            .GroupBy(t => t.UserId)
            .ToDictionary(
                g => g.Key,
                g => g.GroupBy(x => new { Code = x.BankCode ?? "BANK_MUSCAT", Name = x.BankName ?? "Bank Muscat" })
                      .Select(bg => new UserBankSummaryDto { Code = bg.Key.Code, Name = bg.Key.Name, TxCount = bg.Count() })
                      .ToList()
            );

        var result = users.Select(u =>
        {
            txByUser.TryGetValue(u.Id, out var userBanks);
            userBanks ??= new List<UserBankSummaryDto>();

            var connectedBanks = userBanks.Select(b => b.Name).ToList();
            if (!string.IsNullOrWhiteSpace(u.AccountNumber) && !connectedBanks.Any(b => string.Equals(b, u.AccountNumber, StringComparison.OrdinalIgnoreCase)))
            {
                connectedBanks.Add(u.AccountNumber);
            }
            var primaryBank = !string.IsNullOrEmpty(u.AccountNumber) ? u.AccountNumber : userBanks.FirstOrDefault()?.Name;
            var totalTx = userBanks.Sum(b => b.TxCount);

            return new
            {
                id = u.Id,
                email = u.Email,
                fullName = u.FullName,
                accountNumber = u.AccountNumber,
                banks = userBanks,
                connectedBanks = connectedBanks,
                primaryBank = primaryBank,
                totalTransactions = totalTx,
                role = u.Role.ToString(),
                accessStatus = u.AccessStatus.ToString(),
                trustScore = u.TrustScore,
                createdAt = u.CreatedAt
            };
        }).OrderByDescending(u => u.createdAt).ToList();

        return Ok(result);
    }

    [HttpPatch("users/{id}/profile")]
    public async Task<IActionResult> UpdateUserProfile(
        System.Guid id,
        [FromBody] UpdateUserProfileDto dto,
        [FromServices] ThemarIP.Application.Common.Interfaces.IApplicationDbContext context)
    {
        var user = await context.Users.FindAsync(id);
        if (user == null) return NotFound("User not found.");

        if (!string.IsNullOrEmpty(dto.AccessStatus) &&
            System.Enum.TryParse<ThemarIP.Domain.Enums.AccessStatus>(dto.AccessStatus, true, out var status))
        {
            user.AccessStatus = status;
        }

        if (dto.TrustScore.HasValue)
        {
            user.TrustScore = System.Math.Clamp(dto.TrustScore.Value, 0, 100);
        }

        if (!string.IsNullOrEmpty(dto.Role) &&
            System.Enum.TryParse<ThemarIP.Domain.Enums.UserRole>(dto.Role, true, out var role))
        {
            user.Role = role;
        }

        if (!string.IsNullOrWhiteSpace(dto.FullName))
        {
            user.FullName = dto.FullName.Trim();
        }

        if (!string.IsNullOrWhiteSpace(dto.PrimaryBank))
        {
            user.AccountNumber = dto.PrimaryBank.Trim();
        }

        await context.SaveChangesAsync(default);
        return Ok(new
        {
            message = "User profile updated successfully.",
            user = new
            {
                id = user.Id,
                fullName = user.FullName,
                email = user.Email,
                role = user.Role.ToString(),
                accessStatus = user.AccessStatus.ToString(),
                trustScore = user.TrustScore,
                accountNumber = user.AccountNumber,
                primaryBank = user.AccountNumber
            }
        });
    }

    [HttpPatch("users/{id}/score")]
    public async Task<IActionResult> UpdateUserTrustScore(
        System.Guid id,
        [FromBody] UpdateScoreDto dto,
        [FromServices] ThemarIP.Application.Common.Interfaces.IApplicationDbContext context)
    {
        var user = await context.Users.FindAsync(id);
        if (user == null) return NotFound("User not found.");

        user.TrustScore = System.Math.Clamp(dto.TrustScore, 0, 100);
        await context.SaveChangesAsync(default);
        return Ok(new { message = "Trust score updated.", trustScore = user.TrustScore });
    }

    [HttpPatch("users/{id}/status")]
    public async Task<IActionResult> UpdateUserStatus(
        System.Guid id,
        [FromBody] UpdateStatusDto dto,
        [FromServices] ThemarIP.Application.Common.Interfaces.IApplicationDbContext context)
    {
        var user = await context.Users.FindAsync(id);
        if (user == null) return NotFound("User not found.");

        if (System.Enum.TryParse<ThemarIP.Domain.Enums.AccessStatus>(dto.Status, true, out var status))
        {
            user.AccessStatus = status;
            await context.SaveChangesAsync(default);
            return Ok(new { message = "User status updated.", status = user.AccessStatus.ToString() });
        }
        return BadRequest("Invalid access status.");
    }

    [HttpPost("user-bank-selection")]
    public async Task<IActionResult> SaveUserBankSelection(
        [FromBody] UserBankSelectionDto dto,
        [FromServices] ThemarIP.Application.Common.Interfaces.IApplicationDbContext context)
    {
        if (dto == null) return BadRequest(new { message = "Invalid request payload." });

        ThemarIP.Domain.Entities.User? user = null;
        if (dto.UserId.HasValue && dto.UserId.Value != System.Guid.Empty)
        {
            user = await context.Users.FindAsync(dto.UserId.Value);
        }
        else if (!string.IsNullOrWhiteSpace(dto.Email))
        {
            user = await Microsoft.EntityFrameworkCore.EntityFrameworkQueryableExtensions.FirstOrDefaultAsync(
                context.Users, u => u.Email.ToLower() == dto.Email.ToLower());
        }

        if (user == null)
        {
            var userIdClaim = User?.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value
                           ?? User?.FindFirst("sub")?.Value;
            if (!string.IsNullOrEmpty(userIdClaim) && System.Guid.TryParse(userIdClaim, out var claimGuid))
            {
                user = await context.Users.FindAsync(claimGuid);
            }
        }

        if (user == null)
        {
            // If still null, fallback to the latest active non-admin user
            user = await Microsoft.EntityFrameworkCore.EntityFrameworkQueryableExtensions.FirstOrDefaultAsync(
                context.Users.OrderByDescending(u => u.CreatedAt),
                u => u.Role != ThemarIP.Domain.Enums.UserRole.Admin);
        }

        if (user == null)
        {
            return NotFound(new { message = "User not found to associate bank selection." });
        }

        string bankDisplayName = !string.IsNullOrWhiteSpace(dto.BankName) ? dto.BankName.Trim() : (dto.BankCode ?? "Unknown Bank");
        user.AccountNumber = bankDisplayName;

        // If trust score is 0, give initial baseline score of 75 upon bank connection
        if (user.TrustScore == 0)
        {
            user.TrustScore = 75;
        }

        await context.SaveChangesAsync(default);

        return Ok(new
        {
            success = true,
            message = "Bank selection linked to themarip.db successfully.",
            userId = user.Id,
            fullName = user.FullName,
            email = user.Email,
            selectedBank = user.AccountNumber,
            trustScore = user.TrustScore
        });
    }

    [HttpDelete("users/{id}")]
    public async Task<IActionResult> DeleteUser(
        System.Guid id,
        [FromServices] ThemarIP.Application.Common.Interfaces.IApplicationDbContext context)
    {
        var user = await context.Users.FindAsync(id);
        if (user == null) return NotFound("User not found.");

        if (user.Email.Equals("admin@themar.ip", System.StringComparison.OrdinalIgnoreCase) ||
            user.Role == ThemarIP.Domain.Enums.UserRole.Admin)
        {
            return BadRequest("Cannot delete system administrator account.");
        }

        var subs = context.Subscriptions.Where(s => s.UserId == id);
        context.Subscriptions.RemoveRange(subs);

        var kyc = context.KycSubmissions.Where(k => k.UserId == id);
        context.KycSubmissions.RemoveRange(kyc);

        var txns = context.PfmTransactions.Where(t => t.UserId == id);
        context.PfmTransactions.RemoveRange(txns);

        context.Users.Remove(user);
        await context.SaveChangesAsync(default);
        return Ok(new { message = $"User {user.Email} successfully deleted." });
    }

    [HttpDelete("users/purge-non-admin")]
    public async Task<IActionResult> PurgeNonAdminUsers(
        [FromServices] ThemarIP.Application.Common.Interfaces.IApplicationDbContext context)
    {
        var nonAdmins = await Microsoft.EntityFrameworkCore.EntityFrameworkQueryableExtensions.ToListAsync(
            context.Users.Where(u => u.Role != ThemarIP.Domain.Enums.UserRole.Admin && u.Email != "admin@themar.ip"));

        var nonAdminIds = nonAdmins.Select(u => u.Id).ToList();

        var subs = context.Subscriptions.Where(s => nonAdminIds.Contains(s.UserId));
        context.Subscriptions.RemoveRange(subs);

        var kyc = context.KycSubmissions.Where(k => nonAdminIds.Contains(k.UserId));
        context.KycSubmissions.RemoveRange(kyc);

        var txns = context.PfmTransactions.Where(t => nonAdminIds.Contains(t.UserId));
        context.PfmTransactions.RemoveRange(txns);

        context.Users.RemoveRange(nonAdmins);
        await context.SaveChangesAsync(default);

        return Ok(new { message = $"Successfully purged {nonAdmins.Count} users. Only administrator account remains." });
    }

    [HttpDelete("transactions")]
    public async Task<IActionResult> DeleteAllTransactions([FromServices] ThemarIP.Application.Common.Interfaces.IApplicationDbContext context)
    {
        context.PfmTransactions.RemoveRange(context.PfmTransactions);
        await context.SaveChangesAsync(default);
        return Ok(new { message = "All transactions deleted successfully." });
    }

    [HttpGet("category-rules")]
    public async Task<IActionResult> GetCategoryRules([FromServices] ThemarIP.Application.Common.Interfaces.IApplicationDbContext context)
    {
        var rules = await Microsoft.EntityFrameworkCore.EntityFrameworkQueryableExtensions.ToListAsync(
            Microsoft.EntityFrameworkCore.EntityFrameworkQueryableExtensions.Include(
                context.PfmCategorizationRules,
                r => r.Conditions
            )
        );

        var allCategories = await Microsoft.EntityFrameworkCore.EntityFrameworkQueryableExtensions.ToListAsync(context.PfmCategories);
        var catDict = allCategories.ToDictionary(c => c.Id, c => c.Name);

        var result = rules.OrderByDescending(r => r.Priority).Select(r =>
        {
            catDict.TryGetValue(r.CategoryId ?? Guid.Empty, out var catName);
            catDict.TryGetValue(r.SubcategoryId ?? Guid.Empty, out var subName);

            return new
            {
                id = r.Id.ToString(),
                name = r.Name,
                categoryId = r.CategoryId?.ToString() ?? "",
                categoryName = catName ?? "",
                subcategoryId = r.SubcategoryId?.ToString() ?? "",
                subcategoryName = subName ?? "",
                confidence = r.Confidence,
                priority = r.Priority,
                status = r.Status.ToString().ToLowerInvariant(),
                matchCount = r.MatchCount,
                isLearnedFromCorrection = r.IsLearnedFromCorrection,
                conditions = r.Conditions.OrderBy(c => c.OrderIndex).Select(c => new
                {
                    id = c.Id.ToString(),
                    field = MapConditionFieldToString(c.Field),
                    @operator = MapConditionOperatorToString(c.Operator),
                    value = c.Value,
                    logic = c.LogicOperator == ThemarIP.Domain.Enums.Pfm.RuleConditionLogic.Or ? "OR" : "AND"
                }).ToList()
            };
        }).ToList();

        return Ok(result);
    }

    [HttpPost("category-rules")]
    public async Task<IActionResult> CreateCategoryRule(
        [FromBody] SaveCategorizationRuleDto dto,
        [FromServices] ThemarIP.Application.Common.Interfaces.IApplicationDbContext context)
    {
        if (dto == null || string.IsNullOrWhiteSpace(dto.Name))
            return BadRequest(new { message = "Rule name is required." });

        var rule = new ThemarIP.Domain.Entities.Pfm.PfmCategorizationRule
        {
            Id = Guid.NewGuid(),
            Name = dto.Name.Trim(),
            CategoryId = dto.CategoryId,
            SubcategoryId = dto.SubcategoryId,
            Confidence = Math.Clamp(dto.Confidence, 0, 100),
            Priority = Math.Clamp(dto.Priority, 1, 100),
            Status = string.Equals(dto.Status, "inactive", StringComparison.OrdinalIgnoreCase) 
                ? ThemarIP.Domain.Enums.Pfm.RuleStatus.Inactive 
                : ThemarIP.Domain.Enums.Pfm.RuleStatus.Active,
            CreatedAt = DateTimeOffset.UtcNow,
            UpdatedAt = DateTimeOffset.UtcNow
        };

        if (dto.Conditions != null && dto.Conditions.Count > 0)
        {
            for (int i = 0; i < dto.Conditions.Count; i++)
            {
                var c = dto.Conditions[i];
                rule.Conditions.Add(new ThemarIP.Domain.Entities.Pfm.PfmRuleCondition
                {
                    Id = Guid.NewGuid(),
                    RuleId = rule.Id,
                    Field = ParseConditionField(c.Field),
                    Operator = ParseConditionOperator(c.Operator),
                    Value = c.Value ?? "",
                    LogicOperator = string.Equals(c.Logic, "OR", StringComparison.OrdinalIgnoreCase)
                        ? ThemarIP.Domain.Enums.Pfm.RuleConditionLogic.Or
                        : ThemarIP.Domain.Enums.Pfm.RuleConditionLogic.And,
                    OrderIndex = i
                });
            }
        }

        context.PfmCategorizationRules.Add(rule);
        await context.SaveChangesAsync(default);

        return Ok(new
        {
            success = true,
            message = "Rule created and persisted to themarip.db.",
            id = rule.Id.ToString()
        });
    }

    [HttpPut("category-rules/{id}")]
    public async Task<IActionResult> UpdateCategoryRule(
        [FromRoute] Guid id,
        [FromBody] SaveCategorizationRuleDto dto,
        [FromServices] ThemarIP.Application.Common.Interfaces.IApplicationDbContext context)
    {
        if (dto == null || string.IsNullOrWhiteSpace(dto.Name))
            return BadRequest(new { message = "Rule name is required." });

        var rules = await Microsoft.EntityFrameworkCore.EntityFrameworkQueryableExtensions.ToListAsync(
            Microsoft.EntityFrameworkCore.EntityFrameworkQueryableExtensions.Include(
                context.PfmCategorizationRules,
                r => r.Conditions
            )
        );
        var rule = rules.FirstOrDefault(r => r.Id == id || string.Equals(r.Id.ToString(), id.ToString(), StringComparison.OrdinalIgnoreCase));
        if (rule == null) return NotFound(new { message = "Rule not found." });

        rule.Name = dto.Name.Trim();
        rule.CategoryId = dto.CategoryId;
        rule.SubcategoryId = dto.SubcategoryId;
        rule.Confidence = Math.Clamp(dto.Confidence, 0, 100);
        rule.Priority = Math.Clamp(dto.Priority, 1, 100);
        rule.Status = string.Equals(dto.Status, "inactive", StringComparison.OrdinalIgnoreCase)
            ? ThemarIP.Domain.Enums.Pfm.RuleStatus.Inactive
            : ThemarIP.Domain.Enums.Pfm.RuleStatus.Active;
        rule.UpdatedAt = DateTimeOffset.UtcNow;

        // Clear existing conditions and replace
        if (rule.Conditions.Count > 0)
        {
            context.PfmRuleConditions.RemoveRange(rule.Conditions);
        }

        if (dto.Conditions != null && dto.Conditions.Count > 0)
        {
            for (int i = 0; i < dto.Conditions.Count; i++)
            {
                var c = dto.Conditions[i];
                context.PfmRuleConditions.Add(new ThemarIP.Domain.Entities.Pfm.PfmRuleCondition
                {
                    Id = Guid.NewGuid(),
                    RuleId = rule.Id,
                    Field = ParseConditionField(c.Field),
                    Operator = ParseConditionOperator(c.Operator),
                    Value = c.Value ?? "",
                    LogicOperator = string.Equals(c.Logic, "OR", StringComparison.OrdinalIgnoreCase)
                        ? ThemarIP.Domain.Enums.Pfm.RuleConditionLogic.Or
                        : ThemarIP.Domain.Enums.Pfm.RuleConditionLogic.And,
                    OrderIndex = i
                });
            }
        }

        await context.SaveChangesAsync(default);
        return Ok(new { success = true, message = "Rule updated and persisted to themarip.db." });
    }

    [HttpPatch("category-rules/{id}/toggle")]
    public async Task<IActionResult> ToggleCategoryRule(
        [FromRoute] Guid id,
        [FromServices] ThemarIP.Application.Common.Interfaces.IApplicationDbContext context)
    {
        var rules = await Microsoft.EntityFrameworkCore.EntityFrameworkQueryableExtensions.ToListAsync(context.PfmCategorizationRules);
        var rule = rules.FirstOrDefault(r => r.Id == id || string.Equals(r.Id.ToString(), id.ToString(), StringComparison.OrdinalIgnoreCase));
        if (rule == null) return NotFound(new { message = "Rule not found." });

        rule.Status = rule.Status == ThemarIP.Domain.Enums.Pfm.RuleStatus.Active
            ? ThemarIP.Domain.Enums.Pfm.RuleStatus.Inactive
            : ThemarIP.Domain.Enums.Pfm.RuleStatus.Active;
        rule.UpdatedAt = DateTimeOffset.UtcNow;

        await context.SaveChangesAsync(default);
        return Ok(new
        {
            success = true,
            message = "Rule status toggled.",
            status = rule.Status.ToString().ToLowerInvariant()
        });
    }

    [HttpDelete("category-rules/{id}")]
    public async Task<IActionResult> DeleteCategoryRule(
        [FromRoute] Guid id,
        [FromServices] ThemarIP.Application.Common.Interfaces.IApplicationDbContext context)
    {
        var rules = await Microsoft.EntityFrameworkCore.EntityFrameworkQueryableExtensions.ToListAsync(
            Microsoft.EntityFrameworkCore.EntityFrameworkQueryableExtensions.Include(
                context.PfmCategorizationRules,
                r => r.Conditions
            )
        );
        var rule = rules.FirstOrDefault(r => r.Id == id || string.Equals(r.Id.ToString(), id.ToString(), StringComparison.OrdinalIgnoreCase));
        if (rule == null) return NotFound(new { message = "Rule not found." });

        if (rule.Conditions.Count > 0)
        {
            context.PfmRuleConditions.RemoveRange(rule.Conditions);
        }
        context.PfmCategorizationRules.Remove(rule);
        await context.SaveChangesAsync(default);

        return Ok(new { success = true, message = "Rule deleted from themarip.db successfully." });
    }

    [HttpGet("confidence-settings")]
    public async Task<IActionResult> GetConfidenceSettings([FromServices] ThemarIP.Application.Common.Interfaces.IApplicationDbContext context)
    {
        var bands = await Microsoft.EntityFrameworkCore.EntityFrameworkQueryableExtensions.ToListAsync(context.PfmConfidenceBands);
        var weights = await Microsoft.EntityFrameworkCore.EntityFrameworkQueryableExtensions.ToListAsync(context.PfmConfidenceWeights);

        var highBand = bands.FirstOrDefault(b => b.BandName == ThemarIP.Domain.Enums.Pfm.ConfidenceBandName.High);
        var medBand = bands.FirstOrDefault(b => b.BandName == ThemarIP.Domain.Enums.Pfm.ConfidenceBandName.Medium);
        var lowBand = bands.FirstOrDefault(b => b.BandName == ThemarIP.Domain.Enums.Pfm.ConfidenceBandName.Low);

        var merchantWeight = weights.FirstOrDefault(w => w.Signal == ThemarIP.Domain.Enums.Pfm.ConfidenceSignal.MerchantMatch)?.WeightPercent ?? 40;
        var mccWeight = weights.FirstOrDefault(w => w.Signal == ThemarIP.Domain.Enums.Pfm.ConfidenceSignal.MccMatch)?.WeightPercent ?? 30;
        var narrationWeight = weights.FirstOrDefault(w => w.Signal == ThemarIP.Domain.Enums.Pfm.ConfidenceSignal.NarrationMatch)?.WeightPercent ?? 15;
        var historicalWeight = weights.FirstOrDefault(w => w.Signal == ThemarIP.Domain.Enums.Pfm.ConfidenceSignal.HistoricalMatch)?.WeightPercent ?? 10;
        var amountWeight = weights.FirstOrDefault(w => w.Signal == ThemarIP.Domain.Enums.Pfm.ConfidenceSignal.AmountPattern)?.WeightPercent ?? 5;

        return Ok(new
        {
            weights = new
            {
                merchantMatch = merchantWeight,
                mccMatch = mccWeight,
                narrationMatch = narrationWeight,
                historicalMatch = historicalWeight,
                amountPattern = amountWeight
            },
            bands = new
            {
                high = new
                {
                    min = highBand?.MinThreshold ?? 90,
                    max = highBand?.MaxThreshold ?? 100,
                    action = highBand?.Action.ToString().ToLowerInvariant() switch
                    {
                        "autocategorize" => "auto_categorize",
                        "categorizandmonitor" => "categorize_and_monitor",
                        _ => "auto_categorize"
                    }
                },
                medium = new
                {
                    min = medBand?.MinThreshold ?? 70,
                    max = medBand?.MaxThreshold ?? 89,
                    action = medBand?.Action.ToString().ToLowerInvariant() switch
                    {
                        "autocategorize" => "auto_categorize",
                        "categorizandmonitor" => "categorize_and_monitor",
                        _ => "categorize_and_monitor"
                    }
                },
                low = new
                {
                    min = lowBand?.MinThreshold ?? 0,
                    max = lowBand?.MaxThreshold ?? 69,
                    action = "send_to_review"
                }
            }
        });
    }

    [HttpPost("confidence-settings")]
    public async Task<IActionResult> SaveConfidenceSettings(
        [FromBody] System.Text.Json.JsonElement body,
        [FromServices] ThemarIP.Application.Common.Interfaces.IApplicationDbContext context)
    {
        var bands = await Microsoft.EntityFrameworkCore.EntityFrameworkQueryableExtensions.ToListAsync(context.PfmConfidenceBands);
        var weights = await Microsoft.EntityFrameworkCore.EntityFrameworkQueryableExtensions.ToListAsync(context.PfmConfidenceWeights);

        if (body.TryGetProperty("weights", out var wElem))
        {
            if (wElem.TryGetProperty("merchantMatch", out var mm))
            {
                var w = weights.FirstOrDefault(x => x.Signal == ThemarIP.Domain.Enums.Pfm.ConfidenceSignal.MerchantMatch);
                if (w != null) w.WeightPercent = mm.GetInt32();
            }
            if (wElem.TryGetProperty("mccMatch", out var mcc))
            {
                var w = weights.FirstOrDefault(x => x.Signal == ThemarIP.Domain.Enums.Pfm.ConfidenceSignal.MccMatch);
                if (w != null) w.WeightPercent = mcc.GetInt32();
            }
            if (wElem.TryGetProperty("narrationMatch", out var nm))
            {
                var w = weights.FirstOrDefault(x => x.Signal == ThemarIP.Domain.Enums.Pfm.ConfidenceSignal.NarrationMatch);
                if (w != null) w.WeightPercent = nm.GetInt32();
            }
            if (wElem.TryGetProperty("historicalMatch", out var hm))
            {
                var w = weights.FirstOrDefault(x => x.Signal == ThemarIP.Domain.Enums.Pfm.ConfidenceSignal.HistoricalMatch);
                if (w != null) w.WeightPercent = hm.GetInt32();
            }
            if (wElem.TryGetProperty("amountPattern", out var ap))
            {
                var w = weights.FirstOrDefault(x => x.Signal == ThemarIP.Domain.Enums.Pfm.ConfidenceSignal.AmountPattern);
                if (w != null) w.WeightPercent = ap.GetInt32();
            }
        }

        if (body.TryGetProperty("bands", out var bElem))
        {
            if (bElem.TryGetProperty("high", out var hb))
            {
                var b = bands.FirstOrDefault(x => x.BandName == ThemarIP.Domain.Enums.Pfm.ConfidenceBandName.High);
                if (b != null)
                {
                    if (hb.TryGetProperty("min", out var min)) b.MinThreshold = min.GetInt32();
                    if (hb.TryGetProperty("max", out var max)) b.MaxThreshold = max.GetInt32();
                }
            }
            if (bElem.TryGetProperty("medium", out var mb))
            {
                var b = bands.FirstOrDefault(x => x.BandName == ThemarIP.Domain.Enums.Pfm.ConfidenceBandName.Medium);
                if (b != null)
                {
                    if (mb.TryGetProperty("min", out var min)) b.MinThreshold = min.GetInt32();
                    if (mb.TryGetProperty("max", out var max)) b.MaxThreshold = max.GetInt32();
                }
            }
            if (bElem.TryGetProperty("low", out var lb))
            {
                var b = bands.FirstOrDefault(x => x.BandName == ThemarIP.Domain.Enums.Pfm.ConfidenceBandName.Low);
                if (b != null)
                {
                    if (lb.TryGetProperty("min", out var min)) b.MinThreshold = min.GetInt32();
                    if (lb.TryGetProperty("max", out var max)) b.MaxThreshold = max.GetInt32();
                }
            }
        }

        await context.SaveChangesAsync(default);
        return Ok(new { success = true, message = "Confidence settings saved to themarip.db successfully." });
    }

    [HttpGet("intelligence-rules")]
    public async Task<IActionResult> GetIntelligenceRules([FromServices] ThemarIP.Application.Common.Interfaces.IApplicationDbContext context)
    {
        var rules = await Microsoft.EntityFrameworkCore.EntityFrameworkQueryableExtensions.ToListAsync(
            Microsoft.EntityFrameworkCore.EntityFrameworkQueryableExtensions.Include(
                context.PfmIntelligenceRules,
                r => r.Params
            )
        );

        var result = rules.Select(r => new
        {
            id = r.Id.ToString(),
            type = r.RuleType.ToString(),
            name = r.Name,
            description = r.InsightTemplate,
            status = r.Status.ToString().ToLowerInvariant(),
            alertSeverity = "Medium",
            cooldownHours = 24,
            @params = r.Params.Select(p => new
            {
                id = p.Id.ToString(),
                paramKey = p.ParamKey,
                displayName = p.ParamKey,
                paramType = p.ParamType.ToString(),
                paramValue = p.ParamValue
            }).ToList()
        }).ToList();

        return Ok(result);
    }

    [HttpPatch("intelligence-rules/{id}/toggle")]
    public async Task<IActionResult> ToggleIntelligenceRule(
        [FromRoute] Guid id,
        [FromServices] ThemarIP.Application.Common.Interfaces.IApplicationDbContext context)
    {
        var rules = await Microsoft.EntityFrameworkCore.EntityFrameworkQueryableExtensions.ToListAsync(context.PfmIntelligenceRules);
        var rule = rules.FirstOrDefault(r => r.Id == id || string.Equals(r.Id.ToString(), id.ToString(), StringComparison.OrdinalIgnoreCase));
        if (rule == null) return NotFound(new { message = "Rule not found." });

        rule.Status = rule.Status == ThemarIP.Domain.Enums.Pfm.IntelligenceRuleStatus.Active
            ? ThemarIP.Domain.Enums.Pfm.IntelligenceRuleStatus.Inactive
            : ThemarIP.Domain.Enums.Pfm.IntelligenceRuleStatus.Active;
        rule.UpdatedAt = DateTimeOffset.UtcNow;

        await context.SaveChangesAsync(default);
        return Ok(new { success = true, status = rule.Status.ToString().ToLowerInvariant() });
    }

    [HttpPut("intelligence-rules/{id}")]
    public async Task<IActionResult> UpdateIntelligenceRule(
        [FromRoute] Guid id,
        [FromBody] System.Text.Json.JsonElement body,
        [FromServices] ThemarIP.Application.Common.Interfaces.IApplicationDbContext context)
    {
        var rules = await Microsoft.EntityFrameworkCore.EntityFrameworkQueryableExtensions.ToListAsync(
            Microsoft.EntityFrameworkCore.EntityFrameworkQueryableExtensions.Include(
                context.PfmIntelligenceRules,
                r => r.Params
            )
        );
        var rule = rules.FirstOrDefault(r => r.Id == id || string.Equals(r.Id.ToString(), id.ToString(), StringComparison.OrdinalIgnoreCase));
        if (rule == null) return NotFound(new { message = "Rule not found." });

        if (body.TryGetProperty("name", out var nameElem))
        {
            rule.Name = nameElem.GetString() ?? rule.Name;
        }
        if (body.TryGetProperty("insightTemplate", out var templateElem))
        {
            rule.InsightTemplate = templateElem.GetString() ?? rule.InsightTemplate;
        }
        if (body.TryGetProperty("status", out var statusElem))
        {
            var statusStr = statusElem.GetString();
            if (string.Equals(statusStr, "active", StringComparison.OrdinalIgnoreCase))
                rule.Status = ThemarIP.Domain.Enums.Pfm.IntelligenceRuleStatus.Active;
            else if (string.Equals(statusStr, "inactive", StringComparison.OrdinalIgnoreCase))
                rule.Status = ThemarIP.Domain.Enums.Pfm.IntelligenceRuleStatus.Inactive;
        }
        if (body.TryGetProperty("params", out var paramsElem) && paramsElem.ValueKind == System.Text.Json.JsonValueKind.Object)
        {
            foreach (var prop in paramsElem.EnumerateObject())
            {
                var p = rule.Params.FirstOrDefault(x => string.Equals(x.ParamKey, prop.Name, StringComparison.OrdinalIgnoreCase));
                if (p != null)
                {
                    p.ParamValue = prop.Value.ToString();
                    p.UpdatedAt = DateTimeOffset.UtcNow;
                }
            }
        }

        rule.UpdatedAt = DateTimeOffset.UtcNow;
        await context.SaveChangesAsync(default);
        return Ok(new { success = true, message = "Intelligence rule updated in themarip.db." });
    }

    [HttpGet("categories-hierarchy")]
    public async Task<IActionResult> GetCategoryHierarchy([FromServices] ThemarIP.Application.Common.Interfaces.IApplicationDbContext context)
    {
        // Query top-level categories (ParentId == null) and include their Children
        var rootCategories = await Microsoft.EntityFrameworkCore.EntityFrameworkQueryableExtensions.ToListAsync(
            Microsoft.EntityFrameworkCore.EntityFrameworkQueryableExtensions.Include(
                context.PfmCategories.Where(c => c.ParentId == null),
                c => c.Children
            )
        );

        // Map to format that works seamlessly for frontend:
        // Returns id, name, icon, color, displayOrder, isEnabled, parentId,
        // and both 'children' and 'subcategories' (for backwards compatibility)
        var result = rootCategories.Select(c => new
        {
            id = c.Id,
            name = c.Name,
            icon = c.Icon,
            color = c.Color,
            displayOrder = c.DisplayOrder,
            isEnabled = c.IsEnabled,
            parentId = c.ParentId,
            children = c.Children.Select(sub => new
            {
                id = sub.Id,
                categoryId = c.Id,
                parentId = sub.ParentId,
                name = sub.Name,
                icon = sub.Icon,
                color = sub.Color,
                displayOrder = sub.DisplayOrder,
                isEnabled = sub.IsEnabled
            }).ToList(),
            subcategories = c.Children.Select(sub => new
            {
                id = sub.Id,
                categoryId = c.Id,
                parentId = sub.ParentId,
                name = sub.Name,
                icon = sub.Icon,
                color = sub.Color,
                displayOrder = sub.DisplayOrder,
                isEnabled = sub.IsEnabled
            }).ToList()
        }).ToList();

        return Ok(result);
    }

    /// <summary>
    /// Single source of truth: counts transactions per PfmCategory name
    /// by matching PfmTransaction.Narration against active PfmMerchants (and PfmMerchantAliases)
    /// and active CategoryRules / PfmCategorizationRules.
    /// Both Admin Portal and BMPF call this endpoint — single unified server-side engine.
    /// </summary>
    [HttpGet("category-stats")]
    public async Task<IActionResult> GetCategoryStats(
        [FromQuery] System.Guid? userId,
        [FromQuery] string? bankCode,
        [FromServices] ThemarIP.Application.Common.Interfaces.IApplicationDbContext context)
    {
        var activeMerchants = await Microsoft.EntityFrameworkCore.EntityFrameworkQueryableExtensions.ToListAsync(
            Microsoft.EntityFrameworkCore.EntityFrameworkQueryableExtensions.Include(
                Microsoft.EntityFrameworkCore.EntityFrameworkQueryableExtensions.Include(
                    context.PfmMerchants.Where(m => m.IsActive),
                    m => m.Aliases
                ),
                m => m.DefaultCategory
            )
        );

        var rules = await Microsoft.EntityFrameworkCore.EntityFrameworkQueryableExtensions.ToListAsync(context.CategoryRules);
        var activeRules = rules.Where(r => r.IsActive).OrderByDescending(r => r.Priority).ToList();

        var txQuery = context.PfmTransactions.AsQueryable();
        if (userId.HasValue)
        {
            txQuery = txQuery.Where(t => t.UserId == userId.Value);
        }
        if (!string.IsNullOrWhiteSpace(bankCode) && !string.Equals(bankCode, "ALL", System.StringComparison.OrdinalIgnoreCase))
        {
            txQuery = txQuery.Where(t => t.BankCode == bankCode);
        }
        var transactions = await Microsoft.EntityFrameworkCore.EntityFrameworkQueryableExtensions.ToListAsync(txQuery);

        var rootCategories = await Microsoft.EntityFrameworkCore.EntityFrameworkQueryableExtensions.ToListAsync(
            Microsoft.EntityFrameworkCore.EntityFrameworkQueryableExtensions.Include(
                context.PfmCategories.Where(c => c.ParentId == null),
                c => c.Children
            )
        );

        var allSubcategories = rootCategories.SelectMany(c => c.Children.Select(sub => new { Sub = sub, Parent = c })).ToList();

        // Initialise counts and transaction lists for every category
        var counts = new System.Collections.Generic.Dictionary<string, int>(System.StringComparer.OrdinalIgnoreCase);
        var catTxns = new System.Collections.Generic.Dictionary<string, System.Collections.Generic.List<object>>(System.StringComparer.OrdinalIgnoreCase);
        foreach (var cat in rootCategories)
        {
            counts[cat.Name] = 0;
            catTxns[cat.Name] = new System.Collections.Generic.List<object>();
        }
        if (!counts.ContainsKey("Other")) counts["Other"] = 0;
        if (!catTxns.ContainsKey("Other")) catTxns["Other"] = new System.Collections.Generic.List<object>();

        foreach (var tx in transactions)
        {
            var narration = (tx.Narration ?? "").ToUpperInvariant();
            bool matched = false;

            // 1. Check Active Merchants & Aliases from themarip.db
            foreach (var merchant in activeMerchants)
            {
                bool isMerchantMatch = (!string.IsNullOrWhiteSpace(merchant.Name) && narration.Contains(merchant.Name.ToUpperInvariant()))
                    || merchant.Aliases.Any(a => !string.IsNullOrWhiteSpace(a.AliasText) && narration.Contains(a.AliasText.ToUpperInvariant()));

                if (isMerchantMatch)
                {
                    // Find parent category and subcategory
                    string targetCatName = "Other";
                    string subName = "General";

                    if (merchant.DefaultSubcategoryId.HasValue)
                    {
                        var foundSub = allSubcategories.FirstOrDefault(s => s.Sub.Id == merchant.DefaultSubcategoryId.Value);
                        if (foundSub != null)
                        {
                            targetCatName = foundSub.Parent.Name;
                            subName = foundSub.Sub.Name;
                        }
                    }

                    if (targetCatName == "Other" && merchant.DefaultCategoryId.HasValue)
                    {
                        var foundCat = rootCategories.FirstOrDefault(c => c.Id == merchant.DefaultCategoryId.Value);
                        if (foundCat != null)
                        {
                            targetCatName = foundCat.Name;
                        }
                    }

                    if (targetCatName == "Other" && merchant.DefaultCategory != null)
                    {
                        targetCatName = merchant.DefaultCategory.Name;
                    }

                    if (counts.ContainsKey(targetCatName)) counts[targetCatName]++;
                    else counts["Other"]++;

                    var txItem = new
                    {
                        id = tx.Id,
                        transactionDate = tx.TransactionDate,
                        narration = tx.Narration,
                        amount = tx.Amount,
                        currency = tx.Currency,
                        transactionType = tx.TransactionType.ToString(),
                        balanceAfter = tx.BalanceAfter,
                        matchedKeyword = merchant.Name,
                        subcategory = subName,
                        bankCode = tx.BankCode,
                        bankName = tx.BankName
                    };

                    if (catTxns.ContainsKey(targetCatName)) catTxns[targetCatName].Add(txItem);
                    else catTxns["Other"].Add(txItem);

                    matched = true;
                    break;
                }
            }

            // 2. Check Active Categorization Rules
            if (!matched)
            {
                foreach (var rule in activeRules)
                {
                    if (!string.IsNullOrEmpty(rule.Keyword) &&
                        narration.Contains(rule.Keyword.ToUpperInvariant()))
                    {
                        var parentCat = rootCategories.FirstOrDefault(c =>
                            c.Children.Any(s => string.Equals(s.Name, rule.Category, System.StringComparison.OrdinalIgnoreCase))
                            || string.Equals(c.Name, rule.Category, System.StringComparison.OrdinalIgnoreCase));

                        var catName = parentCat?.Name ?? "Other";
                        if (counts.ContainsKey(catName)) counts[catName]++;
                        else counts["Other"]++;

                        var txItem = new
                        {
                            id = tx.Id,
                            transactionDate = tx.TransactionDate,
                            narration = tx.Narration,
                            amount = tx.Amount,
                            currency = tx.Currency,
                            transactionType = tx.TransactionType.ToString(),
                            balanceAfter = tx.BalanceAfter,
                            matchedKeyword = rule.Keyword,
                            subcategory = rule.Category,
                            bankCode = tx.BankCode,
                            bankName = tx.BankName
                        };

                        if (catTxns.ContainsKey(catName)) catTxns[catName].Add(txItem);
                        else catTxns["Other"].Add(txItem);

                        matched = true;
                        break;
                    }
                }
            }

            // 3. Fallback: Uncategorized
            if (!matched)
            {
                counts["Other"]++;
                catTxns["Other"].Add(new
                {
                    id = tx.Id,
                    transactionDate = tx.TransactionDate,
                    narration = tx.Narration,
                    amount = tx.Amount,
                    currency = tx.Currency,
                    transactionType = tx.TransactionType.ToString(),
                    balanceAfter = tx.BalanceAfter,
                    matchedKeyword = "",
                    subcategory = "Uncategorized",
                    bankCode = tx.BankCode,
                    bankName = tx.BankName
                });
            }
        }

        var result = rootCategories
            .Select(c => new
            {
                categoryName = c.Name,
                icon         = c.Icon,
                color        = c.Color,
                txnCount     = counts.ContainsKey(c.Name) ? counts[c.Name] : 0,
                transactions = catTxns.ContainsKey(c.Name) ? catTxns[c.Name] : new System.Collections.Generic.List<object>()
            })
            .ToList();

        return Ok(result);
    }

    /// <summary>
    /// Returns the distinct local banks associated with user's uploaded statements/transactions,
    /// along with transaction count and total spending per bank.
    /// </summary>
    [HttpGet("user-banks")]
    public async Task<IActionResult> GetUserBanks(
        [FromQuery] System.Guid? userId,
        [FromServices] ThemarIP.Application.Common.Interfaces.IApplicationDbContext context)
    {
        var txQuery = context.PfmTransactions.AsQueryable();
        if (userId.HasValue)
        {
            txQuery = txQuery.Where(t => t.UserId == userId.Value);
        }

        var txList = await Microsoft.EntityFrameworkCore.EntityFrameworkQueryableExtensions.ToListAsync(txQuery);
        var banks = txList
            .GroupBy(t => new { Code = t.BankCode ?? "BANK_MUSCAT", Name = t.BankName ?? "Bank Muscat" })
            .Select(g => new
            {
                bankCode = g.Key.Code,
                bankName = g.Key.Name,
                txCount = g.Count(),
                totalSpent = g.Where(t => t.TransactionType == ThemarIP.Domain.Enums.Pfm.TransactionType.Debit).Sum(t => t.Amount)
            })
            .OrderByDescending(b => b.txCount)
            .ToList();

        return Ok(banks);
    }

    [HttpPost("categories")]
    public async Task<IActionResult> AddCategory(
        [FromBody] CreateCategoryDto dto,
        [FromServices] ThemarIP.Application.Common.Interfaces.IApplicationDbContext context)
    {
        var category = new ThemarIP.Domain.Entities.Pfm.PfmCategory
        {
            Id = System.Guid.NewGuid(),
            ParentId = dto.ParentId,
            Name = dto.Name,
            Icon = string.IsNullOrEmpty(dto.Icon) ? (dto.ParentId == null ? "tag" : "corner-down-right") : dto.Icon,
            Color = string.IsNullOrEmpty(dto.Color) ? "#7C3AED" : dto.Color,
            DisplayOrder = dto.DisplayOrder > 0 ? dto.DisplayOrder : 99,
            IsEnabled = dto.IsEnabled
        };
        context.PfmCategories.Add(category);
        await context.SaveChangesAsync(default);
        return Ok(category);
    }

    [HttpDelete("categories/{id}")]
    public async Task<IActionResult> DeleteCategory(
        System.Guid id,
        [FromServices] ThemarIP.Application.Common.Interfaces.IApplicationDbContext context)
    {
        var category = await context.PfmCategories.FindAsync(id);
        if (category == null) return NotFound("Category not found.");

        var children = context.PfmCategories.Where(c => c.ParentId == id);
        context.PfmCategories.RemoveRange(children);
        context.PfmCategories.Remove(category);

        await context.SaveChangesAsync(default);
        return Ok(new { message = "Category deleted successfully." });
    }

    [HttpPut("categories/{id}")]
    public async Task<IActionResult> UpdateCategory(
        System.Guid id,
        [FromBody] CreateCategoryDto dto,
        [FromServices] ThemarIP.Application.Common.Interfaces.IApplicationDbContext context)
    {
        var category = await context.PfmCategories.FindAsync(id);
        if (category == null) return NotFound("Category not found.");

        if (!string.IsNullOrEmpty(dto.Name)) category.Name = dto.Name;
        if (!string.IsNullOrEmpty(dto.Icon)) category.Icon = dto.Icon;
        if (!string.IsNullOrEmpty(dto.Color)) category.Color = dto.Color;
        if (dto.DisplayOrder > 0) category.DisplayOrder = dto.DisplayOrder;
        category.IsEnabled = dto.IsEnabled;

        await context.SaveChangesAsync(default);
        return Ok(category);
    }

    [HttpPut("subcategories/{id}")]
    public async Task<IActionResult> UpdateSubcategory(
        System.Guid id,
        [FromBody] CreateSubcategoryDto dto,
        [FromServices] ThemarIP.Application.Common.Interfaces.IApplicationDbContext context)
    {
        return await UpdateCategory(id, new CreateCategoryDto
        {
            Name = dto.Name,
            ParentId = dto.CategoryId,
            DisplayOrder = dto.DisplayOrder,
            IsEnabled = dto.IsEnabled
        }, context);
    }

    [HttpPost("subcategories")]
    public async Task<IActionResult> AddSubcategory(
        [FromBody] CreateSubcategoryDto dto,
        [FromServices] ThemarIP.Application.Common.Interfaces.IApplicationDbContext context)
    {
        return await AddCategory(new CreateCategoryDto
        {
            ParentId = dto.CategoryId,
            Name = dto.Name,
            DisplayOrder = dto.DisplayOrder,
            IsEnabled = dto.IsEnabled
        }, context);
    }

    [HttpDelete("subcategories/{id}")]
    public async Task<IActionResult> DeleteSubcategory(
        System.Guid id,
        [FromServices] ThemarIP.Application.Common.Interfaces.IApplicationDbContext context)
    {
        return await DeleteCategory(id, context);
    }

    // ============================================================
    // MERCHANTS CRUD ENDPOINTS (themarip.db PfmMerchants)
    // ============================================================

    [HttpGet("merchants")]
    public async Task<IActionResult> GetMerchants([FromServices] ThemarIP.Application.Common.Interfaces.IApplicationDbContext context)
    {
        var merchants = await Microsoft.EntityFrameworkCore.EntityFrameworkQueryableExtensions.ToListAsync(
            Microsoft.EntityFrameworkCore.EntityFrameworkQueryableExtensions.Include(
                Microsoft.EntityFrameworkCore.EntityFrameworkQueryableExtensions.Include(
                    context.PfmMerchants,
                    m => m.Aliases
                ),
                m => m.DefaultCategory
            )
        );

        var allSubcats = await Microsoft.EntityFrameworkCore.EntityFrameworkQueryableExtensions.ToListAsync(
            context.PfmCategories.Where(c => c.ParentId != null)
        );
        var subcatDict = allSubcats.ToDictionary(s => s.Id, s => s.Name);

        var result = merchants.Select(m => new
        {
            id = m.Id.ToString(),
            name = m.Name,
            aliases = m.Aliases.Select(a => a.AliasText).ToList(),
            mcc = m.MccCode,
            defaultCategoryId = m.DefaultCategoryId?.ToString(),
            defaultCategoryName = m.DefaultCategory?.Name,
            defaultSubcategoryId = m.DefaultSubcategoryId?.ToString(),
            defaultSubcategoryName = m.DefaultSubcategoryId.HasValue && subcatDict.ContainsKey(m.DefaultSubcategoryId.Value) ? subcatDict[m.DefaultSubcategoryId.Value] : null,
            defaultConfidence = m.DefaultConfidence,
            txCount = m.TransactionCount,
            correctionRate = m.CorrectionRate,
            status = m.IsActive ? "active" : "inactive"
        }).ToList();

        return Ok(result);
    }

    [HttpPost("merchants")]
    public async Task<IActionResult> CreateMerchant(
        [FromBody] ThemarIP.Application.DTOs.Statements.SaveMerchantRequestDto dto,
        [FromServices] ThemarIP.Application.Common.Interfaces.IApplicationDbContext context)
    {
        if (string.IsNullOrWhiteSpace(dto.Name))
            return BadRequest(new { message = "Merchant name is required." });

        var merchant = new ThemarIP.Domain.Entities.Pfm.PfmMerchant
        {
            Id = Guid.NewGuid(),
            Name = dto.Name.Trim(),
            MccCode = string.IsNullOrWhiteSpace(dto.Mcc) ? null : dto.Mcc.Trim(),
            DefaultCategoryId = dto.DefaultCategoryId,
            DefaultSubcategoryId = dto.DefaultSubcategoryId,
            DefaultConfidence = dto.DefaultConfidence ?? 90,
            IsActive = string.Equals(dto.Status, "active", StringComparison.OrdinalIgnoreCase),
            CreatedAt = DateTimeOffset.UtcNow,
            UpdatedAt = DateTimeOffset.UtcNow
        };

        if (dto.Aliases != null)
        {
            var distinctAliases = dto.Aliases
                .Where(a => !string.IsNullOrWhiteSpace(a))
                .Select(a => a.Trim())
                .Distinct(StringComparer.OrdinalIgnoreCase)
                .ToList();

            var globalAliases = await Microsoft.EntityFrameworkCore.EntityFrameworkQueryableExtensions.ToListAsync(
                Microsoft.EntityFrameworkCore.EntityFrameworkQueryableExtensions.Include(
                    context.PfmMerchantAliases,
                    a => a.Merchant
                )
            );

            foreach (var aliasText in distinctAliases)
            {
                var existingConflict = globalAliases.FirstOrDefault(g => string.Equals(g.AliasText, aliasText, StringComparison.OrdinalIgnoreCase));
                if (existingConflict != null)
                {
                    return BadRequest(new { message = $"Alias '{aliasText}' is already assigned to merchant '{existingConflict.Merchant?.Name ?? "Unknown"}'." });
                }

                merchant.Aliases.Add(new ThemarIP.Domain.Entities.Pfm.PfmMerchantAlias
                {
                    Id = Guid.NewGuid(),
                    MerchantId = merchant.Id,
                    AliasText = aliasText,
                    CreatedAt = DateTimeOffset.UtcNow
                });
            }
        }

        context.PfmMerchants.Add(merchant);
        await context.SaveChangesAsync();

        return Ok(new { message = "Merchant created successfully.", id = merchant.Id.ToString() });
    }

    [HttpPut("merchants/{id}")]
    public async Task<IActionResult> UpdateMerchant(
        [FromRoute] Guid id,
        [FromBody] ThemarIP.Application.DTOs.Statements.SaveMerchantRequestDto dto,
        [FromServices] ThemarIP.Application.Common.Interfaces.IApplicationDbContext context)
    {
        var allMerchants = await Microsoft.EntityFrameworkCore.EntityFrameworkQueryableExtensions.ToListAsync(context.PfmMerchants);
        var merchant = allMerchants.FirstOrDefault(m => m.Id == id || string.Equals(m.Id.ToString(), id.ToString(), StringComparison.OrdinalIgnoreCase));

        if (merchant == null)
            return NotFound(new { message = "Merchant not found." });

        if (string.IsNullOrWhiteSpace(dto.Name))
            return BadRequest(new { message = "Merchant name is required." });

        merchant.Name = dto.Name.Trim();
        merchant.MccCode = string.IsNullOrWhiteSpace(dto.Mcc) ? null : dto.Mcc.Trim();
        merchant.DefaultCategoryId = dto.DefaultCategoryId;
        merchant.DefaultSubcategoryId = dto.DefaultSubcategoryId;
        merchant.DefaultConfidence = dto.DefaultConfidence ?? 90;
        if (!string.IsNullOrEmpty(dto.Status))
            merchant.IsActive = string.Equals(dto.Status, "active", StringComparison.OrdinalIgnoreCase);
        merchant.UpdatedAt = DateTimeOffset.UtcNow;

        if (dto.Aliases != null)
        {
            var existingAliases = await Microsoft.EntityFrameworkCore.EntityFrameworkQueryableExtensions.ToListAsync(
                context.PfmMerchantAliases.Where(a => a.MerchantId == merchant.Id)
            );

            var newAliasTexts = dto.Aliases
                .Where(a => !string.IsNullOrWhiteSpace(a))
                .Select(a => a.Trim())
                .Distinct(StringComparer.OrdinalIgnoreCase)
                .ToList();

            // Remove aliases no longer present
            var toRemove = existingAliases
                .Where(e => !newAliasTexts.Any(n => string.Equals(n, e.AliasText, StringComparison.OrdinalIgnoreCase)))
                .ToList();
            if (toRemove.Count > 0)
            {
                context.PfmMerchantAliases.RemoveRange(toRemove);
            }

            // Add new aliases
            foreach (var text in newAliasTexts)
            {
                if (!existingAliases.Any(e => string.Equals(e.AliasText, text, StringComparison.OrdinalIgnoreCase)))
                {
                    context.PfmMerchantAliases.Add(new ThemarIP.Domain.Entities.Pfm.PfmMerchantAlias
                    {
                        Id = Guid.NewGuid(),
                        MerchantId = merchant.Id,
                        AliasText = text,
                        CreatedAt = DateTimeOffset.UtcNow
                    });
                }
            }
        }

        await context.SaveChangesAsync();
        return Ok(new { message = "Merchant updated successfully." });
    }

    [HttpPatch("merchants/{id}/toggle")]
    public async Task<IActionResult> ToggleMerchantStatus(
        [FromRoute] Guid id,
        [FromServices] ThemarIP.Application.Common.Interfaces.IApplicationDbContext context)
    {
        var all = await Microsoft.EntityFrameworkCore.EntityFrameworkQueryableExtensions.ToListAsync(context.PfmMerchants);
        var merchant = all.FirstOrDefault(m => m.Id == id || string.Equals(m.Id.ToString(), id.ToString(), StringComparison.OrdinalIgnoreCase));
        if (merchant == null) return NotFound(new { message = "Merchant not found." });

        merchant.IsActive = !merchant.IsActive;
        merchant.UpdatedAt = DateTimeOffset.UtcNow;
        await context.SaveChangesAsync();

        return Ok(new { message = "Status toggled.", status = merchant.IsActive ? "active" : "inactive" });
    }

    [HttpDelete("merchants/{id}")]
    public async Task<IActionResult> DeleteMerchant(
        [FromRoute] Guid id,
        [FromServices] ThemarIP.Application.Common.Interfaces.IApplicationDbContext context)
    {
        var all = await Microsoft.EntityFrameworkCore.EntityFrameworkQueryableExtensions.ToListAsync(context.PfmMerchants);
        var merchant = all.FirstOrDefault(m => m.Id == id || string.Equals(m.Id.ToString(), id.ToString(), StringComparison.OrdinalIgnoreCase));
        if (merchant == null) return NotFound(new { message = "Merchant not found." });

        var aliases = await Microsoft.EntityFrameworkCore.EntityFrameworkQueryableExtensions.ToListAsync(
            context.PfmMerchantAliases.Where(a => a.MerchantId == merchant.Id)
        );
        context.PfmMerchantAliases.RemoveRange(aliases);
        context.PfmMerchants.Remove(merchant);
        await context.SaveChangesAsync();

        return Ok(new { message = "Merchant deleted successfully." });
    }

    [HttpPost("parse-notification")]
    public async Task<IActionResult> ParseNotification([FromBody] IngestNotificationRequestDto dto)
    {
        if (string.IsNullOrWhiteSpace(dto.RawMessage) && string.IsNullOrWhiteSpace(dto.EmailSubject))
            return BadRequest(new { message = "Message content or email subject is required." });

        dto.AutoConfirm = false;
        var result = await _notificationParser.ParseNotificationAsync(dto);
        return Ok(result);
    }

    [HttpPost("confirm-notification")]
    public async Task<IActionResult> ConfirmNotification([FromBody] ConfirmNotificationRequestDto dto)
    {
        if (dto.Transaction == null || dto.Transaction.Amount <= 0)
            return BadRequest(new { message = "Valid transaction data is required to confirm." });

        var txId = await _notificationParser.ConfirmAndSaveNotificationAsync(dto);
        return Ok(new { success = true, transactionId = txId, message = "Transaction saved to themarip.db successfully." });
    }

    [HttpPost("ingest-notification")]
    public async Task<IActionResult> IngestNotification([FromBody] IngestNotificationRequestDto dto)
    {
        if (string.IsNullOrWhiteSpace(dto.RawMessage) && string.IsNullOrWhiteSpace(dto.EmailSubject))
            return BadRequest(new { message = "Message content or email subject is required." });

        dto.AutoConfirm = true;
        var result = await _notificationParser.ParseNotificationAsync(dto);
        return Ok(new
        {
            success = result.SavedTransactionId.HasValue,
            isDuplicate = result.IsDuplicate,
            transactionId = result.SavedTransactionId,
            parsed = result
        });
    }

    [HttpGet("bank-formats")]
    public async Task<IActionResult> GetBankFormats()
    {
        var path = Path.Combine(Directory.GetCurrentDirectory(), "storage", "bank_formats.json");
        if (!System.IO.File.Exists(path))
        {
            return Ok(new object[] { });
        }
        var json = await System.IO.File.ReadAllTextAsync(path);
        return Content(json, "application/json");
    }

    [HttpPost("bank-formats")]
    public async Task<IActionResult> SaveBankFormats([FromBody] System.Text.Json.JsonElement body)
    {
        var dir = Path.Combine(Directory.GetCurrentDirectory(), "storage");
        if (!Directory.Exists(dir)) Directory.CreateDirectory(dir);
        var path = Path.Combine(dir, "bank_formats.json");
        var json = System.Text.Json.JsonSerializer.Serialize(body, new System.Text.Json.JsonSerializerOptions { WriteIndented = true });
        await System.IO.File.WriteAllTextAsync(path, json);
        return Ok(new { success = true, message = "Bank format templates saved successfully." });
    }

    [HttpPost("pull-mailbox-emails")]
    public async Task<IActionResult> PullMailboxEmails([FromBody] PullMailboxRequestDto dto)
    {
        var result = await _mailboxPuller.PullAndIngestEmailsAsync(dto);
        return Ok(result);
    }

    private static ThemarIP.Domain.Enums.Pfm.RuleConditionField ParseConditionField(string? s) => (s?.ToLowerInvariant()) switch
    {
        "merchant_name" or "merchantname" => ThemarIP.Domain.Enums.Pfm.RuleConditionField.MerchantName,
        "merchant_id" or "merchantid" => ThemarIP.Domain.Enums.Pfm.RuleConditionField.MerchantId,
        "mcc" or "mcc_code" or "mcccode" => ThemarIP.Domain.Enums.Pfm.RuleConditionField.MccCode,
        "type" or "transactiontype" or "transaction_type" => ThemarIP.Domain.Enums.Pfm.RuleConditionField.TransactionType,
        "amount" => ThemarIP.Domain.Enums.Pfm.RuleConditionField.Amount,
        "currency" => ThemarIP.Domain.Enums.Pfm.RuleConditionField.Currency,
        _ => ThemarIP.Domain.Enums.Pfm.RuleConditionField.Narration
    };

    private static string MapConditionFieldToString(ThemarIP.Domain.Enums.Pfm.RuleConditionField f) => f switch
    {
        ThemarIP.Domain.Enums.Pfm.RuleConditionField.MerchantName => "merchant_name",
        ThemarIP.Domain.Enums.Pfm.RuleConditionField.MerchantId => "merchant_id",
        ThemarIP.Domain.Enums.Pfm.RuleConditionField.MccCode => "mcc",
        ThemarIP.Domain.Enums.Pfm.RuleConditionField.TransactionType => "type",
        ThemarIP.Domain.Enums.Pfm.RuleConditionField.Amount => "amount",
        ThemarIP.Domain.Enums.Pfm.RuleConditionField.Currency => "currency",
        _ => "narration"
    };

    private static ThemarIP.Domain.Enums.Pfm.RuleConditionOperator ParseConditionOperator(string? s) => (s?.ToLowerInvariant()) switch
    {
        "equals" or "equal" => ThemarIP.Domain.Enums.Pfm.RuleConditionOperator.Equals,
        "starts_with" or "startswith" => ThemarIP.Domain.Enums.Pfm.RuleConditionOperator.StartsWith,
        "ends_with" or "endswith" => ThemarIP.Domain.Enums.Pfm.RuleConditionOperator.EndsWith,
        "greater_than" or "greaterthan" => ThemarIP.Domain.Enums.Pfm.RuleConditionOperator.GreaterThan,
        "less_than" or "lessthan" => ThemarIP.Domain.Enums.Pfm.RuleConditionOperator.LessThan,
        "between" => ThemarIP.Domain.Enums.Pfm.RuleConditionOperator.Between,
        _ => ThemarIP.Domain.Enums.Pfm.RuleConditionOperator.Contains
    };

    private static string MapConditionOperatorToString(ThemarIP.Domain.Enums.Pfm.RuleConditionOperator op) => op switch
    {
        ThemarIP.Domain.Enums.Pfm.RuleConditionOperator.Equals => "equals",
        ThemarIP.Domain.Enums.Pfm.RuleConditionOperator.StartsWith => "starts_with",
        ThemarIP.Domain.Enums.Pfm.RuleConditionOperator.EndsWith => "ends_with",
        ThemarIP.Domain.Enums.Pfm.RuleConditionOperator.GreaterThan => "greater_than",
        ThemarIP.Domain.Enums.Pfm.RuleConditionOperator.LessThan => "less_than",
        ThemarIP.Domain.Enums.Pfm.RuleConditionOperator.Between => "between",
        _ => "contains"
    };
}

public class CreateCategoryDto
{
    public System.Guid? ParentId { get; set; }
    public string Name { get; set; } = string.Empty;
    public string Icon { get; set; } = "tag";
    public string Color { get; set; } = "#7C3AED";
    public int DisplayOrder { get; set; } = 99;
    public bool IsEnabled { get; set; } = true;
}

public class CreateSubcategoryDto
{
    public System.Guid CategoryId { get; set; }
    public string Name { get; set; } = string.Empty;
    public int DisplayOrder { get; set; } = 99;
    public bool IsEnabled { get; set; } = true;
}

public class UpdateStatusDto
{
    public string Status { get; set; } = "Active";
}

public class UserBankSummaryDto
{
    public string Code { get; set; } = string.Empty;
    public string Name { get; set; } = string.Empty;
    public int TxCount { get; set; }
}

public class UpdateUserProfileDto
{
    public string? AccessStatus { get; set; }
    public int? TrustScore { get; set; }
    public string? Role { get; set; }
    public string? FullName { get; set; }
    public string? PrimaryBank { get; set; }
}

public class UpdateScoreDto
{
    public int TrustScore { get; set; }
}

public class UserBankSelectionDto
{
    public System.Guid? UserId { get; set; }
    public string? Email { get; set; }
    public string? BankCode { get; set; }
    public string? BankName { get; set; }
}

public class SaveCategorizationRuleDto
{
    public string Name { get; set; } = string.Empty;
    public System.Guid? CategoryId { get; set; }
    public System.Guid? SubcategoryId { get; set; }
    public int Confidence { get; set; } = 85;
    public int Priority { get; set; } = 50;
    public string Status { get; set; } = "Active";
    public System.Collections.Generic.List<SaveRuleConditionDto>? Conditions { get; set; }
}

public class SaveRuleConditionDto
{
    public string Field { get; set; } = "narration";
    public string Operator { get; set; } = "contains";
    public string Value { get; set; } = string.Empty;
    public string Logic { get; set; } = "AND";
}



