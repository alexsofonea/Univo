//
//  Typer.swift
//  Controller
//
//  Created by Alex on 01.04.2025.
//

import Foundation
import CoreGraphics

class TyperService {
    
    static let shared = TyperService()

    func typeText(_ text: String) {
        let eventSource = CGEventSource(stateID: .hidSystemState)

        for char in text {
            if let (keyCode, flags) = keyCodeForCharacter(char) {
                let keyDown = CGEvent(keyboardEventSource: eventSource, virtualKey: keyCode, keyDown: true)
                let keyUp = CGEvent(keyboardEventSource: eventSource, virtualKey: keyCode, keyDown: false)

                if let flags = flags {
                    keyDown?.flags = flags
                    keyUp?.flags = flags
                }

                keyDown?.post(tap: .cghidEventTap)
                keyUp?.post(tap: .cghidEventTap)
            }
        }
    }

    // Helper function to map characters to key codes and optional flags
    func keyCodeForCharacter(_ char: Character) -> (CGKeyCode, CGEventFlags?)? {
        let keyMap: [Character: (CGKeyCode, CGEventFlags?)] = [
            // Lowercase letters
            "a": (0, nil), "b": (11, nil), "c": (8, nil), "d": (2, nil), "e": (14, nil),
            "f": (3, nil), "g": (5, nil), "h": (4, nil), "i": (34, nil), "j": (38, nil),
            "k": (40, nil), "l": (37, nil), "m": (46, nil), "n": (45, nil), "o": (31, nil),
            "p": (35, nil), "q": (12, nil), "r": (15, nil), "s": (1, nil), "t": (17, nil),
            "u": (32, nil), "v": (9, nil), "w": (13, nil), "x": (7, nil), "y": (16, nil),
            "z": (6, nil),

            // Uppercase letters (shift flag)
            "A": (0, .maskShift), "B": (11, .maskShift), "C": (8, .maskShift), "D": (2, .maskShift), "E": (14, .maskShift),
            "F": (3, .maskShift), "G": (5, .maskShift), "H": (4, .maskShift), "I": (34, .maskShift), "J": (38, .maskShift),
            "K": (40, .maskShift), "L": (37, .maskShift), "M": (46, .maskShift), "N": (45, .maskShift), "O": (31, .maskShift),
            "P": (35, .maskShift), "Q": (12, .maskShift), "R": (15, .maskShift), "S": (1, .maskShift), "T": (17, .maskShift),
            "U": (32, .maskShift), "V": (9, .maskShift), "W": (13, .maskShift), "X": (7, .maskShift), "Y": (16, .maskShift),
            "Z": (6, .maskShift),

            // Numbers
            "0": (29, nil), "1": (18, nil), "2": (19, nil), "3": (20, nil), "4": (21, nil),
            "5": (23, nil), "6": (22, nil), "7": (26, nil), "8": (28, nil), "9": (25, nil),

            // Shifted numbers (symbols)
            "!": (18, .maskShift), "@": (19, .maskShift), "#": (20, .maskShift), "$": (21, .maskShift),
            "%": (23, .maskShift), "^": (22, .maskShift), "&": (26, .maskShift), "*": (28, .maskShift),
            "(": (25, .maskShift), ")": (29, .maskShift),

            // Punctuation and other common characters
            " ": (49, nil), // Spacebar
            "-": (27, nil), "_": (27, .maskShift),
            "=": (24, nil), "+": (24, .maskShift),
            "[": (33, nil), "{": (33, .maskShift),
            "]": (30, nil), "}": (30, .maskShift),
            "\\": (42, nil), "|": (42, .maskShift),
            ";": (41, nil), ":": (41, .maskShift),
            "'": (39, nil), "\"": (39, .maskShift),
            ",": (43, nil), "<": (43, .maskShift),
            ".": (47, nil), ">": (47, .maskShift),
            "/": (44, nil), "?": (44, .maskShift),

            // Return and tab
            "\n": (36, nil),
            "\t": (48, nil)
        ]

        return keyMap[char]
    }
}
