//
//  SourceEditSession.swift
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
import XcodeKit

/// Handles insertion and deletion of lines from XCSourceTextBuffer
/// Keeps track of index offset that results from previous insertion and deletions
/// Usefull in circumstances when the a multiple number of insertion/deletion need to be made,
/// since the caller doesn't need to incapsulate insertion/deletion offset logic
class SourceEditSession {
    
    /// index offset for next operation that results from previous insertion/deletion
    fileprivate var editOffset: Int = 0
    
    /// associated source text buffer
    let buffer: XCSourceTextBuffer
    public init(sourceBuffer: XCSourceTextBuffer) {
        self.buffer = sourceBuffer
    }
    
    /// Inserts an array of string into underyling source text buffer
    /// at the same indentation as the line at __index__
    ///
    /// - Parameters:
    ///   - strings: an array of strings to insert, each string should not contain any indentation
    /// and is not required to contain the carrier return character in the end
    ///   - index: the index of previous line before the insertion point. This index should not be offsetted for the previous
    /// insert/remove operation made during this edit session, since they are handled internally
    /// - Returns: true if insertion succeeds
    public func insert(strings: [String], withPreservedIndentationAfter index: Int) -> Bool {
        
        let offsetedIndex = index + self.editOffset
        guard offsetedIndex < self.buffer.lines.count else {
            //print("\(#function):\(#line): Insertion silenty failed: line reference(\(index)) is beyond the bounds of buffer lines(\(self.buffer.lines.count))")
            return false
        }
        
        let nonSpaceCharacters = CharacterSet.whitespacesAndNewlines.inverted
        
        let indentationEndIndex: String.Index
        let targetLine = (self.buffer.lines[offsetedIndex] as! String)
        
        // retriving the possion of next character after indentation
        if let range = targetLine.rangeOfCharacter(from: nonSpaceCharacters){
            indentationEndIndex = range.lowerBound
        } else {
            // if line contains only whitespaces and newlines, set the indendationEndIndex 
            // to the position before the last (carrier return) character
            indentationEndIndex = (targetLine.isEmpty) ? targetLine.endIndex : targetLine.index(before: targetLine.endIndex)
        }
        
        // construct the indendentation string that will be prefixed in each string we will insert
        let currentIndentation = targetLine.substring(to: indentationEndIndex).trimmingCharacters(in: CharacterSet.newlines)
        let newStringsToInsert = strings.map { ($0.hasSuffix("\n") ? currentIndentation + $0 : currentIndentation + $0 + "\n") }
        
        let range: Range<Int> = offsetedIndex + 1 ..< offsetedIndex + 1 + strings.count
        self.buffer.lines.insert(newStringsToInsert, at: IndexSet(integersIn: range))
        
        self.editOffset += strings.count
    
        return true
    }
    
    /// Removes lines at given index range from underlying sourceTextBuffer
    ///
    /// - Parameter indexRange: an index range of lines to remove
    /// - Returns: true if insertion succeeds
    public func remove(linesAt indexRange: Range<Int>) -> Bool {
        
        guard indexRange.lowerBound >= 0 && indexRange.upperBound <= self.buffer.lines.count else {
            //print("\(#function):\(#line): Remove silenty failed: Range is outside the bounds of buffer lines(\(self.buffer.lines.count))")
            return false
        }
        
        let length = indexRange.upperBound - indexRange.lowerBound
        self.buffer.lines.removeObjects(in: NSRange(location: indexRange.lowerBound + self.editOffset, length: length))
        self.editOffset -= length
        
        return true
    }
}
