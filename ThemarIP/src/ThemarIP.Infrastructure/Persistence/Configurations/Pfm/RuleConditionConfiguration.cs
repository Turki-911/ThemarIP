using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using ThemarIP.Domain.Entities.Pfm;
using ThemarIP.Domain.Enums.Pfm;

namespace ThemarIP.Infrastructure.Persistence.Configurations.Pfm;

public class RuleConditionConfiguration : IEntityTypeConfiguration<PfmRuleCondition>
{
    public void Configure(EntityTypeBuilder<PfmRuleCondition> builder)
    {
        builder.ToTable("PfmRuleConditions");
        builder.HasKey(e => e.Id);

        builder.Property(e => e.Field).HasConversion<string>();
        builder.Property(e => e.Operator).HasConversion<string>();
        builder.Property(e => e.Value).IsRequired().HasMaxLength(512);
        builder.Property(e => e.LogicOperator).HasConversion<string>().HasDefaultValue(RuleConditionLogic.And);
        builder.Property(e => e.OrderIndex).HasDefaultValue(0);

        builder.HasOne(e => e.Rule)
            .WithMany(r => r.Conditions)
            .HasForeignKey(e => e.RuleId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.HasIndex(e => new { e.RuleId, e.OrderIndex });
    }
}
