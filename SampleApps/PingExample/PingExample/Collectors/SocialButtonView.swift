//
//  SocialButtonView.swift
//  PingExample
//
//  Copyright (c) 2025 - 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import SwiftUI
import PingDavinci
import PingDavinciPlugin
import PingBrowser
import PingExternalIdP
import PingExternalIdPFacebook
import PingExternalIdPApple
import PingExternalIdPGoogle

public struct SocialButtonView: View {
    
    @StateObject public var socialButtonViewModel: SocialButtonViewModel
    
    public let onNext: (Bool) -> Void
    public let onStart: () -> Void
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if socialButtonViewModel.isFacebook {
                Toggle("Limited Login (OIDC ID token)", isOn: $socialButtonViewModel.facebookLimitedLoginEnabled)
                    .font(.subheadline)
                    .frame(width: 300)
            }
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
    @Published public var facebookLimitedLoginEnabled: Bool = false {
        didSet {
            idpCollector.facebookLimitedLoginEnabled = facebookLimitedLoginEnabled
        }
    }
    public let idpCollector: IdpCollector

    public var isFacebook: Bool { idpCollector.idpType == Constants.FACEBOOK }

    public init(idpCollector: IdpCollector) {
        self.idpCollector = idpCollector
        self.facebookLimitedLoginEnabled = idpCollector.facebookLimitedLoginEnabled
    }
    
    public func startSocialAuthentication() async -> Result<Bool, IdpExceptions> {
        return await idpCollector.authorize()
    }
    
    public func socialButtonText() -> some View {
        let bgColor: Color
        switch idpCollector.idpType {
        case Constants.APPLE:
            bgColor = Color.appleButtonBackground
        case Constants.GOOGLE:
            bgColor = Color.googleButtonBackground
        case Constants.FACEBOOK:
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
