/*
 * Atoll (DynamicIsland)
 * Copyright (C) 2024-2026 Atoll Contributors
 *
 * Originally from boring.notch project
 * Modified and adapted for Atoll (DynamicIsland)
 * See NOTICE for details.
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program. If not, see <https://www.gnu.org/licenses/>.
 */

import Cocoa

class DynamicIslandWindow: NSWindow {
    private var isRecenteringAfterResize = false

    override init(
        contentRect: NSRect,
        styleMask: NSWindow.StyleMask,
        backing: NSWindow.BackingStoreType,
        defer flag: Bool
    ) {
        super.init(
            contentRect: contentRect,
            styleMask: styleMask,
            backing: backing,
            defer: flag
        )
        isOpaque = false
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        backgroundColor = .clear
        isMovable = false
        ignoresMouseEvents = false

        collectionBehavior = [
            .fullScreenAuxiliary,
            .moveToActiveSpace,
            .ignoresCycle,
            .transient,
        ]

        isReleasedWhenClosed = false
        level = .mainMenu + 3
        hasShadow = false

        ScreenCaptureVisibilityManager.shared.register(self, scope: .entireInterface)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(recenterHorizontallyAfterResize),
            name: NSWindow.didResizeNotification,
            object: self
        )
    }
    
    override var canBecomeKey: Bool {
        true
    }
    
    override var canBecomeMain: Bool {
        true
    }

    @objc private func recenterHorizontallyAfterResize() {
        scheduleHorizontalRecenter(after: 0)
        scheduleHorizontalRecenter(after: 0.18)
    }

    private func scheduleHorizontalRecenter(after delay: TimeInterval) {
        guard !isRecenteringAfterResize else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.recenterHorizontallyIfNeeded()
        }
    }

    private func recenterHorizontallyIfNeeded() {
        guard !isRecenteringAfterResize else { return }
        guard isVisible, frame.width > 0, frame.height > 0 else { return }
        guard let targetScreen = screen
            ?? NSScreen.screens.first(where: { $0.frame.intersects(frame) })
            ?? NSScreen.main
            ?? NSScreen.screens.first else { return }
        let expectedX = (targetScreen.frame.midX - frame.width / 2).rounded()
        guard abs(frame.origin.x - expectedX) > 0.5 else { return }
        var next = frame
        next.origin.x = expectedX
        isRecenteringAfterResize = true
        setFrameOrigin(next.origin)
        isRecenteringAfterResize = false
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
