using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;

var builder = WebApplication.CreateBuilder(args);
builder.Services.AddDbContext<AppDb>(o => o.UseSqlite(builder.Configuration.GetConnectionString("Default")));
builder.Services.AddHttpClient();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();
builder.Services.AddCors(o => o.AddDefaultPolicy(p => p.AllowAnyOrigin().AllowAnyHeader().AllowAnyMethod()));
var jwtKey = builder.Configuration["Jwt:Key"]!;
builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme).AddJwtBearer(o =>
{
    o.TokenValidationParameters = new TokenValidationParameters {
        ValidateIssuer = true, ValidateAudience = true, ValidateLifetime = true, ValidateIssuerSigningKey = true,
        ValidIssuer = builder.Configuration["Jwt:Issuer"], ValidAudience = builder.Configuration["Jwt:Audience"],
        IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwtKey))
    };
});
builder.Services.AddAuthorization();
var app = builder.Build();
app.UseCors(); app.UseSwagger(); app.UseSwaggerUI(); app.UseAuthentication(); app.UseAuthorization();
using (var scope = app.Services.CreateScope()) { var db = scope.ServiceProvider.GetRequiredService<AppDb>(); db.Database.EnsureCreated(); Seed(db); }

app.MapGet("/health", () => Results.Ok(new { status = "ok", app = "Quỹ Nhà Mình" }));

app.MapPost("/auth/register", async (RegisterDto x, AppDb db) => {
    if (await db.Users.AnyAsync(u => u.Email == x.Email.Trim().ToLower())) return Results.BadRequest("Email đã tồn tại");
    var salt = Convert.ToHexString(RandomNumberGenerator.GetBytes(16));
    var user = new User { Id = Guid.NewGuid(), Name = x.Name.Trim(), Email = x.Email.Trim().ToLower(), Salt = salt, PasswordHash = Hash(x.Password, salt) };
    db.Users.Add(user); await db.SaveChangesAsync(); return Results.Ok(new { token = Token(user), user = new { user.Id, user.Name, user.Email } });
});
app.MapPost("/auth/login", async (LoginDto x, AppDb db) => {
    var user = await db.Users.SingleOrDefaultAsync(u => u.Email == x.Email.Trim().ToLower());
    if (user is null || user.PasswordHash != Hash(x.Password, user.Salt)) return Results.Unauthorized();
    return Results.Ok(new { token = Token(user), user = new { user.Id, user.Name, user.Email } });
});

