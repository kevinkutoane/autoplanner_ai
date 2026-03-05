import 'package:hive/hive.dart';
import 'repository.dart';

/// Hive-backed implementation of [Repository].
///
/// Handles all local persistence. When migrating to Firestore,
/// create a `FirestoreRepository<T>` that implements the same
/// [Repository] interface — no controller code changes needed.
class HiveRepository<T extends HiveObject> implements Repository<T> {
  final String boxName;
  Box<T>? _box;

  HiveRepository(this.boxName);

  bool get isReady => _box != null && _box!.isOpen;

  @override
  Future<void> init() async {
    if (!isReady) {
      _box = await Hive.openBox<T>(boxName);
    }
  }

  @override
  Future<List<T>> getAll() async {
    await _ensureOpen();
    return _box!.values.toList();
  }

  @override
  Future<T?> getById(String id) async {
    await _ensureOpen();
    return _box!.get(id);
  }

  @override
  Future<void> put(String id, T item) async {
    await _ensureOpen();
    await _box!.put(id, item);
  }

  @override
  Future<void> delete(String id) async {
    await _ensureOpen();
    await _box!.delete(id);
  }

  @override
  Future<void> clear() async {
    await _ensureOpen();
    await _box!.clear();
  }

  Future<void> _ensureOpen() async {
    if (!isReady) await init();
  }
}
