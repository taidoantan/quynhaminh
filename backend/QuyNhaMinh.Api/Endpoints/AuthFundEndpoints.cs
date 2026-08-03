using System.Security.Cryptography;
using Microsoft.EntityFrameworkCore;
using QuyNhaMinh.Api.Contracts;
using QuyNhaMinh.Api.Data;
using QuyNhaMinh.Api.Domain;
using QuyNhaMinh.Api.Services;

namespace QuyNhaMinh.Api.Endpoints;

public static class AuthFundEndpoints {
    public static IEndpointRouteBuilder MapAuthAndFunds(this IEndpointRouteBuilder app) {
        var auth = app.MapGroup("/api/auth").WithTags("Authentication").RequireRateLimiting("api");
        auth.MapPost("/register", Register).AllowAnonymous();
        auth.MapPost("/login", Login).AllowAnonymous();
        auth.MapGet("/me", Me).RequireAuthorization();

        var funds = app.MapGroup("/api/funds").WithTags("Funds").RequireAuthorization().RequireRateLimiting("api");
        funds.MapGet("/", ListFunds);
        funds.MapPost("/", CreateFund);
        funds.MapPost("/join", JoinFund);
        funds.MapGet("/{fundId:guid}", GetFund);
        funds.MapPut("/{fundId:guid}", RenameFund);
        funds.MapDelete("/{fundId:guid}", DeleteFund);
        funds.MapGet("/{fundId:guid}/members", ListMembers);
        funds.MapPut("/{fundId:guid}/members/{memberId:guid}/role", ChangeRole);
        funds.MapDelete("/{fundId:guid}/members/{memberId:guid}", RemoveMember);
        return app;
    }

    private static async Task<IResult> Register(RegisterRequest x, AppDb db, PasswordService passwords, TokenService tokens) {
        var email = x.Email.Trim().ToLowerInvariant();
        if (x.DisplayName.Trim().Length < 2 || !email.Contains('@') || x.Password.Length < 8) return Results.ValidationProblem(new Dictionary<string, string[]> { ["input"] = ["Tên, email hoặc mật khẩu chưa hợp lệ (mật khẩu tối thiểu 8 ký tự)."] });
        if (await db.Users.AnyAsync(u => u.Email == email)) return Results.Conflict(new { message = "Email đã tồn tại." });
        var user = new QuyNhaMinh.Api.Domain.User { DisplayName = x.DisplayName.Trim(), Email = email, PasswordHash = passwords.Hash(x.Password) };
        db.Users.Add(user); await db.SaveChangesAsync();
        return Results.Ok(new AuthResponse(tokens.Create(user), new { user.Id, user.DisplayName, user.Email }));
    }

    private static async Task<IResult> Login(LoginRequest x, AppDb db, PasswordService passwords, TokenService tokens) {
        var email = x.Email.Trim().ToLowerInvariant();
        var user = await db.Users.SingleOrDefaultAsync(u => u.Email == email);
        if (user is null || !passwords.Verify(x.Password, user.PasswordHash)) return Results.Unauthorized();
        return Results.Ok(new AuthResponse(tokens.Create(user), new { user.Id, user.DisplayName, user.Email }));
    }

    private static async Task<IResult> Me(CurrentUser current, AppDb db) {
        var user = await db.Users.FindAsync(current.Id);
        return user is null ? Results.Unauthorized() : Results.Ok(new { user.Id, user.DisplayName, user.Email });
    }

    private static async Task<IResult> ListFunds(CurrentUser current, AppDb db) {
        var data = await db.FundMembers.Where(m => m.UserId == current.Id).OrderBy(m => m.Fund.Name).Select(m => new { m.FundId, m.Fund.Name, m.Fund.InviteCode, m.Role, MemberCount = m.Fund.Members.Count }).ToListAsync();
        return Results.Ok(data);
    }

    private static async Task<IResult> CreateFund(CreateFundRequest x, CurrentUser current, AppDb db) {
        if (string.IsNullOrWhiteSpace(x.Name)) return Results.BadRequest(new { message = "Tên quỹ không được trống." });
        var fund = new Fund { Name = x.Name.Trim(), CreatedBy = current.Id, InviteCode = await UniqueInviteCode(db) };
        db.Funds.Add(fund);
        db.FundMembers.Add(new FundMember { Fund = fund, UserId = current.Id, Role = Roles.Owner });
        AddDefaults(db, fund.Id);
        await db.SaveChangesAsync();
        return Results.Created($"/api/funds/{fund.Id}", new { fund.Id, fund.Name, fund.InviteCode, Role = Roles.Owner });
    }

    private static async Task<IResult> JoinFund(JoinFundRequest x, CurrentUser current, AppDb db) {
        var code = x.InviteCode.Trim().Replace(" ", "").ToUpperInvariant();
        var fund = await db.Funds.SingleOrDefaultAsync(f => f.InviteCode == code);
        if (fund is null) return Results.NotFound(new { message = "Mã mời không đúng." });
        var existing = await db.FundMembers.SingleOrDefaultAsync(m => m.FundId == fund.Id && m.UserId == current.Id);
        if (existing is null) { existing = new FundMember { FundId = fund.Id, UserId = current.Id, Role = Roles.Member }; db.FundMembers.Add(existing); await db.SaveChangesAsync(); }
        return Results.Ok(new { fund.Id, fund.Name, fund.InviteCode, existing.Role });
    }

