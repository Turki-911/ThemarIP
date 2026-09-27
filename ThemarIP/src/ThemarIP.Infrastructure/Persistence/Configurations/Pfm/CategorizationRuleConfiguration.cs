using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using ThemarIP.Domain.Entities.Pfm;
using ThemarIP.Domain.Enums.Pfm;

namespace ThemarIP.Infrastructure.Persistence.Configurations.Pfm;

public class CategorizationRuleConfiguration : IEntityTypeConfiguration<PfmCategorizationRule>
{
    public void Configure(EntityTypeBuilder<PfmCategorizationRule> builder)
    {
        builder.ToTable("PfmCategorizationRules");
        builder.HasKey(e => e.Id);

        builder.Property(e => e.Name).IsRequired().HasMaxLength(256);
        builder.Property(e => e.Status).HasConversion<string>().HasDefaultValue(RuleStatus.Active);
        builder.Property(e => e.Confidence).HasDefaultValue(85);
        builder.Property(e => e.Priority).HasDefaultValue(50);
        builder.Property(e => e.MatchCount).HasDefaultValue(0);
        builder.Property(e => e.IsLearnedFromCorrection).HasDefaultValue(false);

        builder.HasOne(e => e.Category)
            .WithMany(c => c.Rules)
            .HasForeignKey(e => e.CategoryId)
            .OnDelete(DeleteBehavior.SetNull);

        builder.HasOne(e => e.Subcategory)
            .WithMany(s => s.Rules)
            .HasForeignKey(e => e.SubcategoryId)
            .OnDelete(DeleteBehavior.SetNull);

        builder.HasOne(e => e.CreatedByAdmin)
            .WithMany()
            .HasForeignKey(e => e.CreatedByAdminId)
            .OnDelete(DeleteBehavior.SetNull);

        builder.HasIndex(e => e.Priority);
        builder.HasIndex(e => e.Status);
        builder.HasIndex(e => e.IsLearnedFromCorrection);
    }
}
