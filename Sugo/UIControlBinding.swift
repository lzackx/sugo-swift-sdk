//
//  UIControlBinding.swift
//  Sugo
//
//  Created by Yarden Eitan on 8/24/16.
//  Copyright © 2016 Sugo. All rights reserved.
//

import Foundation
import UIKit

class UIControlBinding: CodelessBinding {

    let controlEvent: UIControlEvents
    let verifyEvent: UIControlEvents
    var verified: NSHashTable<UIControl>
    var appliedTo: NSHashTable<UIControl>

    init(eventID: String, eventName: String, path: String, controlEvent: UIControlEvents, verifyEvent: UIControlEvents, attributes: Attributes? = nil) {
        self.controlEvent = controlEvent
        self.verifyEvent = verifyEvent
        self.verified = NSHashTable(options: [NSHashTableWeakMemory, NSHashTableObjectPointerPersonality])
        self.appliedTo = NSHashTable(options: [NSHashTableWeakMemory, NSHashTableObjectPointerPersonality])
        super.init(eventID: eventID, eventName: eventName, path: path, attributes: attributes)
        self.swizzleClass = UIControl.self
    }

    convenience init?(object: [String: Any]) {
        guard let path = object["path"] as? String, path.characters.count >= 1 else {
            Logger.warn(message: "must supply a view path to bind by")
            return nil
        }
        
        guard let eventID = object["event_id"] as? String, eventID.characters.count >= 1 else {
            Logger.warn(message: "binding requires an event id")
            return nil
        }
        
        guard let eventName = object["event_name"] as? String, eventName.characters.count >= 1 else {
            Logger.warn(message: "binding requires an event name")
            return nil
        }

        guard let controlEvent = object["control_event"] as? UInt, controlEvent & UIControlEvents.allEvents.rawValue != 0 else {
            Logger.warn(message: "must supply a valid UIControlEvents value for control_event")
            return nil
        }

        var finalVerifyEvent: UIControlEvents
        if let verifyEvent = object["verify_event"] as? UInt, verifyEvent & UIControlEvents.allEvents.rawValue != 0 {
            finalVerifyEvent = UIControlEvents(rawValue: verifyEvent)
        } else if controlEvent & UIControlEvents.allTouchEvents.rawValue != 0 {
            finalVerifyEvent = UIControlEvents.touchDown
        } else if controlEvent & UIControlEvents.allEditingEvents.rawValue != 0 {
            finalVerifyEvent = UIControlEvents.editingDidBegin
        } else {
            Logger.warn(message: "wasn't able to fetch a valid verify event")
            return nil
        }
        
        if let attributes = object["attributes"] as? InternalProperties {
            let attr = Attributes(attributes: attributes)
            self.init(eventID: eventID,
                      eventName: eventName,
                      path: path,
                      controlEvent: UIControlEvents(rawValue: controlEvent),
                      verifyEvent: finalVerifyEvent,
                      attributes: attr)
        } else {
            self.init(eventID: eventID,
                      eventName: eventName,
                      path: path,
                      controlEvent: UIControlEvents(rawValue: controlEvent),
                      verifyEvent: finalVerifyEvent)
        }
    }

    required init?(coder aDecoder: NSCoder) {
        controlEvent = UIControlEvents(rawValue: aDecoder.decodeObject(forKey: "controlEvent") as! UInt)
        verifyEvent = UIControlEvents(rawValue: aDecoder.decodeObject(forKey: "verifyEvent") as! UInt)
        verified = NSHashTable(options: [NSHashTableWeakMemory, NSHashTableObjectPointerPersonality])
        appliedTo = NSHashTable(options: [NSHashTableWeakMemory, NSHashTableObjectPointerPersonality])
        super.init(coder: aDecoder)
    }

    override func encode(with aCoder: NSCoder) {
        aCoder.encode(controlEvent.rawValue, forKey: "controlEvent")
        aCoder.encode(verifyEvent.rawValue, forKey: "verifyEvent")
        super.encode(with: aCoder)
    }


    override func isEqual(_ object: Any?) -> Bool {
        guard let object = object as? UIControlBinding else {
            return false
        }

        if object === self {
            return true
        } else {
            return super.isEqual(object) && self.controlEvent == object.controlEvent && self.verifyEvent == object.verifyEvent
        }
    }

    override var hash: Int {
        return super.hash ^ Int(self.controlEvent.rawValue) ^ Int(self.verifyEvent.rawValue)
    }

    override var description: String {
        return "UIControl Codeless Binding: \(eventName) for \(path)"
    }

    func resetUIControlStore() {
        verified = NSHashTable(options: [NSHashTableWeakMemory, NSHashTableObjectPointerPersonality])
        appliedTo = NSHashTable(options: [NSHashTableWeakMemory, NSHashTableObjectPointerPersonality])
    }

