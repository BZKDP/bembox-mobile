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

const _pageBg = Color(0xFFFFFCF6);
const _coral = Color(0xFFFF7547);
const _storeKey = 'bem-chat-support'; // история чата поддержки (локально)
const _seenKey = 'bem-op-seen-support'; // id уже показанных сообщений оператора

class _Msg {
  _Msg(this.role, this.content);
  final String role; // user | assistant
  final String content;

  Map<String, dynamic> toJson() => {'role': role, 'content': content};
  factory _Msg.fromJson(Map<String, dynamic> j) => _Msg((j['role'] ?? 'assistant') as String, (j['content'] ?? '') as String);
}

/// «Поддержка bembox» — порт `app/support/page.tsx`. Шапка с наушниками,
/// маскот-приветствие «Привет, я Саша», сетка быстрых действий, чипы и
/// composer со скрепкой/микрофоном. Бэкенд `/api/support/chat`.
class SupportScreen extends ConsumerStatefulWidget {
  const SupportScreen({super.key});

  @override
  ConsumerState<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends ConsumerState<SupportScreen> {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  final List<_Msg> _msgs = [
    _Msg('assistant', 'Привет! Я поддержка bembox. Расскажи что случилось — постараюсь помочь сразу или позову оператора.'),
  ];
  bool _loading = false;

  final Set<String> _seenOp = {};
  Timer? _poll;

  static const _mode = 'support';
  static const _threadId = 'support-main';

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

  /// История переживает уход с экрана (как просил пользователь).
  void _load() {
    try {
      final raw = ref.read(sharedPreferencesProvider).getString(_storeKey);
      if (raw == null) return;
      final list = (jsonDecode(raw) as List).map((e) => _Msg.fromJson(Map<String, dynamic>.from(e as Map))).toList();
      if (list.isNotEmpty) {
        setState(() { _msgs..clear()..addAll(list); });
        _toBottom();
      }
    } catch (_) {/* битый кэш */}
  }

  void _persist() {
    try {
      ref.read(sharedPreferencesProvider).setString(_storeKey, jsonEncode([for (final m in _msgs) m.toJson()]));
    } catch (_) {/* ignore */}
  }

  Future<void> _send(String raw) async {
    final t = raw.trim();
    if (t.isEmpty || _loading) return;
    _ctrl.clear();
    setState(() {
      _msgs.add(_Msg('user', t));
      _loading = true;
    });
    _persist();
    _toBottom();
    try {
      final res = await ref.read(dioClientProvider).post('/support/chat', data: {
        'messages': [for (final m in _msgs) {'role': m.role, 'content': m.content}],
      });
      final raw = (res.data is Map ? res.data['reply'] : null)?.toString().trim() ?? '';
      final reply = raw.isNotEmpty ? raw : 'Секунду, уточняю… Напишите подробнее, что случилось.';
      if (mounted) setState(() { _msgs.add(_Msg('assistant', reply)); _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _msgs.add(_Msg('assistant', 'Сбой связи. Попробуй ещё раз.')); _loading = false; });
    }
    _persist();
    _toBottom();
  }

  /// «Связаться с оператором» — просто отправляем сообщение (оно уходит в
  /// chat_messages через /support/chat, оператор видит его в админке и
  /// отвечает; ответ покажет поллинг chat-history).
  Future<void> _escalate() async => _send('Свяжите с живым оператором.');

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

  /// Тянем тред из `/api/chat-history` и показываем сообщения оператора
  /// (role operator / operator-info). Дедуп по id.
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
          fresh.add(_Msg('operator', (m['content'] ?? '').toString()));
        }
      }
      if (fresh.isNotEmpty && mounted) {
        setState(() => _msgs.addAll(fresh));
        _persist(); _saveSeen(); _toBottom();
      }
    } catch (_) {}
  }

  void _toBottom() => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      });

  void _exit() => context.canPop() ? context.pop() : context.go('/home');

  static const _quickActions = [
    (icon: Icons.local_shipping_outlined, label: 'Где мой курьер?', msg: 'Где мой курьер? Я жду заказ.'),
    (icon: Icons.schedule, label: 'Привезти раньше', msg: 'Можно привезти заказ раньше?'),
    (icon: Icons.close, label: 'Отменить заказ', msg: 'Хочу отменить заказ.'),
    (icon: Icons.phone_outlined, label: 'Связаться с оператором', msg: 'Свяжите с живым оператором.'),
    (icon: Icons.auto_awesome, label: 'Получить промокод', msg: 'Есть какие-то промокоды для меня?'),
    (icon: Icons.help_outline, label: 'Другой вопрос', msg: ''),
  ];

  static const _chips = ['Где курьер?', 'Привезти раньше', 'Отменить заказ', 'Связаться с оператором', 'Промокоды', 'Заказ опаздывает', 'Поменять адрес'];

  @override
  Widget build(BuildContext context) {
    final welcome = _msgs.length <= 1;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) { if (!didPop) _exit(); },
      child: Scaffold(
      backgroundColor: _pageBg,
      body: Column(
        children: [
          _header(),
          Expanded(
            child: ListView(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              children: [
                if (welcome) ...[_welcome(), _quickGrid()],
                for (final m in _msgs) _bubble(m),
                if (_loading) _typing(),
              ],
            ),
          ),
          _chipRow(),
          _composer(),
        ],
      ),
      ),
    );
  }

  Widget _header() => Container(
        padding: EdgeInsets.fromLTRB(12, MediaQuery.of(context).padding.top + 8, 16, 8),
        child: Row(children: [
          GestureDetector(
            onTap: _exit,
            behavior: HitTestBehavior.opaque,
            child: const Padding(padding: EdgeInsets.all(6), child: Icon(Icons.chevron_left, color: BemColors.ink)),
          ),
          const SizedBox(width: 4),
          Container(
            width: 36, height: 36,
            decoration: const BoxDecoration(color: Color(0xFFFFEDDF), shape: BoxShape.circle),
            child: const Icon(Icons.headset_mic_outlined, size: 18, color: _coral),
          ),
          const SizedBox(width: 8),
          const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text('Поддержка bembox', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: -0.3, color: BemColors.ink)),
            SizedBox(height: 1),
            Text('обычно отвечает за минуту', style: TextStyle(fontSize: 11, color: BemColors.mute)),
          ])),
        ]),
      );

  Widget _welcome() => Padding(
        padding: const EdgeInsets.fromLTRB(0, 12, 0, 16),
        child: Column(children: [
          Container(
            width: 120, height: 120,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFFFE9DD), Color(0xFFFFD3C1)]),
              borderRadius: BorderRadius.circular(28),
              boxShadow: const [BoxShadow(color: Color(0x33E8551F), blurRadius: 22, spreadRadius: -10, offset: Offset(0, 8))],
            ),
            child: CachedNetworkImage(imageUrl: '${AppConfig.siteBaseUrl}/deco/helper.webp', fit: BoxFit.cover, alignment: Alignment.topCenter, errorWidget: (_, _, _) => const Icon(Icons.support_agent, size: 48, color: Color(0xFFE85522))),
          ),
          const SizedBox(height: 12),
          const Text('Привет, я Саша', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: -0.3, color: BemColors.ink)),
          const SizedBox(height: 4),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 40),
            child: Text('Помогаю с заказами bembox. Выбери вопрос или напиши свой.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12.5, color: BemColors.mute)),
          ),
        ]),
      );

  Widget _quickGrid() => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 3.5,
          children: [
            for (final a in _quickActions)
              GestureDetector(
                onTap: () {
                  if (a.label == 'Связаться с оператором') { _escalate(); }
                  else if (a.msg.isEmpty) { FocusScope.of(context).requestFocus(FocusNode()); }
                  else { _send(a.msg); }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 12, spreadRadius: -6, offset: Offset(0, 4)), BoxShadow(color: Color(0x0F000000), spreadRadius: 0.5)]),
                  child: Row(children: [
                    Container(width: 32, height: 32, decoration: const BoxDecoration(color: Color(0xFFFFF1EC), shape: BoxShape.circle), child: Icon(a.icon, size: 15, color: _coral)),
                    const SizedBox(width: 10),
                    Expanded(child: Text(a.label, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, height: 1.1, color: BemColors.ink))),
                  ]),
                ),
              ),
          ],
        ),
      );

  Widget _bubble(_Msg m) {
    final isUser = m.role == 'user';
    final isOp = m.role == 'operator';
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.82),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isUser ? _coral : (isOp ? const Color(0xFFFFF3EC) : Colors.white),
          border: isUser ? null : Border.all(color: isOp ? const Color(0x33FF7547) : const Color(0x0F000000)),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18), topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isUser ? 18 : 4), bottomRight: Radius.circular(isUser ? 4 : 18),
          ),
          boxShadow: isUser ? const [BoxShadow(color: Color(0x66E8551F), blurRadius: 18, spreadRadius: -8, offset: Offset(0, 6))] : null,
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          if (isOp) ...[
            const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.headset_mic, size: 13, color: Color(0xFFE85522)),
              SizedBox(width: 4),
              Text('Оператор', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFFE85522))),
            ]),
            const SizedBox(height: 3),
          ],
          Text(m.content, style: TextStyle(fontSize: 14, height: 1.35, color: isUser ? Colors.white : BemColors.ink)),
        ]),
      ),
    );
  }

  Widget _typing() => Padding(
        padding: const EdgeInsets.only(left: 12, bottom: 6),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            for (var i = 0; i < 3; i++) Padding(padding: const EdgeInsets.symmetric(horizontal: 2), child: Container(width: 6, height: 6, decoration: const BoxDecoration(color: BemColors.mute, shape: BoxShape.circle))),
          ]),
        ),
      );

  Widget _chipRow() => SizedBox(
        height: 48,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          itemCount: _chips.length,
          separatorBuilder: (_, _) => const SizedBox(width: 6),
          itemBuilder: (_, i) {
            final label = _chips[i];
            return GestureDetector(
              onTap: () => label == 'Связаться с оператором' ? _escalate() : _send(label.endsWith('?') ? label : '$label.'),
              child: Container(
                height: 32,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                alignment: Alignment.center,
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(999), boxShadow: const [BoxShadow(color: Color(0x0F000000), spreadRadius: 1), BoxShadow(color: Color(0x0F000000), blurRadius: 8, spreadRadius: -4, offset: Offset(0, 2))]),
                child: Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: BemColors.ink)),
              ),
            );
          },
        ),
      );

  Widget _composer() => Container(
        padding: EdgeInsets.fromLTRB(12, 4, 12, MediaQuery.of(context).padding.bottom + 8),
        color: _pageBg,
        child: Row(children: [
          _circleBtn(Icons.attach_file, () {}),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              constraints: const BoxConstraints(minHeight: 44),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(999), boxShadow: const [BoxShadow(color: Color(0x0F000000), spreadRadius: 1), BoxShadow(color: Color(0x14000000), blurRadius: 12, spreadRadius: -6, offset: Offset(0, 4))]),
              child: TextField(
                controller: _ctrl,
                minLines: 1, maxLines: 5,
                textInputAction: TextInputAction.send,
                onSubmitted: _send,
                onChanged: (_) => setState(() {}),
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: BemColors.ink),
                decoration: const InputDecoration(isCollapsed: true, contentPadding: EdgeInsets.symmetric(vertical: 12), border: InputBorder.none, hintText: 'Сообщение', hintStyle: TextStyle(fontSize: 14, color: BemColors.mute)),
              ),
            ),
          ),
          const SizedBox(width: 8),
          _ctrl.text.trim().isNotEmpty
              ? GestureDetector(
                  onTap: () { _send(_ctrl.text); HapticFeedback.selectionClick(); },
                  child: Container(
                    width: 40, height: 40,
                    decoration: const BoxDecoration(color: _coral, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Color(0x80FF7547), blurRadius: 14, spreadRadius: -6, offset: Offset(0, 6))]),
                    child: const Icon(Icons.send, size: 16, color: Colors.white),
                  ),
                )
              : _circleBtn(Icons.mic_none, () {}, accent: true),
        ]),
      );

  Widget _circleBtn(IconData icon, VoidCallback onTap, {bool accent = false}) => GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 40, height: 40,
          decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: const [BoxShadow(color: Color(0x0F000000), spreadRadius: 1), BoxShadow(color: Color(0x14000000), blurRadius: 12, spreadRadius: -6, offset: Offset(0, 4))]),
          child: Icon(icon, size: 16, color: accent ? _coral : const Color(0xFF7A6F66)),
        ),
      );
}
