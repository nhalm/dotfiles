import AppKit
import SwiftUI

extension Image {
	// Also finds the symbols macOS ships outside the public set, such as
	// "bluetooth".
	init(symbol: String, variableValue: Double? = nil) {
		if NSImage(systemSymbolName: symbol, accessibilityDescription: nil) != nil {
			self.init(systemName: symbol, variableValue: variableValue)
		} else {
			self.init(_internalSystemName: symbol)
		}
	}
}
