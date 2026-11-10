import 'package:material_ui/material_ui.dart';

import '../../core/config/app_colors.dart';
import '../../models/pasal_model.dart';
import '../screens/read_pasal_screen.dart';
import '../utils/responsive_layout.dart';

/// Keeps both panes mounted so resizing never discards a query or reading offset.
class AdaptivePasalBrowser extends StatefulWidget {
  const AdaptivePasalBrowser({super.key, required this.child, this.onBack});

  final Widget child;
  final VoidCallback? onBack;

  static bool isReading(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_BrowserScope>()?.reading ??
      false;

  static String? selectedPasalIdOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<_BrowserScope>()
      ?.selectedPasalId;

  static bool open(
    BuildContext context, {
    required PasalModel pasal,
    required List<PasalModel> contextList,
    required String searchQuery,
  }) {
    final browser = context.dependOnInheritedWidgetOfExactType<_BrowserScope>();
    if (browser == null) return false;
    browser.state.open(pasal, contextList, searchQuery);
    return true;
  }

  @override
  State<AdaptivePasalBrowser> createState() => _AdaptivePasalBrowserState();
}

class _AdaptivePasalBrowserState extends State<AdaptivePasalBrowser> {
  PasalModel? _selected;
  List<PasalModel> _contextList = const [];
  String _query = '';
  int _selection = 0;

  void open(PasalModel pasal, List<PasalModel> contextList, String query) {
    FocusScope.of(context).unfocus();
    setState(() {
      _selected = pasal;
      _contextList = contextList;
      _query = query;
      _selection++;
    });
  }

  void _close() => setState(() => _selected = null);

  @override
  Widget build(BuildContext context) {
    final expanded =
        MediaQuery.sizeOf(context).width >= ResponsiveLayout.expanded;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final active = TickerMode.valuesOf(context).enabled;
    return _BrowserScope(
      state: this,
      selectedPasalId: _selected?.id,
      child: PopScope(
        canPop: !active || (_selected == null && widget.onBack == null),
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop && active) {
            if (_selected != null) {
              _close();
            } else {
              widget.onBack?.call();
            }
          }
        },
        child: LayoutBuilder(
          builder: (context, constraints) {
            final split =
                expanded && _selected != null && constraints.maxWidth >= 720;
            final listWidth = split
                ? (constraints.maxWidth * 0.40).clamp(300.0, 440.0)
                : constraints.maxWidth;
            return Stack(
              children: [
                Positioned(
                  top: 0,
                  bottom: 0,
                  left: 0,
                  width: listWidth,
                  child: Offstage(
                    offstage: !split && _selected != null,
                    child: TickerMode(
                      enabled: split || _selected == null,
                      child: widget.child,
                    ),
                  ),
                ),
                if (split)
                  Positioned(
                    top: 0,
                    bottom: 0,
                    left: listWidth,
                    child: VerticalDivider(
                      width: 1,
                      color: AppColors.border(isDark),
                    ),
                  ),
                Positioned(
                  key: const ValueKey('reader-pane'),
                  top: 0,
                  bottom: 0,
                  left: split ? listWidth + 1 : 0,
                  right: 0,
                  child: Offstage(
                    offstage: _selected == null,
                    child: _selected == null
                        ? const SizedBox.shrink()
                        : ReadPasalScreen(
                            key: ValueKey(_selection),
                            pasal: _selected!,
                            contextList: _contextList,
                            searchQuery: _query,
                            onBack: _close,
                          ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _BrowserScope extends InheritedWidget {
  const _BrowserScope({
    required this.state,
    required this.selectedPasalId,
    required super.child,
  });

  final _AdaptivePasalBrowserState state;
  final String? selectedPasalId;

  bool get reading => selectedPasalId != null;

  @override
  bool updateShouldNotify(_BrowserScope oldWidget) =>
      selectedPasalId != oldWidget.selectedPasalId;
}
