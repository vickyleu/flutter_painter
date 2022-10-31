part of 'flutter_painter.dart';

/// Flutter widget to detect user input and request drawing [FreeStyleDrawable]s.
class _FreeStyleWidget extends StatefulWidget {
  /// Child widget.
  final Widget child;
  final Size? scale;

  /// Creates a [_FreeStyleWidget] with the given [controller], [child] widget.
  const _FreeStyleWidget({
    Key? key,
    required this.child,
    required this.scale,
  }) : super(key: key);

  @override
  _FreeStyleWidgetState createState() => _FreeStyleWidgetState();
}

/// State class
class _FreeStyleWidgetState extends State<_FreeStyleWidget> {
  /// The current drawable being drawn.
  Map<int, PathDrawable> drawable = {};
  Map<int, HandEraserDrawable> eraserDrawable = {};
  FreeStyleMode? oldMode;

  bool freeHand = true;
  StreamSubscription<HandEraserEvent>? subscription;


  @override
  void initState() {
    super.initState();
    subscription = eventBus.on<HandEraserEvent>().listen((event) {
      if(!GlobalConfig.of(context).isOverlayShowing){
        onHandEraserCalling(event);
      }
    });
  }

  void onHandEraserCalling(HandEraserEvent event) {
    final controller = PainterController.maybeOf(context);
    if (controller == null) return;
    if(controller.isCovered()){
      return;
    }
    final currentSize =
        (freeStyleParentKey.currentContext?.findRenderObject() as RenderBox?)
            ?.size;
    if (currentSize == null) return;
    final centerLocation = _translateLocation(
        currentSize,
        _globalToLocal(
            Offset(event.point.x.toDouble(), event.point.y.toDouble())));
    if (centerLocation == Offset.zero) return;

    var xScale = 1.0;
    var yScale = 1.0;
    if (widget.scale != null) {
      final originSize = widget.scale!;
      if (originSize != currentSize) {
        xScale = originSize.width / currentSize.width;
        yScale = originSize.height / currentSize.height;
      }
    }
    final rect = Rect.fromLTWH(
        centerLocation.dx - event.size.width / 2,
        centerLocation.dy - event.size.height / 2,
        event.size.width * xScale,
        event.size.height * yScale);

    switch (event.event) {
      case 'WM_POINTERLEAVE': //松手
        {
          if (!eraserDrawable.containsKey(event.pointerId)) return;
          final oldDrawable = eraserDrawable[event.pointerId]!;
          oldDrawable
            ..centerLocation = centerLocation
            ..size = event.size
            ..handLeave = true
            ..path.add(rect);
          controller.notifyListeners();

          eraserDrawable.remove(event.pointerId);
          if (eraserDrawable.keys.isEmpty) {
            //如果没有手掌放在屏幕上了,打开放大缩小
            controller.scaleSettings =
                controller.scaleSettings.copyWith(enabled: true);
          }
          DrawableCreatedNotification(oldDrawable).dispatch(context);
        }
        break;
      case 'WM_POINTERDOWN': //
        {
          final drawable = HandEraserDrawable(
              event.pointerId, centerLocation, event.size,
              path: [rect], handLeave: false);
          eraserDrawable[event.pointerId] = drawable;
          //TODO 这里是合并所有drawable变成一个图形,groupDrawables必须将文字单独拎出来不合并,否则文字就不可以再修改了,但是同时存在一个问题,
          //TODO  文字修改移动不会让 EraseDrawable 跟着移动,还得好好想想怎么处理
          controller.scaleSettings =
              controller.scaleSettings.copyWith(enabled: false);
          controller.groupDrawables();
          // setState(() {
            controller.addDrawables([drawable], newAction: false);
          // });
          DrawableCreatedNotification(drawable).dispatch(context);
        }
        break;
      case 'WM_POINTERUPDATE': //
        {
          if (eraserDrawable.containsKey(event.pointerId)) {
            final oldDrawable = eraserDrawable[event.pointerId]!;
            oldDrawable
              ..centerLocation = centerLocation
              ..size = event.size
              ..handLeave = false
              ..path.add(rect);

            controller.notifyListeners();
            DrawableCreatedNotification(oldDrawable).dispatch(context);
          } else {
            final drawable = HandEraserDrawable(
                event.pointerId, centerLocation, event.size,
                path: [rect], handLeave: false);
            eraserDrawable[event.pointerId] = drawable;
            //TODO 这里是合并所有drawable变成一个图形,groupDrawables必须将文字单独拎出来不合并,否则文字就不可以再修改了,但是同时存在一个问题,
            //TODO  文字修改移动不会让 EraseDrawable 跟着移动,还得好好想想怎么处理
            controller.scaleSettings =
                controller.scaleSettings.copyWith(enabled: false);
            controller.groupDrawables();

            // setState(() {
              controller.addDrawables([drawable], newAction: false);
            // });
            DrawableCreatedNotification(drawable).dispatch(context);
          }
        }
    }
  }

