//
//  SwiftUIView.swift
//  Rebound Journal
//
//  Created by 황석현 on 3/19/25.
//

import SwiftUI

struct ShootCreationHeader: View {
    // Content
    let title: String?
    var description: String? = nil
    var image: ImageResource? = nil
    
    var body: some View {
        HStack {
            if let image = image {
                Image(image)
                    .padding(.trailing, 30)
            }
            VStack(alignment: .leading) {
                Text(title ?? "")
                    .font(.system(size: 25))
                    .fontWeight(.semibold)
                    .padding(.bottom, 3)
                    .foregroundStyle(Color("Default"))
                
                if let description = description {
                    Text(description)
                        .font(.system(size: 18))
                        .foregroundStyle(Color("Description"))
                }
            }
        }
    }
}

#Preview("SelectShootType") {
    ShootCreationHeader(title: "어떤 슛을 남겨볼까요?", description: "슛의 종류를 선택해 보세요.")
}
#Preview("EmotionInput-GoalIn") {
    ShootCreationHeader(title: Constants.ContentText().EmotionInPutGoalIn,
                        image: .goalIn)
}
#Preview("EmotionInput-Rebound") {
    ShootCreationHeader(title: Constants.ContentText().EmotionInPutRebound,
                        image: .rebound)
}
