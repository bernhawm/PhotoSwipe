//
//  Theme.swift
//  PhotoSwipe2
//
//  Created by Wade Bernhardt on 9/30/25.
//
import SwiftUI

enum AppTheme: String, CaseIterable {
    case system, light, dark
}

class ThemeManager: ObservableObject {
    @Published var selectedTheme: AppTheme {
        didSet {
            UserDefaults.standard.set(selectedTheme.rawValue, forKey: "appTheme")
        }
    }

    init() {
        if let stored = UserDefaults.standard.string(forKey: "appTheme"),
           let theme = AppTheme(rawValue: stored) {
            self.selectedTheme = theme
        } else {
            self.selectedTheme = .system
        }
    }

    var colorScheme: ColorScheme? {
        switch selectedTheme {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}
