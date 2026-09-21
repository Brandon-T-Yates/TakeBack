import FamilyControls
import SwiftUI

struct AllowedAppsPicker: View {
  @State var selection: FamilyActivitySelection
  @State private var validationMessage: String?
  let save: (FamilyActivitySelection) throws -> Void
  let cancel: () -> Void

  var body: some View {
    NavigationStack {
      VStack(spacing: 0) {
        FamilyActivityPicker(
          headerText: "Choose individual apps to ALLOW during a future lock session.",
          footerText: "Categories and websites are not supported. Expand a category to select individual apps. No apps are blocked yet.",
          selection: $selection
        )
        if let message = validationMessage {
          Text(message)
            .font(.callout)
            .foregroundStyle(.red)
            .padding()
            .accessibilityLabel(message)
        }
      }
      .navigationTitle("Allowed Apps")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel", action: cancel)
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Save Allowed Apps") {
            do {
              try save(selection)
            } catch {
              validationMessage = error.localizedDescription
            }
          }
        }
      }
    }
  }
}
