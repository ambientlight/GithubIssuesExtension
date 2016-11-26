//
//  NewIssueEntity.swift
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
import OctoKit

/// Container for issue-associated data, call it a POJO if you like
struct IssueEntity {
    var foundTitleº: String?
    var foundOwnerº: String?
    var foundRepositoryº: String?
    var foundAssigneeº: String?
    var foundDescription: String = String()
    var foundNumberº: Int?
    
    /// issue status
    var statusº: Openness?
    
    /// indicates whether the description should override existing issue description
    var editDescriptionShouldOverrideº: Bool?
    
    /// indicates whether this issue entity is designated for issue editing (new issue otherwise)
    var designatedForEditing: Bool = false
}


