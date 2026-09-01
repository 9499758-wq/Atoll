import Cocoa
import SwiftUI

// MARK: - PassthroughHostingView
//
// 统一修复 Atoll 顶部悬浮窗口“整块矩形吃点击”的元凶：
//   原本所有 lock-screen / OSD / 灵动岛窗口都是 borderless 大矩形，ignoresMouseEvents=false，
//   圆角外的透明区域也会拦截鼠标，导致灵动岛正下方（微信保存、浏览器标签等）点不动。
//
// 做法（macOS 上 hitTest 是 NSView 的方法，不是 NSWindow）：
//   用 NSHostingView 子类作为窗口 contentView，重写 hitTest——
//   只对“可见圆角卡片内”的点返回命中，圆角外透明像素返回 nil，
//   事件即落到下方真正的窗口（微信保存框 / 浏览器标签等）。
//   卡片内仍可正常交互（按钮 / 滑块 / tab）。

open class PassthroughHostingView<Content: View>: NSHostingView<Content> {
    /// 内容圆角半径（用于判定圆角外穿透）
    public var contentCornerRadius: CGFloat = 0
    /// 内容相对 contentView 原点的偏移（卡片未占满整窗时使用）
    public var contentInset: CGPoint = .zero
    /// 内容实际尺寸（卡片未占满整窗时使用）；为 0 时按整个 bounds 判定
    public var contentSize: CGSize = .zero

    public required init(rootView: Content) {
        super.init(rootView: rootView)
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    open override func hitTest(_ point: NSPoint) -> NSView? {
        let rect = (contentSize.width > 0 && contentSize.height > 0)
            ? NSRect(origin: contentInset, size: contentSize)
            : bounds
        guard rect.contains(point) else { return nil }
        return super.hitTest(point)
    }
}
