using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using ThemarIP.Domain.Entities.Pfm;
using ThemarIP.Domain.Enums.Pfm;

namespace ThemarIP.Infrastructure.Persistence.Configurations.Pfm;

public class TransactionCategoryConfiguration : IEntityTypeConfiguration<PfmTransactionCategory>
{
    public void Configure(EntityTypeBuilder<PfmTransactionCategory> builder)
    {
        builder.ToTable("PfmTransactionCategories");
        builder.HasKey(e => e.Id);

        builder.Property(e => e.Confidence).HasDefaultValue(0);
        builder.Property(e => e.Source).HasConversion<string>().HasDefaultValue(CategorizationSource.Uncategorized);
        builder.Property(e => e.ScoreMerchantMatch).HasDefaultValue(0);
        builder.Property(e => e.ScoreMccMatch).HasDefaultValue(0);
        builder.Property(e => e.ScoreNarrationMatch).HasDefaultValue(0);
        builder.Property(e => e.ScoreHistoricalMatch).HasDefaultValue(0);
        builder.Property(e => e.ScoreAmountPattern).HasDefaultValue(0);

        // 1:1 with PfmTransaction — unique index enforces this at DB level
        builder.HasOne(e => e.Transaction)
            .WithOne(t => t.Category)
            .HasForeignKey<PfmTransactionCategory>(e => e.TransactionId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.HasOne(e => e.Category)
            .WithMany(c => c.TransactionCategories)
            .HasForeignKey(e => e.CategoryId)
            .OnDelete(DeleteBehavior.SetNull);

        builder.HasOne(e => e.Subcategory)
            .WithMany(s => s.TransactionCategories)
            .HasForeignKey(e => e.SubcategoryId)
            .OnDelete(DeleteBehavior.SetNull);

        builder.HasOne(e => e.MatchedRule)
            .WithMany(r => r.TransactionCategories)
            .HasForeignKey(e => e.MatchedRuleId)
            .OnDelete(DeleteBehavior.SetNull);

        builder.HasIndex(e => e.TransactionId).IsUnique();
        builder.HasIndex(e => e.CategoryId);
        builder.HasIndex(e => e.Source);
        builder.HasIndex(e => e.Confidence);
    }
}
