using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using ThemarIP.Domain.Entities.Pfm;
using ThemarIP.Domain.Enums.Pfm;

namespace ThemarIP.Infrastructure.Persistence.Configurations.Pfm;

public class LearningSuggestionConfiguration : IEntityTypeConfiguration<PfmLearningSuggestion>
{
    public void Configure(EntityTypeBuilder<PfmLearningSuggestion> builder)
    {
        builder.ToTable("PfmLearningSuggestions");
        builder.HasKey(e => e.Id);

        builder.Property(e => e.Pattern).IsRequired().HasMaxLength(512);
        builder.Property(e => e.Status).HasConversion<string>().HasDefaultValue(SuggestionStatus.Pending);
        builder.Property(e => e.OccurrenceCount).HasDefaultValue(0);
        builder.Property(e => e.SuggestedConfidence).HasDefaultValue(85);

        builder.HasOne(e => e.CurrentCategory)
            .WithMany(c => c.SuggestionsAsCurrent)
            .HasForeignKey(e => e.CurrentCategoryId)
            .OnDelete(DeleteBehavior.SetNull);

        builder.HasOne(e => e.CurrentSubcategory)
            .WithMany(s => s.SuggestionsAsCurrent)
            .HasForeignKey(e => e.CurrentSubcategoryId)
            .OnDelete(DeleteBehavior.SetNull);

        builder.HasOne(e => e.SuggestedCategory)
            .WithMany(c => c.SuggestionsAsSuggested)
            .HasForeignKey(e => e.SuggestedCategoryId)
            .OnDelete(DeleteBehavior.SetNull);

        builder.HasOne(e => e.SuggestedSubcategory)
            .WithMany(s => s.SuggestionsAsSuggested)
            .HasForeignKey(e => e.SuggestedSubcategoryId)
            .OnDelete(DeleteBehavior.SetNull);

        builder.HasOne(e => e.GeneratedRule)
            .WithMany()
            .HasForeignKey(e => e.GeneratedRuleId)
            .OnDelete(DeleteBehavior.SetNull);

        builder.HasIndex(e => e.Status);
        builder.HasIndex(e => e.Pattern);
        builder.HasIndex(e => e.OccurrenceCount);
    }
}
