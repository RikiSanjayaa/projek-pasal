import 'package:dio/dio.dart';

import '../../models/ai_chat_model.dart';
import 'api_service.dart';

class AiChatService {
  AiChatService._();

  static Future<AiChatResponse> ask(String question) async {
    try {
      final response = await ApiService.dio.post<Map<String, dynamic>>(
        '/mobile/ai-chat',
        data: {'question': question},
        options: Options(receiveTimeout: const Duration(seconds: 45)),
      );

      return AiChatResponse.fromJson(response.data ?? {});
    } on DioException catch (error) {
      throw Exception(ApiService.messageFromError(error));
    }
  }
}
