using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using ThemarIP.Domain.Entities.Pfm;

namespace ThemarIP.Infrastructure.Persistence.Configurations.Pfm;

public class SubcategoryConfiguration : IEntityTypeConfiguration<PfmSubcategory>
{
    public void Configure(EntityTypeBuilder<PfmSubcategory> builder)
    {
        builder.ToTable("PfmSubcategories");
        builder.HasKey(e => e.Id);

        builder.Property(e => e.Name).IsRequired().HasMaxLength(128);
        builder.Property(e => e.DisplayOrder).HasDefaultValue(0);
        builder.Property(e => e.IsEnabled).HasDefaultValue(true);

        builder.HasOne(e => e.Category)
            .WithMany(c => c.Subcategories)
            .HasForeignKey(e => e.CategoryId)
            .OnDelete(DeleteBehavior.Cascade);

        // Name must be unique within a category (not globally)
        builder.HasIndex(e => new { e.CategoryId, e.Name }).IsUnique();
        builder.HasIndex(e => e.DisplayOrder);
    }
}
