//
//  View+Extension.swift
//  Rebound Journal
//
//  Created by hyunho lee on 4/18/24.
//

import SwiftUI

/// Hide keyboard from any view
extension View {
    func hideKeyboard() {
        DispatchQueue.main.async {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
    }

    /// Apply dynamic font with increased size
    func dynamicFont(_ style: Font.TextStyle, weight: Font.Weight = .regular) -> some View {
        self.font(.system(style, design: .default, weight: weight))
    }
}
