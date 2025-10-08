// 
//  ContinueNodeView.swift
//  PingExample
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import SwiftUI
import PingOrchestrate
import PingDavinci
import PingExternalIdP
import PingProtect
import PingFido2

struct ContinueNodeView: View {
    var continueNode: ContinueNode
    let onNodeUpdated: () -> Void
    let onStart: () -> Void
    let onNext: (Bool) -> Void
    
    @EnvironmentObject var validationViewModel: ValidationViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(continueNode.name)
                .font(.largeTitle)
                .fontWeight(.bold)
                .frame(maxWidth: .infinity, alignment: .center)
                .foregroundStyle(Color.gray)
            Text(continueNode.description)
                .font(.subheadline)
                .frame(maxWidth: .infinity, alignment: .center)
                .foregroundStyle(Color.gray)
            
            Divider()
            
            ForEach(continueNode.collectors, id: \.id) { collector in
                switch collector {
                case let flowCollector as FlowCollector:
                    FlowButtonView(field: flowCollector, onNext: onNext)
                case let passwordCollector as PasswordCollector:
                    PasswordView(field: passwordCollector, onNodeUpdated: onNodeUpdated)
                case let submitCollector as SubmitCollector:
                    SubmitButtonView(field: submitCollector, onNext: onNext)
                case let textCollector as TextCollector:
                    TextView(field: textCollector, onNodeUpdated: onNodeUpdated)
                case let labelCollector as LabelCollector:
                    LabelView(field: labelCollector)
                case let multiSelectCollector as MultiSelectCollector:
                    if multiSelectCollector.type == "COMBOBOX" {
                        ComboBoxView(field: multiSelectCollector, onNodeUpdated: onNodeUpdated)
                    } else {
                        CheckBoxView(field: multiSelectCollector, onNodeUpdated: onNodeUpdated)
                    }
                case let singleSelectCollector as SingleSelectCollector:
                    if singleSelectCollector.type == "DROPDOWN" {
                        DropdownView(field: singleSelectCollector, onNodeUpdated: onNodeUpdated)
                    } else {
                        RadioButtonView(field: singleSelectCollector, onNodeUpdated: onNodeUpdated)
                    }
                case let idpCollector as IdpCollector:
                    let viewModel = SocialButtonViewModel(idpCollector: idpCollector)
                    SocialButtonView(socialButtonViewModel: viewModel, onNext: onNext, onStart: onStart)
                case let deviceRegistrationCollector as DeviceRegistrationCollector:
                    DeviceRegistrationView(field: deviceRegistrationCollector, onNext: onNext)
                case let deviceAuthenticationCollector as DeviceAuthenticationCollector:
                    DeviceAuthenticationView(field: deviceAuthenticationCollector, onNext: onNext)
                case let phoneNumberCollector as PhoneNumberCollector:
                    PhoneNumberView(field: phoneNumberCollector, onNodeUpdated: onNodeUpdated)
                case let protectCollector as ProtectCollector:
                    ProtectView(field: protectCollector, onNodeUpdated: onNodeUpdated)
                case let fido2RegistrationCollector as Fido2RegistrationCollector:
                    Fido2RegistrationCollectorView(collector: fido2RegistrationCollector, onNext: { onNext(true) })
                case let fido2AuthenticationCollector as Fido2AuthenticationCollector:
                    Fido2AuthenticationCollectorView(collector: fido2AuthenticationCollector, onNext: { onNext(true) })
                default:
                    EmptyView()
                }
            }

            // Fallback Next Button
            if !continueNode.collectors.contains(where: { $0 is FlowCollector || $0 is SubmitCollector || $0 is DeviceRegistrationCollector || $0 is DeviceAuthenticationCollector || $0 is Fido2RegistrationCollector || $0 is Fido2AuthenticationCollector }) {
                Button(action: { onNext(false) }) {
                    Text("Next")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.themeButtonBackground)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .padding(.top, 16)
            }
        }
        .padding()
    }
}
