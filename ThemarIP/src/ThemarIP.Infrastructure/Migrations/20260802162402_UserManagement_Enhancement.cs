using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace ThemarIP.Infrastructure.Migrations
{
    /// <inheritdoc />
    public partial class UserManagement_Enhancement : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_KycSubmissions_AdminUsers_ReviewedBy",
                table: "KycSubmissions");

            migrationBuilder.DropTable(
                name: "AdminAuditLogs");

            migrationBuilder.DropTable(
                name: "AdminUsers");

            migrationBuilder.DropIndex(
                name: "IX_KycSubmissions_Status",
                table: "KycSubmissions");

            migrationBuilder.DropColumn(
                name: "KycStatus",
                table: "Users");

            migrationBuilder.DropColumn(
                name: "Status",
                table: "Users");

            migrationBuilder.DropColumn(
                name: "CreatedAt",
                table: "KycSubmissions");

            migrationBuilder.DropColumn(
                name: "IdCardBack",
                table: "KycSubmissions");

            migrationBuilder.DropColumn(
                name: "IdCardFront",
                table: "KycSubmissions");

            migrationBuilder.DropColumn(
                name: "Selfie",
                table: "KycSubmissions");

            migrationBuilder.RenameColumn(
                name: "UpdatedAt",
                table: "Users",
                newName: "AccessStatus");

            migrationBuilder.RenameColumn(
                name: "UpdatedAt",
                table: "KycSubmissions",
                newName: "SubmittedAt");

            migrationBuilder.RenameColumn(
                name: "ReviewedBy",
                table: "KycSubmissions",
                newName: "ReviewedByAdminId");

            migrationBuilder.RenameColumn(
                name: "RejectionReason",
                table: "KycSubmissions",
                newName: "ReasonNote");

            migrationBuilder.RenameIndex(
                name: "IX_KycSubmissions_ReviewedBy",
                table: "KycSubmissions",
                newName: "IX_KycSubmissions_ReviewedByAdminId");

            migrationBuilder.AddColumn<string>(
                name: "AccessReasonCode",
                table: "Users",
                type: "TEXT",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "AccessReasonNote",
                table: "Users",
                type: "TEXT",
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "TrustScore",
                table: "Users",
                type: "INTEGER",
                nullable: false,
                defaultValue: 0);

            migrationBuilder.AddColumn<string>(
                name: "DocumentReferences",
                table: "KycSubmissions",
                type: "TEXT",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "ReasonCode",
                table: "KycSubmissions",
                type: "TEXT",
                nullable: true);

            migrationBuilder.CreateTable(
                name: "AuditLogs",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "TEXT", nullable: false),
                    AdminUserId = table.Column<Guid>(type: "TEXT", nullable: false),
                    TargetUserId = table.Column<Guid>(type: "TEXT", nullable: false),
                    ActionType = table.Column<string>(type: "TEXT", nullable: false),
                    ReasonCode = table.Column<string>(type: "TEXT", nullable: true),
                    ReasonNote = table.Column<string>(type: "TEXT", nullable: true),
                    CreatedAt = table.Column<DateTimeOffset>(type: "TEXT", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_AuditLogs", x => x.Id);
                    table.ForeignKey(
                        name: "FK_AuditLogs_Users_AdminUserId",
                        column: x => x.AdminUserId,
                        principalTable: "Users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_AuditLogs_Users_TargetUserId",
                        column: x => x.TargetUserId,
                        principalTable: "Users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "IX_AuditLogs_AdminUserId",
                table: "AuditLogs",
                column: "AdminUserId");

            migrationBuilder.CreateIndex(
                name: "IX_AuditLogs_TargetUserId",
                table: "AuditLogs",
                column: "TargetUserId");

            migrationBuilder.AddForeignKey(
                name: "FK_KycSubmissions_Users_ReviewedByAdminId",
                table: "KycSubmissions",
                column: "ReviewedByAdminId",
                principalTable: "Users",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_KycSubmissions_Users_ReviewedByAdminId",
                table: "KycSubmissions");

            migrationBuilder.DropTable(
                name: "AuditLogs");

            migrationBuilder.DropColumn(
                name: "AccessReasonCode",
                table: "Users");

            migrationBuilder.DropColumn(
                name: "AccessReasonNote",
                table: "Users");

            migrationBuilder.DropColumn(
                name: "TrustScore",
                table: "Users");

            migrationBuilder.DropColumn(
                name: "DocumentReferences",
                table: "KycSubmissions");

            migrationBuilder.DropColumn(
                name: "ReasonCode",
                table: "KycSubmissions");

            migrationBuilder.RenameColumn(
                name: "AccessStatus",
                table: "Users",
                newName: "UpdatedAt");

            migrationBuilder.RenameColumn(
                name: "SubmittedAt",
                table: "KycSubmissions",
                newName: "UpdatedAt");

            migrationBuilder.RenameColumn(
                name: "ReviewedByAdminId",
                table: "KycSubmissions",
                newName: "ReviewedBy");

            migrationBuilder.RenameColumn(
                name: "ReasonNote",
                table: "KycSubmissions",
                newName: "RejectionReason");

            migrationBuilder.RenameIndex(
                name: "IX_KycSubmissions_ReviewedByAdminId",
                table: "KycSubmissions",
                newName: "IX_KycSubmissions_ReviewedBy");

            migrationBuilder.AddColumn<string>(
                name: "KycStatus",
                table: "Users",
                type: "TEXT",
                nullable: false,
                defaultValue: "");

            migrationBuilder.AddColumn<string>(
                name: "Status",
                table: "Users",
                type: "TEXT",
                nullable: false,
                defaultValue: "");

            migrationBuilder.AddColumn<DateTimeOffset>(
                name: "CreatedAt",
                table: "KycSubmissions",
                type: "TEXT",
                nullable: false,
                defaultValue: new DateTimeOffset(new DateTime(1, 1, 1, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)));

            migrationBuilder.AddColumn<byte[]>(
                name: "IdCardBack",
                table: "KycSubmissions",
                type: "BLOB",
                nullable: true);

            migrationBuilder.AddColumn<byte[]>(
                name: "IdCardFront",
                table: "KycSubmissions",
                type: "BLOB",
                nullable: true);

            migrationBuilder.AddColumn<byte[]>(
                name: "Selfie",
                table: "KycSubmissions",
                type: "BLOB",
                nullable: true);

            migrationBuilder.CreateTable(
                name: "AdminUsers",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "TEXT", nullable: false),
                    CreatedAt = table.Column<DateTimeOffset>(type: "TEXT", nullable: false),
                    Email = table.Column<string>(type: "TEXT", maxLength: 256, nullable: false),
                    LastLogin = table.Column<DateTimeOffset>(type: "TEXT", nullable: true),
                    Name = table.Column<string>(type: "TEXT", nullable: false),
                    PasswordHash = table.Column<string>(type: "TEXT", nullable: false),
                    Role = table.Column<string>(type: "TEXT", nullable: false),
                    Status = table.Column<string>(type: "TEXT", nullable: false),
                    UpdatedAt = table.Column<DateTimeOffset>(type: "TEXT", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_AdminUsers", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "AdminAuditLogs",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "TEXT", nullable: false),
                    AdminId = table.Column<Guid>(type: "TEXT", nullable: false),
                    TargetUserId = table.Column<Guid>(type: "TEXT", nullable: true),
                    Action = table.Column<string>(type: "TEXT", nullable: false),
                    CreatedAt = table.Column<DateTimeOffset>(type: "TEXT", nullable: false),
                    Details = table.Column<string>(type: "TEXT", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_AdminAuditLogs", x => x.Id);
                    table.ForeignKey(
                        name: "FK_AdminAuditLogs_AdminUsers_AdminId",
                        column: x => x.AdminId,
                        principalTable: "AdminUsers",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_AdminAuditLogs_Users_TargetUserId",
                        column: x => x.TargetUserId,
                        principalTable: "Users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.SetNull);
                });

            migrationBuilder.CreateIndex(
                name: "IX_KycSubmissions_Status",
                table: "KycSubmissions",
                column: "Status");

            migrationBuilder.CreateIndex(
                name: "IX_AdminAuditLogs_AdminId",
                table: "AdminAuditLogs",
                column: "AdminId");

            migrationBuilder.CreateIndex(
                name: "IX_AdminAuditLogs_TargetUserId",
                table: "AdminAuditLogs",
                column: "TargetUserId");

            migrationBuilder.CreateIndex(
                name: "IX_AdminUsers_Email",
                table: "AdminUsers",
                column: "Email",
                unique: true);

            migrationBuilder.AddForeignKey(
                name: "FK_KycSubmissions_AdminUsers_ReviewedBy",
                table: "KycSubmissions",
                column: "ReviewedBy",
                principalTable: "AdminUsers",
                principalColumn: "Id",
                onDelete: ReferentialAction.SetNull);
        }
    }
}