    private static async Task<IResult> GetFund(Guid fundId, FundAccess access, AppDb db) {
        var member = await access.Require(fundId);
        var fund = await db.Funds.Where(x => x.Id == fundId).Select(x => new { x.Id, x.Name, x.InviteCode, member.Role, MemberCount = x.Members.Count }).SingleAsync();
        return Results.Ok(fund);
    }

    private static async Task<IResult> RenameFund(Guid fundId, CreateFundRequest x, FundAccess access, AppDb db) {
        await access.Require(fundId, Roles.Owner, Roles.Admin);
        var fund = await db.Funds.FindAsync(fundId); if (fund is null) return Results.NotFound();
        fund.Name = x.Name.Trim(); await db.SaveChangesAsync(); return Results.Ok(fund);
    }

    private static async Task<IResult> DeleteFund(Guid fundId, FundAccess access, CurrentUser current, AppDb db) {
        await access.Require(fundId, Roles.Owner);
        var fund = await db.Funds.FindAsync(fundId); if (fund is null) return Results.NotFound();
        fund.IsDeleted = true; fund.DeletedAt = DateTimeOffset.UtcNow; fund.DeletedBy = current.Id; await db.SaveChangesAsync(); return Results.NoContent();
    }

    private static async Task<IResult> ListMembers(Guid fundId, FundAccess access, AppDb db) {
        await access.Require(fundId);
        return Results.Ok(await db.FundMembers.Where(m => m.FundId == fundId).OrderBy(m => m.User.DisplayName).Select(m => new { m.Id, m.UserId, m.User.DisplayName, m.User.Email, m.Role, m.JoinedAt }).ToListAsync());
    }

    private static async Task<IResult> ChangeRole(Guid fundId, Guid memberId, ChangeRoleRequest x, FundAccess access, AppDb db) {
        await access.Require(fundId, Roles.Owner, Roles.Admin);
        if (!new[] { Roles.Admin, Roles.Member, Roles.Viewer }.Contains(x.Role)) return Results.BadRequest(new { message = "Quyền không hợp lệ." });
        var member = await db.FundMembers.SingleOrDefaultAsync(m => m.Id == memberId && m.FundId == fundId); if (member is null) return Results.NotFound();
        if (member.Role == Roles.Owner) return Results.BadRequest(new { message = "Không thể đổi quyền chủ quỹ." });
        member.Role = x.Role; await db.SaveChangesAsync(); return Results.Ok(member);
    }

    private static async Task<IResult> RemoveMember(Guid fundId, Guid memberId, FundAccess access, AppDb db) {
        await access.Require(fundId, Roles.Owner, Roles.Admin);
        var member = await db.FundMembers.SingleOrDefaultAsync(m => m.Id == memberId && m.FundId == fundId); if (member is null) return Results.NotFound();
        if (member.Role == Roles.Owner) return Results.BadRequest(new { message = "Không thể xóa chủ quỹ." });
        db.FundMembers.Remove(member); await db.SaveChangesAsync(); return Results.NoContent();
    }

    private static async Task<string> UniqueInviteCode(AppDb db) {
        string code; do { code = $"QNM-{RandomNumberGenerator.GetInt32(0x100000, 0xFFFFFF):X6}"; } while (await db.Funds.IgnoreQueryFilters().AnyAsync(f => f.InviteCode == code)); return code;
    }

    private static void AddDefaults(AppDb db, Guid fundId) {
        var expense = new[] { ("Ăn uống", "utensils", "#FF8A34"), ("Đi lại", "directions_car", "#3E8DF5"), ("Nhà cửa", "home", "#52B86A"), ("Điện nước", "water_drop", "#55A9EF"), ("Giáo dục", "school", "#A858C7"), ("Y tế", "favorite", "#EF5B72"), ("Mua sắm", "shopping_bag", "#ED6F9A"), ("Giải trí", "sports_esports", "#F6B52B"), ("Khác", "more_horiz", "#8D96A7") };
        var income = new[] { ("Thu nhập", "payments", "#51B866"), ("Tiền tiếp", "volunteer_activism", "#42A5F5"), ("Hiệu suất", "workspace_premium", "#8E62CF"), ("Khác", "more_horiz", "#8D96A7") };
        db.Categories.AddRange(expense.Select(c => new QuyNhaMinh.Api.Domain.Category { FundId = fundId, Name = c.Item1, Icon = c.Item2, Color = c.Item3, Type = TransactionTypes.Expense, IsDefault = true }));
        db.Categories.AddRange(income.Select(c => new QuyNhaMinh.Api.Domain.Category { FundId = fundId, Name = c.Item1, Icon = c.Item2, Color = c.Item3, Type = TransactionTypes.Income, IsDefault = true }));
        db.MoneyAccounts.Add(new MoneyAccount { FundId = fundId, Name = "Tiền mặt", Type = "cash" });
    }
}
