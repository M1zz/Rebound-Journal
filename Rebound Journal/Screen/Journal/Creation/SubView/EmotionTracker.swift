//
//  FeelingShape.swift
//  Rebound Journal
//
//  Created by 황석현 on 3/23/25.
//

import SwiftUI

struct EmotionTracker: View {
    // Shared Dependencies
    @ObservedObject var viewModel: JournalCreatorViewModel
    
    // UI State
    @State var emotionShape: ImageResource = .positiveCircle
    @State var emotionValue: Double = 0.0
    @State var emotionText: [String] = []
    @State var selectedEmotionTags: [String] = []
    
    var currentEmotionLevel: EmotionLevel {
        switch emotionValue {
        case 0..<0.5: return .level0
        case 0.5..<1.5: return .level1
        case 1.5..<2.5: return .level2
        default: return .level3
        }
    }
    
    // 기타 상태
    var isFirstEnter: Bool {
        !viewModel.isSliderEditing && viewModel.emotionValue == nil
    }
    var isSliderEditing: Bool {
        viewModel.isSliderEditing
    }
    
    var text = Constants.SystemText()
    
    var body: some View {
        ZStack {
            VStack {
                HStack(spacing: 5) {
                    if isFirstEnter {
                        Text(text.sliderGuide)
                            .frame(maxWidth: .infinity)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(Color("Description"))
                            .bold()
                            .padding()
                    } else if !isSliderEditing {
                        EmotionText(emotions: $emotionText, selectedTags: $selectedEmotionTags)
                            .onChange(of: selectedEmotionTags) { _, newValue in
                                viewModel.emotionText = newValue
                            }
                    } else {
                        FeelingShape(value: $emotionValue,
                                     currentFeelingShape: $emotionShape)
                    }
                    
                    Spacer()
                    
                    VerticalSlider(sliderValue: $emotionValue, isEdited: $viewModel.isSliderEditing)
                        .onChange(of: emotionValue) { _, newValue in
                            debugPrint("Slider: \(newValue)")

                            // 감정 모양 업데이트
                            switch newValue {
                            case 0..<0.5:
                                emotionShape = .positiveCircle
                            case 0.5..<1.5:
                                emotionShape = .softSpikes
                            case 1.5..<2.5:
                                emotionShape = .sharpSpike
                            case 2.5...:
                                emotionShape = .thornball
                            default:
                                emotionShape = .positiveCircle
                            }
                            
                            // 감정 텍스트 업데이트
                            switch currentEmotionLevel {
                            case .level0:
                                emotionText = Constants.ContentText().emotionTextsLevel0
                            case .level1:
                                emotionText = Constants.ContentText().emotionTextsLevel1
                            case .level2:
                                emotionText = Constants.ContentText().emotionTextsLevel2
                            case .level3:
                                emotionText = Constants.ContentText().emotionTextsLevel3
                            }
                        }
                        .onChange(of: viewModel.isSliderEditing) { _, _ in
                            viewModel.emotionValue = emotionValue
                        }
                        .frame(width: 60)
                }
            }
        }
    }
}


struct FeelingShape: View {
    @Binding var value: Double
    @State var scale = false
    @Binding var currentFeelingShape: ImageResource
    @State var shapeScale: CGFloat = 1
    
    var body: some View {
        Image(currentFeelingShape)
            .resizable().scaledToFit()
            .frame(maxWidth: .infinity)
            .scaleEffect(shapeScale)
            .onChange(of: currentFeelingShape) { _, _ in
                withAnimation {
                    shapeScale = 0
                }
                DispatchQueue.main.asyncAfter(deadline: .now()) {
                    withAnimation(.easeInOut(duration: 0.8)) {
                        shapeScale = 1
                    }
                }
            }
        
            .onAppear() {
                withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
                    scale.toggle()
                }
            }
    }
}

#Preview {
		EmotionTracker(viewModel: JournalCreatorViewModel());
}
