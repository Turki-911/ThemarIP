using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using ThemarIP.Domain.Entities.Pfm;

namespace ThemarIP.Infrastructure.Persistence.Configurations.Pfm;

public class MerchantConfiguration : IEntityTypeConfiguration<PfmMerchant>
{
    public void Configure(EntityTypeBuilder<PfmMerchant> builder)
    {
        builder.ToTable("PfmMerchants");
        builder.HasKey(e => e.Id);

        builder.Property(e => e.Name).IsRequired().HasMaxLength(256);
        builder.Property(e => e.MccCode).HasMaxLength(8);
        builder.Property(e => e.DefaultConfidence).HasDefaultValue(90);
        builder.Property(e => e.IsActive).HasDefaultValue(true);
        builder.Property(e => e.TransactionCount).HasDefaultValue(0);
        builder.Property(e => e.CorrectionRate).HasPrecision(5, 2).HasDefaultValue(0m);

        builder.HasOne(e => e.DefaultCategory)
            .WithMany(c => c.MerchantsAsDefault)
            .HasForeignKey(e => e.DefaultCategoryId)
            .OnDelete(DeleteBehavior.SetNull);

        builder.HasOne(e => e.DefaultSubcategory)
            .WithMany(s => s.MerchantsAsDefault)
            .HasForeignKey(e => e.DefaultSubcategoryId)
            .OnDelete(DeleteBehavior.SetNull);

        builder.HasIndex(e => e.Name);
        builder.HasIndex(e => e.MccCode);
        builder.HasIndex(e => e.IsActive);
    }
}
