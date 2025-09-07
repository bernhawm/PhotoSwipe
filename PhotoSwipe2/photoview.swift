import SwiftUI
import Photos
import PhotosUI
import UIKit

struct PhotoSwipeView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.scenePhase) private var scenePhase
    
    @State private var photos: [PHAsset] = []
    @State private var currentIndex: Int = 0
    @State private var deleteList: [PHAsset] = []
    @State private var keepList: [PHAsset] = []
    @State private var photoImages: [UIImage] = []   // real photos
    @State private var testImages: [UIImage] = []    // bundled test images
    
    @State private var showHomeAlert = false
    var startFromLast: Bool
    
    private var allImages: [UIImage] {
        return testImages + photoImages
    }
    
    var body: some View {
        VStack {
            HStack {
                Button(action: handleHomeTapped) {
                    Label("Home", systemImage: "house.fill")
                        .padding()
                        .background(Color.blue.opacity(0.8))
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top)
            
            Spacer()
            
            if currentIndex < allImages.count {
                ZStack {
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
                                }
                        )
                    
                    Text("Swipe left = delete, right = keep")
                        .padding()
                        .background(Color.black.opacity(0.5))
                        .foregroundColor(.white)
                        .cornerRadius(8)
                        .padding(.top, 50)
                        .frame(maxHeight: .infinity, alignment: .top)
                }
            } else {
                VStack {
                    Text("Review complete!")
                    Button("Delete Left-Swiped Photos (\(deleteList.count))", action: deletePhotos)
                        .padding()
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
            }
        }
        .onAppear(perform: requestPhotos)
        .navigationTitle("Photo Swipe")
        .navigationBarTitleDisplayMode(.inline)
        .alert("You have unsaved swipes", isPresented: $showHomeAlert) {
            Button("Complete") { deletePhotos(); dismiss() }
            Button("Discard", role: .destructive) { dismiss() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Do you want to complete the swipes before leaving?")
        }
        .onChange(of: scenePhase) { phase, _ in
            if phase == .background && (!deleteList.isEmpty || !keepList.isEmpty) {
                print("App going to background with unsaved swipes!")
            }
        }
    }
    
    private func handleHomeTapped() {
        if deleteList.isEmpty && keepList.isEmpty { dismiss() }
        else { showHomeAlert = true }
    }
    
    private func requestPhotos() {
        PHPhotoLibrary.requestAuthorization { status in
            if status == .authorized {
                let fetchOptions = PHFetchOptions()
                fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: startFromLast)]
                
                let fetched = PHAsset.fetchAssets(with: .image, options: fetchOptions)
                var newPhotos: [PHAsset] = []
                fetched.enumerateObjects { asset, _, _ in newPhotos.append(asset) }
                
                DispatchQueue.main.async {
                    self.photos = newPhotos
                    self.loadImages()
                }
            }
        }
    }
    
    private func loadTestImages() {
        if let urls = Bundle.main.urls(forResourcesWithExtension: nil, subdirectory: "images") {
            print("✅ Found \(urls.count) files in images/:", urls)
            for url in urls {
                if let data = try? Data(contentsOf: url),
                   let img = UIImage(data: data) {
                    self.testImages.append(img)
                }
            }
        } else {
            print("⚠️ No images found in 'images' folder")
        }
    }
    
    private func loadImages() {
        loadTestImages()
        
        let manager = PHCachingImageManager()
        let targetSize = CGSize(width: 800, height: 800)
        for asset in photos {
            manager.requestImage(for: asset, targetSize: targetSize, contentMode: .aspectFit, options: nil) { image, _ in
                if let img = image { self.photoImages.append(img) }
            }
        }
    }
    
    private func swipeLeft() {
        if currentIndex >= testImages.count {
            let photoIndex = currentIndex - testImages.count
            deleteList.append(photos[photoIndex])
        }
        currentIndex += 1
    }
    
    private func swipeRight() {
        if currentIndex >= testImages.count {
            let photoIndex = currentIndex - testImages.count
            keepList.append(photos[photoIndex])
        }
        currentIndex += 1
    }
    
    private func deletePhotos() {
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.deleteAssets(self.deleteList as NSFastEnumeration)
        }) { success, error in
            print(success ? "Deleted successfully" : "Error deleting: \(String(describing: error))")
        }
    }
}

