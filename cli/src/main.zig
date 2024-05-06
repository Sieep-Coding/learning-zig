const std = @import("std");
const Allocator = std.mem.Allocator;

const Transaction = struct {
    description: []const u8,
    amount: f64,
    date: i64,
    category: []const u8,
};

const Category = struct {
    name: []const u8,
    budget: f64,
    transactions: std.ArrayList(Transaction),
};

const FinanceTracker = struct {
    const Self = @This();

    categories: std.ArrayList(Category),
    allocator: Allocator,

    fn init(allocator: Allocator) Self {
        return Self{
            .categories = std.ArrayList(Category).init(allocator),
            .allocator = allocator,
        };
    }

    fn deinit(self: *Self) void {
        for (self.categories.items) |*category| {
            category.transactions.deinit();
            self.allocator.free(category.name);
        }
        self.categories.deinit();
    }

    fn addCategory(self: *Self, name: []const u8, budget: f64) !void {
        try self.categories.append(Category{
            .name = try self.allocator.dupe(u8, name),
            .budget = budget,
            .transactions = std.ArrayList(Transaction).init(self.allocator),
        });
    }

    fn addTransaction(self: *Self, category_name: []const u8, description: []const u8, amount: f64, date: i64) !void {
        for (self.categories.items) |*category| {
            if (std.mem.eql(u8, category.name, category_name)) {
                try category.transactions.append(Transaction{
                    .description = try self.allocator.dupe(u8, description),
                    .amount = amount,
                    .date = date,
                    .category = try self.allocator.dupe(u8, category.name),
                });
                return;
            }
        }
        return error.CategoryNotFound;
    }

    fn printReport(self: *Self) void {
        const stdout = std.io.getStdOut().writer();
        for (self.categories.items) |category| {
            var total_spent: f64 = 0.0;
            stdout.print("Category: {s}\n", .{category.name}) catch unreachable;
            stdout.print("Budget: {d:.2}\n", .{category.budget}) catch unreachable;
            stdout.print("Transactions:\n", .{}) catch unreachable;
            for (category.transactions.items) |transaction| {
                total_spent += transaction.amount;
                const date_time = std.time.nanoToBigSec(transaction.date);
                const year = @as(u16, @intCast(date_time.secs / std.time.sec_per_year + 1970));
                const month = @intCast(u8, (date_time.secs / std.time.sec_per_month) % 12 + 1);
                const day = @intCast(u8, (date_time.secs / std.time.sec_per_day) % std.time.days_per_month(month, year) + 1);
                stdout.print("{d}/{d}/{d} - {s}: {d:.2}\n", .{
                    month,
                    day,
                    year,
                    transaction.description,
                    transaction.amount,
                }) catch unreachable;
            }
            stdout.print("Total Spent: {d:.2}\n", .{total_spent}) catch unreachable;
            stdout.print("Remaining Budget: {d:.2}\n\n", .{category.budget - total_spent}) catch unreachable;
        }
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var tracker = FinanceTracker.init(allocator);
    defer tracker.deinit();

    try tracker.addCategory("Food", 500.0);
    try tracker.addCategory("Transportation", 200.0);
    try tracker.addCategory("Entertainment", 150.0);

    const now = std.time.nanoTimestamp();
    try tracker.addTransaction("Food", "Groceries", 75.25, now);
    try tracker.addTransaction("Food", "Dining Out", 35.80, now);
    try tracker.addTransaction("Transportation", "Gas", 40.50, now);
    try tracker.addTransaction("Entertainment", "Movie Tickets", 20.00, now);

    tracker.printReport();
}
