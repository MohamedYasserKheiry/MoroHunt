import 'package:flutter/material.dart';

import '../data/hunting_knowledge_base.dart';

class _ChatMessage {
  final String text;
  final bool isBot;
  const _ChatMessage({required this.text, required this.isBot});
}

/// "التواصل والدعم الذكي" — a lightweight, fully offline rule-based
/// support assistant (no LLM API call, no network secret). Greets the
/// user automatically, then answers questions about app mechanics and
/// general hunting-compliance concepts using hunting_knowledge_base.dart.
///
/// DELIBERATELY ARABIC-ONLY, regardless of the app's selected
/// language: this assistant is tailored specifically for Moroccan
/// hunters and its knowledge base is Arabic-only content, so this
/// screen does NOT read from the translation dictionary at all —
/// every string here is a hardcoded Arabic literal, on purpose, not
/// an oversight.
class SupportChatScreen extends StatefulWidget {
  const SupportChatScreen({super.key});

  @override
  State<SupportChatScreen> createState() => _SupportChatScreenState();
}

class _SupportChatScreenState extends State<SupportChatScreen> {
  final List<_ChatMessage> _messages = [];
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // The 4 quick-FAQ suggestion chips shown under the welcome message —
  // hidden after the first real exchange so they don't clutter the
  // conversation once the user is actually chatting.
  static const _suggestions = [
    'كيفية استخدام الخريطة والطبقات',
    'التنسيق في القنص الجماعي',
    'إدارة الملف الشخصي والحساب',
    'الأسئلة الأكثر شيوعاً عن التطبيق',
  ];

  @override
  void initState() {
    super.initState();
    // Automatic greeting on entry.
    _messages.add(const _ChatMessage(
      text:
          'مرحباً! أنا المساعد الذكي لتطبيق MoroHunt، كيف يمكنني مساعدتك اليوم؟',
      isBot: true,
    ));
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _send([String? presetText]) {
    final text = (presetText ?? _inputController.text).trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add(_ChatMessage(text: text, isBot: false));
      _messages.add(_ChatMessage(text: findBestResponse(text), isBot: true));
    });
    _inputController.clear();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('التواصل والدعم الذكي')),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isLast = index == _messages.length - 1;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: msg.isBot
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.75,
                        ),
                        decoration: BoxDecoration(
                          color: msg.isBot
                              ? const Color(0xFF2E7D32).withValues(alpha: 0.25)
                              : Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          msg.text,
                          style: const TextStyle(height: 1.5),
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ),
                    // Quick-FAQ chips right under the welcome message —
                    // only while it's still the only message, so they
                    // disappear once a real conversation starts.
                    if (isLast && _messages.length == 1)
                      Padding(
                        padding: const EdgeInsets.only(top: 4, bottom: 10),
                        child: Wrap(
                          alignment: WrapAlignment.end,
                          spacing: 8,
                          runSpacing: 8,
                          children: _suggestions.map((suggestion) {
                            return ActionChip(
                              label: Text(suggestion,
                                  style: const TextStyle(fontSize: 12.5)),
                              backgroundColor: const Color(0xFF2E7D32)
                                  .withValues(alpha: 0.12),
                              side: BorderSide(
                                  color: const Color(0xFF2E7D32)
                                      .withValues(alpha: 0.4)),
                              onPressed: () => _send(suggestion),
                            );
                          }).toList(),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _inputController,
                      textAlign: TextAlign.right,
                      textDirection: TextDirection.rtl,
                      onSubmitted: (_) => _send(),
                      decoration: InputDecoration(
                        hintText: 'اكتب سؤالك هنا...',
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.06),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    child: IconButton(
                      icon:
                          const Icon(Icons.send, color: Colors.white, size: 20),
                      onPressed: _send,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
