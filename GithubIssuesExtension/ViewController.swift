//
//  ViewController.swift
//  GithubIssuesExtension
//
//  Created by Taras Vozniuk on 26/11/2016.
//  Copyright © 2016 Ambientlight. All rights reserved.
//

// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Cocoa
import Foundation

class ViewController: NSViewController {

    let githubPersonalAccessTokenKey = "githubPersonalAccessToken"
    let appGroupIdentifier = "info.ambientlight.GithubIssuesExtensionGroup"
    
    @IBOutlet weak var versionLabel: NSTextField!
    @IBOutlet weak var userTokenTextField: NSTextField!
    @IBOutlet weak var saveTokenButton: NSButton!
    @IBOutlet weak var helpButton: NSButton!
    @IBOutlet weak var clearTokenButton: NSButton!
    @IBOutlet weak var tokenSaveLabel: NSTextField!
    @IBOutlet weak var learnMoreButton: NSButton!
    
    var personalAccessTokenº: String? {
        get {
            return UserDefaults(suiteName: appGroupIdentifier)?.string(forKey: self.githubPersonalAccessTokenKey)
        }
        set {
            //ignore empty string if passed
            if let newValue = newValue, newValue.isEmpty {
                return
            }
            
            let userDefaults = UserDefaults(suiteName: appGroupIdentifier)
            userDefaults?.set(newValue, forKey: self.githubPersonalAccessTokenKey)
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.updateUIElements()
        self.updateLearnMoreButton()
    }

    @IBAction func didPressSaveTokenButton(_ sender: NSButton) {
        self.personalAccessTokenº = self.userTokenTextField.stringValue
        self.updateUIElements()
    }
    
    
    @IBAction func didPressLearnMoreButton(_ sender: Any) {
        guard let githubURL = URL(string: "https://github.com/ambientlight/GithubIssuesExtension") else {
            return
        }
        
        NSWorkspace.shared().open(githubURL)
    }
    
    @IBAction func didPressRemoveTokenButton(_ sender: Any) {
        
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Are you sure?"
        alert.informativeText = "You are about to remove your personal access token from github issues extension."
        alert.addButton(withTitle: "Cancel")
        alert.addButton(withTitle: "OK")
        
        if alert.runModal() != NSAlertFirstButtonReturn {
            self.personalAccessTokenº = nil
        }
        
        self.updateUIElements()
    }
    
    func updateLearnMoreButton(){
        
        let paragraphStyle = NSMutableParagraphStyle();
        paragraphStyle.alignment = .center;
        
        let attributedText = NSMutableAttributedString(string: "Learn more")
        attributedText.addAttribute(NSForegroundColorAttributeName, value: NSColor.blue, range: NSRange(location: 0, length: attributedText.length))
        attributedText.addAttribute(NSParagraphStyleAttributeName, value: paragraphStyle, range: NSRange(location: 0, length: attributedText.length))
        attributedText.fixAttributes(in: NSRange(location: 0, length: attributedText.length))
        
        
        self.learnMoreButton.attributedTitle = attributedText
    }
    
    func updateUIElements(){
        
        self.versionLabel.stringValue = "version: " + (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unspecified")
        if self.personalAccessTokenº != nil {
            
            self.userTokenTextField.stringValue.removeAll()
            
            self.userTokenTextField.isHidden = true
            //self.helpButton.isHidden = true
            self.saveTokenButton.isHidden = true
            
            self.clearTokenButton.isHidden = false
            self.tokenSaveLabel.isHidden = false
            
        } else {
            
            self.saveTokenButton.isEnabled = false
            
            self.clearTokenButton.isHidden = true
            self.tokenSaveLabel.isHidden = true
            
            self.userTokenTextField.isHidden = false
            //self.helpButton.isHidden = false
            self.saveTokenButton.isHidden = false
        }
    }
}

extension ViewController: NSControlTextEditingDelegate {
    
    func control(_ control: NSControl, textShouldEndEditing fieldEditor: NSText) -> Bool {
        self.personalAccessTokenº = control.stringValue
        self.updateUIElements()
        return true
    }
    
    override func controlTextDidChange(_ obj: Notification) {
        guard let textField = obj.object as? NSTextField else {
            return
        }
        
        self.saveTokenButton.isEnabled = !textField.stringValue.isEmpty
    }
    
}
