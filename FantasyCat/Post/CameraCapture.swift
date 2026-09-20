import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// Take a photo or a video now. The system camera UI, because it is the one
/// people already know, with both modes. Hidden where there's no camera (the
/// Simulator), so this can only be tried on a phone.
struct CameraCapture: UIViewControllerRepresentable {
    static var isAvailable: Bool { UIImagePickerController.isSourceTypeAvailable(.camera) }

    let done: (URL?) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let c = UIImagePickerController()
        c.sourceType = .camera
        c.mediaTypes = [UTType.image.identifier, UTType.movie.identifier]
        c.videoQuality = .typeHigh
        c.videoMaximumDuration = 120 // the trim bar picks which 30 seconds to keep
        c.delegate = context.coordinator
        return c
    }

    func updateUIViewController(_ controller: UIImagePickerController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(done: done) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let done: (URL?) -> Void
        init(done: @escaping (URL?) -> Void) { self.done = done }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { done(nil) }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            let tmp = FileManager.default.temporaryDirectory
            if let movie = info[.mediaURL] as? URL {
                // The camera's own file goes away with the picker: keep a copy.
                let dest = tmp.appending(path: "shot-\(UUID().uuidString).\(movie.pathExtension.isEmpty ? "mov" : movie.pathExtension)")
                done((try? FileManager.default.copyItem(at: movie, to: dest)) != nil ? dest : nil)
            } else if let image = info[.originalImage] as? UIImage, let data = image.jpegData(compressionQuality: 0.92) {
                // jpegData bakes in the orientation, so the server sees it upright.
                let dest = tmp.appending(path: "shot-\(UUID().uuidString).jpg")
                done((try? data.write(to: dest)) != nil ? dest : nil)
            } else {
                done(nil)
            }
        }
    }
}
