// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.


import 'dart:async';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:oktoast/oktoast.dart';

//WM_PARENTNOTIFY 528
//WM_POINTERDOWN 582
//WM_LBUTTONDOWN 513
//WM_NCCALCSIZE 131
//WM_NCHITTEST 132
//WM_POINTERACTIVATE 587
// WM_TOUCH  587
// WM_POINTERUPDATE  581
// WM_GESTURE 281

//WM_MOUSEACTIVATE 33

/// Signature for when [MultiDragGestureRecognizer] recognizes the start of a drag gesture.
typedef GestureMultiDragStartCallback = Drag? Function(Offset position);

/// Per-pointer state for a [MultiDragGestureRecognizer].
///
/// A [MultiDragGestureRecognizer] tracks each pointer separately. The state for
/// each pointer is a subclass of [MultiDragPointerState].
abstract class MultiDragPointerState {
  /// Creates per-pointer state for a [MultiDragGestureRecognizer].
  ///
  /// The [initialPosition] argument must not be null.
  MultiDragPointerState(this.initialPosition, this.kind, this.gestureSettings)
    : assert(initialPosition != null),
      _velocityTracker = VelocityTracker.withKind(kind);

  /// Device specific gesture configuration that should be preferred over
  /// framework constants.
  ///
  /// These settings are commonly retrieved from a [MediaQuery].
  final DeviceGestureSettings? gestureSettings;

  /// The global coordinates of the pointer when the pointer contacted the screen.
  final Offset initialPosition;

  final VelocityTracker _velocityTracker;

  /// The kind of pointer performing the multi-drag gesture.
  ///
  /// Used by subclasses to determine the appropriate hit slop, for example.
  final PointerDeviceKind kind;

  Drag? _client;

  /// The offset of the pointer from the last position that was reported to the client.
  ///
  /// After the pointer contacts the screen, the pointer might move some
  /// distance before this movement will be recognized as a drag. This field
  /// accumulates that movement so that we can report it to the client after
  /// the drag starts.
  Offset? get pendingDelta => _pendingDelta;
  Offset? _pendingDelta = Offset.zero;

  Duration? _lastPendingEventTimestamp;

  GestureArenaEntry? _arenaEntry;
  int? _arenaEntryPointer;
  void _setArenaEntry(GestureArenaEntry entry,int pointer) {
    assert(_arenaEntry == null);
    assert(pendingDelta != null);
    assert(_client == null);
    _arenaEntry = entry;
    _arenaEntryPointer = pointer;
  }

  /// Resolve this pointer's entry in the [GestureArenaManager] with the given disposition.
  @protected
  @mustCallSuper
  void resolve(GestureDisposition disposition) {
    _arenaEntry?.resolve(disposition);
  }

  void _move(PointerMoveEvent event) {
    assert(_arenaEntry != null);
    if (!event.synthesized) {
      _velocityTracker.addPosition(event.timeStamp, event.position);
    }
    if (_client != null) {
      assert(pendingDelta == null);
      // Call client last to avoid reentrancy.
      final detail = DragUpdateDetails(
        sourceTimeStamp: event.timeStamp,
        delta: event.delta,
        globalPosition: event.position,
      );
      _client!.update(detail);
      onPointerUpdate(event.pointer,detail);
    } else {
      assert(pendingDelta != null);
      _pendingDelta = _pendingDelta! + event.delta;
      _lastPendingEventTimestamp = event.timeStamp;

      checkForResolutionAfterMove();
    }
  }

  /// Override this to call resolve() if the drag should be accepted or rejected.
  /// This is called when a pointer movement is received, but only if the gesture
  /// has not yet been resolved.
  @protected
  void checkForResolutionAfterMove() { }

  /// Called when the gesture was accepted.
  ///
  /// Either immediately or at some future point before the gesture is disposed,
  /// call starter(), passing it initialPosition, to start the drag.
  @protected
  void accepted(GestureMultiDragStartCallback starter);

  /// Called when the gesture was rejected.
  ///
  /// The [dispose] method will be called immediately following this.
  @protected
  @mustCallSuper
  void rejected() {
    assert(_arenaEntry != null);
    assert(_client == null);
    assert(pendingDelta != null);
    _pendingDelta = null;
    _lastPendingEventTimestamp = null;
    _arenaEntry = null;
    _arenaEntryPointer = null;
  }

