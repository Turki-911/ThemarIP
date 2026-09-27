using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using ThemarIP.Domain.Entities.Pfm;

namespace ThemarIP.Infrastructure.Persistence.Configurations.Pfm;

public class ConfidenceWeightConfiguration : IEntityTypeConfiguration<PfmConfidenceWeight>
{
    public void Configure(EntityTypeBuilder<PfmConfidenceWeight> builder)
    {
        builder.ToTable("PfmConfidenceWeights");
        builder.HasKey(e => e.Id);

        builder.Property(e => e.Signal).HasConversion<string>();
        builder.Property(e => e.DisplayLabel).HasMaxLength(128);
        builder.Property(e => e.WeightPercent).HasDefaultValue(0);
        builder.Property(e => e.Color).HasMaxLength(16).HasDefaultValue("#94A3B8");

        // Only one row per signal
        builder.HasIndex(e => e.Signal).IsUnique();
    }
}
