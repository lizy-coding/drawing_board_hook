import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../models/drawing_element.dart';

class SnapLine {
  final Offset start;
  final Offset end;
  final SnapType type;
  final double opacity;
  final bool isActive;

  const SnapLine({
    required this.start,
    required this.end,
    required this.type,
    this.opacity = 1.0,
    this.isActive = false,
  });

  SnapLine copyWith({
    Offset? start,
    Offset? end,
    SnapType? type,
    double? opacity,
    bool? isActive,
  }) {
    return SnapLine(
      start: start ?? this.start,
      end: end ?? this.end,
      type: type ?? this.type,
      opacity: opacity ?? this.opacity,
      isActive: isActive ?? this.isActive,
    );
  }
}

enum SnapType {
  horizontal,
  vertical,
  center,
}

class SnapResult {
  final Offset position;
  final List<SnapLine> activeSnapLines;
  final bool isSnapped;
  final double snapStrength; // 0.0 to 1.0

  const SnapResult({
    required this.position,
    required this.activeSnapLines,
    required this.isSnapped,
    this.snapStrength = 0.0,
  });
}

class AdsorptionManager {
  // 吸附阈值配置
  static const double snapThreshold = 25.0;
  static const double magneticThreshold = 15.0; // 磁性吸附阈值
  static const double visualThreshold = 35.0; // 视觉引导线显示阈值

  // 动画和过渡配置
  static const double snapStrengthFactor = 0.3; // 吸附强度因子
  static const double dampingFactor = 0.8; // 阻尼因子，防止晃动
  static const int visualFeedbackDelayMs = 200; // 视觉反馈延迟

  // 状态管理
  static bool _isSnapped = false;
  static Timer? _visualTimer;
  static List<SnapLine> _currentSnapLines = [];
  static Offset? _lastPosition;
  static double _currentSnapStrength = 0.0;

  /// 获取带视觉反馈的吸附线
  static List<SnapLine> getVisibleSnapLines(
    List<DrawingElement> elements,
    DrawingElement? currentElement,
  ) {
    if (currentElement == null) return [];

    final snapResult = calculateSnapResult(elements, currentElement);
    _currentSnapLines = snapResult.activeSnapLines;

    // 启动视觉反馈延迟隐藏
    if (snapResult.isSnapped) {
      _visualTimer?.cancel();
      _visualTimer =
          Timer(const Duration(milliseconds: visualFeedbackDelayMs), () {
        if (!_isSnapped) {
          _currentSnapLines.clear();
        }
      });
    }

    return _currentSnapLines;
  }

  /// 计算吸附结果，包含位置、吸附线和吸附强度
  static SnapResult calculateSnapResult(
    List<DrawingElement> elements,
    DrawingElement currentElement,
  ) {
    final snapLines = <SnapLine>[];
    final activeSnapLines = <SnapLine>[];
    final currentSnapPoints = currentElement.getSnapPoints();
    bool isSnapped = false;
    double maxSnapStrength = 0.0;

    for (final element in elements) {
      if (element.id == currentElement.id) continue;

      final elementSnapPoints = element.getSnapPoints();

      for (final currentPoint in currentSnapPoints) {
        for (final elementPoint in elementSnapPoints) {
          // 垂直对齐检测
          final xDistance = (currentPoint.dx - elementPoint.dx).abs();
          if (xDistance < visualThreshold) {
            final snapLine = SnapLine(
              start: Offset(elementPoint.dx, 0),
              end: Offset(elementPoint.dx, double.infinity),
              type: SnapType.vertical,
              opacity: _calculateOpacity(xDistance),
              isActive: xDistance < snapThreshold,
            );
            snapLines.add(snapLine);

            if (xDistance < snapThreshold) {
              activeSnapLines.add(snapLine);
              isSnapped = true;
              maxSnapStrength =
                  max(maxSnapStrength, 1.0 - (xDistance / snapThreshold));
            }
          }

          // 水平对齐检测
          final yDistance = (currentPoint.dy - elementPoint.dy).abs();
          if (yDistance < visualThreshold) {
            final snapLine = SnapLine(
              start: Offset(0, elementPoint.dy),
              end: Offset(double.infinity, elementPoint.dy),
              type: SnapType.horizontal,
              opacity: _calculateOpacity(yDistance),
              isActive: yDistance < snapThreshold,
            );
            snapLines.add(snapLine);

            if (yDistance < snapThreshold) {
              activeSnapLines.add(snapLine);
              isSnapped = true;
              maxSnapStrength =
                  max(maxSnapStrength, 1.0 - (yDistance / snapThreshold));
            }
          }
        }
      }
    }

    return SnapResult(
      position: currentElement.position,
      activeSnapLines: activeSnapLines,
      isSnapped: isSnapped,
      snapStrength: maxSnapStrength,
    );
  }

  /// 计算引导线透明度
  static double _calculateOpacity(double distance) {
    if (distance < magneticThreshold) return 1.0;
    if (distance > visualThreshold) return 0.0;
    return 1.0 -
        ((distance - magneticThreshold) /
            (visualThreshold - magneticThreshold));
  }

  static List<SnapLine> calculateSnapLines(
    List<DrawingElement> elements,
    DrawingElement? currentElement,
  ) {
    if (currentElement == null) return [];
    return calculateSnapResult(elements, currentElement).activeSnapLines;
  }

