//
//  PullToNavigateModifier.swift
//  i-cant-miss
//
//  Created by Codex on 26/11/25.
//

import SwiftUI
import UIKit

// MARK: - Pull Direction

enum PullDirection {
    case up
    case down
}

// MARK: - Pull To Navigate ScrollView

struct PullToNavigateScrollView<Content: View>: View {
    let content: Content
    let bottomOverlayPadding: CGFloat
    let onPullUp: () -> Void
    let onPullDown: () -> Void

    init(
        bottomOverlayPadding: CGFloat = 0,
        onPullUp: @escaping () -> Void,
        onPullDown: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.bottomOverlayPadding = bottomOverlayPadding
        self.onPullUp = onPullUp
        self.onPullDown = onPullDown
        self.content = content()
    }

    var body: some View {
        PullNavigationScrollViewRepresentable(
            bottomOverlayPadding: bottomOverlayPadding,
            onPullUp: onPullUp,
            onPullDown: onPullDown
        ) {
            content
        }
    }
}

// MARK: - UIScrollView Representable

private struct PullNavigationScrollViewRepresentable<Content: View>: UIViewControllerRepresentable {
    let content: Content
    let bottomOverlayPadding: CGFloat
    let onPullUp: () -> Void
    let onPullDown: () -> Void

    init(
        bottomOverlayPadding: CGFloat = 0,
        onPullUp: @escaping () -> Void,
        onPullDown: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.bottomOverlayPadding = bottomOverlayPadding
        self.onPullUp = onPullUp
        self.onPullDown = onPullDown
        self.content = content()
    }

    func makeUIViewController(context: Context) -> PullNavigationScrollViewController<Content> {
        let controller = PullNavigationScrollViewController<Content>()
        controller.bottomOverlayPadding = bottomOverlayPadding
        controller.onPullUp = onPullUp
        controller.onPullDown = onPullDown
        controller.setContent(content)
        return controller
    }

    func updateUIViewController(_ uiViewController: PullNavigationScrollViewController<Content>, context: Context) {
        uiViewController.bottomOverlayPadding = bottomOverlayPadding
        uiViewController.onPullUp = onPullUp
        uiViewController.onPullDown = onPullDown
        uiViewController.updateContent(content)
    }
}

// MARK: - Pull Navigation ScrollView Controller

private class PullNavigationScrollViewController<Content: View>: UIViewController, UIScrollViewDelegate {

    var onPullUp: (() -> Void)?
    var onPullDown: (() -> Void)?
    var bottomOverlayPadding: CGFloat = 0 {
        didSet { updateBottomIndicatorPadding() }
    }

    private let scrollView = UIScrollView()
    private var hostingController: UIHostingController<Content>?
    private var contentHeightConstraint: NSLayoutConstraint?

    private let threshold: CGFloat = 100
    private var hasTriggeredTop = false
    private var hasTriggeredBottom = false
    private var isNavigating = false

    // Pull indicators
    private let topIndicatorView = PullIndicatorUIView()
    private let bottomIndicatorView = PullIndicatorUIView()
    private var bottomIndicatorBottomConstraint: NSLayoutConstraint?

    override func viewDidLoad() {
        super.viewDidLoad()
        setupScrollView()
        setupIndicators()
    }

    private func setupScrollView() {
        scrollView.delegate = self
        scrollView.alwaysBounceVertical = true
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(scrollView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func setupIndicators() {
        topIndicatorView.direction = .up
        topIndicatorView.translatesAutoresizingMaskIntoConstraints = false
        topIndicatorView.alpha = 0

        bottomIndicatorView.direction = .down
        bottomIndicatorView.translatesAutoresizingMaskIntoConstraints = false
        bottomIndicatorView.alpha = 0

        view.addSubview(topIndicatorView)
        view.addSubview(bottomIndicatorView)

        bottomIndicatorBottomConstraint = bottomIndicatorView.bottomAnchor.constraint(
            equalTo: view.safeAreaLayoutGuide.bottomAnchor
        )

        NSLayoutConstraint.activate([
            topIndicatorView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            topIndicatorView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            topIndicatorView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            topIndicatorView.heightAnchor.constraint(equalToConstant: 60),

            bottomIndicatorView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomIndicatorView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomIndicatorView.heightAnchor.constraint(equalToConstant: 60)
        ])

        bottomIndicatorBottomConstraint?.isActive = true
        updateBottomIndicatorPadding()
    }

    func setContent(_ content: Content) {
        if let existing = hostingController {
            existing.willMove(toParent: nil)
            existing.view.removeFromSuperview()
            existing.removeFromParent()
        }

        let hosting = UIHostingController(rootView: content)
        hosting.view.backgroundColor = .clear
        hosting.view.translatesAutoresizingMaskIntoConstraints = false

        addChild(hosting)
        scrollView.addSubview(hosting.view)
        hosting.didMove(toParent: self)

        let heightConstraint = hosting.view.heightAnchor.constraint(greaterThanOrEqualTo: scrollView.heightAnchor)

        NSLayoutConstraint.activate([
            hosting.view.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            hosting.view.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            hosting.view.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            hosting.view.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            hosting.view.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
            heightConstraint
        ])

        hostingController = hosting
        contentHeightConstraint = heightConstraint
    }

    func updateContent(_ content: Content) {
        hostingController?.rootView = content
    }

    // MARK: - UIScrollViewDelegate

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard !isNavigating else { return }

        let offsetY = scrollView.contentOffset.y
        let contentHeight = scrollView.contentSize.height
        let frameHeight = scrollView.frame.height

        // Top overscroll (pulling down)
        if offsetY < 0 {
            let pullDistance = abs(offsetY)
            let progress = min(pullDistance / threshold, 1.5)

            topIndicatorView.alpha = min(progress, 1.0)
            topIndicatorView.updateProgress(progress, isActivated: progress >= 1.0)
            bottomIndicatorView.alpha = 0

            if progress >= 1.0 && !hasTriggeredTop {
                hasTriggeredTop = true
                triggerHaptic()
            } else if progress < 1.0 {
                hasTriggeredTop = false
            }
        }
        // Bottom overscroll (pulling up)
        else if offsetY + frameHeight > contentHeight && contentHeight > 0 {
            let pullDistance = offsetY + frameHeight - contentHeight
            let progress = min(pullDistance / threshold, 1.5)

            bottomIndicatorView.alpha = min(progress, 1.0)
            bottomIndicatorView.updateProgress(progress, isActivated: progress >= 1.0)
            topIndicatorView.alpha = 0

            if progress >= 1.0 && !hasTriggeredBottom {
                hasTriggeredBottom = true
                triggerHaptic()
            } else if progress < 1.0 {
                hasTriggeredBottom = false
            }
        } else {
            topIndicatorView.alpha = 0
            bottomIndicatorView.alpha = 0
        }
    }

    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        checkAndTriggerNavigation()
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        checkAndTriggerNavigation()
    }

