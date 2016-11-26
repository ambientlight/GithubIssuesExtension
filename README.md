##Github Issues Xcode Extension##

Have you even been creating github isses while coding and adding them as `//TODO:` into your source files? Now you won't need to leave xcode while doing that!

This extension adds github issues support to xcode editor.  
Capabilities: 

* Create new github issue
* Modify existing github issue
* Remove all `TODO:` blocks that are linked to github issues if the issues are closed

Commands:

* Create new issue template
* Create modify issue template
* Synchronize Issues (commits issue template to github)
* Remove closed issues

## Installation

1. Close the repo and open ``GithubIssuesExtension.xcodeproj``
2. Enable signing for both the Application and the Xcode Editor Extension
3. Run Product -> Archive
4. Open Window -> Organizer -> Right click on generated archive -> Show in Finder
5. Right click on archive -> Show Package Contents
6. Open ``Products/Applications``
7. Drag ``GithubIssuesExtension.app`` to your Applications folder.
8. Navigate to your Github Settings (in browser). 
9. Go to `Personal access token` (which should be last in the list on the left)
10. Click on `Generate new token` (if you don't have one already)
11. (Optionally add repo scope if you intend to use this plugin with private repos.)
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