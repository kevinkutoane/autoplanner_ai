/// Generic repository contract.
///
/// All data access flows through this interface. Implementations
/// can target Hive (local), Firestore (cloud), or in-memory (test).
abstract class Repository<T> {
  /// Get all items.
  Future<List<T>> getAll();

  /// Get a single item by ID.
  Future<T?> getById(String id);

  /// Add or update an item.
  Future<void> put(String id, T item);

  /// Delete an item by ID.
  Future<void> delete(String id);

  /// Delete all items.
  Future<void> clear();

  /// Initialize (open connections, etc.)
  Future<void> init();
}
