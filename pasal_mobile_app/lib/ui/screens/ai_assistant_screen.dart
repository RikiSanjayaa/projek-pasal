import 'package:flutter/material.dart';

import '../../core/config/app_colors.dart';
import '../../core/services/ai_chat_service.dart';
import '../../core/services/query_service.dart';
import '../../models/ai_chat_model.dart';
import '../widgets/main_layout.dart';
import 'read_pasal_screen.dart';

class AiAssistantScreen extends StatefulWidget {
  const AiAssistantScreen({super.key});

  @override
  State<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends State<AiAssistantScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  final List<AiChatMessage> _messages = [
    AiChatMessage(
      id: 'welcome',
      text:
          'Halo, saya Asisten CariPasal. Tanyakan kasus atau kata kunci hukum, nanti saya bantu cari rujukan pasal dari data aplikasi.',
      isUser: false,
      createdAt: DateTime.now(),
    ),
  ];

  bool _isLoading = false;

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _sendQuestion() async {
    final question = _controller.text.trim();
    if (question.length < 3 || _isLoading) return;

    setState(() {
      _messages.add(
        AiChatMessage(
          id: 'user-${DateTime.now().microsecondsSinceEpoch}',
          text: question,
          isUser: true,
          createdAt: DateTime.now(),
        ),
      );
      _isLoading = true;
      _controller.clear();
    });
    _scrollToBottom();

    try {
      final response = await AiChatService.ask(question);
      if (!mounted) return;

      setState(() {
        _messages.add(
          AiChatMessage(
            id: 'ai-${DateTime.now().microsecondsSinceEpoch}',
            text: response.answer,
            isUser: false,
            createdAt: DateTime.now(),
            sources: response.sources,
            isError: !response.isConfigured,
          ),
        );
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _messages.add(
          AiChatMessage(
            id: 'error-${DateTime.now().microsecondsSinceEpoch}',
            text: error.toString().replaceFirst('Exception: ', ''),
            isUser: false,
            createdAt: DateTime.now(),
            isError: true,
          ),
        );
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
        _scrollToBottom();
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _openSource(AiChatSource source) async {
    final pasal = await QueryService.getPasalById(source.id);
    if (!mounted) return;

    if (pasal == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Pasal rujukan belum ada di data lokal. Coba update data dulu.',
          ),
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ReadPasalScreen(pasal: pasal)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return MainLayout(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(isDark),
          _buildNotice(isDark),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              itemCount: _messages.length + (_isLoading ? 1 : 0),
              itemBuilder: (context, index) {
                if (_isLoading && index == _messages.length) {
                  return _buildTypingBubble(isDark);
                }

                return _buildMessageBubble(_messages[index], isDark);
              },
            ),
          ),
          _buildComposer(isDark),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.auto_awesome_rounded,
              color: AppColors.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Asisten',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 2),
                Text(
                  'Jawaban dari data pasal aplikasi',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Scaffold.of(context).openEndDrawer(),
            icon: Icon(
              Icons.menu,
              color: isDark ? Colors.grey[300] : Colors.grey[700],
            ),
            tooltip: 'Pengaturan',
          ),
        ],
      ),
    );
  }

  Widget _buildNotice(bool isDark) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: isDark ? 0.12 : 0.16),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.amber.withValues(alpha: isDark ? 0.35 : 0.45),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, size: 18, color: Colors.amber[700]),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Asisten ini hanya membantu memahami pasal yang ada di aplikasi. Selalu cek rujukan pasal sebelum mengambil kesimpulan.',
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                color: isDark ? Colors.grey[200] : Colors.grey[800],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(AiChatMessage message, bool isDark) {
    final bubbleColor = message.isUser
        ? AppColors.primary
        : message.isError
        ? Colors.red.withValues(alpha: isDark ? 0.18 : 0.1)
        : AppColors.card(isDark);
    final textColor = message.isUser
        ? Colors.white
        : AppColors.textPrimary(isDark);

    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.82,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.circular(16).copyWith(
            bottomRight: message.isUser ? const Radius.circular(4) : null,
            bottomLeft: !message.isUser ? const Radius.circular(4) : null,
          ),
          border: message.isUser
              ? null
              : Border.all(color: AppColors.border(isDark)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SelectableText(
              message.text,
              style: TextStyle(fontSize: 14, height: 1.55, color: textColor),
            ),
            if (message.sources.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: message.sources.map((source) {
                  return ActionChip(
                    avatar: const Icon(Icons.menu_book_outlined, size: 16),
                    label: Text(
                      '${source.uuKode ?? 'UU'} Pasal ${source.nomor}',
                      overflow: TextOverflow.ellipsis,
                    ),
                    onPressed: () => _openSource(source),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTypingBubble(bool isDark) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.card(isDark),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border(isDark)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Mencari rujukan pasal...',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary(isDark),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComposer(bool isDark) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 104),
        decoration: BoxDecoration(
          color: AppColors.scaffold(isDark),
          border: Border(
            top: BorderSide(
              color: AppColors.border(isDark).withValues(alpha: 0.4),
            ),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.newline,
                enabled: !_isLoading,
                decoration: InputDecoration(
                  hintText: 'Tanya kasus atau pasal...',
                  filled: true,
                  fillColor: AppColors.inputFill(isDark),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            IconButton.filled(
              onPressed: _isLoading ? null : _sendQuestion,
              icon: const Icon(Icons.send_rounded),
              style: IconButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppColors.primary.withValues(
                  alpha: 0.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
