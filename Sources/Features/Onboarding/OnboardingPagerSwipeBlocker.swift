//
//  OnboardingPagerSwipeBlocker.swift
//  SkyAware
//
//  Created by Codex on 6/11/26.
//

import SwiftUI
import UIKit

struct OnboardingPagerSwipeBlocker: UIViewRepresentable {
    func makeUIView(context: Context) -> BlockingView {
        BlockingView()
    }

    func updateUIView(_ uiView: BlockingView, context: Context) {
        uiView.applyIfNeeded()
    }

    final class BlockingView: UIView {
        private var didDisablePagingScrollView = false
        private var retryTask: Task<Void, Never>?

        override func didMoveToWindow() {
            super.didMoveToWindow()
            applyIfNeeded()
        }

        func applyIfNeeded() {
            guard !didDisablePagingScrollView else { return }
            guard let window else { return }

            if let pagingScrollView = Self.pagingScrollView(in: window) {
                pagingScrollView.isScrollEnabled = false
                didDisablePagingScrollView = true
                retryTask?.cancel()
                retryTask = nil
                return
            }

            guard retryTask == nil else { return }
            retryTask = Task { @MainActor [weak self] in
                for _ in 0..<20 {
                    try? await Task.sleep(for: .milliseconds(25))
                    guard let self, !Task.isCancelled else { return }
                    self.applyIfNeeded()
                    if self.didDisablePagingScrollView {
                        return
                    }
                }
                self?.retryTask = nil
            }
        }

        private static func pagingScrollView(in view: UIView) -> UIScrollView? {
            if let scrollView = view as? UIScrollView, scrollView.isPagingEnabled {
                return scrollView
            }

            for child in view.subviews {
                if let pagingScrollView = pagingScrollView(in: child) {
                    return pagingScrollView
                }
            }

            return nil
        }

        deinit {
            retryTask?.cancel()
        }
    }
}
