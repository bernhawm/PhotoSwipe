import SwiftUI
import Photos
import UIKit

struct PhotoTaggingView: View {
    @Environment(\.dismiss) var dismiss

    // MARK: - State
    @State private var photos: [PHAsset] = []
    @State private var currentIndex: Int = 0
    @State private var photoImages: [UIImage?] = []
    @State private var testImages: [UIImage] = []
    @State private var hideAlreadyInAlbums = false

    @State private var groupNames: [String] = ["Group Wade", "Group 2", "Group 3"]
    @State private var newGroupNames: [String] = ["", "", ""]
    @State private var groupPhotos: [[PHAsset]] = [[], [], []]

    @State private var albums: [PHAssetCollection] = []
    @State private var selectedAlbum: PHAssetCollection?
    @State private var showAlbumPicker = false

    @State private var dragOffset: CGSize = .zero
    @State private var dragDirection: String? = nil

    @State private var showSaveConfirmation = false

    @State private var allAssets: PHFetchResult<PHAsset>? = nil
    private let batchSize: Int = 30

    @State private var albumMembership: [String: Bool] = [:]

    struct SwipeAction {
        let asset: PHAsset
        let groupIndex: Int
    }
    @State private var actionStack: [SwipeAction] = []
    @State private var assetAlbumNames: [String: [String]] = [:]

    var startFromLast: Bool
    private var allImages: [UIImage] { testImages + (photoImages.compactMap { $0 }) }

