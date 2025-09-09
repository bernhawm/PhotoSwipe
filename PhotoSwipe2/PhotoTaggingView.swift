import SwiftUI
import Photos
import UIKit

struct PhotoTaggingView: View {
    @Environment(\.dismiss) var dismiss

    @State private var allFetchedAssets: [PHAsset] = []  // all assets, but not all loaded at once
    @State private var photos: [PHAsset] = []            // currently loaded batch
    @State private var currentIndex: Int = 0
    @State private var photoImages: [UIImage] = []
    @State private var testImages: [UIImage] = []
    @State private var hideAlreadyInAlbums = false
    
    @State private var batchSize = 20
    @State private var loadIndex = 0

    @AppStorage("groupNames") private var storedGroupNamesData: Data = Data()
    @State private var groupNames: [String] = ["Group Wade", "Group 2", "Group 3"]
    @State private var newGroupNames: [String] = ["", "", ""]
    @State private var groupPhotos: [[PHAsset]] = [[], [], []]

    @State private var albums: [PHAssetCollection] = []
    @State private var selectedAlbum: PHAssetCollection?
    @State private var showAlbumPicker = false
    @State private var showSaveConfirmation = false
  
    @State private var dragOffset: CGSize = .zero

    var startFromLast: Bool
    private var allImages: [UIImage] { testImages + photoImages }

    // MARK: - Load group names from AppStorage
    private func loadGroupNames() {
        if let decoded = try? JSONDecoder().decode([String].self, from: storedGroupNamesData),
           decoded.count == groupNames.count {
            groupNames = decoded
        }
    }

