import 'package:flutter/material.dart';

/// Represents settings used to create and draw free-style drawables.
@immutable
class FreeStyleSettings {
  /// Free-style painting mode.
  final FreeStyleMode mode;

  /// The color the path will be drawn with.
  final Color color;

  /// The stroke width the path will be drawn with.
  final double strokeWidth;
  final double eraseWidth;

  /// Creates a [FreeStyleSettings] with the given [color]
  /// and [strokeWidth] and [mode] values.
  const FreeStyleSettings({
    this.mode = FreeStyleMode.none,
    this.color = Colors.black,
    this.strokeWidth = 15,
    this.eraseWidth = 45,
  });

  /// Creates a copy of this but with the given fields replaced with the new values.
  FreeStyleSettings copyWith(
      {FreeStyleMode? mode, Color? color, double? strokeWidth,double? eraseWidth}) {
    return FreeStyleSettings(
      mode: mode ?? this.mode,
      color: color ?? this.color,
      strokeWidth: strokeWidth ?? this.strokeWidth,
      eraseWidth: eraseWidth ?? this.eraseWidth,
    );
  }
}

/// Enum representing different states that free-style painting can be.
enum FreeStyleMode {
  /// Free-style painting is disabled.
  none,

  /// Free-style painting is enabled in drawing mode; used to draw scribbles.
  draw,

  /// Free-style painting is enabled in erasing mode; used to erase drawings.
  erase,
}
