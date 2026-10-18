// In-memory stand-in for [PendingSyncQueueStore], used across widget tests
// so sync-queue behavior can be exercised without a real sqflite database.
//
// Mocking here is at the plugin boundary only, per `coding-standards.md`'s
// "mock at the network/DB boundary only" testing convention.

import 'package:elang/shared/models/pending_sync_entry.dart';
import 'package:elang/shared/services/pending_sync_queue_store.dart';

class FakePendingSyncQueueStore implements PendingSyncQueueStore {
  final List<PendingSyncEntry> _entries = [];

  @override
  Future<void> enqueue(PendingSyncEntry entry) async {
    _entries.add(entry);
  }

  @override
  Future<List<PendingSyncEntry>> listPending() async => List.of(_entries);

  @override
  Future<void> remove(String attemptId) async {
    _entries.removeWhere((e) => e.attemptId == attemptId);
  }

  @override
  Future<int> count() async => _entries.length;
}
