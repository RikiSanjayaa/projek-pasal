import 'package:material_ui/material_ui.dart';

import '../../core/utils/search_utils.dart';
import '../../models/pasal_model.dart';
import 'adaptive_pasal_browser.dart';
import 'pasal_card.dart';
import 'search_tier_header.dart';

/// Responsive rows share the tallest card's height without clipping legal titles.
class PasalResultsView extends StatefulWidget {
  const PasalResultsView({
    super.key,
    required this.items,
    required this.contextList,
    this.controller,
    this.searchQuery = '',
    this.searchResult,
    this.showUULabel = true,
    this.footer,
    this.onLeadingItemChanged,
    this.revealItemId,
  });

  final List<PasalModel> items;
  final List<PasalModel> contextList;
  final ScrollController? controller;
  final String searchQuery;
  final SearchResult? searchResult;
  final bool showUULabel;
  final Widget? footer;
  final ValueChanged<String>? onLeadingItemChanged;
  final String? revealItemId;

  @override
  State<PasalResultsView> createState() => _PasalResultsViewState();
}

class _PasalResultsViewState extends State<PasalResultsView> {
  final List<({int start, int end, SearchTierHeader? header})> _groups = [];
  bool _reading = false;
  double? _browseOffset;
  final Map<int, GlobalKey> _rowKeys = {};
  int _columns = 0;
  int _revealGeneration = 0;
  bool _revealing = false;

  @override
  void initState() {
    super.initState();
    _groupResults();
  }

