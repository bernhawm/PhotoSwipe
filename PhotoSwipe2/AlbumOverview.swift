import SwiftUI
import Photos

// MARK: - Node Model
enum CollectionNode {
    case folder(String, PHCollectionList)
    case album(String, PHAssetCollection, Int)
}

// MARK: - AlbumOverview with Hierarchy & Manage Mode
struct AlbumOverview: View {
    let parentCollection: PHCollectionList? // nil for root
    @State private var collections: [CollectionNode] = []
    @State private var manageHierarchyMode: Bool = false
    @State private var movingAlbum: CollectionNode?
    
    var body: some View {
        List {
            ForEach(Array(collections.enumerated()), id: \.1.elementID) { _, node in
                nodeView(node)
            }
        }
        .navigationTitle(parentCollection?.localizedTitle ?? "Albums")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(manageHierarchyMode ? "Done" : "Manage") {
                    manageHierarchyMode.toggle()
                    movingAlbum = nil
                }
            }
        }
        .onAppear(perform: fetchCollections)
    }
    
    // MARK: - Node View
    @ViewBuilder
    private func nodeView(_ node: CollectionNode) -> some View {
        switch node {
        case .folder(let title, let folder):
            HStack {
                if manageHierarchyMode, let moving = movingAlbum {
                    Button("Move Here") {
                        moveAlbum(moving, into: node)
                        movingAlbum = nil
                    }
                }
                NavigationLink(destination: AlbumOverview(parentCollection: folder)) {
                    Label(title, systemImage: "folder.fill")
                }
            }
        case .album(let title, let collection, let count):
            HStack {
                NavigationLink(destination: AlbumDetailView(collection: collection)) {
                    HStack {
                        Label(title, systemImage: "photo.on.rectangle")
                        Spacer()
                        Text("\(count)")
                            .foregroundColor(.secondary)
                    }
                }
                if manageHierarchyMode {
                    Button("Move") { movingAlbum = node }
                        .buttonStyle(BorderlessButtonStyle())
                        .foregroundColor(.blue)
                }
            }
        }
    }
    
    private func moveAlbum(_ album: CollectionNode, into folder: CollectionNode) {
        // Only visual re-ordering in this screen
        if let index = collections.firstIndex(where: { $0.elementID == album.elementID }) {
            collections.remove(at: index)
            collections.insert(album, at: 0)
        }
    }
    
    // MARK: - Fetch Folders + Albums
    private func fetchCollections() {
        var results: [CollectionNode] = []
        let options = PHFetchOptions()
        
        if let parent = parentCollection {
            let subFolders = PHCollectionList.fetchCollections(in: parent, options: nil)
            subFolders.enumerateObjects { collection, _, _ in
                if let folder = collection as? PHCollectionList {
                    results.append(.folder(folder.localizedTitle ?? "Folder", folder))
                }
                if let album = collection as? PHAssetCollection, album.assetCollectionType == .album {
                    let assets = PHAsset.fetchAssets(in: album, options: options)
                    if assets.count > 0 {
                        results.append(.album(album.localizedTitle ?? "Album", album, assets.count))
                    }
                }
            }
        } else {
            let topFolders = PHCollectionList.fetchTopLevelUserCollections(with: nil)
            topFolders.enumerateObjects { collection, _, _ in
                if let folder = collection as? PHCollectionList {
                    results.append(.folder(folder.localizedTitle ?? "Folder", folder))
                }
                if let album = collection as? PHAssetCollection, album.assetCollectionType == .album {
                    let assets = PHAsset.fetchAssets(in: album, options: options)
                    if assets.count > 0 {
                        results.append(.album(album.localizedTitle ?? "Album", album, assets.count))
                    }
                }
            }
        }
        
        self.collections = results.sorted {
            switch ($0, $1) {
            case (.folder(let t1, _), .folder(let t2, _)): return t1 < t2
            case (.folder, .album): return true
            case (.album, .folder): return false
            case (.album(let t1, _, _), .album(let t2, _, _)): return t1 < t2
            }
        }
    }
}

// MARK: - Identifiable helper
extension CollectionNode {
    var elementID: String {
        switch self {
        case .folder(let title, let folder):
            return "folder-\(title)-\(folder.localIdentifier)"
        case .album(let title, let album, _):
            return "album-\(title)-\(album.localIdentifier)"
        }
    }
}

