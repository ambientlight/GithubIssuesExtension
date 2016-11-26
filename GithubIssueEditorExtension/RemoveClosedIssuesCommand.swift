//
//  RemoveClosedIssuesCommand.swift
//  GithubIssuesExtension
//
//  Created by Taras Vozniuk on 24/11/2016.
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
import Dispatch

import OctoKit
import RequestKit

/// Hashable tuple idenfying repostory: owner and repository name
struct RepositoryIdentifier: Hashable {
    var owner: String
    var repository: String
    
    var hashValue: Int {
        return "\(owner)/\(repository)".hashValue
    }
    
    static func ==(lhs: RepositoryIdentifier, rhs: RepositoryIdentifier) -> Bool {
        return lhs.owner == rhs.owner && lhs.repository == rhs.repository
    }
}

/// Removes github-issue linked TODOs if github issues are closed already
class RemoveClosedIssuesCommand: NSObject, XCSourceEditorCommand {
    
    func perform(with invocation: XCSourceEditorCommandInvocation, completionHandler: @escaping (Error?) -> Void ) -> Void {
        
        let existingIssueWithItsRanges = GithubIssuesExtension.todoAssociatedIssuesItsRanges(from: invocation.buffer)
        self.retrieveClosedIssues(for: existingIssueWithItsRanges, andRemoveThemFrom: invocation.buffer, completionHandler: completionHandler)
    }
    
    /// Retrieves all repositories closed issues for passed github-issue and removes associated TODOs
    /// if github issue was already closed
    ///
    /// - remark: the choice was made to fetch all specified repositories and its closed issues instead of invidual issues
    ///           since in a common scenario this will result in lesser amount of API calls needed
    ///
    /// - Parameters:
    ///   - issuesWithRanges: array of issue containers and its associated line ranges
    ///   - source: invocation's sourceTextBuffer
    ///   - completionHandler: a target completion handler that identifiers completion of this command
    func retrieveClosedIssues(for issuesWithRanges: [(IssueEntity, Range<Int>)], andRemoveThemFrom source: XCSourceTextBuffer, completionHandler: @escaping (Error?) -> Void){
        
        // constructing a set of unique repository identifiers
        var repoSet = Set<RepositoryIdentifier>()
        issuesWithRanges.forEach { (issue: IssueEntity, range: Range<Int>) in
            guard let owner = issue.foundOwnerº, !owner.isEmpty,
                  let repo = issue.foundRepositoryº, !repo.isEmpty
            else {
                return
            }
            
            repoSet.insert(RepositoryIdentifier(owner: owner, repository: repo))
        }
        
        guard let apiToken = GithubIssuesExtension.personalAccessTokenº else {
            let error = NSError(domain: GithubIssuesExtension.Literal.errorDomainIdentifier,
                                code: GithubIssuesExtension.ErrorCode.tokenNotSpecified.rawValue,
                                userInfo: [NSLocalizedDescriptionKey: "Github personal access token has not been specified. Please open Github Issues Extension application and specify your access token."])
            completionHandler(error)
            return
        }

        let sourceEditSession = SourceEditSession(sourceBuffer: source)
        // github issues retrieval API fetch count
        let fetchCount = 100
        for repo in repoSet {
            let semaphore = DispatchSemaphore(value: 0)
            var fetchedIssues = [Issue]()
            
            // fetching all repository closed issues. FetchCount at a time.
            var page = 1
            var totalFetched = 0
            repeat {
                var capturedErrorº: Error?
                _ = Octokit(TokenConfiguration(apiToken)).issues(owner: repo.owner, repository: repo.repository, state: .Closed, page: "\(page)", perPage: "\(fetchCount)") { (response: Response<[Issue]>) in
                    switch response {
                    case .failure(let error):
                        //sanitizing error messages
                        capturedErrorº = GithubIssuesExtension.sanitizedRepositoryError(forUnderlyingError: error, inRepositoryWithName: repo.repository, owner: repo.owner)

                    case .success(let issues):
                        fetchedIssues += issues
                        totalFetched = issues.count
                    }
                    
                    semaphore.signal()
                }
                
                semaphore.wait()
                
                // abort the command if the error was found
                if let capturedError = capturedErrorº {
                    completionHandler(capturedError)
                    return
                }
                
                page += 1
            } while (totalFetched == fetchCount)
            
            // filter the passed issues that are closed on github
            let thisRepoIssuesThatAreClosedWithRanges = issuesWithRanges.filter { (issue: IssueEntity, range: Range<Int>) in
                guard let owner = issue.foundOwnerº, !owner.isEmpty,
                      let repository = issue.foundRepositoryº, !repository.isEmpty
                else {
                    return false
                }
                
                return repo.owner == owner && repo.repository == repository && fetchedIssues.contains { (fetchedIssue: Issue) in
                    guard let fetchedIssueNumber = fetchedIssue.number,
                          let issueNumber = issue.foundNumberº
                    else {
                        return false
                    }
                    
                    return fetchedIssueNumber == issueNumber
                }
            }
            
            //remove the closed issues from source
            for (_, range) in thisRepoIssuesThatAreClosedWithRanges {
                _ = sourceEditSession.remove(linesAt: range)
            }
        }
        
        completionHandler(nil)
    }
    
}
