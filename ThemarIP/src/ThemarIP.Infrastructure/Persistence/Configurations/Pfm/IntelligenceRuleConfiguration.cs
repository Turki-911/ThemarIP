using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using ThemarIP.Domain.Entities.Pfm;
using ThemarIP.Domain.Enums.Pfm;

namespace ThemarIP.Infrastructure.Persistence.Configurations.Pfm;

public class IntelligenceRuleConfiguration : IEntityTypeConfiguration<PfmIntelligenceRule>
{
    public void Configure(EntityTypeBuilder<PfmIntelligenceRule> builder)
    {
        builder.ToTable("PfmIntelligenceRules");
        builder.HasKey(e => e.Id);

        builder.Property(e => e.Name).IsRequired().HasMaxLength(256);
        builder.Property(e => e.RuleType).HasConversion<string>();
        builder.Property(e => e.Status).HasConversion<string>().HasDefaultValue(IntelligenceRuleStatus.Active);
        builder.Property(e => e.InsightTemplate).IsRequired().HasMaxLength(1024);
        builder.Property(e => e.Icon).HasMaxLength(64).HasDefaultValue("zap");
        builder.Property(e => e.IconColor).HasMaxLength(16).HasDefaultValue("#3B82F6");
        builder.Property(e => e.FireCount).HasDefaultValue(0);

        builder.HasIndex(e => e.Status);
        builder.HasIndex(e => e.RuleType);
    }
}
