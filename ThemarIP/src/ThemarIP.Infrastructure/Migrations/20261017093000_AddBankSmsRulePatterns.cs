using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;
using ThemarIP.Infrastructure.Persistence;

#nullable disable

namespace ThemarIP.Infrastructure.Migrations
{
    /// <summary>
    /// Additive only: one nullable column holding the list of message patterns grouped under a bank rule.
    /// Existing rows keep working unchanged (NULL = use the single Pattern column).
    /// </summary>
    [DbContext(typeof(ApplicationDbContext))]
    [Migration("20261017093000_AddBankSmsRulePatterns")]
    public partial class AddBankSmsRulePatterns : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "Patterns",
                table: "BankSmsRules",
                type: "TEXT",
                nullable: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "Patterns",
                table: "BankSmsRules");
        }
    }
}
