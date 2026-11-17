import 'dart:js_interop';

@JS('window.location.assign')
external void _assign(JSString url);

void navigate(String url) {
  _assign(url.toJS);
}
