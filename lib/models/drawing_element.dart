import 'package:flutter/material.dart';
import 'dart:math' as math;

/// 画板元素类型枚举
enum ElementType {
  select,    // 选择工具
  rectangle,
  circle,
  line,
}

/// 画板元素模型类
class DrawingElement {
  final String id;
  final Offset position;
  final Size size;
  final ElementType type;
  final Color color;
  final double strokeWidth;
  final bool isSelected;

  const DrawingElement({
    required this.id,
    required this.position,
    required this.size,
    required this.type,
    this.color = Colors.blue,
    this.strokeWidth = 2.0,
    this.isSelected = false,
  });

  /// 创建副本并修改指定属性
  DrawingElement copyWith({
    String? id,
    Offset? position,
    Size? size,
    ElementType? type,
    Color? color,
    double? strokeWidth,
    bool? isSelected,
  }) {
    return DrawingElement(
      id: id ?? this.id,
      position: position ?? this.position,
      size: size ?? this.size,
      type: type ?? this.type,
      color: color ?? this.color,
      strokeWidth: strokeWidth ?? this.strokeWidth,
      isSelected: isSelected ?? this.isSelected,
    );
  }

  /// 获取元素的边界矩形
  Rect get bounds {
    return Rect.fromLTWH(
      position.dx,
      position.dy,
      size.width,
      size.height,
    );
  }

  /// 获取元素中心点
  Offset get center {
    return Offset(
      position.dx + size.width / 2,
      position.dy + size.height / 2,
    );
  }

  /// 获取右下角缩放控制点位置
  Offset get resizeHandle {
    return Offset(
      position.dx + size.width,
      position.dy + size.height,
    );
  }

  /// 获取缩放控制点的矩形区域（用于点击检测）
  Rect get resizeHandleRect {
    const handleSize = 20.0; // 扩大触发热区，提高缩放点灵敏度
    final handleCenter = resizeHandle;
    return Rect.fromCenter(
      center: handleCenter,
      width: handleSize,
      height: handleSize,
    );
  }

  /// 检查指定点是否在缩放控制点内
  bool isPointInResizeHandle(Offset point) {
    return resizeHandleRect.contains(point);
  }

  /// 以左上角为原点进行缩放，返回新的元素
  DrawingElement scaleFromTopLeft(Offset newBottomRight) {
    // 计算新的宽度和高度
    final newWidth = math.max(10.0, newBottomRight.dx - position.dx); // 最小宽度10px
    final newHeight = math.max(10.0, newBottomRight.dy - position.dy); // 最小高度10px
    
    return copyWith(
      size: Size(newWidth, newHeight),
    );
  }

  /// 根据鼠标位置进行缩放（保持比例可选）
  DrawingElement resizeToPoint(Offset mousePosition, {bool maintainAspectRatio = false}) {
    if (maintainAspectRatio) {
      // 保持宽高比缩放
      final originalAspectRatio = size.width / size.height;
      final deltaX = mousePosition.dx - position.dx;
      final deltaY = mousePosition.dy - position.dy;
      
      // 根据较大的变化量来确定新尺寸
      final newWidth = math.max(10.0, deltaX);
      final newHeight = math.max(10.0, newWidth / originalAspectRatio);
      
      // 如果高度变化更大，则以高度为准
      if (deltaY > newHeight) {
        final adjustedHeight = math.max(10.0, deltaY);
        final adjustedWidth = math.max(10.0, adjustedHeight * originalAspectRatio);
        return copyWith(size: Size(adjustedWidth, adjustedHeight));
      }
      
      return copyWith(size: Size(newWidth, newHeight));
    } else {
      // 自由缩放
      return scaleFromTopLeft(mousePosition);
    }
  }

