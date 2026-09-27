using System.Threading;
using System.Threading.Tasks;
using Microsoft.EntityFrameworkCore;
using ThemarIP.Domain.Entities;

namespace ThemarIP.Application.Common.Interfaces;

public interface IApplicationDbContext
{
    DbSet<User> Users { get; }
    DbSet<Subscription> Subscriptions { get; }
    DbSet<StatementUpload> StatementUploads { get; }
    DbSet<Transaction> Transactions { get; }
    DbSet<AiQuery> AiQueries { get; }
    DbSet<SystemLog> SystemLogs { get; }
    DbSet<CategoryRule> CategoryRules { get; }
    DbSet<NboApiConfig> NboApiConfigs { get; }
    DbSet<KycSubmission> KycSubmissions { get; }
    DbSet<AuditLog> AuditLogs { get; }
    DbSet<ThemarIP.Domain.Entities.Pfm.PfmTransaction> PfmTransactions { get; }
    DbSet<ThemarIP.Domain.Entities.Pfm.PfmCategory> PfmCategories { get; }
    DbSet<ThemarIP.Domain.Entities.Pfm.PfmSubcategory> PfmSubcategories { get; }
    DbSet<ThemarIP.Domain.Entities.Pfm.PfmMerchant> PfmMerchants { get; }
    DbSet<ThemarIP.Domain.Entities.Pfm.PfmMerchantAlias> PfmMerchantAliases { get; }

    Task<int> SaveChangesAsync(CancellationToken cancellationToken = default);
}
