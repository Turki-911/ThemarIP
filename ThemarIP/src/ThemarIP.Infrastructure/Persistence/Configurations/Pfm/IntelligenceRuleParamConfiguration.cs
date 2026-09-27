using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using ThemarIP.Domain.Entities.Pfm;
using ThemarIP.Domain.Enums.Pfm;

namespace ThemarIP.Infrastructure.Persistence.Configurations.Pfm;

public class IntelligenceRuleParamConfiguration : IEntityTypeConfiguration<PfmIntelligenceRuleParam>
{
    public void Configure(EntityTypeBuilder<PfmIntelligenceRuleParam> builder)
    {
        builder.ToTable("PfmIntelligenceRuleParams");
        builder.HasKey(e => e.Id);

        builder.Property(e => e.ParamKey).IsRequired().HasMaxLength(128);
        builder.Property(e => e.ParamValue).IsRequired().HasMaxLength(512);
        builder.Property(e => e.ParamType).HasConversion<string>().HasDefaultValue(IntelligenceRuleParamType.String);

        builder.HasOne(e => e.Rule)
            .WithMany(r => r.Params)
            .HasForeignKey(e => e.RuleId)
            .OnDelete(DeleteBehavior.Cascade);

        // Param key must be unique within a rule
        builder.HasIndex(e => new { e.RuleId, e.ParamKey }).IsUnique();
    }
}
