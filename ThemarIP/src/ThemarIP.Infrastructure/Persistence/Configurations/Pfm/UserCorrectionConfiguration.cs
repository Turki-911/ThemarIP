using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using ThemarIP.Domain.Entities.Pfm;
using ThemarIP.Domain.Enums.Pfm;

namespace ThemarIP.Infrastructure.Persistence.Configurations.Pfm;

public class UserCorrectionConfiguration : IEntityTypeConfiguration<PfmUserCorrection>
{
    public void Configure(EntityTypeBuilder<PfmUserCorrection> builder)
    {
        builder.ToTable("PfmUserCorrections");
        builder.HasKey(e => e.Id);

        builder.Property(e => e.Status).HasConversion<string>().HasDefaultValue(CorrectionStatus.Pending);
        builder.Property(e => e.Scope).HasConversion<string>();
        builder.Property(e => e.OriginalConfidence).HasDefaultValue(0);
        builder.Property(e => e.AdminNote).HasMaxLength(1024);

        builder.HasOne(e => e.Transaction)
            .WithMany(t => t.Corrections)
            .HasForeignKey(e => e.TransactionId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.HasOne(e => e.User)
            .WithMany()
            .HasForeignKey(e => e.UserId)
            .OnDelete(DeleteBehavior.Restrict);

        builder.HasOne(e => e.OriginalCategory)
            .WithMany(c => c.OriginalCategoryCorrections)
            .HasForeignKey(e => e.OriginalCategoryId)
            .OnDelete(DeleteBehavior.SetNull);

        builder.HasOne(e => e.OriginalSubcategory)
            .WithMany(s => s.OriginalSubcategoryCorrections)
            .HasForeignKey(e => e.OriginalSubcategoryId)
            .OnDelete(DeleteBehavior.SetNull);

        builder.HasOne(e => e.CorrectedCategory)
            .WithMany(c => c.CorrectedCategoryCorrections)
            .HasForeignKey(e => e.CorrectedCategoryId)
            .OnDelete(DeleteBehavior.SetNull);

        builder.HasOne(e => e.CorrectedSubcategory)
            .WithMany(s => s.CorrectedSubcategoryCorrections)
            .HasForeignKey(e => e.CorrectedSubcategoryId)
            .OnDelete(DeleteBehavior.SetNull);

        builder.HasOne(e => e.ReviewedByAdmin)
            .WithMany()
            .HasForeignKey(e => e.ReviewedByAdminId)
            .OnDelete(DeleteBehavior.SetNull);

        builder.HasOne(e => e.GeneratedRule)
            .WithMany()
            .HasForeignKey(e => e.GeneratedRuleId)
            .OnDelete(DeleteBehavior.SetNull);

        builder.HasIndex(e => e.Status);
        builder.HasIndex(e => e.UserId);
        builder.HasIndex(e => e.CorrectionDate);
    }
}
