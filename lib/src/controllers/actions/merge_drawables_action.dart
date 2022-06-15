import 'package:flutter/foundation.dart';
import 'package:flutter_painter/flutter_painter.dart';

import '../drawables/grouped_drawable.dart';

import '../drawables/drawable.dart';

import '../painter_controller.dart';
import 'action.dart';

/// An action of merging all drawables in the [PainterController] into a [GroupedDrawable].
class MergeDrawablesAction extends ControllerAction<void, void> {
  /// Creates a [MergeDrawablesAction].
  MergeDrawablesAction();

  /// Performs the action.
  ///
  /// Removes all drawables from [controller.value] and inserts a new [GroupedDrawable]
  /// containing all the removed drawables.
  ///
  /// Also sets the selected object drawable to `null` since the selected object drawable would
  /// be removed and replaced with the [GroupedDrawable].
  @protected
  @override
  void perform$(PainterController controller) {
    final value = controller.value;

    final currentDrawables = List<Drawable>.from(value.drawables);

    final shouldMergeDrawables = <Drawable>[];
    final ignoreDrawables = <Drawable>[];
    for (var element in currentDrawables) {
      if(element is TextDrawable){
        // element.
        ignoreDrawables.add(element);
      }else{
        shouldMergeDrawables.add(element);
      }
    }

    final groupedDrawable = GroupedDrawable(drawables: shouldMergeDrawables);
    controller.value = value.copyWith(
      drawables: [...ignoreDrawables,groupedDrawable],
    );
    controller.deselectObjectDrawable(isRemoved: true);
  }

  /// Un-performs the action.
  ///
  /// Removes the [GroupedDrawable] from [controller.value] and inserts back
  /// [GroupedDrawable.drawables] from it.
  @protected
  @override
  void unperform$(PainterController controller) {
    final value = controller.value;
    final currentDrawables = List<Drawable>.from(value.drawables);
    final last = currentDrawables.last;
    if (last is! GroupedDrawable) return;
    final drawables = last.drawables;
    currentDrawables.removeLast();
    currentDrawables.addAll(drawables);
    controller.value = value.copyWith(drawables: currentDrawables);
  }
}
