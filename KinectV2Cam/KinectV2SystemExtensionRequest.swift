//
//  SystemExtensionDelegate.swift
//  KinectV2CameraActivator
//
//  Created by Anderson Lucas de Castro Ramos on 18/02/24.
//

import SwiftUI
import SystemExtensions

@Observable class KinectV2SystemExtensionRequest : NSObject, OSSystemExtensionRequestDelegate
{
    private let _identifier = "br.com.andersonramos.KinectV2Cam.KV2VirtualCam"
    
    var message: String = ""
    var hasMessage: Bool = false
    
    func install()
    {
        hasMessage = false

        // Submit an activation request.
        let activationRequest = OSSystemExtensionRequest.activationRequest(forExtensionWithIdentifier: _identifier, queue: .main)
        activationRequest.delegate = self
        OSSystemExtensionManager.shared.submitRequest(activationRequest)
    }
    
    func uninstall()
    {
        hasMessage = false
        
        let deactivationRequest = OSSystemExtensionRequest.deactivationRequest(forExtensionWithIdentifier: _identifier, queue: .main)
        deactivationRequest.delegate = self
        OSSystemExtensionManager.shared.submitRequest(deactivationRequest)
    }
    
    func clearMessage()
    {
        message = ""
        hasMessage = false
    }
    
    func request(_ request: OSSystemExtensionRequest, actionForReplacingExtension existing: OSSystemExtensionProperties, withExtension ext: OSSystemExtensionProperties) -> OSSystemExtensionRequest.ReplacementAction
    {
        OSSystemExtensionRequest.ReplacementAction.replace
    }
    
    func requestNeedsUserApproval(_ request: OSSystemExtensionRequest) 
    {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security") else 
        {
            fatalError()
        }
        NSWorkspace.shared.open(url)
    }
    
    func request(_ request: OSSystemExtensionRequest, didFinishWithResult result: OSSystemExtensionRequest.Result) 
    {
        // nothing
    }
    
    func request(_ request: OSSystemExtensionRequest, didFailWithError error: Error) 
    {
        message = "SystemExtensionRequest didFailWithError: \(error)"
        hasMessage = true
    }
}