    var body: some View {
        VStack {
            // Group pill bar (static, no highlight)
            HStack {
                ForEach(0..<groupNames.count, id: \.self) { idx in
                    Text(groupNames[idx])
                        .font(.subheadline.weight(.semibold))
                        .padding(.vertical, 6)
                        .padding(.horizontal, 10)
                        .background(Color.gray.opacity(0.2))
                        .clipShape(Capsule())
                    if idx < groupNames.count - 1 { Spacer() }
                }
            }
            .padding(.horizontal)

            // Action buttons
            HStack {
                Button("PIA?") {
                    hideAlreadyInAlbums.toggle()
                    filterPhotos()
                }
                .padding()
                .background(hideAlreadyInAlbums ? Color.red : Color.gray.opacity(0.5))
                .foregroundColor(.white)
                .cornerRadius(8)

                if !actionStack.isEmpty {
                    Button("Undo Last Swipe") { undoLastAction() }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.yellow.opacity(0.8))
                        .foregroundColor(.black)
                        .cornerRadius(8)
                }

                Spacer()
            }
            .padding(.horizontal)

            // Image display + drag
            if currentIndex < allImages.count {
                ZStack {
                    // Background highlight for drag (still kept for visual swipe feedback)
                    if dragDirection == "left" {
                        Color.red.opacity(0.28).cornerRadius(12)
                    } else if dragDirection == "right" {
                        Color.green.opacity(0.28).cornerRadius(12)
                    } else if dragDirection == "up" {
                        Color.blue.opacity(0.28).cornerRadius(12)
                    }

                    Image(uiImage: allImages[currentIndex])
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .cornerRadius(12)
                        .shadow(radius: 5)
                        .offset(dragOffset)
                        .rotationEffect(.degrees(Double(dragOffset.width / 20)))
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    dragOffset = value.translation
                                    if abs(value.translation.width) > abs(value.translation.height) {
                                        dragDirection = value.translation.width > 0 ? "right" : "left"
                                    } else if value.translation.height < 0 {
                                        dragDirection = "up"
                                    } else {
                                        dragDirection = nil
                                    }
                                }
                                .onEnded { value in
                                    handleSwipe(value)
                                    dragOffset = .zero
                                    dragDirection = nil
                                }
                        )
                        .padding()

                    // "Already in Album" overlay
                    if let currentAsset = assetForDisplay(at: currentIndex),
                       let names = assetAlbumNames[currentAsset.localIdentifier], !names.isEmpty {
                        VStack {
                            HStack {
                                Spacer()
                                VStack(alignment: .trailing) {
                                    ForEach(names, id: \.self) { name in
                                        Text(name)
                                            .font(.caption2)
                                            .padding(4)
                                            .background(Color.black.opacity(0.6))
                                            .foregroundColor(.white)
                                            .cornerRadius(6)
                                    }
                                }
                                .padding()
                            }
                            Spacer()
                        }
                    }
                }
            } else {
                Text("Tagging complete!")
                    .font(.headline)
                    .padding()
            }
        }
        .sheet(isPresented: $showAlbumPicker) { albumEditor }
        .sheet(isPresented: $showSaveConfirmation) { saveConfirmationModal }
        .onAppear { loadPhotosAndAlbums() }
        .navigationTitle("Photo Tagging")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                

                Button("Albums") { showAlbumPicker = true }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Save & Exit") { showSaveConfirmation = true }
            }
        }
    }

    // MARK: - Undo
    private func undoLastAction() {
        guard let last = actionStack.popLast() else { return }
        if let idx = groupPhotos[last.groupIndex].firstIndex(where: { $0.localIdentifier == last.asset.localIdentifier }) {
            groupPhotos[last.groupIndex].remove(at: idx)
        }
        if currentIndex > 0 { currentIndex -= 1 }
    }

    // MARK: - Album Editor
    private var albumEditor: some View {
        VStack {
            Text("Edit Groups").font(.headline).padding()
            ScrollView {
                VStack(spacing: 15) {
                    ForEach(0..<groupNames.count, id: \.self) { idx in
                        VStack(alignment: .leading) {
                            HStack {
                                Text(groupNames[idx])
                                    .frame(width: 120, alignment: .leading)
                                    .padding(.vertical, 8)
                                    .background(Color.gray.opacity(0.2))
                                    .cornerRadius(8)
                                VStack(spacing: 0) {
                                    TextField("New name...", text: $newGroupNames[idx])
                                        .textFieldStyle(.roundedBorder)
                                        .padding(.vertical, 8)
                                    if !newGroupNames[idx].isEmpty {
                                        let suggestions = albums.filter {
                                            ($0.localizedTitle ?? "")
                                                .localizedCaseInsensitiveContains(newGroupNames[idx])
                                        }
                                        if !suggestions.isEmpty {
                                            VStack(alignment: .leading, spacing: 0) {
                                                ForEach(suggestions, id: \.self) { album in
                                                    Button(album.localizedTitle ?? "") {
                                                        if let title = album.localizedTitle {
                                                            newGroupNames[idx] = title
                                                        }
                                                    }
                                                    .padding(6)
                                                    .frame(maxWidth: .infinity, alignment: .leading)
                                                    .background(Color.gray.opacity(0.1))
                                                }
                                            }
                                            .border(Color.gray.opacity(0.3))
                                        }
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
                showAlbumPicker = false
            }
            .buttonStyle(.borderedProminent)
            .padding()
        }
    }

    // MARK: - Save Confirmation
    private var saveConfirmationModal: some View {
        VStack {
            Text("Confirm Save").font(.headline).padding()
            ForEach(0..<groupNames.count, id: \.self) { idx in
                VStack(alignment: .leading) {
                    Button(groupNames[idx]) {}
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue.opacity(0.2))
                        .cornerRadius(8)
                    if !groupPhotos[idx].isEmpty {
                        Text("\(groupPhotos[idx].count) new photos will be added.")
                            .font(.subheadline).foregroundColor(.secondary)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 4) {
                                ForEach(Array(groupPhotos[idx].prefix(10).enumerated()), id: \.0) { _, asset in
                                    if let photoIdx = photos.firstIndex(where: { $0.localIdentifier == asset.localIdentifier }),
                                       photoIdx < photoImages.count,
                                       let img = photoImages[photoIdx] {
                                        Image(uiImage: img)
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: 36, height: 36)
                                            .clipped()
                                            .cornerRadius(6)
                                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.gray.opacity(0.3), lineWidth: 1))
                                    } else {
                                        Rectangle()
                                            .fill(Color.gray.opacity(0.2))
                                            .frame(width: 36, height: 36)
                                            .cornerRadius(6)
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    } else {
                        Text("No new photos selected.").font(.subheadline).foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 5)
            }
            HStack {
                Button("Cancel") { showSaveConfirmation = false }.buttonStyle(.bordered)
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

    // MARK: - Photo Loading
    private func loadPhotosAndAlbums() {
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
            guard status == .authorized || status == .limited else { return }
            fetchAlbums()
            loadInitialBatch()
        }
    }

    private func loadInitialBatch() {
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: startFromLast)]
        let all = PHAsset.fetchAssets(with: .image, options: fetchOptions)

        DispatchQueue.main.async {
            self.allAssets = all
            self.photos = []
            self.photoImages = []
            self.loadBatch(startIndex: 0)
        }
    }

    private func loadBatch(startIndex: Int) {
        guard let allAssets = allAssets else { return }
        let endIndex = min(startIndex + batchSize, allAssets.count)
        guard startIndex < endIndex else { return }

        var newAssets: [PHAsset] = []
        for i in startIndex..<endIndex { newAssets.append(allAssets.object(at: i)) }

        let newImages = Array<UIImage?>(repeating: nil, count: newAssets.count)
        DispatchQueue.main.async {
            photos.append(contentsOf: newAssets)
            photoImages.append(contentsOf: newImages)
        }

        let manager = PHCachingImageManager()
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true

        for (offset, asset) in newAssets.enumerated() {
            manager.requestImage(for: asset, targetSize: CGSize(width: 1000, height: 1000),
                                 contentMode: .aspectFit, options: options) { image, _ in
                DispatchQueue.main.async {
                    let idx = startIndex + offset
                    if idx < photoImages.count { photoImages[idx] = image }
                }
            }

            DispatchQueue.global(qos: .background).async {
                let names = albumNames(for: asset)
                let inAlbum = isAssetInAnyAlbum(asset)
                DispatchQueue.main.async {
                    albumMembership[asset.localIdentifier] = inAlbum
                    assetAlbumNames[asset.localIdentifier] = names
                }
            }
        }
    }

    private func albumNames(for asset: PHAsset) -> [String] {
        var result: [String] = []
        let collections = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: nil)
        collections.enumerateObjects { collection, _, _ in
            let assets = PHAsset.fetchAssets(in: collection, options: nil)
            assets.enumerateObjects { a, _, stop in
                if a.localIdentifier == asset.localIdentifier { result.append(collection.localizedTitle ?? "Untitled") }
            }
        }
        return result
    }

    private func loadNextBatchIfNeeded() {
        guard let allAssets = allAssets else { return }
        if photos.count < allAssets.count { loadBatch(startIndex: photos.count) }
    }

    // MARK: - Swipes
    private func swipeLeft() { handleGroupSwipe(groupIndex: 0) }
    private func swipeCenter() { handleGroupSwipe(groupIndex: 1) }
    private func swipeRight() { handleGroupSwipe(groupIndex: 2) }

    private func handleGroupSwipe(groupIndex: Int) {
        guard currentIndex < photos.count else { return }
        let asset = photos[currentIndex]
        groupPhotos[groupIndex].append(asset)
        actionStack.append(SwipeAction(asset: asset, groupIndex: groupIndex))
        addToAlbum(index: groupIndex)
        advanceAfterSwipe()
    }

    private func advanceAfterSwipe() {
        currentIndex += 1
        if currentIndex >= max(0, photos.count - 5) { loadNextBatchIfNeeded() }
    }

    private func handleSwipe(_ value: DragGesture.Value) {
        let horizontal = value.translation.width
        let vertical = value.translation.height
        let hThreshold: CGFloat = 120
        let vThreshold: CGFloat = 120

        if horizontal < -hThreshold { swipeLeft() }
        else if horizontal > hThreshold { swipeRight() }
        else if vertical < -vThreshold { swipeCenter() }
        else if vertical > vThreshold { skipPhoto() }
    }

    private func skipPhoto() { advanceAfterSwipe() }

    // MARK: - Album Helpers
    private func addToAlbum(index: Int) {
        guard currentIndex < photos.count else { return }
        guard let album = selectedAlbum else { return }
        let asset = photos[currentIndex]

        PHPhotoLibrary.shared().performChanges({
            if let albumRequest = PHAssetCollectionChangeRequest(for: album) {
                albumRequest.addAssets([asset] as NSArray)
            }
        }) { success, error in
            if let error = error { print("Add to album error:", error) }
        }
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
                    if let error = error { print("Error creating album: \(error)") }
                    fetchAlbums()
                    album = albums.first(where: { $0.localizedTitle == name })
                    addAssets(assetsInGroup, to: album)
                }
            } else { addAssets(assetsInGroup, to: album) }
        }
    }

    private func fetchAlbums() {
        let collections = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: nil)
        var temp: [PHAssetCollection] = []
        collections.enumerateObjects { collection, _, _ in temp.append(collection) }
        DispatchQueue.main.async {
            self.albums = temp
            updateAlbumMembershipForLoadedAssets()
        }
    }

    private func createAlbum(named name: String) {
        PHPhotoLibrary.shared().performChanges({
            PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: name)
        }) { success, error in
            if success { fetchAlbums() }
            if let error = error { print("Create album error:", error) }
        }
    }

    private func filterPhotos() {
        if hideAlreadyInAlbums {
            var assetsInAlbumsSet = Set<String>()
            for (id, inAlbum) in albumMembership where inAlbum { assetsInAlbumsSet.insert(id) }

            if assetsInAlbumsSet.isEmpty {
                let assetsInAlbums = albums.flatMap { collection -> [PHAsset] in
                    var result: [PHAsset] = []
                    let assets = PHAsset.fetchAssets(in: collection, options: nil)
                    assets.enumerateObjects { asset, _, _ in result.append(asset) }
                    return result
                }
                assetsInAlbumsSet = Set(assetsInAlbums.map { $0.localIdentifier })
            }

            let filteredPhotos = photos.filter { !assetsInAlbumsSet.contains($0.localIdentifier) }
            var updatedImages: [UIImage?] = []
            for asset in filteredPhotos {
                if let idx = photos.firstIndex(where: { $0.localIdentifier == asset.localIdentifier }),
                   idx < photoImages.count {
                    updatedImages.append(photoImages[idx])
                } else { updatedImages.append(nil) }
            }

            DispatchQueue.main.async {
                photos = filteredPhotos
                photoImages = updatedImages
                currentIndex = 0
            }
        } else { loadInitialBatch() }
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

    private func isAssetInAnyAlbum(_ asset: PHAsset) -> Bool {
        let collections = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: nil)
        var found = false
        collections.enumerateObjects { collection, _, stop in
            let assets = PHAsset.fetchAssets(in: collection, options: nil)
            assets.enumerateObjects { a, _, stop2 in
                if a.localIdentifier == asset.localIdentifier { found = true; stop.pointee = true; stop2.pointee = true }
            }
        }
        return found
    }

    private func updateAlbumMembershipForLoadedAssets() {
        DispatchQueue.global(qos: .background).async {
            for asset in photos {
                let inAlbum = isAssetInAnyAlbum(asset)
                DispatchQueue.main.async { albumMembership[asset.localIdentifier] = inAlbum }
            }
        }
    }

    private func assetForDisplay(at index: Int) -> PHAsset? {
        let testCount = testImages.count
        let imageIndex = index - testCount
        guard imageIndex >= 0 && imageIndex < photos.count else { return nil }
        return photos[imageIndex]
    }
}

// MARK: - Safe Index Extension
extension Collection {
    subscript(safe index: Index) -> Element? { indices.contains(index) ? self[index] : nil }
}
