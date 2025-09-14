import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../models/drawing_element.dart';
import '../providers/drawing_provider.dart';
import '../services/adsorption_manager.dart';
import 'drawing_canvas.dart';

/// 画板主界面
class DrawingBoard extends HookConsumerWidget {
  const DrawingBoard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedTool = useState(ElementType.select); // 默认为选择工具
    final selectedColor = useState(Colors.blue);
    final strokeWidth = useState(2.0);
    final focusNode = useFocusNode();
    
    // 使用useEffect替代dispose
    useEffect(() {
      focusNode.requestFocus();
      return () {
        // 清理吸附管理器的计时器
        AdsorptionManager.dispose();
      };
    }, []);
    
    final drawingState = ref.watch(drawingStateProvider);
    final elements = ref.watch(elementsProvider);
    final selectedElement = ref.watch(selectedElementProvider);

    void handleCanvasTap(Offset position) {
      // 检查是否点击了缩放控制点
      if (selectedElement != null && drawingState.isPointInResizeHandle(position)) {
        // 点击了缩放控制点，不做任何操作（由拖拽处理）
        return;
      }
      
      final element = drawingState.findElementAt(position);
      if (element != null) {
        ref.read(drawingStateProvider.notifier).selectElement(element.id);
      } else {
        ref.read(drawingStateProvider.notifier).clearSelection();
        
        // 只有在非选择模式下才创建新元素
        if (selectedTool.value != ElementType.select) {
          final newElement = DrawingElement(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            type: selectedTool.value,
            position: position,
            size: const Size(100, 60),
            color: selectedColor.value,
            strokeWidth: strokeWidth.value,
          );
          
          ref.read(drawingStateProvider.notifier).addElement(newElement);
        }
      }
    }

    void handlePanStart(Offset position) {
      // 简化后的pan处理，具体逻辑已移动到GestureManager
      // 这里只需要处理实际的拖拽/缩放操作
      
      // 优先检查是否点击了缩放控制点
      if (selectedElement != null && drawingState.isPointInResizeHandle(position)) {
        ref.read(drawingStateProvider.notifier).startResize(position);
        return;
      }
      
      // 检查是否选中了元素进行拖拽
      final element = drawingState.findElementAt(position);
      if (element != null) {
        ref.read(drawingStateProvider.notifier).selectElement(element.id);
        ref.read(drawingStateProvider.notifier).startDrag(position);
      }
    }

    void handlePanUpdate(Offset position) {
      if (drawingState.isResizing) {
        ref.read(drawingStateProvider.notifier).updateResize(position);
      } else if (drawingState.isDragging) {
        ref.read(drawingStateProvider.notifier).updateDrag(position);
      }
    }

    void handlePanEnd() {
      if (drawingState.isResizing) {
        ref.read(drawingStateProvider.notifier).endResize();
      } else {
        ref.read(drawingStateProvider.notifier).endDrag();
      }
    }

    Widget buildToolbar() {
      return Container(
        height: 60,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          border: const Border(
            bottom: BorderSide(color: Colors.grey, width: 0.5),
          ),
        ),
        child: Row(
          children: [
            // 工具选择
            const Text('工具: ', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            ...ElementType.values.map((type) {
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(_getToolName(type)),
                  selected: selectedTool.value == type,
                  onSelected: (selected) {
                    if (selected) {
                      selectedTool.value = type;
                    }
                  },
                ),
              );
            }),
            const SizedBox(width: 16),
            
            // 颜色选择
            const Text('颜色: ', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            ...[Colors.blue, Colors.red, Colors.green, Colors.orange, Colors.purple].map((color) {
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => selectedColor.value = color,
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: selectedColor.value == color
                          ? Border.all(color: Colors.black, width: 2)
                          : null,
                    ),
                  ),
                ),
              );
            }),
            const SizedBox(width: 16),
            
            // 线宽选择
            const Text('线宽: ', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            SizedBox(
              width: 100,
              child: Slider(
                value: strokeWidth.value,
                min: 1.0,
                max: 10.0,
                divisions: 9,
                label: strokeWidth.value.round().toString(),
                onChanged: (value) => strokeWidth.value = value,
              ),
            ),
          ],
        ),
      );
    }

    return KeyboardListener(
      focusNode: focusNode,
      onKeyEvent: (event) {
        drawingState.handleKeyEvent(event);
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('吸附线画板'),
          backgroundColor: Colors.grey[100],
          elevation: 1,
          actions: [
            IconButton(
              icon: const Icon(Icons.clear_all),
              onPressed: () {
                ref.read(drawingStateProvider.notifier).clear();
              },
              tooltip: '清空画板',
            ),
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: selectedElement != null
                  ? () => ref.read(drawingStateProvider.notifier).deleteSelectedElement()
                  : null,
              tooltip: '删除选中元素',
            ),
          ],
        ),
        body: Column(
          children: [
            // 工具栏
            buildToolbar(),
            // 画板区域
            Expanded(
              child: Container(
                width: double.infinity,
                color: Colors.white,
                child: DrawingCanvas(
                  elements: elements,
                  selectedElement: selectedElement,
                  onTap: handleCanvasTap,
                  onPanStart: handlePanStart,
                  onPanUpdate: handlePanUpdate,
                  onPanEnd: handlePanEnd,
                  isPointInResizeHandle: (position) => drawingState.isPointInResizeHandle(position),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getToolName(ElementType type) {
    switch (type) {
      case ElementType.select:
        return '选择';
      case ElementType.rectangle:
        return '矩形';
      case ElementType.circle:
        return '圆形';
      case ElementType.line:
        return '直线';
    }
  }

  SystemMouseCursor _getCursorForTool(ElementType type) {
    switch (type) {
      case ElementType.select:
        return SystemMouseCursors.basic;
      case ElementType.rectangle:
      case ElementType.circle:
      case ElementType.line:
        return SystemMouseCursors.precise;
    }
  }
}
