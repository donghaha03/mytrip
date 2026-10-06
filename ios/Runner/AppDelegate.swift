import Flutter
import UIKit
import AVFoundation
import PhotosUI
import Vision
import VisionKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let receipt = ReceiptBridge()
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let channel = FlutterMethodChannel(
      name: "mytrip/receipt",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { result(nil); return }
      switch call.method {
      case "open":
        let options = call.arguments as? [String: Any]
        self.receipt.open(result, captureOnly: options?["captureOnly"] as? Bool ?? false)
      case "close": self.receipt.close(); result(nil)
      default: result(FlutterMethodNotImplemented)
      }
    }
  }
}

/// Apple's scanner handles receipt edges and retakes. Configured LLM mode returns only the photo.
private final class ReceiptBridge: NSObject,
  VNDocumentCameraViewControllerDelegate, PHPickerViewControllerDelegate {
  private var completion: FlutterResult?
  private var session: UUID?
  private var captureOnly = false
  private weak var presented: UIViewController?

  private var presenter: UIViewController? {
    let scene = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .first { $0.activationState == .foregroundActive }
    var controller = scene?.windows.first { $0.isKeyWindow }?.rootViewController
    while let next = controller?.presentedViewController { controller = next }
    return controller
  }

  func open(_ result: @escaping FlutterResult, captureOnly: Bool) {
    guard completion == nil else {
      result(FlutterError(code: "busy", message: "이미 영수증을 인식하고 있어요.", details: nil))
      return
    }
    guard let parent = presenter else {
      result(FlutterError(code: "unavailable", message: "촬영 화면을 열지 못했어요.", details: nil))
      return
    }
    completion = result
    self.captureOnly = captureOnly
    session = UUID()
    let token = session
    let sheet = UIAlertController(title: "영수증 추가", message: "영수증 전체가 보이게 촬영해주세요.", preferredStyle: .actionSheet)
    sheet.addAction(UIAlertAction(title: "영수증 촬영", style: .default) { [weak self, weak sheet] _ in
      guard self?.session == token else { return }
      sheet?.dismiss(animated: true) { self?.startCamera(token) }
    })
    sheet.addAction(UIAlertAction(title: "사진 선택", style: .default) { [weak self, weak sheet] _ in
      guard self?.session == token else { return }
      sheet?.dismiss(animated: true) { self?.startPhotos() }
    })
    sheet.addAction(UIAlertAction(title: "취소", style: .cancel) { [weak self] _ in self?.finish(nil) })
    sheet.popoverPresentationController?.sourceView = parent.view
    sheet.popoverPresentationController?.sourceRect = CGRect(x: parent.view.bounds.midX, y: parent.view.bounds.midY, width: 1, height: 1)
    presented = sheet
    parent.present(sheet, animated: true)
  }

  private func startCamera(_ token: UUID?) {
    guard VNDocumentCameraViewController.isSupported else {
      fail("이 기기에서는 촬영을 사용할 수 없어요. 사진 선택이나 수동 입력을 이용해주세요.")
      return
    }
    func show(_ allowed: Bool) {
      guard session == token else { return }
      guard allowed else {
        fail("카메라 권한이 꺼져 있어요. 설정에서 여행 장부의 카메라를 허용하거나 사진을 선택해주세요.")
        return
      }
      let camera = VNDocumentCameraViewController()
      camera.delegate = self
      camera.modalPresentationStyle = .fullScreen
      presented = camera
      presenter?.present(camera, animated: true)
    }
    if AVCaptureDevice.authorizationStatus(for: .video) == .notDetermined {
      AVCaptureDevice.requestAccess(for: .video) { allowed in
        DispatchQueue.main.async { show(allowed) }
      }
    } else {
      show(AVCaptureDevice.authorizationStatus(for: .video) == .authorized)
    }
  }

  private func startPhotos() {
    // PHPicker exposes only the selected image; no full photo-library permission.
    var configuration = PHPickerConfiguration()
    configuration.filter = .images
    configuration.selectionLimit = 1
    let picker = PHPickerViewController(configuration: configuration)
    picker.delegate = self
    picker.modalPresentationStyle = .fullScreen
    presented = picker
    presenter?.present(picker, animated: true)
  }

  func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
    guard controller === presented else { return }
    let token = session
    guard scan.pageCount == 1 else {
      controller.dismiss(animated: true) {
        if self.session == token { self.fail("영수증은 한 장씩 촬영해주세요.") }
      }
      return
    }
    let image = scan.imageOfPage(at: 0)
    controller.dismiss(animated: true) {
      if self.session == token { self.recognize(image) }
    }
  }
  func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
    guard controller === presented else { return }
    let token = session
    controller.dismiss(animated: true) {
      if self.session == token { self.finish(nil) }
    }
  }
  func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
    guard controller === presented else { return }
    let token = session
    controller.dismiss(animated: true) {
      if self.session == token { self.fail("촬영하지 못했어요. 다시 시도하거나 사진을 선택해주세요.") }
    }
  }
  func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
    let token = session
    picker.dismiss(animated: true) {
      guard self.session == token else { return }
      guard let provider = results.first?.itemProvider else { self.finish(nil); return }
      provider.loadObject(ofClass: UIImage.self) { object, _ in
        DispatchQueue.main.async {
          guard self.session == token else { return }
          guard let image = object as? UIImage else {
            self.fail("사진을 불러오지 못했어요. 다른 사진을 선택해주세요.")
            return
          }
          self.recognize(image)
        }
      }
    }
  }

  private func recognize(_ image: UIImage) {
    guard let token = session else { return }
    let photoOnly = captureOnly
    DispatchQueue.global(qos: .userInitiated).async {
      do {
        // Normalize orientation and bound memory, without a square crop.
        let scale = min(1, 2000 / max(image.size.width, image.size.height))
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let normalized = UIGraphicsImageRenderer(size: size, format: format).image { _ in
          image.draw(in: CGRect(origin: .zero, size: size))
        }
        guard let cgImage = normalized.cgImage,
              let jpeg = normalized.jpegData(compressionQuality: 0.95) else {
          throw NSError(domain: "Receipt", code: 1)
        }
        var payload: [String: Any] = ["image": "data:image/jpeg;base64," + jpeg.base64EncodedString()]
        if !photoOnly {
          let request = VNRecognizeTextRequest()
          request.recognitionLevel = .accurate
          request.usesLanguageCorrection = true
          let supported = try request.supportedRecognitionLanguages()
          request.recognitionLanguages = ["ko-KR", "en-US", "ja-JP", "zh-Hans"]
            .filter { supported.contains($0) }
          if #available(iOS 16.0, *) { request.automaticallyDetectsLanguage = true }
          try VNImageRequestHandler(cgImage: cgImage, options: [:]).perform([request])
          let lines = (request.results ?? []).compactMap { $0.topCandidates(1).first }
          guard !lines.isEmpty else { throw NSError(domain: "Receipt", code: 2) }
          payload["text"] = lines.map { $0.string }.joined(separator: "\n")
          payload["confidence"] = Double(lines.map { $0.confidence }.reduce(0, +)) / Double(lines.count) * 100
        }
        let json = try JSONSerialization.data(withJSONObject: payload)
        DispatchQueue.main.async {
          guard self.session == token else { return }
          self.finish(String(data: json, encoding: .utf8))
        }
      } catch {
        DispatchQueue.main.async {
          guard self.session == token else { return }
          self.fail("영수증 내용을 찾지 못했어요. 선명한 사진으로 다시 시도하거나 수동으로 입력해주세요.")
        }
      }
    }
  }

  func close() {
    presented?.dismiss(animated: false)
    finish(nil)
  }
  private func fail(_ message: String) {
    finish(FlutterError(code: "receipt", message: message, details: nil))
  }
  private func finish(_ value: Any?) {
    let result = completion
    completion = nil
    session = nil
    presented = nil
    result?(value)
  }
}
