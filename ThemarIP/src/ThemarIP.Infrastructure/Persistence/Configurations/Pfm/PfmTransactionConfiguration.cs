using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using ThemarIP.Domain.Entities.Pfm;
using ThemarIP.Domain.Enums.Pfm;

namespace ThemarIP.Infrastructure.Persistence.Configurations.Pfm;

public class PfmTransactionConfiguration : IEntityTypeConfiguration<PfmTransaction>
{
    public void Configure(EntityTypeBuilder<PfmTransaction> builder)
    {
        builder.ToTable("PfmTransactions");
        builder.HasKey(e => e.Id);

        builder.Property(e => e.Narration).IsRequired().HasMaxLength(512);
        builder.Property(e => e.Amount).HasPrecision(18, 3);
        builder.Property(e => e.Currency).HasMaxLength(8).HasDefaultValue("OMR");
        builder.Property(e => e.TransactionType).HasConversion<string>();
        builder.Property(e => e.BalanceAfter).HasPrecision(18, 3);
        builder.Property(e => e.Status).HasConversion<string>().HasDefaultValue(TransactionStatus.Uncategorized);
        builder.Property(e => e.MccCode).HasMaxLength(8);
        builder.Property(e => e.IsRecurring).HasDefaultValue(false);
        builder.Property(e => e.IsEssential).HasDefaultValue(false);
        builder.Property(e => e.BankCode).HasMaxLength(32).HasDefaultValue("BANK_MUSCAT");
        builder.Property(e => e.BankName).HasMaxLength(128).HasDefaultValue("Bank Muscat");

        builder.HasOne(e => e.User)
            .WithMany()
            .HasForeignKey(e => e.UserId)
            .OnDelete(DeleteBehavior.Restrict);

        builder.HasOne(e => e.Merchant)
            .WithMany(m => m.Transactions)
            .HasForeignKey(e => e.MerchantId)
            .OnDelete(DeleteBehavior.SetNull);

        builder.HasIndex(e => e.UserId);
        builder.HasIndex(e => e.MerchantId);
        builder.HasIndex(e => e.TransactionDate);
        builder.HasIndex(e => e.Status);
        builder.HasIndex(e => e.TransactionType);
    }
}