  GlobalKey freeStyleParentKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    if (settings.mode == FreeStyleMode.none || shapeSettings.factory != null) {
      return widget.child;
    }
    oldMode ??= settings.mode;
    final om = oldMode;
    oldMode = settings.mode;

    return RawGestureDetector(
      key: freeStyleParentKey,
      behavior: HitTestBehavior.opaque,
      gestures: {
        _MultiDragGestureDetector:
            GestureRecognizerFactoryWithHandlers<_MultiDragGestureDetector>(
          () => _MultiDragGestureDetector(
              onHorizontalDragDown: (pointer, offset) =>
                  _handleHorizontalDragDown(pointer, offset),
              onHorizontalDragUpdate: (pointer, offset) =>
                  _handleHorizontalDragUpdate(
                    pointer,
                    offset,
                    isNew: om != settings.mode,
                  ),
              onHorizontalDragUp: (pointer) => _handleHorizontalDragUp(pointer),
              onMultiDragEnableCheck: () {
                return [FreeStyleMode.draw, FreeStyleMode.erase]
                    .contains(settings.mode);
              },
              context: context),
          (_) {},
        ),
      },
      child: widget.child,
    );
  }

  /// Getter for [FreeStyleSettings] from `widget.controller.value` to make code more readable.
  FreeStyleSettings get settings =>
      PainterController.of(context).value.settings.freeStyle;

  /// Getter for [ShapeSettings] from `widget.controller.value` to make code more readable.
  ShapeSettings get shapeSettings =>
      PainterController.of(context).value.settings.shape;

  bool MouseTesting = false;

  /// Callback when the user holds their pointer(s) down onto the widget.
  void _handleHorizontalDragDown(int pointer, Offset globalPosition) {
    // If the user is already drawing, don't create a new drawing
    if (this.drawable.containsKey(pointer)) {
      return;
    }
    final currentSize =
        (freeStyleParentKey.currentContext?.findRenderObject() as RenderBox?)
            ?.size;
    if (currentSize == null){
      return;
    }
    if (MouseTesting) {
      final location =
          _translateLocation(currentSize, _globalToLocal(globalPosition));
      onHandEraserCalling(HandEraserEvent(
          pointer,
          Point(location.dx, location.dy),
          const Size(100, 100),
          "WM_POINTERDOWN"));
      return;
    } else {
      if (eraserDrawable.isNotEmpty){
        return;
      }
    }
    // Create a new free-style drawable representing the current drawing
    final PathDrawable drawable;
    if (settings.mode == FreeStyleMode.draw) {
      final location =
          _translateLocation(currentSize, _globalToLocal(globalPosition));
      setFreeHand(true, location);
      // drawable = FreeStyleDrawable(
      //   path: [location],
      //   color: settings.color,
      //   strokeWidth: settings.strokeWidth,
      // );
      drawable = CubicPathDrawable(
        path: [location],
        color: settings.color,
        strokeWidth: settings.strokeWidth,
      );
      (drawable as CubicPathDrawable).startPath(location);

      // Add the drawable to the controller's drawables
      PainterController.of(context).addDrawables([drawable]);
      DrawableCreatedNotification(drawable).dispatch(context);

    } else if (settings.mode == FreeStyleMode.erase) {
      drawable = EraseDrawable(
        path: [_translateLocation(currentSize, _globalToLocal(globalPosition))],
        strokeWidth: settings.eraseWidth,
      );
      //TODO 这里是合并所有drawable变成一个图形,groupDrawables必须将文字单独拎出来不合并,否则文字就不可以再修改了,但是同时存在一个问题,
      //TODO  文字修改移动不会让 EraseDrawable 跟着移动,还得好好想想怎么处理
      PainterController.of(context).groupDrawables();

      // Add the drawable to the controller's drawables
      PainterController.of(context).addDrawables([drawable], newAction: false);
    } else {
      return;
    }
    // Set the drawable as the current drawable
    this.drawable[pointer] = drawable;
  }

  Offset _translateLocation(Size currentSize, Offset location) {
    if (widget.scale != null) {
      final originSize = widget.scale!;
      if (originSize != currentSize) {
        final xScale = originSize.width / currentSize.width;
        final yScale = originSize.height / currentSize.height;
        return location.scale(xScale, yScale);
      }
    }
    return location;
  }

  /// Callback when the user moves, rotates or scales the pointer(s).
  void _handleHorizontalDragUpdate(int pointer, Offset globalPosition,
      {bool isNew = false}) {
    final currentSize =
        (freeStyleParentKey.currentContext?.findRenderObject() as RenderBox?)
            ?.size;
    if (currentSize == null) return;
    if (MouseTesting) {
      final location =
          _translateLocation(currentSize, _globalToLocal(globalPosition));
      onHandEraserCalling(HandEraserEvent(
          pointer,
          Point(location.dx, location.dy),
          const Size(100, 100),
          "WM_POINTERUPDATE"));
      return;
    } else {
      if (eraserDrawable.isNotEmpty) return;
    }
    final drawable = this.drawable[pointer];
    // If there is no current drawable, ignore user input
    if (drawable == null) return;
    final location =
        _translateLocation(currentSize, _globalToLocal(globalPosition));
    setFreeHand(false, location);
    if (this.drawable[pointer] is CubicPathDrawable) {
      (this.drawable[pointer] as CubicPathDrawable).alterPath(location);
      // print("更新手写 alterPath");
      // Replace the current drawable with the copy with the added point
      PainterController.of(context).notifyListeners();
      DrawableCreatedNotification(this.drawable[pointer]).dispatch(context);
      return;
    }
    // Add the new point to a copy of the current drawable
    final newDrawable = drawable.copyWith(
      path: List<Offset>.from(drawable.path)
        // path: List<Offset>.from(isNew?[]:drawable.path)
        ..add(location),
    );
    // Replace the current drawable with the copy with the added point
    PainterController.of(context)
        .replaceDrawable(drawable, newDrawable, newAction: false);
    // Update the current drawable to be the new copy
    this.drawable[pointer] = newDrawable;
  }

  /// Callback when the user removes all pointers from the widget.
  void _handleHorizontalDragUp(int pointer) {
    final currentSize =
        (freeStyleParentKey.currentContext?.findRenderObject() as RenderBox?)
            ?.size;
    if (currentSize == null) return;
    if (MouseTesting) {
      final location = _translateLocation(currentSize,
          _globalToLocal(eraserDrawable.values.last.centerLocation));
      onHandEraserCalling(HandEraserEvent(
          pointer,
          Point(location.dx, location.dy),
          const Size(100, 100),
          "WM_POINTERLEAVE"));
      return;
    } else {
      if (eraserDrawable.isNotEmpty) return;
    }
    if (this.drawable[pointer] is CubicPathDrawable) {
      (this.drawable[pointer] as CubicPathDrawable).closePath();
      PainterController.of(context).notifyListeners();
      DrawableCreatedNotification(drawable[pointer]).dispatch(context);
      // print("结束手写 closePath");
    } else {
      DrawableCreatedNotification(drawable[pointer]).dispatch(context);
    }

    /// Reset the current drawable for the user to draw a new one next time
    drawable.remove(pointer);
    setFreeHand(true, null);
  }

  Offset _globalToLocal(Offset globalPosition) {
    final getBox = context.findRenderObject() as RenderBox;

    return getBox.globalToLocal(globalPosition);
  }

  void setFreeHand(bool freeHand, Offset? location) {
    this.freeHand = freeHand;
  }
}

