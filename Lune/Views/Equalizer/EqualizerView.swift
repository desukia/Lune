//
//  EqualizerView.swift
//  Lune
//
//  10-band Equalizer, Reverb, Pitch, Speed, and Bass Boost controls matching EqualizerActivity.kt.
//

import SwiftUI

@MainActor
public struct EqualizerView: View {
    let primaryColor: Color
    @Environment(\.dismiss) private var dismiss
    
    @State private var gains: [Float] = Array(repeating: 0.0, count: 10)
    @State private var selectedPreset: String = "Flat"
    @State private var bassBoost: Float = 0.0
    @State private var selectedReverb: ReverbPresetType = .off
    @State private var reverbMix: Float = 40.0
    @State private var pitchSemitones: Float = 0.0
    @State private var playbackRate: Float = 1.0
    
    private let eq = EqualizerEngine.shared
    
    public init(primaryColor: Color = Color(hex: 0xD0BCFF)) {
        self.primaryColor = primaryColor
    }
    
    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Preset Selector
                    presetsPicker
                    
                    // 10-Band EQ Sliders
                    tenBandSliders
                    
                    // Bass Boost Slider
                    bassBoostSection
                    
                    // Reverb Environments
                    reverbSection
                    
                    // Pitch & Speed Controls
                    pitchAndSpeedSection
                    
                    // Restore Defaults Button
                    Button {
                        restoreDefaults()
                    } label: {
                        Text("Restore Defaults")
                            .font(.custom("Quicksand-Bold", size: 14))
                            .foregroundColor(.secondary)
                            .padding(.vertical, 12)
                            .padding(.horizontal, 24)
                            .liquidGlass(.regular, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .padding(.bottom, 24)
                }
                .padding(.top, 16)
            }
            .navigationTitle("Equalizer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.custom("Quicksand-Bold", size: 15))
                }
            }
        }
    }
    
    // MARK: - Subsections
    
    private var presetsPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(EqPreset.presets) { preset in
                    let isSelected = selectedPreset == preset.name
                    Button {
                        selectedPreset = preset.name
                        gains = preset.gains
                        eq.applyPreset(preset)
                    } label: {
                        Text(preset.name)
                            .font(.custom(isSelected ? "Quicksand-Bold" : "Quicksand-Regular", size: 13))
                            .foregroundColor(isSelected ? .white : .primary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .liquidGlass(
                                isSelected ? .tinted(primaryColor, opacity: 0.9) : .regular,
                                in: Capsule()
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
    }
    
    private var tenBandSliders: some View {
        VStack(spacing: 12) {
            HStack(alignment: .bottom, spacing: 6) {
                ForEach(0..<10, id: \.self) { i in
                    VStack(spacing: 8) {
                        Text(String(format: "%+.0f", gains[i]))
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(primaryColor)
                        
                        // Vertical Slider
                        CustomVerticalSlider(
                            value: Binding(
                                get: { gains[i] },
                                set: { val in
                                    gains[i] = val
                                    selectedPreset = "Custom"
                                    eq.setBandGain(index: i, gain: val)
                                }
                            ),
                            range: -12...12,
                            accentColor: primaryColor
                        )
                        .frame(height: 140)
                        
                        Text(formatFrequency(eq.frequencies[i]))
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(16)
            .liquidGlass(.regular, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .padding(.horizontal, 16)
        }
    }
    
    private var bassBoostSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("EXTRA BASS")
                    .font(.custom("Quicksand-Bold", size: 14))
                Spacer()
                Text(String(format: "%.0f dB", bassBoost))
                    .font(.custom("Quicksand-Bold", size: 13))
                    .foregroundColor(primaryColor)
            }
            
            Slider(value: $bassBoost, in: 0...12, step: 1) { _ in
                eq.setBassBoost(bassBoost)
            }
            .tint(primaryColor)
        }
        .padding(16)
        .liquidGlass(.regular, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .padding(.horizontal, 16)
    }
    
    private var reverbSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Reverb Environment")
                .font(.custom("Quicksand-Bold", size: 14))
            
            Picker("Reverb", selection: $selectedReverb) {
                ForEach(ReverbPresetType.allCases) { opt in
                    Text(opt.rawValue).tag(opt)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: selectedReverb) { _, rev in
                eq.setReverbPreset(rev, blend: reverbMix)
            }
        }
        .padding(16)
        .liquidGlass(.regular, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .padding(.horizontal, 16)
    }
    
    private var pitchAndSpeedSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Speed
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Playback Speed")
                        .font(.custom("Quicksand-Bold", size: 14))
                    Spacer()
                    Text(String(format: "%.2fx", playbackRate))
                        .font(.custom("Quicksand-Bold", size: 13))
                        .foregroundColor(primaryColor)
                }
                Slider(value: $playbackRate, in: 0.5...2.0, step: 0.05) { _ in
                    eq.setSpeed(playbackRate)
                }
                .tint(primaryColor)
            }
            
            Divider()
            
            // Pitch
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Pitch Shift")
                        .font(.custom("Quicksand-Bold", size: 14))
                    Spacer()
                    Text(String(format: "%+.1f semitones", pitchSemitones))
                        .font(.custom("Quicksand-Bold", size: 13))
                        .foregroundColor(primaryColor)
                }
                Slider(value: $pitchSemitones, in: -12...12, step: 1) { _ in
                    eq.setPitch(pitchSemitones * 100)
                }
                .tint(primaryColor)
            }
        }
        .padding(16)
        .liquidGlass(.regular, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .padding(.horizontal, 16)
    }
    
    private func restoreDefaults() {
        gains = Array(repeating: 0.0, count: 10)
        selectedPreset = "Flat"
        bassBoost = 0.0
        selectedReverb = .off
        pitchSemitones = 0.0
        playbackRate = 1.0
        eq.applyPreset(EqPreset.presets[0])
        eq.setBassBoost(0)
        eq.setReverbPreset(.off)
        eq.setPitch(0)
        eq.setSpeed(1.0)
    }
    
    private func formatFrequency(_ hz: Float) -> String {
        if hz >= 1000 {
            return String(format: "%.0fk", hz / 1000)
        } else {
            return String(format: "%.0f", hz)
        }
    }
}

// Vertical Slider component for 10-band EQ
struct CustomVerticalSlider: View {
    @Binding var value: Float
    let range: ClosedRange<Float>
    let accentColor: Color
    
    var body: some View {
        GeometryReader { geo in
            let height = geo.size.height
            let normalized = (value - range.lowerBound) / (range.upperBound - range.lowerBound)
            let thumbY = height * CGFloat(1.0 - normalized)
            
            ZStack(alignment: .top) {
                Capsule()
                    .fill(Color.primary.opacity(0.12))
                    .frame(width: 4, height: height)
                
                Circle()
                    .fill(accentColor)
                    .frame(width: 16, height: 16)
                    .shadow(radius: 2)
                    .offset(y: max(0, min(height - 16, thumbY - 8)))
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        let clampedY = max(0, min(height, drag.location.y))
                        let pct = 1.0 - Float(clampedY / height)
                        value = range.lowerBound + pct * (range.upperBound - range.lowerBound)
                    }
            )
        }
    }
}
