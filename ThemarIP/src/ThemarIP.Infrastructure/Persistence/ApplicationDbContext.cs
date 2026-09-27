using Microsoft.EntityFrameworkCore;
using ThemarIP.Application.Common.Interfaces;
using ThemarIP.Domain.Entities;
using ThemarIP.Domain.Entities.Pfm;

namespace ThemarIP.Infrastructure.Persistence;

public class ApplicationDbContext : DbContext, IApplicationDbContext
{
    public ApplicationDbContext(DbContextOptions<ApplicationDbContext> options)
        : base(options)
    {
    }

    // ── Existing tables (user management) ────────────────────
    public DbSet<User> Users => Set<User>();
    public DbSet<Subscription> Subscriptions => Set<Subscription>();
    public DbSet<StatementUpload> StatementUploads => Set<StatementUpload>();
    public DbSet<Transaction> Transactions => Set<Transaction>();
    public DbSet<AiQuery> AiQueries => Set<AiQuery>();
    public DbSet<SystemLog> SystemLogs => Set<SystemLog>();
    public DbSet<CategoryRule> CategoryRules => Set<CategoryRule>();
    public DbSet<NboApiConfig> NboApiConfigs => Set<NboApiConfig>();
    public DbSet<KycSubmission> KycSubmissions => Set<KycSubmission>();
    public DbSet<AuditLog> AuditLogs => Set<AuditLog>();

    // ── PFM categorization & intelligence ─────────────────────
    public DbSet<PfmCategory> PfmCategories => Set<PfmCategory>();
    public DbSet<PfmSubcategory> PfmSubcategories => Set<PfmSubcategory>();
    public DbSet<PfmMerchant> PfmMerchants => Set<PfmMerchant>();
    public DbSet<PfmMerchantAlias> PfmMerchantAliases => Set<PfmMerchantAlias>();
    public DbSet<PfmCategorizationRule> PfmCategorizationRules => Set<PfmCategorizationRule>();
    public DbSet<PfmRuleCondition> PfmRuleConditions => Set<PfmRuleCondition>();
    public DbSet<PfmTransaction> PfmTransactions => Set<PfmTransaction>();
    public DbSet<PfmTransactionCategory> PfmTransactionCategories => Set<PfmTransactionCategory>();
    public DbSet<PfmConfidenceBand> PfmConfidenceBands => Set<PfmConfidenceBand>();
    public DbSet<PfmConfidenceWeight> PfmConfidenceWeights => Set<PfmConfidenceWeight>();
    public DbSet<PfmUserCorrection> PfmUserCorrections => Set<PfmUserCorrection>();
    public DbSet<PfmLearningSuggestion> PfmLearningSuggestions => Set<PfmLearningSuggestion>();
    public DbSet<PfmIntelligenceRule> PfmIntelligenceRules => Set<PfmIntelligenceRule>();
    public DbSet<PfmIntelligenceRuleParam> PfmIntelligenceRuleParams => Set<PfmIntelligenceRuleParam>();
    public DbSet<PfmIntelligenceAlert> PfmIntelligenceAlerts => Set<PfmIntelligenceAlert>();
    public DbSet<PfmAuditLog> PfmAuditLogs => Set<PfmAuditLog>();

