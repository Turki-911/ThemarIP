using System;
using System.Collections.Generic;
using System.Text;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Builder;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.IdentityModel.Tokens;
using Microsoft.OpenApi;
using ThemarIP.API.Middleware;
using ThemarIP.Application.Common.Interfaces;
using ThemarIP.Application.Services;
using ThemarIP.Infrastructure.Persistence;
using ThemarIP.Infrastructure.Security;
using ThemarIP.Infrastructure.ExternalApis;
using ThemarIP.Application.Interfaces.Statements;
using ThemarIP.Infrastructure.Services.Statements;

var builder = WebApplication.CreateBuilder(args);

// 1. Add CORS Support
builder.Services.AddCors(options =>
{
    options.AddDefaultPolicy(policy =>
    {
        policy.AllowAnyOrigin()
              .AllowAnyHeader()
              .AllowAnyMethod();
    });
});

// 2. Add Database Context (Supports PostgreSQL or Sqlite)
var dbProvider = builder.Configuration["DatabaseProvider"] ?? "Sqlite";
if (dbProvider.Equals("PostgreSQL", StringComparison.OrdinalIgnoreCase))
{
    var pgConnectionString = builder.Configuration.GetConnectionString("DefaultConnection");
    builder.Services.AddDbContext<ApplicationDbContext>(options =>
        options.UseNpgsql(pgConnectionString, b => b.MigrationsAssembly(typeof(ApplicationDbContext).Assembly.FullName)));
}
else
{
    var sqliteConnectionString = builder.Configuration.GetConnectionString("SqliteConnection") ?? "Data Source=themarip.db";
    builder.Services.AddDbContext<ApplicationDbContext>(options =>
    {
        options.UseSqlite(sqliteConnectionString, b => b.MigrationsAssembly(typeof(ApplicationDbContext).Assembly.FullName));
        options.ConfigureWarnings(w => w.Ignore(Microsoft.EntityFrameworkCore.Diagnostics.RelationalEventId.PendingModelChangesWarning));
    });
}

builder.Services.AddScoped<IApplicationDbContext>(provider => provider.GetRequiredService<ApplicationDbContext>());

// 3. Add Security Services
builder.Services.AddScoped<IPasswordHasher, BcryptPasswordHasher>();
builder.Services.AddScoped<IJwtTokenGenerator, JwtTokenGenerator>();

// 4. Add Application Services
builder.Services.AddScoped<IAuthService, AuthService>();
builder.Services.AddScoped<IPdfExtractorService, PdfExtractorService>();
builder.Services.AddScoped<IBankDetectorService, BankDetectorService>();
builder.Services.AddScoped<ITransactionNormalizerService, TransactionNormalizerService>();
builder.Services.AddScoped<IStatementService, StatementService>();
builder.Services.AddScoped<ITransactionService, TransactionService>();
builder.Services.AddScoped<ISubscriptionService, SubscriptionService>();
builder.Services.AddScoped<IAdminService, AdminService>();
builder.Services.AddScoped<INboConfigService, NboConfigService>();
builder.Services.AddScoped<IBankMuscatPdfParser, BankMuscatPdfParser>();
builder.Services.AddScoped<IStatementExtractionService, StatementExtractionService>();
builder.Services.AddScoped<IBankNotificationParserService, BankNotificationParserService>();
builder.Services.AddScoped<IMailboxPullerService, MailboxPullerService>();

// 4b. Add NBO API Service
builder.Services.AddHttpClient("NboApi", client =>
{
    client.DefaultRequestHeaders.Add("Accept", "application/json");
}).ConfigurePrimaryHttpMessageHandler(() => new System.Net.Http.HttpClientHandler
{
    ServerCertificateCustomValidationCallback = (message, cert, chain, errors) => true // sandbox self-signed cert
});
builder.Services.AddScoped<INboApiService, NboApiService>();

// 5. Add Controllers
builder.Services.AddControllers()
    .AddJsonOptions(options =>
    {
        options.JsonSerializerOptions.ReferenceHandler = System.Text.Json.Serialization.ReferenceHandler.IgnoreCycles;
    });

// 6. Configure JWT Authentication
var secretKey = builder.Configuration["JwtSettings:Secret"] ?? "ThemarIPSecretKeyForJWTAuthentication2026SuperSecureKey!";
var issuer = builder.Configuration["JwtSettings:Issuer"] ?? "ThemarIP.API";
var audience = builder.Configuration["JwtSettings:Audience"] ?? "ThemarIP.Client";