  /// 检查指定点是否在元素内
  bool containsPoint(Offset point) {
    switch (type) {
      case ElementType.select:
        return false; // 选择工具不是实际元素，不参与碰撞检测
      case ElementType.rectangle:
        return bounds.contains(point);
      case ElementType.circle:
        final centerPoint = center;
        final radius = math.min(size.width, size.height) / 2;
        final distance = math.sqrt(
          math.pow(point.dx - centerPoint.dx, 2) +
          math.pow(point.dy - centerPoint.dy, 2),
        );
        return distance <= radius;
      case ElementType.line:
        // 简化的线条碰撞检测，检查点是否在线条附近
        final lineStart = position;
        final lineEnd = Offset(position.dx + size.width, position.dy + size.height);
        final distanceToLine = _distanceToLineSegment(point, lineStart, lineEnd);
        return distanceToLine <= strokeWidth + 5; // 5像素的容错范围
    }
  }

  /// 获取吸附点列表（用于吸附线功能）
  List<Offset> getSnapPoints() {
    final snapPoints = <Offset>[];
    
    switch (type) {
      case ElementType.select:
        // 选择工具不是实际元素，不提供吸附点
        break;
      case ElementType.rectangle:
        // 矩形的8个吸附点：4个角点 + 4个边中点
        snapPoints.addAll([
          position, // 左上角
          Offset(position.dx + size.width, position.dy), // 右上角
          Offset(position.dx, position.dy + size.height), // 左下角
          Offset(position.dx + size.width, position.dy + size.height), // 右下角
          Offset(position.dx + size.width / 2, position.dy), // 上边中点
          Offset(position.dx + size.width / 2, position.dy + size.height), // 下边中点
          Offset(position.dx, position.dy + size.height / 2), // 左边中点
          Offset(position.dx + size.width, position.dy + size.height / 2), // 右边中点
        ]);
        break;
      case ElementType.circle:
        // 圆形的5个吸附点：中心点 + 4个方向点
        final centerPoint = center;
        final radius = math.min(size.width, size.height) / 2;
        snapPoints.addAll([
          centerPoint, // 中心点
          Offset(centerPoint.dx, centerPoint.dy - radius), // 上
          Offset(centerPoint.dx, centerPoint.dy + radius), // 下
          Offset(centerPoint.dx - radius, centerPoint.dy), // 左
          Offset(centerPoint.dx + radius, centerPoint.dy), // 右
        ]);
        break;
      case ElementType.line:
        // 线条的3个吸附点：起点、终点、中点
        final lineStart = position;
        final lineEnd = Offset(position.dx + size.width, position.dy + size.height);
        final midPoint = Offset(
          (lineStart.dx + lineEnd.dx) / 2,
          (lineStart.dy + lineEnd.dy) / 2,
        );
        snapPoints.addAll([lineStart, lineEnd, midPoint]);
        break;
    }
    
    return snapPoints;
  }

  /// 计算点到线段的距离
  double _distanceToLineSegment(Offset point, Offset lineStart, Offset lineEnd) {
    final A = point.dx - lineStart.dx;
    final B = point.dy - lineStart.dy;
    final C = lineEnd.dx - lineStart.dx;
    final D = lineEnd.dy - lineStart.dy;

    final dot = A * C + B * D;
    final lenSq = C * C + D * D;
    
    if (lenSq == 0) {
      // 线段长度为0，返回点到起点的距离
      return math.sqrt(A * A + B * B);
    }
    
    final param = dot / lenSq;
    
    double xx, yy;
    if (param < 0) {
      xx = lineStart.dx;
      yy = lineStart.dy;
    } else if (param > 1) {
      xx = lineEnd.dx;
      yy = lineEnd.dy;
    } else {
      xx = lineStart.dx + param * C;
      yy = lineStart.dy + param * D;
    }
    
    final dx = point.dx - xx;
    final dy = point.dy - yy;
    return math.sqrt(dx * dx + dy * dy);
  }

  /// 生成唯一ID
  static String generateId() {
    return DateTime.now().millisecondsSinceEpoch.toString() + 
           math.Random().nextInt(1000).toString();
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DrawingElement && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'DrawingElement(id: $id, position: $position, size: $size, type: $type)';
  }
}