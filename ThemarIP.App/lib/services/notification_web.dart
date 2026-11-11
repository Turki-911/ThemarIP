import 'dart:js_interop';

@JS('showThemarNotification')
external void _showThemarNotification(JSString title, JSString body);

void triggerWebNotification(String title, String body) {
  try {
    _showThemarNotification(title.toJS, body.toJS);
  } catch (_) {}
}
