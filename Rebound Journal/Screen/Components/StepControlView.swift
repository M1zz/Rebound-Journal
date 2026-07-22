//
//  StepControlView.swift
//  Rebound Journal
//
//  Created by 황석현 on 3/25/25.
//

import SwiftUI

// MARK: 하단의 <이전><다음으로> 버튼을 만드는 뷰

/// 화면 하단에 표시되는 이전/다음 버튼 컴포넌트
/// - hasBackButton: 이전 버튼을 표시할지 여부 (기본값: false)
/// - canGoNext: 다음 버튼 활성화 상태 (기본값: true)
/// - onPrevious: 이전 버튼을 눌렀을 때 실행할 코드 (옵셔널)
/// - onNext: 다음 버튼을 눌렀을 때 실행할 코드 (필수)
/// - nextButtonText: 다음 버튼 텍스트 (기본값: "다음으로")
/// - previousButtonText: 이전 버튼 텍스트 (기본값: "이전")
struct StepControlView: View {
    // MARK: - Properties
    let hasBackButton: Bool
    let canGoNext: Bool
    let onPrevious: (() -> Void)?
    let onNext: () -> Void
    let nextButtonText: String
    let previousButtonText: String
    
    private let constants = Constants.SystemText()
    
    // MARK: - Initializer
    init(
        hasBackButton: Bool = false,
        canGoNext: Bool = true,
        onPrevious: (() -> Void)? = nil,
        onNext: @escaping () -> Void,
        nextButtonText: String? = nil,
        previousButtonText: String? = nil
    ) {
        self.hasBackButton = hasBackButton
        self.canGoNext = canGoNext
        self.onPrevious = onPrevious
        self.onNext = onNext
        self.nextButtonText = nextButtonText ?? constants.nextButton
        self.previousButtonText = previousButtonText ?? constants.previousButton
    }
    
    // MARK: - Body
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 16) {
                if hasBackButton {
                    previousButton
                        .frame(width: (geometry.size.width - 16) / 3)
                }
                
                nextButton
                    .frame(width: hasBackButton ? (geometry.size.width - 16) * 2 / 3 : geometry.size.width)
            }
        }
        .frame(height: 50) // 버튼 높이 고정
    }
    
    var previousButton: some View {
        Button {
            onPrevious?()
        } label: {
            Text(previousButtonText)
                .font(.system(size: 22, weight: .bold))
                .padding()
                .frame(maxWidth: .infinity)
                .foregroundColor(.backButtonText)
                .background(Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 90)
                        .stroke(.backButtonBorder, lineWidth: 2)
                )
        }
    }
    
    var nextButton: some View {
        Button {
            if canGoNext {
                onNext()
            }
        } label: {
            Text(nextButtonText)
                .font(.system(size: 22, weight: .bold))
                .frame(maxWidth: .infinity)
                .padding()
                .background(canGoNext ? Color.accentColor : .disabledButtonBackground)
                .foregroundColor(canGoNext ? .text : .disabledButtonText)
                .cornerRadius(90)
        }
        .disabled(!canGoNext)
        .animation(.easeInOut, value: canGoNext)
    }
}

// MARK: - Preview
#Preview("Both Buttons - Enabled") {
    VStack(spacing: 20) {
        StepControlView(
            hasBackButton: true,
            canGoNext: true,
            onPrevious: { print("Previous tapped") },
            onNext: { print("Next tapped") }
        )
        .padding()
    }
}

#Preview("Both Buttons - Disabled Next") {
    VStack(spacing: 20) {
        StepControlView(
            hasBackButton: true,
            canGoNext: false,
            onPrevious: { print("Previous tapped") },
            onNext: { print("Next tapped") }
        )
        .padding()
    }
}

#Preview("Next Button Only - Enabled") {
    VStack(spacing: 20) {
        StepControlView(
            hasBackButton: false,
            canGoNext: true,
            onNext: { print("Next tapped") }
        )
        .padding()
    }
}

#Preview("Next Button Only - Disabled") {
    VStack(spacing: 20) {
        StepControlView(
            hasBackButton: false,
            canGoNext: false,
            onNext: { print("Next tapped") }
        )
        .padding()
    }
}

#Preview("저장하기") {
    VStack(spacing: 20) {
        StepControlView(
            hasBackButton: true,
            canGoNext: true,
            onPrevious: { print("Previous tapped") },
            onNext: { print("Next tapped") },
            nextButtonText: "저장하기"
        )
        .padding()
    }
}