  void _startDrag(Drag client) {
    assert(_arenaEntry != null);
    assert(_arenaEntryPointer != null);
    assert(_client == null);
    assert(client != null);
    assert(pendingDelta != null);

    _client = client;
    final DragUpdateDetails details = DragUpdateDetails(
      sourceTimeStamp: _lastPendingEventTimestamp,
      delta: pendingDelta!,
      globalPosition: initialPosition,
    );
    _pendingDelta = null;
    _lastPendingEventTimestamp = null;
    // Call client last to avoid reentrancy.
    _client!.update(details);
    // onPointerStart(_arenaEntryPointer!,details);
  }

  void _up() {
    assert(_arenaEntry != null);
    assert(_arenaEntryPointer != null);
    if (_client != null) {
      assert(pendingDelta == null);
      final DragEndDetails details = DragEndDetails(velocity: _velocityTracker.getVelocity());
      final Drag client = _client!;
      _client = null;
      // Call client last to avoid reentrancy.
      client.end(details);
      onPointerEnd(_arenaEntryPointer!,details);
    } else {
      assert(pendingDelta != null);
      final DragEndDetails details = DragEndDetails(velocity: _velocityTracker.getVelocity());
      onPointerEnd(_arenaEntryPointer!,details);

      _pendingDelta = null;
      _lastPendingEventTimestamp = null;
    }
  }

  void _cancel() {
    assert(_arenaEntry != null);
    assert(_arenaEntryPointer != null);
    if (_client != null) {
      assert(pendingDelta == null);
      final Drag client = _client!;
      _client = null;
      // Call client last to avoid reentrancy.
      client.cancel();
      onPointerCancel(_arenaEntryPointer!);
    } else {
      assert(pendingDelta != null);
      _pendingDelta = null;
      _lastPendingEventTimestamp = null;
    }
  }

  /// Releases any resources used by the object.
  @protected
  @mustCallSuper
  void dispose() {
    _arenaEntry?.resolve(GestureDisposition.rejected);
    _arenaEntry = null;
    _arenaEntryPointer = null;
    assert(() {
      _pendingDelta = null;
      return true;
    }());
  }

  @protected
  @mustCallSuper
  void onPointerUpdate(int pointer,DragUpdateDetails details) {}

  @protected
  @mustCallSuper
  void onPointerEnd(int pointer, DragEndDetails details) {}

  @protected
  @mustCallSuper
  void onPointerCancel(int pointer) {}

  @protected
  @mustCallSuper
  void onPointerStart(int pointer, DragDownDetails details) {}
}

/// Recognizes movement on a per-pointer basis.
///
/// In contrast to [DragGestureRecognizer], [MultiDragGestureRecognizer] watches
/// each pointer separately, which means multiple drags can be recognized
/// concurrently if multiple pointers are in contact with the screen.
///
/// [MultiDragGestureRecognizer] is not intended to be used directly. Instead,
/// consider using one of its subclasses to recognize specific types for drag
/// gestures.
///
/// See also:
///
///  * [ImmediateMultiDragGestureRecognizer], the most straight-forward variant
///    of multi-pointer drag gesture recognizer.
///  * [HorizontalMultiDragGestureRecognizer], which only recognizes drags that
///    start horizontally.
///  * [VerticalMultiDragGestureRecognizer], which only recognizes drags that
///    start vertically.
///  * [DelayedMultiDragGestureRecognizer], which only recognizes drags that
///    start after a long-press gesture.
abstract class MultiDragGestureRecognizer extends GestureRecognizer {
  /// Initialize the object.
  // final Size screenSize,
  /// {@macro flutter.gestures.GestureRecognizer.supportedDevices}
  MultiDragGestureRecognizer({
    required Object? debugOwner,
    @Deprecated(
      'Migrate to supportedDevices. '
      'This feature was deprecated after v2.3.0-1.0.pre.',
    )
    PointerDeviceKind? kind,
    Set<PointerDeviceKind>? supportedDevices,
    this.onMultiDragEnableCheck,
    required this.context,
  }) : super(
         debugOwner: debugOwner,
         kind: kind,
         supportedDevices: supportedDevices,
       );

