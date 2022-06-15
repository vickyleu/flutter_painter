import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'path_drawable.dart';
import 'dart:typed_data';

/// Free-style Drawable (hand scribble).
class FreeStyleDrawable extends PathDrawable {
  /// The color the path will be drawn with.
  final Color color;

  /// Creates a [FreeStyleDrawable] to draw [path].
  ///
  /// The path will be drawn with the passed [color] and [strokeWidth] if provided.
  FreeStyleDrawable({
    required List<Offset> path,
    double strokeWidth = 1,
    this.color = Colors.black,
    bool hidden = false,
  })  :
        // An empty path cannot be drawn, so it is an invalid argument.
        assert(path.isNotEmpty, 'The path cannot be an empty list'),

        // The line cannot have a non-positive stroke width.
        assert(strokeWidth > 0,
            'The stroke width cannot be less than or equal to 0'),
        super(path: path, strokeWidth: strokeWidth, hidden: hidden);

  /// Creates a copy of this but with the given fields replaced with the new values.
  @override
  FreeStyleDrawable copyWith({
    bool? hidden,
    List<Offset>? path,
    Color? color,
    double? strokeWidth,
  }) {
    return FreeStyleDrawable(
      path: path ?? this.path,
      color: color ?? this.color,
      strokeWidth: strokeWidth ?? this.strokeWidth,
      hidden: hidden ?? this.hidden,
    );
  }

  @protected
  @override
  Paint get paint => Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..color = color
    ..strokeWidth = strokeWidth;

  /// Compares two [FreeStyleDrawable]s for equality.
  // @override
  // bool operator ==(Object other) {
  //   return other is FreeStyleDrawable &&
  //       super == other &&
  //       other.color == color &&
  //       other.strokeWidth == strokeWidth &&
  //       ListEquality().equals(other.path, path);
  // }
  //
  // @override
  // int get hashCode => hashValues(hidden, hashList(path), color, strokeWidth);
}


extension ColorEx on Color {
  String get hexValue => '#${value.toRadixString(16)}'.replaceRange(1, 3, '');
}

extension OffsetEx on Offset {
  Offset axisDistanceTo(Offset other) => other - this;

  double distanceTo(Offset other) {
    final len = axisDistanceTo(other);

    return sqrt(len.dx * len.dx + len.dy * len.dy);
  }

  double angleTo(Offset other) {
    final len = axisDistanceTo(other);

    return atan2(len.dy, len.dx);
  }

  Offset directionTo(Offset other) {
    final len = axisDistanceTo(other);
    final m = sqrt(len.dx * len.dx + len.dy * len.dy);

    return Offset(m == 0 ? 0 : (len.dx / m), m == 0 ? 0 : (len.dy / m));
  }

  Offset rotate(double radians) {
    final s = sin(radians);
    final c = cos(radians);

    final x = dx * c - dy * s;
    final y = dx * s + dy * c;

    return Offset(x, y);
  }

  Offset rotateAround(Offset center, double radians) {
    return (this - center).rotate(radians) + center;
  }
}

extension PathEx on Path {
  void start(Offset offset) => moveTo(offset.dx, offset.dy);

  void cubic(Offset cpStart, Offset cpEnd, Offset end) =>
      cubicTo(cpStart.dx, cpStart.dy, cpEnd.dx, cpEnd.dy, end.dx, end.dy);

  void line(Offset offset) => lineTo(offset.dx, offset.dy);
}

extension SizeExt on Size {
  Size scaleToFit(Size other) {
    final scale = min(
      other.width / this.width,
      other.height / this.height,
    );

    return this * scale;
  }
}
//TODO: clean up
class PathUtil {
  static Rect bounds(List<Offset> data) {
    double left = data[0].dx;
    double top = data[0].dy;
    double right = data[0].dx;
    double bottom = data[0].dy;

    data.forEach((point) {
      final x = point.dx;
      final y = point.dy;

      if (x < left) {
        left = x;
      } else if (x > right) {
        right = x;
      }

      if (y < top) {
        top = y;
      } else if (y > bottom) {
        bottom = y;
      }
    });

    return Rect.fromLTRB(left, top, right, bottom);
  }

