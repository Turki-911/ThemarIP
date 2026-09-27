using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using ThemarIP.Domain.Entities.Pfm;

namespace ThemarIP.Infrastructure.Persistence.Configurations.Pfm;

public class IntelligenceAlertConfiguration : IEntityTypeConfiguration<PfmIntelligenceAlert>
{
    public void Configure(EntityTypeBuilder<PfmIntelligenceAlert> builder)
    {
        builder.ToTable("PfmIntelligenceAlerts");
        builder.HasKey(e => e.Id);

        builder.Property(e => e.AlertText).IsRequired().HasMaxLength(1024);
        builder.Property(e => e.IsRead).HasDefaultValue(false);

        builder.HasOne(e => e.Rule)
            .WithMany(r => r.Alerts)
            .HasForeignKey(e => e.RuleId)
            .OnDelete(DeleteBehavior.Restrict);

        builder.HasOne(e => e.User)
            .WithMany()
            .HasForeignKey(e => e.UserId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.HasOne(e => e.Transaction)
            .WithMany()
            .HasForeignKey(e => e.TransactionId)
            .OnDelete(DeleteBehavior.SetNull);

        builder.HasIndex(e => e.UserId);
        builder.HasIndex(e => e.IsRead);
        builder.HasIndex(e => e.TriggeredAt);
        builder.HasIndex(e => new { e.UserId, e.IsRead });
    }
}
