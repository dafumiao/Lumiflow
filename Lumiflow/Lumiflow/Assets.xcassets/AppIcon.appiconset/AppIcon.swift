import SwiftUI

struct AppIconGenerator: View {
    var body: some View {
        ZStack {
            // 背景渐变
            LinearGradient(
                gradient: Gradient(colors: [Color(hex: "#3A7BD5"), Color(hex: "#00d2ff")]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // 中心光圈
            Circle()
                .fill(Color(hex: "#DEF3F8").opacity(0.3))
                .frame(width: 600, height: 600)
            
            // 灯光放射线
            ForEach(0..<8) { i in
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(hex: "#FFE15C"))
                    .frame(width: 40, height: 300)
                    .offset(y: -180)
                    .rotationEffect(.degrees(Double(i) * 45))
                    .opacity(0.7)
            }
            
            // 相机外壳
            RoundedRectangle(cornerRadius: 60)
                .fill(Color(hex: "#2D4263"))
                .frame(width: 400, height: 300)
            
            // 相机镜头
            ZStack {
                Circle()
                    .fill(Color(hex: "#FFFFFF"))
                    .frame(width: 240, height: 240)
                Circle()
                    .fill(Color(hex: "#3B7FE6"))
                    .frame(width: 180, height: 180)
                Circle()
                    .fill(Color(hex: "#1D3461"))
                    .frame(width: 120, height: 120)
                Circle()
                    .fill(Color(hex: "#FFFFFF"))
                    .frame(width: 60, height: 60)
            }
            
            // 闪光灯
            Circle()
                .fill(Color(hex: "#FFE15C"))
                .frame(width: 40, height: 40)
                .offset(x: 150, y: -100)
        }
        .frame(width: 1024, height: 1024)
        .clipShape(RoundedRectangle(cornerRadius: 220))
        .overlay(
            RoundedRectangle(cornerRadius: 220)
                .stroke(Color.white, lineWidth: 1)
        )
    }
}

// 颜色扩展
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// 预览
#Preview {
    AppIconGenerator()
} 