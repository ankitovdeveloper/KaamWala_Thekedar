import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

/// Keeps every tab mounted (so scroll position and controllers survive) while
/// still animating the swap: the outgoing page slides off and fades, the
/// incoming one arrives from the opposite side. Direction follows tab order,
/// which makes the nav bar feel spatial rather than arbitrary.
class SharedAxisIndexedStack extends StatefulWidget {
  const SharedAxisIndexedStack({
    super.key,
    required this.index,
    required this.children,
    this.travel = 26,
  });

  final int index;
  final List<Widget> children;

  /// Horizontal travel of the transition, in logical pixels.
  final double travel;

  @override
  State<SharedAxisIndexedStack> createState() => _SharedAxisIndexedStackState();
}

class _SharedAxisIndexedStackState extends State<SharedAxisIndexedStack>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: Motion.normal,
    value: 1,
  );

  late int _current = widget.index;
  int? _outgoing;
  int _direction = 1;

  /// Tabs are mounted on first visit only, so an unopened tab costs nothing.
  late final Set<int> _mounted = {widget.index};

  @override
  void didUpdateWidget(covariant SharedAxisIndexedStack old) {
    super.didUpdateWidget(old);
    if (widget.index == old.index) return;

    setState(() {
      _direction = widget.index > _current ? 1 : -1;
      _outgoing = _current;
      _current = widget.index;
      _mounted.add(_current);
    });

    if (MediaQuery.disableAnimationsOf(context)) {
      _c.value = 1;
      _outgoing = null;
      return;
    }

    _c.forward(from: 0).whenCompleteOrCancel(() {
      if (mounted) setState(() => _outgoing = null);
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = Motion.emphasized.transform(_c.value);

        return Stack(
          children: [
            for (var i = 0; i < widget.children.length; i++)
              if (_mounted.contains(i))
                _layer(index: i, t: t, child: widget.children[i]),
          ],
        );
      },
    );
  }

  Widget _layer({
    required int index,
    required double t,
    required Widget child,
  }) {
    final isCurrent = index == _current;
    final isOutgoing = index == _outgoing;
    final visible = isCurrent || isOutgoing;

    // Everything else stays mounted but frozen and out of the way.
    if (!visible) {
      return Positioned.fill(
        child: TickerMode(enabled: false, child: Offstage(child: child)),
      );
    }

    final opacity = isCurrent ? t : 1 - t;
    final dx = isCurrent
        ? widget.travel * _direction * (1 - t)
        : -widget.travel * _direction * t;

    return Positioned.fill(
      child: IgnorePointer(
        ignoring: !isCurrent,
        child: Opacity(
          opacity: opacity.clamp(0.0, 1.0),
          child: Transform.translate(offset: Offset(dx, 0), child: child),
        ),
      ),
    );
  }
}
