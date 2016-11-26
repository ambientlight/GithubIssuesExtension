//
//  extension_String.swift
//  GithubIssuesExtension
//
//  Created by Taras Vozniuk on 23/11/2016.
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

import Foundation

extension String {
    
    /// checks whether the reciever is and xcode-placeholder
    public var isPlaceholder: Bool {
        return self.hasPrefix("<#") && self.hasSuffix("#>")
    }
    
    /// Removes occurences of all characters from passed character set
    ///
    /// - Parameter set: a character set of characters to remove from string
    /// - Returns: the resulting string with all occuranences of chars from character set removed
    public func removingCharacters(in set: CharacterSet) -> String {
        
        var target = self
        for character in set.allCharacters {
            target = target.replacingOccurrences(of: "\(character)", with: String())
        }
        
        return target
    }
    
    /// Verifies whether the reciever(regex pattern) has matches in a passed string
    ///
    /// - Parameter string: string to validate the regex pattern
    /// - Returns: true if the passed string has matches of reciever(regex patterm)
    public func hasMatches(in string: String) -> Bool {
        
        guard let regex = try? NSRegularExpression(pattern: self, options: .caseInsensitive), regex.numberOfCaptureGroups != 0 else {
            return false
        }
        
        return regex.numberOfMatches(in: string, options: [], range: NSMakeRange(0, string.characters.count)) > 0
    }
    
    /// Retrieve the capturing groups values in a first match of reciever(regex pattern) in the passed string
    ///
    /// - Parameter string: string to extract the capturing groups of reciever(regex pattern)
    /// - Returns: an array of capturing groups values, empty array if passed string doesn't match reciever(regex pattern)
    public func firstMatchCapturingGroups(in string: String) -> [String] {
    
        guard let regex = try? NSRegularExpression(pattern: self, options: .caseInsensitive), regex.numberOfCaptureGroups != 0 else {
            return []
        }
        
        if let match = regex.firstMatch(in: string, options: [], range: NSMakeRange(0, string.characters.count)){
            
            var targetStrings = [String]()
            for index in 1 ... regex.numberOfCaptureGroups {
                let groupRange = match.rangeAt(index)
                targetStrings.append((string as NSString).substring(with: groupRange))
            }
            
            return targetStrings
        } else {
            return []
        }
    }
    
    /// Enumerates capturing groups of each match of reciever(regex pattern) in a passed string
    ///
    /// - Parameters:
    ///   - string: string to extract the capturing groups of reciever(regex pattern)
    ///   - enumerator: callback capturing groups enumerator
    public func enumerateCapturingGroups(in string: String, enumerator: ([String]) -> Void){
        
        guard let regex = try? NSRegularExpression(pattern: self, options: .caseInsensitive), regex.numberOfCaptureGroups != 0 else {
            return
        }
        
        let matches = regex.matches(in: string, options: [], range: NSMakeRange(0, string.characters.count))
        for match in matches {
            
            var targetStrings = [String]()
            for index in 1 ... regex.numberOfCaptureGroups {
                let groupRange = match.rangeAt(index)
                targetStrings.append((string as NSString).substring(with: groupRange))
            }
            
            enumerator(targetStrings)
        }
        
    }
    
    /// Retrieve capturing groups values in each match of reciever(regex pattern) in the passed string
    ///
    /// - Parameter string: string to extract the capturing groups of reciever(regex pattern)
    /// - Returns: array of array of capturing groups values (for each match), empty array if passed string doesn't match reciever(regex pattern)
    public func capturingGroups(in string: String) -> [[String]] {
        
        var targetCapturingGroups = [[String]]()
        self.enumerateCapturingGroups(in: string) { (capturingGroups) in
            targetCapturingGroups.append(capturingGroups)
        }
        
        return targetCapturingGroups
    }
}
