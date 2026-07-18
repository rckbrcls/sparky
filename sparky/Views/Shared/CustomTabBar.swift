//
//  CustomTabBar.swift
//  sparky
//
//  Created by Codex on 18/03/25.
//

import SwiftUI

struct CustomTabBar<TabItemView: View>: UIViewRepresentable {
    @Environment(\.colorScheme) private var colorScheme

    var size: CGSize
    var activeTint: Color = Color.accent
    var inactiveTint: Color = Color.Theme.textSecondary
    var barTint: Color = .gray.opacity(0.15)
    @Binding var activeTab: CustomTab
    @ViewBuilder var tabItemView: (CustomTab) -> TabItemView
    var onTabReselected: ((CustomTab) -> Void)? = nil

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> UISegmentedControl {
        let items = CustomTab.allCases.map(\.rawValue)
        let control = ReselectableSegmentedControl(items: items)
        control.selectedSegmentIndex = activeTab.index

        renderTabImages(for: control)

        DispatchQueue.main.async {
            for subview in control.subviews {
                if subview is UIImageView && subview != control.subviews.last {
                    subview.alpha = 0
                }
            }
            Self.removeShadows(from: control)
        }

        control.backgroundColor = .clear
        control.selectedSegmentTintColor = UIColor(barTint)
        control.setTitleTextAttributes([.foregroundColor: UIColor(activeTint)], for: .selected)

        control.addTarget(context.coordinator, action: #selector(context.coordinator.tabSelected(_:)), for: .valueChanged)
        control.onReselectSegment = { [weak coordinator = context.coordinator] index in
            coordinator?.tabReselected(index: index)
        }
        return control
    }

    func updateUIView(_ uiView: UIViewType, context: Context) {
        context.coordinator.parent = self
        if uiView.selectedSegmentIndex != activeTab.index {
            uiView.selectedSegmentIndex = activeTab.index
        }
        renderTabImages(for: uiView)
        uiView.backgroundColor = .clear
        uiView.selectedSegmentTintColor = UIColor(barTint)
        uiView.setTitleTextAttributes([.foregroundColor: UIColor(activeTint)], for: .selected)
        Self.removeShadows(from: uiView)
        DispatchQueue.main.async {
            Self.removeShadows(from: uiView)
        }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UISegmentedControl, context: Context) -> CGSize? {
        return size
    }

    private func renderTabImages(for control: UISegmentedControl) {
        for (index, tab) in CustomTab.allCases.enumerated() {
            let tint = tab == activeTab ? activeTint : inactiveTint
            let rendered = ImageRenderer(
                content: tabItemView(tab)
                    .foregroundStyle(tint)
                    .environment(\.colorScheme, colorScheme)
            )
            rendered.scale = 2
            control.setImage(rendered.uiImage?.withRenderingMode(.alwaysOriginal), forSegmentAt: index)
        }
    }

    private static func removeShadows(from view: UIView) {
        view.layer.shadowColor = UIColor.clear.cgColor
        view.layer.shadowOpacity = 0
        view.layer.shadowRadius = 0
        view.layer.shadowOffset = .zero
        view.subviews.forEach { removeShadows(from: $0) }
    }

    class Coordinator: NSObject {
        var parent: CustomTabBar
        init(parent: CustomTabBar) {
            self.parent = parent
        }

        @objc func tabSelected(_ control: UISegmentedControl) {
            parent.activeTab = CustomTab.allCases[control.selectedSegmentIndex]
        }

        func tabReselected(index: Int) {
            guard CustomTab.allCases.indices.contains(index) else { return }
            let tab = CustomTab.allCases[index]
            parent.onTabReselected?(tab)
        }
    }

    private final class ReselectableSegmentedControl: UISegmentedControl {
        var onReselectSegment: ((Int) -> Void)?

        override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
            let previousIndex = selectedSegmentIndex
            let tappedIndex = touches.first.flatMap { touch in
                segmentIndex(at: touch.location(in: self))
            } ?? previousIndex

            super.touchesEnded(touches, with: event)

            if tappedIndex == previousIndex, previousIndex != UISegmentedControl.noSegment {
                onReselectSegment?(previousIndex)
            }
        }

        private func segmentIndex(at point: CGPoint) -> Int? {
            guard bounds.width > 0, numberOfSegments > 0 else { return nil }
            let segmentWidth = bounds.width / CGFloat(numberOfSegments)
            guard segmentWidth > 0 else { return nil }
            var index = Int(point.x / segmentWidth)
            index = max(0, min(numberOfSegments - 1, index))
            return index
        }
    }
}

#Preview {
    let environment = AppEnvironment(dataController: DataController.preview)
    environment.bootstrap()
    return ContentView(environment: environment)
}