    // MARK: - Save group names to AppStorage
    private func saveGroupNames() {
        if let encoded = try? JSONEncoder().encode(groupNames) {
            storedGroupNamesData = encoded
        }
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: [.blue.opacity(0.15), .purple.opacity(0.15)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()

            VStack {
                // Group pill bar + skip
                HStack {
                    ForEach(0..<groupNames.count, id: \.self) { idx in
                        Text(groupNames[idx])
                            .font(.subheadline.weight(.semibold))
                            .padding(.vertical, 6)
                            .padding(.horizontal, 12)
                            .background(groupHighlight(for: idx) ? Color.blue.opacity(0.7) : Color.gray.opacity(0.25))
                            .foregroundColor(.white)
                            .clipShape(Capsule())
                            .shadow(radius: groupHighlight(for: idx) ? 5 : 0)
                        if idx < groupNames.count - 1 { Spacer() }
                    }

                    Text("Skip")
                        .font(.subheadline.weight(.semibold))
                        .padding(.vertical, 6)
                        .padding(.horizontal, 12)
                        .background(dragOffset.height > 150 ? Color.red.opacity(0.7) : Color.gray.opacity(0.25))
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                        .shadow(radius: dragOffset.height > 150 ? 5 : 0)
                }
                .padding(.horizontal)

                // Toggle
                Button(hideAlreadyInAlbums ? "Hide Mode: ON" : "Hide Mode: OFF") {
                    hideAlreadyInAlbums.toggle()
                    filterPhotos()
                }
                .font(.subheadline.bold())
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(hideAlreadyInAlbums ? Color.red : Color.gray.opacity(0.5))
                .foregroundColor(.white)
                .cornerRadius(10)
                .padding(.top, 4)

                Spacer()

                // Photo Swiper
                if currentIndex < allImages.count {
                    Image(uiImage: allImages[currentIndex])
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .cornerRadius(16)
                        .shadow(radius: 10)
                        .offset(dragOffset)
                        .rotationEffect(.degrees(Double(dragOffset.width / 20)))
                        .gesture(
                            DragGesture()
                                .onChanged { value in dragOffset = value.translation }
                                .onEnded { value in handleSwipe(value) }
                        )
                        .padding()
                        .transition(.scale)
                        .animation(.spring(), value: currentIndex)
                } else {
                    Text("🎉 Tagging complete!")
                        .font(.headline)
                        .padding()
                        .foregroundColor(.secondary)
                }
            }
        }
        .sheet(isPresented: $showAlbumPicker) { albumEditor }
        .sheet(isPresented: $showSaveConfirmation) { saveConfirmationModal }
        .onAppear {
            loadGroupNames()
            loadPhotosAndAlbums()
        }
        .navigationTitle("Photo Tagging")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Albums") { showAlbumPicker = true }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Save & Exit") {
                    saveGroupNames()
                    showSaveConfirmation = true
                }
            }
        }
    }

    // MARK: - Swipe Handling
    private func handleSwipe(_ value: DragGesture.Value) {
        let horizontal = value.translation.width
        let vertical = value.translation.height
        let threshold: CGFloat = 120

        if vertical > 150 {
            currentIndex += 1
        } else if horizontal < -threshold {
            swipeLeft()
        } else if horizontal > threshold {
            swipeRight()
        } else {
            swipeCenter()
        }

        dragOffset = .zero

        // Prefetch more if we’re 10 into the batch
        if currentIndex % 10 == 0 {
            loadNextBatch()
        }
    }

    // MARK: - Highlight logic for drag
    private func groupHighlight(for index: Int) -> Bool {
        let horizontal = dragOffset.width
        let threshold: CGFloat = 120
        switch index {
        case 0: return horizontal < -threshold
        case 1: return abs(horizontal) < threshold
        case 2: return horizontal > threshold
        default: return false
        }
    }

    // MARK: - Album Editor
    private var albumEditor: some View {
        VStack {
            Text("✏️ Edit Groups")
                .font(.headline)
                .padding()

            ScrollView {
                VStack(spacing: 15) {
                    ForEach(0..<groupNames.count, id: \.self) { idx in
                        HStack {
                            Text(groupNames[idx])
                                .frame(width: 120, alignment: .leading)
                                .padding(8)
                                .background(Color.gray.opacity(0.2))
                                .cornerRadius(8)

                            VStack(spacing: 0) {
                                TextField("New name...", text: $newGroupNames[idx])
                                    .textFieldStyle(.roundedBorder)
                                    .padding(.vertical, 8)

                                if !newGroupNames[idx].isEmpty {
                                    let suggestions = albums.filter {
                                        ($0.localizedTitle ?? "").localizedCaseInsensitiveContains(newGroupNames[idx])
                                    }
                                    if !suggestions.isEmpty {
                                        VStack(alignment: .leading, spacing: 0) {
                                            ForEach(suggestions, id: \.self) { album in
                                                Button {
                                                    if let title = album.localizedTitle {
                                                        newGroupNames[idx] = title
                                                    }
                                                } label: {
                                                    Text(album.localizedTitle ?? "")
                                                        .padding(6)
                                                        .frame(maxWidth: .infinity, alignment: .leading)
                                                }
                                                .background(Color.gray.opacity(0.1))
                                            }
                                        }
                                        .border(Color.gray.opacity(0.3))
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }

            Button("Save & Exit") {
                for (idx, newName) in newGroupNames.enumerated() {
                    if !newName.isEmpty { groupNames[idx] = newName }
                    if !newName.isEmpty, !groupPhotos[idx].isEmpty,
                       !albums.contains(where: { $0.localizedTitle == newName }) {
                        createAlbum(named: newName)
                    }
                    newGroupNames[idx] = ""
                }
                saveGroupNames()
                showAlbumPicker = false
            }
            .buttonStyle(.borderedProminent)
            .padding()
        }
    }

    // MARK: - Save Confirmation Modal
    private var saveConfirmationModal: some View {
        VStack {
            Text("✅ Confirm Save")
                .font(.headline)
                .padding()

            ScrollView {
                ForEach(0..<groupNames.count, id: \.self) { idx in
                    VStack(alignment: .leading) {
                        Button(groupNames[idx]) { }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue.opacity(0.2))
                            .cornerRadius(8)

                        if !groupPhotos[idx].isEmpty {
                            Text("\(groupPhotos[idx].count) new photos will be added.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)

                            AssetThumbnailGrid(assets: groupPhotos[idx], maxCount: 10)
                                .padding(.top, 4)
                        } else {
                            Text("No new photos selected.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 5)
                }
            }

            HStack {
                Button("Cancel") { showSaveConfirmation = false }
                    .buttonStyle(.bordered)
                Spacer()
                Button("Confirm & Save") {
                    saveToSelectedAlbum()
                    showSaveConfirmation = false
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .padding()
    }

    // MARK: - Photo & Album Helpers
    private func loadPhotosAndAlbums() {
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
            guard status == .authorized || status == .limited else { return }
            fetchAlbums()
            fetchAllPhotos()
        }
    }

    private func fetchAllPhotos() {
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: startFromLast)]
        let fetched = PHAsset.fetchAssets(with: .image, options: fetchOptions)
        var assets: [PHAsset] = []
        fetched.enumerateObjects { asset, _, _ in assets.append(asset) }
        DispatchQueue.main.async {
            self.allFetchedAssets = assets
            self.loadNextBatch()
        }
    }

    // Load next batch of photos
    private func loadNextBatch() {
        let endIndex = min(loadIndex + batchSize, allFetchedAssets.count)
        guard loadIndex < endIndex else { return }
        
        let newBatch = Array(allFetchedAssets[loadIndex..<endIndex])
        loadIndex = endIndex
        
        let manager = PHCachingImageManager()
        let targetSize = CGSize(width: 1000, height: 1000)
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isSynchronous = false
        options.isNetworkAccessAllowed = true

        for asset in newBatch {
            manager.requestImage(for: asset,
                                 targetSize: targetSize,
                                 contentMode: .aspectFit,
                                 options: options) { image, _ in
                if let img = image {
                    DispatchQueue.main.async {
                        self.photos.append(asset)
                        self.photoImages.append(img)
                    }
                }
            }
        }
    }

    private func fetchAlbums() {
        let collections = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: nil)
        var temp: [PHAssetCollection] = []
        collections.enumerateObjects { collection, _, _ in temp.append(collection) }
        DispatchQueue.main.async { self.albums = temp }
    }

    private func createAlbum(named name: String) {
        PHPhotoLibrary.shared().performChanges({
            PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: name)
        }) { success, error in
            if success { fetchAlbums() }
            if let error = error { print("Create album error:", error) }
        }
    }

    // MARK: - Swiping Actions
    private func swipeLeft() { addToGroup(0) }
    private func swipeCenter() { addToGroup(1) }
    private func swipeRight() { addToGroup(2) }

    private func addToGroup(_ index: Int) {
        guard currentIndex < photos.count else { return }
        groupPhotos[index].append(photos[currentIndex])
        currentIndex += 1
    }

    private func saveToSelectedAlbum() {
        for (idx, assetsInGroup) in groupPhotos.enumerated() {
            let name = groupNames[idx]
            guard !assetsInGroup.isEmpty else { continue }

            var album: PHAssetCollection? = albums.first(where: { $0.localizedTitle == name })

            if album == nil {
                PHPhotoLibrary.shared().performChanges({
                    PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: name)
                }) { success, error in
                    if let error = error { print("Error creating album: \(error)"); return }
                    fetchAlbums()
                    album = albums.first(where: { $0.localizedTitle == name })
                    addAssets(assetsInGroup, to: album)
                }
            } else {
                addAssets(assetsInGroup, to: album)
            }
        }
        print("Saved all swipes to selected albums.")
    }

    private func filterPhotos() {
        if hideAlreadyInAlbums {
            let assetsInAlbums = albums.flatMap { collection -> [String] in
                var ids: [String] = []
                let assets = PHAsset.fetchAssets(in: collection, options: nil)
                assets.enumerateObjects { asset, _, _ in ids.append(asset.localIdentifier) }
                return ids
            }

            let filteredAssets = allFetchedAssets.filter { !assetsInAlbums.contains($0.localIdentifier) }
            allFetchedAssets = filteredAssets
            photos = []
            photoImages = []
            loadIndex = 0
            loadNextBatch()
            currentIndex = 0
        } else {
            fetchAllPhotos()
            currentIndex = 0
        }
    }

    private func addAssets(_ assets: [PHAsset], to album: PHAssetCollection?) {
        guard let album = album else { return }
        PHPhotoLibrary.shared().performChanges({
            if let albumRequest = PHAssetCollectionChangeRequest(for: album) {
                albumRequest.addAssets(assets as NSArray)
            }
        }) { success, error in
            if let error = error { print("Add assets error:", error) }
        }
    }
}

// MARK: - Thumbnail Helpers
struct AssetThumbnailGrid: View {
    let assets: [PHAsset]
    let maxCount: Int
    
    var body: some View {
        let subset = Array(assets.prefix(maxCount))
        LazyVGrid(columns: Array(repeating: GridItem(.fixed(40), spacing: 4), count: 5), spacing: 4) {
            ForEach(subset, id: \.self) { asset in
                AssetThumbnail(asset: asset)
                    .frame(width: 40, height: 40)
                    .cornerRadius(4)
                    .clipped()
            }
        }
    }
}

struct AssetThumbnail: View {
    let asset: PHAsset
    @State private var image: UIImage?
    
    var body: some View {
        Group {
            if let uiImage = image {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                Color.gray.opacity(0.3)
            }
        }
        .onAppear { loadThumbnail() }
    }
    
    private func loadThumbnail() {
        let manager = PHCachingImageManager.default()
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isSynchronous = false
        options.isNetworkAccessAllowed = true
        manager.requestImage(for: asset,
                             targetSize: CGSize(width: 80, height: 80),
                             contentMode: .aspectFill,
                             options: options) { result, info in
            if let img = result { self.image = img }
        }
    }
}
