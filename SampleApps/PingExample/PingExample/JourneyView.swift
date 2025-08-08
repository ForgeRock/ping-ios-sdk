//
//  JourneyView.swift
//  PingExample
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation
import SwiftUI
import PingOrchestrate
import PingJourney
import PingProtect
import PingExternalIdP

struct JourneyView: View {
    /// The view model that manages the Journey flow logic.
    @StateObject private var journeyViewModel = JourneyViewModel()
    /// A binding to the navigation stack path.
    @Binding var path: [String]
    
    var body: some View {
        ZStack {
            if journeyViewModel.showJourneyNameInput {
                // Show journey name input screen
                JourneyNameInputView(journeyViewModel: journeyViewModel)
            } else {
                // Show the normal journey flow
                ScrollView {
                    VStack {
                        Spacer()
                        // Handle different types of nodes in the Journey.
                        switch journeyViewModel.state.node {
                        case let continueNode as ContinueNode:
                            // Display the callback view for the next node.
                            CallbackView(journeyViewModel: journeyViewModel, node: continueNode)
                        case let errorNode as ErrorNode:
                            // Handle server-side errors (e.g., invalid credentials)
                            // Display error to the user
                            ErrorNodeView(node: errorNode)
                            if let nextNode = errorNode.continueNode {
                                CallbackView(journeyViewModel: journeyViewModel, node: nextNode)
                            }
                        case let failureNode as FailureNode:
                            ErrorView(message: failureNode.cause.localizedDescription)
                        case is SuccessNode:
                            // Authentication successful, retrieve the session
                            VStack{}.onAppear {
                                path.removeLast()
                                path.append("Token")
                            }
                        default:
                            EmptyView()
                        }
                    }
                }
            }
        }
    }
}

/// A view for collecting the journey name before starting the flow
struct JourneyNameInputView: View {
    @ObservedObject var journeyViewModel: JourneyViewModel
    @State private var journeyName: String = ""
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image("Logo")
                .resizable()
                .scaledToFill()
                .frame(width: 120, height: 120)
            
            VStack(spacing: 16) {
                Text("Enter Journey Name")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                TextField("Journey Name", text: $journeyName)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray, lineWidth: 1)
                    )
                    .onAppear() { journeyName = journeyViewModel.getSavedJourneyName() }
                
                Spacer()
                
                NextButton(title: "Start Journey") {
                    Task {
                        journeyViewModel.saveJourneyName(journeyName)
                        await journeyViewModel.startJourney(with: journeyName)
                    }
                }
            }
            
            Spacer()
        }
        .padding()
    }
}

/// A view for displaying the current step in the Journey flow.
struct CallbackView: View {
    /// The Journey view model managing the flow.
    @ObservedObject var journeyViewModel: JourneyViewModel
    /// The next node to process in the flow.
    public var node: ContinueNode
    
    var body: some View {
        VStack {
            Image("Logo").resizable().scaledToFill().frame(width: 100, height: 100)
            
            JourneyNodeView(continueNode: node,
                            onNodeUpdated:  { journeyViewModel.refresh() },
                            onStart: { Task { await journeyViewModel.startJourney(with: journeyViewModel.getSavedJourneyName()) }},
                            onNext: { Task {
                print("Next button tapped")
                await journeyViewModel.next(node: node)
            }})
        }
        
    }
}

struct JourneyNodeView: View {
    var continueNode: ContinueNode
    let onNodeUpdated: () -> Void
    let onStart: () -> Void
    let onNext: () -> Void
    