  static Rect boundsOf(List<List<Offset>> data) {
    double left = data[0][0].dx;
    double top = data[0][0].dy;
    double right = data[0][0].dx;
    double bottom = data[0][0].dy;

    data.forEach((set) => set.forEach((point) {
      final x = point.dx;
      final y = point.dy;

      if (x < left) {
        left = x;
      } else if (x > right) {
        right = x;
      }

      if (y < top) {
        top = y;
      } else if (y > bottom) {
        bottom = y;
      }
    }));

    return Rect.fromLTRB(left, top, right, bottom);
  }

  static List<T> translate<T extends Offset>(List<T> data, Offset location) {
    final output = <T>[];

    data.forEach(
            (point) => output.add(point.translate(location.dx, location.dy) as T));

    return output;
  }

  static List<List<T>> translateData<T extends Offset>(
      List<List<T>> data, Offset location) {
    final output = <List<T>>[];

    data.forEach((set) => output.add(translate(set, location)));

    return output;
  }

  static List<T> scale<T extends Offset>(List<T> data, double ratio) {
    final output = <T>[];

    data.forEach((point) => output.add(point.scale(ratio, ratio) as T));

    return output;
  }

  static List<List<T>> scaleData<T extends Offset>(
      List<List<T>> data, double ratio) {
    final output = <List<T>>[];

    data.forEach((set) => output.add(scale(set, ratio)));

    return output;
  }

  static List<T> normalize<T extends Offset>(List<T> data,
      {Rect? bound, double? border}) {
    bound ??= bounds(data);
    border ??= 0.0;

    return scale<T>(
      translate<T>(data, -bound.topLeft + Offset(border, border)),
      1.0 / (max(bound.width, bound.height) + border * 2.0),
    );
  }

  static List<List<T>> normalizeData<T extends Offset>(List<List<T>> data,
      {Rect? bound}) {
    bound ??= boundsOf(data);

    final ratio = 1.0 / max(bound.width, bound.height);

    return scaleData<T>(
      translateData<T>(data, -bound.topLeft),
      ratio,
    );
  }

  static List<T> fill<T extends Offset>(List<T> data, Rect rect,
      {Rect? bound, double? border}) {
    bound ??= bounds(data);
    border ??= 32.0;

    final outputSize = rect.size;
    final sourceSize = bound;
    Size destinationSize;

    if (outputSize.width / outputSize.height >
        sourceSize.width / sourceSize.height) {
      destinationSize = Size(
          sourceSize.width * outputSize.height / sourceSize.height,
          outputSize.height);
    } else {
      destinationSize = Size(outputSize.width,
          sourceSize.height * outputSize.width / sourceSize.width);
    }

    destinationSize = Size(destinationSize.width - border * 2.0,
        destinationSize.height - border * 2.0);
    final borderSize = Offset(rect.width - destinationSize.width,
        rect.height - destinationSize.height - border) *
        0.5;

    return translate<T>(
        scale<T>(
          normalize<T>(data, bound: bound),
          max(destinationSize.width, destinationSize.height),
        ),
        borderSize);
  }

  static List<List<T>> fillData<T extends Offset>(List<List<T>> data, Rect rect,
      {Rect? bound, double? border}) {
    bound ??= boundsOf(data);
    border ??= 4.0;

    final outputSize = rect.size;
    final sourceSize = bound;
    Size destinationSize;

    if (outputSize.width / outputSize.height >
        sourceSize.width / sourceSize.height) {
      destinationSize = Size(
          sourceSize.width * outputSize.height / sourceSize.height,
          outputSize.height);
    } else {
      destinationSize = Size(outputSize.width,
          sourceSize.height * outputSize.width / sourceSize.width);
    }

    destinationSize = Size(destinationSize.width - border * 2.0,
        destinationSize.height - border * 2.0);
    final borderSize = Offset(rect.width - destinationSize.width,
        rect.height - destinationSize.height) *
        0.5;

    return translateData<T>(
        scaleData<T>(
          normalizeData<T>(data, bound: bound),
          max(destinationSize.width, destinationSize.height),
        ),
        borderSize);
  }

  static Path toPath(List<Offset> points) {
    final path = Path();

    if (points.length > 0) {
      path.moveTo(points[0].dx, points[0].dy);
      points.forEach((point) => path.lineTo(point.dx, point.dy));
    }

    return path;
  }

  static List<Path> toPaths(List<List<Offset>> data) {
    final paths = <Path>[];

    data.forEach((line) => paths.add(toPath(line)));

    return paths;
  }

