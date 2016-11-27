![image](https://raw.githubusercontent.com/ambientlight/GithubIssuesExtension/master/Contents/appIcon256.png)

##Github Issues Xcode Extension##

Have you even been creating github issues while coding and adding them as `//TODO:` into your source files? Now you won't need to leave xcode while doing that!

This extension adds github issues support to xcode editor.  
Capabilities: 

* Create new github issue
* Modify existing github issue
* Remove all `TODO:` blocks that are linked to github issues if issues are already closed

Commands:

* Create new issue template
* Create modify issue template
* Synchronize Issues (commits issue template to github)
* Remove closed issues

## Create New Github Issue

![image](https://raw.githubusercontent.com/ambientlight/GithubIssuesExtension/master/Contents/newIssue.gif)

Owner and repository name are automatically inferred from the source file header. Project name is treated as a repository, while the name of the the copyright holder is treated as repository owner.

``assignee`` parameter is optional.  
``Description`` can be multiline. Empty comment lines ``//`` will be treated as newlines.  
(while issue ``title`` cannot be multiline)

## Modify Existing Github Issue

![image](https://raw.githubusercontent.com/ambientlight/GithubIssuesExtension/master/Contents/modifyIssue.gif)

If shouldOverrideDescription is not specified, the new description will be appended to existing one. 

``title``, `assignee`, `status`, `shouldOverrideDescription` are optional.

## App Store

Will be available later after we play enough with this initial release

## Installation

1. Clone the repo and open ``GithubIssuesExtension.xcodeproj``
2. Enable signing for both the Application and the Xcode Editor Extension
3. Run Product -> Archive
4. Open Window -> Organizer -> Right click on generated archive -> Show in Finder
5. Right click on archive -> Show Package Contents
6. Open ``Products/Applications``
7. Drag ``GithubIssuesExtension.app`` to your Applications folder.
8. Navigate to your Github Settings (in browser). 
9. Go to `Personal access token` (which should be last in the list on the left)
10. Click on `Generate new token` (if you don't have one already)
11. __(Optionally add repo scope if you intend to use this plugin with private repos.)__
12. Generate token and copy it.
13. Open ``GithubIssuesExtension.app``. Paste the token into `GithubIssueExtension` app and hit return. 
14. Close the app.
15. Open System Preferences -> Extensions -> Xcode Source Editor and enable this extension.
16. You should now be able to access the extension under Editor -> Github Issues
17. I recommend you adding the following shortcut to this plugin commands. (Xcode -> Preferences -> Key Bindings -> search Github Issues) 

* Create New Issue Template _(control + option + command + N)_
* Create Modify Issue Template _(control + option + command + M)_
* Synchronize Issues _(control + option + command + P)_
* Remove closed issues _(control + option + command + R)_