/// A custom recognizer that recognize at most only one gesture sequence.
class _DragGestureDetector extends OneSequenceGestureRecognizer {
  _DragGestureDetector({
    required this.onHorizontalDragDown,
    required this.onHorizontalDragUpdate,
    required this.onHorizontalDragUp,
  });

  final ValueSetter<Offset> onHorizontalDragDown;
  final ValueSetter<Offset> onHorizontalDragUpdate;
  final VoidCallback onHorizontalDragUp;

  bool _isTrackingGesture = false;

  @override
  void addPointer(PointerEvent event) {
    if (!_isTrackingGesture) {
      resolve(GestureDisposition.accepted);
      startTrackingPointer(event.pointer);
      _isTrackingGesture = true;
    } else {
      stopTrackingPointer(event.pointer);
    }
  }

  @override
  void handleEvent(PointerEvent event) {
    if (event is PointerDownEvent) {
      onHorizontalDragDown(event.position);
    } else if (event is PointerMoveEvent) {
      onHorizontalDragUpdate(event.position);
    } else if (event is PointerUpEvent) {
      onHorizontalDragUp();
      stopTrackingPointer(event.pointer);
      _isTrackingGesture = false;
    }
  }

  @override
  String get debugDescription => '_DragGestureDetector';

  @override
  void didStopTrackingLastPointer(int pointer) {}
}

