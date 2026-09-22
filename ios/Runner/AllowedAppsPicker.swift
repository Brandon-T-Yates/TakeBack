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
          headerText: "Choose individual apps to keep accessible while locked in.",
          footerText: "Choose 1–50 apps before locking in. Categories and websites are not supported. Expand categories to select individual apps.",
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
