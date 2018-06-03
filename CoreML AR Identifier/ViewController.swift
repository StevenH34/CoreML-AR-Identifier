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
        let scene = SCNScene(named: "art.scnassets/ship.scn")!
        
        // Set the scene to the view
        sceneView.scene = scene
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
    
    // Sends it the image
    func visionRequest(pixelBuffer: CVPixelBuffer) {
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
