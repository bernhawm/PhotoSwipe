import SwiftUI
import Photos
import UIKit

// -----------------------------
// ContentView.swift
// Updated: InfiniteScrollingBackground now scrolls horizontally (left → right)
// -----------------------------

// MARK: - Entry
struct ContentView: View {
    var body: some View {
        HomeView()
    }
}

// MARK: - HomeView
struct HomeView: View {
    @State private var photoImages: [UIImage] = []

    var body: some View {
        NavigationStack {
            ZStack {
                // Background (real photos if loaded, otherwise placeholders)
                if !photoImages.isEmpty {
                    InfiniteScrollingBackground(images: photoImages)
                        .ignoresSafeArea()
                } else {
                    InfiniteScrollingBackground(images: placeholderImages())
                        .ignoresSafeArea()
                }

                // Overlay gradient for readability
                LinearGradient(
                    colors: [Color.black.opacity(0.45), Color.clear, Color.black.opacity(0.55)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                // MARK: - Foreground content
                VStack(spacing: 30) {
                    Text("Photo Swipe")
                        .font(.system(size: 34, weight: .semibold, design: .default)) // more professional
                        .foregroundColor(.white)
                        .shadow(radius: 4)
                        .padding(.top, 40)

                    Spacer()

                    VStack(spacing: 16) {
                        NavigationLink("Swipe Photos") {
                            PhotoSwipeView(startFromLast: false)
                        }
                        .buttonStyle(ModernButtonStyle(color: .blue))

                        NavigationLink("Tag Photos") {
                            PhotoTaggingView(startFromLast: false)
                        }
                        .buttonStyle(ModernButtonStyle(color: .purple))

                        NavigationLink("Albums") {
                            AlbumOverview(parentCollection: nil)
                        }
                        .buttonStyle(ModernButtonStyle(color: .green))

                    }

                    Spacer()
                }
                .padding()

                // MARK: - Settings Button
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        NavigationLink(destination: SettingsView()) {
                            Image(systemName: "gearshape.fill")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(.white)
                                .padding()
                                .background(
                                    Circle()
                                        .fill(Color.black.opacity(0.6))
                                )
                                .shadow(radius: 6)
                        }
                        .padding(.trailing, 20)
                        .padding(.bottom, 30)
                    }
                }
            }
            .onAppear {
                requestAndLoadPhotos()
            }
        }
    }

    // MARK: - Photo Authorization & Loading
    private func requestAndLoadPhotos() {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        if status == .authorized || status == .limited {
            loadMostRecentPhotos()
        } else if status == .notDetermined {
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { newStatus in
                if newStatus == .authorized || newStatus == .limited {
                    loadMostRecentPhotos()
                }
            }
        }
    }

    /// Loads most-recent images (limited number) for background.
    private func loadMostRecentPhotos() {
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        fetchOptions.fetchLimit = 15 // keep it small to start

        let assets = PHAsset.fetchAssets(with: .image, options: fetchOptions)
        let manager = PHCachingImageManager()
        let targetSize = CGSize(width: 200, height: 200)

        let requestOptions = PHImageRequestOptions()
        requestOptions.deliveryMode = .opportunistic
        requestOptions.resizeMode = .fast
        requestOptions.isSynchronous = false

        var loadedImages: [UIImage] = []

        assets.enumerateObjects { asset, _, _ in
            manager.requestImage(for: asset,
                                 targetSize: targetSize,
                                 contentMode: .aspectFill,
                                 options: requestOptions) { img, _ in
                if let ui = img {
                    DispatchQueue.main.async {
                        loadedImages.append(ui)
                        self.photoImages = loadedImages
                    }
                }
            }
        }
    }