  /// Called when this class recognizes the start of a drag gesture.
  ///
  /// The remaining notifications for this drag gesture are delivered to the
  /// [Drag] object returned by this callback.
  GestureMultiDragStartCallback? onStart;
  bool Function()? onMultiDragEnableCheck;

  final BuildContext context;

  Map<int, MultiDragPointerState>? _pointers = <int, MultiDragPointerState>{};

  @override
  void addAllowedPointer(PointerDownEvent event) {
    assert(_pointers != null);
    assert(event.pointer != null);
    assert(event.position != null);
    assert(!_pointers!.containsKey(event.pointer));
    final multiDragEnable = onMultiDragEnableCheck?.call() ?? true ;
    if(multiDragEnable){
      final MultiDragPointerState state = createNewPointerState(event);
      _pointers![event.pointer] = state;
      final gestureArena= GestureBinding.instance.gestureArena.add(event.pointer, this);
      GestureBinding.instance.pointerRouter.addRoute(event.pointer, _handleEvent);
      state._setArenaEntry(gestureArena,event.pointer);
    }else{
      if(_pointers!.isEmpty){
        final MultiDragPointerState state = createNewPointerState(event);
        _pointers![event.pointer] = state;
        final gestureArena= GestureBinding.instance.gestureArena.add(event.pointer, this);
        GestureBinding.instance.pointerRouter.addRoute(event.pointer, _handleEvent);
        state._setArenaEntry(gestureArena,event.pointer);
      }
    }
  }

  /// Subclasses should override this method to create per-pointer state
  /// objects to track the pointer associated with the given event.
  @protected
  @factory
  MultiDragPointerState createNewPointerState(PointerDownEvent event);

  void _handleEvent(PointerEvent event) {
    assert(_pointers != null);
    assert(event.pointer != null);
    assert(event.timeStamp != null);
    assert(event.position != null);
    assert(_pointers!.containsKey(event.pointer));
    final MultiDragPointerState state = _pointers![event.pointer]!;

    /*if(Platform.isAndroid){
      // showToast("""
      // 按压的点 ::
      // 指针事件的输入设备类型 kind:${event.kind},
      // 按压力度pressure:${event.pressure},
      // 表面的距离distance:${event.distance},
      // 屏幕区域大小size:${event.size},
      // 沿主轴半径radiusMajor:${event.radiusMajor},
      // 沿短轴的半径radiusMinor:${event.radiusMinor},
      // 平台特定数据platformData:${event.platformData},
      // 原始数据original:${event.original?.toDiagnosticsNode()??"" },
      // """.trim(),duration: const Duration(seconds: 10));
      final size = event.size;
      final touchMajor= event.radiusMajor;
      final touchMinor= event.radiusMinor;
      final x = event.position.dx;
      final y = event.position.dy;
      final screenSize = MediaQuery.of(context).size;
      final screenHeight = screenSize.height;
      final screenWidth = screenSize.width;
      final touchDimension = (screenHeight*screenWidth)*size;
      if(touchDimension>30*30|| event is PointerUpEvent){

        return;
      }
    }*/

    if (event is PointerMoveEvent) {
      state._move(event);
      // We might be disposed here.
    }
    else if (event is PointerUpEvent) {
      assert(event.delta == Offset.zero);
      state._up();
      // We might be disposed here.
      _removeState(event.pointer);
    }
    else if (event is PointerCancelEvent) {
      assert(event.delta == Offset.zero);
      state._cancel();
      // We might be disposed here.
      _removeState(event.pointer);
    } else if (event is! PointerDownEvent) {
      // we get the PointerDownEvent that resulted in our addPointer getting called since we
      // add ourselves to the pointer router then (before the pointer router has heard of
      // the event).
      assert(false);
    }
    else {
      final DragDownDetails details = DragDownDetails(
        globalPosition: event.position,
      );
      state.onPointerStart(event.pointer, details);
    }
  }

