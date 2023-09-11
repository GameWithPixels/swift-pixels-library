//
//  ButtonWithBorder.swift
//  PixelsExampleApp
//
//  Created by Olivier on 11.09.23.
//

import Foundation
import SwiftUI

struct ButtonWithBorder: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding()
            .border(Color.gray, width: 2)
    }
}
