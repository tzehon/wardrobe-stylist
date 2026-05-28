import GoogleSignIn
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
                .onOpenURL { url in
                    // OAuth callback: route URL-scheme redirects to the GoogleSignIn SDK
                    // so it can complete the sign-in flow.
                    _ = GIDSignIn.sharedInstance.handle(url)
                }
        }
        .modelContainer(container)
    }
}
