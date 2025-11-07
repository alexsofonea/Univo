//
//  Clicker.swift
//  Controller
//
//  Created by Alex on 01.04.2025.
//

import Foundation
import CoreGraphics
import AppKit

class ClickerService {
    static let shared = ClickerService()
    
    func moveMouseAndClick(x: CGFloat, y: CGFloat) {
        let targetPoint = CGPoint(x: x, y: y)
        
        let eventSource = CGEventSource(stateID: .hidSystemState)

        // Move the mouse to the specified coordinates
        let moveEvent = CGEvent(mouseEventSource: eventSource,
                                mouseType: .mouseMoved,
                                mouseCursorPosition: targetPoint,
                                mouseButton: .left)
        moveEvent?.post(tap: .cghidEventTap)

        // Create mouse down and mouse up events
        let mouseDown = CGEvent(mouseEventSource: eventSource,
                                mouseType: .leftMouseDown,
                                mouseCursorPosition: targetPoint,
                                mouseButton: .left)
        
        let mouseUp = CGEvent(mouseEventSource: eventSource,
                              mouseType: .leftMouseUp,
                              mouseCursorPosition: targetPoint,
                              mouseButton: .left)

        // Post the mouse click events
        mouseDown?.post(tap: .cghidEventTap)
        mouseUp?.post(tap: .cghidEventTap)
    }
    
    func doubleClick(x: CGFloat, y: CGFloat) {
        let targetPoint = CGPoint(x: x, y: y)
        
        let eventSource = CGEventSource(stateID: .hidSystemState)
        
        // Move the mouse to the specified coordinates
        let moveEvent = CGEvent(mouseEventSource: eventSource,
                                mouseType: .mouseMoved,
                                mouseCursorPosition: targetPoint,
                                mouseButton: .left)
        moveEvent?.post(tap: .cghidEventTap)
        
        // Create double click events
        let mouseDown = CGEvent(mouseEventSource: eventSource,
                                mouseType: .leftMouseDown,
                                mouseCursorPosition: targetPoint,
                                mouseButton: .left)
        mouseDown?.setIntegerValueField(.mouseEventClickState, value: 2)
        
        let mouseUp = CGEvent(mouseEventSource: eventSource,
                              mouseType: .leftMouseUp,
                              mouseCursorPosition: targetPoint,
                              mouseButton: .left)
        mouseUp?.setIntegerValueField(.mouseEventClickState, value: 2)
        
        // Post the double click events
        mouseDown?.post(tap: .cghidEventTap)
        mouseUp?.post(tap: .cghidEventTap)
    }
    
    func rightClick(x: CGFloat, y: CGFloat) {
        let targetPoint = CGPoint(x: x, y: y)
        
        let eventSource = CGEventSource(stateID: .hidSystemState)
        
        // Move the mouse to the specified coordinates
        let moveEvent = CGEvent(mouseEventSource: eventSource,
                                mouseType: .mouseMoved,
                                mouseCursorPosition: targetPoint,
                                mouseButton: .right)
        moveEvent?.post(tap: .cghidEventTap)
        
        // Create right mouse down and up events
        let mouseDown = CGEvent(mouseEventSource: eventSource,
                                mouseType: .rightMouseDown,
                                mouseCursorPosition: targetPoint,
                                mouseButton: .right)
        
        let mouseUp = CGEvent(mouseEventSource: eventSource,
                              mouseType: .rightMouseUp,
                              mouseCursorPosition: targetPoint,
                              mouseButton: .right)
        
        // Post the right click events
        mouseDown?.post(tap: .cghidEventTap)
        mouseUp?.post(tap: .cghidEventTap)
    }
    
    func scroll(x: CGFloat, y: CGFloat, deltaX: CGFloat, deltaY: CGFloat) {
        let loc = CGPoint(x: x, y: y)
        if let event = CGEvent(scrollWheelEvent2Source: nil,
                               units: .pixel,
                               wheelCount: 2,
                               wheel1: Int32(-deltaY),
                               wheel2: Int32(-deltaX),
                               wheel3: 0) {
            event.location = loc
            event.post(tap: .cghidEventTap)
        }
    }
}
