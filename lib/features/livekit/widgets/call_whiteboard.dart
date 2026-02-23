import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_math_fork/flutter_math.dart';

import '../../../l10n/app_localizations.dart';

enum WhiteboardTool {
  pen,
  highlighter,
  eraser,
  line,
  rectangle,
  oval,
  arrow,
  text,
  equation,
}

/// Whiteboard data message types for LiveKit Data sync
class WhiteboardMessage {
  static const String typeProject = 'project';
  static const String typeRequestProject = 'request_project';
  static const String typeClosed = 'whiteboard_closed';
  static const String typeStudentDrawingPermission =
      'student_drawing_permission';

  final String type;
  final Map<String, dynamic>? payload;

  WhiteboardMessage({required this.type, this.payload});

  factory WhiteboardMessage.fromJson(Map<String, dynamic> json) {
    return WhiteboardMessage(
      type: json['type']?.toString() ?? '',
      payload: json['payload'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      if (payload != null) 'payload': payload,
    };
  }

  String encode() => jsonEncode(toJson());

  static WhiteboardMessage? decode(String data) {
    try {
      final decoded = jsonDecode(data);
      if (decoded is Map<String, dynamic>) {
        return WhiteboardMessage.fromJson(decoded);
      }
    } catch (_) {}
    return null;
  }
}

/// A single stroke in the whiteboard
class WhiteboardStroke {
  final String id;
  final List<Offset> points;
  final Color color;
  final double strokeWidth;

  /// If true, [points] are normalized to the canvas size (0..1 range).
  /// This makes drawings render consistently across different screen sizes.
  final bool normalized;

  WhiteboardStroke({
    required this.id,
    required this.points,
    required this.color,
    required this.strokeWidth,
    this.normalized = false,
  });

  factory WhiteboardStroke.fromJson(Map<String, dynamic> json) {
    final pointsList = (json['points'] as List?)
            ?.map((p) => Offset(
                  (p['x'] as num?)?.toDouble() ?? 0,
                  (p['y'] as num?)?.toDouble() ?? 0,
                ))
            .toList() ??
        [];

    return WhiteboardStroke(
      id: json['id']?.toString() ?? '',
      points: pointsList,
      color: Color(json['color'] as int? ?? 0xFF000000),
      strokeWidth: (json['strokeWidth'] as num?)?.toDouble() ?? 3.0,
      normalized: json['normalized'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'points': points.map((p) => {'x': p.dx, 'y': p.dy}).toList(),
      'color': color.toARGB32(),
      'strokeWidth': strokeWidth,
      'normalized': normalized,
    };
  }
}

/// A text item (for equations/labels) drawn on the whiteboard
class WhiteboardTextItem {
  final String id;
  final String text;
  final Offset position;
  final Color color;
  final double fontSize;
  final bool normalized;

  WhiteboardTextItem({
    required this.id,
    required this.text,
    required this.position,
    required this.color,
    required this.fontSize,
    this.normalized = true,
  });

  factory WhiteboardTextItem.fromJson(Map<String, dynamic> json) {
    return WhiteboardTextItem(
      id: json['id']?.toString() ?? '',
      text: json['text']?.toString() ?? '',
      position: Offset(
        (json['x'] as num?)?.toDouble() ?? 0,
        (json['y'] as num?)?.toDouble() ?? 0,
      ),
      color: Color(json['color'] as int? ?? 0xFF111827),
      fontSize: (json['fontSize'] as num?)?.toDouble() ?? 28.0,
      normalized: json['normalized'] != false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'x': position.dx,
      'y': position.dy,
      'color': color.toARGB32(),
      'fontSize': fontSize,
      'normalized': normalized,
    };
  }
}

enum _WhiteboardActionKind { stroke, text }

class _WhiteboardAction {
  final _WhiteboardActionKind kind;
  final WhiteboardStroke? stroke;
  final WhiteboardTextItem? textItem;

  const _WhiteboardAction._({
    required this.kind,
    this.stroke,
    this.textItem,
  });

  factory _WhiteboardAction.stroke(WhiteboardStroke stroke) {
    return _WhiteboardAction._(
      kind: _WhiteboardActionKind.stroke,
      stroke: stroke,
    );
  }

  factory _WhiteboardAction.text(WhiteboardTextItem textItem) {
    return _WhiteboardAction._(
      kind: _WhiteboardActionKind.text,
      textItem: textItem,
    );
  }
}

/// The whiteboard canvas painter (strokes only - text is rendered as widgets)
class WhiteboardPainter extends CustomPainter {
  final List<WhiteboardStroke> strokes;
  final WhiteboardStroke? currentStroke;

