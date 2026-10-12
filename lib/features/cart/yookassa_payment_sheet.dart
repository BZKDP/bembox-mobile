import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/theme/bem_colors.dart';

const _coral = Color(0xFFFF7547);

/// Показать встроенный виджет оплаты ЮKassa (как `YookassaWidget.tsx` на сайте):
/// грузим `checkout-widget.js`, монтируем форму по [confirmationToken].
/// Возвращает true, если виджет ушёл на return_url (оплата прошла / в обработке).
Future<bool> showYookassaPayment(
  BuildContext context, {
  required String confirmationToken,
  required String orderId,
}) async {
  final returnUrl = 'https://bembox.ru/orders/$orderId?paid=processing';
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0x80000000),
    builder: (ctx) => _YookassaSheet(confirmationToken: confirmationToken, returnUrl: returnUrl),
  );
  return result ?? false;
}

class _YookassaSheet extends StatefulWidget {
  const _YookassaSheet({required this.confirmationToken, required this.returnUrl});
  final String confirmationToken;
  final String returnUrl;

  @override
  State<_YookassaSheet> createState() => _YookassaSheetState();
}

class _YookassaSheetState extends State<_YookassaSheet> {
  late final WebViewController _controller;
  bool _loaded = false;

  String get _html => '''
<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no">
<script src="https://static.yoomoney.ru/checkout-client/checkout-widget.js"></script>
<style>html,body{margin:0;padding:0;background:#fff;font-family:-apple-system,system-ui,sans-serif}#yookassa-checkout{min-height:320px}</style>
</head>
<body>
<div id="yookassa-checkout"></div>
<script>
  function start(){
    if(!window.YooMoneyCheckoutWidget){ setTimeout(start, 120); return; }
    try {
      var widget = new window.YooMoneyCheckoutWidget({
        confirmation_token: '${widget.confirmationToken}',
        return_url: '${widget.returnUrl}',
        customization: { colors: { control_primary: '#FF7547' } },
        error_callback: function(e){ console.log('yk error', e); }
      });
      widget.on('success', function(){ window.location.href = '${widget.returnUrl}'; });
      widget.render('yookassa-checkout');
    } catch(e){ console.log('init err', e); }
  }
  start();
</script>
</body>
</html>
''';

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) { if (mounted) setState(() => _loaded = true); },
        onNavigationRequest: (req) {
          // Виджет ушёл на return_url → оплата принята/в обработке.
          if (req.url.contains('paid=processing') || req.url.startsWith('https://bembox.ru/orders/')) {
            if (mounted) Navigator.of(context).pop(true);
            return NavigationDecision.prevent;
          }
          return NavigationDecision.navigate;
        },
      ))
      ..loadHtmlString(_html, baseUrl: 'https://bembox.ru');
  }

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height * 0.9;
    return Container(
      height: h,
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
      child: Column(children: [
        const SizedBox(height: 10),
        Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0x1A000000), borderRadius: BorderRadius.circular(999))),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 8, 8),
          child: Row(children: [
            const Expanded(child: Text('Оплата', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, letterSpacing: -0.3, color: BemColors.ink))),
            GestureDetector(
              onTap: () => Navigator.of(context).pop(false),
              behavior: HitTestBehavior.opaque,
              child: const Padding(padding: EdgeInsets.all(8), child: Icon(Icons.close, size: 20, color: BemColors.mute)),
            ),
          ]),
        ),
        Expanded(
          child: Stack(children: [
            ClipRRect(borderRadius: BorderRadius.circular(12), child: WebViewWidget(controller: _controller)),
            if (!_loaded)
              const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: _coral)),
                SizedBox(height: 10),
                Text('Загружаем форму оплаты…', style: TextStyle(fontSize: 12.5, color: BemColors.mute)),
              ])),
          ]),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 6, 16, 10),
          child: Text('Платёж принимает ЮKassa, ООО «БЕМ». Безопасно.', textAlign: TextAlign.center, style: TextStyle(fontSize: 10.5, color: BemColors.mute)),
        ),
      ]),
    );
  }
}
