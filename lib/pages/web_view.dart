import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:humhub/util/extensions.dart';
import 'package:humhub/util/manifest.dart';
import 'package:humhub/util/web_view_mixin.dart';
import 'package:webview_flutter/webview_flutter.dart';

class WebViewApp extends ConsumerStatefulWidget {
  final Manifest manifest;
  const WebViewApp({super.key, required this.manifest});

  @override
  WebViewAppState createState() => WebViewAppState();
}

class WebViewAppState extends ConsumerState<WebViewApp> with WebViewMixin {
  final scaffoldKey = GlobalKey<ScaffoldState>();
  late final WebViewController webViewController;
  final WebViewCookieManager cookieManager = WebViewCookieManager();

  @override
  void initState() {
    super.initState();
    webViewController = getWebViewController(widget.manifest);
    cookieManager.setMyCookies(widget.manifest);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: WillPopScope(
        onWillPop: () async {
          bool canGoBack = await webViewController.canGoBack();
          if (canGoBack) {
            webViewController.goBack();
            return Future.value(false);
          } else {
            final exitConfirmed = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Are you sure?'),
                content: const Text('Do you want to exit an App'),
                actions: <Widget>[
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('No'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text('Yes'),
                  ),
                ],
              ),
            );
            return exitConfirmed ?? false;
          }
        },
        child: Scaffold(
          key: scaffoldKey,
          body: WebViewWidget(
            controller: webViewController,
          ),
        ),
      ),
    );
  }
}
