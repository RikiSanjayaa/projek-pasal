import 'package:flutter_test/flutter_test.dart';
import 'package:pasal_mobile_app/models/ai_chat_model.dart';

void main() {
  group('AiChatResponse', () {
    test('fromJson parses answer and sources correctly', () {
      final response = AiChatResponse.fromJson({
        'answer':
            'Berdasarkan data aplikasi, pasal yang relevan adalah Pasal 12.',
        'model': 'gemini-3.1-flash-lite',
        'response_ms': 1280,
        'is_configured': true,
        'sources': [
          {
            'id': 'pasal-12',
            'nomor': '12',
            'judul': 'Pasal percobaan',
            'isi': 'Isi pasal',
            'penjelasan': 'Penjelasan pasal',
            'undang_undang': {
              'id': 'uu-kuhp',
              'kode': 'KUHP',
              'nama': 'Kitab Undang-Undang Hukum Pidana',
            },
          },
        ],
      });

      expect(response.answer, contains('Pasal 12'));
      expect(response.model, 'gemini-3.1-flash-lite');
      expect(response.responseMs, 1280);
      expect(response.isConfigured, isTrue);
      expect(response.sources, hasLength(1));
      expect(response.sources.first.id, 'pasal-12');
      expect(response.sources.first.uuKode, 'KUHP');
    });

    test('fromJson handles missing optional data safely', () {
      final response = AiChatResponse.fromJson({});

      expect(response.answer, '');
      expect(response.sources, isEmpty);
      expect(response.model, '');
      expect(response.responseMs, 0);
      expect(response.isConfigured, isFalse);
    });
  });
}
