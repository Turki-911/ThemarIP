using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using ThemarIP.Domain.Entities.Pfm;

namespace ThemarIP.Infrastructure.Persistence.Configurations.Pfm;

public class CategoryConfiguration : IEntityTypeConfiguration<PfmCategory>
{
    public void Configure(EntityTypeBuilder<PfmCategory> builder)
    {
        builder.ToTable("PfmCategories");
        builder.HasKey(e => e.Id);

        builder.Property(e => e.Name).IsRequired().HasMaxLength(128);
        builder.Property(e => e.Icon).HasMaxLength(64).HasDefaultValue("tag");
        builder.Property(e => e.Color).HasMaxLength(16).HasDefaultValue("#94A3B8");
        builder.Property(e => e.DisplayOrder).HasDefaultValue(0);
        builder.Property(e => e.IsEnabled).HasDefaultValue(true);
        builder.Property(e => e.ParentId).IsRequired(false);

        // Self-referencing recursive hierarchy
        builder.HasOne(e => e.Parent)
            .WithMany(e => e.Children)
            .HasForeignKey(e => e.ParentId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.HasIndex(e => new { e.ParentId, e.Name }).IsUnique();
        builder.HasIndex(e => e.ParentId);
        builder.HasIndex(e => e.DisplayOrder);
    }
}
