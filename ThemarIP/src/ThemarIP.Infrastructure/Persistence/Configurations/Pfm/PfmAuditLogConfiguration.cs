using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using ThemarIP.Domain.Entities.Pfm;
using ThemarIP.Domain.Enums.Pfm;

namespace ThemarIP.Infrastructure.Persistence.Configurations.Pfm;

public class PfmAuditLogConfiguration : IEntityTypeConfiguration<PfmAuditLog>
{
    public void Configure(EntityTypeBuilder<PfmAuditLog> builder)
    {
        builder.ToTable("PfmAuditLogs");
        builder.HasKey(e => e.Id);

        builder.Property(e => e.ActionType).HasConversion<string>();
        builder.Property(e => e.EntityType).IsRequired().HasMaxLength(128);
        builder.Property(e => e.EntityId).IsRequired().HasMaxLength(128);
        builder.Property(e => e.Description).IsRequired().HasMaxLength(1024);

        // JSON snapshots — no max length constraint; SQLite TEXT is unlimited
        builder.Property(e => e.OldValueJson);
        builder.Property(e => e.NewValueJson);

        builder.HasOne(e => e.AdminUser)
            .WithMany()
            .HasForeignKey(e => e.AdminUserId)
            .OnDelete(DeleteBehavior.Restrict);

        builder.HasIndex(e => e.AdminUserId);
        builder.HasIndex(e => e.Timestamp);
        builder.HasIndex(e => new { e.EntityType, e.EntityId });
    }
}