/// A custom recognizer that recognize at most only one gesture sequence.
///
///

class _EmptyDrag extends Drag {
  @override
  void update(DragUpdateDetails details) {}

  @override
  void cancel() {}

  @override
  void end(DragEndDetails details) {}
}

class _MultiDragGestureDetector
    extends multi.ImmediateMultiDragGestureRecognizer {
  _MultiDragGestureDetector({
    required this.onHorizontalDragDown,
    required this.onHorizontalDragUpdate,
    required this.onHorizontalDragUp,
    required BuildContext context,
    required bool Function() onMultiDragEnableCheck,
  }) : super(onMultiDragEnableCheck: onMultiDragEnableCheck, context: context) {
    onStart = (Offset position) {
      return _EmptyDrag();
    };
  }

  final TypedValueSetter<int, Offset> onHorizontalDragDown;
  final TypedValueSetter<int, Offset> onHorizontalDragUpdate;
  final ValueSetter<int> onHorizontalDragUp;

  @override
  multi.MultiDragPointerState createNewPointerState(PointerDownEvent event) {
    return _ImmediatePointerState(event.position, event.kind, gestureSettings,
        onHorizontalDragDown, onHorizontalDragUpdate, onHorizontalDragUp);
  }
}

class _ImmediatePointerState extends multi.MultiDragPointerState {
  _ImmediatePointerState(
      Offset initialPosition,
      PointerDeviceKind kind,
      DeviceGestureSettings? deviceGestureSettings,
      this.onHorizontalDragDown,
      this.onHorizontalDragUpdate,
      this.onHorizontalDragUp)
      : super(initialPosition, kind, deviceGestureSettings);

  final TypedValueSetter<int, Offset> onHorizontalDragDown;
  final TypedValueSetter<int, Offset> onHorizontalDragUpdate;
  final ValueSetter<int> onHorizontalDragUp;

  @override
  void checkForResolutionAfterMove() {
    assert(pendingDelta != null);
    if (pendingDelta!.distance>10||pendingDelta!.distance > computeHitSlop(kind, gestureSettings)) {
      resolve(GestureDisposition.accepted);
    } else {}
  }

  @override
  void accepted(GestureMultiDragStartCallback starter) {
    starter(initialPosition);
  }

  @override
  void onPointerStart(int pointer, DragDownDetails details) {
    super.onPointerStart(pointer, details);
    onHorizontalDragDown.call(pointer, details.globalPosition);
  }

  @override
  void onPointerCancel(int pointer) {
    super.onPointerCancel(pointer);
    onHorizontalDragUp.call(pointer);
  }

  @override
  void onPointerEnd(int pointer, DragEndDetails details) {
    super.onPointerEnd(pointer, details);
    onHorizontalDragUp.call(pointer);
  }

  @override
  void onPointerUpdate(int pointer, DragUpdateDetails details) {
    super.onPointerUpdate(pointer, details);
    onHorizontalDragUpdate.call(pointer, details.globalPosition);
  }
}

typedef TypedValueSetter<int, T> = void Function(int type, T value);

