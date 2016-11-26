//
//  NewIssueCommand.swift
//  GithubIssuesExtension
//
//  Created by Taras Vozniuk on 21/11/2016.
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

import OctoKit
import RequestKit

/// Handles insertion of new issue template into source buffer
class NewIssueCommand: NSObject, XCSourceEditorCommand {
    
    func perform(with invocation: XCSourceEditorCommandInvocation, completionHandler: @escaping (Error?) -> Void ) -> Void {
        
        let (derivedOwnerº, derivedRepositoryº) = GithubIssuesExtension.deriveOwnerAndRepository(fromHeaderIn: invocation.buffer)
        let sourceEditSession = SourceEditSession(sourceBuffer: invocation.buffer)
        
        let selection = invocation.buffer.selections.firstObject as! XCSourceTextRange
        let newIssueBody = [
            "// \(GithubIssuesExtension.Literal.newIssueKey): <#Title#>",
            "//",
            "// - \(GithubIssuesExtension.Parameter.owner.rawValue): \(derivedOwnerº ?? "<#owner#>")",
            "// - \(GithubIssuesExtension.Parameter.repository.rawValue): \(derivedRepositoryº ?? "<#repository#>")",
            "// - \(GithubIssuesExtension.Parameter.assignee.rawValue): <#assignee#>",
            "//",
            "// <#Description#>"
        ]
        
        let targetError: NSError? = (!sourceEditSession.insert(strings: newIssueBody, withPreservedIndentationAfter: selection.end.line - 1)) ? NSError(domain: GithubIssuesExtension.Literal.errorDomainIdentifier, code: GithubIssuesExtension.ErrorCode.insertionFailed.rawValue, userInfo: [NSLocalizedDescriptionKey: "Couldn't insert. Please submit an issues on https://github.com/ambientlight/GithubIssuesExtension/issues if it is not there already"]) : nil
        completionHandler(targetError)
    }
    
}
