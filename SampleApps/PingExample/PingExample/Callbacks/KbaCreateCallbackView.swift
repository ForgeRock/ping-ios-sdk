//
//  KbaCreateCallbackView.swift
//  PingExample
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import SwiftUI
import PingJourney

struct KbaCreateCallbackView: View {
    let callback: KbaCreateCallback
    let onNodeUpdated: () -> Void

    @State var selectedQuestion: String = ""
    @State var answerText: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Question Picker
            VStack(alignment: .leading) {
                if !callback.prompt.isEmpty {
                                Text(callback.prompt)
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                    .multilineTextAlignment(.leading)
                            }
                Picker(callback.prompt, selection: $selectedQuestion) {
                    ForEach(callback.predefinedQuestions, id: \.self) { question in
                        Text(question).tag(question)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray, lineWidth: 1)
                )
                .onChange(of: selectedQuestion) { newValue in
                    callback.selectedQuestion = newValue
                   // onNodeUpdated()
                }
            }

            // Answer Input Field
            VStack(alignment: .leading) {
                TextField(
                    "Answer",
                    text: $answerText
                )
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray, lineWidth: 1)
                )
                .onChange(of: answerText) { newValue in
                    callback.selectedAnswer = newValue
                }
                .onSubmit {
                    onNodeUpdated()
                }
            }
        }
        .padding()
        .onAppear {
            selectedQuestion = callback.predefinedQuestions.first ?? ""
            answerText = callback.selectedAnswer
            if !selectedQuestion.isEmpty {
                callback.selectedQuestion = selectedQuestion
            }
        }
    }
}
