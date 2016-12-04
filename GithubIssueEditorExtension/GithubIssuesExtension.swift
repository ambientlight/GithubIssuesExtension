//
//  GithubIssuesExtension.swift
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

/// Contains shared functionality that commands of this extension use
class GithubIssuesExtension: NSObject, XCSourceEditorExtension {
    
    /// General purpose literals
    class Literal {
        static let errorDomainIdentifier = "info.ambientlight.GithubIssuesExtension"
        
        static let newIssueKey = "New Github Issue"
        static let editIssueKey = "Edit Github Issue"
        
        static let githubPersonalAccessTokenKey = "githubPersonalAccessToken"
        static let appGroupIdentifier = "info.ambientlight.GithubIssuesExtensionGroup"
    }
    
    /// Set of NSError error codes returned by this editor extension
    enum ErrorCode: Int {
        case tokenNotSpecified = -1
        case commandNotFound = -2
        case insertionFailed = -3
        case repositoryNotFound = -4
        case apiTokenIsInvalid = -5
        case sandboxDirectoryNotFound = -6
        case unattributedGithubRequestError = -7
    }
    
    /// Supported issue templates keys(identifiers)
    ///
    /// - newGithubIssue: represents new github issue template
    /// - editGithubIssue: reprsentes modify github issue template
    enum IssueKey: String {
        case newGithubIssue = "newgithubissue"
        case editGithubIssue = "editgithubissue"
    }
    
    /// Supported issue associated parameters
    ///
    /// - owner: repository owner
    /// - repository: repository name
    /// - assignee: username of this issue assignee
    /// - title: issue title
    /// - status: issue status - __open/closed__
    /// - shouldOverrideDescription: indicates whether the description should override existing issue description - __true/false__,
    /// default to false, meaning the description will be appended to existing one
    enum Parameter: String {
        case owner
        case repository
        case assignee
        case title
        case status
        case shouldOverrideDescription
    }
    
    static var personalAccessTokenº: String? {
        get {
            return UserDefaults(suiteName: Literal.appGroupIdentifier)?.string(forKey: Literal.githubPersonalAccessTokenKey)
        }
    }
    
    /// Derives the language of the source based on the file extension
    /// present in xcode-generated header
    ///
    /// - Parameter sourceTextBuffer: invocation's sourceTextBuffer
    /// - Returns: language name or file extension, nil if source filename is not present 
    /// as first non-empty line in xcode-generated header
    static func deriveSourceFileLanguage(fromHeaderIn sourceTextBuffer: XCSourceTextBuffer) -> String? {
        
        var nonEmptyHeaderLines = [String]()
        
        // extracts header lines while ignores empty ones
        for lineObject in sourceTextBuffer.lines {
            let lineNoIndent = (lineObject as! String).trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            if !lineNoIndent.hasPrefix("//"){
                break
            }
            
            if lineNoIndent != "//" {
                nonEmptyHeaderLines.append(lineNoIndent)
            }
        }

        guard nonEmptyHeaderLines.count >= 1 else {
            return nil
        }
        
        let extensionLanguageMap =
            ["m": "objective-c",
             "h": "objective-c"]
        
        //matches: [//][0+ spaces][anything that starts with letter][.][captures 1+ of anything]
        let sourceFileExtensionCapturingGroups = "//\\s*\\w.*\\.(.+)".firstMatchCapturingGroups(in: nonEmptyHeaderLines[0])
        if let parsedExtension = sourceFileExtensionCapturingGroups.first {
            return extensionLanguageMap[parsedExtension] ?? parsedExtension
        } else {
            return nil
        }
    }
    
    /// Derives the owner and repository name from xcode-generated
    /// source file header. 
    /// Project name is treated as a repository, 
    /// while the name of the the copyright holder is treated as repository owner
    ///
    /// - Warning: won't parse correctly if header will have contain lines inserted in between original generated
    /// - Parameter sourceTextBuffer: invocation's sourceTextBuffer
    /// - Returns: tuple of __(owner?, repository?)__
    static func deriveOwnerAndRepository(fromHeaderIn sourceTextBuffer: XCSourceTextBuffer) -> (String?, String?) {
        
        var targetOwnerº: String?
        var targetRepositoryº: String?
        
        var nonEmptyHeaderLines = [String]()
        
        // extracts header lines while ignores empty ones
        for lineObject in sourceTextBuffer.lines {
            let lineNoIndent = (lineObject as! String).trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            if !lineNoIndent.hasPrefix("//"){
                break
            }
            
            if lineNoIndent != "//" {
                nonEmptyHeaderLines.append(lineNoIndent)
            }
        }
        
        guard nonEmptyHeaderLines.count >= 4 else {
            return (targetOwnerº, targetRepositoryº)
        }
        
        //matches: [//][0+ spaces][captures 1+ letters][anything left]
        let projectLineCapturingGroups = "//\\s*([\\w]+).*".firstMatchCapturingGroups(in: nonEmptyHeaderLines[1])
        if let parsedProject = projectLineCapturingGroups.first {
            targetRepositoryº = parsedProject
        }
        
        //matches: [//][0+ spaces][Copyright][0+ spaces][©][0+ spaces][1+ digits][0+ spaces][captures 1+ leters][anything left]
        let ownerLineCapturingGroups = "//\\s*Copyright\\s*©\\s*\\d+\\s*(\\w+).*".firstMatchCapturingGroups(in: nonEmptyHeaderLines[3])
        if let parsedOwner = ownerLineCapturingGroups.first {
            targetOwnerº = parsedOwner
        }
        
        return (targetOwnerº, targetRepositoryº)
    }
    
