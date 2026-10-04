import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/semantics.dart';

import '../theme/app_colors.dart';

/// Right reveals delete; left reveals edit. Swiping never deletes a record.
class SwipeActions extends StatefulWidget {
  const SwipeActions({
    super.key,
    required this.child,
    required this.onEdit,
    required this.onDelete,
    required this.label,
  });
  final Widget child;
  final VoidCallback onEdit, onDelete;
  final String label;
  @override
  State<SwipeActions> createState() => _SwipeActionsState();
}

class _SwipeActionsState extends State<SwipeActions> {
  static const _width = 80.0;
  double _offset = 0;
  bool _dragging = false;
  final _focus = FocusNode();
  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  void _reveal(double offset) {
    setState(() => _offset = offset);
    _focus.requestFocus();
  }

  void _close() => setState(() => _offset = 0);
  void _run(bool delete) {
    _close();
    (delete ? widget.onDelete : widget.onEdit)();
  }

  KeyEventResult _key(FocusNode _, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.escape && _offset != 0) {
      _close();
    } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      _reveal(_width);
    } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      _reveal(-_width);
    } else if (_offset != 0 && event.logicalKey == LogicalKeyboardKey.enter) {
      _run(_offset > 0);
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
          onHorizontalDragStart: (_) => setState(() => _dragging = true),
          onHorizontalDragUpdate: (d) => setState(
            () => _offset = (_offset + d.delta.dx).clamp(-_width, _width),
          ),
          onHorizontalDragEnd: (_) {
            setState(() {
              _dragging = false;
              _offset = _offset.abs() < 30 ? 0 : _offset.sign * _width;
            });
            if (_offset != 0) _focus.requestFocus();
          },
          onHorizontalDragCancel: () {
            if (!_dragging) return;
            setState(() {
              _dragging = false;
              _offset = 0;
            });
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              children: [
                if (_offset != 0)
                  Positioned.fill(
                    child: ColoredBox(
                      color: _offset > 0
                          ? AppColors.dangerSoft
                          : AppColors.primarySoft,
                      child: Align(
                        alignment: _offset > 0
                            ? Alignment.centerLeft
                            : Alignment.centerRight,
                        child: SizedBox(
                          width: _width,
                          child: IconButton(
                            tooltip:
                                '${widget.label} ${_offset > 0 ? '삭제' : '수정'}',
                            color: _offset > 0
                                ? AppColors.danger
                                : AppColors.primary,
                            onPressed: () => _run(_offset > 0),
                            icon: Icon(
                              _offset > 0
                                  ? Icons.delete_outline_rounded
                                  : Icons.edit_outlined,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                AnimatedContainer(
                  duration: _dragging || MediaQuery.disableAnimationsOf(context)
                      ? Duration.zero
                      : const Duration(milliseconds: 180),
                  transform: Matrix4.translationValues(_offset, 0, 0),
                  child: Stack(
                    children: [
                      ColoredBox(color: AppColors.white, child: widget.child),
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
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
