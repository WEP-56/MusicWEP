import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

class HorizontalItemScroller extends StatefulWidget {
  const HorizontalItemScroller({
    super.key,
    required this.height,
    required this.itemCount,
    required this.itemBuilder,
    this.separatorBuilder,
    this.scrollStep = 220,
  });

  final double height;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final IndexedWidgetBuilder? separatorBuilder;
  final double scrollStep;

  @override
  State<HorizontalItemScroller> createState() => _HorizontalItemScrollerState();
}

class _HorizontalItemScrollerState extends State<HorizontalItemScroller> {
  late final ScrollController _controller;
  bool _canScrollBackward = false;
  bool _canScrollForward = false;

  @override
  void initState() {
    super.initState();
    _controller = ScrollController()..addListener(_syncScrollState);
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncScrollState());
  }

  @override
  void didUpdateWidget(covariant HorizontalItemScroller oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncScrollState());
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_syncScrollState)
      ..dispose();
    super.dispose();
  }

  void _syncScrollState() {
    if (!mounted || !_controller.hasClients) {
      return;
    }
    final position = _controller.position;
    final canScrollBackward = position.pixels > position.minScrollExtent;
    final canScrollForward = position.pixels < position.maxScrollExtent;
    if (canScrollBackward == _canScrollBackward &&
        canScrollForward == _canScrollForward) {
      return;
    }
    setState(() {
      _canScrollBackward = canScrollBackward;
      _canScrollForward = canScrollForward;
    });
  }

  Future<void> _scrollBy(double delta) async {
    if (!_controller.hasClients) {
      return;
    }
    final position = _controller.position;
    final target = (position.pixels + delta).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    await _controller.animateTo(
      target,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        _ScrollArrowButton(
          icon: Icons.chevron_left_rounded,
          enabled: _canScrollBackward,
          onTap: () => _scrollBy(-widget.scrollStep),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: ScrollConfiguration(
            behavior: const MaterialScrollBehavior().copyWith(
              scrollbars: false,
              dragDevices: PointerDeviceKind.values.toSet(),
            ),
            child: Scrollbar(
              controller: _controller,
              thumbVisibility: true,
              interactive: true,
              scrollbarOrientation: ScrollbarOrientation.bottom,
              child: SizedBox(
                height: widget.height,
                child: ListView.separated(
                  controller: _controller,
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.only(bottom: 6),
                  itemCount: widget.itemCount,
                  separatorBuilder:
                      widget.separatorBuilder ??
                      (_, _) => const SizedBox(width: 8),
                  itemBuilder: widget.itemBuilder,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),
        _ScrollArrowButton(
          icon: Icons.chevron_right_rounded,
          enabled: _canScrollForward,
          onTap: () => _scrollBy(widget.scrollStep),
        ),
      ],
    );
  }
}

class _ScrollArrowButton extends StatelessWidget {
  const _ScrollArrowButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: enabled
              ? theme.colorScheme.surfaceContainerLow
              : theme.colorScheme.surfaceContainerLow.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: enabled
                ? theme.dividerColor
                : theme.dividerColor.withValues(alpha: 0.45),
          ),
        ),
        child: Icon(
          icon,
          size: 18,
          color: enabled
              ? theme.colorScheme.onSurfaceVariant
              : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.42),
        ),
      ),
    );
  }
}
