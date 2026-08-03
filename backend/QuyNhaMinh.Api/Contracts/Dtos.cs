namespace QuyNhaMinh.Api.Contracts;

public sealed record RegisterRequest(string DisplayName, string Email, string Password);
public sealed record LoginRequest(string Email, string Password);
public sealed record AuthResponse(string Token, object User);
public sealed record CreateFundRequest(string Name);
public sealed record JoinFundRequest(string InviteCode);
public sealed record ChangeRoleRequest(string Role);
public sealed record CategoryRequest(string Name, string Type, string Icon, string Color);
public sealed record MoneyAccountRequest(string Name, string Type, decimal InitialBalance, string Currency = "VND");
public sealed record TransactionRequest(Guid FundId, Guid CategoryId, Guid AccountId, string Type, decimal Amount, DateTime TransactionDate, string? Note, string? Merchant, string? ReceiptUrl);
public sealed record BudgetRequest(Guid CategoryId, int Year, int Month, decimal LimitAmount, decimal WarningPercent = 80);
public sealed record ReminderRequest(string Title, decimal? ExpectedAmount, DateTime NextDueAt, string Recurrence, bool IsEnabled = true);
public sealed record ReceiptAnalyzeRequest(Guid FundId, string DataUrl);
public sealed record ReceiptSuggestion(string Type, decimal Amount, string? Date, string? Merchant, string Category, string Note, decimal Confidence, IReadOnlyList<string> Warnings, string? ImageUrl);
public sealed record RestoreRequest(IReadOnlyList<Guid> Ids);
public sealed record BackupImportRequest(string Json);