  static Rect pathBounds(List<Path> data) {
    Rect init = data[0].getBounds();

    double left = init.left;
    double top = init.top;
    double right = init.right;
    double bottom = init.bottom;

    data.forEach((path) {
      final bound = path.getBounds();

      left = min(left, bound.left);
      top = min(top, bound.top);
      right = max(right, bound.right);
      bottom = max(bottom, bound.bottom);
    });

    return Rect.fromLTRB(left, top, right, bottom);
  }

  static Path scalePath(Path data, double ratio) {
    final transform = Matrix4.identity();
    transform.scale(ratio, ratio);

    return data.transform(transform.storage);
  }

  static List<Path> scalePaths(List<Path> data, double ratio) {
    final output = <Path>[];

    data.forEach((path) => output.add(scalePath(path, ratio)));

    return output;
  }

  static List<Path> translatePaths(List<Path> data, Offset location) {
    final output = <Path>[];

    final transform = Matrix4.identity();
    transform.translate(location.dx, location.dy);

    data.forEach((path) => output.add(path.transform(transform.storage)));

    return output;
  }

  static Path toShapePath(List<CubicLine> lines, double size, double maxSize) {
    assert(lines.length > 0);

    if (lines.length == 1) {
      final line = lines[0];
      if (line.isDot) {
        //TODO: return null or create circle ?
        return Path()
          ..start(line.start)
          ..line(line.end);
      }

      return line.toShape(size, maxSize);
    }

    final path = Path();

    final firstLine = lines.first;
    path.start(firstLine.start + firstLine.cpsUp(size, maxSize));

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final d1 = line.cpsUp(size, maxSize);
      final d2 = line.cpeUp(size, maxSize);

      path.cubic(line.cpStart + d1, line.cpEnd + d2, line.end + d2);
    }

    final lastLine = lines.last;
    path.line(lastLine.end + lastLine.cpeDown(size, maxSize));

    for (int i = lines.length - 1; i > -1; i--) {
      final line = lines[i];
      final d3 = line.cpeDown(size, maxSize);
      final d4 = line.cpsDown(size, maxSize);

      path.cubic(line.cpEnd + d3, line.cpStart + d4, line.start + d4);
    }

    path.close();

    return path;
  }

  static Path toLinePath(List<CubicLine> lines) {
    assert(lines.length > 0);

    final path = Path()..start(lines[0]);

    lines.forEach((line) => path.cubic(line.cpStart, line.cpEnd, line.end));

    return path;
  }
}

class CubicPathDrawable extends PathDrawable with ChangeNotifier {



  /// Returns [PaintingStyle.fill] based paint.
  Paint get fillPaint => Paint()
    ..color = color
    ..strokeWidth = 0.0;

  @override
  void draw(Canvas canvas, Size size){
    var minWidth=0.3;
    var canvasWidth = strokeWidth;
    if(canvasWidth/10.0<0.3){
      minWidth=0.3;
    }else{
      minWidth=canvasWidth/10.0;
    }
    final paint = fillPaint;
    for (var path in paths) {
      if (path.isFilled) {
        if (path.isDot) {
          canvas.drawCircle(path.lines[0],
              path.lines[0].startRadius(minWidth, canvasWidth), paint);
        } else {
          canvas.drawPath(
              PathUtil.toShapePath(path.lines, minWidth, canvasWidth), paint);

          final first = path.lines.first;
          final last = path.lines.last;

          canvas.drawCircle(
              first.start, first.startRadius(minWidth, canvasWidth), paint);
          canvas.drawCircle(
              last.end, last.endRadius(minWidth, canvasWidth), paint);
        }
      }
    }

  }



  /// The color the path will be drawn with.
  final Color color;

  /// List of active paths.
  final _paths = <CubicPath>[];

  /// List of currently completed lines.
  List<CubicPath> get paths => _paths;
  /// Currently unfinished path.
  CubicPath? _activePath;

  /// Checks if is there unfinished path.
  bool get hasActivePath => _activePath != null;

  /// Checks if something is drawn.
  bool get isFilled => _paths.isNotEmpty;

  /// Visual parameters of line painting.
  // SignaturePaintParams? params;

  /// Canvas size.
  Size _areaSize = Size.zero;

  /// Distance between two control points.
  final double threshold;

  /// Smoothing ratio of path.
  final double smoothRatio;

  /// Maximal velocity.
  final double velocityRange;

