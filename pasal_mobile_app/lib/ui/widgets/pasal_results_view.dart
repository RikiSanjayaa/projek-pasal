import 'package:material_ui/material_ui.dart';

import '../../core/utils/search_utils.dart';
import '../../models/pasal_model.dart';
import 'adaptive_pasal_browser.dart';
import 'pasal_card.dart';
import 'search_tier_header.dart';

/// Variable-height grid rows keep long legal titles readable without fixed tile heights.
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
  });

  final List<PasalModel> items;
  final List<PasalModel> contextList;
  final ScrollController? controller;
  final String searchQuery;
  final SearchResult? searchResult;
  final bool showUULabel;
  final Widget? footer;

  @override
  State<PasalResultsView> createState() => _PasalResultsViewState();
}

class _PasalResultsViewState extends State<PasalResultsView> {
  final List<({int start, int end, SearchTierHeader? header})> _groups = [];
  bool _reading = false;
  double? _browseOffset;

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
  }

  void _groupResults() {
    _groups.clear();
    var start = 0;
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

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = ((constraints.maxWidth - 40 + 12) / 332).floor().clamp(
        1,
        3,
      );
      return CustomScrollView(
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
                    itemBuilder: (context, row) => Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
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
                    ),
                  ),
                ],
                SliverToBoxAdapter(
                  child: widget.footer ?? const SizedBox(height: 20),
                ),
              ],
            ),
          ),
        ],
      );
    },
  );
}
