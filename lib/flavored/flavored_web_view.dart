import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:app_settings/app_settings.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app_badger/flutter_app_badger.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:humhub/components/auth_in_app_browser.dart';
import 'package:humhub/models/channel_message.dart';
import 'package:humhub/models/hum_hub.dart';
import 'package:humhub/util/connectivity_plugin.dart';
import 'package:humhub/util/extensions.dart';
import 'package:humhub/util/notifications/channel.dart';
import 'package:humhub/util/providers.dart';
import 'package:loggy/loggy.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

class WebViewGlobalController {
  static InAppWebViewController? _value;

  static InAppWebViewController? get value => _value;

  static void setValue(InAppWebViewController newValue) {
    _value = newValue;
  }
}

class FlavoredWebView extends ConsumerStatefulWidget {
  static const String path = '/flavored_web_view';
  const FlavoredWebView({super.key});

  @override
  FlavoredWebViewState createState() => FlavoredWebViewState();
}

class FlavoredWebViewState extends ConsumerState<FlavoredWebView> {
  late HumHub instance;
  late AuthInAppBrowser authBrowser;
  late URLRequest _initialRequest;
  final _options = InAppWebViewGroupOptions(
    crossPlatform: InAppWebViewOptions(
      useShouldOverrideUrlLoading: true,
      useShouldInterceptFetchRequest: true,
      javaScriptEnabled: true,
      supportZoom: false,
      javaScriptCanOpenWindowsAutomatically: true,
    ),
    android: AndroidInAppWebViewOptions(
      supportMultipleWindows: true,
    ),
  );

