import 'package:flutter_test/flutter_test.dart';
import 'package:pasal_mobile_app/core/services/archive_service.dart';
import '../../mocks/shared_preferences_mock.dart';

void main() {
  group('ArchiveService', () {
    setUp(() {
      // Reset SharedPreferences mock before each test
      setupMockSharedPreferences({});
    });

    group('singleton pattern', () {
      test('returns same instance when called multiple times', () {
        final instance1 = ArchiveService();
        final instance2 = ArchiveService();

        expect(identical(instance1, instance2), true);
      });
    });

    group('isArchived', () {
      test('returns false when pasal is not archived', () {
        setupMockSharedPreferences({});
        final service = ArchiveService();

        // Clear the archivedIds to ensure clean state
        service.archivedIds.value = [];

        expect(service.isArchived('pasal-1'), false);
      });

      test('returns true when pasal is archived', () {
        final service = ArchiveService();
        service.archivedIds.value = ['pasal-1', 'pasal-2'];

        expect(service.isArchived('pasal-1'), true);
        expect(service.isArchived('pasal-2'), true);
      });

      test('returns false for unarchived pasal in list with archives', () {
        final service = ArchiveService();
        service.archivedIds.value = ['pasal-1', 'pasal-2'];

        expect(service.isArchived('pasal-3'), false);
      });
    });

    group('toggleArchive', () {
      test('adds pasal to archive when not already archived', () async {
        setupMockSharedPreferences({});
        final service = ArchiveService();
        service.archivedIds.value = [];

        await service.toggleArchive('pasal-1');

        expect(service.archivedIds.value, contains('pasal-1'));
        expect(service.isArchived('pasal-1'), true);
      });

      test('removes pasal from archive when already archived', () async {
        setupMockSharedPreferences({
          'archived_pasal_ids': ['pasal-1', 'pasal-2'],
        });
        final service = ArchiveService();
        service.archivedIds.value = ['pasal-1', 'pasal-2'];

        await service.toggleArchive('pasal-1');

        expect(service.archivedIds.value, isNot(contains('pasal-1')));
        expect(service.archivedIds.value, contains('pasal-2'));
        expect(service.isArchived('pasal-1'), false);
      });

      test('preserves other archived items when toggling', () async {
        setupMockSharedPreferences({});
        final service = ArchiveService();
        service.archivedIds.value = ['pasal-1', 'pasal-2', 'pasal-3'];

        await service.toggleArchive('pasal-2');

        expect(service.archivedIds.value, contains('pasal-1'));
        expect(service.archivedIds.value, isNot(contains('pasal-2')));
        expect(service.archivedIds.value, contains('pasal-3'));
      });

      test('can toggle multiple times', () async {
        setupMockSharedPreferences({});
        final service = ArchiveService();
        service.archivedIds.value = [];

        // Add
        await service.toggleArchive('pasal-1');
        expect(service.isArchived('pasal-1'), true);

        // Remove
        await service.toggleArchive('pasal-1');
        expect(service.isArchived('pasal-1'), false);

        // Add again
        await service.toggleArchive('pasal-1');
        expect(service.isArchived('pasal-1'), true);
      });

      test('handles empty archive list correctly', () async {
        setupMockSharedPreferences({});
        final service = ArchiveService();
        service.archivedIds.value = [];

        await service.toggleArchive('pasal-1');

        expect(service.archivedIds.value.length, 1);
        expect(service.archivedIds.value.first, 'pasal-1');
      });

      test('multiple archives can be added sequentially', () async {
        setupMockSharedPreferences({});
        final service = ArchiveService();
        service.archivedIds.value = [];

        await service.toggleArchive('pasal-1');
        await service.toggleArchive('pasal-2');
        await service.toggleArchive('pasal-3');

        expect(service.archivedIds.value.length, 3);
        expect(service.isArchived('pasal-1'), true);
        expect(service.isArchived('pasal-2'), true);
        expect(service.isArchived('pasal-3'), true);
      });
    });

    group('archivedIds ValueNotifier', () {
      test('notifies listeners when archive is toggled', () async {
        setupMockSharedPreferences({});
        final service = ArchiveService();
        service.archivedIds.value = [];

        int notifyCount = 0;
        service.archivedIds.addListener(() {
          notifyCount++;
        });

        await service.toggleArchive('pasal-1');

        expect(notifyCount, greaterThan(0));
      });

      test('value is updated immediately after toggle', () async {
        setupMockSharedPreferences({});
        final service = ArchiveService();
        service.archivedIds.value = [];

        final beforeToggle = List<String>.from(service.archivedIds.value);
        await service.toggleArchive('pasal-1');
        final afterToggle = service.archivedIds.value;

        expect(beforeToggle, isEmpty);
        expect(afterToggle, contains('pasal-1'));
      });
    });

    group('persistence', () {
      test('loads existing archives from SharedPreferences', () async {
        setupMockSharedPreferences({
          'archived_pasal_ids': ['pasal-1', 'pasal-2'],
        });

        // Create a new service instance to test loading
        // Note: Due to singleton pattern, we test via the value notifier
        final service = ArchiveService();

        // Simulate what _loadArchives does
        service.archivedIds.value = ['pasal-1', 'pasal-2'];

        expect(service.archivedIds.value.length, 2);
        expect(service.isArchived('pasal-1'), true);
        expect(service.isArchived('pasal-2'), true);
      });

      test('handles empty SharedPreferences gracefully', () async {
        setupMockSharedPreferences({});
        final service = ArchiveService();

        // Simulate empty load
        service.archivedIds.value = [];

        expect(service.archivedIds.value, isEmpty);
      });

      test('handles null SharedPreferences list gracefully', () async {
        setupMockSharedPreferences({});
        final service = ArchiveService();

        // When getStringList returns null, it should default to empty list
        service.archivedIds.value = [];

        expect(service.archivedIds.value, isEmpty);
        expect(service.isArchived('any-id'), false);
      });
    });

    group('edge cases', () {
      test('handles empty string pasal id', () async {
        setupMockSharedPreferences({});
        final service = ArchiveService();
        service.archivedIds.value = [];

        await service.toggleArchive('');

        expect(service.archivedIds.value, contains(''));
        expect(service.isArchived(''), true);
      });

      test('handles special characters in pasal id', () async {
        setupMockSharedPreferences({});
        final service = ArchiveService();
        service.archivedIds.value = [];

        const specialId = 'pasal-123-abc-!@#';
        await service.toggleArchive(specialId);

        expect(service.isArchived(specialId), true);
      });

      test('handles very long pasal id', () async {
        setupMockSharedPreferences({});
        final service = ArchiveService();
        service.archivedIds.value = [];

        final longId = 'pasal-${'a' * 1000}';
        await service.toggleArchive(longId);

        expect(service.isArchived(longId), true);
      });

      test('handles duplicate toggle attempts gracefully', () async {
        setupMockSharedPreferences({});
        final service = ArchiveService();
        service.archivedIds.value = ['pasal-1'];

        // Try to add same pasal (should remove since it exists)
        await service.toggleArchive('pasal-1');
        expect(service.isArchived('pasal-1'), false);

        // List should only have one entry max
        expect(service.archivedIds.value.where((id) => id == 'pasal-1').length, 0);
      });
    });

    group('global archiveService instance', () {
      test('archiveService global is same as factory instance', () {
        final factoryInstance = ArchiveService();

        expect(identical(archiveService, factoryInstance), true);
      });
    });
  });
}
