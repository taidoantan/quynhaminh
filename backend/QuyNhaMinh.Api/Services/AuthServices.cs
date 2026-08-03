using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Security.Cryptography;
using System.Text;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using QuyNhaMinh.Api.Data;
using QuyNhaMinh.Api.Domain;

namespace QuyNhaMinh.Api.Services;

public sealed class PasswordService {
    private const int Iterations = 210_000;
    public string Hash(string password) {
        var salt = RandomNumberGenerator.GetBytes(16);
        var hash = Rfc2898DeriveBytes.Pbkdf2(password, salt, Iterations, HashAlgorithmName.SHA256, 32);
        return $"{Iterations}.{Convert.ToBase64String(salt)}.{Convert.ToBase64String(hash)}";
    }
    public bool Verify(string password, string encoded) {
        try {
            var p = encoded.Split('.');
            var expected = Convert.FromBase64String(p[2]);
            var actual = Rfc2898DeriveBytes.Pbkdf2(password, Convert.FromBase64String(p[1]), int.Parse(p[0]), HashAlgorithmName.SHA256, expected.Length);
            return CryptographicOperations.FixedTimeEquals(actual, expected);
        } catch { return false; }
    }
}

public sealed class TokenService(IConfiguration configuration) {
    public string Create(QuyNhaMinh.Api.Domain.User user) {
        var key = configuration["Jwt:Key"] ?? throw new InvalidOperationException("Jwt:Key is missing");
        if (Encoding.UTF8.GetByteCount(key) < 32) throw new InvalidOperationException("Jwt:Key must contain at least 32 bytes");
        var claims = new[] { new Claim(JwtRegisteredClaimNames.Sub, user.Id.ToString()), new Claim(ClaimTypes.NameIdentifier, user.Id.ToString()), new Claim(ClaimTypes.Name, user.DisplayName), new Claim(ClaimTypes.Email, user.Email) };
        var credentials = new SigningCredentials(new SymmetricSecurityKey(Encoding.UTF8.GetBytes(key)), SecurityAlgorithms.HmacSha256);
        var token = new JwtSecurityToken(configuration["Jwt:Issuer"], configuration["Jwt:Audience"], claims, expires: DateTime.UtcNow.AddDays(14), signingCredentials: credentials);
        return new JwtSecurityTokenHandler().WriteToken(token);
    }
}

public sealed class CurrentUser(IHttpContextAccessor accessor) {
    public Guid Id => Guid.TryParse(accessor.HttpContext?.User.FindFirstValue(ClaimTypes.NameIdentifier), out var id) ? id : throw new UnauthorizedAccessException();
}

public sealed class FundAccess(QuyNhaMinh.Api.Data.AppDb db, CurrentUser currentUser) {
    public Task<FundMember?> Membership(Guid fundId) => db.FundMembers.Include(x => x.User).SingleOrDefaultAsync(x => x.FundId == fundId && x.UserId == currentUser.Id);
    public async Task<FundMember> Require(Guid fundId, params string[] roles) {
        var member = await Membership(fundId) ?? throw new ForbiddenException("Bạn không thuộc quỹ này");
        if (roles.Length > 0 && !roles.Contains(member.Role)) throw new ForbiddenException("Bạn không có quyền thực hiện thao tác này");
        return member;
    }
    public Task<bool> CanWrite(Guid fundId) => db.FundMembers.AnyAsync(x => x.FundId == fundId && x.UserId == currentUser.Id && x.Role != Roles.Viewer);
}

public sealed class ForbiddenException(string message) : Exception(message);