    /// Parses this extension generated TODOs that are linked to github issues
    ///
    /// - Parameter sourceTextBuffer: invocation's sourceTextBuffer
    /// - Returns: array of issue containers and its associated line ranges
    static func todoAssociatedIssuesItsRanges(from sourceTextBuffer: XCSourceTextBuffer) -> [(IssueEntity, Range<Int>)] {
        
        var targetIssueEntitiesAndItsLineRange = [(IssueEntity, Range<Int>)]()
        
        var skipNextLine: Bool = false
        for index in stride(from: 0, to: sourceTextBuffer.lines.count - 1, by: 1) {
            
            if skipNextLine {
                skipNextLine = false
                continue
            }
            
            let lineNoIndent = (sourceTextBuffer.lines[index] as! String).trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            let nextLineNoIndent = (sourceTextBuffer.lines[index+1] as! String).trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            
            // avoid matching when non-needed
            if !lineNoIndent.hasPrefix("//"){
                continue
            }
            
            //matches: [//TODO:][0+ spaces][captures 1+ letters][0+ spaces][/][0+ spaces][captures 1+ letters][0+ spaces][:][0+ spaces][Issue][0+ spaces][#][captures 1+ digits][0+ spaces][:][0+ spaces][captures anything left]
            let capturingGroups = "//TODO:\\s*([\\w]+)\\s*/\\s*([\\w]+)\\s*:\\s*Issue\\s*#([\\d]+)\\s*:\\s*(.*)".firstMatchCapturingGroups(in: lineNoIndent)
            
            //matches: [//link:][0+ spaces][captures 1+ anything left]
            let linkLineCapturingGroups = "//link:\\s*(.+)".firstMatchCapturingGroups(in: nextLineNoIndent)
            if capturingGroups.count == 4 && linkLineCapturingGroups.count == 1 {
                skipNextLine = true
                
                var issueEntity = IssueEntity()
                issueEntity.foundOwnerº = capturingGroups[0]
                issueEntity.foundRepositoryº = capturingGroups[1]
                issueEntity.foundNumberº = Int(capturingGroups[2])
                issueEntity.foundTitleº = capturingGroups[3]
                
                targetIssueEntitiesAndItsLineRange.append((issueEntity, index ..< index+2))
            }
        }
        
        return targetIssueEntitiesAndItsLineRange
    }
    
