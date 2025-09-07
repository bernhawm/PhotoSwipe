import SwiftUI

struct ContentView: View {
    var body: some View {
        HomeView()
    }
}

struct HomeView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("📸 Photo Swipe")
                    .font(.largeTitle)
                    .bold()
                    .padding(.bottom, 40)
                
                NavigationLink("Swipe Photos (Newest First)") {
                    PhotoSwipeView(startFromLast: false)
                }
                .buttonStyle(.borderedProminent)
                
                NavigationLink("Swipe Photos (Oldest First)") {
                    PhotoSwipeView(startFromLast: true)
                }
                .buttonStyle(.bordered)
            }
            .padding()
        }
    }
}
