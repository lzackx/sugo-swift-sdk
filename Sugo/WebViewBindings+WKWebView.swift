//
//  WebViewBindings+WKWebView.swift
//  Sugo
//
//  Created by Zack on 29/11/16.
//  Copyright © 2016年 Sugo. All rights reserved.
//

import Foundation
import WebKit
import JavaScriptCore

extension WebViewBindings: WKScriptMessageHandler {
    
    func startWKWebViewBindings(webView: inout WKWebView) {
        if !self.wkWebViewJavaScriptInjected {
            self.wkWebViewCurrentJSTrack = self.wkJavaScriptTrack
            self.wkWebViewCurrentJSSource = self.wkJavaScriptSource
            self.wkWebViewCurrentJSExcute = self.wkJavaScriptExcute
            webView.configuration.userContentController
                .addUserScript(self.wkWebViewCurrentJSTrack)
            webView.configuration.userContentController
                .addUserScript(self.wkWebViewCurrentJSSource)
            webView.configuration.userContentController
                .addUserScript(self.wkWebViewCurrentJSExcute)
            webView.configuration.userContentController.add(self, name: "WKWebViewBindingsTrack")
            webView.configuration.userContentController.add(self, name: "WKWebViewBindingsTime")
            self.wkWebViewJavaScriptInjected = true
            Logger.debug(message: "WKWebView Injected")
        }
    }
    
    func stopWKWebViewBindings(webView: WKWebView) {
        if self.wkWebViewJavaScriptInjected {
            webView.configuration.userContentController.removeScriptMessageHandler(forName: "WKWebViewBindingsTrack")
            webView.configuration.userContentController.removeScriptMessageHandler(forName: "WKWebViewBindingsTime")
            self.wkWebViewJavaScriptInjected = false
            self.wkWebView = nil
        }
    }
    
    func updateWKWebViewBindings(webView: inout WKWebView) {
        if self.wkWebViewJavaScriptInjected {
            var userScripts = webView.configuration.userContentController.userScripts
            if let index = userScripts.index(of: self.wkWebViewCurrentJSSource) {
                userScripts.remove(at: index)
            }
            webView.configuration.userContentController.removeAllUserScripts()
            for userScript in userScripts {
                webView.configuration.userContentController.addUserScript(userScript)
            }
            self.wkWebViewCurrentJSSource = self.wkJavaScriptSource
            webView.configuration.userContentController
                .addUserScript(self.wkWebViewCurrentJSSource)
            Logger.debug(message: "WKWebView Updated")
        }
    }
    
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        
        Logger.debug(message: "message name: \(message.name)")
        switch message.name {
        case "WKWebViewBindingsTrack":
            if let body = message.body as? [String: Any] {
                if let eventID = body["eventID"] as? String {
                    WebViewInfoStorage.global.eventID = eventID
                }
                if let eventName = body["eventName"] as? String {
                    WebViewInfoStorage.global.eventName = eventName
                }
                if let properties = body["properties"] as? String {
                    WebViewInfoStorage.global.properties = properties
                }
                
                let pData = WebViewInfoStorage.global.properties.data(using: String.Encoding.utf8)
                if let pJSON = try? JSONSerialization.jsonObject(with: pData!,
                                                                 options: JSONSerialization.ReadingOptions.mutableContainers) as? Properties {
                    Sugo.mainInstance().track(eventID: WebViewInfoStorage.global.eventID,
                                              eventName: WebViewInfoStorage.global.eventName,
                                              properties: pJSON)
                } else {
                    Sugo.mainInstance().track(eventID: WebViewInfoStorage.global.eventID,
                                              eventName: WebViewInfoStorage.global.eventName)
                }
                Logger.debug(message: "id = \(WebViewInfoStorage.global.eventID), name = \(WebViewInfoStorage.global.eventName)")
            } else {
                Logger.debug(message: "Wrong message body type: name=\(message.name), body=\(message.body as? String)")
            }
        case "WKWebViewBindingsTime":
            if let body = message.body as? [String: Any] {
                if let eventName = body["eventName"] as? String {
                    Sugo.mainInstance().time(event: eventName)
                    Logger.debug(message: "time event name = \(eventName)")
                }
            } else {
                Logger.debug(message: "Wrong message body type: name=\(message.name), body=\(message.body as? String)")
            }
        default:
            Logger.debug(message: "Wrong message name = \(message.name)")
        }
    }
}

extension WebViewBindings {
    
    var wkJavaScriptExcute: WKUserScript {
        return WKUserScript(source: self.jsWKWebViewBindingsExcute,
                            injectionTime: WKUserScriptInjectionTime.atDocumentEnd,
                            forMainFrameOnly: true)
    }
    
    var wkJavaScriptSource: WKUserScript {
        return WKUserScript(source: self.jsWKWebViewBindingsSource,
                            injectionTime: WKUserScriptInjectionTime.atDocumentEnd,
                            forMainFrameOnly: true)
    }
    
    var wkJavaScriptTrack: WKUserScript {
        return WKUserScript(source: self.jsWKWebViewTrack,
                            injectionTime: WKUserScriptInjectionTime.atDocumentEnd,
                            forMainFrameOnly: true)
    }
    
    var jsWKWebViewBindingsExcute: String {
        return self.jsSource(of: "WebViewBindings.excute")
    }
    
    var jsWKWebViewBindingsSource: String {
        return self.jsSource(of: "WebViewBindings.1")
            + "sugo_bindings.current_page = '\(self.wkVCPath)::' + window.location.pathname;\n"
            + "sugo_bindings.h5_event_bindings = \(self.stringBindings);\n"
            + self.jsSource(of: "WebViewBindings.2")
    }
    var jsWKWebViewTrack: String {
        return self.jsSource(of: "WKWebViewTrack")
    }
}