    /// Parses this extension new/edit issue templates
    ///
    /// - Parameter sourceTextBuffer: invocation's sourceTextBuffer
    /// - Returns: array of issue containers and its associated line ranges
    static func issueTemplatesWithItsRanges(from sourceTextBuffer: XCSourceTextBuffer) -> [(IssueEntity, Range<Int>)] {
        
        var targetIssueEntitiesAndItsLineRange = [(IssueEntity, Range<Int>)]()
        
        var currentIssueEntity = IssueEntity()
        var isParsingNewIssue = false
        var startedParsingDescription = false
        var parsingTitle = false
        var latestStartLine = 0
        
        var isParsingCodeBlock = false
        var codeBlockRootIndentationº: String?
        var currentCodeBlockLowerBoundº: Int?
        
        for (index, lineObject) in sourceTextBuffer.lines.enumerated() {
            let lineNoIndent = (lineObject as! String).trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            
            if isParsingCodeBlock && !lineNoIndent.hasPrefix("//") {
                var line = (lineObject as! String)
                
                var codeBlockRootIndenation: String
                if let indentation = codeBlockRootIndentationº {
                    codeBlockRootIndenation = indentation
                } else {
                    codeBlockRootIndenation = line.extractingIndentation()
                    codeBlockRootIndentationº = codeBlockRootIndenation
                }
                
                //remove the root indentation from code line
                if let indentationRange = line.range(of: codeBlockRootIndenation){
                    line = line.substring(from: indentationRange.upperBound)
                }
                
                currentIssueEntity.foundDescription += line
                continue
            }
            
            //avoid matching when non-needed
            if !isParsingNewIssue, !lineNoIndent.hasPrefix("//"){
                continue
            }
            
            //matches: [//][captures 1+ letters and spaces][: 0 or 1 times][0+ spaces][captures 1+ digits OR 1+ of anything]
            let capturingGroups = "//([\\w\\s]+):?\\s*(\\d+|.+)".firstMatchCapturingGroups(in: lineNoIndent)
            if let parsedKeyThatCanContrainSpaces = capturingGroups.first,
               let issueKey = IssueKey(rawValue: parsedKeyThatCanContrainSpaces.removingCharacters(in: CharacterSet.whitespaces).lowercased()){
                
                //found a new issue instance
                //finalize current one and move on
                if isParsingNewIssue {
                    startedParsingDescription = false
                    parsingTitle = true
                    targetIssueEntitiesAndItsLineRange.append((currentIssueEntity, latestStartLine ..< index))
                    currentIssueEntity = IssueEntity()
                } else {
                    isParsingNewIssue = true
                    parsingTitle = true
                }
                
                currentIssueEntity.designatedForEditing = (issueKey == .editGithubIssue)
                //second element in captured groups is an issue number or an issue title
                if issueKey == .editGithubIssue, capturingGroups.count >= 2 {
                    currentIssueEntity.foundNumberº = Int(capturingGroups[1])
                } else {
                    currentIssueEntity.foundTitleº = capturingGroups[1]
                }
                
                latestStartLine = index
                continue
            }
            
            if isParsingNewIssue {
                
                //finalize current issue
                if !lineNoIndent.hasPrefix("//") && !isParsingCodeBlock {
                    isParsingNewIssue = false
                    startedParsingDescription = false
                    parsingTitle = false
                    targetIssueEntitiesAndItsLineRange.append((currentIssueEntity, latestStartLine ..< index))
                    currentIssueEntity = IssueEntity()
                    continue
                }
                
                //handles the case when the issues is being parsed
                //and end of file is reached
                defer {
                    if (index == sourceTextBuffer.lines.count - 1){
                        isParsingNewIssue = false
                        parsingTitle = false
                        startedParsingDescription = false
                        targetIssueEntitiesAndItsLineRange.append((currentIssueEntity, latestStartLine ..< index + 1))
                    }
                }
                
                //matches: [//][0+ spaces][-][0+ spaces][captures 1+ letters][0+ spaces][:][0+ spaces][captures 1+ any characters]
                let capturedParameters = "//\\s*-\\s*(\\w+)\\s*:\\s*(.+)".firstMatchCapturingGroups(in: lineNoIndent)
                if capturedParameters.isEmpty {
                    //found not a parameter pattern, treated as description if we are not parsing title anymore
                    
                    let lineWithoutCommentsPrefixCleaned = lineNoIndent.substring(from: lineNoIndent.index(lineNoIndent.startIndex, offsetBy: 2)).trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                    
                    //we are parsing title until we either reach a parameter line or //[empty]
                    if parsingTitle {
                        if lineWithoutCommentsPrefixCleaned.isEmpty {
                            parsingTitle = false
                        } else if let title = currentIssueEntity.foundTitleº {
                            currentIssueEntity.foundTitleº = title + " " + lineWithoutCommentsPrefixCleaned
                        }
                    
                    //if we already started parsing description, treat //[empty] as newline, ignore //[empty] otherwise
                    //startedParsingDescription is set once we encounter any first //[random text] which is not a parameter pattern after [keyline]
                    } else if startedParsingDescription {
                        //start parsing code block
                        if lineWithoutCommentsPrefixCleaned.hasPrefix("<code>") && !isParsingCodeBlock {
                            isParsingCodeBlock = true
                            currentIssueEntity.foundDescription += "\n" + "```" + (self.deriveSourceFileLanguage(fromHeaderIn: sourceTextBuffer) ?? String()) + "\n"
                            currentCodeBlockLowerBoundº = index + 1
                        } else if lineWithoutCommentsPrefixCleaned.hasPrefix("</code>") && isParsingCodeBlock {
                            currentIssueEntity.foundDescription += "\n" + "```" + "\n"
                            isParsingCodeBlock = false
                            
                            if let currentCodeBlockLowerBound = currentCodeBlockLowerBoundº {
                                currentIssueEntity.codeRanges.append(currentCodeBlockLowerBound ..< index)
                            }
                            currentCodeBlockLowerBoundº = nil
                            
                        } else {
                            currentIssueEntity.foundDescription += (lineWithoutCommentsPrefixCleaned.isEmpty) ? "\n" : lineWithoutCommentsPrefixCleaned
                        }
                    } else if !lineWithoutCommentsPrefixCleaned.isEmpty {
                        currentIssueEntity.foundDescription += lineWithoutCommentsPrefixCleaned
                        startedParsingDescription = true
                    }
                    
                } else if capturedParameters.count == 2 {
                    
                    //we are parsing title until we either reach a parameter line or //[empty]
                    parsingTitle = false
                    
                    let parameterString = capturedParameters[0]
                    let parameterValue = capturedParameters[1]
                    guard let parameter = Parameter(rawValue: parameterString) else {
                        //unknown parameter
                        continue
                    }
                    
                    // we don't override the issue parameter if we it is already set
                    // (if for some reason duplicated parameter was found)
                    
                    switch (parameter, currentIssueEntity.designatedForEditing) {
                    case (.owner, _):
                        guard currentIssueEntity.foundOwnerº == nil else { continue }
                        currentIssueEntity.foundOwnerº = parameterValue
                    case (.repository, _):
                        guard currentIssueEntity.foundRepositoryº == nil else { continue }
                        currentIssueEntity.foundRepositoryº = parameterValue
                    case (.assignee, _):
                        guard currentIssueEntity.foundAssigneeº == nil else { continue }
                        currentIssueEntity.foundAssigneeº = parameterValue
                    case (.title, true):
                        guard currentIssueEntity.foundTitleº == nil else { continue }
                        currentIssueEntity.foundTitleº = parameterValue
                    case (.status, true):
                        guard currentIssueEntity.statusº == nil else { continue }
                        currentIssueEntity.statusº = Openness(rawValue: parameterValue)
                    case (.shouldOverrideDescription, true):
                        guard currentIssueEntity.editDescriptionShouldOverrideº == nil else { continue }
                        if parameterValue.lowercased() == "true" || parameterValue == "1" {
                            currentIssueEntity.editDescriptionShouldOverrideº = true
                        } else if parameterValue.lowercased() == "false" || parameterValue == "0"  {
                            currentIssueEntity.editDescriptionShouldOverrideº = false
                        }
                    default: break
                    }
                }
            }
        }
        
        return targetIssueEntitiesAndItsLineRange
    }
    
