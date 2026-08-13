using System.Text;
using System.Threading.RateLimiting;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Diagnostics;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using Microsoft.OpenApi.Models;
using PdfSharp.Fonts;
using QuyNhaMinh.Api.Data;
using QuyNhaMinh.Api.Endpoints;
using QuyNhaMinh.Api.Services;

var builder = WebApplication.CreateBuilder(args);
var jwtKey = Environment.GetEnvironmentVariable("JWT_KEY") ?? builder.Configuration["Jwt:Key"] ?? "LOCAL-ONLY-CHANGE-THIS-KEY-32-BYTES";
if (builder.Environment.IsProduction() && jwtKey.StartsWith("LOCAL-ONLY")) throw new InvalidOperationException("JWT_KEY must be configured in production.");
builder.Configuration["Jwt:Key"] = jwtKey;
var databaseUrl = Environment.GetEnvironmentVariable("DATABASE_URL");
if (!string.IsNullOrWhiteSpace(databaseUrl)) builder.Services.AddDbContext<AppDb>(o => o.UseNpgsql(NormalizeDatabaseUrl(databaseUrl)));
else builder.Services.AddDbContext<AppDb>(o => o.UseSqlite(builder.Configuration.GetConnectionString("Default") ?? "Data Source=quynhaminh.db"));

builder.Services.AddHttpContextAccessor();
builder.Services.AddHttpClient();
builder.Services.AddSingleton<PasswordService>();
builder.Services.AddSingleton<TokenService>();
builder.Services.AddScoped<CurrentUser>();
builder.Services.AddScoped<FundAccess>();
builder.Services.AddScoped<SupabaseStorage>();
builder.Services.AddScoped<GeminiReceiptService>();
builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme).AddJwtBearer(o => {
    o.TokenValidationParameters = new TokenValidationParameters { ValidateIssuer = true, ValidateAudience = true, ValidateLifetime = true, ValidateIssuerSigningKey = true, ValidIssuer = builder.Configuration["Jwt:Issuer"] ?? "QuyNhaMinh", ValidAudience = builder.Configuration["Jwt:Audience"] ?? "QuyNhaMinhMobile", IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwtKey)), ClockSkew = TimeSpan.FromMinutes(1) };
});
builder.Services.AddAuthorization();
builder.Services.AddCors(o => o.AddDefaultPolicy(p => p.AllowAnyOrigin().AllowAnyHeader().AllowAnyMethod()));
builder.Services.AddRateLimiter(o => { o.RejectionStatusCode = StatusCodes.Status429TooManyRequests; o.AddPolicy("api", context => RateLimitPartition.GetFixedWindowLimiter(context.User.Identity?.Name ?? context.Connection.RemoteIpAddress?.ToString() ?? "anonymous", _ => new FixedWindowRateLimiterOptions { PermitLimit = 120, Window = TimeSpan.FromMinutes(1), QueueLimit = 0 })); });
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen(o => {
    o.SwaggerDoc("v1", new OpenApiInfo { Title = "Quỹ Nhà Mình API", Version = "v1", Description = "API quản lý thu chi gia đình, nhiều quỹ, Gemini OCR và Supabase." });
    o.AddSecurityDefinition("Bearer", new OpenApiSecurityScheme { Name = "Authorization", Type = SecuritySchemeType.Http, Scheme = "bearer", BearerFormat = "JWT", In = ParameterLocation.Header, Description = "Nhập JWT nhận từ /api/auth/login" });
    o.AddSecurityRequirement(new OpenApiSecurityRequirement { [new OpenApiSecurityScheme { Reference = new OpenApiReference { Type = ReferenceType.SecurityScheme, Id = "Bearer" } }] = Array.Empty<string>() });
});

var app = builder.Build();
GlobalFontSettings.FontResolver ??= new QnmFontResolver(app.Environment.ContentRootPath);
app.UseExceptionHandler(error => error.Run(async context => {
    var exception = context.Features.Get<IExceptionHandlerFeature>()?.Error;
    var (status, title, detail) = exception switch { ForbiddenException e => (403, "Không có quyền", e.Message), UnauthorizedAccessException => (401, "Chưa đăng nhập", "Phiên đăng nhập không hợp lệ hoặc đã hết hạn."), ExternalServiceException e => (e.StatusCode, e.Message, app.Environment.IsDevelopment() ? e.Detail : "Dịch vụ bên ngoài tạm thời không khả dụng."), ArgumentException e => (400, "Dữ liệu không hợp lệ", e.Message), _ => (500, "Lỗi máy chủ", app.Environment.IsDevelopment() ? exception?.Message ?? "Unknown" : "Đã có lỗi xảy ra.") };
    context.Response.StatusCode = status; await context.Response.WriteAsJsonAsync(new ProblemDetails { Status = status, Title = title, Detail = detail });
}));
app.UseCors();
app.UseRateLimiter();
app.UseAuthentication();
app.UseAuthorization();
app.UseStaticFiles();
app.UseSwagger();
app.UseSwaggerUI();
app.MapGet("/health", () => Results.Ok(new { status = "ok", app = "Quỹ Nhà Mình", database = string.IsNullOrWhiteSpace(databaseUrl) ? "sqlite-local" : "postgresql", utc = DateTimeOffset.UtcNow })).AllowAnonymous();
app.MapGet("/app-update", () => Results.Ok(new {
    version = Environment.GetEnvironmentVariable("APP_LATEST_VERSION") ?? "2.0.2",
    url = Environment.GetEnvironmentVariable("APP_UPDATE_URL") ?? "https://github.com/taidoantan/quynhaminh/releases/latest/download/QuyNhaMinh.apk",
    notes = Environment.GetEnvironmentVariable("APP_UPDATE_NOTES") ?? "Cập nhật Quỹ Nhà Mình để có giao diện và tính năng mới nhất."
})).AllowAnonymous();
app.MapAuthAndFunds();
app.MapFinance();
app.MapDataFeatures();


await InitializeDatabase(app.Services);
app.Run("http://0.0.0.0:5180");

static async Task InitializeDatabase(IServiceProvider services) {
    using var scope = services.CreateScope(); var db = scope.ServiceProvider.GetRequiredService<AppDb>();
    // Supabase already has system tables; migrations must create the application schema.
    if (db.Database.IsNpgsql()) await SupabaseSchema.EnsureAsync(db);
    else if ((await db.Database.GetPendingMigrationsAsync()).Any() || (await db.Database.GetAppliedMigrationsAsync()).Any()) await db.Database.MigrateAsync();
    else await db.Database.EnsureCreatedAsync();
}

static string NormalizeDatabaseUrl(string value) {
    if (!value.StartsWith("postgres://", StringComparison.OrdinalIgnoreCase) && !value.StartsWith("postgresql://", StringComparison.OrdinalIgnoreCase)) return value;
    var uri = new Uri(value); var user = uri.UserInfo.Split(':', 2); return $"Host={uri.Host};Port={(uri.Port > 0 ? uri.Port : 5432)};Database={uri.AbsolutePath.TrimStart('/')};Username={Uri.UnescapeDataString(user[0])};Password={Uri.UnescapeDataString(user.ElementAtOrDefault(1) ?? "")};SSL Mode=Require;Trust Server Certificate=true";
}

public partial class Program;