// class _MultiDragGestureDetector extends _MultiDragGestureRecognizer {
//   _MultiDragGestureDetector({
//     required this.onHorizontalDragDown,
//     required this.onHorizontalDragUpdate,
//     required this.onHorizontalDragUp,
//     Object? debugOwner,
//     Set<PointerDeviceKind>? supportedDevices,
//   }): super(
//     debugOwner: debugOwner,
//     supportedDevices: supportedDevices,
//   );
//
//   final TypedValueSetter<int,Offset> onHorizontalDragDown;
//   final TypedValueSetter<int,Offset> onHorizontalDragUpdate;
//   final VoidCallback onHorizontalDragUp;
//
//   // bool _isTrackingGesture = false;
//
//   @override
//   _MultiDragPointerState createNewPointerState(PointerDownEvent event) {
//     return _ImmediatePointerState(event.position, event.kind, gestureSettings);
//   }
//
//   ///begin
//   @override
//   void addAllowedPointer(PointerDownEvent event) {
//     assert(_pointers != null);
//     assert(event.pointer != null);
//     assert(event.position != null);
//     assert(!_pointers!.containsKey(event.pointer));
//     final _MultiDragPointerState state = createNewPointerState(event);
//     _pointers![event.pointer] = state;
//     GestureBinding.instance.pointerRouter.addRoute(event.pointer, _handleEvent);
//     state._setArenaEntry(GestureBinding.instance.gestureArena.add(event.pointer, this));
//   }
//
//   void _handleEvent(PointerEvent event) {
//     assert(_pointers != null);
//     assert(event.pointer != null);
//     assert(event.timeStamp != null);
//     assert(event.position != null);
//     assert(_pointers!.containsKey(event.pointer));
//     final _MultiDragPointerState state = _pointers![event.pointer]!;
//     if (event is PointerMoveEvent) {
//       onHorizontalDragUpdate(event.pointer,event.position);
//       state._move(event);
//       // We might be disposed here.
//     } else if (event is PointerUpEvent) {
//       assert(event.delta == Offset.zero);
//       onHorizontalDragUp();
//       state._up();
//       // We might be disposed here.
//       _removeState(event.pointer);
//     } else if (event is PointerCancelEvent) {
//       assert(event.delta == Offset.zero);
//       onHorizontalDragUp();
//       state._cancel();
//       // We might be disposed here.
//       _removeState(event.pointer);
//     } else if (event is! PointerDownEvent) {
//       // we get the PointerDownEvent that resulted in our addPointer getting called since we
//       // add ourselves to the pointer router then (before the pointer router has heard of
//       // the event).
//       assert(false);
//       onHorizontalDragDown(event.pointer,event.position);
//     }
//   }
//
//   @override
//   String get debugDescription => '_DragGestureDetector';
//
//   @override
//   void didStopTrackingLastPointer(int pointer) {}
// }