    /// Sanitizes underlying OctoKit error
    ///
    /// - Parameters:
    ///   - error: original octokit error
    ///   - repo: repository name
    ///   - owner: repository owner name
    /// - Returns: error with sanitized description
    static func sanitizedRepositoryError(forUnderlyingError error: Error, inRepositoryWithName repo: String, owner: String) -> NSError {
        
        let requestKitErrorMessageº = ((error as NSError).userInfo["RequestKitErrorResponseKey"] as? [String: Any])?["message"] as? String
        if let errorMessage = requestKitErrorMessageº, errorMessage == "Not Found" {
             return NSError(domain: GithubIssuesExtension.Literal.errorDomainIdentifier,
                                      code: GithubIssuesExtension.ErrorCode.repositoryNotFound.rawValue,
                                      userInfo: [NSLocalizedDescriptionKey: "Repository \(owner)/\(repo) not found"])
        } else if let errorMessage = requestKitErrorMessageº, errorMessage == "Bad credentials" {
             return NSError(domain: GithubIssuesExtension.Literal.errorDomainIdentifier,
                                      code: GithubIssuesExtension.ErrorCode.apiTokenIsInvalid.rawValue,
                                      userInfo: [NSLocalizedDescriptionKey: "API token is invalid"])
        } else if let errorMessage = requestKitErrorMessageº {
            return NSError(domain: GithubIssuesExtension.Literal.errorDomainIdentifier,
                                      code: GithubIssuesExtension.ErrorCode.unattributedGithubRequestError.rawValue,
                                      userInfo: [NSLocalizedDescriptionKey: "Github request error: \(errorMessage)"])
        } else if (error as NSError).domain == "com.nerdishbynature.octokit" && (error as NSError).code == 404 {
            return NSError(domain: GithubIssuesExtension.Literal.errorDomainIdentifier,
                           code: GithubIssuesExtension.ErrorCode.unattributedGithubRequestError.rawValue,
                           userInfo: [NSLocalizedDescriptionKey: "Github request error: \((error as NSError).code): Likely repository or issue has not been found. (are you trying to access private repository but you access token doesn't contain a repo scope?)"])
        } else {
            return error as NSError
        }
    }
}
