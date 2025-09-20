import SwiftUI
import Photos
import UIKit

struct PhotoSwipeView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.scenePhase) private var scenePhase

    @State private var dragOffset: CGSize = .zero
    @State private var allFetchedAssets: [PHAsset] = []   // all photos (lazy loaded)
    @State private var photos: [PHAsset] = []             // current batch
    @State private var currentIndex: Int = 0
    @State private var deleteList: [PHAsset] = []
    @State private var keepList: [PHAsset] = []
    @State private var photoImages: [UIImage] = []
    @State private var batchSize = 20
    @State private var loadIndex = 0

    @State private var lastAction: (PHAsset, UIImage, String)?
    @State private var showDeleteConfirmation: Bool = false

    // 🔹 NEW: show list modal
    @State private var showListModal: Bool = false
    @State private var activeListType: String = "Delete" // "Delete" or "Keep"
    
    // 🔹 NEW: selection in modal
    @State private var selectedAssets: Set<String> = []

    var startFromLast: Bool

    var body: some View {
        VStack {
            // Top bar with counts + Undo
            HStack {
                // 🔹 Tap to see deleteList
                Text("\(deleteList.count)")
                    .font(.headline)
                    .foregroundColor(.red)
                    .onTapGesture {
                        activeListType = "Delete" // 🔹 NEW
                        showListModal = true       // 🔹 NEW
                        selectedAssets.removeAll() // 🔹 NEW
                    }
                
                Spacer()
                
                if lastAction != nil {
                    Button("Undo") { undoLastAction() }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.yellow.opacity(0.8))
                        .foregroundColor(.black)
                        .cornerRadius(8)
                }
                
                Spacer()
                
                // 🔹 Tap to see keepList
                Text("\(keepList.count)")
                    .font(.headline)
                    .foregroundColor(.green)
                    .onTapGesture {
                        activeListType = "Keep"  // 🔹 NEW
                        showListModal = true      // 🔹 NEW
                        selectedAssets.removeAll()// 🔹 NEW
                    }
            }
            .padding(.horizontal)

            Spacer()

            if currentIndex < photoImages.count {
                ZStack {
                    if dragOffset.width < -100 {
                        Color.red.opacity(0.3).cornerRadius(12)
                    } else if dragOffset.width > 100 {
                        Color.green.opacity(0.3).cornerRadius(12)
                    }

                    Image(uiImage: photoImages[currentIndex])
                        .resizable()
                        .scaledToFit()
                        .cornerRadius(12)
                        .shadow(radius: 5)
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
                }
            } else {
                VStack {
                    Text("Review complete!")
                    Button("Delete \(deleteList.count) Photos") {
                        deletePhotos()
                    }
                    .padding()
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
            }

            Spacer()
        }
        .onAppear(perform: requestPhotos)
        .onChange(of: scenePhase) { phase, _ in
            if phase == .background && (!deleteList.isEmpty || !keepList.isEmpty) {
                print("App going to background with unsaved swipes!")
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    if deleteList.isEmpty {
                        dismiss()
                    } else {
                        showDeleteConfirmation = true
                    }
                }) {
                    HStack {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                }
            }
        }
        .sheet(isPresented: $showDeleteConfirmation) {
            deleteConfirmationView()
        }
        // 🔹 NEW: modal for viewing Delete / Keep lists
        .sheet(isPresented: $showListModal) {
            listModalView()
        }
    }

    // MARK: - List Modal 🔹 NEW
    @ViewBuilder
    private func listModalView() -> some View {
        VStack(spacing: 16) {
            Text("\(activeListType) Photos")
                .font(.headline)
                .padding(.top, 12)

            ScrollView(.horizontal, showsIndicators: true) {
                HStack(spacing: 12) {
                    let assets = activeListType == "Delete" ? deleteList : keepList
                    ForEach(assets, id: \.localIdentifier) { asset in
                        VStack {
                            AssetThumbnail(asset: asset)
                                .frame(width: 100, height: 100)
                                .cornerRadius(8)
                                .overlay(
                                    selectedAssets.contains(asset.localIdentifier) ?
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.blue, lineWidth: 4) : nil
                                )
                                .onTapGesture {
                                    if selectedAssets.contains(asset.localIdentifier) {
                                        selectedAssets.remove(asset.localIdentifier)
                                    } else {
                                        selectedAssets.insert(asset.localIdentifier)
                                    }
                                }
                            Text(activeListType)
                                .font(.caption)
                                .foregroundColor(activeListType == "Delete" ? .red : .green)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }

            Spacer()

            HStack {
                Button("Cancel") {
                    showListModal = false
                    selectedAssets.removeAll()
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.gray.opacity(0.15))
                .cornerRadius(10)

                Button("Remove Selected") {
                    removeSelectedFromList()
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.red)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
        .presentationDetents([.medium, .large])
    }

    // 🔹 NEW: remove selected assets from deleteList or keepList
    private func removeSelectedFromList() {
        if activeListType == "Delete" {
            deleteList.removeAll { selectedAssets.contains($0.localIdentifier) }
        } else {
            keepList.removeAll { selectedAssets.contains($0.localIdentifier) }
        }
        selectedAssets.removeAll()
        showListModal = false
    }

    // MARK: - Delete Confirmation
    private func deleteConfirmationView() -> some View {
        VStack(spacing: 16) {
            Text("Confirm Deletion")
                .font(.headline)
                .padding(.top, 12)

            Text("You have \(deleteList.count) photo(s) marked for deletion.")
                .font(.subheadline)
                .foregroundColor(.secondary)

            ScrollView(.horizontal, showsIndicators: true) {
                HStack(spacing: 12) {
                    ForEach(deleteList, id: \.localIdentifier) { asset in
                        AssetThumbnail(asset: asset)
                            .frame(width: 100, height: 100)
                            .cornerRadius(8)
                            .clipped()
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }

            Spacer()

            HStack {
                Button("Cancel") {
                    showDeleteConfirmation = false
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.gray.opacity(0.15))
                .cornerRadius(10)

                Button(action: {
                    deletePhotos {
                        DispatchQueue.main.async {
                            showDeleteConfirmation = false
                            dismiss()
                        }
                    }
                }) {
                    Text("Confirm Deletion")
                        .frame(maxWidth: .infinity)
                }
                .padding()
                .background(Color.red)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .padding(.horizontal)

            Button("Go Home") {
                showDeleteConfirmation = false
                dismiss()
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(10)
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: - Request Photos
    private func requestPhotos() {
        PHPhotoLibrary.requestAuthorization { status in
            guard status == .authorized || status == .limited else { return }

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
    }

    // MARK: - Load Photos in Batches
    private func loadNextBatch() {
        let endIndex = min(loadIndex + batchSize, allFetchedAssets.count)
        guard loadIndex < endIndex else { return }

        let newBatch = Array(allFetchedAssets[loadIndex..<endIndex])
        loadIndex = endIndex

        let manager = PHCachingImageManager()
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isSynchronous = false
        options.isNetworkAccessAllowed = true

        for asset in newBatch {
            manager.requestImage(for: asset,
                                 targetSize: CGSize(width: 800, height: 800),
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

    // MARK: - Handle Swipe
    private func handleSwipe(_ value: DragGesture.Value) {
        let horizontal = value.translation.width
        let threshold: CGFloat = 120

        if horizontal < -threshold { swipeLeft() }
        else if horizontal > threshold { swipeRight() }
        else { skipPhoto() }

        dragOffset = .zero
    }

    private func swipeLeft() {
        if currentIndex < photos.count {
            let asset = photos[currentIndex]
            let image = photoImages[currentIndex]
            deleteList.append(asset)
            lastAction = (asset, image, "delete")
        }
        nextPhoto()
    }

    private func swipeRight() {
        if currentIndex < photos.count {
            let asset = photos[currentIndex]
            let image = photoImages[currentIndex]
            keepList.append(asset)
            lastAction = (asset, image, "keep")
        }
        nextPhoto()
    }

    private func skipPhoto() {
        lastAction = nil
        nextPhoto()
    }

    private func nextPhoto() {
        currentIndex += 1
        if currentIndex % 10 == 0 {
            loadNextBatch()
        }
    }

    // MARK: - Undo
    private func undoLastAction() {
        guard let action = lastAction else { return }

        switch action.2 {
        case "delete":
            if let index = deleteList.firstIndex(of: action.0) {
                deleteList.remove(at: index)
            }
        case "keep":
            if let index = keepList.firstIndex(of: action.0) {
                keepList.remove(at: index)
            }
        default: break
        }

        currentIndex = max(currentIndex - 1, 0)
        if !photos.contains(action.0) {
            photos.insert(action.0, at: currentIndex)
            photoImages.insert(action.1, at: currentIndex)
        }

        lastAction = nil
    }

    // MARK: - Delete
    private func deletePhotos(completion: (() -> Void)? = nil) {
        guard !deleteList.isEmpty else {
            completion?()
            return
        }

        let assetsToDelete = deleteList

        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.deleteAssets(assetsToDelete as NSFastEnumeration)
        }) { success, error in
            if success {
                print("Deleted successfully")
                DispatchQueue.main.async {
                    let idsToDelete = Set(assetsToDelete.map { $0.localIdentifier })
                    self.photos.removeAll { idsToDelete.contains($0.localIdentifier) }
                    self.photoImages.removeAll()

                    let manager = PHCachingImageManager()
                    let options = PHImageRequestOptions()
                    options.deliveryMode = .highQualityFormat
                    options.isSynchronous = false
                    options.isNetworkAccessAllowed = true

                    var rebuilt: [UIImage] = []
                    let group = DispatchGroup()
                    for asset in self.photos {
                        group.enter()
                        manager.requestImage(for: asset,
                                             targetSize: CGSize(width: 800, height: 800),
                                             contentMode: .aspectFit,
                                             options: options) { image, _ in
                            if let img = image { rebuilt.append(img) }
                            group.leave()
                        }
                    }
                    group.notify(queue: .main) {
                        self.photoImages = rebuilt
                        self.currentIndex = min(self.currentIndex, max(0, self.photoImages.count - 1))
                        self.deleteList.removeAll { idsToDelete.contains($0.localIdentifier) }
                        completion?()
                    }
                }
            } else {
                print("Error deleting: \(String(describing: error))")
                completion?()
            }
        }
    }
}
