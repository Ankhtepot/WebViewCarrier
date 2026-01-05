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
      if (pages.isNotEmpty) {
        setState(() => selected = pages.first);
        // load the page after the frame so the WebView widget is mounted
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (selected != null && selected!.url.isNotEmpty) {
            controller.loadRequest(Uri.parse(selected!.url));
          }
        });
      }
      return;
    }
    // try to find the same logical page (by url) in the new list and update selected to that instance
    final matched = pages.firstWhere(
      (p) => p.url == selected!.url,
      orElse: () => PageItem(description: '', url: ''),
    );
    if (matched.url.isEmpty) {
      // selected no longer exists in new pages -> chose first one
      setState(() => selected = pages.isNotEmpty ? pages.first : null);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (selected != null && selected!.url.isNotEmpty) {
          controller.loadRequest(Uri.parse(selected!.url));
        }
      });
    } else if (!identical(matched, selected)) {
      // update to the new list instance so Dropdown value matches exactly one item
      setState(() => selected = matched);
      // load newly matched page after frame
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (selected != null && selected!.url.isNotEmpty) {
          controller.loadRequest(Uri.parse(selected!.url));
        }
      });
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
    // load after frame to ensure webview is mounted
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (fromList.url.isNotEmpty) controller.loadRequest(Uri.parse(fromList.url));
    });
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
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        // Title should just show WebView
        title: const Text('WebView', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        actions: [
          // pages dropdown
          ValueListenableBuilder<FetchStatus>(
            valueListenable: ApiService.instance.fetchStatus,
            builder: (context, status, _) {
              return ValueListenableBuilder<List<PageItem>>(
                valueListenable: ApiService.instance.pages,
                builder: (context, pages, _) {
                  final disabled = (status == FetchStatus.empty || status == FetchStatus.failed) && pages.isEmpty;

                  if (pages.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Center(
                        child: Text(
                          disabled ? 'No pages' : 'Loading',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    );
                  }

                  // always show the selected description in the button (remove static selectedItemBuilder)
                  final valueInList = selected != null && pages.any((p) => p.url == selected!.url)
                      ? pages.firstWhere((p) => p.url == selected!.url)
                      : null;

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: SizedBox(
                      width: 220,
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<PageItem>(
                          // value must be an instance from the current pages list (we already compute valueInList)
                          value: valueInList,
                          icon: const Icon(Icons.arrow_drop_down, color: Colors.white, size: 28),
                          iconSize: 28,
                          // When closed, use white text so it's visible on the black AppBar
                          // We'll define `style` once below.
                          // The drop-down menu items (when opened) should use black text on white background
                          dropdownColor: Colors.white,
                          items: pages.map((p) {
                            return DropdownMenuItem<PageItem>(
                              key: Key(p.url),
                              value: p,
                              child: Text(p.description, style: const TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                            );
                          }).toList(),
                          // Render the closed button's selected label in white so it's visible on the AppBar.
                          // Use a simple Container (no Expanded/Flexible) to avoid layout issues.
                          selectedItemBuilder: (context) {
                            return pages.map((p) {
                              return Container(
                                alignment: Alignment.centerLeft,
                                padding: const EdgeInsets.only(right: 5.0),
                                child: Text(
                                  p.description,
                                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList();
                          },
                          hint: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 36.0),
                            child: const Text('Choose Page', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
                          ),
                          disabledHint: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 36.0),
                            child: const Text('Choose Page', style: TextStyle(color: Colors.white54, fontSize: 20, fontWeight: FontWeight.w700)),
                          ),
                          onChanged: disabled || ApiService.instance.isWorking.value ? null : _onSelect,
                          // Show the selected item's label in white (visible on the black AppBar)
                          style: const TextStyle(color: Colors.white, fontSize: 18),
                          // Allow the closed button to use the available width so the label is visible
                          isExpanded: true,
                          iconEnabledColor: Colors.white,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                  );
                },
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
                    : const Icon(Icons.refresh, color: Colors.white),
                onPressed: loading
                    ? null
                    : () async {
                        // force fetch and update fetchStatus
                        final success = await ApiService.instance.fetchPages(
                          baseUrl: baseUrl,
                          totpCode: TotpService.instance.getCode(),
                        );

                        // if fetch succeeded and there were pages, pick first if nothing selected
                        final pages = ApiService.instance.pages.value;
                        if (success && pages.isNotEmpty && selected == null) {
                          setState(() => selected = pages.first);
                          controller.loadRequest(Uri.parse(selected!.url));
                        }
                      },
              );
            },
          ),
        ],
      ),
      body: ValueListenableBuilder<FetchStatus>(
        valueListenable: ApiService.instance.fetchStatus,
        builder: (context, status, _) {
          return ValueListenableBuilder<List<PageItem>>(
            valueListenable: ApiService.instance.pages,
            builder: (context, pages, _) {
              if (pages.isEmpty) {
                if (status == FetchStatus.empty) {
                  return const Center(child: _EmptyState());
                }
                if (status == FetchStatus.failed) {
                  return const Center(child: _ErrorState());
                }
                // initial loading or idle
                return const Center(child: _LoadingState());
              }

              // normal: show webview (selection is handled by _onPagesUpdated listener)
              return WebViewWidget(controller: controller);
            },
          );
        },
      ),
    );
  }
}

// helper small widgets
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: const [
        Icon(Icons.inbox, size: 64, color: Colors.grey),
        SizedBox(height: 12),
        Text('No pages available to choose', style: TextStyle(fontSize: 16)),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: const [
        Icon(Icons.error_outline, size: 64, color: Colors.red),
        SizedBox(height: 12),
        Text('Retrieving pages failed, nothing to show', style: TextStyle(fontSize: 16)),
      ],
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: const [
        CircularProgressIndicator(),
        SizedBox(height: 12),
        Text('Loading pages...', style: TextStyle(fontSize: 16)),
      ],
    );
  }
}
