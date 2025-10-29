//
//  BindingKeysViewModel.swift
//  PingExample
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation
import PingBinding
import PingMfaCommons

@MainActor
class BindingKeysViewModel: ObservableObject {
    
    @Published var userKeys: [UserKey] = []
    
    func fetchKeys() {
        do {
            self.userKeys = try BindingModule.getAllKeys()
        } catch {
            print("Error fetching keys: \(error)")
        }
    }
    
    func deleteKey(key: UserKey) {
        do {
            try BindingModule.deleteKey(key)
            fetchKeys()
        } catch {
            print("Error deleting key: \(error)")
        }
    }
    
    func deleteAllKeys() {
        do {
            try BindingModule.deleteAllKeys()
            fetchKeys()
        } catch {
            print("Error deleting all keys: \(error)")
        }
    }
}