  WhiteboardPainter({
    required this.strokes,
    this.currentStroke,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw completed strokes
    for (final stroke in strokes) {
      _drawStroke(canvas, stroke, size);
    }

    // Draw current stroke being drawn
    if (currentStroke != null) {
      _drawStroke(canvas, currentStroke!, size);
    }
    // Note: Text items are rendered as overlay widgets for proper LaTeX support
  }

  void _drawStroke(Canvas canvas, WhiteboardStroke stroke, Size size) {
    if (stroke.points.isEmpty) return;

    Offset toCanvasPoint(Offset p) {
      if (!stroke.normalized) return p;
      // Clamp normalized points to reduce weird out-of-bounds artifacts.
      final nx = (p.dx).clamp(0.0, 1.0).toDouble();
      final ny = (p.dy).clamp(0.0, 1.0).toDouble();
      return Offset(nx * size.width, ny * size.height);
    }

    final paint = Paint()
      ..color = stroke.color
      ..strokeWidth = stroke.strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    if (stroke.points.length == 1) {
      // Draw a dot for single point
      canvas.drawCircle(
          toCanvasPoint(stroke.points.first), stroke.strokeWidth / 2, paint);
      return;
    }

    final path = Path();
    final first = toCanvasPoint(stroke.points.first);
    path.moveTo(first.dx, first.dy);

    for (int i = 1; i < stroke.points.length; i++) {
      final pt = toCanvasPoint(stroke.points[i]);
      path.lineTo(pt.dx, pt.dy);
    }

    canvas.drawPath(path, paint);
  }

  // Note: Text/math rendering is handled by widget overlays in CallWhiteboardState._buildTextOverlays()
  // using flutter_math_fork for proper LaTeX support (fractions, integrals, etc.)

  @override
  bool shouldRepaint(covariant WhiteboardPainter oldDelegate) {
    return oldDelegate.strokes != strokes ||
        oldDelegate.currentStroke != currentStroke;
  }
}

/// Whiteboard widget for collaborative drawing (teacher and students can draw)
class CallWhiteboard extends StatefulWidget {
  final bool isTeacher;
  final void Function(Map<String, dynamic> projectData)? onSendProject;
  final Stream<Map<String, dynamic>>? projectStream;
  final VoidCallback? onClose;

  /// If true, students can also draw on the whiteboard (controlled by teacher)
  final bool studentDrawingEnabled;

  /// Callback when teacher toggles student drawing permission
  final void Function(bool enabled)? onStudentDrawingToggle;

  /// Initial strokes to load (from Firestore persistence)
  final List<Map<String, dynamic>>? initialStrokes;

  /// GlobalKey to access the whiteboard state for capturing
  final GlobalKey<CallWhiteboardState>? whiteboardKey;

  const CallWhiteboard({
    super.key,
    required this.isTeacher,
    this.onSendProject,
    this.projectStream,
    this.onClose,
    this.studentDrawingEnabled =
        false, // Disabled by default, teacher must enable
    this.onStudentDrawingToggle,
    this.initialStrokes,
    this.whiteboardKey,
  });

  @override
  State<CallWhiteboard> createState() => CallWhiteboardState();
}

class CallWhiteboardState extends State<CallWhiteboard> {
  final List<WhiteboardStroke> _strokes = [];
  final List<WhiteboardTextItem> _texts = [];
  final List<_WhiteboardAction> _actionHistory = [];
  final List<_WhiteboardAction> _redoStack = [];
  WhiteboardStroke? _currentStroke;
  Offset? _pendingTextPosition;
  String? _selectedTextId;
  String? _editingTextId;
  StreamSubscription<Map<String, dynamic>>? _projectSubscription;
  Timer? _debounceTimer;
  final TextEditingController _textEditingController = TextEditingController();
  final FocusNode _textFocusNode = FocusNode();

  // Key for capturing whiteboard as image
  final GlobalKey _repaintBoundaryKey = GlobalKey();

  // Drawing settings
  Color _selectedColor = Colors.black;
  double _strokeWidth = 3.0;
  int _strokeIdCounter = 0;
  WhiteboardTool _tool = WhiteboardTool.pen;

  /// Capture the whiteboard canvas as a PNG image bytes
  Future<Uint8List?> captureWhiteboard({double pixelRatio = 2.0}) async {
    try {
      final boundary = _repaintBoundaryKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) {
        debugPrint('CallWhiteboard: Cannot capture - boundary is null');
        return null;
      }

      final image = await boundary.toImage(pixelRatio: pixelRatio);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        debugPrint('CallWhiteboard: Cannot capture - byteData is null');
        return null;
      }

      debugPrint(
          'CallWhiteboard: Captured whiteboard image (${byteData.lengthInBytes} bytes, pixelRatio: $pixelRatio)');
      return byteData.buffer.asUint8List();
    } catch (e) {
      debugPrint('CallWhiteboard: Error capturing whiteboard: $e');
      return null;
    }
  }

  // Available colors
  static const List<Color> _colors = [
    Colors.black,
    Colors.red,
    Colors.blue,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.yellow,
    Colors.white,
  ];

  // Available stroke widths
  static const List<double> _strokeWidths = [2.0, 4.0, 6.0, 10.0];

  // Debounce delay for sending project updates (ms)
  static const int _sendDebounceMs = 400;

  @override
  void initState() {
    super.initState();
    _subscribeToProjectStream();
    _loadInitialStrokes();
  }

  void _loadInitialStrokes() {
    if (widget.initialStrokes != null && widget.initialStrokes!.isNotEmpty) {
      try {
        final strokesList = widget.initialStrokes!
            .map((s) => WhiteboardStroke.fromJson(s))
            .toList();
        _strokes.addAll(strokesList);
        _rebuildActionHistory();
        debugPrint(
            'CallWhiteboard: Loaded ${strokesList.length} initial strokes from persistence');
      } catch (e) {
        debugPrint('CallWhiteboard: Error loading initial strokes: $e');
      }
    }
  }

  void _rebuildActionHistory() {
    _actionHistory
      ..clear()
      ..addAll(_strokes.map(_WhiteboardAction.stroke))
      ..addAll(_texts.map(_WhiteboardAction.text));
    _redoStack.clear();
  }

  @override
  void didUpdateWidget(CallWhiteboard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.projectStream != widget.projectStream) {
      _projectSubscription?.cancel();
      _subscribeToProjectStream();
    }
  }

  void _subscribeToProjectStream() {
    debugPrint(
        'CallWhiteboard: Subscribing to project stream (isTeacher: ${widget.isTeacher}, hasStream: ${widget.projectStream != null})');
    _projectSubscription = widget.projectStream?.listen(
      _onProjectReceived,
      onError: (e) => debugPrint('CallWhiteboard: Stream error: $e'),
      onDone: () => debugPrint('CallWhiteboard: Stream done'),
    );
  }

