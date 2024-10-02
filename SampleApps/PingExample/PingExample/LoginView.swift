//
//  LoginView.swift
//  PingExample
//
//  Copyright (c) 2024 Ping Identity. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation
import SwiftUI
import PingOrchestrate
import PingDavinci

struct DavinciView: View {
  
  @StateObject private var viewmodel =  DavinciViewModel()
  @Binding var path: [String]
  
  var body: some View {
    ZStack {
      ScrollView {
        VStack {
          Spacer()
          switch viewmodel.data.currentNode {
          case let connector as Connector:
            ConnectorView(viewmodel: viewmodel, connector: connector)
          case is SuccessNode:
            VStack{}.onAppear {
              path.removeLast()
              path.append("Token")
            }
          case let errorNode as ErrorNode:
            if let connector = viewmodel.data.previousNode as? Connector {
              ConnectorView(viewmodel: viewmodel, connector: connector)
            }
            ErrorView(name: errorNode.cause.localizedDescription)
          case let failureNode as FailureNode:
            if let connector = viewmodel.data.previousNode as? Connector {
              ConnectorView(viewmodel: viewmodel, connector: connector)
            }
            ErrorView(name: failureNode.message)
          default:
            EmptyView()
          }
        }
      }
      
      Spacer()
      
      // Activity indicator
      if viewmodel.isLoading {
        Color.black.opacity(0.4)
          .edgesIgnoringSafeArea(.all)
        
        ProgressView()
          .progressViewStyle(CircularProgressViewStyle())
          .scaleEffect(4) // Increase spinner size if needed
          .foregroundColor(.white) // Set spinner color
      }
    }
  }
}

struct ConnectorView: View {
  
  @ObservedObject var viewmodel: DavinciViewModel
  public var connector: Connector
  
  var body: some View {
    VStack {
      Image("Logo").resizable().scaledToFill().frame(width: 100, height: 100)
        .padding(.vertical, 32)
      HeaderView(name: connector.name)
      NewLoginView(
        davinciViewModel: viewmodel,
        connector: connector, collectorsList: connector.collectors)
    }
  }
}

struct ErrorView: View {
  var name: String = ""
  
  var body: some View {
    VStack {
      Text("Oops! Something went wrong.\(name)")
        .foregroundColor(.red).padding(.top, 20)
    }
  }
}

struct HeaderView: View {
  var name: String = ""
  var body: some View {
    VStack {
      Text(name)
        .font(.title)
    }
  }
}

struct NewLoginView: View {
  // MARK: - Propertiers
  @ObservedObject var davinciViewModel: DavinciViewModel
  
  public var connector: Connector
  
  public var collectorsList: Collectors
  
  // MARK: - View
  var body: some View {
    
    VStack {
      
      ForEach(collectorsList, id: \.id) { field in
        
        VStack {
          if let text = field as? TextCollector {
            InputView(text: text.value, placeholderString: text.label, field: text)
          }
          
          if let password = field as? PasswordCollector {
            InputView(placeholderString: password.label, secureField: true, field: password)
          }
          
          if let submitButton = field as? SubmitCollector {
            InputButton(title: submitButton.label, field: submitButton) {
              Task {
                await davinciViewModel.next(node: connector)
              }
            }
          }
          
        }.padding(.horizontal, 5).padding(.top, 20)
        
        
        if let flowButton = field as? FlowCollector {
          Button(action: {
            flowButton.value = "action"
            Task {
              await davinciViewModel.next(node: connector)
            }
          }) {
            Text(flowButton.label)
              .foregroundColor(.black)
          }
        }
      }
    }
  }
}
