//
//  ContentView.swift
//  talkGPT
//
//  Created by AlohaYos on 2023/05/05.
//

import Foundation
import AVFoundation
import SwiftUI
import OpenAISwift

let apiToken = "SET YOUR ChatGPT API TOKEN HERE"

struct ContentView: View {
	@FocusState var focus
	@State var loading: Bool = false
	@State var currentQuestion: String = ""
	@State var responseList: [AIResponse] = []
	@State var error: Error?

	struct AIResponse: Identifiable {
		let id: UUID = UUID()
		let question: String
		let answer: String
	}
	
	let openAI = OpenAISwift(authToken: apiToken)
	
	@StateObject var viewModel = ContentViewModel()
	   
	   var body: some View {
		   VStack(alignment: .leading) {
			   HStack {
				   TextField("質問を入力!", text: $viewModel.voiceText)
				   Button("送信") {
					   viewModel.sendQuestion()
				   }
			   }
			   ScrollView(.vertical, showsIndicators: false) {
				   ForEach(viewModel.conversations, id: \.self) { message in
					   Text(message)
					   Spacer()
				   }
				   
				   
				   if viewModel.showProgressView {
					   HStack {
						   Spacer()
						   ProgressView("Now Loading...")
						   Spacer()
					   }
					   .padding(.top,  200)
				   }
			   }
		   }
		   .padding()
	   }
}

struct ContentView_Previews: PreviewProvider {
	static var previews: some View {
		ContentView()
	}
}

class ContentViewModel: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
	@Published var voiceText = ""
	@Published var conversations: [String] = []
	@Published var showProgressView = false
	@Published var synthesizer = AVSpeechSynthesizer()
	
	private var openAI = OpenAISwift(authToken: apiToken)
	
	override init() {
		AVSpeechSynthesisVoice.speechVoices()
	}
	
	func sendQuestion() {
		showProgressView = true
		
		guard !voiceText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
		conversations.append("質問: \(voiceText)\n")
		var sendText: String = ""
		for mes in conversations {
			sendText = sendText + mes
		}

		print("### Q ###\n"+voiceText)
		openAI.sendCompletion(with: sendText, maxTokens: 500, completionHandler: { result in
			switch result {
			case .success(let model):
				Task { @MainActor in
					self.showProgressView = false
					var responseMessage = model.choices?.first?.text ?? ""
					responseMessage = responseMessage.replacingOccurrences(of: "回答:", with: "")
					responseMessage = responseMessage.replacingOccurrences(of: "答え:", with: "")
					responseMessage = responseMessage.replacingOccurrences(of: "答え：", with: "")
					responseMessage = responseMessage.trimmingCharacters(in: .whitespacesAndNewlines)
					print("### A ###\n"+responseMessage)
					self.speechResponseMessage(message: responseMessage)

					self.conversations.append("回答: \(responseMessage)\n")
					var dumpText: String = ""
					for mes in self.conversations {
						dumpText = dumpText + mes
					}
					print("### Conversation ###\n"+dumpText)

					self.voiceText = ""
				}
			case .failure:
				self.conversations.append("ERROR")
			}
		})
	}
	
	func speechResponseMessage(message: String) {
		let utterance = AVSpeechUtterance(string: message)
		utterance.rate = 0.5

		let voices = AVSpeechSynthesisVoice.speechVoices()
		let voice:AVSpeechSynthesisVoice? = voices.first{
			$0.identifier == "com.apple.ttsbundle.Otoya-compact"
		}
		if let voice = voice {
			utterance.voice = voice
		} else {
			utterance.voice = AVSpeechSynthesisVoice(language: "ja-JP")
		}
		synthesizer.speak(utterance)
	}
	
}
