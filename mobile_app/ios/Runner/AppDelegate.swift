import Firebase
import Flutter
import Photos
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private let galleryChannel = "bustan_amari/gallery"

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Firebase must be configured before GeneratedPluginRegistrant so that
    // firebase_messaging can attach its method channel handler.
    FirebaseApp.configure()

    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(name: galleryChannel, binaryMessenger: controller.binaryMessenger)
      channel.setMethodCallHandler { [weak self] call, result in
        guard call.method == "saveImageToGallery" else {
          result(FlutterMethodNotImplemented)
          return
        }

        guard
          let args = call.arguments as? [String: Any],
          let typedData = args["bytes"] as? FlutterStandardTypedData,
          let fileName = args["fileName"] as? String,
          !fileName.isEmpty
        else {
          result(
            FlutterError(
              code: "INVALID_ARGS",
              message: "Missing image bytes or fileName",
              details: nil
            )
          )
          return
        }

        let folderName = (args["folderName"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let albumName = (folderName?.isEmpty == false) ? folderName! : "Bustan Amari"

        self?.saveImageToPhotoLibrary(
          imageData: typedData.data,
          fileName: fileName,
          albumName: albumName,
          result: result
        )
      }
    }

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func complete(_ result: @escaping FlutterResult, with value: Any?) {
    DispatchQueue.main.async {
      result(value)
    }
  }

  private func saveImageToPhotoLibrary(
    imageData: Data,
    fileName: String,
    albumName: String,
    result: @escaping FlutterResult
  ) {
    requestPhotoAccess { [weak self] granted in
      guard granted else {
        self?.complete(
          result,
          with: FlutterError(
            code: "PERMISSION_DENIED",
            message: "Photo library permission denied",
            details: nil
          )
        )
        return
      }

      self?.getOrCreateAlbum(named: albumName) { album, albumError in
        if let albumError {
          self?.complete(
            result,
            with: FlutterError(
              code: "ALBUM_ERROR",
              message: albumError.localizedDescription,
              details: nil
            )
          )
          return
        }

        var savedAssetId: String?
        PHPhotoLibrary.shared().performChanges({
          let creationRequest = PHAssetCreationRequest.forAsset()
          let options = PHAssetResourceCreationOptions()
          options.originalFilename = fileName
          creationRequest.addResource(with: .photo, data: imageData, options: options)
          savedAssetId = creationRequest.placeholderForCreatedAsset?.localIdentifier

          if let album,
            let placeholder = creationRequest.placeholderForCreatedAsset,
            let albumChangeRequest = PHAssetCollectionChangeRequest(for: album)
          {
            albumChangeRequest.addAssets([placeholder] as NSArray)
          }
        }) { success, error in
          if success {
            self?.complete(result, with: savedAssetId ?? "saved")
          } else {
            self?.complete(
              result,
              with: FlutterError(
                code: "SAVE_FAILED",
                message: error?.localizedDescription ?? "Failed to save image",
                details: nil
              )
            )
          }
        }
      }
    }
  }

  private func requestPhotoAccess(completion: @escaping (Bool) -> Void) {
    if #available(iOS 14, *) {
      let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
      if status == .authorized || status == .limited {
        completion(true)
        return
      }

      PHPhotoLibrary.requestAuthorization(for: .readWrite) { newStatus in
        completion(newStatus == .authorized || newStatus == .limited)
      }
    } else {
      let status = PHPhotoLibrary.authorizationStatus()
      if status == .authorized {
        completion(true)
        return
      }

      PHPhotoLibrary.requestAuthorization { newStatus in
        completion(newStatus == .authorized)
      }
    }
  }

  private func getOrCreateAlbum(
    named albumName: String,
    completion: @escaping (PHAssetCollection?, Error?) -> Void
  ) {
    if let existing = fetchAlbum(named: albumName) {
      completion(existing, nil)
      return
    }

    var placeholder: PHObjectPlaceholder?
    PHPhotoLibrary.shared().performChanges({
      let createRequest = PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: albumName)
      placeholder = createRequest.placeholderForCreatedAssetCollection
    }) { success, error in
      guard success, let localId = placeholder?.localIdentifier else {
        completion(nil, error)
        return
      }

      let result = PHAssetCollection.fetchAssetCollections(
        withLocalIdentifiers: [localId],
        options: nil
      )
      completion(result.firstObject, nil)
    }
  }

  private func fetchAlbum(named albumName: String) -> PHAssetCollection? {
    let fetchOptions = PHFetchOptions()
    fetchOptions.predicate = NSPredicate(format: "title = %@", albumName)

    let result = PHAssetCollection.fetchAssetCollections(
      with: .album,
      subtype: .albumRegular,
      options: fetchOptions
    )
    return result.firstObject
  }
}
