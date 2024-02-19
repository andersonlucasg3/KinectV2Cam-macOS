//
//  ContentView.swift
//  KinectV2CameraActivator
//
//  Created by Anderson Lucas de Castro Ramos on 18/02/24.
//

import SwiftUI

import SystemExtensions

struct ContentView: View 
{
    @State var kinectV2SystemExtensionRequest: KinectV2SystemExtensionRequest = .init()
    
    var body: some View
    {
        VStack {
            Button {
                kinectV2SystemExtensionRequest.install()
            } label: {
                Text(verbatim: "Install Extension")
            }.alert(kinectV2SystemExtensionRequest.message, isPresented: $kinectV2SystemExtensionRequest.hasMessage) {
                Button {
                    kinectV2SystemExtensionRequest.clearMessage()
                } label: {
                    Text(verbatim: "Ok")
                }

            }
            
            Button {
                kinectV2SystemExtensionRequest.uninstall()
            } label: {
                Text(verbatim: "Uninstall Extension")
            }.alert(kinectV2SystemExtensionRequest.message, isPresented: $kinectV2SystemExtensionRequest.hasMessage) {
                Button {
                    kinectV2SystemExtensionRequest.clearMessage()
                } label: {
                    Text(verbatim: "Ok")
                }
            }
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