    // --- Placeholder images
    private func placeholderImages() -> [UIImage] {
        let size = CGSize(width: 300, height: 300)
        let colors: [UIColor] = [.systemBlue, .systemPurple, .systemPink, .systemTeal, .systemIndigo]
        return colors.map { color in
            UIGraphicsImageRenderer(size: size).image { ctx in
                color.setFill()
                ctx.fill(CGRect(origin: .zero, size: size))

                let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                   colors: [UIColor.white.withAlphaComponent(0.06).cgColor,
                                            UIColor.clear.cgColor] as CFArray,
                                   locations: [0.0, 1.0])!
                ctx.cgContext.drawLinearGradient(g, start: .zero,
                                                 end: CGPoint(x: size.width, y: size.height),
                                                 options: [])
            }
        }
    }
}

// MARK: - Modern Button Style
struct ModernButtonStyle: ButtonStyle {
    var color: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity)
            .font(.system(size: 18, weight: .medium)) // <-- professional font baked in
            .foregroundColor(.white)
            .padding(.vertical, 16)
            .padding(.horizontal, 20)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(
                            AngularGradient(
                                gradient: Gradient(stops: [
                                    .init(color: color.opacity(0.95), location: 0.0),
                                    .init(color: color.opacity(0.75), location: 0.4),
                                    .init(color: color.opacity(0.95), location: 1.0)
                                ]),
                                center: .center
                            )
                        )

                    RoundedRectangle(cornerRadius: 14)
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.22), Color.white.opacity(0.03)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .blendMode(.overlay)

                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
                }
            )
            .shadow(color: .black.opacity(configuration.isPressed ? 0.18 : 0.28),
                    radius: configuration.isPressed ? 6 : 10,
                    x: 0, y: configuration.isPressed ? 3 : 6)
            .padding(.horizontal, 40)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.35, dampingFraction: 0.7), value: configuration.isPressed)
    }
}



// MARK: - Infinite Scrolling Background (3-high grid, scrolls horizontally)
struct InfiniteScrollingBackground: View {
    let images: [UIImage]
    var speed: CGFloat = 15 // points per second

    @State private var yOffset: CGFloat = 160

    var body: some View {
        GeometryReader { geo in
            let columns = 3
            let tileSize = geo.size.width / CGFloat(columns)
            let rows = Int(ceil(Double(images.count) / Double(columns)))
            let totalHeight = CGFloat(rows) * tileSize

            ZStack {
                // Repeat twice for seamless scroll
                VStack(spacing: 0) {
                    LazyVGrid(columns: Array(repeating: GridItem(.fixed(tileSize), spacing: 0), count: columns), spacing: 0) {
                        ForEach(images.indices, id: \.self) { idx in
                            Image(uiImage: images[idx])
                                .resizable()
                                .scaledToFill()
                                .frame(width: tileSize, height: tileSize)
                                .clipped()
                        }
                    }
                    LazyVGrid(columns: Array(repeating: GridItem(.fixed(tileSize), spacing: 0), count: columns), spacing: 0) {
                        ForEach(images.indices, id: \.self) { idx in
                            Image(uiImage: images[idx])
                                .resizable()
                                .scaledToFill()
                                .frame(width: tileSize, height: tileSize)
                                .clipped()
                        }
                    }
                }
                .offset(y: yOffset)
                .onAppear {
                    Timer.scheduledTimer(withTimeInterval: 1/60, repeats: true) { _ in
                        yOffset -= speed * (1/60)
                        if yOffset <= -totalHeight {
                            yOffset = 0
                        }
                    }
                }
            }
            .clipped()
        }
    }
}


// MARK: - CollageGrid
struct CollageGrid: View {
    let images: [UIImage]

    var body: some View {
        GeometryReader { geo in
            let columns = 3
            let size = geo.size.width / CGFloat(columns)

            LazyVGrid(columns: Array(repeating: GridItem(.fixed(size), spacing: 0), count: columns), spacing: 0) {
                ForEach(images.indices, id: \.self) { idx in
                    Image(uiImage: images[idx])
                        .resizable()
                        .scaledToFill()
                        .frame(width: size, height: size)
                        .clipped()
                }
            }
        }
    }
}

// MARK: - Settings View placeholder
struct SettingsView: View {
    var body: some View {
        Text("Settings")
            .font(.largeTitle)
            .padding()
    }
}

// MARK: - Previews
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
