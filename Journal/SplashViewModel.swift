//
//  SplashViewModel.swift
//  Journal
//
//  Created by Danah Alfanissn on 28/04/1447 AH.
//


import SwiftUI

struct Splash: View {
    @State private var showIntro = false
    @State private var animate = false

    var body: some View {
        ZStack {
            if showIntro {
                Intro() // يفتح شاشة Intro بعد 3 ثواني
            } else {
                // خلفية متدرجة
                LinearGradient(
                    colors: [Color.black, Color(red: 0.06, green: 0.06, blue: 0.08)],
                    startPoint: .top, endPoint: .bottom
                )
                .ignoresSafeArea()

                // محتوى السبلّاش
                VStack(spacing: 20) {
                    Spacer()

                    Image("url")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 140, height: 140)
                        .scaleEffect(animate ? 1.0 : 0.86)
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
                .onAppear {
                    withAnimation(.spring(response: 0.7, dampingFraction: 0.7)) { animate = true }
                    // مؤقت 3 ثواني → انتقال
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        withAnimation(.easeInOut) { showIntro = true }
                    }
                }
            }
        }
        // لإخفاء شريط التنقل بالطريقة الحديثة (iOS 17+)
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
    }
}

#Preview {
    NavigationStack { Splash() }
}
