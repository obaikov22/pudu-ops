import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/storage_service.dart';

// Единственный инстанс StorageService для всего приложения
final _storageInstance = StorageService();

final storageServiceProvider = Provider<StorageService>((ref) {
  return _storageInstance;
});

final storageInitProvider = FutureProvider<void>((ref) async {
  final storage = ref.read(storageServiceProvider);
  await storage.init();
});