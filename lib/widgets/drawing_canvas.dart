import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/drawing_element.dart';
import '../services/adsorption_manager.dart';
import '../services/gesture_manager.dart';
import 'dart:math' as math;

/// 画板画布组件
class DrawingCanvas extends StatefulWidget {
  final List<DrawingElement> elements;
  final DrawingElement? selectedElement;
  final Function(Offset) onTap;
  final Function(Offset) onPanStart;
  final Function(Offset) onPanUpdate;
  final Function() onPanEnd;
  final Function(Offset)? isPointInResizeHandle;

  const DrawingCanvas({
    super.key,
    required this.elements,
    this.selectedElement,
    required this.onTap,
    required this.onPanStart,
    required this.onPanUpdate,
    required this.onPanEnd,
    this.isPointInResizeHandle,
  });

  @override
  State<DrawingCanvas> createState() => _DrawingCanvasState();
}

class _DrawingCanvasState extends State<DrawingCanvas> {
  SystemMouseCursor _currentCursor = SystemMouseCursors.basic;
  final GestureManager _gestureManager = GestureManager();

  /// 检查是否在缩放控制点上
  bool _isInResizeHandle(Offset position) {
    if (widget.selectedElement == null) return false;
    return widget.isPointInResizeHandle?.call(position) ?? false;
  }

  /// 检查是否在右下角热区
  bool _isInBottomRightHotZone(Offset position, Size size) {
    const hotZoneSize = 20.0;
    return position.dx > size.width - hotZoneSize && 
           position.dy > size.height - hotZoneSize;
  }