  PullToRefreshController? _pullToRefreshController;
  late PullToRefreshOptions _pullToRefreshOptions;
  HeadlessInAppWebView? headlessWebView;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    instance = ModalRoute.of(context)?.settings.arguments as HumHub;
    _initialRequest = _initRequest;
    _pullToRefreshController = initPullToRefreshController;
    authBrowser = AuthInAppBrowser(
      manifest: instance.manifest!,
      concludeAuth: (URLRequest request) {
        _concludeAuth(request);
      },
    );
    // ignore: deprecated_member_use
    return WillPopScope(
      onWillPop: () {
        return WebViewGlobalController.value!.exitApp(context, ref);
      },
      child: Scaffold(
        backgroundColor: HexColor(instance.manifest!.themeColor),
        body: SafeArea(
          bottom: false,
          child: InAppWebView(
            initialUrlRequest: _initialRequest,
            initialOptions: _options,
            pullToRefreshController: _pullToRefreshController,
            shouldOverrideUrlLoading: _shouldOverrideUrlLoading,
            onWebViewCreated: _onWebViewCreated,
            shouldInterceptFetchRequest: _shouldInterceptFetchRequest,
            onCreateWindow: (inAppWebViewController, createWindowAction) async {
              final urlToOpen = createWindowAction.request.url;
              if (urlToOpen == null) return Future.value(false);
              if (await canLaunchUrl(urlToOpen)) {
                await launchUrl(urlToOpen, mode: LaunchMode.externalApplication);
              } else {
                logError('Could not launch $urlToOpen');
              }

              return Future.value(true); // Allow creating a new window.
            },
            onLoadStop: _onLoadStop,
            onLoadStart: (controller, uri) async {
              _setAjaxHeadersJQuery(controller);
            },
            onProgressChanged: _onProgressChanged,
            onLoadError: (InAppWebViewController controller, Uri? url, int code, String message) {
              if (code == -1009) NoConnectionDialog.show(context);
            },
          ),
        ),
      ),
    );
  }

  Future<NavigationActionPolicy?> _shouldOverrideUrlLoading(
      InAppWebViewController controller, NavigationAction action) async {
    // 1st check if url is not def. app url and open it in a browser or inApp.
    _setAjaxHeadersJQuery(controller);
    final url = action.request.url!.origin;
    if (!url.startsWith(instance.manifest!.baseUrl) && action.isForMainFrame) {
      authBrowser.launchUrl(action.request);
      return NavigationActionPolicy.CANCEL;
    }
    // 2nd Append customHeader if url is in app redirect and CANCEL the requests without custom headers
    if (Platform.isAndroid ||
        action.iosWKNavigationType == IOSWKNavigationType.LINK_ACTIVATED ||
        action.iosWKNavigationType == IOSWKNavigationType.FORM_SUBMITTED) {
      Map<String, String> mergedMap = {...instance.customHeaders, ...?action.request.headers};
      URLRequest newRequest = action.request.copyWith(headers: mergedMap);
      controller.loadUrl(urlRequest: newRequest);
      return NavigationActionPolicy.CANCEL;
    }
    return NavigationActionPolicy.ALLOW;
  }

  _concludeAuth(URLRequest request) {
    authBrowser.close();
    WebViewGlobalController.value!.loadUrl(urlRequest: request);
  }

  _onWebViewCreated(InAppWebViewController controller) async {
    headlessWebView = HeadlessInAppWebView();
    headlessWebView!.run();
    await controller.addWebMessageListener(
      WebMessageListener(
        jsObjectName: "flutterChannel",
        onPostMessage: (inMessage, sourceOrigin, isMainFrame, replyProxy) async {
          ChannelMessage message = ChannelMessage.fromJson(inMessage!);
          await _handleJSMessage(message, headlessWebView!);
        },
      ),
    );
    WebViewGlobalController.setValue(controller);
  }

  Future<FetchRequest?> _shouldInterceptFetchRequest(InAppWebViewController controller, FetchRequest request) async {
    request.headers!.addAll(_initialRequest.headers!);
    return request;
  }

  URLRequest get _initRequest {
    String? url = instance.manifest!.startUrl;
    String? payloadFromPush = InitFromPush.usePayload();
    if (payloadFromPush != null) url = payloadFromPush;
    return URLRequest(url: Uri.parse(url), headers: instance.customHeaders);
  }

  _onLoadStop(InAppWebViewController controller, Uri? url) {
    // Disable remember me checkbox on login and set def. value to true: check if the page is actually login page, if it is inject JS that hides element
    if (url!.path.contains('/user/auth/login')) {
      WebViewGlobalController.value!
          .evaluateJavascript(source: "document.querySelector('#login-rememberme').checked=true");
      WebViewGlobalController.value!.evaluateJavascript(
          source:
              "document.querySelector('#account-login-form > div.form-group.field-login-rememberme').style.display='none';");
    }
    _setAjaxHeadersJQuery(controller);
    _pullToRefreshController?.endRefreshing();
  }

  _onProgressChanged(InAppWebViewController controller, int progress) {
    if (progress == 100) {
      _pullToRefreshController?.endRefreshing();
    }
  }

  PullToRefreshController? get initPullToRefreshController {
    _pullToRefreshOptions = PullToRefreshOptions(
      color: HexColor(instance.manifest!.themeColor),
    );
    return kIsWeb
        ? null
        : PullToRefreshController(
            options: _pullToRefreshOptions,
            onRefresh: () async {
              Uri? url = await WebViewGlobalController.value!.getUrl();
              if (url != null) {
                WebViewGlobalController.value!.loadUrl(
                  urlRequest:
                      URLRequest(url: await WebViewGlobalController.value!.getUrl(), headers: instance.customHeaders),
                );
              } else {
                WebViewGlobalController.value!.reload();
              }
            },
          );
  }

  askForNotificationPermissions() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Notification Permission"),
        content: const Text("Please enable notifications for HumHub in the device settings"),
        actions: <Widget>[
          TextButton(
            child: const Text("Enable"),
            onPressed: () {
              AppSettings.openAppSettings();
              Navigator.pop(context);
            },
          ),
          TextButton(
            child: const Text("Skip"),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _setAjaxHeadersJQuery(InAppWebViewController controller) async {
    String jsCode = "\$.ajaxSetup({headers: ${jsonEncode(instance.customHeaders).toString()}});";
    await controller.evaluateJavascript(source: jsCode);
  }

  Future<void> _handleJSMessage(ChannelMessage message, HeadlessInAppWebView headlessWebView) async {
    switch (message.action) {
      case ChannelAction.registerFcmDevice:
        String? token = ref.read(pushTokenProvider).value;
        if (token != null) {
          var postData = Uint8List.fromList(utf8.encode("token=$token"));
          URLRequest request = URLRequest(url: Uri.parse(message.url!), method: "POST", body: postData);
          await headlessWebView.webViewController.loadUrl(urlRequest: request);
        }
        var status = await Permission.notification.status;
        // status.isDenied: The user has previously denied the notification permission
        // !status.isGranted: The user has never been asked for the notification permission
        if (status.isDenied || !status.isGranted) askForNotificationPermissions();
        break;
      case ChannelAction.updateNotificationCount:
        if (message.count != null) FlutterAppBadger.updateBadgeCount(message.count!);
        break;
      case ChannelAction.unregisterFcmDevice:
        String? token = ref.read(pushTokenProvider).value;
        if (token != null) {
          var postData = Uint8List.fromList(utf8.encode("token=$token"));
          URLRequest request = URLRequest(url: Uri.parse(message.url!), method: "POST", body: postData);
          // Works but for admin to see the changes it need to reload a page because a request is called on separate instance.
          await headlessWebView.webViewController.loadUrl(urlRequest: request);
        }
        break;
      default:
        break;
    }
  }

  @override
  void dispose() {
    super.dispose();
    if (headlessWebView != null) {
      headlessWebView!.dispose();
    }
  }
}