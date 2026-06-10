//
//  WelcomeView.swift
//  WealthPath
//
//  Created by Davis Morales on 6/1/26.
//

import SwiftUI

struct WelcomeView: View {
    var onLogin: () -> Void

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.09, green: 0.38, blue: 0.24),
                    Color(red: 0.04, green: 0.20, blue: 0.12)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 24) {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.08))
                            .frame(width: 140, height: 140)
                        Circle()
                            .fill(Color.white.opacity(0.15))
                            .frame(width: 116, height: 116)
                        Canvas { context, size in
                            let w = size.width
                            let h = size.height

                            // W trend line — last segment is longer to imply a strong finishing trend
                            var path = Path()
                            path.move(to:    CGPoint(x: w * 0.05, y: h * 0.24))
                            path.addLine(to: CGPoint(x: w * 0.26, y: h * 0.82))
                            path.addLine(to: CGPoint(x: w * 0.50, y: h * 0.40))
                            path.addLine(to: CGPoint(x: w * 0.67, y: h * 0.78))
                            path.addLine(to: CGPoint(x: w * 0.97, y: h * 0.06))
                            context.stroke(
                                path,
                                with: .color(.white),
                                style: StrokeStyle(lineWidth: 4.5, lineCap: .round, lineJoin: .round)
                            )

                            // Arrowhead at the tip
                            let tipX = w * 0.97
                            let tipY = h * 0.06
                            let prevX = w * 0.67
                            let prevY = h * 0.78
                            let dx = tipX - prevX
                            let dy = tipY - prevY
                            let len = sqrt(dx * dx + dy * dy)
                            let nx = dx / len
                            let ny = dy / len
                            let arrowLen: CGFloat = 11
                            let arrowAngle: CGFloat = 0.45

                            let lx = tipX - arrowLen * (nx * cos(arrowAngle) - ny * sin(arrowAngle))
                            let ly = tipY - arrowLen * (ny * cos(arrowAngle) + nx * sin(arrowAngle))
                            let rx = tipX - arrowLen * (nx * cos(-arrowAngle) - ny * sin(-arrowAngle))
                            let ry = tipY - arrowLen * (ny * cos(-arrowAngle) + nx * sin(-arrowAngle))

                            var arrow = Path()
                            arrow.move(to: CGPoint(x: lx, y: ly))
                            arrow.addLine(to: CGPoint(x: tipX, y: tipY))
                            arrow.addLine(to: CGPoint(x: rx, y: ry))
                            context.stroke(
                                arrow,
                                with: .color(.white),
                                style: StrokeStyle(lineWidth: 4.5, lineCap: .round, lineJoin: .round)
                            )
                        }
                        .frame(width: 66, height: 46)
                    }

                    VStack(spacing: 12) {
                        Text("Wealth Path")
                            .font(.system(size: 44, weight: .bold, design: .rounded))
                            .foregroundColor(.white)

                        Text("Your path to financial wealth")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.72))
                            .multilineTextAlignment(.center)
                            .lineSpacing(5)
                    }
                }

                Spacer()

                NavigationLink(destination: LoginView(onLogin: onLogin)) {
                    Text("Get Started")
                        .font(.headline)
                        .foregroundColor(.wealthGreen)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 17)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 60)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }
}

#Preview {
    NavigationStack {
        WelcomeView(onLogin: {})
    }
    .tint(.wealthGreen)
}
