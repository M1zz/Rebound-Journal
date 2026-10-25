//
//  Binding+Extension.swift
//  ZinggumDol
//
//  Created by hyunho lee on 4/18/24.
//

import SwiftUI

/// Helps us monitor changes on a binding object. For example when user selected a certain segment from segmented control or picker
extension Binding {
    func onChange(_ handler: @escaping (Value) -> Void) -> Binding<Value> {
        return Binding(
            get: { self.wrappedValue },
            set: { selection in
                self.wrappedValue = selection
                handler(selection)
        })
    }
}
