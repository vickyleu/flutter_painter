import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_painter/flutter_painter_extensions.dart';
import 'package:flutter_painter/flutter_painter_pure.dart';

class HandEraserDrawable extends Drawable {
  final int pointerId;
  Offset centerLocation;
  Size size;
  List<Rect> path;

  bool handLeave = true;

  HandEraserDrawable(
    this.pointerId,
    this.centerLocation,
    this.size, {
    required this.path,
    required this.handLeave,
    bool hidden = false,
  })  :
        // An empty path cannot be drawn, so it is an invalid argument.
        assert(path.isNotEmpty, 'The path cannot be an empty list'),
        super(hidden: hidden);

  Rect toRect() => Rect.fromLTWH(
      centerLocation.dx, centerLocation.dy, size.width, size.height);

  /// Creates a copy of this but with the given fields replaced with the new values.
  @override
  HandEraserDrawable copyWith({
    bool? hidden,
    bool? handLeave,
    Offset? centerLocation,
    Size? size,
    List<Rect>? path,
  }) {
    return HandEraserDrawable(
      pointerId,
      centerLocation ?? this.centerLocation,
      size ?? this.size,
      handLeave: handLeave ?? this.handLeave,
      path: path ?? this.path,
      hidden: hidden ?? this.hidden,
    );
  }

  Paint get paint => Paint()
        ..style = PaintingStyle.fill
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..blendMode = BlendMode.clear
      // ..color = Colors.red
      ;

  //
  // ..style = PaintingStyle.fill
  // ..strokeCap = StrokeCap.round
  // ..strokeJoin = StrokeJoin.round
  // ..color = Colors.red
  // ..blendMode = BlendMode.dst
  // //
  // ;

  @override
  void draw(Canvas canvas, Size size) {
    // Create a UI path to draw
    final path = Path();
    final firstRect = this.path[0];
    //移动到第一个点
    path.moveTo(firstRect.left + firstRect.width / 2,
        firstRect.top + firstRect.height / 2);
    //添加第一个矩形
    path.addRect(firstRect);
    // path.lineTo(this.path[0].left,this.path[0].top);

    fillPath(path, firstRect);
    path.fillType = PathFillType.nonZero;
    path.close();
    // Draw the path on the canvas
    canvas.drawPath(path, paint);

    if (!handLeave) {
      var paint1 = Paint()
        ..color = const Color(0xff995588)
        ..style = PaintingStyle.fill;
      final rrect = RRect.fromRectAndCorners(
          Rect.fromLTWH(
              centerLocation.dx - this.size.width / 2,
              centerLocation.dy - this.size.height / 2,
              this.size.width,
              this.size.height),
          topLeft: const Radius.circular(10),
          topRight: const Radius.circular(10),
          bottomLeft: const Radius.circular(10),
          bottomRight: const Radius.circular(10));
      canvas.drawRRect(rrect, paint1);
    }
  }

  // Draw a line between each point on the free path
  void fillPath(Path path, Rect firstRect) {
    this.path.sublist(1)
      ..forEach((r){
        path.addRect(r);
      });

    return;

    var lastRect = firstRect;
    this.path.sublist(1)
      ..forEach((rect) {
        path.quadraticBezierTo(
            lastRect.left, lastRect.top, rect.left, rect.top);
        lastRect = rect;
      })
      ..apply((list) {
        path.quadraticBezierTo(
            lastRect.left, lastRect.bottom, list.last.left, list.last.bottom);
      })
      ..reversed
      .apply((that) {
        that
          ..forEach((rect) {
            path.quadraticBezierTo(
                lastRect.right, lastRect.bottom, rect.right, rect.bottom);
            lastRect = rect;
          })
          ..apply((list) {
            path.quadraticBezierTo(lastRect.right, lastRect.bottom,
                firstRect.right, firstRect.top);
          });
      });
    path.quadraticBezierTo(firstRect.right, firstRect.top, firstRect.left,
        firstRect.top);
  }
}
