import 'dart:async';
import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_config.dart';
import '../../core/providers.dart';
import '../../core/theme/bem_colors.dart';

const _storeKey = 'bem-chat-assistant'; // история чата помощника (локально)
const _seenKey = 'bem-op-seen-assistant'; // id уже показанных сообщений оператора

const _coral = Color(0xFFFF7547);
const _coralDeep = Color(0xFFE85522);
const _soft = Color(0xFFFFF3EC); // header bg
const _chatBg = Color(0xFFFAFAFA);

const _greeting =
    'Здравствуйте! Я персональный помощник bembox. Опишите задачу — подберу '
    'решение, посчитаю цену и при необходимости подключу живого специалиста. '
    'Это платная услуга.';

const _quick = ['Полить цветы', 'Выгулять собаку', 'Забрать посылку из ПВЗ', 'Купить лекарства ночью'];

class _Msg {
  _Msg(this.from, this.text, this.ts, {this.actions});
  final String from; // me | bot
  final String text;
  final DateTime ts;
  final List<String>? actions; // кнопки-варианты [ACTIONS] от ассистента

  Map<String, dynamic> toJson() => {
        'from': from,
        'text': text,
        'ts': ts.millisecondsSinceEpoch,
        if (actions != null) 'actions': actions,
      };

  factory _Msg.fromJson(Map<String, dynamic> j) => _Msg(
        (j['from'] ?? 'bot') as String,
        (j['text'] ?? '') as String,
        DateTime.fromMillisecondsSinceEpoch((j['ts'] as num?)?.toInt() ?? 0),
        actions: (j['actions'] as List?)?.map((e) => e.toString()).toList(),
      );
}

/// «Персональный помощник» — порт `app/services/request/page.tsx` (helper-режим).
/// Полноэкранный чат: цветная шапка с аватаром, приветствие, чипы «частые
/// задачи», градиентные «мои» пузыри. Бэкенд `/api/assistant`.
class AssistantScreen extends ConsumerStatefulWidget {
  const AssistantScreen({super.key});

  @override
  ConsumerState<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends ConsumerState<AssistantScreen> {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  final List<_Msg> _msgs = [];
  bool _typing = false;

  // Ответы оператора приходят в chat_messages (как видит админка). Поллим тред
  // и показываем сообщения role=operator/operator-info по id (без дублей).
  final Set<String> _seenOp = {};
  Timer? _poll;

  static const _mode = 'assistant';
  static const _threadId = 'assistant-main';

  @override
  void initState() {
    super.initState();
    _load();
    _loadSeen();
    _startPolling();
  }

  @override
  void dispose() {
    _poll?.cancel();
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// Загрузка сохранённой истории (переживает уход с экрана, как на сайте).
  void _load() {
    try {
      final raw = ref.read(sharedPreferencesProvider).getString(_storeKey);
      if (raw == null) return;
      final list = (jsonDecode(raw) as List).map((e) => _Msg.fromJson(Map<String, dynamic>.from(e as Map))).toList();
      if (list.isNotEmpty) {
        setState(() => _msgs.addAll(list));
        _toBottom();
      }
    } catch (_) {/* битый кэш — игнор */}
  }

  void _persist() {
    try {
      ref.read(sharedPreferencesProvider).setString(_storeKey, jsonEncode([for (final m in _msgs) m.toJson()]));
    } catch (_) {/* ignore */}
  }

  Future<void> _send(String raw) async {
    final t = raw.trim();
    if (t.isEmpty || _typing) return;
    _ctrl.clear();
    setState(() {
      _msgs.add(_Msg('me', t, DateTime.now()));
      _typing = true;
    });
    _persist();
    _toBottom();
    final user = ref.read(authControllerProvider).user;
    try {
      final res = await ref.read(dioClientProvider).post('/assistant', data: {
        'messages': [for (final m in _msgs) {'role': m.from == 'me' ? 'user' : 'assistant', 'content': m.text}],
        'mode': 'assistant',
        'userContext': {
          if (user?.lastAddress != null && user!.lastAddress!.isNotEmpty) 'address': user.lastAddress,
          if (user?.phone != null && user!.phone!.isNotEmpty) 'phone': user.phone,
        },
      });
      final data = res.data is Map ? res.data as Map : const {};
      final actions = (data['actions'] as List?)?.map((e) => e.toString()).toList();
      final needsOperator = data['needsOperator'] == true;
      // ИИ иногда отдаёт пустой reply (особенно с [ESCALATE]) — не показываем
      // пустой пузырь, подставляем осмысленный текст.
      final rawReply = (data['reply'])?.toString().trim() ?? '';
      final reply = rawReply.isNotEmpty
          ? rawReply
          : (needsOperator ? 'Передаю оператору — ответит в течение нескольких минут.' : 'Хм, не понял. Опишите задачу иначе?');
      if (mounted) {
        setState(() {
          _msgs.add(_Msg('bot', reply, DateTime.now(), actions: actions));
          _typing = false;
        });
        _persist();
      }
    } catch (_) {
      if (mounted) setState(() { _msgs.add(_Msg('bot', 'Что-то с подключением. Попробуйте ещё раз через секунду.', DateTime.now())); _typing = false; });
      _persist();
    }
    _toBottom();
  }

  // ── Ответы оператора из chat_messages (тот же тред, что в админке) ──
  void _saveSeen() {
    try { ref.read(sharedPreferencesProvider).setString(_seenKey, jsonEncode(_seenOp.toList())); } catch (_) {}
  }

  void _loadSeen() {
    try {
      final raw = ref.read(sharedPreferencesProvider).getString(_seenKey);
      if (raw != null) _seenOp.addAll((jsonDecode(raw) as List).map((e) => e.toString()));
    } catch (_) {}
  }

  void _startPolling() {
    _poll?.cancel();
    _pollOnce();
    _poll = Timer.periodic(const Duration(seconds: 8), (_) => _pollOnce());
  }

  /// Тянем тред из `/api/chat-history` и показываем новые сообщения оператора
  /// (role operator / operator-info) — их пишет оператор в админке. Дедуп по id.
  Future<void> _pollOnce() async {
    try {
      final res = await ref.read(dioClientProvider).get('/chat-history', query: {'mode': _mode, 'thread_id': _threadId});
      final msgs = (res.data is Map ? res.data['messages'] : null) as List? ?? const [];
      final fresh = <_Msg>[];
      for (final m in msgs) {
        if (m is! Map) continue;
        final id = m['id']?.toString();
        final role = m['role']?.toString();
        if (id == null || _seenOp.contains(id)) continue;
        if (role == 'operator' || role == 'operator-info') {
          _seenOp.add(id);
          fresh.add(_Msg('op', (m['content'] ?? '').toString(), DateTime.now()));
        }
      }
      if (fresh.isNotEmpty && mounted) {
        setState(() => _msgs.addAll(fresh));
        _persist();
        _saveSeen();
        _toBottom();
      }
    } catch (_) {/* сеть — следующий тик */}
  }

  void _newChat() {
    setState(() { _msgs.clear(); _ctrl.clear(); });
    _persist();
    _startPolling();
  }

  void _toBottom() => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      });

