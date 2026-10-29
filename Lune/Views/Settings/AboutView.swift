//
//  AboutView.swift
//  Lune
//
//  Complete 1:1 parity with Android Lune's AboutActivity:
//  - Hero Moon + Note Logo
//  - Version 0.0.1 (License: GPLv3)
//  - Action row: Github, Website, and Donate
//  - Support the Project sheet (PayPal + Monero with copy address)
//  - Author: MrDemonc (Creator and maintainer)
//  - Credits: Desukia (Testing, design suggestions, and logo)
//  - Open Source Libraries (Coil, Gson, Room, Jaudiotagger, Jetpack Compose, Quicksand Font)
//

import SwiftUI
import UIKit

@MainActor
public struct AboutView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    
    @StateObject private var settings = SettingsManager.shared
    @State private var showDonateSheet: Bool = false
    @State private var showMonero: Bool = false
    @State private var copiedMonero: Bool = false
    
    public init() {}
    
    public var body: some View {
        let colors = settings.resolveColors(for: colorScheme)
        
        ScrollView {
            VStack(spacing: 24) {
                // MARK: - Logo Section
                VStack(spacing: 12) {
                    Image("AppLogo")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 150, height: 150)
                        .shadow(color: colors.primary.opacity(0.35), radius: 24, x: 0, y: 8)
                        .padding(.top, 16)
                    
                    // Version
                    Text("Version 0.0.1")
                        .font(.custom("Quicksand-Bold", size: 24))
                        .foregroundColor(colors.primary)
                    
                    Text("License: GPLv3")
                        .font(.custom("Quicksand-SemiBold", size: 14))
                        .foregroundColor(colors.onSurface.opacity(0.70))
                }
                
                // MARK: - Action Buttons (Row of 3)
                HStack(spacing: 10) {
                    // Github
                    Link(destination: URL(string: "https://github.com/MrDemonc/Lune/tree/main")!) {
                        HStack(spacing: 6) {
                            Image(systemName: "chevron.left.forwardslash.chevron.right")
                                .font(.system(size: 13, weight: .bold))
                            Text("Github")
                                .font(.custom("Quicksand-Bold", size: 14))
                                .lineLimit(1)
                        }
                        .foregroundColor(colors.onSurface)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(colors.surfaceVariant.opacity(0.85))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    
                    // Website
                    Link(destination: URL(string: "https://mrdemonc.github.io/Lune/")!) {
                        HStack(spacing: 6) {
                            Image(systemName: "globe")
                                .font(.system(size: 14, weight: .medium))
                            Text("Website")
                                .font(.custom("Quicksand-Bold", size: 14))
                                .lineLimit(1)
                        }
                        .foregroundColor(colors.onSurface)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(colors.surfaceVariant.opacity(0.85))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    
                    // Donate
                    Button {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        showDonateSheet = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "cup.and.saucer.fill")
                                .font(.system(size: 13, weight: .bold))
                            Text("Donate")
                                .font(.custom("Quicksand-Bold", size: 14))
                                .lineLimit(1)
                        }
                        .foregroundColor(colorScheme == .dark ? Color.black : Color.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(colors.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                }
                .padding(.horizontal, 20)
                
                // MARK: - Developer & Brand Info
                VStack(alignment: .leading, spacing: 18) {
                    // App Creator (Desukia)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("App Creator")
                            .font(.custom("Quicksand-Bold", size: 13))
                            .foregroundColor(colors.secondary)
                            .textCase(.uppercase)
                        
                        Text("Desukia")
                            .font(.custom("Quicksand-Bold", size: 17))
                            .foregroundColor(colors.onSurface)
                        
                        Text("Creator and developer of Lune for iOS")
                            .font(.custom("Quicksand-Regular", size: 14))
                            .foregroundColor(colors.onSurface.opacity(0.75))
                    }
                    
                    Divider()
                        .background(Color.white.opacity(0.15))
                    
                    // Brand Creator (MrDemonc)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Lune Brand")
                            .font(.custom("Quicksand-Bold", size: 13))
                            .foregroundColor(colors.secondary)
                            .textCase(.uppercase)
                        
                        Text("MrDemonc")
                            .font(.custom("Quicksand-Bold", size: 17))
                            .foregroundColor(colors.onSurface)
                        
                        Text("Creator of the Lune brand")
                            .font(.custom("Quicksand-Regular", size: 14))
                            .foregroundColor(colors.onSurface.opacity(0.75))
                    }
                    
                    Divider()
                        .background(Color.white.opacity(0.15))
                    
                    // Typography License
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Typography")
                            .font(.custom("Quicksand-Bold", size: 13))
                            .foregroundColor(colors.secondary)
                            .textCase(.uppercase)
                        
                        libraryRow(
                            name: "Quicksand Font",
                            description: "Quicksand is a sans-serif typeface designed by Andrew Paglinawan.\nLicense: SIL Open Font License, 1.1",
                            colors: colors
                        )
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 12)
                .padding(.bottom, 40)
            }
        }
        .background(colors.background.ignoresSafeArea())
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Image(systemName: "info.circle")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(colors.primary)
                }
            }
        }
        .sheet(isPresented: $showDonateSheet) {
            donateSheetView(colors: colors)
                .presentationDetents([.medium, .fraction(0.65)])
                .presentationDragIndicator(.visible)
        }
    }
    
    // MARK: - Library Row Helper
    private func libraryRow(name: String, description: String, colors: LuneColorScheme) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(name)
                .font(.custom("Quicksand-Bold", size: 16))
                .foregroundColor(colors.onSurface)
            
            Text(description)
                .font(.custom("Quicksand-Regular", size: 13))
                .foregroundColor(colors.onSurface.opacity(0.70))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
    
    // MARK: - Donate Sheet (Parity with Android's DonateDialog)
    private func donateSheetView(colors: LuneColorScheme) -> some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Text("Support the Project")
                        .font(.custom("Quicksand-Bold", size: 22))
                        .foregroundColor(colors.onSurface)
                        .padding(.top, 16)
                    
                    // PayPal Option
                    Link(destination: URL(string: "https://paypal.me/TommyZambrano")!) {
                        HStack(spacing: 10) {
                            Image(systemName: "cup.and.saucer.fill")
                                .font(.system(size: 18))
                            Text("PayPal")
                                .font(.custom("Quicksand-Bold", size: 16))
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundColor(colorScheme == .dark ? Color.black : Color.white)
                        .padding(16)
                        .background(colors.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    
                    // Monero Option Toggle
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            showMonero.toggle()
                        }
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "bitcoinsign.circle.fill")
                                .font(.system(size: 18))
                            Text("Monero")
                                .font(.custom("Quicksand-Bold", size: 16))
                            Spacer()
                            Image(systemName: showMonero ? "chevron.up" : "chevron.down")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundColor(colors.onSurface)
                        .padding(16)
                        .background(colors.surfaceVariant.opacity(0.85))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    
                    // Monero Address Box
                    if showMonero {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Monero Address:")
                                .font(.custom("Quicksand-Bold", size: 12))
                                .foregroundColor(colors.secondary)
                                .textCase(.uppercase)
                            
                            HStack(alignment: .top, spacing: 10) {
                                Text("88s5Re4p6a3P9TtqaG1G2Yeq5Ppp1w1npXebyLjktuxYgurFAGn4GRbKuPKGbx1pD1bBwohtAriL7JqB12ECp4SnMN1T3q9")
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundColor(colors.onSurface.opacity(0.85))
                                    .lineLimit(4)
                                    .multilineTextAlignment(.leading)
                                
                                Spacer()
                                
                                Button {
                                    UIPasteboard.general.string = "88s5Re4p6a3P9TtqaG1G2Yeq5Ppp1w1npXebyLjktuxYgurFAGn4GRbKuPKGbx1pD1bBwohtAriL7JqB12ECp4SnMN1T3q9"
                                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                                    copiedMonero = true
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                                        copiedMonero = false
                                    }
                                } label: {
                                    Image(systemName: copiedMonero ? "checkmark.circle.fill" : "doc.on.doc.fill")
                                        .font(.system(size: 18))
                                        .foregroundColor(copiedMonero ? Color.green : colors.primary)
                                        .frame(width: 36, height: 36)
                                        .background(colors.primary.opacity(0.12))
                                        .clipShape(Circle())
                                }
                            }
                            
                            if copiedMonero {
                                Text("Copied to clipboard!")
                                    .font(.custom("Quicksand-Bold", size: 12))
                                    .foregroundColor(.green)
                                    .transition(.opacity)
                            }
                        }
                        .padding(16)
                        .background(Color.white.opacity(colorScheme == .dark ? 0.08 : 0.04))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }
                    
                    Spacer(minLength: 16)
                }
                .padding(.horizontal, 20)
            }
            .background(colors.background.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") {
                        showDonateSheet = false
                    }
                    .font(.custom("Quicksand-Bold", size: 15))
                    .foregroundColor(colors.primary)
                }
            }
        }
    }
}