//
// abstract class _MultiDragGestureRecognizer extends GestureRecognizer {
//   /// Initialize the object.
//   ///
//   /// {@macro flutter.gestures.GestureRecognizer.supportedDevices}
//   _MultiDragGestureRecognizer({
//     required Object? debugOwner,
//     @Deprecated(
//       'Migrate to supportedDevices. '
//           'This feature was deprecated after v2.3.0-1.0.pre.',
//     )
//     PointerDeviceKind? kind,
//     Set<PointerDeviceKind>? supportedDevices,
//   }) : super(
//     debugOwner: debugOwner,
//     kind: kind,
//     supportedDevices: supportedDevices,
//   );
//
//   /// Called when this class recognizes the start of a drag gesture.
//   ///
//   /// The remaining notifications for this drag gesture are delivered to the
//   /// [Drag] object returned by this callback.
//   GestureMultiDragStartCallback? onStart;
//
//   Map<int, _MultiDragPointerState>? _pointers = <int, _MultiDragPointerState>{};
//
//   @override
//   void addAllowedPointer(PointerDownEvent event) {
//     assert(_pointers != null);
//     assert(event.pointer != null);
//     assert(event.position != null);
//     assert(!_pointers!.containsKey(event.pointer));
//     final _MultiDragPointerState state = createNewPointerState(event);
//     _pointers![event.pointer] = state;
//     GestureBinding.instance.pointerRouter.addRoute(event.pointer, _handleEvent);
//     state._setArenaEntry(GestureBinding.instance.gestureArena.add(event.pointer, this));
//   }
//
//   /// Subclasses should override this method to create per-pointer state
//   /// objects to track the pointer associated with the given event.
//   @protected
//   @factory
//   _MultiDragPointerState createNewPointerState(PointerDownEvent event);
//
//   void _handleEvent(PointerEvent event) {
//     assert(_pointers != null);
//     assert(event.pointer != null);
//     assert(event.timeStamp != null);
//     assert(event.position != null);
//     assert(_pointers!.containsKey(event.pointer));
//     final _MultiDragPointerState state = _pointers![event.pointer]!;
//     if (event is PointerMoveEvent) {
//       state._move(event);
//       // We might be disposed here.
//     } else if (event is PointerUpEvent) {
//       assert(event.delta == Offset.zero);
//       state._up();
//       // We might be disposed here.
//       _removeState(event.pointer);
//     } else if (event is PointerCancelEvent) {
//       assert(event.delta == Offset.zero);
//       state._cancel();
//       // We might be disposed here.
//       _removeState(event.pointer);
//     } else if (event is! PointerDownEvent) {
//       // we get the PointerDownEvent that resulted in our addPointer getting called since we
//       // add ourselves to the pointer router then (before the pointer router has heard of
//       // the event).
//       assert(false);
//     }
//   }
//
//   @override
//   void acceptGesture(int pointer) {
//     assert(_pointers != null);
//     final _MultiDragPointerState? state = _pointers![pointer];
//     if (state == null)
//       return; // We might already have canceled this drag if the up comes before the accept.
//     state.accepted((Offset initialPosition) => _startDrag(initialPosition, pointer));
//   }
//
//   Drag? _startDrag(Offset initialPosition, int pointer) {
//     assert(_pointers != null);
//     final _MultiDragPointerState state = _pointers![pointer]!;
//     assert(state != null);
//     assert(state._pendingDelta != null);
//     Drag? drag;
//     if (onStart != null)
//       drag = invokeCallback<Drag?>('onStart', () => onStart!(initialPosition));
//     if (drag != null) {
//       state._startDrag(drag);
//     } else {
//       _removeState(pointer);
//     }
//     return drag;
//   }
//
//   @override
//   void rejectGesture(int pointer) {
//     assert(_pointers != null);
//     if (_pointers!.containsKey(pointer)) {
//       final _MultiDragPointerState state = _pointers![pointer]!;
//       assert(state != null);
//       state.rejected();
//       _removeState(pointer);
//     } // else we already preemptively forgot about it (e.g. we got an up event)
//   }
//
//   void _removeState(int pointer) {
//     if (_pointers == null) {
//       // We've already been disposed. It's harmless to skip removing the state
//       // for the given pointer because dispose() has already removed it.
//       return;
//     }
//     assert(_pointers!.containsKey(pointer));
//     GestureBinding.instance.pointerRouter.removeRoute(pointer, _handleEvent);
//     _pointers!.remove(pointer)!.dispose();
//   }
//
//   @override
//   void dispose() {
//     _pointers!.keys.toList().forEach(_removeState);
//     assert(_pointers!.isEmpty);
//     _pointers = null;
//     super.dispose();
//   }
// }
//
//
// /// Per-pointer state for a [MultiDragGestureRecognizer].
// ///
// /// A [MultiDragGestureRecognizer] tracks each pointer separately. The state for
// /// each pointer is a subclass of [_MultiDragPointerState].
// abstract class _MultiDragPointerState {
//   /// Creates per-pointer state for a [MultiDragGestureRecognizer].
//   ///
//   /// The [initialPosition] argument must not be null.
//   _MultiDragPointerState(this.initialPosition, this.kind, this.gestureSettings)
//       : assert(initialPosition != null),
//         _velocityTracker = VelocityTracker.withKind(kind);
//
//   /// Device specific gesture configuration that should be preferred over
//   /// framework constants.
//   ///
//   /// These settings are commonly retrieved from a [MediaQuery].
//   final DeviceGestureSettings? gestureSettings;
//
//   /// The global coordinates of the pointer when the pointer contacted the screen.
//   final Offset initialPosition;
//
//   final VelocityTracker _velocityTracker;
//
//   /// The kind of pointer performing the multi-drag gesture.
//   ///
//   /// Used by subclasses to determine the appropriate hit slop, for example.
//   final PointerDeviceKind kind;
//
//   Drag? _client;
//
//   /// The offset of the pointer from the last position that was reported to the client.
//   ///
//   /// After the pointer contacts the screen, the pointer might move some
//   /// distance before this movement will be recognized as a drag. This field
//   /// accumulates that movement so that we can report it to the client after
//   /// the drag starts.
//   Offset? get pendingDelta => _pendingDelta;
//   Offset? _pendingDelta = Offset.zero;
//
//   Duration? _lastPendingEventTimestamp;
//
//   GestureArenaEntry? _arenaEntry;
//   void _setArenaEntry(GestureArenaEntry entry) {
//     assert(_arenaEntry == null);
//     assert(pendingDelta != null);
//     assert(_client == null);
//     _arenaEntry = entry;
//   }
//
//   /// Resolve this pointer's entry in the [GestureArenaManager] with the given disposition.
//   @protected
//   @mustCallSuper
//   void resolve(GestureDisposition disposition) {
//     _arenaEntry!.resolve(disposition);
//   }
//
//   void _move(PointerMoveEvent event) {
//     assert(_arenaEntry != null);
//     if (!event.synthesized)
//       _velocityTracker.addPosition(event.timeStamp, event.position);
//     if (_client != null) {
//       assert(pendingDelta == null);
//       // Call client last to avoid reentrancy.
//       _client!.update(DragUpdateDetails(
//         sourceTimeStamp: event.timeStamp,
//         delta: event.delta,
//         globalPosition: event.position,
//       ));
//     } else {
//       assert(pendingDelta != null);
//       _pendingDelta = _pendingDelta! + event.delta;
//       _lastPendingEventTimestamp = event.timeStamp;
//       checkForResolutionAfterMove();
//     }
//   }
//
//   /// Override this to call resolve() if the drag should be accepted or rejected.
//   /// This is called when a pointer movement is received, but only if the gesture
//   /// has not yet been resolved.
//   @protected
//   void checkForResolutionAfterMove() { }
//
//   /// Called when the gesture was accepted.
//   ///
//   /// Either immediately or at some future point before the gesture is disposed,
//   /// call starter(), passing it initialPosition, to start the drag.
//   @protected
//   void accepted(GestureMultiDragStartCallback starter);
//
//   /// Called when the gesture was rejected.
//   ///
//   /// The [dispose] method will be called immediately following this.
//   @protected
//   @mustCallSuper
//   void rejected() {
//     assert(_arenaEntry != null);
//     assert(_client == null);
//     assert(pendingDelta != null);
//     _pendingDelta = null;
//     _lastPendingEventTimestamp = null;
//     _arenaEntry = null;
//   }
//
//   void _startDrag(Drag client) {
//     assert(_arenaEntry != null);
//     assert(_client == null);
//     assert(client != null);
//     assert(pendingDelta != null);
//     _client = client;
//     final DragUpdateDetails details = DragUpdateDetails(
//       sourceTimeStamp: _lastPendingEventTimestamp,
//       delta: pendingDelta!,
//       globalPosition: initialPosition,
//     );
//     _pendingDelta = null;
//     _lastPendingEventTimestamp = null;
//     // Call client last to avoid reentrancy.
//     _client!.update(details);
//   }
//
//   void _up() {
//     assert(_arenaEntry != null);
//     if (_client != null) {
//       assert(pendingDelta == null);
//       final DragEndDetails details = DragEndDetails(velocity: _velocityTracker.getVelocity());
//       final Drag client = _client!;
//       _client = null;
//       // Call client last to avoid reentrancy.
//       client.end(details);
//     } else {
//       assert(pendingDelta != null);
//       _pendingDelta = null;
//       _lastPendingEventTimestamp = null;
//     }
//   }
//
//   void _cancel() {
//     assert(_arenaEntry != null);
//     if (_client != null) {
//       assert(pendingDelta == null);
//       final Drag client = _client!;
//       _client = null;
//       // Call client last to avoid reentrancy.
//       client.cancel();
//     } else {
//       assert(pendingDelta != null);
//       _pendingDelta = null;
//       _lastPendingEventTimestamp = null;
//     }
//   }
//
//   /// Releases any resources used by the object.
//   @protected
//   @mustCallSuper
//   void dispose() {
//     _arenaEntry?.resolve(GestureDisposition.rejected);
//     _arenaEntry = null;
//     assert(() {
//       _pendingDelta = null;
//       return true;
//     }());
//   }
// }
//
// class _ImmediatePointerState extends _MultiDragPointerState {
//   _ImmediatePointerState(Offset initialPosition, PointerDeviceKind kind, DeviceGestureSettings? deviceGestureSettings) : super(initialPosition, kind, deviceGestureSettings);
//
//   @override
//   void checkForResolutionAfterMove() {
//     assert(pendingDelta != null);
//     if (pendingDelta!.distance > computeHitSlop(kind, gestureSettings))
//       resolve(GestureDisposition.accepted);
//   }
//
//   @override
//   void accepted(GestureMultiDragStartCallback starter) {
//     starter(initialPosition);
//   }
//
//
// }
