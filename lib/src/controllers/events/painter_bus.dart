/// This is an example of how to set up the [EventBus] and its events.
import 'dart:math';

import 'package:event_bus/event_bus.dart';
import 'package:flutter/cupertino.dart';

/// The global [EventBus] object.
 final EventBus eventBus = EventBus();


class LogEvent{
  String message;
  LogEvent(this.message);
  @override
  String toString() {
    return 'LogEvent{message: $message}';
  }
}

/// Event A.
class HandEraserEvent {
  int pointerId;
  Point point;
  Size size;
  String event;

  HandEraserEvent(this.pointerId, this.point, this.size, this.event);

  @override
  String toString() {
    return 'HandEraserEvent{pointerId: $pointerId, point: $point, size: $size, event: $event}';
  }
}

enum VolumeOperation { ADD, REMOVE,CHANGE }

class VolumeEvent {
  VolumeOperation operation;
  String volumeName;
  String fileSystem;
  String location;
  bool otg;
  int? deviceId;

  VolumeEvent(this.operation,{required this.volumeName,required this.location,required this.fileSystem,this.otg=false,this.deviceId});

  @override
  String toString() {
    return 'VolumeEvent{operation: $operation, volumeName: $volumeName, fileSystem: $fileSystem, location: $location, otg: $otg, deviceId: $deviceId}';
  }
}