var auth = app.MapGroup("/api").RequireAuthorization();
auth.MapPost("/families", async (CreateFamilyDto x, ClaimsPrincipal cp, AppDb db) => {
    var uid = UserId(cp); var family = new Family { Id = Guid.NewGuid(), Name = x.Name.Trim(), InviteCode = RandomNumberGenerator.GetInt32(100000,999999).ToString() };
    db.Families.Add(family); db.Members.Add(new FamilyMember { Id=Guid.NewGuid(), FamilyId=family.Id, UserId=uid, Role="admin" }); await db.SaveChangesAsync();
    return Results.Ok(family);
});
auth.MapPost("/families/join", async (JoinFamilyDto x, ClaimsPrincipal cp, AppDb db) => {
    var fam = await db.Families.SingleOrDefaultAsync(f => f.InviteCode == x.InviteCode); if (fam is null) return Results.NotFound("Mã mời không đúng");
    var uid=UserId(cp); if(!await db.Members.AnyAsync(m=>m.FamilyId==fam.Id&&m.UserId==uid)) { db.Members.Add(new FamilyMember { Id=Guid.NewGuid(), FamilyId=fam.Id, UserId=uid, Role="member"}); await db.SaveChangesAsync(); }
    return Results.Ok(fam);
});
auth.MapGet("/families", async (ClaimsPrincipal cp, AppDb db) => {
    var uid=UserId(cp); return Results.Ok(await db.Members.Where(m=>m.UserId==uid).Select(m=>new { m.FamilyId, m.Family!.Name, m.Family.InviteCode, m.Role }).ToListAsync());
});
auth.MapGet("/categories", async (string type, AppDb db) => Results.Ok(await db.Categories.Where(c=>c.Type==type).OrderBy(c=>c.Name).ToListAsync()));
auth.MapPost("/transactions", async (TransactionDto x, ClaimsPrincipal cp, AppDb db) => {
    var uid=UserId(cp); if(!await db.Members.AnyAsync(m=>m.FamilyId==x.FamilyId&&m.UserId==uid)) return Results.Forbid();
    var t=new MoneyTransaction { Id=Guid.NewGuid(), FamilyId=x.FamilyId, UserId=uid, Type=x.Type, Category=x.Category, Amount=x.Amount, Date=x.Date, Note=x.Note??"", Merchant=x.Merchant??"", ReceiptImageBase64=x.ReceiptImageBase64, CreatedAt=DateTime.UtcNow };
    db.Transactions.Add(t); await db.SaveChangesAsync(); return Results.Ok(t);
});
auth.MapGet("/transactions", async (Guid familyId, DateTime? from, DateTime? to, ClaimsPrincipal cp, AppDb db) => {
    var uid=UserId(cp); if(!await db.Members.AnyAsync(m=>m.FamilyId==familyId&&m.UserId==uid)) return Results.Forbid();
    var q=db.Transactions.Where(t=>t.FamilyId==familyId); if(from!=null) q=q.Where(t=>t.Date>=from); if(to!=null) q=q.Where(t=>t.Date<=to);
    return Results.Ok(await q.OrderByDescending(t=>t.Date).ThenByDescending(t=>t.CreatedAt).Take(500).ToListAsync());
});
auth.MapGet("/summary", async (Guid familyId, int year, int month, ClaimsPrincipal cp, AppDb db) => {
    var uid=UserId(cp); if(!await db.Members.AnyAsync(m=>m.FamilyId==familyId&&m.UserId==uid)) return Results.Forbid();
    var start=new DateTime(year,month,1); var end=start.AddMonths(1); var q=db.Transactions.Where(t=>t.FamilyId==familyId&&t.Date>=start&&t.Date<end);
    var income=await q.Where(t=>t.Type=="income").SumAsync(t=>(decimal?)t.Amount)??0; var expense=await q.Where(t=>t.Type=="expense").SumAsync(t=>(decimal?)t.Amount)??0;
    var categories=await q.Where(t=>t.Type=="expense").GroupBy(t=>t.Category).Select(g=>new { category=g.Key, amount=g.Sum(x=>x.Amount)}).OrderByDescending(x=>x.amount).ToListAsync();
    return Results.Ok(new { income, expense, balance=income-expense, categories });
});
auth.MapPost("/receipts/analyze", async (ReceiptAnalyzeDto x, IHttpClientFactory factory, IConfiguration cfg) => {
    var key=Environment.GetEnvironmentVariable("GEMINI_API_KEY");
    if(string.IsNullOrWhiteSpace(key)) return Results.Problem("Backend chưa có GEMINI_API_KEY", statusCode:503);
    var comma=x.DataUrl.IndexOf(',');
    if(comma<0) return Results.BadRequest("Ảnh hóa đơn không hợp lệ");
    var metadata=x.DataUrl[..comma];
    var mime=metadata.StartsWith("data:") ? metadata[5..].Split(';')[0] : "image/jpeg";
    var imageData=x.DataUrl[(comma+1)..];
    var prompt="Đọc hóa đơn hoặc chứng từ Việt Nam. Trả về duy nhất JSON hợp lệ gồm: type (income hoặc expense), amount (số), date (ISO yyyy-MM-dd hoặc null), merchant (chuỗi hoặc null), category (chuỗi ngắn), note (chuỗi). Không dùng markdown.";
    var body=new { contents=new[]{new { role="user", parts=new object[]{new { text=prompt }, new { inline_data=new { mime_type=mime, data=imageData } }}}}, generationConfig=new { responseMimeType="application/json" }};
    var model=cfg["Gemini:Model"]??"gemini-3.5-flash";
    var client=factory.CreateClient(); client.DefaultRequestHeaders.Add("x-goog-api-key",key);
    var res=await client.PostAsJsonAsync($"https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent",body);
    var raw=await res.Content.ReadAsStringAsync();
    if(!res.IsSuccessStatusCode) return Results.Problem(raw,statusCode:(int)res.StatusCode);
    using var doc=JsonDocument.Parse(raw);
    var text=doc.RootElement.GetProperty("candidates")[0].GetProperty("content").GetProperty("parts")[0].GetProperty("text").GetString()?.Trim();
    if(string.IsNullOrWhiteSpace(text)) return Results.Problem("Gemini không trả về kết quả hóa đơn");
    if(text.StartsWith("```")){ text=text.Replace("```json","").Replace("```","").Trim(); }
    try { using var parsed=JsonDocument.Parse(text); return Results.Text(parsed.RootElement.GetRawText(),"application/json"); }
    catch(JsonException){ return Results.Problem("Gemini trả về dữ liệu không đúng định dạng JSON"); }
});
app.Run("http://0.0.0.0:5180");

