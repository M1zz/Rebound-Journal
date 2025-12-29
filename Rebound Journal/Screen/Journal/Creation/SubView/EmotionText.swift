//
//  FeelingText.swift
//  Rebound Journal
//
//  Created by 황석현 on 3/26/25.
//

import SwiftUI

struct EmotionText: View {

    // UI State
    @Binding var emotions: [String]
    @Binding var selectedTags: [String]
    @State private var showSheet = false
    @State private var inputText = ""
    @State private var showToast = false

    // etc
    @Namespace private var animation

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(.vertical) {
                VStack {
                    // MARK: alignment를 수정하면 태그 정렬 위치가 바뀜
                    EmotionTagLayout(alignment: .leading , spacing: 10) {
                        ForEach(emotions.filter{ selectedTags.contains($0) }, id: \.self) { tag in
                            EmotionTagView(tag, .selectedTagBackground)
                            // MARK: 애니메이션이 좀 더 이뻐짐
                                .matchedGeometryEffect(id: tag, in: animation)
                                .onTapGesture {
                                    // Removing to Selected Tag List
                                    withAnimation(.snappy) {
                                        selectedTags.removeAll(where: { $0 == tag })
                                    }
                                }
                        }
                        // MARK: 선택한 태그는 보이지 않게 필터링
                        ForEach(emotions.filter{ !selectedTags.contains($0) }, id: \.self) { tag in
                            EmotionTagView(tag, .unselectedTagBackground)
                            // MARK: 애니메이션이 좀 더 이뻐짐
                                .matchedGeometryEffect(id: tag, in: animation)
                                .onTapGesture {
                                    withAnimation(.snappy) {
                                        if !selectedTags.isEmpty {
                                            // 이미 선택된 감정이 있으면 토스트 표시하고 교체
                                            showToast = true
                                            selectedTags.removeAll()
                                        }
                                        // 마지막에 누른 감정만 선택
                                        selectedTags.insert(tag, at: 0)
                                    }
                                }
                        }
                    }
                    Text("직접 쓰기")
                        .frame(maxWidth: .infinity)
                        .frame(height: 35)
                        .overlay(
                            RoundedRectangle(cornerRadius: 17)
                                .stroke(Color.gray.opacity(0.5), lineWidth: 2)
                        )
                        .onTapGesture {
                            showSheet = true
                        }
                        .sheet(isPresented: $showSheet, content: {
                            CreateEmotionView(isPresented: $showSheet, onConfirm: { input in
                                withAnimation(.snappy) {
                                    if !selectedTags.isEmpty {
                                        // 이미 선택된 감정이 있으면 토스트 표시하고 교체
                                        showToast = true
                                        selectedTags.removeAll()
                                    }
                                    emotions.append(input)
                                    selectedTags.append(input)
                                }
                            })
                            .presentationDetents([.fraction(0.3)])
                        })
                        .padding(10)
                }
            }
            .scrollIndicators(.hidden)
            .zIndex(0)
        }
        .overlay(alignment: .top) {
            if showToast {
                ToastView(message: "감정은 하나만 선택됩니다")
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(1)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            withAnimation {
                                showToast = false
                            }
                        }
                    }
            }
        }
    }
    
    @ViewBuilder
    func EmotionTagView(_ tag: String, _ color: Color) -> some View {
        let isSelected = color == Color.selectedTagBackground ? true : false
        HStack(spacing: 8) {
            Text(tag)
                .font(.system(size: 16, weight: .light))
        }
				.foregroundStyle(isSelected ? .accent : .black)
        .padding(.horizontal, 10)
				.padding(.vertical, 12)
        .background {
            Capsule()
                .fill(color)
        }
    }
}

// MARK: - Layout
struct EmotionTagLayout: Layout {
    /// Layout Properties
    var alignment: Alignment = .center
    /// Both Horizontal & Vertical
    var spacing: CGFloat = 10
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? 0
        var height: CGFloat = 0
        let rows = generateRows(maxWidth, proposal, subviews)
        
