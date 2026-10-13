import FamilyControls
import SwiftUI

struct AllowedAppsPicker: View {
  @State var selection: FamilyActivitySelection
  let save: (FamilyActivitySelection) -> Void
  let cancel: () -> Void

  var body: some View {
    NavigationStack {
      FamilyActivityPicker(
        headerText: "Select the apps you want available while locked in. Everything else will be restricted.",
        footerText: "Choose 1–50 apps before locking in. Expand categories to select individual apps.",
        selection: $selection
      )
      .navigationTitle("Choose what stays")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel", action: cancel)
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Save Allowed Apps") {
            save(selection)
          }
        }
      }
    }
  }
}
