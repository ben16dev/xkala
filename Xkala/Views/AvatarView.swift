import SwiftUI

struct AvatarView: View {
    private let mood: AvatarMood
    private let size: CGFloat

    @AppStorage("selectedAvatarKind") private var selectedAvatarKindRawValue = AvatarKind.salamander.rawValue

    private var selectedAvatarKind: AvatarKind {
        AvatarKind(rawValue: selectedAvatarKindRawValue) ?? .salamander
    }

    private var resolvedAssetName: String {
        selectedAvatarKind.assetName(for: mood)
    }

    init(size: CGFloat = 48, mood: AvatarMood = .idle) {
        self.size = size
        self.mood = mood
    }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var breathing = false

    private var breatheScale: CGFloat {
        reduceMotion ? 1.0 : (breathing ? 1.015 : 0.985)
    }

    /// Glow solo sobre el avatar (no muta `AvatarMoodCalculator`).
    /// Misma potencia para strong / happy / tired; `idle` sin halo.
    private var glowColor: Color {
        switch mood {
        case .strong:
            return Color.yellow.opacity(0.80)
        case .happy:
            return Color.green.opacity(0.80)
        case .tired:
            return Color.blue.opacity(0.80)
        case .idle:
            return .clear
        }
    }

    private var glowRadius: CGFloat {
        switch mood {
        case .strong, .happy, .tired:
            return 20
        case .idle:
            return 0
        }
    }

    var body: some View {
        Image(resolvedAssetName)
            .renderingMode(.original)
            .resizable()
            .scaledToFit()
            .scaleEffect(selectedAvatarKind.imageScale * 1.12 * breatheScale)
            .offset(y: selectedAvatarKind.imageYOffset * size)
            .frame(width: size, height: size)
            .clipped()
            .shadow(color: glowColor, radius: glowRadius)
            .shadow(color: glowColor.opacity(0.55), radius: glowRadius * 0.55)
            .overlay {
                if glowRadius > 0 {
                    Circle()
                        .stroke(glowColor.opacity(0.22), lineWidth: 2)
                        .blur(radius: 8)
                        .allowsHitTesting(false)
                }
            }
            .id(resolvedAssetName)
            .transaction { transaction in
                if reduceMotion {
                    transaction.disablesAnimations = true
                }
            }
            .animation(
                .easeInOut(duration: 2.4).repeatForever(autoreverses: true),
                value: breathing
            )
            .onAppear {
                breathing = true
            }
            .onChange(of: reduceMotion) { _, newValue in
                if newValue {
                    breathing = false
                } else {
                    breathing = true
                }
            }
    }
}
