import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';

enum WhiteboardTool {
  pen,
  highlighter,
  eraser,
  line,
  rectangle,
  oval,
  arrow,
}

/// Whiteboard data message types for LiveKit Data sync
class WhiteboardMessage {
  static const String typeProject = 'project';
  static const String typeRequestProject = 'request_project';
  static const String typeClosed = 'whiteboard_closed';
  static const String typeStudentDrawingPermission = 'student_drawing_permission';

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

/// The whiteboard canvas painter
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
      canvas.drawCircle(toCanvasPoint(stroke.points.first),
          stroke.strokeWidth / 2, paint);
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

  const CallWhiteboard({
    super.key,
    required this.isTeacher,
    this.onSendProject,
    this.projectStream,
    this.onClose,
    this.studentDrawingEnabled = false, // Disabled by default, teacher must enable
    this.onStudentDrawingToggle,
    this.initialStrokes,
  });

  @override
  State<CallWhiteboard> createState() => _CallWhiteboardState();
}

class _CallWhiteboardState extends State<CallWhiteboard> {
  final List<WhiteboardStroke> _strokes = [];
  final List<WhiteboardStroke> _redoStack = [];
  WhiteboardStroke? _currentStroke;
  StreamSubscription<Map<String, dynamic>>? _projectSubscription;
  Timer? _debounceTimer;

  // Drawing settings
  Color _selectedColor = Colors.black;
  double _strokeWidth = 3.0;
  int _strokeIdCounter = 0;
  WhiteboardTool _tool = WhiteboardTool.pen;

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
        debugPrint('CallWhiteboard: Loaded ${strokesList.length} initial strokes from persistence');
      } catch (e) {
        debugPrint('CallWhiteboard: Error loading initial strokes: $e');
      }
    }
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
    debugPrint('CallWhiteboard: Subscribing to project stream (isTeacher: ${widget.isTeacher}, hasStream: ${widget.projectStream != null})');
    _projectSubscription = widget.projectStream?.listen(
      _onProjectReceived,
      onError: (e) => debugPrint('CallWhiteboard: Stream error: $e'),
      onDone: () => debugPrint('CallWhiteboard: Stream done'),
    );
  }

  void _onProjectReceived(Map<String, dynamic> projectData) {
    if (!mounted) return;

    debugPrint('CallWhiteboard: Received project data (isTeacher: ${widget.isTeacher})');

    try {
      final strokesList = (projectData['strokes'] as List?)
              ?.map((s) => WhiteboardStroke.fromJson(s as Map<String, dynamic>))
              .toList() ??
          [];

      debugPrint('CallWhiteboard: Received ${strokesList.length} strokes, local has ${_strokes.length}');

      // Replace local strokes with received strokes (source of truth from sender)
      // This ensures undo/delete/clear operations sync properly
      setState(() {
        _strokes.clear();
        _strokes.addAll(strokesList);
        _redoStack.clear();
      });

      debugPrint('CallWhiteboard: Updated to ${_strokes.length} strokes');
    } catch (e) {
      debugPrint('CallWhiteboard: Error loading project: $e');
    }
  }

  Map<String, dynamic> _getProjectData() {
    return {
      'strokes': _strokes.map((s) => s.toJson()).toList(),
      'version': 2,
    };
  }

  void _sendProject() {
    if (widget.onSendProject == null) {
      debugPrint('CallWhiteboard: Cannot send - onSendProject is null');
      return;
    }
    final data = _getProjectData();
    debugPrint('CallWhiteboard: Sending project with ${_strokes.length} strokes (isTeacher: ${widget.isTeacher})');
    widget.onSendProject?.call(data);
  }

  /// Check if the current user can draw
  bool get _canDraw => widget.isTeacher || widget.studentDrawingEnabled;

  bool get _isShapeTool =>
      _tool == WhiteboardTool.line ||
      _tool == WhiteboardTool.rectangle ||
      _tool == WhiteboardTool.oval ||
      _tool == WhiteboardTool.arrow;

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
    if (canvasSize.width <= 0 || canvasSize.height <= 0) return const Offset(0, 0);
    final nx = (p.dx / canvasSize.width).clamp(0.0, 1.0).toDouble();
    final ny = (p.dy / canvasSize.height).clamp(0.0, 1.0).toDouble();
    return Offset(nx, ny);
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

        final left = Offset(base.dx - leftDir.dx * headLen, base.dy - leftDir.dy * headLen);
        final right = Offset(base.dx - rightDir.dx * headLen, base.dy - rightDir.dy * headLen);

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
        // Not used for freehand tools.
        return [start, end];
    }
  }

  void _onPanStart(DragStartDetails details, Size canvasSize) {
    if (!_canDraw) return;

    final point = _normalizePoint(details.localPosition, canvasSize);
    setState(() {
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
    if (!_canDraw || _currentStroke == null) return;

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
    if (!_canDraw || _currentStroke == null) return;

    setState(() {
      _strokes.add(_currentStroke!);
      _currentStroke = null;
      _redoStack.clear();
    });
    _scheduleSendProject();
  }

  void _clearCanvas() {
    if (!_canDraw) return;

    setState(() {
      _strokes.clear();
      _redoStack.clear();
    });
    _scheduleSendProject();
  }

  void _undoLast() {
    if (!_canDraw || _strokes.isEmpty) return;

    setState(() {
      _redoStack.add(_strokes.removeLast());
    });
    _scheduleSendProject();
  }

  void _redoLast() {
    if (!_canDraw || _redoStack.isEmpty) return;
    setState(() {
      _strokes.add(_redoStack.removeLast());
    });
    _scheduleSendProject();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _projectSubscription?.cancel();
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
                              tooltip: AppLocalizations.of(context)!
                                  .whiteboardClose,
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
                          icon:
                              const Icon(Icons.close, color: Colors.white70),
                          tooltip:
                              AppLocalizations.of(context)!.whiteboardClose,
                        ),
                        const SizedBox(width: 8),
                      ],

                      // Title
                      const Icon(Icons.draw,
                          color: Colors.white70, size: 20),
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
                          return _canDraw
                              ? GestureDetector(
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
            color:
                widget.studentDrawingEnabled ? Colors.green : Colors.white70,
            size: 16,
          ),
          const SizedBox(width: 6),
          Text(
            widget.studentDrawingEnabled
                ? AppLocalizations.of(context)!.whiteboardStudentsCanDraw
                : AppLocalizations.of(context)!.whiteboardViewOnly,
            style: TextStyle(
              color: widget.studentDrawingEnabled ? Colors.green : Colors.white70,
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
            const Icon(Icons.arrow_drop_down,
                color: Colors.white70, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildUndoButton() {
    return IconButton(
      onPressed: _strokes.isEmpty ? null : _undoLast,
      icon: Icon(
        Icons.undo,
        color: _strokes.isEmpty ? Colors.white24 : Colors.white70,
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
    return IconButton(
      onPressed: _strokes.isEmpty ? null : _clearCanvas,
      icon: Icon(
        Icons.delete_outline,
        color: _strokes.isEmpty ? Colors.white24 : Colors.white70,
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
          onTap: () => setState(() => _tool = tool),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: selected ? Colors.white.withValues(alpha: 0.18) : Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selected ? Colors.white54 : Colors.white12,
              ),
            ),
            child: Tooltip(
              message: tooltip,
              child: Icon(icon, size: 18, color: selected ? Colors.white : Colors.white70),
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
    ];
  }
}