  CubicPathDrawable({
    required List<Offset> path,
    double strokeWidth = 1,
    this.color = Colors.black,
    bool hidden = false,

    this.threshold: 3.0,
    this.smoothRatio: 0.65,
    this.velocityRange: 2.0,
  })   :
        assert(threshold > 0.0),
        assert(smoothRatio > 0.0),
        assert(velocityRange > 0.0),
  // An empty path cannot be drawn, so it is an invalid argument.
        assert(path.isNotEmpty, 'The path cannot be an empty list'),

  // The line cannot have a non-positive stroke width.
        assert(strokeWidth > 0,
        'The stroke width cannot be less than or equal to 0'),
        super(path: path, strokeWidth: strokeWidth, hidden: hidden);

  @override
  PathDrawable copyWith({bool? hidden, List<Offset>? path, double? strokeWidth}) {
    return CubicPathDrawable(
      path: path ?? this.path,
      color: color ,
      strokeWidth: strokeWidth ?? this.strokeWidth,
      hidden: hidden ?? this.hidden,
    );
  }

  @protected
  @override
  Paint get paint => Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..color = color
    ..strokeWidth = strokeWidth;




  /// Starts new line at given [point].
  void startPath(Offset point) {
    assert(!hasActivePath);

    _activePath = CubicPath(
      threshold: threshold,
      smoothRatio: smoothRatio,
    )..maxVelocity = velocityRange;

    _activePath!.begin(point,
        velocity: _paths.isNotEmpty ? _paths.last._currentVelocity : 0.0);

    _paths.add(_activePath!);
  }

  /// Adds [point[ to active path.
  void alterPath(Offset point) {
    assert(hasActivePath);
    _activePath!.add(point);
    notifyListeners();
  }


  /// Closes active path at given [point].
  void closePath({Offset? point}) {
    assert(hasActivePath);

    if (!_activePath!.end(point: point)) {
      _paths.removeLast();
    }

    _activePath = null;

    notifyListeners();
  }

  /// Removes last line.
  bool stepBack() {
    assert(!hasActivePath);

    if (_paths.isNotEmpty) {
      _paths.removeLast();
      notifyListeners();

      return true;
    }

    return false;
  }

  /// Clears all data.
  void clear() {
    _paths.clear();

    notifyListeners();
  }

  //TODO: Only landscape to landscape mode works correctly now. Add support for orientation switching.
  /// Handles canvas size changes.
  bool notifyDimension(Size size) {
    if (_areaSize == size) {
      return false;
    }

    if (_areaSize.isEmpty ||
        _areaSize.width == size.width ||
        _areaSize.height == size.height) {
      _areaSize = size;
      return false;
    }

    if (hasActivePath) {
      closePath();
    }

    if (!isFilled) {
      _areaSize = size;
      return false;
    }

    //final ratioX = size.width / _areaSize.width;
    final ratioY = size.height / _areaSize.height;
    final scale = ratioY;

    _areaSize = size;

    for (var path in _paths) {
      path.setScale(scale);
    }

    //TODO: Called during rebuild, so notify must be postponed one frame - will be solved by widget/state
    Future.delayed(const Duration(), () => notifyListeners());

    return true;
  }
  @override
  void dispose() {
    _paths.clear();
    _activePath = null;
    super.dispose();
  }
}

/// Extended [Offset] point with [timestamp].
class OffsetPoint extends Offset {
  /// Timestamp of this point. Used to determine velocity to other points.
  final int timestamp;

  /// 2D point in canvas space.
  /// [timestamp] of this [Offset]. Used to determine velocity to other points.
  const OffsetPoint({
    required double dx,
    required double dy,
    required this.timestamp,
  }) : super(dx, dy);

  factory OffsetPoint.from(Offset offset) => OffsetPoint(
    dx: offset.dx,
    dy: offset.dy,
    timestamp: DateTime.now().millisecondsSinceEpoch,
  );

  /// Returns velocity between this and [other] - previous point.
  double velocityFrom(OffsetPoint other) => timestamp != other.timestamp
      ? this.distanceTo(other) / (timestamp - other.timestamp)
      : 0.0;

  @override
  OffsetPoint translate(double translateX, double translateY) {
    return OffsetPoint(
      dx: dx + translateX,
      dy: dy + translateY,
      timestamp: timestamp,
    );
  }

  @override
  OffsetPoint scale(double scaleX, double scaleY) {
    return OffsetPoint(
      dx: dx * scaleX,
      dy: dy * scaleY,
      timestamp: timestamp,
    );
  }