  void _onProjectReceived(Map<String, dynamic> projectData) {
    if (!mounted) return;

    debugPrint(
        'CallWhiteboard: Received project data (isTeacher: ${widget.isTeacher})');

    try {
      final strokesList = (projectData['strokes'] as List?)
              ?.map((s) => WhiteboardStroke.fromJson(s as Map<String, dynamic>))
              .toList() ??
          [];
      final textsList = (projectData['texts'] as List?)
              ?.map(
                (t) => WhiteboardTextItem.fromJson(t as Map<String, dynamic>),
              )
              .toList() ??
          [];

      debugPrint(
          'CallWhiteboard: Received ${strokesList.length} strokes and ${textsList.length} text items, local has ${_strokes.length} strokes and ${_texts.length} text items');

      // Replace local strokes with received strokes (source of truth from sender)
      // This ensures undo/delete/clear operations sync properly
      setState(() {
        _strokes.clear();
        _strokes.addAll(strokesList);
        _texts.clear();
        _texts.addAll(textsList);
        _pendingTextPosition = null;
        _selectedTextId = null;
        _editingTextId = null;
        _textEditingController.clear();
        _rebuildActionHistory();
      });

      debugPrint(
          'CallWhiteboard: Updated to ${_strokes.length} strokes and ${_texts.length} text items');
    } catch (e) {
      debugPrint('CallWhiteboard: Error loading project: $e');
    }
  }

  Map<String, dynamic> _getProjectData() {
    return {
      'strokes': _strokes.map((s) => s.toJson()).toList(),
      'texts': _texts.map((t) => t.toJson()).toList(),
      'version': 2,
    };
  }

  void _sendProject() {
    if (widget.onSendProject == null) {
      debugPrint('CallWhiteboard: Cannot send - onSendProject is null');
      return;
    }
    final data = _getProjectData();
    debugPrint(
        'CallWhiteboard: Sending project with ${_strokes.length} strokes (isTeacher: ${widget.isTeacher})');
    widget.onSendProject?.call(data);
  }

  /// Check if the current user can draw
  bool get _canDraw => widget.isTeacher || widget.studentDrawingEnabled;

  bool get _isShapeTool =>
      _tool == WhiteboardTool.line ||
      _tool == WhiteboardTool.rectangle ||
      _tool == WhiteboardTool.oval ||
      _tool == WhiteboardTool.arrow;

  bool get _isTextTool =>
      _tool == WhiteboardTool.text || _tool == WhiteboardTool.equation;

  Color get _activeColor {
    switch (_tool) {
      case WhiteboardTool.highlighter:
        // Keep the same hue but use lower alpha like Zoom's highlighter.
        return _selectedColor.withValues(alpha: 0.35);
      case WhiteboardTool.eraser:
        // Background is white; treat eraser as a fat white stroke.
        return Colors.white;
      case WhiteboardTool.pen:
      case WhiteboardTool.line:
      case WhiteboardTool.rectangle:
      case WhiteboardTool.oval:
      case WhiteboardTool.arrow:
      case WhiteboardTool.text:
      case WhiteboardTool.equation:
        return _selectedColor;
    }
  }

  double get _activeStrokeWidth {
    switch (_tool) {
      case WhiteboardTool.eraser:
        return (_strokeWidth * 4).clamp(12.0, 40.0).toDouble();
      case WhiteboardTool.highlighter:
        return (_strokeWidth * 2).clamp(6.0, 24.0).toDouble();
      case WhiteboardTool.pen:
      case WhiteboardTool.line:
      case WhiteboardTool.rectangle:
      case WhiteboardTool.oval:
      case WhiteboardTool.arrow:
      case WhiteboardTool.text:
      case WhiteboardTool.equation:
        return _strokeWidth;
    }
  }

  void _scheduleSendProject() {
    if (!_canDraw) return;

    _debounceTimer?.cancel();
    _debounceTimer = Timer(
      const Duration(milliseconds: _sendDebounceMs),
      _sendProject,
    );
  }

  Offset _normalizePoint(Offset p, Size canvasSize) {
    if (canvasSize.width <= 0 || canvasSize.height <= 0) {
      return const Offset(0, 0);
    }
    final nx = (p.dx / canvasSize.width).clamp(0.0, 1.0).toDouble();
    final ny = (p.dy / canvasSize.height).clamp(0.0, 1.0).toDouble();
    return Offset(nx, ny);
  }

  double _textBoxWidth(Size canvasSize) {
    return math.min(360.0, math.max(180.0, canvasSize.width * 0.4));
  }

  double _textBoxHeight(Size canvasSize) {
    return math.min(180.0, math.max(96.0, canvasSize.height * 0.2));
  }

  WhiteboardTextItem _normalizedTextItem(
      WhiteboardTextItem item, Size canvasSize) {
    if (item.normalized) return item;
    return WhiteboardTextItem(
      id: item.id,
      text: item.text,
      position: _normalizePoint(item.position, canvasSize),
      color: item.color,
      fontSize: item.fontSize,
      normalized: true,
    );
  }

  void _syncTextInHistory(WhiteboardTextItem updated) {
    _WhiteboardAction remap(_WhiteboardAction action) {
      if (action.kind == _WhiteboardActionKind.text &&
          action.textItem?.id == updated.id) {
        return _WhiteboardAction.text(updated);
      }
      return action;
    }

    for (int i = 0; i < _actionHistory.length; i++) {
      _actionHistory[i] = remap(_actionHistory[i]);
    }
    for (int i = 0; i < _redoStack.length; i++) {
      _redoStack[i] = remap(_redoStack[i]);
    }
  }