    private func checkAndTriggerNavigation() {
        guard !isNavigating else { return }

        if hasTriggeredTop {
            performNavigation(direction: .up)
        } else if hasTriggeredBottom {
            performNavigation(direction: .down)
        }
    }

    private func performNavigation(direction: PullDirection) {
        isNavigating = true

        UIView.animate(withDuration: 0.3) {
            self.topIndicatorView.alpha = 0
            self.bottomIndicatorView.alpha = 0
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            switch direction {
            case .up:
                self?.onPullUp?()
            case .down:
                self?.onPullDown?()
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.isNavigating = false
                self?.hasTriggeredTop = false
                self?.hasTriggeredBottom = false
                self?.scrollView.setContentOffset(.zero, animated: false)
            }
        }
    }

    private func triggerHaptic() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }

    private func updateBottomIndicatorPadding() {
        bottomIndicatorBottomConstraint?.constant = -bottomOverlayPadding

        if isViewLoaded {
            view.layoutIfNeeded()
        }
    }
}

// MARK: - Pull Indicator UIView

private class PullIndicatorUIView: UIView {

    var direction: PullDirection = .up {
        didSet { updateDirection() }
    }

    private let stackView = UIStackView()
    private let arrowImageView = UIImageView()
    private let label = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
    }

    private func setupViews() {
        backgroundColor = .clear

        stackView.axis = .vertical
        stackView.alignment = .center
        stackView.spacing = 4
        stackView.translatesAutoresizingMaskIntoConstraints = false

        arrowImageView.contentMode = .scaleAspectFit
        arrowImageView.tintColor = .secondaryLabel
        arrowImageView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 18, weight: .semibold)

        label.font = .systemFont(ofSize: 12, weight: .medium)
        label.textColor = .secondaryLabel
        label.textAlignment = .center

        stackView.addArrangedSubview(arrowImageView)
        stackView.addArrangedSubview(label)
        addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.centerXAnchor.constraint(equalTo: centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])

        updateDirection()
    }

    private func updateDirection() {
        switch direction {
        case .up:
            arrowImageView.image = UIImage(systemName: "chevron.up")
        case .down:
            arrowImageView.image = UIImage(systemName: "chevron.down")
        }
        updateLabel(isActivated: false)
    }

    func updateProgress(_ progress: CGFloat, isActivated: Bool) {
        let scale = 0.8 + (min(progress, 1.0) * 0.4)
        arrowImageView.transform = CGAffineTransform(scaleX: scale, y: scale)

        arrowImageView.tintColor = isActivated ? .tintColor : .secondaryLabel
        label.textColor = isActivated ? .tintColor : .secondaryLabel

        updateLabel(isActivated: isActivated)
    }

    private func updateLabel(isActivated: Bool) {
        switch direction {
        case .up:
            label.text = isActivated ? "Release for Previous" : "Pull for Previous"
        case .down:
            label.text = isActivated ? "Release for Next" : "Pull for Next"
        }
    }
}

// MARK: - Preview

#Preview {
    PullToNavigateScrollView(
        onPullUp: { print("Pull up - go to previous") },
        onPullDown: { print("Pull down - go to next") }
    ) {
        VStack(spacing: 20) {
            ForEach(0..<5) { i in
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.secondary.opacity(0.2))
                    .frame(height: 100)
                    .overlay {
                        Text("Item \(i)")
                    }
            }
        }
        .padding()
    }
}
