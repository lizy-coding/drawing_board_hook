import 'package:flutter/material.dart';
import '../models/drawing_element.dart';

/// 手势类型枚举
enum GestureType {
  none,
  tap,
  drag,
  resize,
  create,
}

/// 手势状态
class GestureState {
  final GestureType type;
  final Offset startPosition;
  final DrawingElement? targetElement;
  final bool isActive;

  const GestureState({
    this.type = GestureType.none,
    required this.startPosition,
    this.targetElement,
    this.isActive = false,
  });

  GestureState copyWith({
    GestureType? type,
    Offset? startPosition,
    DrawingElement? targetElement,
    bool? isActive,
  }) {
    return GestureState(
      type: type ?? this.type,
      startPosition: startPosition ?? this.startPosition,
      targetElement: targetElement ?? this.targetElement,
      isActive: isActive ?? this.isActive,
    );
  }
}

/// 手势管理器 - 负责隔离和协调不同类型的手势
class GestureManager {
  GestureState _currentGesture = GestureState(startPosition: Offset.zero);
  
  // 手势回调
  Function(Offset)? onTapCallback;
  Function(Offset, DrawingElement?)? onDragStartCallback;
  Function(Offset)? onDragUpdateCallback;
  Function()? onDragEndCallback;
  Function(Offset, DrawingElement)? onResizeStartCallback;
  Function(Offset)? onResizeUpdateCallback;
  Function()? onResizeEndCallback;
  Function(Offset)? onCreateStartCallback;
  Function(Offset)? onCreateUpdateCallback;
  Function()? onCreateEndCallback;

  GestureState get currentGesture => _currentGesture;
  bool get hasActiveGesture => _currentGesture.isActive;
  
  /// 处理点击开始
  void handleTapDown(Offset position, List<DrawingElement> elements, 
      DrawingElement? selectedElement, Function(Offset) isPointInResizeHandle) {
    
    if (hasActiveGesture) return;
    
    // 优先级1: 检查缩放控制点
    if (selectedElement != null && isPointInResizeHandle(position)) {
      _startResizeGesture(position, selectedElement);
      return;
    }
    
    // 优先级2: 检查元素选择/拖拽
    final targetElement = _findElementAt(position, elements);
    if (targetElement != null) {
      // 记录为潜在拖拽，等待pan手势确认
      _prepareDragGesture(position, targetElement);
      return;
    }
    
    // 优先级3: 创建新元素
    _prepareCreateGesture(position);
  }
  
  /// 处理拖拽开始
  void handlePanStart(Offset position) {
    // 检查是否有准备状态的手势（不只是激活状态）
    if (_currentGesture.type == GestureType.none) return;
    
    switch (_currentGesture.type) {
      case GestureType.drag:
        _activateDragGesture(position);
        break;
      case GestureType.resize:
        _activateResizeGesture(position);
        break;
      case GestureType.create:
        _activateCreateGesture(position);
        break;
      default:
        break;
    }
  }
  
  /// 处理拖拽更新
  void handlePanUpdate(Offset position) {
    if (!hasActiveGesture) return;
    
    switch (_currentGesture.type) {
      case GestureType.drag:
        onDragUpdateCallback?.call(position);
        break;
      case GestureType.resize:
        onResizeUpdateCallback?.call(position);
        break;
      case GestureType.create:
        onCreateUpdateCallback?.call(position);
        break;
      default:
        break;
    }
  }
  
  /// 处理手势结束
  void handlePanEnd() {
    if (!hasActiveGesture) return;
    
    switch (_currentGesture.type) {
      case GestureType.drag:
        onDragEndCallback?.call();
        break;
      case GestureType.resize:
        onResizeEndCallback?.call();
        break;
      case GestureType.create:
        onCreateEndCallback?.call();
        break;
      default:
        break;
    }
    
    _resetGesture();
  }
  
  /// 处理点击（无拖拽的tap）
  void handleTap() {
    if (hasActiveGesture) return;
    
    // 处理拖拽手势的tap事件（选择元素）
    if (_currentGesture.type == GestureType.drag) {
      onTapCallback?.call(_currentGesture.startPosition);
    }
    // 处理创建手势的tap事件
    else if (_currentGesture.type == GestureType.create) {
      onTapCallback?.call(_currentGesture.startPosition);
    }
    // 处理普通tap事件
    else if (_currentGesture.type == GestureType.none) {
      onTapCallback?.call(_currentGesture.startPosition);
    }
    
    _resetGesture();
  }
  
