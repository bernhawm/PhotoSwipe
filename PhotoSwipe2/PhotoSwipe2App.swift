import SwiftUI

@main
struct PhotoSwipeApp: App {
    // App-wide image cache
    @StateObject private var imageLoader = ImageLoader()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(imageLoader) // make it available everywhere
        }
    }
}
