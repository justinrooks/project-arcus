//
//  OnboardingStepShell.swift
//  SkyAware
//
//  Created by Codex on 6/11/26.
//

import SwiftUI

struct OnboardingStepShell<Content: View, Footer: View>: View {
    private let footerBottomClearance: CGFloat = 52
    private let content: Content
    private let footer: Footer

    init(
        @ViewBuilder content: () -> Content,
        @ViewBuilder footer: () -> Footer
    ) {
        self.content = content()
        self.footer = footer()
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                content
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 32)
            .padding(.vertical, 24)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            footer
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 32)
                .padding(.top, 16)
                .padding(.bottom, footerBottomClearance)
                .background(Color(.skyAwareBackground))
        }
        .background(Color(.skyAwareBackground).ignoresSafeArea())
    }
}
