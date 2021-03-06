//
//  UIWebViewController.swift
//  SugoDemo
//
//  Created by Zack on 6/12/16.
//  Copyright © 2016年 Sugo. All rights reserved.
//

import UIKit

class UIWebViewController: UIViewController  {

    @IBOutlet weak var webView: UIWebView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = "UIWebView"
        // Do any additional setup after loading the view.
        self.webView.delegate = self
        let url = URL(string: "http://www.jd.com")
        let request = URLRequest(url: url!)
        
        self.webView.loadRequest(request)
    }
    
    deinit {
        self.webView.delegate = nil
    }
    
}

// Mark: - UIWebViewDelegate
extension UIWebViewController: UIWebViewDelegate {
       
    // Note: - Developer should implement these very delegate method for codeless bindings
    func webViewDidStartLoad(_ webView: UIWebView) {
        print(#function)
    }
    
    func webViewDidFinishLoad(_ webView: UIWebView) {
        print(#function)
    }
    
}
