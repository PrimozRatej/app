import 'package:flutter/material.dart';
import 'package:humhub/util/manifest.dart';
import 'package:webview_flutter/webview_flutter.dart';

extension MyCookies on WebViewCookieManager {
  Future<void> setMyCookies(Manifest manifest) async {
    await setCookie(
      WebViewCookie(
        name: 'is_mobile_app',
        value: 'true',
        domain: manifest.baseUrl,
      ),
    );
  }
}

class HexColor extends Color {
  static int _getColorFromHex(String hexColor) {
    hexColor = hexColor.toUpperCase().replaceAll("#", "");
    if (hexColor.length == 6) {
      hexColor = "FF$hexColor";
    }
    return int.parse(hexColor, radix: 16);
  }

  HexColor(final String hexColor) : super(_getColorFromHex(hexColor));
}