import Foundation
import Testing
@testable import Wardrobe

struct StylingConsentButtonPresentationTests {
    @Test func enabledColorsMeetMinimumContrast() {
        expectMinimumContrast(
            StylingConsentButtonPalette.colors(isEnabled: true, isPressed: false)
        )
    }

    @Test func pressedColorsMeetMinimumContrast() {
        expectMinimumContrast(
            StylingConsentButtonPalette.colors(isEnabled: true, isPressed: true)
        )
    }

    @Test func disabledColorsMeetMinimumContrast() {
        expectMinimumContrast(
            StylingConsentButtonPalette.colors(isEnabled: false, isPressed: false)
        )
    }

    @Test func contrastMathUsesSRGBLinearization() {
        let black = StylingConsentButtonSRGB(hex: 0x000000)
        let white = StylingConsentButtonSRGB(hex: 0xFFFFFF)

        #expect(abs(contrastRatio(black, white) - 21) < 0.001)
    }

    private func expectMinimumContrast(_ colors: StylingConsentButtonColors) {
        #expect(contrastRatio(colors.background, colors.foreground) >= 4.5)
    }

    private func contrastRatio(
        _ first: StylingConsentButtonSRGB,
        _ second: StylingConsentButtonSRGB
    ) -> Double {
        let firstLuminance = relativeLuminance(first)
        let secondLuminance = relativeLuminance(second)
        let lighter = max(firstLuminance, secondLuminance)
        let darker = min(firstLuminance, secondLuminance)

        return (lighter + 0.05) / (darker + 0.05)
    }

    private func relativeLuminance(_ color: StylingConsentButtonSRGB) -> Double {
        0.2126 * linearized(color.red)
            + 0.7152 * linearized(color.green)
            + 0.0722 * linearized(color.blue)
    }

    private func linearized(_ channel: Double) -> Double {
        if channel <= 0.04045 {
            return channel / 12.92
        }

        return pow((channel + 0.055) / 1.055, 2.4)
    }
}
