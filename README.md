# Flutter Hook Widget Examples

这个项目旨在展示和学习 Flutter Hooks 的使用方法。Flutter Hooks 是一种用于状态管理的强大模式，源自于 React Hooks 的概念。

## 项目结构

```
lib/
  ├── src/
  │   └── examples/
  │       ├── counter_hook.dart      # 计数器示例
  │       ├── text_field_hook.dart   # 文本输入示例
  │       ├── animation_hook.dart    # 动画示例
  │       └── lifecycle_hook.dart    # 生命周期示例
  └── flutter_hook_widget.dart       # 主入口文件
```

## 示例列表

1. **Counter Hook**
   - 使用 `useState` hook 实现计数器功能
   - 展示基本的状态管理

2. **Text Field Hook** (即将添加)
   - 使用 `useTextEditingController` 管理文本输入
   - 展示表单控制和验证

3. **Animation Hook** (即将添加)
   - 使用 `useAnimationController` 实现动画效果
   - 展示动画状态管理

4. **Lifecycle Hook** (即将添加)
   - 使用 `useEffect` 管理组件生命周期
   - 展示副作用处理

## 常用 Hooks 说明

- **useState**: 用于管理状态
- **useEffect**: 处理副作用
- **useMemoized**: 缓存计算结果
- **useCallback**: 缓存回调函数
- **useRef**: 持久化值的引用

## 开始使用

1. 确保你的 Flutter 环境已经设置好
2. 克隆此仓库
3. 运行以下命令：

```bash
flutter pub get
flutter run
```

## 学习资源

- [Flutter Hooks 官方文档](https://pub.dev/packages/flutter_hooks)
- [Flutter Hooks 教程](https://pub.dev/documentation/flutter_hooks/latest/)

## 贡献

欢迎提交 Pull Request 来改进代码或添加新的示例！

## 许可证

MIT License

