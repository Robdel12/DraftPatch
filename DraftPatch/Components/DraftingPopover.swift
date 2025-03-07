//
//  DraftingPopover.swift
//  DraftPatch
//
//  Created by Robert DeLuca on 3/6/25.
//

import SwiftUI

struct DraftingPopover: View {
  @Binding var selectedDraftApp: DraftApp?
  @Binding var isShowingPopover: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text("Draft with")
        .font(.title3)

      ForEach(DraftApp.allCases) { app in
        let selected = selectedDraftApp == app
        let isDisabled = selectedDraftApp != nil && !selected

        HStack {
          HStack(spacing: 8) {
            Image(app.name)
              .resizable()
              .scaledToFit()
              .frame(width: 32, height: 32)

            Text(app.name)
              .foregroundStyle(isDisabled ? .gray : .primary)
          }

          Spacer()

          Button(action: {
            if selected {
              selectedDraftApp = nil
            } else {
              selectedDraftApp = app
            }

            isShowingPopover = false
          }) {
            Image(systemName: selected ? "xmark.circle.fill" : "checkmark.circle")
              .foregroundStyle(selected ? .red : (isDisabled ? .gray : .blue))
              .font(.title3)
          }
          .buttonStyle(.plain)
          .disabled(isDisabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      }
    }
    .padding()
    .frame(minWidth: 200)
  }
}
