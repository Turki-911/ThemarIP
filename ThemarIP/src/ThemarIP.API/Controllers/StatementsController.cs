using System.Threading.Tasks;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
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
            if (!request.UserId.HasValue || request.UserId.Value == System.Guid.Empty)
            {
                var claimId = User?.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value;
                if (System.Guid.TryParse(claimId, out var parsedUserId))
                {
                    request.UserId = parsedUserId;
                }
            }

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
        txns = txns.OrderByDescending(t => t.TransactionDate).ThenByDescending(t => t.CreatedAt).ToList();
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
                g => g.Select(x => ThemarIP.Application.Common.BankCatalog.Canonical(x.BankCode, x.BankName))
                      .GroupBy(b => b.Code, StringComparer.OrdinalIgnoreCase)
                      .Select(bg => new UserBankSummaryDto
                      {
                          Code = bg.First().Code,
                          Name = bg.First().Name,
                          TxCount = bg.Count()
                      })
                      .ToList()
            );

        var result = users.Select(u =>
        {
            txByUser.TryGetValue(u.Id, out var userBanks);
            userBanks ??= new List<UserBankSummaryDto>();

            var parsedSelection = ThemarIP.Application.Common.BankCatalog.ParseSelection(u.AccountNumber);
            var selectedList = parsedSelection.Select(b => b.Name).ToList();

            // Merge selected banks with 0 transactions into userBanks so the admin sees all selected banks cleanly
            foreach (var sb in parsedSelection)
            {
                if (!userBanks.Any(b => string.Equals(b.Code, sb.Code, StringComparison.OrdinalIgnoreCase) ||
                                        string.Equals(b.Name, sb.Name, StringComparison.OrdinalIgnoreCase)))
                {
                    userBanks.Add(new UserBankSummaryDto { Code = sb.Code, Name = sb.Name, TxCount = 0 });
                }
            }

            var connectedBanks = userBanks.Select(b => b.Name).Distinct(StringComparer.OrdinalIgnoreCase).ToList();
            var primaryBank = selectedList.Count > 0 ? string.Join(", ", selectedList) : userBanks.FirstOrDefault()?.Name;
            var totalTx = userBanks.Sum(b => b.TxCount);

            return new
            {
                id = u.Id,
                email = u.Email,
                fullName = u.FullName,
                accountNumber = primaryBank ?? u.AccountNumber,
                selectedBanks = selectedList,
                banks = userBanks,
                connectedBanks = connectedBanks,
                primaryBank = primaryBank,
                totalTransactions = totalTx,
                role = u.Role.ToString(),
                accessStatus = u.AccessStatus.ToString(),
                trustScore = u.TrustScore,
                requirePasswordReset = string.Equals(u.AccessReasonNote, "RESET_PASSWORD_REQUIRED", StringComparison.OrdinalIgnoreCase),
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

        if (dto.PrimaryBank != null)
        {
            var canonicalBanks = ThemarIP.Application.Common.BankCatalog.ParseSelection(dto.PrimaryBank);
            user.AccountNumber = string.Join(", ", canonicalBanks.Select(b => b.Name));
            await AutoEnableBankSmsRulesAsync(context, user.AccountNumber, null);
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

    [HttpPost("users/{id}/require-password-reset")]
    public async Task<IActionResult> RequireUserPasswordReset(
        System.Guid id,
        [FromServices] ThemarIP.Application.Common.Interfaces.IApplicationDbContext context)
    {
        var user = await context.Users.FindAsync(id);
        if (user == null) return NotFound(new { message = "User not found." });

        user.AccessReasonNote = "RESET_PASSWORD_REQUIRED";
        await context.SaveChangesAsync(default);

        return Ok(new
        {
            success = true,
            message = $"Password reset enabled for {user.Email}. The user will be prompted to enter and confirm a new password in the app.",
            userId = user.Id,
            email = user.Email,
            requirePasswordReset = true
        });
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

        var canonicalPicked = ThemarIP.Application.Common.BankCatalog.Canonical(dto.BankCode, dto.BankName);
        string bankDisplayName = canonicalPicked.Name;

        // Multi-bank support: append canonical bank name without overwriting existing selections
        var existingBanks = ThemarIP.Application.Common.BankCatalog.ParseSelection(user.AccountNumber)
            .Select(b => b.Name)
            .ToList();
        if (!existingBanks.Any(b => string.Equals(b, bankDisplayName, StringComparison.OrdinalIgnoreCase)))
        {
            existingBanks.Add(bankDisplayName);
        }
        user.AccountNumber = string.Join(", ", existingBanks);

        // Auto-enable matching Bank SMS Rule(s) for all selected banks
        var enabledRules = await AutoEnableBankSmsRulesAsync(context, user.AccountNumber, canonicalPicked.Code);

        // If trust score is 0, give initial baseline score of 75 upon bank connection
        if (user.TrustScore == 0)
        {
            user.TrustScore = 75;
        }

        await context.SaveChangesAsync(default);

        return Ok(new
        {
            success = true,
            message = "Bank selection linked to themarip.db and SMS rules enabled.",
            userId = user.Id,
            fullName = user.FullName,
            email = user.Email,
            selectedBank = user.AccountNumber,
            selectedBanks = existingBanks,
            enabledSmsRules = enabledRules,
            trustScore = user.TrustScore
        });
    }

    [HttpPost("user-bank-unsync")]
    public async Task<IActionResult> UnsyncUserBank(
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
            return NotFound(new { message = "User not found to unsync bank." });
        }

        var canonicalTarget = ThemarIP.Application.Common.BankCatalog.Canonical(dto.BankCode, dto.BankName);

        // Remove canonical bank from user.AccountNumber CSV
        var remainingBanks = ThemarIP.Application.Common.BankCatalog.ParseSelection(user.AccountNumber)
            .Where(b => !string.Equals(b.Code, canonicalTarget.Code, StringComparison.OrdinalIgnoreCase) &&
                        !string.Equals(b.Name, canonicalTarget.Name, StringComparison.OrdinalIgnoreCase))
            .Select(b => b.Name)
            .ToList();

        user.AccountNumber = remainingBanks.Count > 0 ? string.Join(", ", remainingBanks) : null;

        // Also remove any PfmTransactions belonging to this user for the unsynced bank
        var userTxs = await Microsoft.EntityFrameworkCore.EntityFrameworkQueryableExtensions.ToListAsync(
            context.PfmTransactions.Where(t => t.UserId == user.Id));
        var txsToRemove = userTxs
            .Where(t => string.Equals(
                ThemarIP.Application.Common.BankCatalog.Canonical(t.BankCode, t.BankName).Code,
                canonicalTarget.Code,
                StringComparison.OrdinalIgnoreCase))
            .ToList();

        if (txsToRemove.Count > 0)
        {
            context.PfmTransactions.RemoveRange(txsToRemove);
        }

        await context.SaveChangesAsync(default);

        return Ok(new
        {
            success = true,
            message = $"Unsynced {canonicalTarget.Name} and removed {txsToRemove.Count} transaction(s).",
            userId = user.Id,
            removedBankCode = canonicalTarget.Code,
            removedBankName = canonicalTarget.Name,
            removedTransactions = txsToRemove.Count,
            selectedBank = user.AccountNumber,
            selectedBanks = remainingBanks
        });
    }

    private static async Task<List<string>> AutoEnableBankSmsRulesAsync(
        ThemarIP.Application.Common.Interfaces.IApplicationDbContext context,
        string? bankNamesCsv,
        string? bankCode)
    {
        var enabledNames = new List<string>();
        var selection = ThemarIP.Application.Common.BankCatalog.ParseSelection(bankNamesCsv);
        if (!string.IsNullOrWhiteSpace(bankCode))
        {
            var extra = ThemarIP.Application.Common.BankCatalog.Canonical(bankCode, null);
            if (!selection.Any(s => string.Equals(s.Code, extra.Code, StringComparison.OrdinalIgnoreCase)))
                selection.Add(extra);
        }
        if (selection.Count == 0) return enabledNames;

        var allRules = await Microsoft.EntityFrameworkCore.EntityFrameworkQueryableExtensions.ToListAsync(context.BankSmsRules);
        foreach (var r in allRules)
        {
            if (ThemarIP.Application.Common.BankCatalog.IsSelected(r.BankCode, r.BankName, selection))
            {
                if (!r.IsActive)
                {
                    r.IsActive = true;
                    r.UpdatedAt = System.DateTimeOffset.UtcNow;
                }
                var canonical = ThemarIP.Application.Common.BankCatalog.Canonical(r.BankCode, r.BankName);
                if (!enabledNames.Contains(canonical.Name, StringComparer.OrdinalIgnoreCase))
                    enabledNames.Add(canonical.Name);
            }
        }
        return enabledNames;
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
            fireCount = r.FireCount,
            lastFiredAt = r.LastFiredAt,
            icon = r.Icon,
            iconColor = r.IconColor,
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
        [FromServices] ThemarIP.Infrastructure.Persistence.ApplicationDbContext context)
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
        if (body.TryGetProperty("icon", out var iconElem))
        {
            rule.Icon = iconElem.GetString() ?? rule.Icon;
        }
        if (body.TryGetProperty("iconColor", out var iconColorElem))
        {
            rule.IconColor = iconColorElem.GetString() ?? rule.IconColor;
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
                else
                {
                    rule.Params.Add(new ThemarIP.Domain.Entities.Pfm.PfmIntelligenceRuleParam
                    {
                        Id = Guid.NewGuid(),
                        RuleId = rule.Id,
                        ParamKey = prop.Name,
                        ParamValue = prop.Value.ToString(),
                        ParamType = ThemarIP.Domain.Enums.Pfm.IntelligenceRuleParamType.String,
                        UpdatedAt = DateTimeOffset.UtcNow
                    });
                }
            }
        }

        rule.UpdatedAt = DateTimeOffset.UtcNow;
        await context.SaveChangesAsync(default);
        return Ok(new { success = true, message = "Intelligence rule updated in themarip.db." });
    }

    [HttpPost("intelligence-rules")]
    public async Task<IActionResult> CreateIntelligenceRule(
        [FromBody] System.Text.Json.JsonElement body,
        [FromServices] ThemarIP.Infrastructure.Persistence.ApplicationDbContext context)
    {
        var name = body.TryGetProperty("name", out var n) ? n.GetString() : null;
        if (string.IsNullOrWhiteSpace(name))
            return BadRequest(new { message = "Rule name is required." });

        var typeStr = body.TryGetProperty("type", out var t) ? t.GetString() : "BudgetThreshold";
        if (!Enum.TryParse<ThemarIP.Domain.Enums.Pfm.IntelligenceRuleType>(typeStr, true, out var ruleType))
        {
            ruleType = ThemarIP.Domain.Enums.Pfm.IntelligenceRuleType.BudgetThreshold;
        }

        var template = body.TryGetProperty("insightTemplate", out var tmpl) ? tmpl.GetString() : string.Empty;
        var icon = body.TryGetProperty("icon", out var ic) ? ic.GetString() : "bell";
        var iconColor = body.TryGetProperty("iconColor", out var col) ? col.GetString() : "#8B5CF6";
        var statusStr = body.TryGetProperty("status", out var st) ? st.GetString() : "active";

        var rule = new ThemarIP.Domain.Entities.Pfm.PfmIntelligenceRule
        {
            Id = Guid.NewGuid(),
            Name = name.Trim(),
            RuleType = ruleType,
            Status = string.Equals(statusStr, "active", StringComparison.OrdinalIgnoreCase)
                ? ThemarIP.Domain.Enums.Pfm.IntelligenceRuleStatus.Active
                : ThemarIP.Domain.Enums.Pfm.IntelligenceRuleStatus.Inactive,
            InsightTemplate = template ?? string.Empty,
            Icon = string.IsNullOrWhiteSpace(icon) ? "bell" : icon,
            IconColor = string.IsNullOrWhiteSpace(iconColor) ? "#8B5CF6" : iconColor,
            CreatedAt = DateTimeOffset.UtcNow,
            UpdatedAt = DateTimeOffset.UtcNow
        };

        if (body.TryGetProperty("params", out var paramsElem) && paramsElem.ValueKind == System.Text.Json.JsonValueKind.Object)
        {
            foreach (var prop in paramsElem.EnumerateObject())
            {
                rule.Params.Add(new ThemarIP.Domain.Entities.Pfm.PfmIntelligenceRuleParam
                {
                    Id = Guid.NewGuid(),
                    RuleId = rule.Id,
                    ParamKey = prop.Name,
                    ParamValue = prop.Value.ToString(),
                    ParamType = ThemarIP.Domain.Enums.Pfm.IntelligenceRuleParamType.String,
                    UpdatedAt = DateTimeOffset.UtcNow
                });
            }
        }
        else
        {
            // Default params for budget threshold rule
            rule.Params.Add(new ThemarIP.Domain.Entities.Pfm.PfmIntelligenceRuleParam
            {
                Id = Guid.NewGuid(),
                RuleId = rule.Id,
                ParamKey = "thresholdPercent",
                ParamValue = "50",
                ParamType = ThemarIP.Domain.Enums.Pfm.IntelligenceRuleParamType.Number
            });
            rule.Params.Add(new ThemarIP.Domain.Entities.Pfm.PfmIntelligenceRuleParam
            {
                Id = Guid.NewGuid(),
                RuleId = rule.Id,
                ParamKey = "channel",
                ParamValue = "Push Notification",
                ParamType = ThemarIP.Domain.Enums.Pfm.IntelligenceRuleParamType.String
            });
            rule.Params.Add(new ThemarIP.Domain.Entities.Pfm.PfmIntelligenceRuleParam
            {
                Id = Guid.NewGuid(),
                RuleId = rule.Id,
                ParamKey = "period",
                ParamValue = "monthly",
                ParamType = ThemarIP.Domain.Enums.Pfm.IntelligenceRuleParamType.String
            });
        }

        context.PfmIntelligenceRules.Add(rule);
        await context.SaveChangesAsync(default);

        return Ok(new
        {
            id = rule.Id.ToString(),
            type = rule.RuleType.ToString(),
            name = rule.Name,
            description = rule.InsightTemplate,
            status = rule.Status.ToString().ToLowerInvariant(),
            icon = rule.Icon,
            iconColor = rule.IconColor,
            fireCount = rule.FireCount,
            @params = rule.Params.Select(p => new { paramKey = p.ParamKey, paramValue = p.ParamValue }).ToList()
        });
    }

    [HttpDelete("intelligence-rules/{id}")]
    public async Task<IActionResult> DeleteIntelligenceRule(
        [FromRoute] Guid id,
        [FromServices] ThemarIP.Infrastructure.Persistence.ApplicationDbContext context)
    {
        var rule = await Microsoft.EntityFrameworkCore.EntityFrameworkQueryableExtensions.FirstOrDefaultAsync(
            Microsoft.EntityFrameworkCore.EntityFrameworkQueryableExtensions.Include(
                Microsoft.EntityFrameworkCore.EntityFrameworkQueryableExtensions.Include(
                    context.PfmIntelligenceRules,
                    r => r.Params
                ),
                r => r.Alerts
            ),
            r => r.Id == id
        );
        if (rule == null) return NotFound(new { message = "Intelligence rule not found." });

        context.PfmIntelligenceRuleParams.RemoveRange(rule.Params);
        context.PfmIntelligenceAlerts.RemoveRange(rule.Alerts);
        context.PfmIntelligenceRules.Remove(rule);
        await context.SaveChangesAsync(default);

        return Ok(new { success = true, message = "Intelligence rule deleted successfully." });
    }

    [HttpPost("intelligence-rules/evaluate")]
    public async Task<IActionResult> EvaluateIntelligenceRules(
        [FromBody] System.Text.Json.JsonElement? body,
        [FromQuery] Guid? userId,
        [FromServices] ThemarIP.Infrastructure.Persistence.ApplicationDbContext context)
    {
        Guid? filterRuleId = null;
        if (body.HasValue && body.Value.TryGetProperty("ruleId", out var rIdElem))
        {
            if (Guid.TryParse(rIdElem.GetString(), out var parsedRId)) filterRuleId = parsedRId;
        }

        Guid? targetUserId = userId;
        if (!targetUserId.HasValue && body.HasValue && body.Value.TryGetProperty("userId", out var uIdElem))
        {
            if (Guid.TryParse(uIdElem.GetString(), out var parsedUId)) targetUserId = parsedUId;
        }

        bool force = false;
        if (body.HasValue && body.Value.TryGetProperty("force", out var forceElem))
        {
            force = forceElem.GetBoolean();
        }

        // 1. Fetch active BudgetThreshold rules
        var allRules = await Microsoft.EntityFrameworkCore.EntityFrameworkQueryableExtensions.ToListAsync(
            Microsoft.EntityFrameworkCore.EntityFrameworkQueryableExtensions.Include(
                context.PfmIntelligenceRules,
                r => r.Params
            )
        );

        var budgetRules = allRules
            .Where(r => r.Status == ThemarIP.Domain.Enums.Pfm.IntelligenceRuleStatus.Active &&
                        r.RuleType == ThemarIP.Domain.Enums.Pfm.IntelligenceRuleType.BudgetThreshold &&
                        (!filterRuleId.HasValue || r.Id == filterRuleId.Value))
            .ToList();

        if (budgetRules.Count == 0)
        {
            return Ok(new
            {
                success = true,
                evaluatedRules = 0,
                notificationsTriggered = 0,
                message = "No active budget threshold rules found to evaluate.",
                notifications = new object[] { }
            });
        }

        // 2. Query open budget periods from vw_budget_period_overview
        var conn = context.Database.GetDbConnection();
        if (conn.State != System.Data.ConnectionState.Open)
        {
            await conn.OpenAsync();
        }

        var periodRows = new List<(string BudgetPeriodId, string UserId, string FullName, string Email, string Currency, long EffectiveTotal, long NormalSpent, long RemainingTotal, string PeriodStart, string PeriodEnd)>();

        string userFilter = "";
        if (targetUserId.HasValue && targetUserId.Value != Guid.Empty)
        {
            userFilter = $" AND lower(o.UserId) = '{targetUserId.Value.ToString().ToLowerInvariant()}'";
        }

        await using (var cmd = conn.CreateCommand())
        {
            cmd.CommandText = @"
                SELECT 
                    o.BudgetPeriodId,
                    o.UserId,
                    COALESCE(u.FullName, 'Demo User') AS FullName,
                    COALESCE(u.Email, 'user@themarip.com') AS Email,
                    o.Currency,
                    o.EffectiveTotalBudgetBaisa,
                    o.NormalSpentBaisa,
                    o.RemainingTotalBaisa,
                    o.PeriodStart,
                    o.PeriodEnd
                FROM vw_budget_period_overview o
                LEFT JOIN Users u ON lower(u.Id) = lower(o.UserId)
                WHERE o.Status = 'open' AND o.EffectiveTotalBudgetBaisa > 0" + userFilter + ";";

            await using var reader = await cmd.ExecuteReaderAsync();
            while (await reader.ReadAsync())
            {
                periodRows.Add((
                    reader.GetString(0),
                    reader.GetString(1),
                    reader.GetString(2),
                    reader.GetString(3),
                    reader.GetString(4),
                    Convert.ToInt64(reader.GetValue(5)),
                    Convert.ToInt64(reader.GetValue(6)),
                    Convert.ToInt64(reader.GetValue(7)),
                    reader.GetString(8),
                    reader.GetString(9)
                ));
            }
        }

        var dispatchedNotifications = new List<object>();
        var cooldownCutoff = DateTimeOffset.UtcNow.AddHours(-12);

        // Fetch recent alerts for deduplication
        var recentAlerts = await Microsoft.EntityFrameworkCore.EntityFrameworkQueryableExtensions.ToListAsync(
            context.PfmIntelligenceAlerts.Where(a => a.TriggeredAt > cooldownCutoff)
        );

        foreach (var rule in budgetRules)
        {
            // Parse threshold percent
            var threshParam = rule.Params.FirstOrDefault(p => string.Equals(p.ParamKey, "thresholdPercent", StringComparison.OrdinalIgnoreCase)
                                                            || string.Equals(p.ParamKey, "threshold", StringComparison.OrdinalIgnoreCase));
            double thresholdPercent = 50.0;
            if (threshParam != null && double.TryParse(threshParam.ParamValue, out var parsedThresh))
            {
                thresholdPercent = parsedThresh;
            }

            foreach (var bp in periodRows)
            {
                if (!Guid.TryParse(bp.UserId, out var userGuid)) continue;

                double spendPct = bp.EffectiveTotal > 0
                    ? (bp.NormalSpent / (double)bp.EffectiveTotal) * 100.0
                    : 0.0;

                if (spendPct >= thresholdPercent)
                {
                    // Check deduplication
                    if (!force && recentAlerts.Any(a => a.RuleId == rule.Id && a.UserId == userGuid))
                    {
                        continue; // already fired recently
                    }

                    // Resolve template
                    string template = string.IsNullOrWhiteSpace(rule.InsightTemplate)
                        ? "You have reached {thresholdPercent}% of your monthly budget ({spentAmount} of {totalBudget} {currency})."
                        : rule.InsightTemplate;

                    var spentAmountStr = (bp.NormalSpent / 1000.0).ToString("N3", System.Globalization.CultureInfo.InvariantCulture);
                    var totalBudgetStr = (bp.EffectiveTotal / 1000.0).ToString("N3", System.Globalization.CultureInfo.InvariantCulture);
                    var remainingAmountStr = (Math.Max(0, bp.RemainingTotal) / 1000.0).ToString("N3", System.Globalization.CultureInfo.InvariantCulture);

                    var msg = template
                        .Replace("{thresholdPercent}", thresholdPercent.ToString("0"))
                        .Replace("{threshold}", thresholdPercent.ToString("0"))
                        .Replace("{spentAmount}", spentAmountStr)
                        .Replace("{totalBudget}", totalBudgetStr)
                        .Replace("{remainingAmount}", remainingAmountStr)
                        .Replace("{currency}", bp.Currency)
                        .Replace("{userName}", bp.FullName)
                        .Replace("{period}", "monthly");

                    // Also replace any custom rule parameters in template
                    foreach (var p in rule.Params)
                    {
                        msg = msg.Replace($"{{{p.ParamKey}}}", p.ParamValue);
                    }

                    var alert = new ThemarIP.Domain.Entities.Pfm.PfmIntelligenceAlert
                    {
                        Id = Guid.NewGuid(),
                        RuleId = rule.Id,
                        UserId = userGuid,
                        AlertText = msg,
                        TriggeredAt = DateTimeOffset.UtcNow,
                        IsRead = false
                    };

                    context.PfmIntelligenceAlerts.Add(alert);
                    rule.FireCount++;
                    rule.LastFiredAt = DateTimeOffset.UtcNow;

                    dispatchedNotifications.Add(new
                    {
                        alertId = alert.Id.ToString(),
                        ruleId = rule.Id.ToString(),
                        ruleName = rule.Name,
                        userId = bp.UserId,
                        userName = bp.FullName,
                        userEmail = bp.Email,
                        thresholdPercent = thresholdPercent,
                        currentSpendPercent = Math.Round(spendPct, 1),
                        spentAmount = spentAmountStr,
                        totalBudget = totalBudgetStr,
                        currency = bp.Currency,
                        channel = "Push Notification",
                        message = msg,
                        deliveryStatus = "Delivered",
                        triggeredAt = alert.TriggeredAt
                    });
                }
            }
        }

        await context.SaveChangesAsync(default);

        return Ok(new
        {
            success = true,
            evaluatedRules = budgetRules.Count,
            evaluatedUsers = periodRows.Count,
            notificationsTriggered = dispatchedNotifications.Count,
            notifications = dispatchedNotifications
        });
    }

    [HttpGet("intelligence-rules/alerts")]
    public async Task<IActionResult> GetIntelligenceAlerts(
        [FromServices] ThemarIP.Infrastructure.Persistence.ApplicationDbContext context,
        [FromQuery] Guid? userId = null)
    {
        var query = context.PfmIntelligenceAlerts
            .Include(a => a.Rule)
            .Include(a => a.User)
            .AsQueryable();

        if (userId.HasValue && userId.Value != Guid.Empty)
        {
            query = query.Where(a => a.UserId == userId.Value);
        }

        var alerts = await query
            .OrderByDescending(a => a.TriggeredAt)
            .Take(50)
            .ToListAsync();

        var result = alerts.Select(a => new
        {
            id = a.Id.ToString(),
            ruleId = a.RuleId.ToString(),
            ruleName = a.Rule?.Name ?? "Budget Intelligence Rule",
            ruleType = a.Rule?.RuleType.ToString() ?? "BudgetThreshold",
            userId = a.UserId.ToString(),
            userName = a.User?.FullName ?? "Demo User",
            userEmail = a.User?.Email ?? "user@themarip.com",
            message = a.AlertText,
            channel = "Push Notification",
            deliveryStatus = "Delivered",
            isRead = a.IsRead,
            triggeredAt = a.TriggeredAt
        }).ToList();

        return Ok(result);
    }

    [HttpPost("intelligence-rules/alerts/{id}/read")]
    public async Task<IActionResult> MarkAlertAsRead(
        [FromRoute] Guid id,
        [FromServices] ThemarIP.Infrastructure.Persistence.ApplicationDbContext context)
    {
        var alert = await context.PfmIntelligenceAlerts.FindAsync(id);
        if (alert == null) return NotFound(new { message = "Alert not found." });

        alert.IsRead = true;
        await context.SaveChangesAsync(default);
        return Ok(new { success = true });
    }

    [HttpPost("intelligence-rules/alerts/mark-all-read")]
    public async Task<IActionResult> MarkAllAlertsAsRead(
        [FromQuery] Guid? userId,
        [FromServices] ThemarIP.Infrastructure.Persistence.ApplicationDbContext context)
    {
        var query = context.PfmIntelligenceAlerts.Where(a => !a.IsRead);
        if (userId.HasValue && userId.Value != Guid.Empty)
        {
            query = query.Where(a => a.UserId == userId.Value);
        }

        var unread = await query.ToListAsync();
        foreach (var a in unread)
        {
            a.IsRead = true;
        }

        await context.SaveChangesAsync(default);
        return Ok(new { success = true, markedCount = unread.Count });
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

        // Map to format that works seamlessly for frontend, ordered by DisplayOrder:
        // Returns id, name, icon, color, displayOrder, isEnabled, parentId,
        // and both 'children' and 'subcategories' (for backwards compatibility)
        var result = rootCategories
            .OrderBy(c => c.DisplayOrder)
            .ThenBy(c => c.Name)
            .Select(c => new
            {
                id = c.Id,
                name = c.Name,
                icon = c.Icon,
                color = c.Color,
                displayOrder = c.DisplayOrder,
                isEnabled = c.IsEnabled,
                parentId = c.ParentId,
                children = c.Children
                    .OrderBy(sub => sub.DisplayOrder)
                    .ThenBy(sub => sub.Name)
                    .Select(sub => new
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
                subcategories = c.Children
                    .OrderBy(sub => sub.DisplayOrder)
                    .ThenBy(sub => sub.Name)
                    .Select(sub => new
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
    /// by matching PfmTransaction.Narration against active PfmMerchants (and PfmMerchantAliases, longest match first),
    /// active PfmCategorizationRules (with PfmRuleConditions), and active CategoryRules.
    /// Both Admin Portal and Mobile App use this unified engine.
    /// </summary>
    [HttpGet("category-stats")]
    public async Task<IActionResult> GetCategoryStats(
        [FromQuery] System.Guid? userId,
        [FromQuery] string? bankCode,
        [FromServices] ThemarIP.Application.Common.Interfaces.IApplicationDbContext context,
        [FromServices] ThemarIP.Application.Common.Interfaces.IBankTransactionMessageParserService messageParser)
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

        var pfmRules = await Microsoft.EntityFrameworkCore.EntityFrameworkQueryableExtensions.ToListAsync(
            Microsoft.EntityFrameworkCore.EntityFrameworkQueryableExtensions.Include(
                context.PfmCategorizationRules.Where(r => r.Status == ThemarIP.Domain.Enums.Pfm.RuleStatus.Active),
                r => r.Conditions
            )
        );
        var activePfmRules = pfmRules.OrderByDescending(r => r.Priority).ThenByDescending(r => r.Confidence).ToList();

        var legacyRules = await Microsoft.EntityFrameworkCore.EntityFrameworkQueryableExtensions.ToListAsync(context.CategoryRules);
        var activeLegacyRules = legacyRules.Where(r => r.IsActive).OrderByDescending(r => r.Priority).ThenByDescending(r => (r.Keyword ?? "").Length).ToList();

        if (!userId.HasValue || userId.Value == System.Guid.Empty)
        {
            var claimId = User?.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value;
            if (System.Guid.TryParse(claimId, out var parsedUserId))
            {
                userId = parsedUserId;
            }
        }

        var txQuery = context.PfmTransactions.AsQueryable();
        if (userId.HasValue && userId.Value != System.Guid.Empty)
        {
            txQuery = txQuery.Where(t => t.UserId == userId.Value);
        }
        if (!string.IsNullOrWhiteSpace(bankCode) && !string.Equals(bankCode, "ALL", System.StringComparison.OrdinalIgnoreCase))
        {
            txQuery = txQuery.Where(t => t.BankCode == bankCode);
        }
        var transactions = await Microsoft.EntityFrameworkCore.EntityFrameworkQueryableExtensions.ToListAsync(txQuery);
        transactions = transactions.OrderByDescending(t => t.TransactionDate).ThenByDescending(t => t.CreatedAt).ToList();

        var rawRootCategories = await Microsoft.EntityFrameworkCore.EntityFrameworkQueryableExtensions.ToListAsync(
            Microsoft.EntityFrameworkCore.EntityFrameworkQueryableExtensions.Include(
                context.PfmCategories.Where(c => c.ParentId == null),
                c => c.Children
            )
        );
        var rootCategories = rawRootCategories
            .Where(c => c.IsEnabled)
            .OrderBy(c => c.DisplayOrder)
            .ThenBy(c => c.Name)
            .ToList();

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

        var parsedMap = await messageParser.GetParsedLookupByTransactionIdsAsync(transactions.Select(t => t.Id));

        foreach (var tx in transactions)
        {
            var narration = (tx.Narration ?? "").ToUpperInvariant();
            bool isCreditTx = tx.TransactionType == ThemarIP.Domain.Enums.Pfm.TransactionType.Credit
                || (narration.Contains("HAS BEEN CREDITED") && !narration.Contains("IS DEBITED"))
                || (narration.Contains("RECEIVED") && narration.Contains("FROM"))
                || narration.Contains("MOBILE PAYMENT FROM");
            bool isDebitPosOrOutgoing = !isCreditTx && (narration.StartsWith("POS ") || narration.Contains("IS DEBITED") || narration.Contains("MOBILE PAYMENT FOR"));

            if (!parsedMap.TryGetValue(tx.Id, out var parsedMsg))
            {
                parsedMsg = await messageParser.ParseAndStoreAsync(new ThemarIP.Application.DTOs.Sms.ParseBankMessageRequestDto
                {
                    BankCode = tx.BankCode,
                    Sender = tx.BankName,
                    RawMessage = tx.Narration ?? string.Empty,
                    FallbackAmount = tx.Amount,
                    FallbackCurrency = tx.Currency,
                    FallbackDirection = isCreditTx ? "CREDIT" : "DEBIT",
                    FallbackDate = tx.TransactionDate
                }, tx.UserId, tx.Id, null);
                parsedMap[tx.Id] = parsedMsg;
            }

            string cleanDescription = !string.IsNullOrWhiteSpace(parsedMsg.GeneratedDescription)
                ? parsedMsg.GeneratedDescription
                : (tx.Narration ?? "Transaction");

            // Prefer the parsed message date+time when PfmTransaction.TransactionDate has 00:00:00 time, or fall back to CreatedAt time
            var effectiveTxDate = tx.TransactionDate;
            if (parsedMsg.TransactionDate.HasValue &&
                (effectiveTxDate.TimeOfDay == System.TimeSpan.Zero || parsedMsg.TransactionDate.Value.TimeOfDay != System.TimeSpan.Zero))
            {
                effectiveTxDate = parsedMsg.TransactionDate.Value;
            }
            else if (effectiveTxDate.TimeOfDay == System.TimeSpan.Zero && tx.CreatedAt.Date == effectiveTxDate.Date && tx.CreatedAt.TimeOfDay != System.TimeSpan.Zero)
            {
                effectiveTxDate = tx.CreatedAt;
            }

            object BuildTxItem(string matchedKw, string subCat) => new
            {
                id = tx.Id,
                transactionDate = effectiveTxDate,
                createdAt = tx.CreatedAt,
                narration = cleanDescription,
                generatedDescription = cleanDescription,
                originalMessage = tx.Narration,
                amount = tx.Amount,
                currency = tx.Currency,
                transactionType = isCreditTx ? "Credit" : "Debit",
                transactionTypeCode = parsedMsg.TransactionType,
                direction = isCreditTx ? "CREDIT" : "DEBIT",
                balanceAfter = tx.BalanceAfter ?? parsedMsg.BalanceAfter,
                counterpartyName = parsedMsg.CounterpartyName,
                accountNumberMasked = parsedMsg.AccountNumberMasked,
                transactionReference = parsedMsg.TransactionReference,
                confidenceScore = parsedMsg.ConfidenceScore,
                reviewStatus = parsedMsg.ReviewStatus,
                matchedKeyword = matchedKw,
                subcategory = subCat,
                bankCode = tx.BankCode,
                bankName = tx.BankName
            };

            bool matched = false;

            // 1. Check Active Merchants & Aliases from themarip.db (Longest-Match-First specificity)
            ThemarIP.Domain.Entities.Pfm.PfmMerchant? bestMerchant = null;
            int bestMatchLen = 0;

            foreach (var merchant in activeMerchants)
            {
                var mCatName = merchant.DefaultCategory?.Name ?? "";
                if (isDebitPosOrOutgoing && string.Equals(mCatName, "Income", System.StringComparison.OrdinalIgnoreCase))
                {
                    continue;
                }

                int maxLenForMerchant = 0;
                if (!string.IsNullOrWhiteSpace(merchant.Name))
                {
                    var mNameUpper = merchant.Name.Trim().ToUpperInvariant();
                    if (narration.Contains(mNameUpper))
                    {
                        maxLenForMerchant = mNameUpper.Length;
                    }
                }

                foreach (var alias in merchant.Aliases)
                {
                    if (!string.IsNullOrWhiteSpace(alias.AliasText))
                    {
                        var aliasUpper = alias.AliasText.Trim().ToUpperInvariant();
                        if (aliasUpper.Length > maxLenForMerchant && narration.Contains(aliasUpper))
                        {
                            maxLenForMerchant = aliasUpper.Length;
                        }
                    }
                }

                if (maxLenForMerchant > 0)
                {
                    if (bestMerchant == null ||
                        maxLenForMerchant > bestMatchLen ||
                        (maxLenForMerchant == bestMatchLen && merchant.DefaultConfidence > bestMerchant.DefaultConfidence))
                    {
                        bestMerchant = merchant;
                        bestMatchLen = maxLenForMerchant;
                    }
                }
            }

            if (bestMerchant != null)
            {
                string targetCatName = "Other";
                string subName = "Uncategorized";

                if (bestMerchant.DefaultSubcategoryId.HasValue)
                {
                    var foundSub = allSubcategories.FirstOrDefault(s => s.Sub.Id == bestMerchant.DefaultSubcategoryId.Value);
                    if (foundSub != null)
                    {
                        targetCatName = foundSub.Parent.Name;
                        subName = foundSub.Sub.Name;
                    }
                }

                if (targetCatName == "Other" && bestMerchant.DefaultCategoryId.HasValue)
                {
                    var foundCat = rootCategories.FirstOrDefault(c => c.Id == bestMerchant.DefaultCategoryId.Value);
                    if (foundCat != null)
                    {
                        targetCatName = foundCat.Name;
                        subName = foundCat.Children.OrderBy(s => s.DisplayOrder).FirstOrDefault()?.Name ?? foundCat.Name;
                    }
                }

                if (targetCatName == "Other" && bestMerchant.DefaultCategory != null)
                {
                    targetCatName = bestMerchant.DefaultCategory.Name;
                    subName = bestMerchant.DefaultCategory.Children.OrderBy(s => s.DisplayOrder).FirstOrDefault()?.Name ?? targetCatName;
                }

                if (counts.ContainsKey(targetCatName)) counts[targetCatName]++;
                else counts["Other"]++;

                var txItem = BuildTxItem(bestMerchant.Name, subName);

                if (catTxns.ContainsKey(targetCatName)) catTxns[targetCatName].Add(txItem);
                else catTxns["Other"].Add(txItem);

                matched = true;
            }

            // 2. Check Active PfmCategorizationRules (with PfmRuleConditions, ordered by Priority desc)
            if (!matched)
            {
                foreach (var pfmRule in activePfmRules)
                {
                    if (pfmRule.Conditions == null || pfmRule.Conditions.Count == 0) continue;

                    string matchedKeyword = pfmRule.Name;
                    if (EvaluatePfmRuleConditions(pfmRule.Conditions, tx, narration, isCreditTx, out var condKeyword))
                    {
                        if (!string.IsNullOrWhiteSpace(condKeyword)) matchedKeyword = condKeyword;

                        string targetCatName = "Other";
                        string subName = "Uncategorized";

                        if (pfmRule.SubcategoryId.HasValue)
                        {
                            var foundSub = allSubcategories.FirstOrDefault(s => s.Sub.Id == pfmRule.SubcategoryId.Value);
                            if (foundSub != null)
                            {
                                targetCatName = foundSub.Parent.Name;
                                subName = foundSub.Sub.Name;
                            }
                        }

                        if (targetCatName == "Other" && pfmRule.CategoryId.HasValue)
                        {
                            var foundCat = rootCategories.FirstOrDefault(c => c.Id == pfmRule.CategoryId.Value);
                            if (foundCat != null)
                            {
                                targetCatName = foundCat.Name;
                                subName = foundCat.Children.OrderBy(s => s.DisplayOrder).FirstOrDefault()?.Name ?? foundCat.Name;
                            }
                        }

                        if (counts.ContainsKey(targetCatName)) counts[targetCatName]++;
                        else counts["Other"]++;

                        var txItem = BuildTxItem(matchedKeyword, subName);

                        if (catTxns.ContainsKey(targetCatName)) catTxns[targetCatName].Add(txItem);
                        else catTxns["Other"].Add(txItem);

                        matched = true;
                        break;
                    }
                }
            }

            // 3. Check Active Legacy CategoryRules fallback
            if (!matched)
            {
                foreach (var rule in activeLegacyRules)
                {
                    if (!string.IsNullOrEmpty(rule.Keyword) &&
                        narration.Contains(rule.Keyword.ToUpperInvariant()))
                    {
                        var matchedSub = allSubcategories.FirstOrDefault(s =>
                            string.Equals(s.Sub.Name, rule.Category, System.StringComparison.OrdinalIgnoreCase));
                        var parentCat = matchedSub?.Parent ?? rootCategories.FirstOrDefault(c =>
                            string.Equals(c.Name, rule.Category, System.StringComparison.OrdinalIgnoreCase));

                        var catName = parentCat?.Name ?? "Other";
                        var subName = matchedSub?.Sub.Name ?? parentCat?.Children.OrderBy(s => s.DisplayOrder).FirstOrDefault()?.Name ?? rule.Category;

                        if (counts.ContainsKey(catName)) counts[catName]++;
                        else counts["Other"]++;

                        var txItem = BuildTxItem(rule.Keyword, subName);

                        if (catTxns.ContainsKey(catName)) catTxns[catName].Add(txItem);
                        else catTxns["Other"].Add(txItem);

                        matched = true;
                        break;
                    }
                }
            }

            // 4. Fallback: Uncategorized / Credit Deposit
            if (!matched)
            {
                string fallbackCat = isCreditTx && catTxns.ContainsKey("Income") ? "Income" : "Other";
                counts[fallbackCat]++;
                catTxns[fallbackCat].Add(BuildTxItem("", isCreditTx ? "Freelance" : "Uncategorized"));
            }
        }

        var result = rootCategories
            .Select(c => new
            {
                categoryName = c.Name,
                icon         = c.Icon,
                color        = c.Color,
                displayOrder = c.DisplayOrder,
                isEnabled    = c.IsEnabled,
                txnCount     = counts.ContainsKey(c.Name) ? counts[c.Name] : 0,
                transactions = catTxns.ContainsKey(c.Name) ? catTxns[c.Name] : new System.Collections.Generic.List<object>()
            })
            .ToList();

        return Ok(result);
    }

    private static bool EvaluatePfmRuleConditions(
        System.Collections.Generic.ICollection<ThemarIP.Domain.Entities.Pfm.PfmRuleCondition> conditions,
        ThemarIP.Domain.Entities.Pfm.PfmTransaction tx,
        string narrationUpper,
        bool isCreditTx,
        out string matchedValue)
    {
        matchedValue = string.Empty;
        var ordered = conditions.OrderBy(c => c.OrderIndex).ToList();
        if (ordered.Count == 0) return false;

        bool result = true;
        for (int i = 0; i < ordered.Count; i++)
        {
            var c = ordered[i];
            var targetVal = (c.Value ?? "").Trim();
            var targetUpper = targetVal.ToUpperInvariant();
            bool condHit = false;

            switch (c.Field)
            {
                case ThemarIP.Domain.Enums.Pfm.RuleConditionField.TransactionType:
                    var txTypeStr = isCreditTx ? "CREDIT" : "DEBIT";
                    condHit = EvaluateStringOp(txTypeStr, targetUpper, c.Operator);
                    break;

                case ThemarIP.Domain.Enums.Pfm.RuleConditionField.Currency:
                    condHit = EvaluateStringOp((tx.Currency ?? "OMR").ToUpperInvariant(), targetUpper, c.Operator);
                    break;

                case ThemarIP.Domain.Enums.Pfm.RuleConditionField.MccCode:
                    condHit = EvaluateStringOp((tx.MccCode ?? "").ToUpperInvariant(), targetUpper, c.Operator);
                    break;

                case ThemarIP.Domain.Enums.Pfm.RuleConditionField.Amount:
                    if (decimal.TryParse(targetVal, System.Globalization.NumberStyles.Any, System.Globalization.CultureInfo.InvariantCulture, out var numVal))
                    {
                        condHit = c.Operator switch
                        {
                            ThemarIP.Domain.Enums.Pfm.RuleConditionOperator.Equals => tx.Amount == numVal,
                            ThemarIP.Domain.Enums.Pfm.RuleConditionOperator.GreaterThan => tx.Amount > numVal,
                            ThemarIP.Domain.Enums.Pfm.RuleConditionOperator.LessThan => tx.Amount < numVal,
                            _ => tx.Amount == numVal
                        };
                    }
                    break;

                default: // Narration, MerchantName, MerchantId
                    condHit = EvaluateStringOp(narrationUpper, targetUpper, c.Operator);
                    if (condHit && string.IsNullOrEmpty(matchedValue))
                    {
                        matchedValue = targetVal;
                    }
                    break;
            }

            if (i == 0)
            {
                result = condHit;
            }
            else
            {
                var prevLogic = ordered[i - 1].LogicOperator;
                if (prevLogic == ThemarIP.Domain.Enums.Pfm.RuleConditionLogic.Or || c.LogicOperator == ThemarIP.Domain.Enums.Pfm.RuleConditionLogic.Or)
                {
                    result = result || condHit;
                }
                else
                {
                    result = result && condHit;
                }
            }
        }

        return result;
    }

    private static bool EvaluateStringOp(string sourceUpper, string targetUpper, ThemarIP.Domain.Enums.Pfm.RuleConditionOperator op)
    {
        if (string.IsNullOrEmpty(targetUpper)) return false;
        return op switch
        {
            ThemarIP.Domain.Enums.Pfm.RuleConditionOperator.Equals => string.Equals(sourceUpper, targetUpper, System.StringComparison.OrdinalIgnoreCase),
            ThemarIP.Domain.Enums.Pfm.RuleConditionOperator.StartsWith => sourceUpper.StartsWith(targetUpper, System.StringComparison.OrdinalIgnoreCase),
            ThemarIP.Domain.Enums.Pfm.RuleConditionOperator.EndsWith => sourceUpper.EndsWith(targetUpper, System.StringComparison.OrdinalIgnoreCase),
            _ => sourceUpper.Contains(targetUpper, System.StringComparison.OrdinalIgnoreCase)
        };
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
        if (!userId.HasValue || userId.Value == System.Guid.Empty)
        {
            var claimId = User?.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value;
            if (System.Guid.TryParse(claimId, out var parsedUserId))
            {
                userId = parsedUserId;
            }
        }

        var txQuery = context.PfmTransactions.AsQueryable();
        ThemarIP.Domain.Entities.User? user = null;
        if (userId.HasValue && userId.Value != System.Guid.Empty)
        {
            txQuery = txQuery.Where(t => t.UserId == userId.Value);
            user = await context.Users.FindAsync(userId.Value);
        }

        var txList = await Microsoft.EntityFrameworkCore.EntityFrameworkQueryableExtensions.ToListAsync(txQuery);
        var grouped = txList
            .Select(t => new { Canonical = ThemarIP.Application.Common.BankCatalog.Canonical(t.BankCode, t.BankName), Tx = t })
            .GroupBy(x => x.Canonical.Code, StringComparer.OrdinalIgnoreCase)
            .ToDictionary(
                g => g.Key,
                g => new
                {
                    bankCode = g.First().Canonical.Code,
                    bankName = g.First().Canonical.Name,
                    txCount = g.Count(),
                    totalSpent = g.Where(x => x.Tx.TransactionType == ThemarIP.Domain.Enums.Pfm.TransactionType.Debit).Sum(x => x.Tx.Amount)
                },
                StringComparer.OrdinalIgnoreCase
            );

        if (user != null)
        {
            var selected = ThemarIP.Application.Common.BankCatalog.ParseSelection(user.AccountNumber);
            foreach (var sb in selected)
            {
                if (!grouped.ContainsKey(sb.Code))
                {
                    grouped[sb.Code] = new
                    {
                        bankCode = sb.Code,
                        bankName = sb.Name,
                        txCount = 0,
                        totalSpent = 0m
                    };
                }
            }
        }

        var banks = grouped.Values
            .OrderByDescending(b => b.txCount)
            .ThenBy(b => b.bankName)
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

        if (!dto.UserId.HasValue || dto.UserId.Value == System.Guid.Empty)
        {
            var claimId = User?.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value;
            if (System.Guid.TryParse(claimId, out var parsedUserId))
            {
                dto.UserId = parsedUserId;
            }
        }

        var txId = await _notificationParser.ConfirmAndSaveNotificationAsync(dto);
        return Ok(new { success = true, transactionId = txId, message = "Transaction saved to themarip.db successfully." });
    }

    [HttpPost("ingest-notification")]
    public async Task<IActionResult> IngestNotification([FromBody] IngestNotificationRequestDto dto)
    {
        if (string.IsNullOrWhiteSpace(dto.RawMessage) && string.IsNullOrWhiteSpace(dto.EmailSubject))
            return BadRequest(new { message = "Message content or email subject is required." });

        if (!dto.UserId.HasValue || dto.UserId.Value == System.Guid.Empty)
        {
            var claimId = User?.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value;
            if (System.Guid.TryParse(claimId, out var parsedUserId))
            {
                dto.UserId = parsedUserId;
            }
        }

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



