import 'package:adsorption_line/models/drawing_element.dart';
import 'package:adsorption_line/state/drawing_state.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

// 创建DrawingState的provider
final drawingStateProvider = ChangeNotifierProvider<DrawingState>((ref) {
  return DrawingState();
});

// 便捷的getter providers
final elementsProvider = Provider<List<DrawingElement>>((ref) {
  return ref.watch(drawingStateProvider).elements;
});

final selectedElementProvider = Provider<DrawingElement?>((ref) {
  return ref.watch(drawingStateProvider).selectedElement;
});

final isDraggingProvider = Provider<bool>((ref) {
  return ref.watch(drawingStateProvider).isDragging;
});
