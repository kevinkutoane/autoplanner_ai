/// Shared date-comparison helpers used across the app.
///
/// Centralizes calendar-day equality so changes propagate everywhere.
bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