    protected override void ConfigureConventions(ModelConfigurationBuilder configurationBuilder)
    {
        base.ConfigureConventions(configurationBuilder);
        configurationBuilder.Properties<Guid>().HaveConversion<string>();
        configurationBuilder.Properties<Guid?>().HaveConversion<string>();
        configurationBuilder.Properties<DateTimeOffset>().HaveConversion<string>();
        configurationBuilder.Properties<DateTimeOffset?>().HaveConversion<string>();
    }

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);

        // Apply all IEntityTypeConfiguration<T> classes from this assembly.
        // This picks up all Pfm/Configurations/*.cs files automatically.
        modelBuilder.ApplyConfigurationsFromAssembly(typeof(ApplicationDbContext).Assembly);

        modelBuilder.Entity<User>(entity =>
        {
            entity.HasKey(e => e.Id);
            entity.HasIndex(e => e.Email).IsUnique();
            entity.Property(e => e.Email).IsRequired().HasMaxLength(256);
            entity.Property(e => e.FullName).IsRequired().HasMaxLength(256);
            entity.Property(e => e.Role).HasConversion<string>();
            entity.Property(e => e.AccountNumber).HasMaxLength(64);
            
            // New enums
            entity.Property(e => e.AccessStatus).HasConversion<string>().HasDefaultValue(ThemarIP.Domain.Enums.AccessStatus.Pending);
            entity.Property(e => e.AccessReasonCode).HasConversion<string>();
        });

        // KycSubmission Configuration
        modelBuilder.Entity<KycSubmission>(entity =>
        {
            entity.HasKey(e => e.Id);
            entity.Property(e => e.Status).HasConversion<string>();
            entity.Property(e => e.ReasonCode).HasConversion<string>();
            
            entity.HasOne(e => e.User)
                .WithMany(u => u.KycSubmissions)
                .HasForeignKey(e => e.UserId)
                .OnDelete(DeleteBehavior.Cascade);
                
            entity.HasOne(e => e.ReviewedByAdmin)
                .WithMany()
                .HasForeignKey(e => e.ReviewedByAdminId)
                .OnDelete(DeleteBehavior.Restrict);
        });

        // AuditLog Configuration
        modelBuilder.Entity<AuditLog>(entity =>
        {
            entity.HasKey(e => e.Id);
            entity.Property(e => e.ActionType).HasConversion<string>();
            entity.Property(e => e.ReasonCode).HasConversion<string>();
            
            entity.HasOne(e => e.AdminUser)
                .WithMany(u => u.AdminAuditLogs)
                .HasForeignKey(e => e.AdminUserId)
                .OnDelete(DeleteBehavior.Restrict);
                
            entity.HasOne(e => e.TargetUser)
                .WithMany(u => u.TargetAuditLogs)
                .HasForeignKey(e => e.TargetUserId)
                .OnDelete(DeleteBehavior.Cascade);
        });

        // Subscription Configuration
        modelBuilder.Entity<Subscription>(entity =>
        {
            entity.HasKey(e => e.Id);
            entity.Property(e => e.Tier).HasConversion<string>();
            entity.Property(e => e.Status).HasConversion<string>();
            entity.Property(e => e.Price).HasPrecision(18, 2);
            entity.HasOne(e => e.User)
                .WithMany(u => u.Subscriptions)
                .HasForeignKey(e => e.UserId)
                .OnDelete(DeleteBehavior.Cascade);
        });

        // StatementUpload Configuration
        modelBuilder.Entity<StatementUpload>(entity =>
        {
            entity.HasKey(e => e.Id);
            entity.Property(e => e.Status).HasConversion<string>();
            entity.Property(e => e.Source).HasMaxLength(32).HasDefaultValue("FILE_UPLOAD");
            entity.Property(e => e.AccountNumber).HasMaxLength(64);
            entity.HasOne(e => e.User)
                .WithMany(u => u.StatementUploads)
                .HasForeignKey(e => e.UserId)
                .OnDelete(DeleteBehavior.Cascade);
        });

        // Transaction Configuration
        modelBuilder.Entity<Transaction>(entity =>
        {
            entity.HasKey(e => e.Id);
            entity.Property(e => e.Amount).HasPrecision(18, 3);
            entity.HasOne(e => e.StatementUpload)
                .WithMany(s => s.Transactions)
                .HasForeignKey(e => e.StatementUploadId)
                .OnDelete(DeleteBehavior.Cascade);

            entity.HasOne(e => e.User)
                .WithMany()
                .HasForeignKey(e => e.UserId)
                .OnDelete(DeleteBehavior.Restrict);
        });

        // AiQuery Configuration
        modelBuilder.Entity<AiQuery>(entity =>
        {
            entity.HasKey(e => e.Id);
            entity.HasOne(e => e.User)
                .WithMany(u => u.AiQueries)
                .HasForeignKey(e => e.UserId)
                .OnDelete(DeleteBehavior.Cascade);
        });

        // CategoryRule Configuration
        modelBuilder.Entity<CategoryRule>(entity =>
        {
            entity.HasKey(e => e.Id);
            entity.HasIndex(e => e.Keyword);
            entity.Property(e => e.Keyword).IsRequired().HasMaxLength(128);
            entity.Property(e => e.Category).IsRequired().HasMaxLength(128);
        });
    }
}
