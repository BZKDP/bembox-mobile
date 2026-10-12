import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/theme/bem_colors.dart';

const _pageBg = Color(0xFFFFFCF6);

class _Msg {
  _Msg(this.role, this.content);
  final String role; // user | assistant
  final String content;
}

/// Общий чат-экран — Помощник (`/api/assistant`) и Поддержка (`/api/support/chat`).
/// Оба бэка: POST {messages:[{role,content}]} → {reply}. Пузырьки + ввод снизу.
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, required this.title, required this.endpoint, required this.greeting});
  final String title;
  final String endpoint;
  final String greeting;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  late final List<_Msg> _msgs = [_Msg('assistant', widget.greeting)];
  bool _sending = false;

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _sending) return;
    _ctrl.clear();
    setState(() {
      _msgs.add(_Msg('user', text));
      _sending = true;
    });
    _toBottom();
    try {
      final res = await ref.read(dioClientProvider).post(widget.endpoint, data: {
        'messages': [for (final m in _msgs) {'role': m.role, 'content': m.content}],
      });
      final reply = (res.data is Map ? res.data['reply'] : null)?.toString() ?? '…';
      if (mounted) setState(() { _msgs.add(_Msg('assistant', reply)); _sending = false; });
    } catch (_) {
      if (mounted) setState(() { _msgs.add(_Msg('assistant', 'Не получилось ответить. Попробуйте ещё раз.')); _sending = false; });
    }
    _toBottom();
  }

  void _toBottom() => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pageBg,
      appBar: AppBar(
        backgroundColor: _pageBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: BemColors.ink,
        leading: IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => context.canPop() ? context.pop() : context.go('/home')),
        title: Text(widget.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.3)),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                itemCount: _msgs.length + (_sending ? 1 : 0),
                itemBuilder: (_, i) {
                  if (i == _msgs.length) return _bubble(_Msg('assistant', '…'), typing: true);
                  return _bubble(_msgs[i]);
                },
              ),
            ),
            _inputBar(),
          ],
        ),
      ),
    );
  }

  Widget _bubble(_Msg m, {bool typing = false}) {
    final isUser = m.role == 'user';
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        decoration: BoxDecoration(
          color: isUser ? BemColors.coral : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18), topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isUser ? 18 : 4), bottomRight: Radius.circular(isUser ? 4 : 18),
          ),
          boxShadow: isUser ? null : const [BoxShadow(color: Color(0x0F000000), blurRadius: 6, spreadRadius: -2, offset: Offset(0, 2))],
        ),
        child: Text(
          typing ? 'печатает…' : m.content,
          style: TextStyle(fontSize: 14, height: 1.35, color: isUser ? Colors.white : BemColors.ink),
        ),
      ),
    );
  }

  Widget _inputBar() => Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        decoration: const BoxDecoration(color: _pageBg, boxShadow: [BoxShadow(color: Color(0x0F000000), blurRadius: 10, offset: Offset(0, -2))]),
        child: Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: const Color(0xFFEFE7D4))),
                child: TextField(
                  controller: _ctrl,
                  minLines: 1, maxLines: 4,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _send(),
                  style: const TextStyle(fontSize: 14, color: BemColors.ink),
                  decoration: const InputDecoration(isCollapsed: true, contentPadding: EdgeInsets.symmetric(vertical: 10), border: InputBorder.none, hintText: 'Сообщение…', hintStyle: TextStyle(color: BemColors.mute)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () { _send(); HapticFeedback.selectionClick(); },
              child: Container(
                width: 44, height: 44,
                decoration: const BoxDecoration(color: BemColors.coral, shape: BoxShape.circle),
                child: const Icon(Icons.arrow_upward, size: 22, color: Colors.white),
              ),
            ),
          ],
        ),
      );
}