builder.Services.AddAuthentication(options =>
{
    options.DefaultAuthenticateScheme = JwtBearerDefaults.AuthenticationScheme;
    options.DefaultChallengeScheme = JwtBearerDefaults.AuthenticationScheme;
})
.AddJwtBearer(options =>
{
    options.TokenValidationParameters = new TokenValidationParameters
    {
        ValidateIssuer = true,
        ValidateAudience = true,
        ValidateLifetime = true,
        ValidateIssuerSigningKey = true,
        ValidIssuer = issuer,
        ValidAudience = audience,
        IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(secretKey))
    };
});

builder.Services.AddAuthorization();

// 7. Configure Swagger with OpenAPI
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen(options =>
{
    options.SwaggerDoc("v1", new OpenApiInfo
    {
        Title = "ThemarIP Web API",
        Version = "v1",
        Description = "Core Web API for Themar Card Management & Statement Processing built with Clean Architecture."
    });

    var securityScheme = new OpenApiSecurityScheme
    {
        Name = "Authorization",
        Type = SecuritySchemeType.Http,
        Scheme = "bearer",
        BearerFormat = "JWT",
        In = ParameterLocation.Header,
        Description = "Enter JWT Bearer token"
    };

    options.AddSecurityDefinition("Bearer", securityScheme);

    options.AddSecurityRequirement((doc) => new OpenApiSecurityRequirement
    {
        [new OpenApiSecuritySchemeReference("Bearer", doc)] = new List<string>()
    });
});

var app = builder.Build();

// 8. Auto-migrate and Seed Database
using (var scope = app.Services.CreateScope())
{
    var services = scope.ServiceProvider;
    try
    {
        var dbContext = services.GetRequiredService<ApplicationDbContext>();
        var passwordHasher = services.GetRequiredService<IPasswordHasher>();
        await DbInitializer.SeedAsync(dbContext, passwordHasher);
    }
    catch (Exception ex)
    {
        var logger = services.GetRequiredService<Microsoft.Extensions.Logging.ILogger<Program>>();
        logger.LogError(ex, "An error occurred during database migration / seeding.");
    }
}

// 9. Configure Request Pipeline
app.UseMiddleware<GlobalExceptionHandlingMiddleware>();

if (app.Environment.IsDevelopment() || app.Environment.IsProduction())
{
    app.UseSwagger();
    app.UseSwaggerUI(c =>
    {
        c.SwaggerEndpoint("/swagger/v1/swagger.json", "ThemarIP.API v1");
        c.RoutePrefix = "swagger";
    });
}

app.UseCors();

var contentTypeProvider = new Microsoft.AspNetCore.StaticFiles.FileExtensionContentTypeProvider();
contentTypeProvider.Mappings[".wasm"] = "application/wasm";
contentTypeProvider.Mappings[".apk"] = "application/vnd.android.package-archive";
contentTypeProvider.Mappings[".json"] = "application/json";

app.UseDefaultFiles();
app.UseStaticFiles(new StaticFileOptions
{
    ContentTypeProvider = contentTypeProvider,
    ServeUnknownFileTypes = true
});

app.UseAuthentication();
app.UseAuthorization();
app.MapControllers();
app.MapFallbackToFile("index.html");

// 10. Health & Infrastructure Diagnostics Endpoint
app.MapGet("/api/health", async (ApplicationDbContext db) =>
{
    try
    {
        var canConnect = await db.Database.CanConnectAsync();
        var catCount = await db.PfmCategories.CountAsync();
        var txCount = await db.Transactions.CountAsync();
        return Results.Ok(new
        {
            status = "Healthy",
            service = "ThemarIP.API",
            version = "2.4.0",
            timestamp = DateTime.UtcNow,
            database = new
            {
                provider = "Sqlite",
                connected = canConnect,
                categories = catCount,
                transactions = txCount
            }
        });
    }
    catch (Exception ex)
    {
        return Results.Json(new
        {
            status = "Degraded",
            service = "ThemarIP.API",
            error = ex.Message,
            timestamp = DateTime.UtcNow
        }, statusCode: 500);
    }
});

app.Run();