  @override
  bool operator ==(other) {
    return other is OffsetPoint &&
        other.dx == dx &&
        other.dy == dy &&
        other.timestamp == timestamp;
  }

  @override
  int get hashCode => hashValues(super.hashCode, timestamp);
}

/// Line between two points. Curve of this line is controlled with other two points.
/// Check https://cubic-bezier.com/ for more info about Bezier Curve.
class CubicLine extends Offset {
  /// Initial point of curve.
  final OffsetPoint start;

  /// Control of [start] point.
  final Offset cpStart;

  /// Control of [end] point
  final Offset cpEnd;

  /// End point of curve.
  final OffsetPoint end;

  late double _velocity;
  late double _distance;

  /// Cache of Up vector.
  Offset? _upStartVector;

  /// Up vector of [start] point.
  Offset get upStartVector =>
      _upStartVector ??
          (_upStartVector = start.directionTo(point(0.001)).rotate(-math.pi * 0.5));

  /// Cache of Up vector.
  Offset? _upEndVector;

  /// Up vector of [end] point.
  Offset get upEndVector =>
      _upEndVector ??
          (_upEndVector = end.directionTo(point(0.999)).rotate(math.pi * 0.5));

  /// Down vector.
  Offset get _downStartVector => upStartVector.rotate(math.pi);

  /// Down vector.
  Offset get _downEndVector => upEndVector.rotate(math.pi);

  /// Start ratio size of line.
  double startSize;

  /// End ratio size of line.
  double endSize;

  /// Checks if point is dot.
  /// Returns 'true' if [start] and [end] is same -> [velocity] is zero.
  bool get isDot => _velocity == 0.0;

  /// Based on Bezier Cubic curve.
  /// [start] point of curve.
  /// [end] point of curve.
  /// [cpStart] - control point of [start] vector.
  /// [cpEnd] - control point of [end] vector.
  /// [startSize] - size ratio at begin of curve.
  /// [endSize] - size ratio at end of curve.
  /// [upStartVector] - pre-calculated Up vector fo start point.
  /// [upEndVector] - pre-calculated Up vector of end point.
  CubicLine({
    required this.start,
    required this.cpStart,
    required this.cpEnd,
    required this.end,
    Offset? upStartVector,
    Offset? upEndVector,
    this.startSize: 0.0,
    this.endSize: 0.0,
  }) : super(start.dx, start.dy) {
    _upStartVector = upStartVector;
    _upEndVector = upEndVector;
    _velocity = end.velocityFrom(start);
    _distance = start.distanceTo(end);
  }

  @override
  CubicLine scale(double scaleX, double scaleY) => CubicLine(
    start: start.scale(scaleX, scaleY),
    cpStart: cpStart.scale(scaleX, scaleY),
    cpEnd: cpEnd.scale(scaleX, scaleY),
    end: end.scale(scaleX, scaleY),
    upStartVector: _upStartVector,
    upEndVector: _upEndVector,
    startSize: startSize * (scaleX + scaleY) * 0.5,
    endSize: endSize * (scaleX + scaleY) * 0.5,
  );

  @override
  CubicLine translate(double translateX, double translateY) => CubicLine(
    start: start.translate(translateX, translateY),
    cpStart: cpStart.translate(translateX, translateY),
    cpEnd: cpEnd.translate(translateX, translateY),
    end: end.translate(translateX, translateY),
    upStartVector: _upStartVector,
    upEndVector: _upEndVector,
    startSize: startSize,
    endSize: endSize,
  );

  /// Calculates length of Cubic curve with given [accuracy].
  /// 0 - fastest, raw accuracy.
  /// 1 - slowest, most accurate.
  /// Returns length of curve.
  double length({double accuracy: 0.1}) {
    final steps = (accuracy * 100).toInt();

    if (steps <= 1) {
      return _distance;
    }

    double length = 0.0;

    Offset prevPoint = start;
    for (int i = 1; i < steps; i++) {
      final t = i / steps;

      final next = point(t);

      length += prevPoint.distanceTo(next);
      prevPoint = next;
    }

    return length;
  }

  /// Calculates point on curve at given [t].
  /// [t] - 0 to 1.
  /// Returns location on Curve at [t].
  Offset point(double t) {
    final rt = 1.0 - t;
    return (start * rt * rt * rt) +
        (cpStart * 3.0 * rt * rt * t) +
        (cpEnd * 3.0 * rt * t * t) +
        (end * t * t * t);
  }

