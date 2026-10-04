import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/semantics.dart';

import '../theme/app_colors.dart';

/// Swipe left to reveal both actions. Swiping never changes a record.
class SwipeActions extends StatefulWidget {
  const SwipeActions({
    super.key,
    required this.child,
    required this.onEdit,
    required this.onDelete,
    required this.label,
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
    this.previewSwipe = false,
  });
  final Widget child;
  final VoidCallback onEdit, onDelete;
  final String label;
  final BorderRadius borderRadius;
  final bool previewSwipe;
  @override
  State<SwipeActions> createState() => _SwipeActionsState();
}

class _SwipeActionsState extends State<SwipeActions>
    with SingleTickerProviderStateMixin {
  static const _width = 144.0;
  double _offset = 0;
  double _dragDistance = 0;
  bool _startedOpen = false, _draggedLeft = false;
  bool _dragging = false;
  final _focus = FocusNode();
  late final _preview = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 4000),
  );
  late final _previewOffset = TweenSequence<double>([
    TweenSequenceItem(tween: ConstantTween(0.0), weight: 25),
    TweenSequenceItem(
      tween: Tween<double>(
        begin: 0,
        end: -_width,
      ).chain(CurveTween(curve: Curves.easeOutCubic)),
      weight: 20,
    ),
    TweenSequenceItem(tween: ConstantTween(-_width), weight: 35),
    TweenSequenceItem(
      tween: Tween<double>(
        begin: -_width,
        end: 0,
      ).chain(CurveTween(curve: Curves.easeOutCubic)),
      weight: 20,
    ),
  ]).animate(_preview);
  @override
  void initState() {
    super.initState();
    _preview.addListener(() => setState(() => _offset = _previewOffset.value));
    if (widget.previewSwipe) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (MediaQuery.disableAnimationsOf(context)) {
          setState(() => _offset = -_width);
        } else {
          _preview.forward();
        }
      });
    }
  }

  @override
  void dispose() {
    _focus.dispose();
    _preview.dispose();
    super.dispose();
  }

  void _reveal(double offset) {
    _preview.stop();
    setState(() => _offset = offset);
    _focus.requestFocus();
  }

  void _close() {
    _preview.stop();
    setState(() => _offset = 0);
  }

  void _run(bool delete) {
    _close();
    (delete ? widget.onDelete : widget.onEdit)();
  }

  KeyEventResult _key(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.escape && _offset != 0) {
      _close();
    } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      _close();
    } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      _reveal(-_width);
    } else if (_offset != 0 &&
        node.hasPrimaryFocus &&
        event.logicalKey == LogicalKeyboardKey.enter) {
      _run(false);
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) => Focus(
    focusNode: _focus,
    onKeyEvent: _key,
    child: Semantics(
      customSemanticsActions: {
        CustomSemanticsAction(label: '${widget.label} 수정'): () => _run(false),
        CustomSemanticsAction(label: '${widget.label} 삭제'): () => _run(true),
      },
      child: TapRegion(
        onTapOutside: (_) {
          if (_offset != 0 && !_dragging) _close();
        },
        child: GestureDetector(
          onTapDown: (_) => _focus.requestFocus(),
          onHorizontalDragStart: (_) {
            _preview.stop();
            _startedOpen = _offset != 0;
            _draggedLeft = false;
            _dragDistance = 0;
            setState(() => _dragging = true);
          },
          onHorizontalDragUpdate: (d) {
            _dragDistance += d.delta.dx;
            _draggedLeft |= d.delta.dx < 0;
            setState(() => _offset = (_offset + d.delta.dx).clamp(-_width, 0));
          },
          onHorizontalDragEnd: (_) {
            setState(() {
              _dragging = false;
              _offset = _offset.abs() < 30 ? 0 : _offset.sign * _width;
            });
            if (_offset != 0) _focus.requestFocus();
            // An open row closes first; a closed row can navigate back.
            if (!_startedOpen &&
                !_draggedLeft &&
                _dragDistance >= 96 &&
                !widget.previewSwipe) {
              Navigator.of(context).maybePop();
            }
          },
          onHorizontalDragCancel: () {
            if (!_dragging) return;
            setState(() {
              _dragging = false;
              _offset = 0;
            });
          },
          child: ClipRRect(
            borderRadius: widget.borderRadius,
            child: Stack(
              children: [
                if (_offset != 0)
                  const Positioned.fill(
                    child: ColoredBox(color: AppColors.primarySoft),
                  ),
                if (_offset != 0)
                  Positioned.fill(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: SizedBox(
                        width: _width,
                        height: double.infinity,
                        child: Row(children: [_action(false), _action(true)]),
                      ),
                    ),
                  ),
                AnimatedContainer(
                  duration:
                      _dragging ||
                          _preview.isAnimating ||
                          MediaQuery.disableAnimationsOf(context)
                      ? Duration.zero
                      : const Duration(milliseconds: 180),
                  transform: Matrix4.translationValues(_offset, 0, 0),
                  child: Stack(
                    children: [
                      ExcludeFocus(
                        excluding: _offset != 0,
                        child: ClipRRect(
                          borderRadius: widget.borderRadius,
                          child: widget.child,
                        ),
                      ),
                      if (_offset != 0)
                        Positioned.fill(
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: _close,
                          ),
                        ),
                    ],
                  ),
                ),
                if (widget.previewSwipe && _preview.isAnimating)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: ExcludeSemantics(
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: Transform.translate(
                            offset: Offset(_offset, -8),
                            child: const Icon(
                              Icons.touch_app_outlined,
                              size: 28,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  Widget _action(bool delete) => Expanded(
    child: Tooltip(
      message: '${widget.label} ${delete ? '삭제' : '수정'}',
      child: TextButton(
        style: TextButton.styleFrom(
          backgroundColor: delete
              ? AppColors.dangerSoft
              : AppColors.primarySoft,
          foregroundColor: delete ? AppColors.danger : AppColors.primary,
          shape: const RoundedRectangleBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 4),
          minimumSize: const Size(72, double.infinity),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        onPressed: () => _run(delete),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              delete ? Icons.delete_outline_rounded : Icons.edit_outlined,
              size: 22,
            ),
            const SizedBox(height: 5),
            Text(
              delete ? '삭제' : '수정',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    ),
  );
}
