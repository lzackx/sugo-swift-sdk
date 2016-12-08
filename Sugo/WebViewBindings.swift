//
//  WebViewBindings.swift
//  Sugo
//
//  Created by Zack on 28/11/16.
//  Copyright © 2016年 Sugo. All rights reserved.
//

import UIKit
import WebKit
import JavaScriptCore

enum WebViewBindingsMode: String {
    case decide     = "decide"
    case codeless   = "codeless"
}

class WebViewBindings: NSObject {
    
    var mode: WebViewBindingsMode
    var decideBindings: [[String: Any]]
    var codelessBindings: [[String: Any]]
    var bindings: [[String: Any]]
    var vcPath: String
    var stringBindings: String
    
    var uiWebView: UIWebView?
    var wkWebView: WKWebView?
    
    var vcSwizzleRunning = false
    var uiWebViewSwizzleRunning = false
    var wkWebViewJavaScriptInjected = false
    var vcSwizzleBlockName = UUID().uuidString
    var uiWebViewSwizzleBlockName = UUID().uuidString
    
    static var global: WebViewBindings {
        return singleton
    }
    private static let singleton = WebViewBindings(mode: WebViewBindingsMode.decide)
    
    private init(mode: WebViewBindingsMode) {
        self.mode = mode
        self.decideBindings = [[String: Any]]()
        self.codelessBindings = [[String: Any]]()
        self.bindings = [[String: Any]]()
        self.vcPath = String()
        self.stringBindings = String()
        super.init()
    }
    
    func fillBindings() {
        if self.mode == WebViewBindingsMode.decide {
            self.bindings = self.decideBindings
        } else if self.mode == WebViewBindingsMode.codeless {
            self.bindings = self.codelessBindings
        } else {
            self.bindings = [[String: Any]]()
        }
        if !self.bindings.isEmpty {
            do {
                let jsonBindings = try JSONSerialization.data(withJSONObject: self.bindings,
                                                              options: JSONSerialization.WritingOptions.prettyPrinted)
                self.stringBindings = String(data: jsonBindings, encoding: String.Encoding.utf8)!
            } catch {
                Logger.debug(message: "Failed to serialize JSONObject: \(self.bindings)")
            }
        }
        stop()
        execute()
    }
}








