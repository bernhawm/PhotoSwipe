import SwiftUI
import Photos
import UIKit

struct PhotoTaggingView: View {
    @Environment(\.dismiss) var dismiss

    @State private var photos: [PHAsset] = []
    @State private var currentIndex: Int = 0
    @State private var photoImages: [UIImage] = []
    @State private var testImages: [UIImage] = []
    @State private var hideAlreadyInAlbums = false

    @State private var groupNames: [String] = ["Group Wade", "Group 2", "Group 3"]
    @State private var newGroupNames: [String] = ["", "", ""]
    @State private var groupPhotos: [[PHAsset]] = [[], [], []]

    @State private var albums: [PHAssetCollection] = []
    @State private var selectedAlbum: PHAssetCollection?
    @State private var showAlbumPicker = false

    // New state for confirmation modal
    @State private var showSaveConfirmation = false

    var startFromLast: Bool
    private var allImages: [UIImage] { testImages + photoImages }

    var body: some View {
        VStack {
            // Group pill bar
            HStack {
                Text(groupNames[0])
                    .font(.subheadline.weight(.semibold))
                    .padding(.vertical, 6)
                    .padding(.horizontal, 10)
                    .background(Color.gray.opacity(0.2))
                    .clipShape(Capsule())
                Spacer()
                Text(groupNames[1])
                    .font(.subheadline.weight(.semibold))
                    .padding(.vertical, 6)
                    .padding(.horizontal, 10)
                    .background(Color.gray.opacity(0.2))
                    .clipShape(Capsule())
                Spacer()
                Text(groupNames[2])
                    .font(.subheadline.weight(.semibold))
                    .padding(.vertical, 6)
                    .padding(.horizontal, 10)
                    .background(Color.gray.opacity(0.2))
                    .clipShape(Capsule())
            }
            .padding(.horizontal)
            
            Button("PIA?") {
                hideAlreadyInAlbums.toggle()
                filterPhotos()
            }
            .padding()
            .background(hideAlreadyInAlbums ? Color.red : Color.gray.opacity(0.5))
            .foregroundColor(.white)
            .cornerRadius(8)
            
            Spacer()

            if currentIndex < allImages.count {
                Image(uiImage: allImages[currentIndex])
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .cornerRadius(12)
                    .shadow(radius: 5)
                    .gesture(
                        DragGesture()
                            .onEnded { value in
                                if value.translation.width < -100 { swipeLeft() }
                                else if value.translation.width > 100 { swipeRight() }
                                else { swipeCenter() }
                            }
                    )
                    .padding()
            } else {
                Text("Tagging complete!")
                    .font(.headline)
                    .padding()
            }
        }
        // Album editing sheet
        .sheet(isPresented: $showAlbumPicker) {
            albumEditor
        }
        // New Save confirmation modal
        .sheet(isPresented: $showSaveConfirmation) {
            saveConfirmationModal
        }
        .onAppear(perform: loadPhotosAndAlbums)
        .navigationTitle("Photo Tagging")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Albums") { showAlbumPicker = true }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Save & Exit") {
                    showSaveConfirmation = true
                }
            }
        }
    }

    // MARK: - Album Editor
    private var albumEditor: some View {
        VStack {
            Text("Edit Groups")
                .font(.headline)
                .padding()

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

                                    // Autosuggest dropdown
                                    if !newGroupNames[idx].isEmpty {
                                        let suggestions = albums.filter {
                                            ($0.localizedTitle ?? "")
                                                .localizedCaseInsensitiveContains(newGroupNames[idx])
                                        }

                                        if !suggestions.isEmpty {
                                            VStack(alignment: .leading, spacing: 0) {
                                                ForEach(suggestions, id: \.self) { album in
                                                    Button(action: {
                                                        if let title = album.localizedTitle {
                                                            newGroupNames[idx] = title
                                                        }
                                                    }) {
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
                        }
                        .padding(.horizontal)
                    }
                }
            }

            Button("Save & Exit") {
                for (idx, newName) in newGroupNames.enumerated() {
                    if !newName.isEmpty {
                        groupNames[idx] = newName
                    }
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

    // MARK: - Save Confirmation Modal
    private var saveConfirmationModal: some View {
        VStack {
            Text("Confirm Save")
                .font(.headline)
                .padding()

            ForEach(0..<groupNames.count, id: \.self) { idx in
                VStack(alignment: .leading) {
                    Button(groupNames[idx]) {
                        // Could allow toggling/selecting later if needed
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue.opacity(0.2))
                    .cornerRadius(8)

                    if !groupPhotos[idx].isEmpty {
                        Text("\(groupPhotos[idx].count) new photos will be added.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        // Show up to 10 small previews
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 4) {
                                ForEach(Array(groupPhotos[idx].prefix(10).enumerated()), id: \.0) { (offset, asset) in
                                    // Try to find the index of this asset in photos
                                    if let photoIdx = photos.firstIndex(where: { $0.localIdentifier == asset.localIdentifier }),
                                       photoIdx < photoImages.count {
                                        Image(uiImage: photoImages[photoIdx])
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: 36, height: 36)
                                            .clipped()
                                            .cornerRadius(6)
                                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.gray.opacity(0.3), lineWidth: 1))
                                    } else {
                                        // Placeholder if image not found
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
                        Text("No new photos selected.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 5)
            }

            HStack {
                Button("Cancel") {
                    showSaveConfirmation = false
                }
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

    // MARK: - Photo & Album Loading
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
        var newPhotos: [PHAsset] = []
        fetched.enumerateObjects { asset, _, _ in newPhotos.append(asset) }
        DispatchQueue.main.async { self.photos = newPhotos; loadImages(for: newPhotos) }
    }

    private func loadImages(for assets: [PHAsset]) {
        let manager = PHCachingImageManager()
        let targetSize = CGSize(width: 1000, height: 1000)
        var results: [UIImage] = []
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true

        let group = DispatchGroup()
        for asset in assets {
            group.enter()
            manager.requestImage(for: asset, targetSize: targetSize, contentMode: .aspectFit, options: options) { image, _ in
                if let img = image { results.append(img) }
                group.leave()
            }
        }

        group.notify(queue: .main) { self.photoImages = results }
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

    // MARK: - Swiping
    private func swipeLeft() { if currentIndex < photos.count { groupPhotos[0].append(photos[currentIndex]) }; addToAlbum(index: 0); currentIndex += 1 }
    private func swipeCenter() { if currentIndex < photos.count { groupPhotos[1].append(photos[currentIndex]) }; addToAlbum(index: 1); currentIndex += 1 }
    private func swipeRight() { if currentIndex < photos.count { groupPhotos[2].append(photos[currentIndex]) }; addToAlbum(index: 2); currentIndex += 1 }

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

            // Check if album exists
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
            let assetsInAlbums = albums.flatMap { collection -> [PHAsset] in
                var result: [PHAsset] = []
                let assets = PHAsset.fetchAssets(in: collection, options: nil)
                assets.enumerateObjects { asset, _, _ in result.append(asset) }
                return result
            }
            photos = photos.filter { !assetsInAlbums.contains($0) }
        } else {
            fetchAllPhotos()
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