string Token(User u){ var claims=new[]{new Claim(JwtRegisteredClaimNames.Sub,u.Id.ToString()),new Claim(ClaimTypes.Name,u.Name)}; var creds=new SigningCredentials(new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwtKey)),SecurityAlgorithms.HmacSha256); return new JwtSecurityTokenHandler().WriteToken(new JwtSecurityToken(builder.Configuration["Jwt:Issuer"],builder.Configuration["Jwt:Audience"],claims,expires:DateTime.UtcNow.AddDays(30),signingCredentials:creds)); }
static Guid UserId(ClaimsPrincipal cp)=>Guid.Parse(cp.FindFirstValue(JwtRegisteredClaimNames.Sub)??cp.FindFirstValue(ClaimTypes.NameIdentifier)!);
static string Hash(string p,string s)=>Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(p+s)));
static void Seed(AppDb db){ if(db.Categories.Any())return; string[] inc={"Tiền thu nhập","Tiền tiếp","Tiền hiệu suất","Tiền thưởng","Tiền khác"}; string[] exp={"Ăn uống","Đổ xăng","Học phí","Tiền điện","Tiền nước","Internet","Mua sắm","Y tế","Đi lại","Chi khác"}; db.Categories.AddRange(inc.Select(x=>new Category{Id=Guid.NewGuid(),Name=x,Type="income"})); db.Categories.AddRange(exp.Select(x=>new Category{Id=Guid.NewGuid(),Name=x,Type="expense"})); db.SaveChanges(); }

record RegisterDto(string Name,string Email,string Password); record LoginDto(string Email,string Password); record CreateFamilyDto(string Name); record JoinFamilyDto(string InviteCode);
record TransactionDto(Guid FamilyId,string Type,string Category,decimal Amount,DateTime Date,string? Note,string? Merchant,string? ReceiptImageBase64); record ReceiptAnalyzeDto(string DataUrl);
class AppDb(DbContextOptions<AppDb> o):DbContext(o){ public DbSet<User> Users=>Set<User>(); public DbSet<Family> Families=>Set<Family>(); public DbSet<FamilyMember> Members=>Set<FamilyMember>(); public DbSet<MoneyTransaction> Transactions=>Set<MoneyTransaction>(); public DbSet<Category> Categories=>Set<Category>(); protected override void OnModelCreating(ModelBuilder b){b.Entity<User>().HasIndex(x=>x.Email).IsUnique();b.Entity<Family>().HasIndex(x=>x.InviteCode).IsUnique();} }
class User{public Guid Id{get;set;} public string Name{get;set;}=""; public string Email{get;set;}=""; public string Salt{get;set;}=""; public string PasswordHash{get;set;}="";}
class Family{public Guid Id{get;set;} public string Name{get;set;}=""; public string InviteCode{get;set;}="";}
class FamilyMember{public Guid Id{get;set;} public Guid FamilyId{get;set;} public Family? Family{get;set;} public Guid UserId{get;set;} public User? User{get;set;} public string Role{get;set;}="member";}
class MoneyTransaction{public Guid Id{get;set;} public Guid FamilyId{get;set;} public Guid UserId{get;set;} public string Type{get;set;}="expense"; public string Category{get;set;}=""; public decimal Amount{get;set;} public DateTime Date{get;set;} public string Note{get;set;}=""; public string Merchant{get;set;}=""; public string? ReceiptImageBase64{get;set;} public DateTime CreatedAt{get;set;}}
class Category{public Guid Id{get;set;} public string Name{get;set;}=""; public string Type{get;set;}="expense";}
