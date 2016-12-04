//
//  SubmitNewIssuesCommand.swift
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

import OctoKit
import RequestKit

/// Parses the new/edit issue template from source and submit them to github
class SubmitIssuesCommand: NSObject, XCSourceEditorCommand {
    
    func perform(with invocation: XCSourceEditorCommandInvocation, completionHandler: @escaping (Error?) -> Void ) -> Void {
        let targetIssueEntitiesAndItsLineRange = GithubIssuesExtension.issueTemplatesWithItsRanges(from: invocation.buffer)
        self.submit(issuesWithLineRange: targetIssueEntitiesAndItsLineRange, with: invocation, completionHandler: completionHandler)
    }
    
    /// Submits the passed issues to github
    ///
    /// - Parameters:
    ///   - issuesWithRanges: array of issue containers and its associated line ranges
    ///   - source: invocation's sourceTextBuffer
    ///   - completionHandler: a target completion handler that identifiers completion of this command
    func submit(issuesWithLineRange: [(IssueEntity, Range<Int>)], with invocation: XCSourceEditorCommandInvocation, completionHandler: @escaping (Error?) -> Void){
        
        guard let apiToken = GithubIssuesExtension.personalAccessTokenº else {
            let error = NSError(domain: GithubIssuesExtension.Literal.errorDomainIdentifier,
                          code: GithubIssuesExtension.ErrorCode.tokenNotSpecified.rawValue,
                          userInfo: [NSLocalizedDescriptionKey: "Github personal access token has not been specified. Please open Github Issues Extension application and specify your access token."])
            completionHandler(error)
            return
        }
        
        //
        // submitting the issues to github
        //
        let tokenConfiguration = TokenConfiguration(apiToken)
        let sourceEditSession = SourceEditSession(sourceBuffer: invocation.buffer)
        for (issueEntity, issueBodyRange) in issuesWithLineRange {
            
            // issue templates that don't contain required parameters are ignored
            if let issueOwner = issueEntity.foundOwnerº, !issueOwner.isEmpty, !issueOwner.isPlaceholder,
                let issueRepo = issueEntity.foundRepositoryº, !issueRepo.isEmpty, !issueRepo.isPlaceholder {
                
                let targetDescriptionº = (issueEntity.foundDescription.isPlaceholder) ? nil : issueEntity.foundDescription
                let targetAssigneeº = ((issueEntity.foundAssigneeº ?? "").isPlaceholder) ? nil : issueEntity.foundAssigneeº
                
                /// target closure that replaces the issues template with github issue associated TODO
                let replaceIssueTemplateWithTargetIssueContent = { (issueº: Issue?) in
                    
                    let resultingIssueTitle = issueº?.title ?? String()
                    let resultingIssueNumber = issueº?.number ?? -1
                    // constructing the target issue URL by hand since API returns only api-url
                    let resultingIssueURLString = "https://github.com/\(issueOwner)/\(issueRepo)/issues/\(resultingIssueNumber)"
                    
                    // constructing the line ranges that belong to issue for removal after submission succeeds
                    // code blocks are ignored
                    var issueBodyRangesExcludingCode = [Range<Int>]()
                    var beginingRange = issueBodyRange.lowerBound
                    for codeRange in issueEntity.codeRanges {
                        issueBodyRangesExcludingCode.append(beginingRange ..< codeRange.lowerBound)
                        beginingRange = codeRange.upperBound
                    }
                    issueBodyRangesExcludingCode.append(beginingRange ..< issueBodyRange.upperBound)
            
                    for issueBodyRangeExcludingCode in issueBodyRangesExcludingCode {
                        _ = sourceEditSession.remove(linesAt: issueBodyRangeExcludingCode.lowerBound ..< issueBodyRangeExcludingCode.upperBound)
                    }
                    let submittedIssueBody = [
                        "//TODO: \(issueOwner)/\(issueRepo): Issue #\(resultingIssueNumber): \(resultingIssueTitle)",
                        "//link: \(resultingIssueURLString)"
                    ]
                    
                    _ = sourceEditSession.insert(strings: submittedIssueBody, withPreservedIndentationAfter: issueBodyRange.upperBound - 1)
                }
                
                var capturedErrorº: Error?
                let semaphore = DispatchSemaphore(value: 0)
                let requestCompletionHandler = { (response: Response<Issue>) in
                    switch response {
                    case .success(let issue):
                        replaceIssueTemplateWithTargetIssueContent(issue)
                    case .failure(let error):
                        //sanitizing error messages
                        capturedErrorº = GithubIssuesExtension.sanitizedRepositoryError(forUnderlyingError: error, inRepositoryWithName: issueRepo, owner: issueOwner)
                    }
                    
                    semaphore.signal()
                }
            
                if issueEntity.designatedForEditing {
                    
                    // issue templates that don't contain required parameters are ignored
                    guard let issueNumber = issueEntity.foundNumberº else {
                        continue
                    }
                    
                    let targetTitleº = (issueEntity.foundTitleº ?? "").isPlaceholder ? nil : issueEntity.foundTitleº

                    if let shouldOverride = issueEntity.editDescriptionShouldOverrideº, shouldOverride == true {
                        _ = Octokit(tokenConfiguration).patchIssue(owner: issueOwner, repository: issueRepo, number: issueNumber, title: targetTitleº, body: targetDescriptionº, assignee: targetAssigneeº, state: issueEntity.statusº, completion: requestCompletionHandler)
                    } else {
                        // retrieving existing issue in order to get the existing description (for appending)
                        _ = Octokit(tokenConfiguration).issue(owner: issueOwner, repository: issueRepo, number: issueNumber) { (response) in
                            switch response {
                            case .success(let issue):
                                
                                var modifiedDescription = (issue.body ?? "")
                                if let descriptionAddition = targetDescriptionº {
                                    modifiedDescription += "\n" + descriptionAddition
                                }
                                
                                _ = Octokit(tokenConfiguration).patchIssue(owner: issueOwner, repository: issueRepo, number: issueNumber, title: targetTitleº, body: modifiedDescription, assignee: targetAssigneeº, state: issueEntity.statusº, completion: requestCompletionHandler)
                                
                            case .failure(let error):
                                capturedErrorº = GithubIssuesExtension.sanitizedRepositoryError(forUnderlyingError: error, inRepositoryWithName: issueRepo, owner: issueOwner)
                                semaphore.signal()
                            }
                        }
                    }
                    
                    semaphore.wait()
                    
                } else {
                    
                    // issue templates that don't contain required parameters are ignored
                    guard let issueTitle = issueEntity.foundTitleº, !issueTitle.isEmpty, !issueTitle.isPlaceholder else {
                        continue
                    }
                    
                    _ = Octokit(tokenConfiguration).postIssue(owner: issueOwner, repository: issueRepo, title: issueTitle, body: targetDescriptionº, assignee: targetAssigneeº, completion: requestCompletionHandler)
                    semaphore.wait()
                }
                
                // abort the command if the error was found
                if let capturedError = capturedErrorº {
                    completionHandler(capturedError)
                    return
                }
            }
        }
        
        completionHandler(nil)
    }
    
}
