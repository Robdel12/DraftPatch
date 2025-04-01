//
//  LoadingAnimationView.swift
//  DraftPatch
//
//  Created by Robert DeLuca on 4/1/25.
//

import SwiftUI

struct LoadingAnimationView: View {
  @State private var animate = false

  var body: some View {
    HStack(spacing: 8) {
      Circle()
        .frame(width: 10, height: 10)
        .scaleEffect(animate ? 1 : 0.5)
        .animation(Animation.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: animate)
      Circle()
        .frame(width: 10, height: 10)
        .scaleEffect(animate ? 1 : 0.5)
        .animation(
          Animation.easeInOut(duration: 0.6).delay(0.2).repeatForever(autoreverses: true), value: animate)
      Circle()
        .frame(width: 10, height: 10)
        .scaleEffect(animate ? 1 : 0.5)
        .animation(
          Animation.easeInOut(duration: 0.6).delay(0.4).repeatForever(autoreverses: true), value: animate)
    }
    .onAppear {
      animate = true
    }
  }
}
