/// Copyright (c) 2023 Kodeco Inc.
///
/// Permission is hereby granted, free of charge, to any person obtaining a copy
/// of this software and associated documentation files (the "Software"), to deal
/// in the Software without restriction, including without limitation the rights
/// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
/// copies of the Software, and to permit persons to whom the Software is
/// furnished to do so, subject to the following conditions:
///
/// The above copyright notice and this permission notice shall be included in
/// all copies or substantial portions of the Software.
///
/// Notwithstanding the foregoing, you may not use, copy, modify, merge, publish,
/// distribute, sublicense, create a derivative work, and/or sell copies of the
/// Software in any work that is designed, intended, or marketed for pedagogical or
/// instructional purposes related to programming, coding, application development,
/// or information technology.  Permission for such use, copying, modification,
/// merger, publication, distribution, sublicensing, creation of derivative works,
/// or sale is expressly withheld.
///
/// This project and source code may use libraries or frameworks that are
/// released under various Open-Source licenses. Use of those libraries and
/// frameworks are governed by their own individual licenses.
///
/// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
/// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
/// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
/// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
/// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
/// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
/// THE SOFTWARE.

import UIKit
import Photos
import Combine

class CollageNeueModel: ObservableObject {
	@Published var imagePreview: UIImage?
	static let collageSize = CGSize(width: UIScreen.main.bounds.width, height: 200)
	private var subscriptions = Set<AnyCancellable>()
	private let images = CurrentValueSubject<[UIImage], Never>([])
	let updateUISubject = PassthroughSubject<Int, Never>()
	private(set) var selectedPhotosSubject = PassthroughSubject<UIImage, Never>()

	// MARK: - Collage

	private(set) var lastSavedPhotoID = ""
	private(set) var lastErrorMessage = ""

	func bindMainView() {
		// 1
		images
		// 2
			.handleEvents(receiveOutput: { [weak self] photos in
				self?.updateUISubject.send(photos.count)
			})
			.map { photos in
				UIImage.collage(images: photos, size: Self.collageSize)
			}
		// 3
			.assign(to: &$imagePreview)
	}

	func add() {
		//		if let image = UIImage(named: "IMG_1907") {
		//			images.value.append(image)
		//		}

		selectedPhotosSubject = PassthroughSubject<UIImage, Never>()

//		let newPhotos = selectedPhotosSubject.share()
		let newPhotos = selectedPhotosSubject
			.prefix(while: { [unowned self] _ in
				self.images.value.count < 6
			})
			.share()
		
		newPhotos
			.map { [unowned self] newImage in
				// 1
				return self.images.value + [newImage]
			}
		// 2
			.assign(to: \.value, on: images)
		// 3
			.store(in: &subscriptions)
	}

	func clear() {
		images.send([])
	}

	func save() {
		guard let image = imagePreview else { return }

		// 1
		PhotoWriter.save(image)
			.sink(
				receiveCompletion: { [unowned self] completion in
					// 2
					if case .failure(let error) = completion {
						lastErrorMessage = error.localizedDescription
					}
					clear()
				}, receiveValue: { [unowned self] id in
					lastSavedPhotoID = id
				})
			.store(in: &subscriptions)
	}

	// MARK: -  Displaying photos picker
	private lazy var imageManager = PHCachingImageManager()
	private(set) var thumbnails = [String: UIImage]()
	private let thumbnailSize = CGSize(width: 200, height: 200)

	func bindPhotoPicker() {

	}

	func loadPhotos() -> PHFetchResult<PHAsset> {
		let allPhotosOptions = PHFetchOptions()
		allPhotosOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
		return PHAsset.fetchAssets(with: allPhotosOptions)
	}

	func enqueueThumbnail(asset: PHAsset) {
		guard thumbnails[asset.localIdentifier] == nil else { return }

		imageManager.requestImage(for: asset, targetSize: thumbnailSize, contentMode: .aspectFill, options: nil, resultHandler: { image, _ in
			guard let image = image else { return }
			self.thumbnails[asset.localIdentifier] = image
		})
	}

	func selectImage(asset: PHAsset) {
		imageManager.requestImage(
			for: asset,
			targetSize: UIScreen.main.bounds.size,
			contentMode: .aspectFill,
			options: nil
		) { [weak self] image, info in
			guard let self = self,
						let image = image,
						let info = info else { return }

			if let isThumbnail = info[PHImageResultIsDegradedKey as String] as? Bool, isThumbnail {
				// Skip the thumbnail version of the asset
				return
			}

			// Send the selected image
			self.selectedPhotosSubject.send(image)
		}
	}
}
