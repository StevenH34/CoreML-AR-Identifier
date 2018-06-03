//
//  ViewController.swift
//  CoreML AR Identifier
//
//  Created by Steven Hedges on 6/2/18.
//  Copyright © 2018 Steven Hedges. All rights reserved.
//

import UIKit
import SceneKit
import ARKit
import Vision

class ViewController: UIViewController, ARSCNViewDelegate {

    @IBOutlet var sceneView: ARSCNView!
    
    // The resnet model
    private var resnetModel = Resnet50()
    // Result of hit test
    private var hitTestResult : ARHitTestResult!
    // Array of vision requests
    private var visionRequestArray = [VNRequest]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set the view's delegate
        sceneView.delegate = self
        
        // Show statistics such as fps and timing information
        sceneView.showsStatistics = true
        
        // Create a new scene
        let scene = SCNScene()
        
        // Set the scene to the view
        sceneView.scene = scene
        
        regsiterGestureRecognizer()
    }
    
    // Register gesture
    private func regsiterGestureRecognizer() {
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(tappedScreen))
        self.sceneView.addGestureRecognizer(tapGestureRecognizer)
    }
    
    // Called when screen is tapped
    @objc func tappedScreen(recognizer: UIGestureRecognizer) {
        let sceneView = recognizer.view as! ARSCNView
        // Only need the center of the screen
        let touchLocation = self.sceneView.center
        
        // Need the current
        guard let currentFrame = sceneView.session.currentFrame else { return }
        
        // If there is a current frame, ge the hit test results
        let hitTestOfCurrentFrame = sceneView.hitTest(touchLocation, types: .featurePoint)
        if hitTestOfCurrentFrame.isEmpty { return }
        
        guard let hitTestResult = hitTestOfCurrentFrame.first else { return }
        self.hitTestResult = hitTestResult
        
        // Getting the image
        let pixelBuffer = currentFrame.capturedImage
        visionRequest(pixelBuffer: pixelBuffer)
    }
    
    // Create the text node
    private func createTextNode(text: String) -> SCNNode{
        let parentNode = SCNNode()
        
        let sphere = SCNSphere(radius: 0.01)
        let sphereMaterial = SCNMaterial()
        sphereMaterial.diffuse.contents = UIColor.blue
        sphere.firstMaterial = sphereMaterial
        
        let sphereNode = SCNNode(geometry: sphere)
        
        let textGeometry = SCNText(string: text, extrusionDepth: 0)
        textGeometry.firstMaterial?.diffuse.contents = UIColor.blue
        textGeometry.firstMaterial?.specular.contents = UIColor.white
        textGeometry.firstMaterial?.isDoubleSided = true
        
        // Change font text
        let textFont = UIFont(name: "Futura", size: 0.3)
        textGeometry.font = textFont
        
        let textNode = SCNNode(geometry: textGeometry)
        textNode.scale = SCNVector3(0.1, 0.1, 0.1)
        
        parentNode.addChildNode(sphereNode)
        parentNode.addChildNode(textNode)
        return parentNode
    }
    
    private func displayText(text: String) {
        
        let textNode = createTextNode(text: text)
        
        textNode.position = SCNVector3(self.hitTestResult.worldTransform.columns.3.x, self.hitTestResult.worldTransform.columns.3.y, self.hitTestResult.worldTransform.columns.3.z)
        
        self.sceneView.scene.rootNode.addChildNode(textNode)
    }
    
    // Sends it the image
    private func visionRequest(pixelBuffer: CVPixelBuffer) {
        // Create the model through which the vision will be passed
        let visionModel = try! VNCoreMLModel(for: self.resnetModel.model)
        // Vision CoreML request
        let request = VNCoreMLRequest(model: visionModel) { request, error in
            if error != nil { return }
            
            guard let observations = request.results else {
                return
            }
            
            let observation = observations.first as! VNClassificationObservation
            
            print("Name \(observation.identifier) and confidence is \(observation.confidence)")
            
            DispatchQueue.main.async {
                self.displayText(text: observation.identifier)
            }
        }
        
        // Configure the request
        request.imageCropAndScaleOption = .centerCrop
        self.visionRequestArray = [request]
        
        // Image request handler
        let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .upMirrored, options: [:])
        
        DispatchQueue.global().async {
            try! imageRequestHandler.perform(self.visionRequestArray)
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Create a session configuration
        let configuration = ARWorldTrackingConfiguration()

        // Run the view's session
        sceneView.session.run(configuration)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
    }
    
}
