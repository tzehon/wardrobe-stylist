import SwiftData
import SwiftUI

struct ContentView: View {
    @Query private var items: [Item]

    var body: some View {
        NavigationStack {
            if items.isEmpty {
                ContentUnavailableView {
                    Label("Your wardrobe is empty", systemImage: "tshirt")
                } description: {
                    Text("Connect Gmail or add photos to start building your catalog.")
                }
                .navigationTitle("Wardrobe")
            } else {
                List(items) { item in
                    Text(item.name)
                }
                .navigationTitle("Wardrobe")
            }
        }
    }
}
