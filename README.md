# NPS Browser for macOS

A Swift implementation of NPS Browser.\
**Requires macOS 12 or later. Built and tested with Xcode 27 on the latest macOS (macOS 27).**

This fork is updated for current macOS. It runs natively on Apple silicon and on Intel Macs.

![](/Screenshots/main.png?raw=true)

## Features
* Localization in Simplified Chinese
* Bookmarks can be saved by clicking the star icon in the corner of the details panel
* Downloads can be started from the bookmark list
* Downloads can be stopped and resumed at any point, they can also be resumed if the app is closed during download
* Compatibility pack support for FW 3.61+
* Game updates are always the latest version
* Game artwork is displayed
* Downloads retry on network errors and wait for the network to return
* A Cancel button in the download list removes a download
* Games, updates and compatibility packs are checked with SHA256 when the list has a hash
* An animation shows the artwork flying to the Downloads button
* The search text stays when you change the console or the region

## Usage
* Change or set URLs and extraction preferences in the Preferences window
* From the menu select Database > Reload or press ⌘R
* Compatibility pack URLs must be the raw text file.

## Removal
After moving to trash, run:
```
rm -r ~/Library/Application\ Support/JK3Y.NPS-Browser/
rm -r ~/Library/Caches/JK3Y.NPS-Browser
rm -r ~/Library/Caches/NPS\ Browser
defaults delete JK3Y.NPS-Browser
```

## Compatibility
| Item | Version |
|---|---|
| macOS | 12 or later, tested on macOS 27 |
| Xcode | 26 or later, tested with Xcode 27 |
| Swift | 5 language mode, built with the Swift 6 toolchain |
| Architectures | arm64 and x86_64 (universal) |
| Dependencies | Swift Package Manager (no Carthage) |

The bundled `pkg2zip` and `vitaupdatelinks` tools are universal binaries.

## Building
Make sure you have Xcode 26 or later installed.
Open the .xcodeproj file. Xcode fetches the Swift Package Manager dependencies on its own.

Build by going to Product > Build.

Export an app bundle by going to Product > Archive > Export.

#### [Changelog][]

## Thanks
* Ann0ying for app icon
* Luro02 for the [pkg2zip][] fork
* devnoname120 for [vitanpupdatelinks][]
* L1cardo for Simplified Chinese translation

[Changelog]: https://github.com/JK3Y/NPS-Browser-macOS/blob/master/CHANGELOG.md
[pkg2zip]: https://github.com/Luro02/pkg2zip
[vitanpupdatelinks]: https://github.com/devnoname120/vitanpupdatelinks