        for (index, row) in rows.enumerated() {
            // Finding max Height in each row and adding it to the View's Total Height
            if index == (rows.count - 1) {
                // Since there is no spacing needed for the last item
                height += row.maxHeight(proposal)
            }  else {
                height += row.maxHeight(proposal) + spacing
            }
        }
        
        return .init(width: maxWidth, height: height)
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        // Placing Views
        var origin = bounds.origin
        let maxWidth = bounds.width
        debugPrint(maxWidth, bounds.maxX)
        let rows = generateRows(maxWidth, proposal, subviews)
        
        for row in rows {
            // Chaning Origin X based on Alignments
            let leading: CGFloat = bounds.maxX - maxWidth
            let trailing = bounds.maxX - (row.reduce(CGFloat.zero) { partialResult, view in
                let width = view.sizeThatFits(proposal).width
                if view == row.last {
                    // No Spacing
                    return partialResult + width
                }
                // With Spacing
                return partialResult + width + spacing
            })
            let center = (trailing + leading) / 2
            
            // Resetting Origin X to Zero for Each Row
            origin.x = (alignment == .leading ? leading : alignment == .trailing ? trailing : center)
            
            for view in row {
                let viewSize = view.sizeThatFits(proposal)
                view.place(at: origin, proposal: proposal)
                // Updating Origin X
                origin.x += (viewSize.width + spacing)
            }
            
            // Updating Origin Y
            origin.y += (row.maxHeight(proposal) + spacing)
        }
    }
    
    /// Generating Rows based on Available Size
    func generateRows(_ maxWidth: CGFloat, _ proposal: ProposedViewSize, _ subviews: Subviews) -> [[LayoutSubviews.Element]] {
        var row: [LayoutSubviews.Element] = []
        var rows: [[LayoutSubviews.Element]] = []
        
        /// Origin
        var origin = CGRect.zero.origin
        
        for view in subviews {
            let viewSize = view.sizeThatFits(proposal)
            
            // Pushing to New Row
            if (origin.x + viewSize.width + spacing) > maxWidth {
                rows.append(row)
                row.removeAll()
                // Resetting X Origin since it needs to start from left to right
                origin.x = 0
                row.append(view)
                // Updating Origin X
                origin.x += (viewSize.width + spacing)
            } else {
                // Adding item to Same Row
                row.append(view)
                // Updating Origin X
                origin.x += (viewSize.width + spacing)
            }
        }
        if !row.isEmpty {
            rows.append(row)
            row.removeAll()
        }
        return rows
    }
}

extension [LayoutSubviews.Element] {
    func maxHeight(_ proposal: ProposedViewSize) -> CGFloat {
        return self.compactMap { view in
            return view.sizeThatFits(proposal).height
        }.max() ?? 0
    }
}

struct CreateEmotionView: View {
    @Binding var isPresented: Bool
    @State private var tempText = ""
    @FocusState private var isTextFieldFocused: Bool
    var onConfirm: (String) -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Text("지금 감정을 입력해봐요")
                .font(.headline)
                .padding(.top, 30)
            
            TextField("여기에 입력", text: $tempText)
                .focused($isTextFieldFocused)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        isTextFieldFocused = true
                    }
                }
            StepControlView(
                hasBackButton: true,
                canGoNext: !tempText.isEmpty,
                onPrevious: {
                    isPresented = false
                },
                onNext: {
                    onConfirm(tempText)
                    isPresented = false
                },
                nextButtonText: "확인",
                previousButtonText: "취소"
            )
        }
        .padding()
    }
}

// MARK: - Toast View
struct ToastView: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                Capsule()
                    .fill(Color.black.opacity(0.8))
                    .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
            )
            .padding(.top, 16)
    }
}

#Preview {
    EmotionText(emotions: .constant(["감정태그", "기분이 좋은"]),selectedTags: .constant(["감정태그"]))
				.preferredColorScheme(.dark)
}
