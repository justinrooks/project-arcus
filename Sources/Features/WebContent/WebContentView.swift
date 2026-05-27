//
//  WebContentView.swift
//  SkyAware
//

import SwiftUI
import WebKit

struct WebContentView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    let route: WebContentRoute

    @State private var webView: WKWebView?
    @State private var isLoading = false
    @State private var estimatedProgress: Double = 0
    @State private var canGoBack = false
    @State private var canGoForward = false
    @State private var currentURL: URL?
    @State private var hasLoadError = false

    private var navTitle: String {
        route.title ?? route.sourceName ?? "Source"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if hasLoadError {
                    errorState
                } else {
                    SkyAwareWebView(
                        url: route.url,
                        webView: $webView,
                        isLoading: $isLoading,
                        estimatedProgress: $estimatedProgress,
                        canGoBack: $canGoBack,
                        canGoForward: $canGoForward,
                        currentURL: $currentURL,
                        hasLoadError: $hasLoadError
                    )
                }
            }
            .navigationTitle(navTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                    .accessibilityLabel("Close page")
                }

                ToolbarItemGroup(placement: .bottomBar) {
                    Button {
                        webView?.goBack()
                    } label: {
                        Image(systemName: "chevron.backward")
                    }
                    .accessibilityLabel("Back")
                    .disabled(canGoBack == false)

                    Button {
                        webView?.goForward()
                    } label: {
                        Image(systemName: "chevron.forward")
                    }
                    .accessibilityLabel("Forward")
                    .disabled(canGoForward == false)

                    Button {
                        webView?.reload()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .accessibilityLabel("Refresh")

                    Spacer()

                    ShareLink(item: currentURL ?? route.url) {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .accessibilityLabel("Share page")

                    Button {
                        openInSafari()
                    } label: {
                        Image(systemName: "safari")
                    }
                    .accessibilityLabel("Open in Safari")
                }
            }
            .safeAreaInset(edge: .top) {
                if isLoading {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Opening page…")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        ProgressView(value: estimatedProgress)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.thinMaterial)
                }
            }
        }
    }

    private var errorState: some View {
        ContentUnavailableView {
            Label("This page couldn’t be opened.", systemImage: "exclamationmark.triangle")
        } description: {
            Text("Open it in Safari instead.")
        } actions: {
            Button("Open in Safari") {
                openInSafari()
            }
            .accessibilityLabel("Open this page in Safari")
            Button("Close") {
                dismiss()
            }
            .accessibilityLabel("Close page")
        }
        .padding(.horizontal, 16)
    }

    private func openInSafari() {
        openURL(currentURL ?? route.url)
    }
}

private struct SkyAwareWebView: UIViewRepresentable {
    let url: URL

    @Binding var webView: WKWebView?
    @Binding var isLoading: Bool
    @Binding var estimatedProgress: Double
    @Binding var canGoBack: Bool
    @Binding var canGoForward: Bool
    @Binding var currentURL: URL?
    @Binding var hasLoadError: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> WKWebView {
        let view = WKWebView(frame: .zero)
        view.allowsBackForwardNavigationGestures = true
        view.navigationDelegate = context.coordinator
        context.coordinator.bind(to: view)

        webView = view
        view.load(URLRequest(url: url))
        return view
    }

    func updateUIView(_ view: WKWebView, context: Context) {
        guard view.url == nil else { return }
        view.load(URLRequest(url: url))
    }

    static func dismantleUIView(_ uiView: WKWebView, coordinator: Coordinator) {
        coordinator.unbind()
        uiView.navigationDelegate = nil
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        private var parent: SkyAwareWebView
        private var progressObservation: NSKeyValueObservation?
        private var loadingObservation: NSKeyValueObservation?
        private var backObservation: NSKeyValueObservation?
        private var forwardObservation: NSKeyValueObservation?
        private var urlObservation: NSKeyValueObservation?

        init(_ parent: SkyAwareWebView) {
            self.parent = parent
        }

        func bind(to webView: WKWebView) {
            progressObservation = webView.observe(\.estimatedProgress, options: [.initial, .new]) { [weak self] _, _ in
                guard let self else { return }
                Task { @MainActor in
                    self.parent.estimatedProgress = webView.estimatedProgress
                }
            }
            loadingObservation = webView.observe(\.isLoading, options: [.initial, .new]) { [weak self] _, _ in
                guard let self else { return }
                Task { @MainActor in
                    self.parent.isLoading = webView.isLoading
                }
            }
            backObservation = webView.observe(\.canGoBack, options: [.initial, .new]) { [weak self] _, _ in
                guard let self else { return }
                Task { @MainActor in
                    self.parent.canGoBack = webView.canGoBack
                }
            }
            forwardObservation = webView.observe(\.canGoForward, options: [.initial, .new]) { [weak self] _, _ in
                guard let self else { return }
                Task { @MainActor in
                    self.parent.canGoForward = webView.canGoForward
                }
            }
            urlObservation = webView.observe(\.url, options: [.initial, .new]) { [weak self] _, _ in
                guard let self else { return }
                Task { @MainActor in
                    self.parent.currentURL = webView.url
                }
            }
        }

        func unbind() {
            progressObservation = nil
            loadingObservation = nil
            backObservation = nil
            forwardObservation = nil
            urlObservation = nil
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            Task { @MainActor in
                parent.hasLoadError = false
            }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            Task { @MainActor in
                parent.hasLoadError = true
            }
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            Task { @MainActor in
                parent.hasLoadError = true
            }
        }
    }
}
