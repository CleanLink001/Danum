import 'dart:js_interop';

@JS('eval')
external void _eval(String code);

void webEval(String code) {
  _eval(code);
}
