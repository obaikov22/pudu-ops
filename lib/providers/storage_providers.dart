import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/storage_service.dart';

/// The single StorageService instance, initialized in main() before runApp().
/// Set via [initStorageServiceProvider] — must be called before ProviderScope.
late final StorageService _storageInstance;

/// Call once in main() after StorageService.init() completes.
void initStorageServiceProvider(StorageService storage) {
  _storageInstance = storage;
}

final storageServiceProvider = Provider<StorageService>((ref) {
  return _storageInstance;
});
