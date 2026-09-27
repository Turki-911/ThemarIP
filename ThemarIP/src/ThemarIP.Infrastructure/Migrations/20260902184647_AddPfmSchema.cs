using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace ThemarIP.Infrastructure.Migrations
{
    /// <inheritdoc />
    public partial class AddPfmSchema : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AlterColumn<string>(
                name: "AccessStatus",
                table: "Users",
                type: "TEXT",
                nullable: false,
                defaultValue: "Pending",
                oldClrType: typeof(string),
                oldType: "TEXT");

            migrationBuilder.CreateTable(
                name: "PfmAuditLogs",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "TEXT", nullable: false),
                    AdminUserId = table.Column<Guid>(type: "TEXT", nullable: false),
                    ActionType = table.Column<string>(type: "TEXT", nullable: false),
                    EntityType = table.Column<string>(type: "TEXT", maxLength: 128, nullable: false),
                    EntityId = table.Column<string>(type: "TEXT", maxLength: 128, nullable: false),
                    Description = table.Column<string>(type: "TEXT", maxLength: 1024, nullable: false),
                    OldValueJson = table.Column<string>(type: "TEXT", nullable: true),
                    NewValueJson = table.Column<string>(type: "TEXT", nullable: true),
                    Timestamp = table.Column<DateTimeOffset>(type: "TEXT", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_PfmAuditLogs", x => x.Id);
                    table.ForeignKey(
                        name: "FK_PfmAuditLogs_Users_AdminUserId",
                        column: x => x.AdminUserId,
                        principalTable: "Users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "PfmCategories",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "TEXT", nullable: false),
                    Name = table.Column<string>(type: "TEXT", maxLength: 128, nullable: false),
                    Icon = table.Column<string>(type: "TEXT", maxLength: 64, nullable: false, defaultValue: "tag"),
                    Color = table.Column<string>(type: "TEXT", maxLength: 16, nullable: false, defaultValue: "#94A3B8"),
                    DisplayOrder = table.Column<int>(type: "INTEGER", nullable: false, defaultValue: 0),
                    IsEnabled = table.Column<bool>(type: "INTEGER", nullable: false, defaultValue: true),
                    CreatedAt = table.Column<DateTimeOffset>(type: "TEXT", nullable: false),
                    UpdatedAt = table.Column<DateTimeOffset>(type: "TEXT", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_PfmCategories", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "PfmConfidenceBands",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "TEXT", nullable: false),
                    BandName = table.Column<string>(type: "TEXT", nullable: false),
                    DisplayLabel = table.Column<string>(type: "TEXT", maxLength: 128, nullable: false),
                    MinThreshold = table.Column<int>(type: "INTEGER", nullable: false, defaultValue: 0),
                    MaxThreshold = table.Column<int>(type: "INTEGER", nullable: false, defaultValue: 100),
                    Action = table.Column<string>(type: "TEXT", nullable: false),
                    ActionLabel = table.Column<string>(type: "TEXT", maxLength: 256, nullable: false),
                    UpdatedAt = table.Column<DateTimeOffset>(type: "TEXT", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_PfmConfidenceBands", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "PfmConfidenceWeights",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "TEXT", nullable: false),
                    Signal = table.Column<string>(type: "TEXT", nullable: false),
                    DisplayLabel = table.Column<string>(type: "TEXT", maxLength: 128, nullable: false),
                    WeightPercent = table.Column<int>(type: "INTEGER", nullable: false, defaultValue: 0),
                    Color = table.Column<string>(type: "TEXT", maxLength: 16, nullable: false, defaultValue: "#94A3B8"),
                    UpdatedAt = table.Column<DateTimeOffset>(type: "TEXT", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_PfmConfidenceWeights", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "PfmIntelligenceRules",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "TEXT", nullable: false),
                    Name = table.Column<string>(type: "TEXT", maxLength: 256, nullable: false),
                    RuleType = table.Column<string>(type: "TEXT", nullable: false),
                    Status = table.Column<string>(type: "TEXT", nullable: false, defaultValue: "Active"),
                    InsightTemplate = table.Column<string>(type: "TEXT", maxLength: 1024, nullable: false),
                    Icon = table.Column<string>(type: "TEXT", maxLength: 64, nullable: false, defaultValue: "zap"),
                    IconColor = table.Column<string>(type: "TEXT", maxLength: 16, nullable: false, defaultValue: "#3B82F6"),
                    FireCount = table.Column<int>(type: "INTEGER", nullable: false, defaultValue: 0),
                    LastFiredAt = table.Column<DateTimeOffset>(type: "TEXT", nullable: true),
                    CreatedAt = table.Column<DateTimeOffset>(type: "TEXT", nullable: false),
                    UpdatedAt = table.Column<DateTimeOffset>(type: "TEXT", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_PfmIntelligenceRules", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "PfmSubcategories",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "TEXT", nullable: false),
                    CategoryId = table.Column<Guid>(type: "TEXT", nullable: false),
                    Name = table.Column<string>(type: "TEXT", maxLength: 128, nullable: false),
                    DisplayOrder = table.Column<int>(type: "INTEGER", nullable: false, defaultValue: 0),
                    IsEnabled = table.Column<bool>(type: "INTEGER", nullable: false, defaultValue: true),
                    CreatedAt = table.Column<DateTimeOffset>(type: "TEXT", nullable: false),
                    UpdatedAt = table.Column<DateTimeOffset>(type: "TEXT", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_PfmSubcategories", x => x.Id);
                    table.ForeignKey(
                        name: "FK_PfmSubcategories_PfmCategories_CategoryId",
                        column: x => x.CategoryId,
                        principalTable: "PfmCategories",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "PfmIntelligenceRuleParams",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "TEXT", nullable: false),
                    RuleId = table.Column<Guid>(type: "TEXT", nullable: false),
                    ParamKey = table.Column<string>(type: "TEXT", maxLength: 128, nullable: false),
                    ParamValue = table.Column<string>(type: "TEXT", maxLength: 512, nullable: false),
                    ParamType = table.Column<string>(type: "TEXT", nullable: false, defaultValue: "String"),
                    UpdatedAt = table.Column<DateTimeOffset>(type: "TEXT", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_PfmIntelligenceRuleParams", x => x.Id);
                    table.ForeignKey(
                        name: "FK_PfmIntelligenceRuleParams_PfmIntelligenceRules_RuleId",
                        column: x => x.RuleId,
                        principalTable: "PfmIntelligenceRules",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "PfmCategorizationRules",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "TEXT", nullable: false),
                    Name = table.Column<string>(type: "TEXT", maxLength: 256, nullable: false),
                    CategoryId = table.Column<Guid>(type: "TEXT", nullable: true),
                    SubcategoryId = table.Column<Guid>(type: "TEXT", nullable: true),
                    Confidence = table.Column<int>(type: "INTEGER", nullable: false, defaultValue: 85),
                    Priority = table.Column<int>(type: "INTEGER", nullable: false, defaultValue: 50),
                    Status = table.Column<string>(type: "TEXT", nullable: false, defaultValue: "Active"),
                    MatchCount = table.Column<int>(type: "INTEGER", nullable: false, defaultValue: 0),
                    IsLearnedFromCorrection = table.Column<bool>(type: "INTEGER", nullable: false, defaultValue: false),
                    CreatedByAdminId = table.Column<Guid>(type: "TEXT", nullable: true),
                    CreatedAt = table.Column<DateTimeOffset>(type: "TEXT", nullable: false),
                    UpdatedAt = table.Column<DateTimeOffset>(type: "TEXT", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_PfmCategorizationRules", x => x.Id);
                    table.ForeignKey(
                        name: "FK_PfmCategorizationRules_PfmCategories_CategoryId",
                        column: x => x.CategoryId,
                        principalTable: "PfmCategories",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.SetNull);
                    table.ForeignKey(
                        name: "FK_PfmCategorizationRules_PfmSubcategories_SubcategoryId",
                        column: x => x.SubcategoryId,
                        principalTable: "PfmSubcategories",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.SetNull);
                    table.ForeignKey(
                        name: "FK_PfmCategorizationRules_Users_CreatedByAdminId",
                        column: x => x.CreatedByAdminId,
                        principalTable: "Users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.SetNull);
                });

            migrationBuilder.CreateTable(
                name: "PfmMerchants",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "TEXT", nullable: false),
                    Name = table.Column<string>(type: "TEXT", maxLength: 256, nullable: false),
                    MccCode = table.Column<string>(type: "TEXT", maxLength: 8, nullable: true),
                    DefaultCategoryId = table.Column<Guid>(type: "TEXT", nullable: true),
                    DefaultSubcategoryId = table.Column<Guid>(type: "TEXT", nullable: true),
                    DefaultConfidence = table.Column<int>(type: "INTEGER", nullable: false, defaultValue: 90),
                    IsActive = table.Column<bool>(type: "INTEGER", nullable: false, defaultValue: true),
                    TransactionCount = table.Column<int>(type: "INTEGER", nullable: false, defaultValue: 0),
                    CorrectionRate = table.Column<decimal>(type: "TEXT", precision: 5, scale: 2, nullable: false, defaultValue: 0m),
                    CreatedAt = table.Column<DateTimeOffset>(type: "TEXT", nullable: false),
                    UpdatedAt = table.Column<DateTimeOffset>(type: "TEXT", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_PfmMerchants", x => x.Id);
                    table.ForeignKey(
                        name: "FK_PfmMerchants_PfmCategories_DefaultCategoryId",
                        column: x => x.DefaultCategoryId,
                        principalTable: "PfmCategories",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.SetNull);
                    table.ForeignKey(
                        name: "FK_PfmMerchants_PfmSubcategories_DefaultSubcategoryId",
                        column: x => x.DefaultSubcategoryId,
                        principalTable: "PfmSubcategories",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.SetNull);
                });

            migrationBuilder.CreateTable(
                name: "PfmLearningSuggestions",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "TEXT", nullable: false),
                    Pattern = table.Column<string>(type: "TEXT", maxLength: 512, nullable: false),
                    CurrentCategoryId = table.Column<Guid>(type: "TEXT", nullable: true),
                    CurrentSubcategoryId = table.Column<Guid>(type: "TEXT", nullable: true),
                    SuggestedCategoryId = table.Column<Guid>(type: "TEXT", nullable: true),
                    SuggestedSubcategoryId = table.Column<Guid>(type: "TEXT", nullable: true),
                    OccurrenceCount = table.Column<int>(type: "INTEGER", nullable: false, defaultValue: 0),
                    SuggestedConfidence = table.Column<int>(type: "INTEGER", nullable: false, defaultValue: 85),
                    Status = table.Column<string>(type: "TEXT", nullable: false, defaultValue: "Pending"),
                    GeneratedRuleId = table.Column<Guid>(type: "TEXT", nullable: true),
                    DetectedAt = table.Column<DateTimeOffset>(type: "TEXT", nullable: false),
                    UpdatedAt = table.Column<DateTimeOffset>(type: "TEXT", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_PfmLearningSuggestions", x => x.Id);
                    table.ForeignKey(
                        name: "FK_PfmLearningSuggestions_PfmCategories_CurrentCategoryId",
                        column: x => x.CurrentCategoryId,
                        principalTable: "PfmCategories",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.SetNull);
                    table.ForeignKey(
                        name: "FK_PfmLearningSuggestions_PfmCategories_SuggestedCategoryId",
                        column: x => x.SuggestedCategoryId,
                        principalTable: "PfmCategories",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.SetNull);
                    table.ForeignKey(
                        name: "FK_PfmLearningSuggestions_PfmCategorizationRules_GeneratedRuleId",
                        column: x => x.GeneratedRuleId,
                        principalTable: "PfmCategorizationRules",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.SetNull);
                    table.ForeignKey(
                        name: "FK_PfmLearningSuggestions_PfmSubcategories_CurrentSubcategoryId",
                        column: x => x.CurrentSubcategoryId,
                        principalTable: "PfmSubcategories",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.SetNull);
                    table.ForeignKey(
                        name: "FK_PfmLearningSuggestions_PfmSubcategories_SuggestedSubcategoryId",
                        column: x => x.SuggestedSubcategoryId,
                        principalTable: "PfmSubcategories",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.SetNull);
                });

            migrationBuilder.CreateTable(
                name: "PfmRuleConditions",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "TEXT", nullable: false),
                    RuleId = table.Column<Guid>(type: "TEXT", nullable: false),
                    Field = table.Column<string>(type: "TEXT", nullable: false),
                    Operator = table.Column<string>(type: "TEXT", nullable: false),
                    Value = table.Column<string>(type: "TEXT", maxLength: 512, nullable: false),
                    LogicOperator = table.Column<string>(type: "TEXT", nullable: false, defaultValue: "And"),
                    OrderIndex = table.Column<int>(type: "INTEGER", nullable: false, defaultValue: 0)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_PfmRuleConditions", x => x.Id);
                    table.ForeignKey(
                        name: "FK_PfmRuleConditions_PfmCategorizationRules_RuleId",
                        column: x => x.RuleId,
                        principalTable: "PfmCategorizationRules",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "PfmMerchantAliases",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "TEXT", nullable: false),
                    MerchantId = table.Column<Guid>(type: "TEXT", nullable: false),
                    AliasText = table.Column<string>(type: "TEXT", maxLength: 256, nullable: false),
                    CreatedAt = table.Column<DateTimeOffset>(type: "TEXT", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_PfmMerchantAliases", x => x.Id);
                    table.ForeignKey(
                        name: "FK_PfmMerchantAliases_PfmMerchants_MerchantId",
                        column: x => x.MerchantId,
                        principalTable: "PfmMerchants",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "PfmTransactions",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "TEXT", nullable: false),
                    UserId = table.Column<Guid>(type: "TEXT", nullable: false),
                    MerchantId = table.Column<Guid>(type: "TEXT", nullable: true),
                    Narration = table.Column<string>(type: "TEXT", maxLength: 512, nullable: false),
                    Amount = table.Column<decimal>(type: "TEXT", precision: 18, scale: 3, nullable: false),
                    Currency = table.Column<string>(type: "TEXT", maxLength: 8, nullable: false, defaultValue: "OMR"),
                    TransactionType = table.Column<string>(type: "TEXT", nullable: false),
                    BalanceAfter = table.Column<decimal>(type: "TEXT", precision: 18, scale: 3, nullable: true),
                    TransactionDate = table.Column<DateTimeOffset>(type: "TEXT", nullable: false),
                    IsRecurring = table.Column<bool>(type: "INTEGER", nullable: false, defaultValue: false),
                    IsEssential = table.Column<bool>(type: "INTEGER", nullable: false, defaultValue: false),
                    Status = table.Column<string>(type: "TEXT", nullable: false, defaultValue: "Uncategorized"),
                    MccCode = table.Column<string>(type: "TEXT", maxLength: 8, nullable: true),
                    CreatedAt = table.Column<DateTimeOffset>(type: "TEXT", nullable: false),
                    UpdatedAt = table.Column<DateTimeOffset>(type: "TEXT", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_PfmTransactions", x => x.Id);
                    table.ForeignKey(
                        name: "FK_PfmTransactions_PfmMerchants_MerchantId",
                        column: x => x.MerchantId,
                        principalTable: "PfmMerchants",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.SetNull);
                    table.ForeignKey(
                        name: "FK_PfmTransactions_Users_UserId",
                        column: x => x.UserId,
                        principalTable: "Users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "PfmIntelligenceAlerts",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "TEXT", nullable: false),
                    RuleId = table.Column<Guid>(type: "TEXT", nullable: false),
                    UserId = table.Column<Guid>(type: "TEXT", nullable: false),
                    TransactionId = table.Column<Guid>(type: "TEXT", nullable: true),
                    AlertText = table.Column<string>(type: "TEXT", maxLength: 1024, nullable: false),
                    IsRead = table.Column<bool>(type: "INTEGER", nullable: false, defaultValue: false),
                    TriggeredAt = table.Column<DateTimeOffset>(type: "TEXT", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_PfmIntelligenceAlerts", x => x.Id);
                    table.ForeignKey(
                        name: "FK_PfmIntelligenceAlerts_PfmIntelligenceRules_RuleId",
                        column: x => x.RuleId,
                        principalTable: "PfmIntelligenceRules",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_PfmIntelligenceAlerts_PfmTransactions_TransactionId",
                        column: x => x.TransactionId,
                        principalTable: "PfmTransactions",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.SetNull);
                    table.ForeignKey(
                        name: "FK_PfmIntelligenceAlerts_Users_UserId",
                        column: x => x.UserId,
                        principalTable: "Users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "PfmTransactionCategories",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "TEXT", nullable: false),
                    TransactionId = table.Column<Guid>(type: "TEXT", nullable: false),
                    CategoryId = table.Column<Guid>(type: "TEXT", nullable: true),
                    SubcategoryId = table.Column<Guid>(type: "TEXT", nullable: true),
                    Confidence = table.Column<int>(type: "INTEGER", nullable: false, defaultValue: 0),
                    Source = table.Column<string>(type: "TEXT", nullable: false, defaultValue: "Uncategorized"),
                    MatchedRuleId = table.Column<Guid>(type: "TEXT", nullable: true),
                    ScoreMerchantMatch = table.Column<int>(type: "INTEGER", nullable: false, defaultValue: 0),
                    ScoreMccMatch = table.Column<int>(type: "INTEGER", nullable: false, defaultValue: 0),
                    ScoreNarrationMatch = table.Column<int>(type: "INTEGER", nullable: false, defaultValue: 0),
                    ScoreHistoricalMatch = table.Column<int>(type: "INTEGER", nullable: false, defaultValue: 0),
                    ScoreAmountPattern = table.Column<int>(type: "INTEGER", nullable: false, defaultValue: 0),
                    CategorizedAt = table.Column<DateTimeOffset>(type: "TEXT", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_PfmTransactionCategories", x => x.Id);
                    table.ForeignKey(
                        name: "FK_PfmTransactionCategories_PfmCategories_CategoryId",
                        column: x => x.CategoryId,
                        principalTable: "PfmCategories",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.SetNull);
                    table.ForeignKey(
                        name: "FK_PfmTransactionCategories_PfmCategorizationRules_MatchedRuleId",
                        column: x => x.MatchedRuleId,
                        principalTable: "PfmCategorizationRules",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.SetNull);
                    table.ForeignKey(
                        name: "FK_PfmTransactionCategories_PfmSubcategories_SubcategoryId",
                        column: x => x.SubcategoryId,
                        principalTable: "PfmSubcategories",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.SetNull);
                    table.ForeignKey(
                        name: "FK_PfmTransactionCategories_PfmTransactions_TransactionId",
                        column: x => x.TransactionId,
                        principalTable: "PfmTransactions",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "PfmUserCorrections",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "TEXT", nullable: false),
                    TransactionId = table.Column<Guid>(type: "TEXT", nullable: false),
                    UserId = table.Column<Guid>(type: "TEXT", nullable: false),
                    OriginalCategoryId = table.Column<Guid>(type: "TEXT", nullable: true),
                    OriginalSubcategoryId = table.Column<Guid>(type: "TEXT", nullable: true),
                    OriginalConfidence = table.Column<int>(type: "INTEGER", nullable: false, defaultValue: 0),
                    CorrectedCategoryId = table.Column<Guid>(type: "TEXT", nullable: true),
                    CorrectedSubcategoryId = table.Column<Guid>(type: "TEXT", nullable: true),
                    CorrectionDate = table.Column<DateTimeOffset>(type: "TEXT", nullable: false),
                    Status = table.Column<string>(type: "TEXT", nullable: false, defaultValue: "Pending"),
                    Scope = table.Column<string>(type: "TEXT", nullable: true),
                    ReviewedByAdminId = table.Column<Guid>(type: "TEXT", nullable: true),
                    ReviewedAt = table.Column<DateTimeOffset>(type: "TEXT", nullable: true),
                    GeneratedRuleId = table.Column<Guid>(type: "TEXT", nullable: true),
                    AdminNote = table.Column<string>(type: "TEXT", maxLength: 1024, nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_PfmUserCorrections", x => x.Id);
                    table.ForeignKey(
                        name: "FK_PfmUserCorrections_PfmCategories_CorrectedCategoryId",
                        column: x => x.CorrectedCategoryId,
                        principalTable: "PfmCategories",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.SetNull);
                    table.ForeignKey(
                        name: "FK_PfmUserCorrections_PfmCategories_OriginalCategoryId",
                        column: x => x.OriginalCategoryId,
                        principalTable: "PfmCategories",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.SetNull);
                    table.ForeignKey(
                        name: "FK_PfmUserCorrections_PfmCategorizationRules_GeneratedRuleId",
                        column: x => x.GeneratedRuleId,
                        principalTable: "PfmCategorizationRules",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.SetNull);
                    table.ForeignKey(
                        name: "FK_PfmUserCorrections_PfmSubcategories_CorrectedSubcategoryId",
                        column: x => x.CorrectedSubcategoryId,
                        principalTable: "PfmSubcategories",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.SetNull);
                    table.ForeignKey(
                        name: "FK_PfmUserCorrections_PfmSubcategories_OriginalSubcategoryId",
                        column: x => x.OriginalSubcategoryId,
                        principalTable: "PfmSubcategories",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.SetNull);
                    table.ForeignKey(
                        name: "FK_PfmUserCorrections_PfmTransactions_TransactionId",
                        column: x => x.TransactionId,
                        principalTable: "PfmTransactions",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_PfmUserCorrections_Users_ReviewedByAdminId",
                        column: x => x.ReviewedByAdminId,
                        principalTable: "Users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.SetNull);
                    table.ForeignKey(
                        name: "FK_PfmUserCorrections_Users_UserId",
                        column: x => x.UserId,
                        principalTable: "Users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateIndex(
                name: "IX_PfmAuditLogs_AdminUserId",
                table: "PfmAuditLogs",
                column: "AdminUserId");

            migrationBuilder.CreateIndex(
                name: "IX_PfmAuditLogs_EntityType_EntityId",
                table: "PfmAuditLogs",
                columns: new[] { "EntityType", "EntityId" });

            migrationBuilder.CreateIndex(
                name: "IX_PfmAuditLogs_Timestamp",
                table: "PfmAuditLogs",
                column: "Timestamp");

            migrationBuilder.CreateIndex(
                name: "IX_PfmCategories_DisplayOrder",
                table: "PfmCategories",
                column: "DisplayOrder");

            migrationBuilder.CreateIndex(
                name: "IX_PfmCategories_Name",
                table: "PfmCategories",
                column: "Name",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_PfmCategorizationRules_CategoryId",
                table: "PfmCategorizationRules",
                column: "CategoryId");

            migrationBuilder.CreateIndex(
                name: "IX_PfmCategorizationRules_CreatedByAdminId",
                table: "PfmCategorizationRules",
                column: "CreatedByAdminId");

            migrationBuilder.CreateIndex(
                name: "IX_PfmCategorizationRules_IsLearnedFromCorrection",
                table: "PfmCategorizationRules",
                column: "IsLearnedFromCorrection");

            migrationBuilder.CreateIndex(
                name: "IX_PfmCategorizationRules_Priority",
                table: "PfmCategorizationRules",
                column: "Priority");

            migrationBuilder.CreateIndex(
                name: "IX_PfmCategorizationRules_Status",
                table: "PfmCategorizationRules",
                column: "Status");

            migrationBuilder.CreateIndex(
                name: "IX_PfmCategorizationRules_SubcategoryId",
                table: "PfmCategorizationRules",
                column: "SubcategoryId");

            migrationBuilder.CreateIndex(
                name: "IX_PfmConfidenceBands_BandName",
                table: "PfmConfidenceBands",
                column: "BandName",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_PfmConfidenceWeights_Signal",
                table: "PfmConfidenceWeights",
                column: "Signal",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_PfmIntelligenceAlerts_IsRead",
                table: "PfmIntelligenceAlerts",
                column: "IsRead");

            migrationBuilder.CreateIndex(
                name: "IX_PfmIntelligenceAlerts_RuleId",
                table: "PfmIntelligenceAlerts",
                column: "RuleId");

            migrationBuilder.CreateIndex(
                name: "IX_PfmIntelligenceAlerts_TransactionId",
                table: "PfmIntelligenceAlerts",
                column: "TransactionId");

            migrationBuilder.CreateIndex(
                name: "IX_PfmIntelligenceAlerts_TriggeredAt",
                table: "PfmIntelligenceAlerts",
                column: "TriggeredAt");

            migrationBuilder.CreateIndex(
                name: "IX_PfmIntelligenceAlerts_UserId",
                table: "PfmIntelligenceAlerts",
                column: "UserId");

            migrationBuilder.CreateIndex(
                name: "IX_PfmIntelligenceAlerts_UserId_IsRead",
                table: "PfmIntelligenceAlerts",
                columns: new[] { "UserId", "IsRead" });

            migrationBuilder.CreateIndex(
                name: "IX_PfmIntelligenceRuleParams_RuleId_ParamKey",
                table: "PfmIntelligenceRuleParams",
                columns: new[] { "RuleId", "ParamKey" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_PfmIntelligenceRules_RuleType",
                table: "PfmIntelligenceRules",
                column: "RuleType");

            migrationBuilder.CreateIndex(
                name: "IX_PfmIntelligenceRules_Status",
                table: "PfmIntelligenceRules",
                column: "Status");

            migrationBuilder.CreateIndex(
                name: "IX_PfmLearningSuggestions_CurrentCategoryId",
                table: "PfmLearningSuggestions",
                column: "CurrentCategoryId");

            migrationBuilder.CreateIndex(
                name: "IX_PfmLearningSuggestions_CurrentSubcategoryId",
                table: "PfmLearningSuggestions",
                column: "CurrentSubcategoryId");

            migrationBuilder.CreateIndex(
                name: "IX_PfmLearningSuggestions_GeneratedRuleId",
                table: "PfmLearningSuggestions",
                column: "GeneratedRuleId");

            migrationBuilder.CreateIndex(
                name: "IX_PfmLearningSuggestions_OccurrenceCount",
                table: "PfmLearningSuggestions",
                column: "OccurrenceCount");

            migrationBuilder.CreateIndex(
                name: "IX_PfmLearningSuggestions_Pattern",
                table: "PfmLearningSuggestions",
                column: "Pattern");

            migrationBuilder.CreateIndex(
                name: "IX_PfmLearningSuggestions_Status",
                table: "PfmLearningSuggestions",
                column: "Status");

            migrationBuilder.CreateIndex(
                name: "IX_PfmLearningSuggestions_SuggestedCategoryId",
                table: "PfmLearningSuggestions",
                column: "SuggestedCategoryId");

            migrationBuilder.CreateIndex(
                name: "IX_PfmLearningSuggestions_SuggestedSubcategoryId",
                table: "PfmLearningSuggestions",
                column: "SuggestedSubcategoryId");

            migrationBuilder.CreateIndex(
                name: "IX_PfmMerchantAliases_AliasText",
                table: "PfmMerchantAliases",
                column: "AliasText",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_PfmMerchantAliases_MerchantId",
                table: "PfmMerchantAliases",
                column: "MerchantId");

            migrationBuilder.CreateIndex(
                name: "IX_PfmMerchants_DefaultCategoryId",
                table: "PfmMerchants",
                column: "DefaultCategoryId");

            migrationBuilder.CreateIndex(
                name: "IX_PfmMerchants_DefaultSubcategoryId",
                table: "PfmMerchants",
                column: "DefaultSubcategoryId");

            migrationBuilder.CreateIndex(
                name: "IX_PfmMerchants_IsActive",
                table: "PfmMerchants",
                column: "IsActive");

            migrationBuilder.CreateIndex(
                name: "IX_PfmMerchants_MccCode",
                table: "PfmMerchants",
                column: "MccCode");

            migrationBuilder.CreateIndex(
                name: "IX_PfmMerchants_Name",
                table: "PfmMerchants",
                column: "Name");

            migrationBuilder.CreateIndex(
                name: "IX_PfmRuleConditions_RuleId_OrderIndex",
                table: "PfmRuleConditions",
                columns: new[] { "RuleId", "OrderIndex" });

            migrationBuilder.CreateIndex(
                name: "IX_PfmSubcategories_CategoryId_Name",
                table: "PfmSubcategories",
                columns: new[] { "CategoryId", "Name" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_PfmSubcategories_DisplayOrder",
                table: "PfmSubcategories",
                column: "DisplayOrder");

            migrationBuilder.CreateIndex(
                name: "IX_PfmTransactionCategories_CategoryId",
                table: "PfmTransactionCategories",
                column: "CategoryId");

            migrationBuilder.CreateIndex(
                name: "IX_PfmTransactionCategories_Confidence",
                table: "PfmTransactionCategories",
                column: "Confidence");

            migrationBuilder.CreateIndex(
                name: "IX_PfmTransactionCategories_MatchedRuleId",
                table: "PfmTransactionCategories",
                column: "MatchedRuleId");

            migrationBuilder.CreateIndex(
                name: "IX_PfmTransactionCategories_Source",
                table: "PfmTransactionCategories",
                column: "Source");

            migrationBuilder.CreateIndex(
                name: "IX_PfmTransactionCategories_SubcategoryId",
                table: "PfmTransactionCategories",
                column: "SubcategoryId");

            migrationBuilder.CreateIndex(
                name: "IX_PfmTransactionCategories_TransactionId",
                table: "PfmTransactionCategories",
                column: "TransactionId",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_PfmTransactions_MerchantId",
                table: "PfmTransactions",
                column: "MerchantId");

            migrationBuilder.CreateIndex(
                name: "IX_PfmTransactions_Status",
                table: "PfmTransactions",
                column: "Status");

            migrationBuilder.CreateIndex(
                name: "IX_PfmTransactions_TransactionDate",
                table: "PfmTransactions",
                column: "TransactionDate");

            migrationBuilder.CreateIndex(
                name: "IX_PfmTransactions_TransactionType",
                table: "PfmTransactions",
                column: "TransactionType");

            migrationBuilder.CreateIndex(
                name: "IX_PfmTransactions_UserId",
                table: "PfmTransactions",
                column: "UserId");

            migrationBuilder.CreateIndex(
                name: "IX_PfmUserCorrections_CorrectedCategoryId",
                table: "PfmUserCorrections",
                column: "CorrectedCategoryId");

            migrationBuilder.CreateIndex(
                name: "IX_PfmUserCorrections_CorrectedSubcategoryId",
                table: "PfmUserCorrections",
                column: "CorrectedSubcategoryId");

            migrationBuilder.CreateIndex(
                name: "IX_PfmUserCorrections_CorrectionDate",
                table: "PfmUserCorrections",
                column: "CorrectionDate");

            migrationBuilder.CreateIndex(
                name: "IX_PfmUserCorrections_GeneratedRuleId",
                table: "PfmUserCorrections",
                column: "GeneratedRuleId");

            migrationBuilder.CreateIndex(
                name: "IX_PfmUserCorrections_OriginalCategoryId",
                table: "PfmUserCorrections",
                column: "OriginalCategoryId");

            migrationBuilder.CreateIndex(
                name: "IX_PfmUserCorrections_OriginalSubcategoryId",
                table: "PfmUserCorrections",
                column: "OriginalSubcategoryId");

            migrationBuilder.CreateIndex(
                name: "IX_PfmUserCorrections_ReviewedByAdminId",
                table: "PfmUserCorrections",
                column: "ReviewedByAdminId");

            migrationBuilder.CreateIndex(
                name: "IX_PfmUserCorrections_Status",
                table: "PfmUserCorrections",
                column: "Status");

            migrationBuilder.CreateIndex(
                name: "IX_PfmUserCorrections_TransactionId",
                table: "PfmUserCorrections",
                column: "TransactionId");

            migrationBuilder.CreateIndex(
                name: "IX_PfmUserCorrections_UserId",
                table: "PfmUserCorrections",
                column: "UserId");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "PfmAuditLogs");

            migrationBuilder.DropTable(
                name: "PfmConfidenceBands");

            migrationBuilder.DropTable(
                name: "PfmConfidenceWeights");

            migrationBuilder.DropTable(
                name: "PfmIntelligenceAlerts");

            migrationBuilder.DropTable(
                name: "PfmIntelligenceRuleParams");

            migrationBuilder.DropTable(
                name: "PfmLearningSuggestions");

            migrationBuilder.DropTable(
                name: "PfmMerchantAliases");

            migrationBuilder.DropTable(
                name: "PfmRuleConditions");

            migrationBuilder.DropTable(
                name: "PfmTransactionCategories");

            migrationBuilder.DropTable(
                name: "PfmUserCorrections");

            migrationBuilder.DropTable(
                name: "PfmIntelligenceRules");

            migrationBuilder.DropTable(
                name: "PfmCategorizationRules");

            migrationBuilder.DropTable(
                name: "PfmTransactions");

            migrationBuilder.DropTable(
                name: "PfmMerchants");

            migrationBuilder.DropTable(
                name: "PfmSubcategories");

            migrationBuilder.DropTable(
                name: "PfmCategories");

            migrationBuilder.AlterColumn<string>(
                name: "AccessStatus",
                table: "Users",
                type: "TEXT",
                nullable: false,
                oldClrType: typeof(string),
                oldType: "TEXT",
                oldDefaultValue: "Pending");
        }
    }
}
