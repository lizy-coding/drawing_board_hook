import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../models/drawing_element.dart';

/// 吸附点类型（按边分类）
enum SnapEdgeType {
  top,      // 顶边
  bottom,   // 底边
  left,     // 左边
  right,    // 右边
  centerH,  // 水平中心线
  centerV,  // 垂直中心线
}

/// 吸附方向
enum SnapDirection { horizontal, vertical }

/// 结构化吸附点
class SnapPoint {
  final Offset position;
  final SnapEdgeType edgeType;
  final SnapDirection direction;

  const SnapPoint({
    required this.position,
    required this.edgeType,
    required this.direction,
  });
}

/// 元素的所有边信息
class ElementEdges {
  final SnapPoint? top;
  final SnapPoint? bottom;
  final SnapPoint? left;
  final SnapPoint? right;
  final SnapPoint? centerH;
  final SnapPoint? centerV;

  const ElementEdges({
    this.top,
    this.bottom,
    this.left,
    this.right,
    this.centerH,
    this.centerV,
  });
}

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
  static const double unlockThreshold = 20.0; // 解锁拖动阈值

  // 动画和过渡配置
  static const double snapStrengthFactor = 0.3; // 吸附强度因子
  static const double dampingFactor = 0.8; // 正常阻尼因子
  static const double lockedDampingFactor = 0.95; // 锁定状态强阻尼
  static const double unlockingDampingFactor = 0.7; // 解锁过程中等阻尼
  static const int visualFeedbackDelayMs = 200; // 视觉反馈延迟

  // 状态管理
  static bool _isSnapped = false;
  static bool _isLocked = false; // 吸附锁定状态
  static Timer? _visualTimer;
  static List<SnapLine> _currentSnapLines = [];
  static Offset? _lastPosition;
  static Offset? _lockedPosition; // 锁定时的吸附位置
  static Offset _dragAccumulation = Offset.zero; // 拖动累积偏移
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

  /// 计算吸附结果，包含位置、吸附线和吸附强度（优化版：只检测相同边对齐）
  static SnapResult calculateSnapResult(
    List<DrawingElement> elements,
    DrawingElement currentElement,
  ) {
    final activeSnapLines = <SnapLine>[];
    bool isSnapped = false;
    double maxSnapStrength = 0.0;

    // 获取当前元素的边信息
    final currentEdges = _getElementEdges(currentElement);
    
    for (final element in elements) {
      if (element.id == currentElement.id) continue;
      
      // 获取目标元素的边信息
      final targetEdges = _getElementEdges(element);
      
      // 严格相同边对齐：只比较相同类型的边
      _compareAndAddSnapLines(currentEdges.top, targetEdges.top, activeSnapLines);
      _compareAndAddSnapLines(currentEdges.bottom, targetEdges.bottom, activeSnapLines);
      _compareAndAddSnapLines(currentEdges.left, targetEdges.left, activeSnapLines);
      _compareAndAddSnapLines(currentEdges.right, targetEdges.right, activeSnapLines);
      _compareAndAddSnapLines(currentEdges.centerH, targetEdges.centerH, activeSnapLines);
      _compareAndAddSnapLines(currentEdges.centerV, targetEdges.centerV, activeSnapLines);
    }
    
    // 计算最大吸附强度
    for (final snapLine in activeSnapLines) {
      if (snapLine.isActive) {
        isSnapped = true;
        // 基于透明度推算吸附强度
        maxSnapStrength = max(maxSnapStrength, snapLine.opacity);
      }
    }

    return SnapResult(
      position: currentElement.position,
      activeSnapLines: activeSnapLines.where((line) => line.isActive).toList(),
      isSnapped: isSnapped,
      snapStrength: maxSnapStrength,
    );
  }

  /// 获取元素的边信息
  static ElementEdges _getElementEdges(DrawingElement element) {
    final bounds = element.bounds;
    
    return ElementEdges(
      top: SnapPoint(
        position: Offset(bounds.center.dx, bounds.top),
        edgeType: SnapEdgeType.top,
        direction: SnapDirection.horizontal,
      ),
      bottom: SnapPoint(
        position: Offset(bounds.center.dx, bounds.bottom),
        edgeType: SnapEdgeType.bottom,
        direction: SnapDirection.horizontal,
      ),
      left: SnapPoint(
        position: Offset(bounds.left, bounds.center.dy),
        edgeType: SnapEdgeType.left,
        direction: SnapDirection.vertical,
      ),
      right: SnapPoint(
        position: Offset(bounds.right, bounds.center.dy),
        edgeType: SnapEdgeType.right,
        direction: SnapDirection.vertical,
      ),
      centerH: SnapPoint(
        position: Offset(bounds.center.dx, bounds.center.dy),
        edgeType: SnapEdgeType.centerH,
        direction: SnapDirection.horizontal,
      ),
      centerV: SnapPoint(
        position: Offset(bounds.center.dx, bounds.center.dy),
        edgeType: SnapEdgeType.centerV,
        direction: SnapDirection.vertical,
      ),
    );
  }

  /// 检查两个边类型是否兼容（可以相互吸附）
  /// 严格相同边对齐：只有相同类型的边才能相互吸附
  static bool _areEdgesCompatible(SnapEdgeType current, SnapEdgeType target) {
    return current == target;
  }

  /// 比较两个兼容的边并添加吸附线
  /// 比较两个兼容的边并添加吸附线
  static void _compareAndAddSnapLines(
    SnapPoint? currentEdge,
    SnapPoint? targetEdge,
    List<SnapLine> snapLines,
  ) {
    if (currentEdge == null || targetEdge == null) return;
    if (!_areEdgesCompatible(currentEdge.edgeType, targetEdge.edgeType)) return;
    
    final distance = currentEdge.direction == SnapDirection.horizontal
        ? (currentEdge.position.dy - targetEdge.position.dy).abs()
        : (currentEdge.position.dx - targetEdge.position.dx).abs();
    
    if (distance >= visualThreshold) return;
    
    // 创建吸附线
    final snapLine = _createSnapLine(targetEdge, distance);
    if (snapLine != null) {
      snapLines.add(snapLine);
    }
  }

  /// 创建吸附线
  static SnapLine? _createSnapLine(SnapPoint targetEdge, double distance) {
    final isActive = distance < snapThreshold;
    final opacity = _calculateOpacity(distance);
    
    if (targetEdge.direction == SnapDirection.vertical) {
      // 垂直对齐线
      return SnapLine(
        start: Offset(targetEdge.position.dx, 0),
        end: Offset(targetEdge.position.dx, double.infinity),
        type: SnapType.vertical,
        opacity: opacity,
        isActive: isActive,
      );
    } else {
      // 水平对齐线
      return SnapLine(
        start: Offset(0, targetEdge.position.dy),
        end: Offset(double.infinity, targetEdge.position.dy),
        type: SnapType.horizontal,
        opacity: opacity,
        isActive: isActive,
      );
    }
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

  /// 渐进式吸附位置计算（含锁定/解锁机制）
  static Offset snapPosition(
    Offset position,
    List<DrawingElement> elements,
    DrawingElement currentElement,
  ) {
    // 创建临时元素用于计算
    final tempElement = currentElement.copyWith(position: position);
    final snapResult = calculateSnapResult(elements, tempElement);

    // 如果当前处于锁定状态，检查是否需要解锁
    if (_isLocked && _lockedPosition != null) {
      final dragDelta = position - _lastPosition!;
      _dragAccumulation += dragDelta;
      
      // 计算累积拖动距离
      final accumulatedDistance = _dragAccumulation.distance;
      
      if (accumulatedDistance > unlockThreshold) {
        // 解锁吸附
        _unlock();
      } else {
        // 仍处于锁定状态，使用强阻尼返回锁定位置
        final result = _applyLockedDamping(position, _lockedPosition!);
        _lastPosition = result;
        return result;
      }
    }

    // 未锁定或已解锁，进行正常吸附计算
    if (!snapResult.isSnapped) {
      _lastPosition = position;
      _currentSnapStrength = 0.0;
      _isSnapped = false;
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

    final snappedPosition = Offset(newX, newY);
    
    // 检查是否需要锁定吸附
    if (_shouldLock(position, snappedPosition, snapStrength)) {
      _lock(snappedPosition);
    }

    // 应用适当的阻尼
    Offset result;
    if (_lastPosition != null) {
      final dampingToUse = _isLocked ? lockedDampingFactor : dampingFactor;
      result = _applyDamping(snappedPosition, _lastPosition!, dampingToUse);
    } else {
      result = snappedPosition;
    }

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

  /// 应用阻尼减少晃动（支持不同阻尼系数）
  static Offset _applyDamping(Offset current, Offset last, [double? customDamping]) {
    final damping = customDamping ?? dampingFactor;
    final dx = current.dx - last.dx;
    final dy = current.dy - last.dy;

    // 如果移动距离很小，应用更强的阻尼
    if (dx.abs() < 2.0 && dy.abs() < 2.0) {
      return Offset(
        last.dx + dx * damping * 0.5,
        last.dy + dy * damping * 0.5,
      );
    }

    return Offset(
      last.dx + dx * damping,
      last.dy + dy * damping,
    );
  }

  /// 应用锁定状态的强阻尼
  static Offset _applyLockedDamping(Offset current, Offset locked) {
    final dx = current.dx - locked.dx;
    final dy = current.dy - locked.dy;
    
    // 锁定状态下使用极强的阻尼，让元素几乎不动
    return Offset(
      locked.dx + dx * (1.0 - lockedDampingFactor),
      locked.dy + dy * (1.0 - lockedDampingFactor),
    );
  }

  /// 判断是否应该锁定吸附
  static bool _shouldLock(Offset originalPos, Offset snappedPos, double snapStrength) {
    if (_isLocked) return false; // 已经锁定，不重复锁定
    
    // 当吸附强度足够高且位置偏移较小时锁定
    final offset = (originalPos - snappedPos).distance;
    return snapStrength > 0.8 && offset < 5.0;
  }

  /// 锁定吸附
  static void _lock(Offset position) {
    _isLocked = true;
    _lockedPosition = position;
    _dragAccumulation = Offset.zero;
  }

  /// 解锁吸附
  static void _unlock() {
    _isLocked = false;
    _lockedPosition = null;
    _dragAccumulation = Offset.zero;
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
    _isLocked = false;
    _lastPosition = null;
    _lockedPosition = null;
    _dragAccumulation = Offset.zero;
    _currentSnapStrength = 0.0;
  }

  /// 开始新的拖拽操作时重置锁定状态
  static void startDrag() {
    _unlock();
  }

  /// 获取当前锁定状态（用于调试）
  static bool get isLocked => _isLocked;
}
