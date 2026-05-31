import AVFoundation
import SceneKit
import SwiftUI
import UIKit

struct EquirectangularSceneView: UIViewRepresentable {
    let content: RenderContent

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView(frame: .zero)
        view.backgroundColor = .black
        view.autoenablesDefaultLighting = false
        view.allowsCameraControl = false
        view.preferredFramesPerSecond = 60
        view.isPlaying = true
        view.scene = context.coordinator.makeScene(with: content)

        let pan = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePan(_:)))
        let pinch = UIPinchGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePinch(_:)))
        view.addGestureRecognizer(pan)
        view.addGestureRecognizer(pinch)

        return view
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
        uiView.isPlaying = true
        context.coordinator.updateContentIfNeeded(content, in: uiView)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator: NSObject {
        private let scene = SCNScene()
        private let cameraNode = SCNNode()
        private let sphereNode = SCNNode()
        private var currentSignature = ""
        private var yaw: Float = 0
        private var pitch: Float = 0
        private var fieldOfView: CGFloat = 70

        func makeScene(with content: RenderContent) -> SCNScene {
            let camera = SCNCamera()
            camera.fieldOfView = fieldOfView
            camera.zNear = 0.01
            camera.zFar = 100
            cameraNode.camera = camera
            cameraNode.position = SCNVector3(0, 0, 0)
            scene.rootNode.addChildNode(cameraNode)

            let sphere = SCNSphere(radius: 10)
            sphere.segmentCount = 96
            sphere.firstMaterial?.isDoubleSided = true
            sphere.firstMaterial?.cullMode = .front
            sphere.firstMaterial?.diffuse.mipFilter = .linear
            sphereNode.geometry = sphere
            sphereNode.scale = SCNVector3(-1, 1, 1)
            scene.rootNode.addChildNode(sphereNode)

            apply(content: content)
            return scene
        }

        func updateContentIfNeeded(_ content: RenderContent, in view: SCNView) {
            let signature = makeSignature(for: content)
            guard signature != currentSignature else { return }
            apply(content: content)
            view.scene = scene
        }

        private func apply(content: RenderContent) {
            guard let material = sphereNode.geometry?.firstMaterial else { return }
            switch content {
            case .image(let image):
                material.diffuse.contents = image
                currentSignature = "image-\(Unmanaged.passUnretained(image).toOpaque())"
            case .player(let player):
                material.diffuse.contents = player
                currentSignature = "player-\(Unmanaged.passUnretained(player).toOpaque())"
            }
        }

        private func makeSignature(for content: RenderContent) -> String {
            switch content {
            case .image(let image):
                return "image-\(Unmanaged.passUnretained(image).toOpaque())"
            case .player(let player):
                return "player-\(Unmanaged.passUnretained(player).toOpaque())"
            }
        }

        @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
            guard let view = gesture.view else { return }
            let translation = gesture.translation(in: view)
            gesture.setTranslation(.zero, in: view)

            let sensitivity: Float = 0.005
            yaw += Float(translation.x) * sensitivity
            pitch += Float(translation.y) * sensitivity
            pitch = min(max(pitch, -.pi / 2 + 0.01), .pi / 2 - 0.01)

            cameraNode.eulerAngles = SCNVector3(pitch, yaw, 0)
        }

        @objc func handlePinch(_ gesture: UIPinchGestureRecognizer) {
            guard let camera = cameraNode.camera else { return }
            if gesture.state == .changed {
                fieldOfView /= gesture.scale
                fieldOfView = min(max(fieldOfView, 35), 100)
                camera.fieldOfView = fieldOfView
                gesture.scale = 1
            }
        }
    }
}
