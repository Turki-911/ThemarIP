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
        var result = users.Select(u => new
        {
            id = u.Id,
            email = u.Email,
            fullName = u.FullName,
            accountNumber = u.AccountNumber,
            role = u.Role.ToString(),
            accessStatus = u.AccessStatus.ToString(),
            trustScore = u.TrustScore,
            createdAt = u.CreatedAt
        }).OrderByDescending(u => u.createdAt).ToList();
        return Ok(result);
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
        var rules = await Microsoft.EntityFrameworkCore.EntityFrameworkQueryableExtensions.ToListAsync(context.CategoryRules);
        return Ok(rules);
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
                        subcategory = subName
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
                            subcategory = rule.Category
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
                    subcategory = "Uncategorized"
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

