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
  });
  final Widget child;
  final VoidCallback onEdit, onDelete;
  final String label;
  @override
  State<SwipeActions> createState() => _SwipeActionsState();
}

class _SwipeActionsState extends State<SwipeActions> {
  static const _width = 144.0;
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
          onHorizontalDragStart: (_) => setState(() => _dragging = true),
          onHorizontalDragUpdate: (d) => setState(
            () => _offset = (_offset + d.delta.dx).clamp(-_width, 0),
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
                  duration: _dragging || MediaQuery.disableAnimationsOf(context)
                      ? Duration.zero
                      : const Duration(milliseconds: 180),
                  transform: Matrix4.translationValues(_offset, 0, 0),
                  child: Stack(
                    children: [
                      ExcludeFocus(
                        excluding: _offset != 0,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: ColoredBox(
                            color: AppColors.white,
                            child: widget.child,
                          ),
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
