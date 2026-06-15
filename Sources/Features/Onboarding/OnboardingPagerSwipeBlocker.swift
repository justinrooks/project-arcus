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

        override func didMoveToWindow() {
            super.didMoveToWindow()
            applyIfNeeded()
        }

        func applyIfNeeded() {
            guard !didDisablePagingScrollView else { return }
            guard let pagingScrollView = ancestorPagingScrollView() else { return }

            pagingScrollView.isScrollEnabled = false
            didDisablePagingScrollView = true
        }

        private func ancestorPagingScrollView() -> UIScrollView? {
            var currentView = superview
            while let view = currentView {
                if let scrollView = view as? UIScrollView, scrollView.isPagingEnabled {
                    return scrollView
                }
                currentView = view.superview
            }
            return nil
        }
    }
}
