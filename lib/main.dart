// dart
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/material.dart';
import 'package:web_view_mvp/services/totp_service.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'models/page_item.dart';
import 'services/api_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(home: WebViewCarrier());
  }
}

class WebViewCarrier extends StatefulWidget {
  const WebViewCarrier({super.key});

  @override
  WebViewCarrierState createState() => WebViewCarrierState();
}

class WebViewCarrierState extends State<WebViewCarrier> {
  late final WebViewController controller;
  PageItem? selected;

  late final String baseUrl;
  late final String shared;

  @override
  void initState() {
    super.initState();

    baseUrl = dotenv.env['BASE_URL'] ?? '';
    shared = dotenv.env['SHARED_SECRET'] ?? '';

    TotpService.instance.setSharedSecret(shared);
    TotpService.instance.start();

    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadRequest(Uri.parse('about:blank'));

    // keep selected in sync with actual list instances
    ApiService.instance.pages.addListener(_onPagesUpdated);

    // fetch pages on startup
    ApiService.instance.fetchPages(
      baseUrl: baseUrl,
      totpCode: TotpService.instance.getCode(),
    );
  }

  void _onPagesUpdated() {
    final pages = ApiService.instance.pages.value;
    if (selected == null) {
      // optional: set a default selection if desired
      return;
    }
    // try to find the same logical page (by url) in the new list and update selected to that instance
    final matched = pages.firstWhere(
      (p) => p.url == selected!.url,
      orElse: () => PageItem(description: '', url: ''),
    );
    if (matched.url.isEmpty) {
      // selected no longer exists in new pages; clear selection safely
      setState(() => selected = null);
    } else if (!identical(matched, selected)) {
      // update to the new list instance so Dropdown value matches exactly one item
      setState(() => selected = matched);
    }
  }

  void _onSelect(PageItem? item) {
    if (item == null) return;
    // always set to the instance from the current pages list (should already be so)
    final pages = ApiService.instance.pages.value;
    final fromList = pages.firstWhere(
      (p) => p.url == item.url,
      orElse: () => item,
    );
    setState(() => selected = fromList);
    if (fromList.url.isNotEmpty) {
      controller.loadRequest(Uri.parse(fromList.url));
    }
  }

  @override
  void dispose() {
    ApiService.instance.pages.removeListener(_onPagesUpdated);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // simple title, no temporary ValueNotifier
        title: Text(selected?.description ?? 'Pages'),
        actions: [
          // pages dropdown
          ValueListenableBuilder<List<PageItem>>(
            valueListenable: ApiService.instance.pages,
            builder: (context, pages, _) {
              if (pages.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Center(child: Text('No pages')),
                );
              }

              // ensure the DropdownButton value is an instance from the current list
              final valueInList =
                  selected != null && pages.any((p) => p.url == selected!.url)
                  ? pages.firstWhere((p) => p.url == selected!.url)
                  : null;

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<PageItem>(
                    value: valueInList,
                    hint: const Text('Select'),
                    items: pages.map((p) {
                      return DropdownMenuItem<PageItem>(
                        key: Key(p.url),
                        value: p,
                        child: Text(p.description),
                      );
                    }).toList(),
                    onChanged: _onSelect,
                  ),
                ),
              );
            },
          ),
          // refresh button
          ValueListenableBuilder<bool>(
            valueListenable: ApiService.instance.isWorking,
            builder: (context, loading, _) {
              return IconButton(
                icon: loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white),
                      )
                    : const Icon(Icons.refresh),
                onPressed: loading
                    ? null
                    : () => ApiService.instance.fetchPages(
                        baseUrl: baseUrl,
                        totpCode: TotpService.instance.getCode(),
                      ),
              );
            },
          ),
        ],
      ),
      body: WebViewWidget(controller: controller),
    );
  }
}
