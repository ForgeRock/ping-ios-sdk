//
//  SocialButtonView.swift
//  PingExample
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import SwiftUI
import PingDavinci
import PingBrowser
import PingExternal_idp
import PingExternal_idp_Facebook
import PingExternal_idp_Apple
import PingExternal_idp_Google

public struct SocialButtonView: View {
    
    @StateObject public var socialButtonViewModel: SocialButtonViewModel
    
    public let onNext: (Bool) -> Void
    public let onStart: () -> Void
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                Task {
                    let result = await socialButtonViewModel.startSocialAuthentication()
                    switch result {
                    case .success(_):
                        onNext(true)
                    case .failure(let error):
                        print(error)
                        onStart()
                    }
                }
            } label: {
                socialButtonViewModel.socialButtonText()
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
    }
}

@MainActor
public class SocialButtonViewModel: ObservableObject {
    @Published public var isComplete: Bool = false
    public let idpCollector: IdpCollector
    
    public init(idpCollector: IdpCollector) {
        self.idpCollector = idpCollector
    }
    
    public func startSocialAuthentication() async -> Result<Bool, IdpExceptions> {
        return await idpCollector.authorize()
    }
    
    public func socialButtonText() -> some View {
        let bgColor: Color
        switch idpCollector.idpType {
        case "APPLE":
            bgColor = Color.appleButtonBackground
        case "GOOGLE":
            bgColor = Color.googleButtonBackground
        case "FACEBOOK":
            bgColor = Color.facebookButtonBackground
        default:
            bgColor = Color.themeButtonBackground
        }
        let text = Text(idpCollector.label)
            .font(.headline)
            .foregroundColor(.white)
            .padding()
            .frame(width: 300, height: 50)
            .background(bgColor)
            .cornerRadius(15.0)
        
        return text
    }
}
