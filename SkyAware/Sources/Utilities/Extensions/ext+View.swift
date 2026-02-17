//
//  ext+View.swift
//  SkyAware
//
//  Created by Justin Rooks on 7/25/25.
//

import SwiftUI

extension View {
    @ViewBuilder
    func skyAwareSurface(
        cornerRadius: CGFloat = SkyAwareRadius.medium,
        tint: Color = .white.opacity(0.06),
        interactive: Bool = false,
        shadowOpacity: Double = 0.10,
        shadowRadius: CGFloat = 10,
        shadowY: CGFloat = 4
    ) -> some View {
        if #available(iOS 26, *) {
            if interactive {
                self
                    .glassEffect(
                        .regular.tint(tint).interactive(),
                        in: .rect(cornerRadius: cornerRadius)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .strokeBorder(.white.opacity(0.16), lineWidth: 0.8)
                            .allowsHitTesting(false)
                    }
                    .shadow(color: .black.opacity(shadowOpacity), radius: shadowRadius, x: 0, y: shadowY)
            } else {
                self
                    .glassEffect(
                        .regular.tint(tint),
                        in: .rect(cornerRadius: cornerRadius)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .strokeBorder(.white.opacity(0.16), lineWidth: 0.8)
                            .allowsHitTesting(false)
                    }
                    .shadow(color: .black.opacity(shadowOpacity), radius: shadowRadius, x: 0, y: shadowY)
            }
        } else {
            self
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(.cardBackground)
                        .background(
                            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                                .fill(Color.clear)
                                .shadow(
                                    color: .black.opacity(shadowOpacity),
                                    radius: shadowRadius,
                                    x: 0,
                                    y: shadowY
                                )
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                                .strokeBorder(.white.opacity(0.10), lineWidth: 1)
                                .allowsHitTesting(false)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                )
        }
    }

    func badgeStyle(background: LinearGradient) -> some View {
        self
            .frame(minWidth: 130, idealWidth: 145, maxWidth: 145,
                   minHeight: 150, idealHeight: 150, maxHeight: 160)
            .aspectRatio(1, contentMode: .fit)
            .padding()
            .background(RoundedRectangle(cornerRadius: SkyAwareRadius.large, style: .continuous).fill(background))
            .skyAwareSurface(
                cornerRadius: SkyAwareRadius.large,
                tint: .white.opacity(0.08),
                shadowOpacity: 0.18,
                shadowRadius: 8,
                shadowY: 4
            )
    }
    
    
    /// This modifier will allow you to display a "redacted" view or fuzzy view
    /// while content is loading as an example.
    /// - Parameter isActive: boolean evaluating to true/false. True redacts content, false displays it
    /// - Returns: a redaction configuration to apply to the view
    func placeholder(_ isActive: Bool) -> some View {
        self
            .redacted(reason: isActive ? .placeholder : [])
            .opacity(isActive ? 0.8 : 1)
            .animation(.snappy, value: isActive)
    }
    
    @ViewBuilder
    func cardBackground(
        cornerRadius: CGFloat = 26,
        shadowOpacity: Double = 0.10,
        shadowRadius: CGFloat = 10,
        shadowY: CGFloat = 4
    ) -> some View {
        self.skyAwareSurface(
            cornerRadius: cornerRadius,
            tint: .white.opacity(0.10),
            shadowOpacity: shadowOpacity,
            shadowRadius: shadowRadius,
            shadowY: shadowY
        )
    }
    
    func cardRowBackground(
        cornerRadius: CGFloat = 18,
        shadowOpacity: Double = 0.0,
        shadowRadius: CGFloat = 0,
        shadowY: CGFloat = 0
    ) -> some View {
        self
            .cardBackground(
                cornerRadius: cornerRadius,
                shadowOpacity: shadowOpacity,
                shadowRadius: shadowRadius,
                shadowY: shadowY
            )
            .listRowInsets(EdgeInsets(top: 6, leading: 14, bottom: 6, trailing: 14))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
    }
    
    func mesoscaleCardChrome(for layout: DetailLayout) -> some View {
        let cornerRadius: CGFloat = SkyAwareRadius.medium
        let hPad: CGFloat = layout == .sheet ? 16 : 18
        let vPad: CGFloat = layout == .sheet ? 12 : 24
        let shadowOpacity: Double = layout == .full ? 0.10 : 0
        
        switch layout {
        case .sheet:
            return AnyView(
                self
                    .padding(.horizontal, hPad)
                    .padding(.vertical, vPad)
                    .skyAwareSurface(
                        cornerRadius: cornerRadius,
                        tint: .white.opacity(0.08),
                        shadowOpacity: shadowOpacity,
                        shadowRadius: 12,
                        shadowY: 5
                    )
                )
        case .full:
            return AnyView(
                self
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 24)
            )
        }
    }

    @ViewBuilder
    func skyAwareGlassButtonStyle(prominent: Bool = false) -> some View {
        if #available(iOS 26, *) {
            if prominent {
                self.buttonStyle(.glassProminent)
            } else {
                self.buttonStyle(.glass)
            }
        } else {
            if prominent {
                self.buttonStyle(.borderedProminent)
            } else {
                self.buttonStyle(.bordered)
            }
        }
    }

    @ViewBuilder
    func skyAwareChip(
        cornerRadius: CGFloat = 26,
        tint: Color = .white.opacity(0.10),
        interactive: Bool = false
    ) -> some View {
        if #available(iOS 26, *) {
            if interactive {
                self.glassEffect(
                    .regular.tint(tint).interactive(),
                    in: .rect(cornerRadius: cornerRadius)
                )
            } else {
                self.glassEffect(
                    .regular.tint(tint),
                    in: .rect(cornerRadius: cornerRadius)
                )
            }
        } else {
            self
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(.ultraThinMaterial)
                )
        }
    }
    
    func getHeight(for height: Binding<CGFloat>, tolerance: CGFloat = 1) -> some View {
        self
            .fixedSize(horizontal: false, vertical: true)
            .background(
                GeometryReader { geo in
                    Color.clear
                        .onAppear {
                            let measuredHeight = geo.size.height
                            if abs(measuredHeight - height.wrappedValue) > tolerance {
                                height.wrappedValue = measuredHeight
                            }
                        }
                        .onChange(of: geo.size.height) { _, newValue in
                            if abs(newValue - height.wrappedValue) > tolerance {
                                height.wrappedValue = newValue
                            }
                        }
                }
            )
    }
}
