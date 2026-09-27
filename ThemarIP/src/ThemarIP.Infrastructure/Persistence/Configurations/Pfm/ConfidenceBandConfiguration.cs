using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using ThemarIP.Domain.Entities.Pfm;
using ThemarIP.Domain.Enums.Pfm;

namespace ThemarIP.Infrastructure.Persistence.Configurations.Pfm;

public class ConfidenceBandConfiguration : IEntityTypeConfiguration<PfmConfidenceBand>
{
    public void Configure(EntityTypeBuilder<PfmConfidenceBand> builder)
    {
        builder.ToTable("PfmConfidenceBands");
        builder.HasKey(e => e.Id);

        builder.Property(e => e.BandName).HasConversion<string>();
        builder.Property(e => e.DisplayLabel).HasMaxLength(128);
        builder.Property(e => e.Action).HasConversion<string>();
        builder.Property(e => e.ActionLabel).HasMaxLength(256);
        builder.Property(e => e.MinThreshold).HasDefaultValue(0);
        builder.Property(e => e.MaxThreshold).HasDefaultValue(100);

        // Only one row per band name
        builder.HasIndex(e => e.BandName).IsUnique();
    }
}
