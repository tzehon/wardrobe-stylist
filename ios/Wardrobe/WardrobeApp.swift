import SwiftData
import SwiftUI

@main
struct WardrobeApp: App {
    let container: ModelContainer

    init() {
        do {
            container = try ModelContainer(for: Item.self, Outfit.self, WearLog.self)
        } catch {
            fatalError("Failed to create the SwiftData ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(container)
    }
}
