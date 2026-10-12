using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using ThemarIP.Domain.Entities.Sms;

namespace ThemarIP.Infrastructure.Persistence.Configurations.Sms;

public class BankSmsRuleConfiguration : IEntityTypeConfiguration<BankSmsRule>
{
    public void Configure(EntityTypeBuilder<BankSmsRule> b)
    {
        b.ToTable("BankSmsRules");
        b.HasKey(x => x.Id);
        b.Property(x => x.BankName).IsRequired().HasMaxLength(128);
        b.Property(x => x.BankCode).HasMaxLength(64);
        b.Property(x => x.SenderIds).IsRequired().HasMaxLength(512);
        b.Property(x => x.Pattern).IsRequired().HasMaxLength(4000);
        b.Property(x => x.DefaultType).HasMaxLength(16);
        b.Property(x => x.DefaultCurrency).HasMaxLength(8);
        b.Property(x => x.UpdatedBy).HasMaxLength(256);
        b.HasIndex(x => x.IsActive);
    }
}

public class BankSmsRuleVersionConfiguration : IEntityTypeConfiguration<BankSmsRuleVersion>
{
    public void Configure(EntityTypeBuilder<BankSmsRuleVersion> b)
    {
        b.ToTable("BankSmsRuleVersions");
        b.HasKey(x => x.Id);
        b.HasIndex(x => new { x.RuleId, x.Version });
        b.Property(x => x.ChangedBy).HasMaxLength(256);
    }
}

public class SmsProcessingLogConfiguration : IEntityTypeConfiguration<SmsProcessingLog>
{
    public void Configure(EntityTypeBuilder<SmsProcessingLog> b)
    {
        b.ToTable("SmsProcessingLogs");
        b.HasKey(x => x.Id);
        b.Property(x => x.Sender).HasMaxLength(64);
        b.Property(x => x.MessageHash).HasMaxLength(64);
        b.Property(x => x.Status).HasMaxLength(32);
        b.Property(x => x.Reference).HasMaxLength(128);
        b.HasIndex(x => new { x.UserId, x.MessageHash });
        b.HasIndex(x => new { x.UserId, x.RuleId, x.Reference });
        b.HasIndex(x => x.CreatedAt);
    }
}