// MARK: - AlbumDetailView with Selection
struct AlbumDetailView: View {
    let collection: PHAssetCollection
    @State private var assets: [PHAsset] = []
    @State private var selectionMode: Bool = false
    @State private var selectedAssets: Set<String> = [] // localIdentifiers
    @State private var actionMode: ActionMode = .none
    
    enum ActionMode {
        case none, remove, delete
    }
    
    var body: some View {
        VStack {
            if selectionMode {
                HStack {
                    Button("Cancel") {
                        selectionMode = false
                        selectedAssets.removeAll()
                        actionMode = .none
                    }
                    Spacer()
                    Picker("", selection: $actionMode) {
                        Text("Remove").tag(ActionMode.remove)
                        Text("Delete").tag(ActionMode.delete)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    
                    Spacer()
                    Button("Confirm") { performAction() }
                        .disabled(selectedAssets.isEmpty || actionMode == .none)
                }
                .padding()
            }
            
            ScrollView {
                LazyVGrid(columns: Array(repeating: .init(.flexible()), count: 3), spacing: 2) {
                    ForEach(assets, id: \.localIdentifier) { asset in
                        AssetThumbnail(asset: asset,
                                       isSelected: selectedAssets.contains(asset.localIdentifier),
                                       actionMode: actionMode)
                            .frame(width: 120, height: 120)
                            .clipped()
                            .onTapGesture {
                                if selectionMode {
                                    toggleSelection(asset)
                                }
                            }
                    }
                }
            }
        }
        .navigationTitle(collection.localizedTitle ?? "Album")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(selectionMode ? "Done" : "Select Photos") {
                    selectionMode.toggle()
                    if !selectionMode { selectedAssets.removeAll(); actionMode = .none }
                }
            }
        }
        .onAppear(perform: loadAssets)
    }
    
    private func toggleSelection(_ asset: PHAsset) {
        if selectedAssets.contains(asset.localIdentifier) {
            selectedAssets.remove(asset.localIdentifier)
        } else {
            selectedAssets.insert(asset.localIdentifier)
        }
    }
    
    private func performAction() {
        switch actionMode {
        case .delete: deleteSelected()
        case .remove: removeSelectedFromAlbum()
        default: break
        }
    }
    
    private func deleteSelected() {
        let assetsToDelete = assets.filter { selectedAssets.contains($0.localIdentifier) }
        PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.deleteAssets(assetsToDelete as NSArray)
        } completionHandler: { success, error in
            if success { loadAssets(); selectedAssets.removeAll() }
            else { print("Error deleting: \(error?.localizedDescription ?? "unknown")") }
        }
    }
    
    private func removeSelectedFromAlbum() {
        let assetsToRemove = assets.filter { selectedAssets.contains($0.localIdentifier) }
        PHPhotoLibrary.shared().performChanges {
            if let request = PHAssetCollectionChangeRequest(for: collection) {
                request.removeAssets(assetsToRemove as NSArray)
            }
        } completionHandler: { success, error in
            if success { loadAssets(); selectedAssets.removeAll() }
            else { print("Error removing: \(error?.localizedDescription ?? "unknown")") }
        }
    }
    
    private func loadAssets() {
        let fetchResult = PHAsset.fetchAssets(in: collection, options: nil)
        var results: [PHAsset] = []
        fetchResult.enumerateObjects { asset, _, _ in results.append(asset) }
        self.assets = results
    }
}

// MARK: - Asset Thumbnail with Centered Indicator
struct AssetThumbnail: View {
    let asset: PHAsset
    var isSelected: Bool = false
    var actionMode: AlbumDetailView.ActionMode = .none
    @State private var image: UIImage?
    
    var body: some View {
        ZStack {
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
            
            if isSelected {
                Circle()
                    .fill(actionMode == .delete ? Color.red.opacity(0.7) : Color.yellow.opacity(0.7))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: actionMode == .delete ? "trash.fill" : "minus")
                            .foregroundColor(.white)
                            .bold()
                    )
            }
        }
    }
    
    private func loadThumbnail() {
        let manager = PHCachingImageManager.default()
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isSynchronous = false
        options.isNetworkAccessAllowed = true
        
        manager.requestImage(for: asset,
                             targetSize: CGSize(width: 200, height: 200),
                             contentMode: .aspectFill,
                             options: options) { result, _ in
            if let img = result { self.image = img }
        }
    }
}