  /// Velocity along this line.
  double velocity({double accuracy: 0.0}) => start.timestamp != end.timestamp
      ? length(accuracy: accuracy) / (end.timestamp - start.timestamp)
      : 0.0;

  /// Combines line velocity with [inVelocity] based on [velocityRatio].
  double combineVelocity(double inVelocity,
      {double velocityRatio: 0.65, double maxFallOff: 1.0}) {
    final value =
        (_velocity * velocityRatio) + (inVelocity * (1.0 - velocityRatio));

    maxFallOff *= _distance / 10.0;

    final dif = value - inVelocity;
    if (dif.abs() > maxFallOff) {
      if (dif > 0.0) {
        return inVelocity + maxFallOff;
      } else {
        return inVelocity - maxFallOff;
      }
    }

    return value;
  }

  /// Converts this line to Cubic [Path].
  Path toPath() => Path()
    ..moveTo(dx, dy)
    ..cubicTo(cpStart.dx, cpStart.dy, cpEnd.dx, cpEnd.dy, end.dx, end.dy);

  /// Converts this line to [CubicArc].
  List<CubicArc> toArc(double size, double deltaSize, {double precision: 0.5}) {
    final list = <CubicArc>[];

    final steps = (_distance * precision).floor().clamp(1, 30);

    Offset start = this.start;
    for (int i = 0; i < steps; i++) {
      final t = (i + 1) / steps;
      final loc = point(t);
      final width = size + deltaSize * t;

      list.add(CubicArc(
        start: start,
        location: loc,
        size: width,
      ));

      start = loc;
    }

    return list;
  }

  /// Converts this line to closed [Path].
  Path toShape(double size, double maxSize) {
    final startArm = (size + (maxSize - size) * startSize) * 0.5;
    final endArm = (size + (maxSize - size) * endSize) * 0.5;

    final sDirUp = upStartVector;
    final eDirUp = upEndVector;

    final d1 = sDirUp * startArm;
    final d2 = eDirUp * endArm;
    final d3 = eDirUp.rotate(math.pi) * endArm;
    final d4 = sDirUp.rotate(math.pi) * startArm;

    return Path()
      ..start(start + d1)
      ..cubic(cpStart + d1, cpEnd + d2, end + d2)
      ..line(end + d3)
      ..cubic(cpEnd + d3, cpStart + d4, start + d4)
      ..close();
  }

  /// Returns Up offset of start point.
  Offset cpsUp(double size, double maxSize) =>
      upStartVector * startRadius(size, maxSize);

  /// Returns Up offset of end point.
  Offset cpeUp(double size, double maxSize) =>
      upEndVector * endRadius(size, maxSize);

  /// Returns Down offset of start point.
  Offset cpsDown(double size, double maxSize) =>
      _downStartVector * startRadius(size, maxSize);

  /// Returns Down offset of end point.
  Offset cpeDown(double size, double maxSize) =>
      _downEndVector * endRadius(size, maxSize);

  /// Returns radius of start point.
  double startRadius(double size, double maxSize) =>
      _lerpRadius(size, maxSize, startSize);

  /// Returns radius of end point.
  double endRadius(double size, double maxSize) =>
      _lerpRadius(size, maxSize, endSize);

  /// Linear interpolation of size.
  /// Returns radius of interpolated size.
  double _lerpRadius(double size, double maxSize, double t) =>
      (size + (maxSize - size) * t) * 0.5;

  /// Calculates [current] point based on [previous] and [next] control points.
  static Offset softCP(OffsetPoint current,
      {OffsetPoint? previous,
        OffsetPoint? next,
        bool reverse: false,
        double smoothing: 0.65}) {
    assert(smoothing >= 0.0 && smoothing <= 1.0);

    previous ??= current;
    next ??= current;

    final sharpness = 1.0 - smoothing;

    final dist1 = previous.distanceTo(current);
    final dist2 = current.distanceTo(next);
    final dist = dist1 + dist2;
    final dir1 = current.directionTo(next);
    final dir2 = current.directionTo(previous);
    final dir3 =
    reverse ? next.directionTo(previous) : previous.directionTo(next);

    final velocity =
    (dist * 0.3 / (next.timestamp - previous.timestamp)).clamp(0.5, 3.0);
    final ratio = (dist * velocity * smoothing)
        .clamp(0.0, (reverse ? dist2 : dist1) * 0.5);

    final dir =
        ((reverse ? dir2 : dir1) * sharpness) + (dir3 * smoothing) * ratio;
    final x = current.dx + dir.dx;
    final y = current.dy + dir.dy;

    return Offset(x, y);
  }
}

