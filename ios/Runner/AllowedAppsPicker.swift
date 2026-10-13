import FamilyControls
import SwiftUI

enum AllowedAppsPickerSaveResult {
  case completed
  case limitExceeded
}

struct AllowedAppsPicker: View {
  @State var selection: FamilyActivitySelection
  @State private var limitMessage: String?
  let save: (FamilyActivitySelection) -> AllowedAppsPickerSaveResult
  let cancel: () -> Void

  var body: some View {
    NavigationStack {
      VStack(spacing: 0) {
        FamilyActivityPicker(
          headerText: "Select the apps you want available while locked in. Everything else will be restricted.",
          footerText: "Choose up to 50 apps.",
          selection: $selection
        )
        if let limitMessage {
          Text(limitMessage)
            .font(.callout)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal)
            .padding(.vertical, 8)
            .accessibilityLabel(limitMessage)
        }
      }
      .navigationTitle("Choose what stays")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel", action: cancel)
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Save Allowed Apps") {
            limitMessage = nil
            if save(selection) == .limitExceeded {
              limitMessage = "Unbound supports up to 50 allowed apps."
            }
          }
        }
      }
    }
  }
}
