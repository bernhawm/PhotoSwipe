import SwiftUI
import Photos

// 🔸 UPDATED: TimelineBrowser shows a selectable grid around an initial date.
// Uses an Identifiable wrapper so sheet(item:) doesn't flash white.
// NOTE: This file defines the thumbnail used by the timeline only (TimelineAssetThumbnail).
// If you already have an `AssetThumbnail` elsewhere remove or rename it to avoid duplicate types.

/// Identifiable wrapper for PHAsset to use with sheet(item:)
fileprivate struct IdentifiableAsset: Identifiable {
    let id: String
    let asset: PHAsset
    init(_ asset: PHAsset) {
        self.asset = asset
        self.id = asset.localIdentifier
    }
}

/// Full-screen, scrollable photo browser for picking a starting point.
/// Users can adjust the "around" date and tap any photo -> a small confirmation sheet appears.
struct TimelineBrowser: View {
    @Environment(\.dismiss) private var dismiss

    // initial date to center around (caller passes)
    private let initialDate: Date
    private let onSelect: (PHAsset) -> Void

    // local state
    @State private var aroundDate: Date
    @State private var assets: [PHAsset] = []
    @State private var gridSize: CGFloat = 100
    @State private var selected: IdentifiableAsset? = nil

    init(initialDate: Date = Date(), onSelect: @escaping (PHAsset) -> Void) {
        self.initialDate = initialDate
        self.onSelect = onSelect
        _aroundDate = State(initialValue: initialDate) // initialize @State from init arg
    }

    var body: some View {
        NavigationView {
            VStack {
                // date controls
                HStack {
                    DatePicker("", selection: $aroundDate, displayedComponents: [.date])
                        .labelsHidden()
                    Spacer()
                    Button("Refresh") { fetchAssets() }
                }
                .padding(.horizontal)

                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: gridSize), spacing: 4)], spacing: 4) {
                        ForEach(assets, id: \.localIdentifier) { asset in
                            TimelineAssetThumbnail(asset: asset)
                                .frame(height: gridSize)
                                .clipped()
                                .cornerRadius(6)
                                .onTapGesture {
                                    // 🔸 FIX: wrap asset in Identifiable wrapper and present sheet(item:)
                                    selected = IdentifiableAsset(asset)
                                }
                        }
                    }
                    .padding(6)
                }
            }
            .navigationTitle("Jump in Time")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Slider(value: $gridSize, in: 60...160)
                        .frame(width: 120)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .onAppear(perform: fetchAssets)
            // 🔸 FIX: Present confirmation sheet only when selected != nil (prevents blank white instant sheet)
            .sheet(item: $selected) { item in
                TimelineAssetSheet(asset: item.asset) {
                    // user confirmed "Start From Here"
                    onSelect(item.asset)
                    dismiss()
                }
            }
        }
    }

    /// Fetch assets roughly +/- 6 months around the selected date
    private func fetchAssets() {
        let sixMonths: TimeInterval = 60*60*24*30*6
        let minDate = aroundDate.addingTimeInterval(-sixMonths)
        let maxDate = aroundDate.addingTimeInterval(sixMonths)
        let opts = PHFetchOptions()
        opts.predicate = NSPredicate(format: "creationDate >= %@ AND creationDate <= %@", minDate as NSDate, maxDate as NSDate)
        opts.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
        let fetch = PHAsset.fetchAssets(with: .image, options: opts)

        var arr: [PHAsset] = []
        fetch.enumerateObjects { a, _, _ in arr.append(a) }
        DispatchQueue.main.async { assets = arr }
    }
}

// MARK: - Confirmation sheet shown when user taps a thumbnail
fileprivate struct TimelineAssetSheet: View {
    let asset: PHAsset
    let onStart: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 16) {
            TimelineAssetThumbnail(asset: asset)
                .frame(width: 260, height: 260)
                .cornerRadius(12)

            Text("Start queue from this photo?")
                .font(.headline)
                .padding(.top)

            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.gray.opacity(0.2))
                .cornerRadius(10)

                Button("Start From Here") {
                    onStart()
                    dismiss()
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .padding(.horizontal)
        }
        .padding()
        .presentationDetents([.fraction(0.35)])
    }
}

// MARK: - Thumbnail used by TimelineBrowser only (keeps name unique to avoid collisions)
fileprivate struct TimelineAssetThumbnail: View {
    let asset: PHAsset
    @State private var image: UIImage? = nil

    var body: some View {
        ZStack {
            if let img = image {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
            } else {
                Rectangle().fill(Color.gray.opacity(0.2))
            }
        }
        .onAppear {
            // opportunistic / fast thumbnail
            let options = PHImageRequestOptions()
            options.deliveryMode = .opportunistic
            options.isNetworkAccessAllowed = true
            PHImageManager.default().requestImage(for: asset,
                                                 targetSize: CGSize(width: 300, height: 300),
                                                 contentMode: .aspectFill,
                                                 options: options) { img, _ in
                if let img = img { image = img }
            }
        }
    }
}
