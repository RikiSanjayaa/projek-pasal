class AiChatSource {
  final String id;
  final String nomor;
  final String? judul;
  final String isi;
  final String? penjelasan;
  final String? uuId;
  final String? uuKode;
  final String? uuNama;

  const AiChatSource({
    required this.id,
    required this.nomor,
    this.judul,
    required this.isi,
    this.penjelasan,
    this.uuId,
    this.uuKode,
    this.uuNama,
  });

  factory AiChatSource.fromJson(Map<String, dynamic> json) {
    final uu = json['undang_undang'] is Map
        ? Map<String, dynamic>.from(json['undang_undang'] as Map)
        : <String, dynamic>{};

    return AiChatSource(
      id: json['id']?.toString() ?? '',
      nomor: json['nomor']?.toString() ?? '',
      judul: json['judul']?.toString(),
      isi: json['isi']?.toString() ?? '',
      penjelasan: json['penjelasan']?.toString(),
      uuId: uu['id']?.toString(),
      uuKode: uu['kode']?.toString(),
      uuNama: uu['nama']?.toString(),
    );
  }
}

class AiChatResponse {
  final String answer;
  final List<AiChatSource> sources;
  final String model;
  final int responseMs;
  final bool isConfigured;

  const AiChatResponse({
    required this.answer,
    required this.sources,
    required this.model,
    required this.responseMs,
    required this.isConfigured,
  });

  factory AiChatResponse.fromJson(Map<String, dynamic> json) {
    return AiChatResponse(
      answer: json['answer']?.toString() ?? '',
      sources: (json['sources'] as List<dynamic>? ?? [])
          .whereType<Map>()
          .map((item) => AiChatSource.fromJson(Map<String, dynamic>.from(item)))
          .toList(),
      model: json['model']?.toString() ?? '',
      responseMs: int.tryParse(json['response_ms']?.toString() ?? '') ?? 0,
      isConfigured: json['is_configured'] == true,
    );
  }
}

class AiChatMessage {
  final String id;
  final String text;
  final bool isUser;
  final DateTime createdAt;
  final List<AiChatSource> sources;
  final bool isError;

  const AiChatMessage({
    required this.id,
    required this.text,
    required this.isUser,
    required this.createdAt,
    this.sources = const [],
    this.isError = false,
  });
}