/// Arc between two points.
class CubicArc extends Offset {
  static const _pi2 = math.pi * 2.0;

  /// End location of arc.
  final Offset location;

  /// Line size.
  final double size;

  /// Arc path.
  Path get path => Path()
    ..moveTo(dx, dy)
    ..arcToPoint(location, rotation: _pi2);

  /// Rectangle of start and end point.
  Rect get rect => Rect.fromPoints(this, location);

  /// Arc line.
  /// [start] point of arc.
  /// [location] end point of arc.
  /// [size] ratio of arc. typically 0 - 1.
  CubicArc({
    required Offset start,
    required this.location,
    this.size: 1.0,
  }) : super(start.dx, start.dy);

  @override
  Offset translate(double translateX, double translateY) => CubicArc(
    start: Offset(dx + translateX, dy + translateY),
    location: location.translate(translateX, translateY),
    size: size,
  );

  @override
  Offset scale(double scaleX, double scaleY) => CubicArc(
    start: Offset(dx * scaleX, dy * scaleY),
    location: location.scale(scaleX, scaleY),
    size: size * (scaleX + scaleY) * 0.5,
  );
}

/// Combines sequence of points into one Line.
class CubicPath {
  /// Raw data.
  final _points = <OffsetPoint>[];

  /// [CubicLine] representation of path.
  final _lines = <CubicLine>[];

  /// [CubicArc] representation of path.
  final _arcs = <CubicArc>[];

  /// Returns raw data of path.
  List<OffsetPoint> get points => _points;

  /// Returns [CubicLine] representation of path.
  List<CubicLine> get lines => _lines;

  /// Returns [CubicArc] representation of path.
  List<CubicArc> get arcs => _arcs;

  /// First point of path.
  Offset? get _origin => _points.isNotEmpty ? _points[0] : null;

  /// Last point of path.
  OffsetPoint? get _lastPoint =>
      _points.isNotEmpty ? _points[_points.length - 1] : null;

  /// Checks if path is valid.
  bool get isFilled => _lines.isNotEmpty;

  /// Unfinished path.
  Path? _temp;

  /// Returns currently unfinished part of path.
  Path? get tempPath => _temp;

  /// Maximum possible velocity.
  double maxVelocity = 1.0;

  /// Actual average velocity.
  double _currentVelocity = 0.0;

  /// Actual size based on velocity.
  double _currentSize = 0.0;

  /// Distance between two control points.
  final threshold;

  /// Ratio of line smoothing.
  /// Don't have impact to performance. Values between 0 - 1.
  /// [0] - no smoothing, no flattening.
  /// [1] - best smoothing, but flattened.
  /// Best results are between: 0.5 - 0.85.
  final smoothRatio;

  /// Checks if this Line is just dot.
  bool get isDot => lines.length == 1 && lines[0].isDot;

  /// Line builder.
  /// [threshold] - Distance between two control points.
  /// [smoothRatio] - Ratio of line smoothing.
  CubicPath({
    this.threshold: 3.0,
    this.smoothRatio: 0.65,
  });

  /// Adds line to path.
  void _addLine(CubicLine line) {
    if (_lines.length == 0) {
      if (_currentVelocity == 0.0) {
        _currentVelocity = line._velocity;
      }

      if (_currentSize == 0.0) {
        _currentSize = _lineSize(_currentVelocity, maxVelocity);
      }
    } else {
      line._upStartVector = _lines.last.upEndVector;
    }

    _lines.add(line);

    final combinedVelocity =
    line.combineVelocity(_currentVelocity, maxFallOff: 0.125);
    final double endSize = _lineSize(combinedVelocity, maxVelocity);

    if (combinedVelocity > maxVelocity) {
      maxVelocity = combinedVelocity;
    }

    line.startSize = _currentSize;
    line.endSize = endSize;

    _arcs.addAll(line.toArc(_currentSize, endSize - _currentSize));

    _currentSize = endSize;
    _currentVelocity = combinedVelocity;
  }

