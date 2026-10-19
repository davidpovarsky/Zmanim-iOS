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
    func clearGlassEffectIfAvailable(in shape: some Shape = Capsule()) -> some View {
        self.background(Color(uiColor: .secondarySystemBackground), in: shape)
    }

    @ViewBuilder
    func regularGlassEffectIfAvailable(in shape: some Shape = Capsule()) -> some View {
        self.background(.regularMaterial, in: shape)
    }
}
