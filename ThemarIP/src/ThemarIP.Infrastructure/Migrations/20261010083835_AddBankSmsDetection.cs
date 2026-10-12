using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace ThemarIP.Infrastructure.Migrations
{
    /// <inheritdoc />
    public partial class AddBankSmsDetection : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            // Additive only: new SMS tables. Existing tables are intentionally untouched.
            migrationBuilder.CreateTable(
                name: "BankSmsRules",
                columns: table => new
                {
                    Id = table.Column<string>(type: "TEXT", nullable: false),
                    BankName = table.Column<string>(type: "TEXT", maxLength: 128, nullable: false),
                    BankCode = table.Column<string>(type: "TEXT", maxLength: 64, nullable: false),
                    SenderIds = table.Column<string>(type: "TEXT", maxLength: 512, nullable: false),
                    Pattern = table.Column<string>(type: "TEXT", maxLength: 4000, nullable: false),
                    FieldMappings = table.Column<string>(type: "TEXT", nullable: false),
                    DebitKeywords = table.Column<string>(type: "TEXT", nullable: false),
                    CreditKeywords = table.Column<string>(type: "TEXT", nullable: false),
                    DefaultType = table.Column<string>(type: "TEXT", maxLength: 16, nullable: false),
                    DefaultCurrency = table.Column<string>(type: "TEXT", maxLength: 8, nullable: false),
                    DateFormats = table.Column<string>(type: "TEXT", nullable: false),
                    SampleMessage = table.Column<string>(type: "TEXT", nullable: false),
                    IsActive = table.Column<bool>(type: "INTEGER", nullable: false),
                    Version = table.Column<int>(type: "INTEGER", nullable: false),
                    CreatedAt = table.Column<string>(type: "TEXT", nullable: false),
                    UpdatedAt = table.Column<string>(type: "TEXT", nullable: false),
                    UpdatedBy = table.Column<string>(type: "TEXT", maxLength: 256, nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_BankSmsRules", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "BankSmsRuleVersions",
                columns: table => new
                {
                    Id = table.Column<string>(type: "TEXT", nullable: false),
                    RuleId = table.Column<string>(type: "TEXT", nullable: false),
                    Version = table.Column<int>(type: "INTEGER", nullable: false),
                    Snapshot = table.Column<string>(type: "TEXT", nullable: false),
                    ChangedBy = table.Column<string>(type: "TEXT", maxLength: 256, nullable: true),
                    CreatedAt = table.Column<string>(type: "TEXT", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_BankSmsRuleVersions", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "SmsProcessingLogs",
                columns: table => new
                {
                    Id = table.Column<string>(type: "TEXT", nullable: false),
                    UserId = table.Column<string>(type: "TEXT", nullable: true),
                    Sender = table.Column<string>(type: "TEXT", maxLength: 64, nullable: false),
                    RawMessage = table.Column<string>(type: "TEXT", nullable: false),
                    MessageHash = table.Column<string>(type: "TEXT", maxLength: 64, nullable: false),
                    RuleId = table.Column<string>(type: "TEXT", nullable: true),
                    RuleVersion = table.Column<int>(type: "INTEGER", nullable: true),
                    Status = table.Column<string>(type: "TEXT", maxLength: 32, nullable: false),
                    Details = table.Column<string>(type: "TEXT", nullable: false),
                    ExtractedJson = table.Column<string>(type: "TEXT", nullable: true),
                    Reference = table.Column<string>(type: "TEXT", maxLength: 128, nullable: true),
                    TransactionId = table.Column<string>(type: "TEXT", nullable: true),
                    ReceivedAt = table.Column<string>(type: "TEXT", nullable: false),
                    CreatedAt = table.Column<string>(type: "TEXT", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_SmsProcessingLogs", x => x.Id);
                });

            migrationBuilder.CreateIndex(
                name: "IX_BankSmsRules_IsActive",
                table: "BankSmsRules",
                column: "IsActive");

            migrationBuilder.CreateIndex(
                name: "IX_BankSmsRuleVersions_RuleId_Version",
                table: "BankSmsRuleVersions",
                columns: new[] { "RuleId", "Version" });

            migrationBuilder.CreateIndex(
                name: "IX_SmsProcessingLogs_CreatedAt",
                table: "SmsProcessingLogs",
                column: "CreatedAt");

            migrationBuilder.CreateIndex(
                name: "IX_SmsProcessingLogs_UserId_MessageHash",
                table: "SmsProcessingLogs",
                columns: new[] { "UserId", "MessageHash" });

            migrationBuilder.CreateIndex(
                name: "IX_SmsProcessingLogs_UserId_RuleId_Reference",
                table: "SmsProcessingLogs",
                columns: new[] { "UserId", "RuleId", "Reference" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "BankSmsRules");

            migrationBuilder.DropTable(
                name: "BankSmsRuleVersions");

            migrationBuilder.DropTable(
                name: "SmsProcessingLogs");
        }
    }
}
