//
//  ImageLoader.swift
//  PhotoSwipe2
//
//  Created by Wade Bernhardt on 8/23/25.
//

import Foundation
import SwiftUI

class ImageLoader: ObservableObject {
    @Published var images: [UIImage] = []
    
    init() {
        loadImagesFromBundle() // safe here because it’s just a class method
    }

    func loadImagesFromBundle() {
        guard let resourcePath = Bundle.main.resourcePath else {
            print("❌ No resource path found.")
            return
        }

        let imagesPath = (resourcePath as NSString).appendingPathComponent("images")

        do {
            let fileManager = FileManager.default
            let files = try fileManager.contentsOfDirectory(atPath: imagesPath)

            let loaded = files.compactMap { file -> UIImage? in
                let fullPath = (imagesPath as NSString).appendingPathComponent(file)
                return UIImage(contentsOfFile: fullPath)
            }

            DispatchQueue.main.async {
                self.images = loaded
                print("✅ Preloaded \(loaded.count) images from bundle")
            }

        } catch {
            print("❌ Failed to load images: \(error.localizedDescription)")
        }
    }
}
