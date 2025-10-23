//
//  Splash.swift
//  Journal
//
//  Created by Danah Alfanissn on 01/05/1447 AH.
//

import SwiftUI

struct Splash: View {
    @StateObject private var vm = SplashViewModel()

    var body: some View {
        ZStack {
            // الخلفية العامة (ثابتة لتجنب السواد)
            LinearGradient(
                colors: [Color.black, Color(red: 0.06, green: 0.06, blue: 0.08)],
                startPoint: .top, endPoint: .bottom
                
            )
            .ignoresSafeArea()

            if vm.showIntro {
                // الانتقال السلس للصفحة التالية
                IntroUI()
                    .transition(.opacity)
            } else {
                VStack(spacing: 20) {
                    Spacer()

                    Image("Splash page2")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 140, height: 140)
                        .scaleEffect(vm.animate ? 1.0 : 0.86)
                        .shadow(color: .black.opacity(0.35), radius: 18, x: 0, y: 6)

                    Text("Journali")
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .foregroundColor(.white)

                    Text("Your thoughts, your story")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.85))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)

                    Spacer()
                }
                .padding(.vertical, 48)
                .task { vm.start() }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
    }
}

#Preview { NavigationStack { Splash() } }