  String _time(DateTime t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  void _exit() => context.canPop() ? context.pop() : context.go('/home');

  @override
  Widget build(BuildContext context) {
    final empty = _msgs.isEmpty;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) { if (!didPop) _exit(); },
      child: Scaffold(
      backgroundColor: _chatBg,
      body: Column(
        children: [
          _header(),
          Expanded(
            child: ListView(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              children: [
                if (empty) _heroAvatar(),
                _greetingBubble(),
                if (empty) _quickChips(),
                for (final m in _msgs) _msgWithActions(m),
                if (_typing) _typingBubble(),
              ],
            ),
          ),
          _inputBar(),
        ],
      ),
      ),
    );
  }

  // ── Шапка ──
  Widget _header() => Container(
        padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + 8, 16, 10),
        decoration: const BoxDecoration(color: _soft, border: Border(bottom: BorderSide(color: Color(0x0D000000)))),
        child: Row(children: [
          GestureDetector(
            onTap: _exit,
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: 38, height: 38,
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.85), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0x0F000000))),
              child: const Icon(Icons.chevron_left, size: 22, color: BemColors.ink),
            ),
          ),
          const SizedBox(width: 10),
          _avatar(44, 14),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            const Text('Персональный помощник', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: -0.3, color: BemColors.ink)),
            const SizedBox(height: 3),
            Row(children: [
              Container(width: 6, height: 6, decoration: const BoxDecoration(color: _coral, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              const Text('отвечает сразу', style: TextStyle(fontSize: 11, color: _coralDeep)),
            ]),
          ])),
          _pillBtn(child: const Icon(Icons.menu, size: 15, color: _coralDeep), onTap: () {}),
          const SizedBox(width: 6),
          _pillBtn(child: const Text('+ Новый', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _coralDeep)), onTap: _newChat, wide: true),
        ]),
      );

  Widget _pillBtn({required Widget child, required VoidCallback onTap, bool wide = false}) => GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: 32,
          width: wide ? null : 32,
          padding: wide ? const EdgeInsets.symmetric(horizontal: 12) : null,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.85), borderRadius: BorderRadius.circular(999), border: Border.all(color: const Color(0x0F000000))),
          child: child,
        ),
      );

  Widget _avatar(double size, double radius) => Container(
        width: size, height: size,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFFFE9DD), Color(0xFFFFD3C1)]),
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: const Color(0x0D000000)),
        ),
        child: CachedNetworkImage(imageUrl: '${AppConfig.siteBaseUrl}/deco/helper.webp', fit: BoxFit.cover, alignment: Alignment.topCenter, errorWidget: (_, _, _) => const Icon(Icons.support_agent, color: _coralDeep)),
      );

  // ── Контент ──
  Widget _heroAvatar() => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Center(child: _avatar(88, 26)),
      );

  Widget _greetingBubble() => Align(
        alignment: Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.82),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: const Color(0x0D000000)),
            borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16), bottomRight: Radius.circular(16), bottomLeft: Radius.circular(6)),
          ),
          child: const Text(_greeting, style: TextStyle(fontSize: 14, height: 1.35, color: BemColors.ink)),
        ),
      );

  Widget _quickChips() => Padding(
        padding: const EdgeInsets.fromLTRB(4, 4, 0, 4),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text('ЧАСТЫЕ ЗАДАЧИ', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.5, color: Color(0xB3E85522))),
          ),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final q in _quick)
              GestureDetector(
                onTap: () => _send(q),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(999), border: Border.all(color: const Color(0x33FF7547))),
                  child: Text(q, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: _coralDeep)),
                ),
              ),
          ]),
        ]),
      );

  /// Пузырь + кнопки-варианты [ACTIONS] (если их прислал ассистент).
  Widget _msgWithActions(_Msg m) {
    if (m.actions == null || m.actions!.isEmpty) return _bubble(m);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _bubble(m),
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Wrap(spacing: 8, runSpacing: 8, children: [
          for (final a in m.actions!)
            GestureDetector(
              onTap: () => _send(a),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0x40FF7547)),
                  boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 8, spreadRadius: -4, offset: Offset(0, 2))],
                ),
                child: Text(a, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: BemColors.ink)),
              ),
            ),
        ]),
      ),
    ]);
  }

  Widget _bubble(_Msg m) {
    final isMe = m.from == 'me';
    final isOp = m.from == 'op'; // ответ живого оператора
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.82),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isMe ? null : (isOp ? const Color(0xFFFFF3EC) : Colors.white),
          gradient: isMe ? const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFFF8A5C), Color(0xFFE85522)]) : null,
          border: isMe ? null : Border.all(color: isOp ? const Color(0x33FF7547) : const Color(0x0D000000)),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16), topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 6), bottomRight: Radius.circular(isMe ? 6 : 16),
          ),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          if (isOp) ...[
            const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.headset_mic, size: 13, color: _coralDeep),
              SizedBox(width: 4),
              Text('Оператор', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: _coralDeep)),
            ]),
            const SizedBox(height: 3),
          ],
          Text(m.text, style: TextStyle(fontSize: 14, height: 1.35, color: isMe ? Colors.white : BemColors.ink)),
          const SizedBox(height: 2),
          Align(alignment: Alignment.centerRight, child: Text(_time(m.ts), style: TextStyle(fontSize: 10, color: isMe ? Colors.white.withValues(alpha: 0.7) : BemColors.mute))),
        ]),
      ),
    );
  }

  Widget _typingBubble() => Align(
        alignment: Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(color: Colors.white, border: Border.all(color: const Color(0x0D000000)), borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16), bottomRight: Radius.circular(16), bottomLeft: Radius.circular(6))),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            for (var i = 0; i < 3; i++) Padding(padding: const EdgeInsets.symmetric(horizontal: 2), child: Container(width: 6, height: 6, decoration: const BoxDecoration(color: _coral, shape: BoxShape.circle))),
          ]),
        ),
      );

  Widget _inputBar() => Container(
        padding: EdgeInsets.fromLTRB(12, 8, 12, MediaQuery.of(context).padding.bottom + 8),
        decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Color(0x0D000000)))),
        child: Row(children: [
          Expanded(
            child: Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(color: const Color(0x0A000000), borderRadius: BorderRadius.circular(999)),
              child: TextField(
                controller: _ctrl,
                minLines: 1, maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: _send,
                style: const TextStyle(fontSize: 14, color: BemColors.ink),
                decoration: const InputDecoration(isCollapsed: true, border: InputBorder.none, hintText: 'Опишите задачу — займёмся', hintStyle: TextStyle(fontSize: 14, color: BemColors.mute)),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () { _send(_ctrl.text); HapticFeedback.selectionClick(); },
            child: Container(
              width: 44, height: 44,
              decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFFF8A5C), Color(0xFFE85522)]), shape: BoxShape.circle),
              child: const Icon(Icons.send, size: 17, color: Colors.white),
            ),
          ),
        ]),
      );
}
