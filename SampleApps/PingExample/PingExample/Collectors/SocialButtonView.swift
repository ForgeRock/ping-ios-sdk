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

    // Blocks a second tap while a ceremony/authorization is in flight; the button now has
    // real pressed/disabled feedback via `PingActionButtonStyle`, so this must be wired
    // explicitly instead of relying on system button behavior during the async `Task`.
    @State private var isAuthenticating = false

    public var body: some View {
        VStack(alignment: .leading, spacing: PingTheme.Spacing.small) {
            if socialButtonViewModel.isFacebook {
                Toggle("Limited Login (OIDC ID token)", isOn: $socialButtonViewModel.facebookLimitedLoginEnabled)
                    .font(PingTheme.Typography.supporting)
                    .frame(maxWidth: .infinity)
            }
            Button {
                isAuthenticating = true
                Task {
                    let result = await socialButtonViewModel.startSocialAuthentication()
                    isAuthenticating = false
                    switch result {
                    case .success(_):
                        onNext(true)
                    case .failure(let error):
                        print(error)
                        onStart()
                    }
                }
            } label: {
                Text(socialButtonViewModel.idpCollector.label)
            }
            .buttonStyle(PingActionButtonStyle(role: .provider(
                background: socialButtonViewModel.providerBackground,
                foreground: .white
            )))
            .disabled(isAuthenticating)
        }
        .padding(.vertical, PingTheme.Spacing.small)
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

    /// The provider-branded surface for this collector's identity provider.
    ///
    /// Brand color selection stays caller-decided per DESIGN_SYSTEM.md; the
    /// `default` branch is a generic fallback and uses ``PingTheme/Color/actionPrimary``.
    public var providerBackground: Color {
        switch idpCollector.idpType {
        case Constants.APPLE:
            return PingTheme.Color.brandApple
        case Constants.GOOGLE:
            return PingTheme.Color.brandGoogle
        case Constants.FACEBOOK:
            return PingTheme.Color.brandFacebook
        default:
            return PingTheme.Color.actionPrimary
        }
    }
}