  @override
  void didUpdateWidget(PasalResultsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.items != widget.items ||
        oldWidget.searchResult != widget.searchResult) {
      _groupResults();
      _browseOffset = null;
    }
    if (widget.revealItemId == null) {
      _revealGeneration++;
      _revealing = false;
    }
    if (widget.revealItemId != null &&
        (oldWidget.revealItemId != widget.revealItemId ||
            oldWidget.items != widget.items)) {
      _scheduleReveal();
    }
  }

  void _groupResults() {
    _groups.clear();
    var start = 0;
    _rowKeys.clear();
    SearchTierHeader? header;
    for (var i = 0; i < widget.items.length; i++) {
      final next = SearchTierHeader.before(
        widget.searchResult,
        widget.items,
        i,
      );
      if (i > 0 && next != null) {
        _groups.add((start: start, end: i, header: header));
        start = i;
      }
      if (i == 0 || next != null) header = next;
    }
    if (widget.items.isNotEmpty)
      _groups.add((start: start, end: widget.items.length, header: header));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reading = AdaptivePasalBrowser.isReading(context);
    final controller = widget.controller;
    if (reading && !_reading && controller != null && controller.hasClients) {
      _browseOffset = controller.offset;
    } else if (!reading && _reading && _browseOffset != null) {
      final offset = _browseOffset!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && controller != null && controller.hasClients) {
          controller.jumpTo(
            offset.clamp(0, controller.position.maxScrollExtent),
          );
        }
      });
    }
    _reading = reading;
  }

  bool _reportScheduled = false;

  void _scheduleLeadingReport() {
    if (_reportScheduled || widget.onLeadingItemChanged == null) return;
    _reportScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _reportScheduled = false;
      if (mounted) _reportLeadingItem();
    });
  }

  void _reportLeadingItem() {
    if (_revealing || widget.onLeadingItemChanged == null) return;
    final viewport = context.findRenderObject();
    if (viewport is! RenderBox || !viewport.hasSize) return;
    final top = viewport.localToGlobal(Offset.zero).dy;
    final bottom = top + viewport.size.height;
    int? leading;
    for (final entry in _rowKeys.entries) {
      final row = entry.value.currentContext?.findRenderObject();
      if (row is! RenderBox || !row.attached || !row.hasSize) continue;
      final rowTop = row.localToGlobal(Offset.zero).dy;
      if (rowTop + row.size.height > top &&
          rowTop < bottom &&
          (leading == null || entry.key < leading)) {
        leading = entry.key;
      }
    }
    if (leading != null) {
      widget.onLeadingItemChanged!(widget.items[leading].id);
    }
  }

  void _scheduleReveal() {
    final generation = ++_revealGeneration;
    _revealing = true;
    void reveal(int attempt) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || generation != _revealGeneration) return;
        final controller = widget.controller;
        final index = widget.items.indexWhere(
          (item) => item.id == widget.revealItemId,
        );
        if (index < 0 || controller == null || !controller.hasClients) {
          _revealing = false;
          return;
        }
        final rowStart = _groups
            .where((group) => index >= group.start && index < group.end)
            .first
            .start;
        final key =
            _rowKeys[rowStart + ((index - rowStart) ~/ _columns) * _columns];
        final target = key?.currentContext;
        if (target != null) {
          final previousOffset = controller.offset;
          Scrollable.ensureVisible(target, alignment: 0);
          if ((controller.offset - previousOffset).abs() > 0.5 &&
              attempt < widget.items.length) {
            reveal(attempt + 1);
            WidgetsBinding.instance.scheduleFrame();
            return;
          }
          _revealing = false;
          _scheduleLeadingReport();
          return;
        }
        // Materialize only the intervening viewport, not every offscreen row.
        if (attempt >= widget.items.length) {
          _revealing = false;
          return;
        }
        final mountedRows = _rowKeys.entries.where(
          (entry) => entry.value.currentContext != null,
        );
        final before = mountedRows.every((entry) => entry.key > index);
        final position = controller.position;
        controller.jumpTo(
          (controller.offset + (before ? -1 : 1) * position.viewportDimension)
              .clamp(position.minScrollExtent, position.maxScrollExtent),
        );
        reveal(attempt + 1);
        WidgetsBinding.instance.scheduleFrame();
      });
    }

    reveal(0);
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = ((constraints.maxWidth - 40 + 12) / 332).floor().clamp(
        1,
        3,
      );
      if (_columns != columns) {
        _columns = columns;
        if (widget.revealItemId != null) _scheduleReveal();
      }
      return NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification.depth == 0) _scheduleLeadingReport();
          return false;
        },
        child: CustomScrollView(
          controller: widget.controller,
          primary: widget.controller == null,
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverMainAxisGroup(
                slivers: [
                  for (final group in _groups) ...[
                    if (group.header != null)
                      SliverToBoxAdapter(child: group.header),
                    SliverList.builder(
                      itemCount: ((group.end - group.start) / columns).ceil(),
                      itemBuilder: (context, row) {
                        final cards = Row(
                          crossAxisAlignment: columns == 1
                              ? CrossAxisAlignment.start
                              : CrossAxisAlignment.stretch,
                          children: [
                            for (var column = 0; column < columns; column++)
                              Expanded(
                                child: Padding(
                                  padding: EdgeInsets.only(
                                    right: column < columns - 1 ? 12 : 0,
                                  ),
                                  child:
                                      group.start + row * columns + column <
                                          group.end
                                      ? PasalCard(
                                          pasal:
                                              widget.items[group.start +
                                                  row * columns +
                                                  column],
                                          contextList: widget.contextList,
                                          searchQuery: widget.searchQuery,
                                          showUULabel: widget.showUULabel,
                                        )
                                      : const SizedBox.shrink(),
                                ),
                              ),
                          ],
                        );
                        // Measure only the current row (at most three cards), not the list.
                        final child = columns == 1
                            ? cards
                            : IntrinsicHeight(child: cards);
                        if (widget.onLeadingItemChanged == null) return child;
                        return KeyedSubtree(
                          key: _rowKeys.putIfAbsent(
                            group.start + row * columns,
                            GlobalKey.new,
                          ),
                          child: child,
                        );
                      },
                    ),
                  ],
                  SliverToBoxAdapter(
                    child: widget.footer ?? const SizedBox(height: 20),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}