  /// 准备拖拽手势
  void _prepareDragGesture(Offset position, DrawingElement element) {
    _currentGesture = GestureState(
      type: GestureType.drag,
      startPosition: position,
      targetElement: element,
      isActive: false,
    );
  }
  
  /// 激活拖拽手势
  void _activateDragGesture(Offset position) {
    _currentGesture = _currentGesture.copyWith(isActive: true);
    onDragStartCallback?.call(position, _currentGesture.targetElement);
  }
  
  /// 开始缩放手势
  void _startResizeGesture(Offset position, DrawingElement element) {
    _currentGesture = GestureState(
      type: GestureType.resize,
      startPosition: position,
      targetElement: element,
      isActive: false,
    );
  }
  
  /// 激活缩放手势
  void _activateResizeGesture(Offset position) {
    _currentGesture = _currentGesture.copyWith(isActive: true);
    onResizeStartCallback?.call(position, _currentGesture.targetElement!);
  }
  
  /// 准备创建手势
  void _prepareCreateGesture(Offset position) {
    _currentGesture = GestureState(
      type: GestureType.create,
      startPosition: position,
      isActive: false,
    );
  }
  
  /// 激活创建手势
  void _activateCreateGesture(Offset position) {
    _currentGesture = _currentGesture.copyWith(isActive: true);
    onCreateStartCallback?.call(position);
  }
  
  /// 重置手势状态
  void _resetGesture() {
    _currentGesture = GestureState(startPosition: Offset.zero);
  }
  
  /// 查找指定位置的元素
  DrawingElement? _findElementAt(Offset position, List<DrawingElement> elements) {
    // 逆序遍历，优先选择最上层的元素
    for (int i = elements.length - 1; i >= 0; i--) {
      final element = elements[i];
      if (_isPointInElement(position, element)) {
        return element;
      }
    }
    return null;
  }
  
  /// 检查点是否在元素内
  bool _isPointInElement(Offset point, DrawingElement element) {
    switch (element.type) {
      case ElementType.rectangle:
        return element.bounds.contains(point);
      case ElementType.circle:
        final center = element.center;
        final radius = element.size.width / 2;
        return (point - center).distance <= radius;
      case ElementType.line:
        // 线条点击检测，容错范围5像素
        return _distanceToLineSegment(
          point,
          element.position,
          Offset(element.position.dx + element.size.width, 
                 element.position.dy + element.size.height)
        ) <= 5.0;
      default:
        return false;
    }
  }
  
  /// 计算点到线段的距离
  double _distanceToLineSegment(Offset point, Offset lineStart, Offset lineEnd) {
    final lineLength = (lineEnd - lineStart).distance;
    if (lineLength == 0) return (point - lineStart).distance;
    
    final t = ((point - lineStart).dx * (lineEnd - lineStart).dx + 
              (point - lineStart).dy * (lineEnd - lineStart).dy) / 
              (lineLength * lineLength);
    
    final clampedT = t.clamp(0.0, 1.0);
    final projection = lineStart + (lineEnd - lineStart) * clampedT;
    
    return (point - projection).distance;
  }
  
  /// 配置回调函数
  void configureCallbacks({
    Function(Offset)? onTap,
    Function(Offset, DrawingElement?)? onDragStart,
    Function(Offset)? onDragUpdate,
    Function()? onDragEnd,
    Function(Offset, DrawingElement)? onResizeStart,
    Function(Offset)? onResizeUpdate,
    Function()? onResizeEnd,
    Function(Offset)? onCreateStart,
    Function(Offset)? onCreateUpdate,
    Function()? onCreateEnd,
  }) {
    onTapCallback = onTap;
    onDragStartCallback = onDragStart;
    onDragUpdateCallback = onDragUpdate;
    onDragEndCallback = onDragEnd;
    onResizeStartCallback = onResizeStart;
    onResizeUpdateCallback = onResizeUpdate;
    onResizeEndCallback = onResizeEnd;
    onCreateStartCallback = onCreateStart;
    onCreateUpdateCallback = onCreateUpdate;
    onCreateEndCallback = onCreateEnd;
  }
}