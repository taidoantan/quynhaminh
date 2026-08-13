using Microsoft.EntityFrameworkCore;

namespace QuyNhaMinh.Api.Data;

/// <summary>Creates the application schema in Supabase, whose database already has system tables.</summary>
public static class SupabaseSchema {
    public static Task EnsureAsync(AppDb db) => db.Database.ExecuteSqlRawAsync("""
CREATE TABLE IF NOT EXISTS "Users" ("Id" uuid PRIMARY KEY, "DisplayName" text NOT NULL, "Email" text NOT NULL, "PasswordHash" text NOT NULL, "CreatedAt" timestamptz NOT NULL);
CREATE UNIQUE INDEX IF NOT EXISTS "IX_Users_Email" ON "Users" ("Email");
CREATE TABLE IF NOT EXISTS "Funds" ("Id" uuid PRIMARY KEY, "Name" text NOT NULL, "InviteCode" text NOT NULL, "CreatedBy" uuid NOT NULL, "CreatedAt" timestamptz NOT NULL, "IsDeleted" boolean NOT NULL, "DeletedAt" timestamptz NULL, "DeletedBy" uuid NULL);
CREATE UNIQUE INDEX IF NOT EXISTS "IX_Funds_InviteCode" ON "Funds" ("InviteCode");
CREATE TABLE IF NOT EXISTS "FundMembers" ("Id" uuid PRIMARY KEY, "FundId" uuid NOT NULL REFERENCES "Funds"("Id") ON DELETE CASCADE, "UserId" uuid NOT NULL REFERENCES "Users"("Id") ON DELETE CASCADE, "Role" text NOT NULL, "JoinedAt" timestamptz NOT NULL);
CREATE UNIQUE INDEX IF NOT EXISTS "IX_FundMembers_FundId_UserId" ON "FundMembers" ("FundId", "UserId");
CREATE TABLE IF NOT EXISTS "Categories" ("Id" uuid PRIMARY KEY, "FundId" uuid NOT NULL, "Name" text NOT NULL, "Type" text NOT NULL, "Icon" text NOT NULL, "Color" text NOT NULL, "IsDefault" boolean NOT NULL, "IsDeleted" boolean NOT NULL, "DeletedAt" timestamptz NULL, "DeletedBy" uuid NULL);
CREATE UNIQUE INDEX IF NOT EXISTS "IX_Categories_FundId_Type_Name" ON "Categories" ("FundId", "Type", "Name");
CREATE TABLE IF NOT EXISTS "MoneyAccounts" ("Id" uuid PRIMARY KEY, "FundId" uuid NOT NULL, "Name" text NOT NULL, "Type" text NOT NULL, "InitialBalance" numeric(18,2) NOT NULL, "Currency" text NOT NULL, "IsDeleted" boolean NOT NULL, "DeletedAt" timestamptz NULL, "DeletedBy" uuid NULL);
CREATE TABLE IF NOT EXISTS "Transactions" ("Id" uuid PRIMARY KEY, "FundId" uuid NOT NULL, "CreatedBy" uuid NOT NULL, "CategoryId" uuid NOT NULL, "AccountId" uuid NOT NULL, "Type" text NOT NULL, "Amount" numeric(18,2) NOT NULL, "TransactionDate" timestamp NOT NULL, "Note" text NOT NULL, "Merchant" text NOT NULL, "ReceiptUrl" text NULL, "CreatedAt" timestamptz NOT NULL, "UpdatedAt" timestamptz NOT NULL, "IsDeleted" boolean NOT NULL, "DeletedAt" timestamptz NULL, "DeletedBy" uuid NULL);
CREATE TABLE IF NOT EXISTS "Budgets" ("Id" uuid PRIMARY KEY, "FundId" uuid NOT NULL, "CategoryId" uuid NOT NULL, "Year" integer NOT NULL, "Month" integer NOT NULL, "LimitAmount" numeric(18,2) NOT NULL, "WarningPercent" numeric NOT NULL);
CREATE UNIQUE INDEX IF NOT EXISTS "IX_Budgets_FundId_CategoryId_Year_Month" ON "Budgets" ("FundId", "CategoryId", "Year", "Month");
CREATE TABLE IF NOT EXISTS "Reminders" ("Id" uuid PRIMARY KEY, "FundId" uuid NOT NULL, "Title" text NOT NULL, "ExpectedAmount" numeric(18,2) NULL, "NextDueAt" timestamp NOT NULL, "Recurrence" text NOT NULL, "IsEnabled" boolean NOT NULL, "IsDeleted" boolean NOT NULL, "DeletedAt" timestamptz NULL, "DeletedBy" uuid NULL);
CREATE TABLE IF NOT EXISTS "Receipts" ("Id" uuid PRIMARY KEY, "FundId" uuid NOT NULL, "UploadedBy" uuid NOT NULL, "TransactionId" uuid NULL, "ImageUrl" text NOT NULL, "Provider" text NOT NULL, "RawResult" text NOT NULL, "Confidence" numeric NOT NULL, "CreatedAt" timestamptz NOT NULL);
CREATE TABLE IF NOT EXISTS "AuditLogs" ("Id" uuid PRIMARY KEY, "FundId" uuid NULL, "UserId" uuid NOT NULL, "Action" text NOT NULL, "EntityType" text NOT NULL, "EntityId" uuid NULL, "DataJson" text NOT NULL, "CreatedAt" timestamptz NOT NULL);
""");
}