    override func execute() {

        if !self.running {
            let executeBlock = {
                (view: AnyObject?, command: Selector, param1: AnyObject?, param2: AnyObject?) in
                if let root = UIApplication.shared.keyWindow {
                    if let view = view as? UIControl, self.appliedTo.contains(view) {
                        if !self.path.isSelected(leaf: view, from: root, isFuzzy: true) {
                            if Sugo.mainInstance().heatMap.mode {
                                Sugo.mainInstance().heatMap.wipeObjectOfPath(path: self.path.string)
                            }
                            self.stopOn(view: view)
                            self.appliedTo.remove(view)
                        }
                    } else {
                        var objects: [UIControl]
                        // select targets based off path
                        if let view = view as? UIControl {
                            if self.path.isSelected(leaf: view, from: root, isFuzzy: true) {
                                objects = [view]
                            } else {
                                objects = []
                            }
                        } else {
                            objects = self.path.selectFrom(root: root) as! [UIControl]
                        }

                        for control in objects {
                            if self.verifyEvent != UIControlEvents(rawValue:0) && self.verifyEvent != self.controlEvent {
                                control.addTarget(self, action: #selector(self.preVerify(sender:event:)), for: self.verifyEvent)
                            }
                            control.addTarget(self, action: #selector(self.execute(sender:event:)), for: self.controlEvent)
                            self.appliedTo.add(control)
                        }
                        if Sugo.mainInstance().heatMap.mode {
                            Sugo.mainInstance().heatMap.renderObjectOfPath(path: self.path.string, root: root)
                        }
                    }
                }
            }

            // Execute once in case the view to be tracked is already on the screen
            executeBlock(nil, #function, nil, nil)

            Swizzler.swizzleSelector(NSSelectorFromString("didMoveToWindow"),
                                     withSelector: #selector(UIView.sugoViewDidMoveToWindow),
                                     for: swizzleClass,
                                     name: name,
                                     block: executeBlock)
            Swizzler.swizzleSelector(NSSelectorFromString("didMoveToSuperview"),
                                     withSelector: #selector(UIView.sugoViewDidMoveToSuperview),
                                     for: swizzleClass,
                                     name: name,
                                     block: executeBlock)
            running = true
        }
    }

    override func stop() {
        if running {
            // remove what has been swizzled
            Swizzler.unswizzleSelector(NSSelectorFromString("didMoveToWindow"),
                                       aClass: swizzleClass,
                                       name: name)
            Swizzler.unswizzleSelector(NSSelectorFromString("didMoveToSuperview"),
                                       aClass: swizzleClass,
                                       name: name)

            // remove target-action pairs
            for control in appliedTo.allObjects {
                stopOn(view: control)
            }
            resetUIControlStore()
            running = false
        }
    }

    func stopOn(view: UIControl) {
        if verifyEvent != UIControlEvents(rawValue: 0) && verifyEvent != controlEvent {
            view.removeTarget(self, action: #selector(self.preVerify(sender:event:)), for: verifyEvent)
        }
        view.removeTarget(self, action: #selector(self.execute(sender:event:)), for: controlEvent)
    }

    func verifyControlMatchesPath(_ control: AnyObject) -> Bool {
        if let root = UIApplication.shared.keyWindow {
            return path.isSelected(leaf: control, from: root)
        }
        return false
    }

    @objc func preVerify(sender: UIControl, event: UIEvent) {
        if verifyControlMatchesPath(sender) {
            verified.add(sender)
        } else {
            verified.remove(sender)
        }
    }

    @objc func execute(sender: UIControl, event: UIEvent) {
        var shouldTrack = false
        if verifyEvent != UIControlEvents(rawValue: 0) && verifyEvent != controlEvent {
            shouldTrack = verified.contains(sender)
        } else {
            shouldTrack = verifyControlMatchesPath(sender)
        }
        if shouldTrack {
            var p = Properties()
            if let a = self.attributes {
                p += a.parse()
            }
            let keys = SugoDimensions.keys
            let values = SugoDimensions.values
            if let vc = UIViewController.sugoCurrentUIViewController() {
                p[keys["PagePath"]!] = NSStringFromClass(vc.classForCoder)
                for info in SugoPageInfos.global.infos {
                    if let infoPage = info["page"] as? String,
                        infoPage == NSStringFromClass(vc.classForCoder) {
                        p[keys["PageName"]!] = infoPage
                        if let infoPageCategory = info["page_category"] as? String {
                            p[keys["PageCategory"]!] = infoPageCategory;
                        }
                        break
                    }
                }
            }
            if controlEvent == UIControlEvents.editingDidBegin {
                p[keys["EventType"]!] = values["focus"]!
            } else {
                p[keys["EventType"]!] = values["click"]!
            }
            self.track(eventID: self.eventID,
                       eventName: self.eventName,
                       properties: p)
        }
    }

}

extension UIView {
    
    @objc func viewCallOriginalMethodWithSwizzledBlocks(originalSelector: Selector) {
        if let originalMethod = class_getInstanceMethod(type(of: self), originalSelector),
            let swizzle = Swizzler.swizzles[originalMethod] {
            typealias SUGOCFunction = @convention(c) (AnyObject, Selector) -> Void
            let curriedImplementation = unsafeBitCast(swizzle.originalMethod, to: SUGOCFunction.self)
            curriedImplementation(self, originalSelector)

            for (_, block) in swizzle.blocks {
                block(self, swizzle.selector, nil, nil)
            }
        }
    }
    
    @objc func sugoViewDidMoveToWindow() {
        let originalSelector = NSSelectorFromString("didMoveToWindow")
        viewCallOriginalMethodWithSwizzledBlocks(originalSelector: originalSelector)
    }

    @objc func sugoViewDidMoveToSuperview() {
        let originalSelector = NSSelectorFromString("didMoveToSuperview")
        viewCallOriginalMethodWithSwizzledBlocks(originalSelector: originalSelector)
    }

    @objc func sugoViewLayoutSubviews() {
        let originalSelector = NSSelectorFromString("layoutSubviews")
        viewCallOriginalMethodWithSwizzledBlocks(originalSelector: originalSelector)
    }
    

}
