namespace QuyNhaMinh.Api.Domain;

public interface IEntity { Guid Id { get; set; } }
public interface ISoftDelete { bool IsDeleted { get; set; } DateTimeOffset? DeletedAt { get; set; } Guid? DeletedBy { get; set; } }

public sealed class User : IEntity {
    public Guid Id { get; set; } = Guid.NewGuid();
    public string DisplayName { get; set; } = "";
    public string Email { get; set; } = "";
    public string PasswordHash { get; set; } = "";
    public DateTimeOffset CreatedAt { get; set; } = DateTimeOffset.UtcNow;
    public ICollection<FundMember> Memberships { get; set; } = [];
}

public sealed class Fund : IEntity, ISoftDelete {
    public Guid Id { get; set; } = Guid.NewGuid();
    public string Name { get; set; } = "";
    public string InviteCode { get; set; } = "";
    public Guid CreatedBy { get; set; }
    public DateTimeOffset CreatedAt { get; set; } = DateTimeOffset.UtcNow;
    public bool IsDeleted { get; set; }
    public DateTimeOffset? DeletedAt { get; set; }
    public Guid? DeletedBy { get; set; }
    public ICollection<FundMember> Members { get; set; } = [];
}

public sealed class FundMember : IEntity {
    public Guid Id { get; set; } = Guid.NewGuid();
    public Guid FundId { get; set; }
    public Fund Fund { get; set; } = null!;
    public Guid UserId { get; set; }
    public User User { get; set; } = null!;
    public string Role { get; set; } = Roles.Member;
    public DateTimeOffset JoinedAt { get; set; } = DateTimeOffset.UtcNow;
}

public sealed class Category : IEntity, ISoftDelete {
    public Guid Id { get; set; } = Guid.NewGuid();
    public Guid FundId { get; set; }
    public string Name { get; set; } = "";
    public string Type { get; set; } = TransactionTypes.Expense;
    public string Icon { get; set; } = "category";
    public string Color { get; set; } = "#2674EA";
    public bool IsDefault { get; set; }
    public bool IsDeleted { get; set; }
    public DateTimeOffset? DeletedAt { get; set; }
    public Guid? DeletedBy { get; set; }
}

public sealed class MoneyAccount : IEntity, ISoftDelete {
    public Guid Id { get; set; } = Guid.NewGuid();
    public Guid FundId { get; set; }
    public string Name { get; set; } = "";
    public string Type { get; set; } = "cash";
    public decimal InitialBalance { get; set; }
    public string Currency { get; set; } = "VND";
    public bool IsDeleted { get; set; }
    public DateTimeOffset? DeletedAt { get; set; }
    public Guid? DeletedBy { get; set; }
}

public sealed class MoneyTransaction : IEntity, ISoftDelete {
    public Guid Id { get; set; } = Guid.NewGuid();
    public Guid FundId { get; set; }
    public Guid CreatedBy { get; set; }
    public Guid CategoryId { get; set; }
    public Guid AccountId { get; set; }
    public string Type { get; set; } = TransactionTypes.Expense;
    public decimal Amount { get; set; }
    public DateTime TransactionDate { get; set; }
    public string Note { get; set; } = "";
    public string Merchant { get; set; } = "";
    public string? ReceiptUrl { get; set; }
    public DateTimeOffset CreatedAt { get; set; } = DateTimeOffset.UtcNow;
    public DateTimeOffset UpdatedAt { get; set; } = DateTimeOffset.UtcNow;
    public bool IsDeleted { get; set; }
    public DateTimeOffset? DeletedAt { get; set; }
    public Guid? DeletedBy { get; set; }
}

public sealed class Budget : IEntity {
    public Guid Id { get; set; } = Guid.NewGuid();
    public Guid FundId { get; set; }
    public Guid CategoryId { get; set; }
    public int Year { get; set; }
    public int Month { get; set; }
    public decimal LimitAmount { get; set; }
    public decimal WarningPercent { get; set; } = 80;
}

public sealed class Reminder : IEntity, ISoftDelete {
    public Guid Id { get; set; } = Guid.NewGuid();
    public Guid FundId { get; set; }
    public string Title { get; set; } = "";
    public decimal? ExpectedAmount { get; set; }
    public DateTime NextDueAt { get; set; }
    public string Recurrence { get; set; } = "none";
    public bool IsEnabled { get; set; } = true;
    public bool IsDeleted { get; set; }
    public DateTimeOffset? DeletedAt { get; set; }
    public Guid? DeletedBy { get; set; }
}

public sealed class Receipt : IEntity {
    public Guid Id { get; set; } = Guid.NewGuid();
    public Guid FundId { get; set; }
    public Guid UploadedBy { get; set; }
    public Guid? TransactionId { get; set; }
    public string ImageUrl { get; set; } = "";
    public string Provider { get; set; } = "gemini";
    public string RawResult { get; set; } = "";
    public decimal Confidence { get; set; }
    public DateTimeOffset CreatedAt { get; set; } = DateTimeOffset.UtcNow;
}

public sealed class AuditLog : IEntity {
    public Guid Id { get; set; } = Guid.NewGuid();
    public Guid? FundId { get; set; }
    public Guid UserId { get; set; }
    public string Action { get; set; } = "";
    public string EntityType { get; set; } = "";
    public Guid? EntityId { get; set; }
    public string DataJson { get; set; } = "{}";
    public DateTimeOffset CreatedAt { get; set; } = DateTimeOffset.UtcNow;
}

public static class Roles { public const string Owner = "owner"; public const string Admin = "admin"; public const string Member = "member"; public const string Viewer = "viewer"; }
public static class TransactionTypes { public const string Income = "income"; public const string Expense = "expense"; }