    private var showNext: Bool {
        !continueNode.callbacks.contains { callback in
            callback is ConfirmationCallback ||
            callback is SuspendedTextOutputCallback ||
            callback is PingOneProtectInitializeCallback ||
            callback is PingOneProtectEvaluationCallback ||
            callback is SelectIdpCallback ||
            callback is IdpCallback
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            
            ForEach(continueNode.callbacks, id: \.id) { callback in
                switch callback {
                case let booleanCallback as BooleanAttributeInputCallback:
                    BooleanAttributeInputCallbackView(callback: booleanCallback, onNodeUpdated: onNodeUpdated)
                    
                case let choiceCallback as ChoiceCallback:
                    ChoiceCallbackView(callback: choiceCallback, onNodeUpdated: onNodeUpdated)
                    
                case let confirmationCallback as ConfirmationCallback:
                    ConfirmationCallbackView(callback: confirmationCallback, onSelected: onNext)
                    
                case let consentCallback as ConsentMappingCallback:
                    ConsentMappingCallbackView(callback: consentCallback, onNodeUpdated: onNodeUpdated)
                    
                case let kbaCallback as KbaCreateCallback:
                    KbaCreateCallbackView(callback: kbaCallback, onNodeUpdated: onNodeUpdated)
                    
                case let numberCallback as NumberAttributeInputCallback:
                    NumberAttributeInputCallbackView(callback: numberCallback, onNodeUpdated: onNodeUpdated)
                    
                case let passwordCallback as PasswordCallback:
                    PasswordCallbackView(callback: passwordCallback, onNodeUpdated: onNodeUpdated)
                    
                case let pollingCallback as PollingWaitCallback:
                    PollingWaitCallbackView(callback: pollingCallback, onTimeout: onNext)
                    
                case let stringCallback as StringAttributeInputCallback:
                    StringAttributeInputCallbackView(callback: stringCallback, onNodeUpdated: onNodeUpdated)
                    
                case let termsCallback as TermsAndConditionsCallback:
                    TermsAndConditionsCallbackView(callback: termsCallback, onNodeUpdated: onNodeUpdated)
                    
                case let textInputCallback as TextInputCallback:
                    TextInputCallbackView(callback: textInputCallback, onNodeUpdated: onNodeUpdated)
                    
                case let textOutputCallback as TextOutputCallback:
                    TextOutputCallbackView(callback: textOutputCallback)
                    
                case let suspendedTextCallback as SuspendedTextOutputCallback:
                    TextOutputCallbackView(callback: suspendedTextCallback)
                    
                case let nameCallback as NameCallback:
                    NameCallbackView(callback: nameCallback, onNodeUpdated: onNodeUpdated)
                    
                case let validatedUsernameCallback as ValidatedUsernameCallback:
                    ValidatedUsernameCallbackView(callback: validatedUsernameCallback, onNodeUpdated: onNodeUpdated)
                    
                case let validatedPasswordCallback as ValidatedPasswordCallback:
                    ValidatedPasswordCallbackView(callback: validatedPasswordCallback, onNodeUpdated: onNodeUpdated)
                    
                case let protectInitCallback as PingOneProtectInitializeCallback:
                    PingOneProtectInitializeCallbackView(callback: protectInitCallback, onNext: onNext)
                    
                case let protectEvalCallback as PingOneProtectEvaluationCallback:
                    PingOneProtectEvaluationCallbackView(callback: protectEvalCallback, onNext: onNext)
                    
                case let selectIdpCallback as SelectIdpCallback:
                    SelectIdpCallbackView(callback: selectIdpCallback, onNext: onNext)
                    
                case let idpCallback as IdpCallback:
                    let idpCallbackViewModel = IdpCallbackViewModel(callback: idpCallback)
                    IdpCallbackView(viewModel: idpCallbackViewModel, onNext: onNext)

                default:
                    EmptyView()
                }
            }
            
            if showNext {
                Button(action: { onNext() }) {
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

struct IdpCallbackView: View {
    @StateObject var viewModel: IdpCallbackViewModel
    
    let onNext: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            switch viewModel.authState {
            case .authenticating:
                Image(systemName: "person.circle.fill")
                    .font(.largeTitle)
                    .foregroundColor(.white)
                Text(viewModel.callback.provider)
                    .font(.body)
                    .foregroundColor(.secondary)
                    NextButton(title: "Continue") {
                        Task { @MainActor in
                            if viewModel.hasStartedAuthorization == false {
                                // Call the performAuthorization method to start the process.
                                await viewModel.performAuthorization()
                            }
                        }
                    }
            case .failure(let error):
                Image(systemName: "xmark.octagon.fill")
                    .font(.largeTitle)
                    .foregroundColor(.red)
                Text("Authorization failed: \(error.localizedDescription)")
                    .font(.body)
                    .multilineTextAlignment(.center)
                NextButton(title: "Continue") {
                    Task {
                        self.onNext()
                    }
                }
                .buttonStyle(.bordered)
                
            case .completed:
                Image(systemName: "checkmark.circle.fill")
                    .font(.largeTitle)
                    .foregroundColor(.green)
                Text("Authorization Successful")
                    .font(.body)
                    .multilineTextAlignment(.center)
                NextButton(title: "Continue") {
                    Task {
                        self.onNext()
                    }
                }
            }
        }
        .padding()
    }
}

@MainActor
class IdpCallbackViewModel: ObservableObject {
    
    @Published var authState: AuthState = .authenticating
    
    // 1. Add a flag to track if the task has been started.
    var hasStartedAuthorization = false
    
    let callback: IdpCallback

    enum AuthState {
        case authenticating
        case completed
        case failure(Error)
    }
    
    init(callback: IdpCallback) {
        self.callback = callback
    }
    
    func performAuthorization() async {
        Task { @MainActor in
            // 2. Check the flag. If the task has already run, do nothing.
            guard !hasStartedAuthorization else { return }
            hasStartedAuthorization = true
            
            let result = await callback.authorize()
            
            switch result {
            case .success:
                self.authState = .completed
            case .failure(let error):
                self.authState = .failure(error)
            }
        }
    }
}

struct SelectIdpCallbackView: View {
    let callback: SelectIdpCallback
    let onNext: () -> Void
    
    var body: some View {
        ScrollView {
            
            LazyVStack(alignment: .center, spacing: 12) {
                
                // Add a title for better context
                Text("Select a provider")
                    .font(.headline)
                    .padding(.bottom, 8)
                
                ForEach(callback.providers) { provider in
                    Button(action: {
                        callback.value = provider.provider
                        self.onNext()
                    }) {
                        // Make the button label more descriptive and visually appealing
                        Text(provider.provider.capitalized)
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .padding()
    }
}