  void _beginEditingText(WhiteboardTextItem item, Size canvasSize) {
    if (!_canDraw) return;
    final normalizedItem = _normalizedTextItem(item, canvasSize);
    setState(() {
      _selectedTextId = item.id;
      _editingTextId = item.id;
      _pendingTextPosition = normalizedItem.position;
      _textEditingController.text = item.text;
      _tool = _containsLatex(item.text)
          ? WhiteboardTool.equation
          : WhiteboardTool.text;
      _selectedColor = item.color;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _textFocusNode.requestFocus();
        _textEditingController.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _textEditingController.text.length,
        );
      }
    });
  }

  void _moveTextByDelta(String textId, Offset delta, Size canvasSize) {
    if (!_canDraw) return;
    final index = _texts.indexWhere((t) => t.id == textId);
    if (index == -1) return;

    final current = _normalizedTextItem(_texts[index], canvasSize);
    final dx = canvasSize.width <= 0 ? 0.0 : delta.dx / canvasSize.width;
    final dy = canvasSize.height <= 0 ? 0.0 : delta.dy / canvasSize.height;

    final boxWidthNorm = _textBoxWidth(canvasSize) / canvasSize.width;
    final boxHeightNorm = _textBoxHeight(canvasSize) / canvasSize.height;
    final maxX = (1.0 - boxWidthNorm).clamp(0.0, 1.0).toDouble();
    final maxY = (1.0 - boxHeightNorm).clamp(0.0, 1.0).toDouble();

    final updated = WhiteboardTextItem(
      id: current.id,
      text: current.text,
      position: Offset(
        (current.position.dx + dx).clamp(0.0, maxX).toDouble(),
        (current.position.dy + dy).clamp(0.0, maxY).toDouble(),
      ),
      color: current.color,
      fontSize: current.fontSize,
      normalized: true,
    );

    setState(() {
      _texts[index] = updated;
      _selectedTextId = textId;
    });
    _syncTextInHistory(updated);
    _scheduleSendProject();
  }

  void _deleteTextById(String textId) {
    if (!_canDraw) return;
    setState(() {
      _texts.removeWhere((t) => t.id == textId);
      _actionHistory.removeWhere(
        (a) => a.kind == _WhiteboardActionKind.text && a.textItem?.id == textId,
      );
      _redoStack.removeWhere(
        (a) => a.kind == _WhiteboardActionKind.text && a.textItem?.id == textId,
      );
      if (_selectedTextId == textId) _selectedTextId = null;
      if (_editingTextId == textId) _editingTextId = null;
      _pendingTextPosition = null;
      _textEditingController.clear();
    });
    _textFocusNode.unfocus();
    _scheduleSendProject();
  }

  List<Offset> _shapePoints({
    required WhiteboardTool tool,
    required Offset start,
    required Offset end,
  }) {
    final x1 = math.min(start.dx, end.dx);
    final y1 = math.min(start.dy, end.dy);
    final x2 = math.max(start.dx, end.dx);
    final y2 = math.max(start.dy, end.dy);

    switch (tool) {
      case WhiteboardTool.line:
        return [start, end];
      case WhiteboardTool.arrow:
        final dx = end.dx - start.dx;
        final dy = end.dy - start.dy;
        final len = math.sqrt(dx * dx + dy * dy);
        if (len <= 0.0001) return [start, end];

        // Arrowhead sized relative to stroke width, but in normalized space.
        final headLen = (0.035).clamp(0.02, 0.05).toDouble();
        final ux = dx / len;
        final uy = dy / len;
        final base = Offset(end.dx - ux * headLen, end.dy - uy * headLen);
        const angle = math.pi / 7;
        final sinA = math.sin(angle);
        final cosA = math.cos(angle);

        Offset rotate(Offset v, double sin, double cos) {
          return Offset(v.dx * cos - v.dy * sin, v.dx * sin + v.dy * cos);
        }

        final dir = Offset(ux, uy);
        final leftDir = rotate(dir, sinA, cosA);
        final rightDir = rotate(dir, -sinA, cosA);

        final left = Offset(
            base.dx - leftDir.dx * headLen, base.dy - leftDir.dy * headLen);
        final right = Offset(
            base.dx - rightDir.dx * headLen, base.dy - rightDir.dy * headLen);

        // Path: start -> end, then draw the two arrowhead legs.
        return [start, end, left, end, right];
      case WhiteboardTool.rectangle:
        return [
          Offset(x1, y1),
          Offset(x2, y1),
          Offset(x2, y2),
          Offset(x1, y2),
          Offset(x1, y1),
        ];
      case WhiteboardTool.oval:
        // Approximate ellipse with a polyline.
        final cx = (x1 + x2) / 2;
        final cy = (y1 + y2) / 2;
        final rx = (x2 - x1) / 2;
        final ry = (y2 - y1) / 2;
        if (rx <= 0.0001 || ry <= 0.0001) return [start, end];
        const segments = 36;
        final pts = <Offset>[];
        for (int i = 0; i <= segments; i++) {
          final t = (i / segments) * 2 * math.pi;
          pts.add(Offset(cx + math.cos(t) * rx, cy + math.sin(t) * ry));
        }
        return pts;
      case WhiteboardTool.pen:
      case WhiteboardTool.highlighter:
      case WhiteboardTool.eraser:
      case WhiteboardTool.text:
      case WhiteboardTool.equation:
        // Not used for freehand tools.
        return [start, end];
    }
  }

  void _onPanStart(DragStartDetails details, Size canvasSize) {
    if (!_canDraw || _isTextTool) return;

    final point = _normalizePoint(details.localPosition, canvasSize);
    setState(() {
      _selectedTextId = null;
      _editingTextId = null;
      _pendingTextPosition = null;
      _textEditingController.clear();
      _currentStroke = WhiteboardStroke(
        id: '${DateTime.now().millisecondsSinceEpoch}_${_strokeIdCounter++}',
        points: [point],
        color: _activeColor,
        strokeWidth: _activeStrokeWidth,
        normalized: true,
      );
    });
  }

  void _onPanUpdate(DragUpdateDetails details, Size canvasSize) {
    if (!_canDraw || _isTextTool || _currentStroke == null) return;

    final point = _normalizePoint(details.localPosition, canvasSize);
    setState(() {
      final current = _currentStroke!;
      if (_isShapeTool) {
        final start = current.points.isNotEmpty ? current.points.first : point;
        _currentStroke = WhiteboardStroke(
          id: current.id,
          points: _shapePoints(tool: _tool, start: start, end: point),
          color: current.color,
          strokeWidth: current.strokeWidth,
          normalized: current.normalized,
        );
      } else {
        _currentStroke = WhiteboardStroke(
          id: current.id,
          points: [...current.points, point],
          color: current.color,
          strokeWidth: current.strokeWidth,
          normalized: current.normalized,
        );
      }
    });
  }

  void _onPanEnd(DragEndDetails details) {
    if (!_canDraw || _isTextTool || _currentStroke == null) return;

    setState(() {
      final stroke = _currentStroke!;
      _strokes.add(stroke);
      _actionHistory.add(_WhiteboardAction.stroke(stroke));
      _currentStroke = null;
      _redoStack.clear();
    });
    _scheduleSendProject();
  }

  void _onTapDown(TapDownDetails details, Size canvasSize) {
    if (!_canDraw || !_isTextTool) {
      if (_selectedTextId != null || _pendingTextPosition != null) {
        setState(() {
          _selectedTextId = null;
          _editingTextId = null;
          _pendingTextPosition = null;
          _textEditingController.clear();
        });
      }
      _textFocusNode.unfocus();
      return;
    }

    final normalizedPoint = _normalizePoint(details.localPosition, canvasSize);
    setState(() {
      _selectedTextId = null;
      _editingTextId = null;
      _pendingTextPosition = normalizedPoint;
      _textEditingController.clear();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _textFocusNode.requestFocus();
      }
    });
  }

  void _commitTextFromEditor() {
    if (!_canDraw || _pendingTextPosition == null) return;

    final inputText = _textEditingController.text.trim();
    if (inputText.isEmpty) {
      _cancelTextEditor();
      return;
    }

    final editingId = _editingTextId;
    if (editingId != null) {
      final index = _texts.indexWhere((t) => t.id == editingId);
      if (index != -1) {
        final existing = _texts[index];
        final updated = WhiteboardTextItem(
          id: existing.id,
          text: inputText,
          position: _pendingTextPosition!,
          color: _selectedColor,
          fontSize: _tool == WhiteboardTool.equation
              ? existing.fontSize.clamp(28.0, 34.0)
              : existing.fontSize.clamp(20.0, 30.0),
          normalized: true,
        );
        setState(() {
          _texts[index] = updated;
          _selectedTextId = updated.id;
          _editingTextId = null;
          _pendingTextPosition = null;
          _textEditingController.clear();
        });
        _syncTextInHistory(updated);
      } else {
        setState(() {
          _editingTextId = null;
          _pendingTextPosition = null;
          _textEditingController.clear();
        });
      }
    } else {
      final textItem = WhiteboardTextItem(
        id: '${DateTime.now().millisecondsSinceEpoch}_${_strokeIdCounter++}',
        text: inputText,
        position: _pendingTextPosition!,
        color: _selectedColor,
        fontSize: _tool == WhiteboardTool.equation ? 30 : 24,
        normalized: true,
      );

      setState(() {
        _texts.add(textItem);
        _actionHistory.add(_WhiteboardAction.text(textItem));
        _redoStack.clear();
        _selectedTextId = textItem.id;
        _editingTextId = null;
        _pendingTextPosition = null;
        _textEditingController.clear();
      });
    }
    _textFocusNode.unfocus();
    _scheduleSendProject();
  }

  void _cancelTextEditor() {
    setState(() {
      _editingTextId = null;
      _pendingTextPosition = null;
      _textEditingController.clear();
    });
    _textFocusNode.unfocus();
  }

  void _clearCanvas() {
    if (!_canDraw) return;

    setState(() {
      _strokes.clear();
      _texts.clear();
      _actionHistory.clear();
      _redoStack.clear();
      _selectedTextId = null;
      _editingTextId = null;
      _pendingTextPosition = null;
      _textEditingController.clear();
    });
    _textFocusNode.unfocus();
    _scheduleSendProject();
  }

  void _undoLast() {
    if (!_canDraw || _actionHistory.isEmpty) return;

    setState(() {
      final action = _actionHistory.removeLast();
      _redoStack.add(action);
      if (action.kind == _WhiteboardActionKind.stroke &&
          action.stroke != null) {
        _strokes.removeWhere((s) => s.id == action.stroke!.id);
      } else if (action.kind == _WhiteboardActionKind.text &&
          action.textItem != null) {
        _texts.removeWhere((t) => t.id == action.textItem!.id);
        if (_selectedTextId == action.textItem!.id) {
          _selectedTextId = null;
        }
      }
    });
    _scheduleSendProject();
  }

  void _redoLast() {
    if (!_canDraw || _redoStack.isEmpty) return;
    setState(() {
      final action = _redoStack.removeLast();
      _actionHistory.add(action);
      if (action.kind == _WhiteboardActionKind.stroke &&
          action.stroke != null) {
        _strokes.add(action.stroke!);
      } else if (action.kind == _WhiteboardActionKind.text &&
          action.textItem != null) {
        _texts.add(action.textItem!);
        _selectedTextId = action.textItem!.id;
      }
    });
    _scheduleSendProject();
  }

  /// Check if text contains LaTeX math notation
  bool _containsLatex(String text) {
    return text.contains('\\frac') ||
        text.contains('\\sqrt') ||
        text.contains('\\sum') ||
        text.contains('\\int') ||
        text.contains('\\prod') ||
        text.contains('^{') ||
        text.contains('_{') ||
        text.contains('\\') ||
        RegExp(r'\^[0-9a-zA-Z]').hasMatch(text) ||
        RegExp(r'_[0-9a-zA-Z]').hasMatch(text);
  }

  /// Build interactive text/equation boxes that can be selected, moved,
  /// edited, and deleted.
  List<Widget> _buildTextOverlays(Size canvasSize) {
    if (_texts.isEmpty) return [];

    const edgePadding = 10.0;
    final boxWidth = _textBoxWidth(canvasSize);
    final boxHeight = _textBoxHeight(canvasSize);
    final widgets = <Widget>[];

    for (final textItem in _texts) {
      if (textItem.text.trim().isEmpty) continue;

      final normalizedItem = _normalizedTextItem(textItem, canvasSize);
      var left = normalizedItem.position.dx * canvasSize.width;
      var top = normalizedItem.position.dy * canvasSize.height;
      left = left.clamp(edgePadding, canvasSize.width - boxWidth - edgePadding);
      top = top.clamp(edgePadding, canvasSize.height - boxHeight - edgePadding);

      final isSelected = _selectedTextId == textItem.id;
      final isEquation = _containsLatex(textItem.text);
      final fontSize = textItem.fontSize.clamp(16.0, 34.0);

      if (_editingTextId == textItem.id) {
        continue;
      }

      widgets.add(
        Positioned(
          left: left,
          top: top,
          width: boxWidth,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              setState(() {
                _selectedTextId = textItem.id;
                if (_editingTextId != null && _editingTextId != textItem.id) {
                  _editingTextId = null;
                  _pendingTextPosition = null;
                  _textEditingController.clear();
                }
              });
            },
            onDoubleTap:
                _canDraw ? () => _beginEditingText(textItem, canvasSize) : null,
            onPanStart: _canDraw && _isTextTool
                ? (_) {
                    setState(() {
                      _selectedTextId = textItem.id;
                      _editingTextId = null;
                      _pendingTextPosition = null;
                      _textEditingController.clear();
                    });
                  }
                : null,
            onPanUpdate: _canDraw && _isTextTool
                ? (details) =>
                    _moveTextByDelta(textItem.id, details.delta, canvasSize)
                : null,
            child: Container(
              constraints: BoxConstraints(
                minHeight: 72,
                maxHeight: boxHeight,
              ),
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.96),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF3B82F6)
                      : const Color(0xFFD1D5DB),
                  width: isSelected ? 2 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isSelected && _canDraw)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        _buildTextActionButton(
                          icon: Icons.edit,
                          color: const Color(0xFF2563EB),
                          tooltip: 'Edit',
                          onPressed: () =>
                              _beginEditingText(textItem, canvasSize),
                        ),
                        const SizedBox(width: 6),
                        _buildTextActionButton(
                          icon: Icons.delete_outline,
                          color: const Color(0xFFDC2626),
                          tooltip: 'Delete',
                          onPressed: () => _deleteTextById(textItem.id),
                        ),
                      ],
                    ),
                  if (isSelected && _canDraw) const SizedBox(height: 6),
                  ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: boxHeight - 20),
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: isEquation
                          ? _buildMathWidget(
                              textItem.text, textItem.color, fontSize)
                          : Text(
                              textItem.text,
                              style: TextStyle(
                                color: textItem.color,
                                fontSize: fontSize,
                                fontWeight: FontWeight.w600,
                                height: 1.35,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return widgets;
  }

  Widget _buildTextActionButton({
    required IconData icon,
    required Color color,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, size: 14, color: color),
        ),
      ),
    );
  }

  List<Widget> _buildPendingTextEditor(Size canvasSize) {
    if (_pendingTextPosition == null || !_canDraw || !_isTextTool) {
      return const [];
    }

    final isEquationMode = _tool == WhiteboardTool.equation;
    final isEditing = _editingTextId != null;
    const edgePadding = 12.0;
    final editorWidth = _textBoxWidth(canvasSize);
    var left = _pendingTextPosition!.dx * canvasSize.width;
    var top = _pendingTextPosition!.dy * canvasSize.height;
    left =
        left.clamp(edgePadding, canvasSize.width - editorWidth - edgePadding);
    top = top.clamp(
      edgePadding,
      canvasSize.height - _textBoxHeight(canvasSize) - edgePadding,
    );

    return [
      Positioned(
        left: left,
        top: top,
        child: Material(
          color: Colors.white,
          elevation: 8,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: editorWidth,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFD1D5DB)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _textEditingController,
                  focusNode: _textFocusNode,
                  autofocus: true,
                  textInputAction: TextInputAction.done,
                  minLines: 2,
                  maxLines: 5,
                  style: TextStyle(
                    color: _selectedColor,
                    fontSize: isEquationMode ? 20 : 18,
                    fontWeight: FontWeight.w600,
                  ),
                  onSubmitted: (_) => _commitTextFromEditor(),
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    hintText: isEquationMode
                        ? r'Type equation in box, e.g. \frac{a+b}{2}'
                        : 'Type text in box...',
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _cancelTextEditor,
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _commitTextFromEditor,
                      child: Text(
                        isEditing
                            ? 'Save'
                            : (isEquationMode ? 'Insert' : 'Add'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ];
  }

  /// Build a math widget that renders LaTeX properly
  Widget _buildMathWidget(String text, Color color, double fontSize) {
    try {
      // flutter_math_fork handles LaTeX rendering
      return Math.tex(
        text,
        textStyle: TextStyle(
          color: color,
          fontSize: fontSize,
        ),
        mathStyle: MathStyle.display,
        onErrorFallback: (error) {
          // If LaTeX parsing fails, show plain text
          return Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
            ),
          );
        },
      );
    } catch (e) {
      // Fallback to plain text on any error
      return Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
        ),
      );
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _projectSubscription?.cancel();
    _textEditingController.dispose();
    _textFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isNarrow = MediaQuery.of(context).size.width < 700;

    return Container(
      color: const Color(0xFF1a1a2e),
      child: Column(
        children: [
          // Toolbar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(
              color: Color(0xFF252540),
              border: Border(
                bottom: BorderSide(color: Colors.white12),
              ),
            ),
            child: isNarrow
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          // Close button (teacher only)
                          if (widget.isTeacher && widget.onClose != null) ...[
                            IconButton(
                              onPressed: widget.onClose,
                              icon: const Icon(Icons.close,
                                  color: Colors.white70),
                              tooltip:
                                  AppLocalizations.of(context)!.whiteboardClose,
                            ),
                            const SizedBox(width: 8),
                          ],

                          // Title
                          const Icon(Icons.draw,
                              color: Colors.white70, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              AppLocalizations.of(context)!.whiteboard,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),

                      // Student drawing toggle (teacher only)
                      if (widget.isTeacher &&
                          widget.onStudentDrawingToggle != null) ...[
                        const SizedBox(height: 8),
                        _buildStudentDrawingToggle(context),
                      ],

                      // Drawing tools (shown when user can draw)
                      if (_canDraw) ...[
                        const SizedBox(height: 8),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              ..._buildToolPicker(),
                              const SizedBox(width: 12),
                              ..._buildColorPickers(),
                              const SizedBox(width: 16),
                              _buildStrokeWidthPicker(),
                              const SizedBox(width: 8),
                              _buildUndoButton(),
                              _buildRedoButton(),
                              _buildClearButton(),
                              if (_isTextTool) ...[
                                const SizedBox(width: 8),
                                Text(
                                  _tool == WhiteboardTool.equation
                                      ? 'Click canvas to type equation, drag box to move'
                                      : 'Click canvas to type text, drag box to move',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ],
                  )
                : Row(
                    children: [
                      // Close button (teacher only)
                      if (widget.isTeacher && widget.onClose != null) ...[
                        IconButton(
                          onPressed: widget.onClose,
                          icon: const Icon(Icons.close, color: Colors.white70),
                          tooltip:
                              AppLocalizations.of(context)!.whiteboardClose,
                        ),
                        const SizedBox(width: 8),
                      ],

                      // Title
                      const Icon(Icons.draw, color: Colors.white70, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        AppLocalizations.of(context)!.whiteboard,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),

                      // Student drawing toggle (teacher only)
                      if (widget.isTeacher &&
                          widget.onStudentDrawingToggle != null) ...[
                        const SizedBox(width: 16),
                        _buildStudentDrawingToggle(context),
                      ],

                      // Drawing tools (shown when user can draw)
                      if (_canDraw) ...[
                        const SizedBox(width: 16),
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  ..._buildToolPicker(),
                                  const SizedBox(width: 12),
                                  ..._buildColorPickers(),
                                  const SizedBox(width: 16),
                                  _buildStrokeWidthPicker(),
                                  const SizedBox(width: 8),
                                  _buildUndoButton(),
                                  _buildRedoButton(),
                                  _buildClearButton(),
                                  if (_isTextTool) ...[
                                    const SizedBox(width: 8),
                                    Text(
                                      _tool == WhiteboardTool.equation
                                          ? 'Click canvas to type equation, drag box to move'
                                          : 'Click canvas to type text, drag box to move',
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
          ),

          // Canvas area
          Expanded(
            child: Stack(
              children: [
                // White canvas background
                Positioned.fill(
                  child: Container(
                    margin: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final canvasSize =
                              Size(constraints.maxWidth, constraints.maxHeight);
                          return RepaintBoundary(
                            key: _repaintBoundaryKey,
                            child: Stack(
                              children: [
                                // Strokes layer (painted)
                                Positioned.fill(
                                  child: _canDraw
                                      ? GestureDetector(
                                          onTapDown: (d) =>
                                              _onTapDown(d, canvasSize),
                                          onPanStart: (d) =>
                                              _onPanStart(d, canvasSize),
                                          onPanUpdate: (d) =>
                                              _onPanUpdate(d, canvasSize),
                                          onPanEnd: _onPanEnd,
                                          child: CustomPaint(
                                            painter: WhiteboardPainter(
                                              strokes: _strokes,
                                              currentStroke: _currentStroke,
                                            ),
                                            size: canvasSize,
                                          ),
                                        )
                                      : CustomPaint(
                                          painter: WhiteboardPainter(
                                            strokes: _strokes,
                                            currentStroke: null,
                                          ),
                                          size: canvasSize,
                                        ),
                                ),
                                // Text/Math overlay layer (widgets)
                                ..._buildTextOverlays(canvasSize),
                                ..._buildPendingTextEditor(canvasSize),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),

                // Info overlay for view-only mode (when student drawing is disabled)
                if (!_canDraw)
                  Positioned(
                    bottom: 32,
                    left: 32,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.visibility,
                              color: Colors.white70, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            AppLocalizations.of(context)!.whiteboardViewOnly,
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentDrawingToggle(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: widget.studentDrawingEnabled
            ? Colors.green.withValues(alpha: 0.2)
            : Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: widget.studentDrawingEnabled ? Colors.green : Colors.white30,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            widget.studentDrawingEnabled ? Icons.edit : Icons.visibility,
            color: widget.studentDrawingEnabled ? Colors.green : Colors.white70,
            size: 16,
          ),
          const SizedBox(width: 6),
          Text(
            widget.studentDrawingEnabled
                ? AppLocalizations.of(context)!.whiteboardStudentsCanDraw
                : AppLocalizations.of(context)!.whiteboardViewOnly,
            style: TextStyle(
              color:
                  widget.studentDrawingEnabled ? Colors.green : Colors.white70,
              fontSize: 12,
            ),
          ),
          const SizedBox(width: 4),
          SizedBox(
            height: 24,
            child: Switch(
              value: widget.studentDrawingEnabled,
              onChanged: widget.onStudentDrawingToggle,
              activeThumbColor: Colors.green,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildColorPickers() {
    return List.generate(_colors.length, (index) {
      final color = _colors[index];
      final isSelected = color == _selectedColor;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: InkWell(
          onTap: () => setState(() => _selectedColor = color),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? Colors.white : Colors.white30,
                width: isSelected ? 2.5 : 1,
              ),
            ),
          ),
        ),
      );
    });
  }

  Widget _buildStrokeWidthPicker() {
    return PopupMenuButton<double>(
      initialValue: _strokeWidth,
      onSelected: (value) => setState(() => _strokeWidth = value),
      tooltip: 'Brush size',
      itemBuilder: (context) => _strokeWidths
          .map((width) => PopupMenuItem(
                value: width,
                child: Row(
                  children: [
                    Container(
                      width: width * 2,
                      height: width * 2,
                      decoration: const BoxDecoration(
                        color: Colors.black,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text('${width.toInt()}px'),
                  ],
                ),
              ))
          .toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white12,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: _strokeWidth * 1.5,
              height: _strokeWidth * 1.5,
              decoration: BoxDecoration(
                color: _selectedColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_drop_down, color: Colors.white70, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildUndoButton() {
    final hasUndo = _actionHistory.isNotEmpty;
    return IconButton(
      onPressed: hasUndo ? _undoLast : null,
      icon: Icon(
        Icons.undo,
        color: hasUndo ? Colors.white70 : Colors.white24,
      ),
      tooltip: 'Undo',
    );
  }

  Widget _buildRedoButton() {
    return IconButton(
      onPressed: _redoStack.isEmpty ? null : _redoLast,
      icon: Icon(
        Icons.redo,
        color: _redoStack.isEmpty ? Colors.white24 : Colors.white70,
      ),
      tooltip: 'Redo',
    );
  }

  Widget _buildClearButton() {
    final hasContent = _strokes.isNotEmpty || _texts.isNotEmpty;
    return IconButton(
      onPressed: hasContent ? _clearCanvas : null,
      icon: Icon(
        Icons.delete_outline,
        color: hasContent ? Colors.white70 : Colors.white24,
      ),
      tooltip: 'Clear all',
    );
  }

  List<Widget> _buildToolPicker() {
    Widget toolButton({
      required WhiteboardTool tool,
      required IconData icon,
      required String tooltip,
    }) {
      final selected = _tool == tool;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: InkWell(
          onTap: () {
            setState(() {
              _tool = tool;
              _currentStroke = null;
              if (!_isTextTool) {
                _pendingTextPosition = null;
                _textEditingController.clear();
              }
            });
            if (!_isTextTool) {
              _textFocusNode.unfocus();
            }
          },
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: selected
                  ? Colors.white.withValues(alpha: 0.18)
                  : Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selected ? Colors.white54 : Colors.white12,
              ),
            ),
            child: Tooltip(
              message: tooltip,
              child: Icon(icon,
                  size: 18, color: selected ? Colors.white : Colors.white70),
            ),
          ),
        ),
      );
    }

    return [
      toolButton(
        tool: WhiteboardTool.pen,
        icon: Icons.brush,
        tooltip: 'Pen',
      ),
      toolButton(
        tool: WhiteboardTool.highlighter,
        icon: Icons.highlight,
        tooltip: 'Highlighter',
      ),
      toolButton(
        tool: WhiteboardTool.eraser,
        icon: Icons.auto_fix_high,
        tooltip: 'Eraser',
      ),
      toolButton(
        tool: WhiteboardTool.line,
        icon: Icons.show_chart,
        tooltip: 'Line',
      ),
      toolButton(
        tool: WhiteboardTool.arrow,
        icon: Icons.arrow_right_alt,
        tooltip: 'Arrow',
      ),
      toolButton(
        tool: WhiteboardTool.rectangle,
        icon: Icons.crop_square,
        tooltip: 'Rectangle',
      ),
      toolButton(
        tool: WhiteboardTool.oval,
        icon: Icons.circle_outlined,
        tooltip: 'Oval',
      ),
      toolButton(
        tool: WhiteboardTool.text,
        icon: Icons.text_fields,
        tooltip: 'Text',
      ),
      toolButton(
        tool: WhiteboardTool.equation,
        icon: Icons.functions,
        tooltip: 'Equation (LaTeX)',
      ),
    ];
  }
}
