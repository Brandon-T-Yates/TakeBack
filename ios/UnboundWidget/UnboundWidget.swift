import SwiftUI
import WidgetKit

struct UnboundEntry: TimelineEntry {
  let date: Date
  let state: WidgetRestrictionState
}

struct UnboundProvider: TimelineProvider {
  func placeholder(in context: Context) -> UnboundEntry { UnboundEntry(date: .now, state: .setup) }
  func getSnapshot(in context: Context, completion: @escaping (UnboundEntry) -> Void) {
    entry(completion: completion)
  }
  func getTimeline(in context: Context, completion: @escaping (Timeline<UnboundEntry>) -> Void) {
    entry { entry in
      completion(Timeline(entries: [entry], policy: .after(entry.date.addingTimeInterval(30 * 60))))
    }
  }
  private func entry(completion: @escaping (UnboundEntry) -> Void) {
    Task { @MainActor in
      #if targetEnvironment(simulator)
      let state = WidgetRestrictionState.setup
      #else
      let state = WidgetRestrictionState(NativeRestrictionCoordinator().snapshot())
      #endif
      completion(UnboundEntry(date: .now, state: state))
    }
  }
}

struct UnboundWidgetView: View {
  let entry: UnboundEntry
  private let ink = Color(red: 32 / 255, green: 61 / 255, blue: 54 / 255)
  private let canvas = Color(red: 247 / 255, green: 246 / 255, blue: 242 / 255)

  var body: some View {
    VStack(spacing: 12) {
      Text("Unbound").font(.system(size: 18, weight: .bold))
      if let enabled = entry.state.requestedEnabled {
        Button(intent: SetLockdownIntent(enabled: enabled)) { control }
          .buttonStyle(.plain)
          .accessibilityLabel(entry.state.title)
          .accessibilityValue(entry.state.accessibilityState)
      } else {
        // A non-interactive widget tap opens its containing app using WidgetKit.
        control.accessibilityElement(children: .combine)
      }
    }
    .foregroundStyle(ink)
    .containerBackground(canvas, for: .widget)
  }

  private var control: some View {
    WidgetControlLabel(state: entry.state).invalidatableContent()
  }
}

@main
struct UnboundWidget: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: NativeWidgetChanges.kind, provider: UnboundProvider()) { entry in
      UnboundWidgetView(entry: entry)
    }
    .configurationDisplayName("Unbound")
    .description("Lock in or unlock your allowed-app restrictions.")
    .supportedFamilies([.systemSmall])
  }
}
