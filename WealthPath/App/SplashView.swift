//
//  SplashView.swift
//  WealthPath
//

import SwiftUI

struct SplashView: View {
    @State private var rotation: Double = 0

    var body: some View {
        ZStack {
            Color.wealthGreen.ignoresSafeArea()
            WLogoShape()
                .stroke(.white, style: StrokeStyle(lineWidth: 8, lineCap: .round, lineJoin: .round))
                .frame(width: 44, height: 31)
                .rotationEffect(.degrees(rotation))
                .onAppear {
                    withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                        rotation = 360
                    }
                }
        }
    }
}

private struct WLogoShape: Shape {
    // Matches the proportional coordinates used to generate the app icon
    private let linePoints: [(CGFloat, CGFloat)] = [
        (0.05, 0.24), (0.26, 0.82), (0.50, 0.40), (0.67, 0.78), (0.97, 0.06)
    ]

    func path(in rect: CGRect) -> Path {
        let pts = linePoints.map { CGPoint(x: $0.0 * rect.width, y: $0.1 * rect.height) }

        var p = Path()
        p.move(to: pts[0])
        pts.dropFirst().forEach { p.addLine(to: $0) }

        // Arrowhead at the tip
        let tip = pts[4]
        let prev = pts[3]
        let dx = tip.x - prev.x
        let dy = tip.y - prev.y
        let len = sqrt(dx * dx + dy * dy)
        let nx = dx / len, ny = dy / len
        let aLen: CGFloat = rect.width * 0.13
        let angle: CGFloat = 0.45

        let lx = tip.x - aLen * (nx * cos(angle) - ny * sin(angle))
        let ly = tip.y - aLen * (ny * cos(angle) + nx * sin(angle))
        let rx = tip.x - aLen * (nx * cos(-angle) - ny * sin(-angle))
        let ry = tip.y - aLen * (ny * cos(-angle) + nx * sin(-angle))

        p.move(to: CGPoint(x: lx, y: ly))
        p.addLine(to: tip)
        p.addLine(to: CGPoint(x: rx, y: ry))

        return p
    }
}

#Preview {
    SplashView()
}
