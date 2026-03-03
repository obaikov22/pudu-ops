import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/template.dart';
import 'storage_providers.dart';

final _uuid = const Uuid();

class TemplatesController extends Notifier<List<Template>> {
  @override
  List<Template> build() {
    return _load();
  }

  List<Template> _load() {
    final storage = ref.read(storageServiceProvider);
    final templates = storage.templatesBox.values.toList();

    templates.sort((a, b) => a.startMinutes.compareTo(b.startMinutes));
    return templates;
  }

  void refresh() {
    state = _load();
  }

  Future<void> addOrUpdate(Template template) async {
    final storage = ref.read(storageServiceProvider);
    await storage.templatesBox.put(template.id, template);
    refresh();
  }

  Future<void> create({
    required String name,
    required String robotId,
    required String floor,
    required int startMinutes,
    required List<TemplateTask> tasks,
  }) async {
    final storage = ref.read(storageServiceProvider);

    final template = Template(
      id: _uuid.v4(),
      name: name,
      robotId: robotId,
      floor: floor,
      tasks: tasks,
      startMinutes: startMinutes,
      enabled: true,
    );

    await storage.templatesBox.put(template.id, template);
    refresh();
  }

  Future<void> toggleEnabled(Template template) async {
    final storage = ref.read(storageServiceProvider);
    final updated = template.copyWith(enabled: !template.enabled);
    await storage.templatesBox.put(updated.id, updated);
    refresh();
  }

  Future<void> delete(String id) async {
    final storage = ref.read(storageServiceProvider);
    await storage.templatesBox.delete(id);
    refresh();
  }
}

final templatesControllerProvider =
    NotifierProvider<TemplatesController, List<Template>>(
  TemplatesController.new,
);