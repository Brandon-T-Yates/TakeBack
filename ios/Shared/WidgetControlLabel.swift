import SwiftUI

/// The exact widget control content, also renderable in native tests with inert states.
struct WidgetControlLabel: View {
  let state: WidgetRestrictionState
  private let canvas = Color(red: 247 / 255, green: 246 / 255, blue: 242 / 255)
  var body: some View {
    VStack(spacing: 10) {
      Image(systemName: state.symbol)
        .font(.system(size: 34, weight: .medium))
        .opacity(state.uncertain ? 0.55 : 1)
        .overlay(alignment: .bottomTrailing) {
          if state.uncertain {
            Image(systemName: "questionmark.circle.fill")
              .font(.system(size: 15)).background(canvas, in: Circle()).offset(x: 8, y: 3)
          }
        }
      Text(state.title).font(.system(size: 15, weight: .semibold))
        .minimumScaleFactor(0.7).lineLimit(1)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}