  /// Adds dot to path.
  void _addDot(CubicLine line) {
    final size = 0.25 + _lineSize(_currentVelocity, maxVelocity) * 0.5;
    line.startSize = size;

    _lines.add(line);
    _arcs.addAll(line.toArc(size, 0.0));
  }

  /// Calculates line size based on [velocity].
  double _lineSize(double velocity, double max) {
    velocity /= max;

    return 1.0 - velocity.clamp(0.0, 1.0);
  }

  /// Starts path at given [point].
  /// Must be called as first, before [begin], [end].
  void begin(Offset point, {double velocity: 0.0}) {
    _points.add(OffsetPoint.from(point));
    _currentVelocity = velocity;

    _temp = _dot(point);
  }

  /// Alters path with given [point].
  void add(Offset point) {
    assert(_origin != null);

    final nextPoint = point is OffsetPoint ? point : OffsetPoint.from(point);

    if (_lastPoint == null || _lastPoint!.distanceTo(nextPoint) < threshold) {
      _temp = _line(_points.last, nextPoint);

      return;
    }

    _points.add(nextPoint);
    int count = _points.length;

    if (count < 3) {
      if (count > 1) {
        _temp = _line(_points[0], _points[1]);
      }

      return;
    }

    int i = count - 3;

    final prev = i > 0 ? _points[i - 1] : _points[i];
    final start = _points[i];
    final end = _points[i + 1];
    final next = _points[i + 2];

    final cpStart = CubicLine.softCP(
      start,
      previous: prev,
      next: end,
      smoothing: smoothRatio,
    );

    final cpEnd = CubicLine.softCP(
      end,
      previous: start,
      next: next,
      smoothing: smoothRatio,
      reverse: true,
    );

    final line = CubicLine(
      start: start,
      cpStart: cpStart,
      cpEnd: cpEnd,
      end: end,
    );

    _addLine(line);

    _temp = _line(end, next);
  }

  bool hasPoint(){
    return _points.isNotEmpty;
  }

  /// Ends path at given [point].
  bool end({Offset? point}) {
    if (point != null) {
      add(point);
    }

    _temp = null;

    if (_points.isEmpty) {
      return false;
    }

    if (_points.length < 3) {
      if (_points.length == 1) {
        _addDot(CubicLine(
          start: _points[0],
          cpStart: _points[0],
          cpEnd: _points[0],
          end: _points[0],
        ));
      } else {
        if (_points[0].distanceTo(points[1]) > 0.0) {
          _addLine(CubicLine(
            start: _points[0],
            cpStart: _points[0],
            cpEnd: _points[1],
            end: _points[1],
          ));
        }
      }
    } else {
      final i = _points.length - 3;

      if (_points[i + 1].distanceTo(points[i + 2]) > 0.0) {
        _addLine(CubicLine(
          start: _points[i + 1],
          cpStart: _points[i + 1],
          cpEnd: _points[i + 2],
          end: _points[i + 2],
        ));
      }
    }

    return true;
  }

  /// Creates [Path] as dot at given [point].
  Path _dot(Offset point) => Path()
    ..moveTo(point.dx, point.dy)
    ..cubicTo(
      point.dx,
      point.dy,
      point.dx,
      point.dy,
      point.dx,
      point.dy,
    );

  /// Creates [Path] between [start] and [end] points, curve is controlled be [startCp] and [endCp] control points.
  Path _line(Offset start, Offset end, [Offset? startCp, Offset? endCp]) =>
      Path()
        ..moveTo(start.dx, start.dy)
        ..cubicTo(
          startCp != null ? startCp.dx : (start.dx + end.dx) * 0.5,
          startCp != null ? startCp.dy : (start.dy + end.dy) * 0.5,
          endCp != null ? endCp.dx : (start.dx + end.dx) * 0.5,
          endCp != null ? endCp.dy : (start.dy + end.dy) * 0.5,
          end.dx,
          end.dy,
        );

  /// Sets scale of whole line.
  void setScale(double ratio) {
    if (!isFilled) {
      return;
    }

    final arcData = PathUtil.scale<CubicArc>(_arcs, ratio);
    _arcs
      ..clear()
      ..addAll(arcData);

    final lineData = PathUtil.scale<CubicLine>(_lines, ratio);
    _lines
      ..clear()
      ..addAll(lineData);
  }

  /// Clears all path data-.
  void clear() {
    _points.clear();
    _lines.clear();
    _arcs.clear();
  }
}