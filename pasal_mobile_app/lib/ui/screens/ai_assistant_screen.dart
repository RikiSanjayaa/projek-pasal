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
  final List<AiChatMessage> _messages = [];

  static const List<String> _quickPrompts = [
    'Saya mengalami pencopetan',
    'Apa hukum penipuan online?',
    'Jelaskan Pasal 12',
  ];

  bool _isLoading = false;

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _sendQuestion([String? value]) async {
    final question = (value ?? _controller.text).trim();
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
    _focusNode.unfocus();
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
        duration: const Duration(milliseconds: 240),
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
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;

    return MainLayout(
      child: MediaQuery.withClampedTextScaling(
        maxScaleFactor: 1.15,
        child: GestureDetector(
          onTap: _focusNode.unfocus,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(isDark, keyboardOpen),
              if (!keyboardOpen) _buildNotice(isDark),
              Expanded(
                child: _messages.isEmpty && !_isLoading
                    ? _buildEmptyState(isDark)
                    : ListView.builder(
                        controller: _scrollController,
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: EdgeInsets.fromLTRB(
                          20,
                          keyboardOpen ? 8 : 10,
                          20,
                          18,
                        ),
                        itemCount: _messages.length + (_isLoading ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (_isLoading && index == _messages.length) {
                            return _buildTypingBubble(isDark);
                          }

                          return _buildMessageBubble(_messages[index], isDark);
                        },
                      ),
              ),
              _buildComposer(isDark, keyboardOpen),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark, bool compact) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, compact ? 10 : 16, 20, compact ? 6 : 8),
      child: Row(
        children: [
          Container(
            width: compact ? 34 : 42,
            height: compact ? 34 : 42,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(compact ? 12 : 14),
            ),
            child: Icon(
              Icons.auto_awesome_rounded,
              color: AppColors.primary,
              size: compact ? 18 : 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Asisten',
                  style: TextStyle(
                    fontSize: compact ? 21 : 25,
                    fontWeight: FontWeight.w800,
                    height: 1.05,
                    color: AppColors.textPrimary(isDark),
                  ),
                ),
                if (!compact) ...[
                  const SizedBox(height: 3),
                  Text(
                    'Cari jawaban dari data pasal aplikasi',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary(isDark),
                    ),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            onPressed: () => Scaffold.of(context).openEndDrawer(),
            icon: Icon(
              Icons.menu_rounded,
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: isDark ? 0.11 : 0.14),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.amber.withValues(alpha: isDark ? 0.34 : 0.42),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, size: 18, color: Colors.amber[700]),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'AI membantu membaca data pasal. Cek rujukan sebelum dipakai.',
              style: TextStyle(
                fontSize: 12,
                height: 1.35,
                color: isDark ? Colors.grey[200] : Colors.grey[800],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.card(isDark),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border(isDark)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.psychology_alt_rounded,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Tanyakan kasus atau pasal',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary(isDark),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Asisten akan mencari rujukan dari database aplikasi, lalu menjelaskan dengan bahasa yang mudah dipahami.',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.45,
                  color: AppColors.textSecondary(isDark),
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _quickPrompts.map((prompt) {
                  return ActionChip(
                    avatar: const Icon(Icons.bolt_rounded, size: 16),
                    label: Text(prompt),
                    onPressed: () => _sendQuestion(prompt),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMessageBubble(AiChatMessage message, bool isDark) {
    final width = MediaQuery.sizeOf(context).width;
    final bubbleWidth = message.isUser ? width * 0.78 : width * 0.88;
    final bubbleColor = message.isUser
        ? AppColors.primary
        : message.isError
        ? Colors.red.withValues(alpha: isDark ? 0.18 : 0.08)
        : AppColors.card(isDark);
    final borderColor = message.isError
        ? Colors.red.withValues(alpha: 0.35)
        : AppColors.border(isDark);
    final textColor = message.isUser
        ? Colors.white
        : AppColors.textPrimary(isDark);

    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: bubbleWidth),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(message.isUser ? 18 : 6),
            bottomRight: Radius.circular(message.isUser ? 6 : 18),
          ),
          border: message.isUser ? null : Border.all(color: borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message.isError) ...[
              Row(
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    size: 17,
                    color: Colors.red[300],
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Terjadi kendala',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.red[300],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            SelectableText(
              message.text,
              style: TextStyle(fontSize: 13.5, height: 1.5, color: textColor),
            ),
            if (message.sources.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Rujukan',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary(isDark),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: message.sources.map((source) {
                  return ActionChip(
                    visualDensity: VisualDensity.compact,
                    avatar: const Icon(Icons.menu_book_outlined, size: 15),
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
              'Mencari rujukan...',
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

  Widget _buildComposer(bool isDark, bool keyboardOpen) {
    return SafeArea(
      top: false,
      child: Container(
        padding: EdgeInsets.fromLTRB(20, 8, 20, keyboardOpen ? 10 : 96),
        decoration: BoxDecoration(
          color: AppColors.scaffold(isDark),
          border: Border(
            top: BorderSide(
              color: AppColors.border(isDark).withValues(alpha: 0.28),
            ),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                minLines: 1,
                maxLines: 3,
                textInputAction: TextInputAction.newline,
                enabled: !_isLoading,
                keyboardAppearance: isDark ? Brightness.dark : Brightness.light,
                decoration: InputDecoration(
                  hintText: 'Tanya kasus atau pasal...',
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  filled: true,
                  fillColor: AppColors.inputFill(isDark),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
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
            SizedBox(
              width: 48,
              height: 48,
              child: IconButton.filled(
                onPressed: _isLoading ? null : _sendQuestion,
                icon: const Icon(Icons.send_rounded, size: 21),
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppColors.primary.withValues(
                    alpha: 0.4,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