  /// 根据位置更新光标
  void _updateCursor(Offset position, Size size) {
    SystemMouseCursor newCursor;
    
    final isInResize = _isInResizeHandle(position);
    final isInHotZone = _isInBottomRightHotZone(position, size);
    
    if (isInResize) {
      // 在缩放控制点上显示双箭头光标，明确指示缩放功能
      newCursor = SystemMouseCursors.resizeDownRight;
      print('光标切换到缩放模式 - 缩放控制点');
    } else if (isInHotZone) {
      // 右下角热区也显示双箭头光标
      newCursor = SystemMouseCursors.resizeDownRight;
      print('光标切换到缩放模式 - 右下角热区');
    } else {
      newCursor = SystemMouseCursors.basic;
    }
    
    if (_currentCursor != newCursor) {
      setState(() {
        _currentCursor = newCursor;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _configureGestureManager();
  }

  /// 配置手势管理器的回调
  void _configureGestureManager() {
    _gestureManager.configureCallbacks(
      onTap: widget.onTap,
      onDragStart: (position, element) => widget.onPanStart(position),
      onDragUpdate: widget.onPanUpdate,
      onDragEnd: widget.onPanEnd,
      onResizeStart: (position, element) => widget.onPanStart(position),
      onResizeUpdate: widget.onPanUpdate,
      onResizeEnd: widget.onPanEnd,
      onCreateStart: (position) => widget.onPanStart(position),
      onCreateUpdate: widget.onPanUpdate,
      onCreateEnd: widget.onPanEnd,
    );
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: _currentCursor,
      onHover: (event) {
        final renderBox = context.findRenderObject() as RenderBox?;
        if (renderBox != null) {
          _updateCursor(event.localPosition, renderBox.size);
        }
      },
      child: GestureDetector(
        onTapDown: (details) {
          _gestureManager.handleTapDown(
            details.localPosition,
            widget.elements,
            widget.selectedElement,
            widget.isPointInResizeHandle ?? (position) => false,
          );
        },
        onTap: () {
          // onTap在onTapDown之后触发，GestureDetector.onTap不提供details
        },
        onPanStart: (details) {
          _gestureManager.handlePanStart(details.localPosition);
        },
        onPanUpdate: (details) {
          _gestureManager.handlePanUpdate(details.localPosition);
        },
        onPanEnd: (_) {
          _gestureManager.handlePanEnd();
        },
        child: CustomPaint(
          painter: DrawingCanvasPainter(
            elements: widget.elements,
            selectedElement: widget.selectedElement,
          ),
          size: Size.infinite,
        ),
      ),
    );
  }
}

/// 画布绘制器
class DrawingCanvasPainter extends CustomPainter {
  final List<DrawingElement> elements;
  final DrawingElement? selectedElement;

  DrawingCanvasPainter({
    required this.elements,
    this.selectedElement,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 绘制所有元素
    for (final element in elements) {
      _drawElement(canvas, element);
    }

    // 绘制选中元素的边框
    if (selectedElement != null) {
      _drawSelectionBorder(canvas, selectedElement!);
    }

    // 绘制吸附线
    if (selectedElement != null) {
      _drawSnapLines(canvas, size);
    }
  }

  /// 绘制单个元素
  void _drawElement(Canvas canvas, DrawingElement element) {
    final paint = Paint()
      ..color = element.color
      ..strokeWidth = element.strokeWidth
      ..style = PaintingStyle.stroke;

    switch (element.type) {
      case ElementType.select:
        // 选择工具不绘制任何内容
        break;
      case ElementType.rectangle:
        canvas.drawRect(element.bounds, paint);
        break;
      case ElementType.circle:
        final center = element.center;
        final radius = math.min(element.size.width, element.size.height) / 2;
        canvas.drawCircle(center, radius, paint);
        break;
      case ElementType.line:
        final start = element.position;
        final end = Offset(
          element.position.dx + element.size.width,
          element.position.dy + element.size.height,
        );
        canvas.drawLine(start, end, paint);
        break;
    }
  }

  /// 绘制选中边框
  void _drawSelectionBorder(Canvas canvas, DrawingElement element) {
    final paint = Paint()
      ..color = Colors.blue
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    // 绘制虚线边框
    final rect = element.bounds.inflate(5);
    _drawDashedRect(canvas, rect, paint);

    // 绘制普通控制点
    final controlPointPaint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.fill;

    final normalControlPoints = [
      rect.topLeft,
      rect.topRight,
      rect.bottomLeft,
      Offset(rect.center.dx, rect.top),
      Offset(rect.center.dx, rect.bottom),
      Offset(rect.left, rect.center.dy),
      Offset(rect.right, rect.center.dy),
    ];

    for (final point in normalControlPoints) {
      canvas.drawCircle(point, 3, controlPointPaint);
    }

    // 绘制右下角缩放控制点（特殊样式）
    final resizeHandlePaint = Paint()
      ..color = Colors.orange
      ..style = PaintingStyle.fill;
    
    final resizeHandleBorderPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    // 绘制右下角缩放控制点
    canvas.drawCircle(rect.bottomRight, 4, resizeHandlePaint);
    canvas.drawCircle(rect.bottomRight, 4, resizeHandleBorderPaint);
  }

  /// 绘制吸附线
  /// 只有当元素进入吸附阈值范围内时才显示吸附线
  void _drawSnapLines(Canvas canvas, Size canvasSize) {
    if (selectedElement == null) return;

    // 使用新的可见吸附线方法
    final visibleSnapLines = AdsorptionManager.getVisibleSnapLines(
      elements,
      selectedElement,
    );

    if (visibleSnapLines.isEmpty) return;

    final snapLinePaint = Paint()
      ..color = Colors.red.withOpacity(0.8)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    for (final snapLine in visibleSnapLines) {
      Offset start = snapLine.start;
      Offset end = snapLine.end;

      // 调整线条长度以适应画布，但让线条更贴近元素
      if (snapLine.type == SnapType.vertical) {
        // 计算垂直线的合理范围
        double minY = double.infinity;
        double maxY = double.negativeInfinity;
        
        for (final element in elements) {
          final bounds = element.bounds;
          minY = math.min(minY, bounds.top - 20);
          maxY = math.max(maxY, bounds.bottom + 20);
        }
        
        start = Offset(snapLine.start.dx, math.max(0, minY));
        end = Offset(snapLine.start.dx, math.min(canvasSize.height, maxY));
      } else if (snapLine.type == SnapType.horizontal) {
        // 计算水平线的合理范围
        double minX = double.infinity;
        double maxX = double.negativeInfinity;
        
        for (final element in elements) {
          final bounds = element.bounds;
          minX = math.min(minX, bounds.left - 20);
          maxX = math.max(maxX, bounds.right + 20);
        }
        
        start = Offset(math.max(0, minX), snapLine.start.dy);
        end = Offset(math.min(canvasSize.width, maxX), snapLine.start.dy);
      }

      _drawDashedLine(canvas, start, end, snapLinePaint);
    }
  }

  /// 绘制虚线矩形
  void _drawDashedRect(Canvas canvas, Rect rect, Paint paint) {
    final path = Path()
      ..addRect(rect);
    
    _drawDashedPath(canvas, path, paint);
  }

  /// 绘制虚线
  void _drawDashedLine(Canvas canvas, Offset start, Offset end, Paint paint) {
    const dashWidth = 5.0;
    const dashSpace = 3.0;
    
    final distance = (end - start).distance;
    final dashCount = (distance / (dashWidth + dashSpace)).floor();
    
    if (dashCount == 0) return;
    
    final direction = (end - start) / distance;
    
    for (int i = 0; i < dashCount; i++) {
      final dashStart = start + direction * (i * (dashWidth + dashSpace));
      final dashEnd = dashStart + direction * dashWidth;
      canvas.drawLine(dashStart, dashEnd, paint);
    }
  }

  /// 绘制虚线路径
  void _drawDashedPath(Canvas canvas, Path path, Paint paint) {
    const dashWidth = 5.0;
    const dashSpace = 3.0;
    
    final metrics = path.computeMetrics();
    for (final metric in metrics) {
      double distance = 0.0;
      bool draw = true;
      
      while (distance < metric.length) {
        final length = draw ? dashWidth : dashSpace;
        final end = math.min(distance + length, metric.length);
        
        if (draw) {
          final extractPath = metric.extractPath(distance, end);
          canvas.drawPath(extractPath, paint);
        }
        
        distance = end;
        draw = !draw;
      }
    }
  }

  @override
  bool shouldRepaint(covariant DrawingCanvasPainter oldDelegate) {
    return elements != oldDelegate.elements ||
           selectedElement != oldDelegate.selectedElement;
  }
}