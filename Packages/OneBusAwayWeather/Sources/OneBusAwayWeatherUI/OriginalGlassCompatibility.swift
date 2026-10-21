//
//  OriginalGlassCompatibility.swift
//  OBAKit
//
//  Copyright © Open Transit Software Foundation
//  This source code is licensed under the Apache 2.0 license found in the
//  LICENSE file in the root directory of this source tree.
//

import SwiftUI

extension View {
    @ViewBuilder
    public func clearGlassEffectIfAvailable(in shape: some Shape = Capsule()) -> some View {
        #if canImport(SwiftUI)
        if #available(iOS 26.0, *) {
            self.glassEffect(.clear, in: shape)
        } else {
            self.background(.ultraThinMaterial, in: shape)
        }
        #else
        self.background(.ultraThinMaterial, in: shape)
        #endif
    }

    @ViewBuilder
    public func regularGlassEffectIfAvailable(in shape: some Shape = Capsule()) -> some View {
        #if canImport(SwiftUI)
        if #available(iOS 26.0, *) {
            self.glassEffect(.regular, in: shape)
        } else {
            self.background(.regularMaterial, in: shape)
        }
        #else
        self.background(.regularMaterial, in: shape)
        #endif
    }
}