  /// 渐进式吸附位置计算
  static Offset snapPosition(
    Offset position,
    List<DrawingElement> elements,
    DrawingElement currentElement,
  ) {
    // 创建临时元素用于计算
    final tempElement = currentElement.copyWith(position: position);
    final snapResult = calculateSnapResult(elements, tempElement);

    if (!snapResult.isSnapped) {
      _lastPosition = position;
      _currentSnapStrength = 0.0;
      return position;
    }

    double newX = position.dx;
    double newY = position.dy;
    double snapStrength = snapResult.snapStrength;

    // 查找最近的吸附点
    double minXDistance = double.infinity;
    double minYDistance = double.infinity;
    double snapX = position.dx;
    double snapY = position.dy;

    for (final snapLine in snapResult.activeSnapLines) {
      if (snapLine.type == SnapType.vertical) {
        final distance = (position.dx - snapLine.start.dx).abs();
        if (distance < minXDistance) {
          minXDistance = distance;
          snapX = snapLine.start.dx;
        }
      } else if (snapLine.type == SnapType.horizontal) {
        final distance = (position.dy - snapLine.start.dy).abs();
        if (distance < minYDistance) {
          minYDistance = distance;
          snapY = snapLine.start.dy;
        }
      }
    }

    // 渐进式吸附：根据距离和历史位置计算平滑过渡
    if (minXDistance < snapThreshold) {
      final snapFactor = _calculateSnapFactor(minXDistance, snapStrength);
      newX = _lerp(position.dx, snapX, snapFactor);
    }

    if (minYDistance < snapThreshold) {
      final snapFactor = _calculateSnapFactor(minYDistance, snapStrength);
      newY = _lerp(position.dy, snapY, snapFactor);
    }

    // 应用阻尼以减少晃动
    if (_lastPosition != null) {
      final dampedPosition = _applyDamping(Offset(newX, newY), _lastPosition!);
      newX = dampedPosition.dx;
      newY = dampedPosition.dy;
    }

    final result = Offset(newX, newY);
    _lastPosition = result;
    _currentSnapStrength = snapStrength;
    _isSnapped = snapResult.isSnapped;

    return result;
  }

  /// 计算吸附因子
  static double _calculateSnapFactor(double distance, double snapStrength) {
    if (distance < magneticThreshold) {
      return snapStrengthFactor + (snapStrength * 0.4); // 强吸附
    }
    return snapStrengthFactor * (1.0 - distance / snapThreshold); // 渐进吸附
  }

  /// 线性插值
  static double _lerp(double a, double b, double t) {
    return a + (b - a) * t.clamp(0.0, 1.0);
  }

  /// 应用阻尼减少晃动
  static Offset _applyDamping(Offset current, Offset last) {
    final dx = current.dx - last.dx;
    final dy = current.dy - last.dy;

    // 如果移动距离很小，应用更强的阻尼
    if (dx.abs() < 2.0 && dy.abs() < 2.0) {
      return Offset(
        last.dx + dx * dampingFactor * 0.5,
        last.dy + dy * dampingFactor * 0.5,
      );
    }

    return Offset(
      last.dx + dx * dampingFactor,
      last.dy + dy * dampingFactor,
    );
  }

  /// 应用磁性效果（增强的渐进式吸附体验）
  static Offset applyMagneticEffect(
    Offset position,
    List<DrawingElement> elements,
    DrawingElement currentElement,
  ) {
    // 创建临时元素用于计算
    final tempElement = currentElement.copyWith(position: position);
    final snapResult = calculateSnapResult(elements, tempElement);
    
    if (!snapResult.isSnapped) {
      return position;
    }

    // 在磁性阈值内应用预吸附效果
    double newX = position.dx;
    double newY = position.dy;
    
    for (final snapLine in snapResult.activeSnapLines) {
      if (snapLine.type == SnapType.vertical) {
        final distance = (position.dx - snapLine.start.dx).abs();
        if (distance < magneticThreshold) {
          // 强磁性效果：快速吸附
          final magneticFactor = 1.0 - (distance / magneticThreshold);
          newX = _lerp(position.dx, snapLine.start.dx, magneticFactor * 0.8);
        } else if (distance < visualThreshold) {
          // 轻微磁性效果：提供引导感
          final guideFactor = 1.0 - (distance / visualThreshold);
          newX = _lerp(position.dx, snapLine.start.dx, guideFactor * 0.2);
        }
      } else if (snapLine.type == SnapType.horizontal) {
        final distance = (position.dy - snapLine.start.dy).abs();
        if (distance < magneticThreshold) {
          // 强磁性效果：快速吸附
          final magneticFactor = 1.0 - (distance / magneticThreshold);
          newY = _lerp(position.dy, snapLine.start.dy, magneticFactor * 0.8);
        } else if (distance < visualThreshold) {
          // 轻微磁性效果：提供引导感
          final guideFactor = 1.0 - (distance / visualThreshold);
          newY = _lerp(position.dy, snapLine.start.dy, guideFactor * 0.2);
        }
      }
    }

    // 应用平滑过渡以避免突兀的跳跃
    final result = Offset(newX, newY);
    return _lastPosition != null ? _applyDamping(result, _lastPosition!) : result;
  }

  /// 清理资源（在页面销毁时调用）
  static void dispose() {
    _visualTimer?.cancel();
    _visualTimer = null;
    _currentSnapLines.clear();
    _isSnapped = false;
    _lastPosition = null;
    _currentSnapStrength = 0.0;
  }
}