  @override
  void acceptGesture(int pointer) {
    assert(_pointers != null);
    final multiDragEnable = onMultiDragEnableCheck?.call() ?? true ;
    if(multiDragEnable){
      final MultiDragPointerState? state = _pointers![pointer];
      if (state == null) {
        return;
      } // We might already have canceled this drag if the up comes before the accept.

      state.accepted((Offset initialPosition) => _startDrag(initialPosition, pointer));
    }else if(_pointers!.isEmpty){
      final MultiDragPointerState? state = _pointers![pointer];
      if (state == null) {
        return;
      } // We might already have canceled this drag if the up comes before the accept.
      state.accepted((Offset initialPosition) => _startDrag(initialPosition, pointer));
    }
  }

  Drag? _startDrag(Offset initialPosition, int pointer) {
    assert(_pointers != null);
    final MultiDragPointerState state = _pointers![pointer]!;
    assert(state != null);
    assert(state._pendingDelta != null);
    Drag? drag;
    if (onStart != null) {
      drag = invokeCallback<Drag?>('onStart', () => onStart!(initialPosition));
    }
    if (drag != null) {
      state._startDrag(drag);
    } else {
      _removeState(pointer);
    }
    return drag;
  }

  @override
  void rejectGesture(int pointer) {
    assert(_pointers != null);
    if (_pointers!.containsKey(pointer)) {
      final MultiDragPointerState state = _pointers![pointer]!;
      assert(state != null);
      state.rejected();
      _removeState(pointer);
    } // else we already preemptively forgot about it (e.g. we got an up event)
  }

  void _removeState(int pointer) {
    if (_pointers == null) {
      // We've already been disposed. It's harmless to skip removing the state
      // for the given pointer because dispose() has already removed it.
      return;
    }
    assert(_pointers!.containsKey(pointer));
    GestureBinding.instance.pointerRouter.removeRoute(pointer, _handleEvent);
    _pointers!.remove(pointer)!.dispose();
  }

  @override
  void dispose() {
    _pointers!.keys.toList().forEach(_removeState);
    assert(_pointers!.isEmpty);
    _pointers = null;
    super.dispose();
  }
}

class _ImmediatePointerState extends MultiDragPointerState {
  _ImmediatePointerState(Offset initialPosition, PointerDeviceKind kind, DeviceGestureSettings? deviceGestureSettings) : super(initialPosition, kind, deviceGestureSettings);

  @override
  void checkForResolutionAfterMove() {
    assert(pendingDelta != null);
    if (pendingDelta!.distance > computeHitSlop(kind, gestureSettings)) {
      resolve(GestureDisposition.accepted);
    }
  }

  @override
  void accepted(GestureMultiDragStartCallback starter) {
    starter(initialPosition);
  }
}

/// Recognizes movement both horizontally and vertically on a per-pointer basis.
///
/// In contrast to [PanGestureRecognizer], [ImmediateMultiDragGestureRecognizer]
/// watches each pointer separately, which means multiple drags can be
/// recognized concurrently if multiple pointers are in contact with the screen.
///
/// See also:
///
///  * [PanGestureRecognizer], which recognizes only one drag gesture at a time,
///    regardless of how many fingers are involved.
///  * [HorizontalMultiDragGestureRecognizer], which only recognizes drags that
///    start horizontally.
///  * [VerticalMultiDragGestureRecognizer], which only recognizes drags that
///    start vertically.
///  * [DelayedMultiDragGestureRecognizer], which only recognizes drags that
///    start after a long-press gesture.
class ImmediateMultiDragGestureRecognizer extends MultiDragGestureRecognizer {
  /// Create a gesture recognizer for tracking multiple pointers at once.
  ///
  /// {@macro flutter.gestures.GestureRecognizer.supportedDevices}
  ImmediateMultiDragGestureRecognizer({
    Object? debugOwner,
    @Deprecated(
      'Migrate to supportedDevices. '
      'This feature was deprecated after v2.3.0-1.0.pre.',
    )
    PointerDeviceKind? kind,
    Set<PointerDeviceKind>? supportedDevices,
    bool Function()? onMultiDragEnableCheck,
    required BuildContext context,
  }) : super(
         debugOwner: debugOwner,
         kind: kind,
         supportedDevices: supportedDevices,
         onMultiDragEnableCheck: onMultiDragEnableCheck,
         context: context
       );

  @override
  MultiDragPointerState createNewPointerState(PointerDownEvent event) {
    return _ImmediatePointerState(event.position, event.kind, gestureSettings);
  }

  @override
  String get debugDescription => 'multidrag';
}

