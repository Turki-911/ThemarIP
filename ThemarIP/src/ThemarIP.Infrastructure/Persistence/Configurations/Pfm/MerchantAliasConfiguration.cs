using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using ThemarIP.Domain.Entities.Pfm;

namespace ThemarIP.Infrastructure.Persistence.Configurations.Pfm;

public class MerchantAliasConfiguration : IEntityTypeConfiguration<PfmMerchantAlias>
{
    public void Configure(EntityTypeBuilder<PfmMerchantAlias> builder)
    {
        builder.ToTable("PfmMerchantAliases");
        builder.HasKey(e => e.Id);

        builder.Property(e => e.AliasText).IsRequired().HasMaxLength(256);

        builder.HasOne(e => e.Merchant)
            .WithMany(m => m.Aliases)
            .HasForeignKey(e => e.MerchantId)
            .OnDelete(DeleteBehavior.Cascade);

        // Alias text must be unique globally — the engine uses it as a lookup key
        builder.HasIndex(e => e.AliasText).IsUnique();
        builder.HasIndex(e => e.MerchantId);
    }
}
