import SwiftUI
import Photos

// MARK: - Node Model
enum CollectionNode {
    case folder(String, PHCollectionList)
    case album(String, PHAssetCollection, Int)
}

// MARK: - AlbumOverview with Hierarchy (Photo Albums Only)
struct AlbumOverview: View {
    let parentCollection: PHCollectionList? // nil for root
    @State private var collections: [CollectionNode] = []
    
    var body: some View {
        List {
            ForEach(Array(collections.enumerated()), id: \.1.elementID) { _, node in
                nodeView(node)
            }
        }
        .navigationTitle(parentCollection?.localizedTitle ?? "Albums")
        .onAppear(perform: fetchCollections)
    }
    
    // MARK: - ViewBuilder to reduce type-check complexity
    @ViewBuilder
    private func nodeView(_ node: CollectionNode) -> some View {
        switch node {
        case .folder(let title, let folder):
            NavigationLink(destination: AlbumOverview(parentCollection: folder)) {
                Label(title, systemImage: "folder.fill")
            }
            
        case .album(let title, let collection, let count):
            NavigationLink(destination: AlbumDetailView(collection: collection)) {
                HStack {
                    Label(title, systemImage: "photo.on.rectangle")
                    Spacer()
                    Text("\(count)")
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    // MARK: - Fetch Folders + Albums
    private func fetchCollections() {
        var results: [CollectionNode] = []
        let options = PHFetchOptions()
        
        if let parent = parentCollection {
            // Fetch sub-folders only
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
            // Root: fetch top-level folders + albums
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
            // Folders first, then albums alphabetically
            switch ($0, $1) {
            case (.folder(let t1, _), .folder(let t2, _)):
                return t1 < t2
            case (.folder, .album):
                return true
            case (.album, .folder):
                return false
            case (.album(let t1, _, _), .album(let t2, _, _)):
                return t1 < t2
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

// MARK: - AlbumDetailView (needs to be present)
struct AlbumDetailView: View {
    let collection: PHAssetCollection
    @State private var assets: [PHAsset] = []
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: Array(repeating: .init(.flexible()), count: 3), spacing: 2) {
                ForEach(assets, id: \.localIdentifier) { asset in
                    AssetThumbnail(asset: asset)
                        .frame(width: 120, height: 120)
                        .clipped()
                }
            }
        }
        .navigationTitle(collection.localizedTitle ?? "Album")
        .onAppear(perform: loadAssets)
    }
    
    private func loadAssets() {
        let fetchResult = PHAsset.fetchAssets(in: collection, options: nil)
        var results: [PHAsset] = []
        fetchResult.enumerateObjects { asset, _, _ in results.append(asset) }
        self.assets = results
    }
}

// MARK: - Asset Thumbnail Helper
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
                             targetSize: CGSize(width: 200, height: 200),
                             contentMode: .aspectFill,
                             options: options) { result, _ in
            if let img = result { self.image = img }
        }
    }
}
