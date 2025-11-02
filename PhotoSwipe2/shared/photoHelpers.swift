// PhotoHelpers.swift
import Photos
import UIKit

/// Loads a high-quality UIImage for a PHAsset.
func requestHighQualityImage(
    for asset: PHAsset,
    targetSize: CGSize = CGSize(width: 1200, height: 1200),
    completion: @escaping (UIImage?) -> Void
) {
    let manager = PHCachingImageManager()
    let options = PHImageRequestOptions()
    options.deliveryMode = .highQualityFormat
    options.isNetworkAccessAllowed = true

    manager.requestImage(
        for: asset,
        targetSize: targetSize,
        contentMode: .aspectFit,
        options: options
    ) { image, _ in
        completion(image)
    }
}

/// Checks if a PHAsset belongs to any album.
func albumsContaining(asset: PHAsset) -> [String] {
    var names: [String] = []
    let collections = PHAssetCollection.fetchAssetCollectionsContaining(asset, with: .album, options: nil)
    collections.enumerateObjects { collection, _, _ in
        names.append(collection.localizedTitle ?? "")
    }
    return names
}
