using Microsoft.EntityFrameworkCore;
using QuyNhaMinh.Api.Domain;

namespace QuyNhaMinh.Api.Data;

public sealed class AppDb(DbContextOptions<AppDb> options) : DbContext(options) {
    public DbSet<QuyNhaMinh.Api.Domain.User> Users => Set<QuyNhaMinh.Api.Domain.User>();
    public DbSet<PasswordReset> PasswordResets => Set<PasswordReset>();
    public DbSet<Fund> Funds => Set<Fund>();
    public DbSet<FundMember> FundMembers => Set<FundMember>();
    public DbSet<FundInvitation> FundInvitations => Set<FundInvitation>();
    public DbSet<QuyNhaMinh.Api.Domain.Category> Categories => Set<QuyNhaMinh.Api.Domain.Category>();
    public DbSet<MoneyAccount> MoneyAccounts => Set<MoneyAccount>();
    public DbSet<QuyNhaMinh.Api.Domain.MoneyTransaction> Transactions => Set<QuyNhaMinh.Api.Domain.MoneyTransaction>();
    public DbSet<Budget> Budgets => Set<Budget>();
    public DbSet<Reminder> Reminders => Set<Reminder>();
    public DbSet<Receipt> Receipts => Set<Receipt>();
    public DbSet<AuditLog> AuditLogs => Set<AuditLog>();

    protected override void OnModelCreating(ModelBuilder b) {
        b.Entity<QuyNhaMinh.Api.Domain.User>().HasIndex(x => x.Email).IsUnique();
        b.Entity<Fund>().HasIndex(x => x.InviteCode).IsUnique();
        b.Entity<PasswordReset>().HasIndex(x => new { x.UserId, x.ExpiresAt });
        b.Entity<FundMember>().HasIndex(x => new { x.FundId, x.UserId }).IsUnique();
        b.Entity<FundInvitation>().HasIndex(x => new { x.FundId, x.RecipientUserId }).IsUnique();
        b.Entity<QuyNhaMinh.Api.Domain.Category>().HasIndex(x => new { x.FundId, x.Type, x.Name }).IsUnique();
        b.Entity<Budget>().HasIndex(x => new { x.FundId, x.CategoryId, x.Year, x.Month }).IsUnique();
        b.Entity<QuyNhaMinh.Api.Domain.MoneyTransaction>().Property(x => x.Amount).HasPrecision(18, 2);
        b.Entity<MoneyAccount>().Property(x => x.InitialBalance).HasPrecision(18, 2);
        b.Entity<Budget>().Property(x => x.LimitAmount).HasPrecision(18, 2);
        b.Entity<Reminder>().Property(x => x.ExpectedAmount).HasPrecision(18, 2);
        b.Entity<Fund>().HasQueryFilter(x => !x.IsDeleted);
        b.Entity<QuyNhaMinh.Api.Domain.Category>().HasQueryFilter(x => !x.IsDeleted);
        b.Entity<MoneyAccount>().HasQueryFilter(x => !x.IsDeleted);
        b.Entity<QuyNhaMinh.Api.Domain.MoneyTransaction>().HasQueryFilter(x => !x.IsDeleted);
        b.Entity<Reminder>().HasQueryFilter(x => !x.IsDeleted);
    }
}
