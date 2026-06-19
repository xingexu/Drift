import AppKit
import SwiftUI

// MARK: - Mini Player Panel (NSPanel-backed always-on-top floating window)

final class MiniPlayerPanel: NSPanel {

    private static let defaultSize = NSRect(x: 0, y: 0, width: 200, height: 72)
    private static let savedOriginKey = "MiniPlayerPanelOrigin"

    init() {
        super.init(
            contentRect: MiniPlayerPanel.defaultSize,
            styleMask: [.borderless, .nonactivatingPanel, .hudWindow],
            backing: .buffered,
            defer: false
        )
        level = .floating
        isFloatingPanel = true
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        isMovableByWindowBackground = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    }

    // MARK: - Show / Hide

    @MainActor
    func show(viewModel: StudyViewModel) {
        let hostingView = NSHostingView(
            rootView: MiniPlayerView(viewModel: viewModel) {
                self.close()
            }
        )
        hostingView.frame = contentRect(forFrameRect: frame)
        contentView = hostingView

        restoreOriginOrCenter()
        makeKeyAndOrderFront(nil)
    }

    // MARK: - Persistence helpers

    private func restoreOriginOrCenter() {
        if let saved = UserDefaults.standard.string(forKey: MiniPlayerPanel.savedOriginKey),
           let data = saved.data(using: .utf8),
           let dict = try? JSONSerialization.jsonObject(with: data) as? [String: CGFloat],
           let x = dict["x"],
           let y = dict["y"] {
            setFrameOrigin(NSPoint(x: x, y: y))
        } else {
            center()
        }
    }

    override func close() {
        // Persist position so it reopens in the same spot
        let origin = frame.origin
        let dict: [String: CGFloat] = ["x": origin.x, "y": origin.y]
        if let data = try? JSONSerialization.data(withJSONObject: dict),
           let str = String(data: data, encoding: .utf8) {
            UserDefaults.standard.set(str, forKey: MiniPlayerPanel.savedOriginKey)
        }
        super.close()
    }
}
