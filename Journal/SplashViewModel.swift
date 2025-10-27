//
//  SplashViewModel.swift
//  Journal
//
//  Created by Danah Alfanissn on 28/04/1447 AH.
//


import SwiftUI
import Combine
@MainActor
final class SplashViewModel: ObservableObject {
    @Published var showIntro = false
    @Published var animate = false

    func start() {
        withAnimation(.spring(response: 0.7, dampingFraction: 0.7)) {
            animate = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            withAnimation(.easeInOut) { self.showIntro = true }
        }
    }
}
