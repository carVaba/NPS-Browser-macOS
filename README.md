# NPS Browser for macOS

**Install:** download the `.dmg` from the [Releases][releases] page, then follow [Install](#install).

This is a **fork** of [NPS Browser for macOS][upstream] by JK3Y. The original project is archived.
All credit for the original app goes to JK3Y and the contributors. See [Thanks](#thanks).

**Requires macOS 12 or later.** Runs natively on Apple silicon and on Intel Macs.

![](/Screenshots/main.png?raw=true)

## What works now

Tested by hand on macOS 27:

| Area | Status |
|---|---|
| Browse the PSV games list and sort it | Works |
| Game details and artwork | Works |
| Download a game, then extract it with pkg2zip | Works |
| Download speed and time left in the download list | Works |
| Finished downloads show a green bar, a click opens the folder | Works |
| A game with only a compatibility patch (no pack) | Works |
| The same file twice: a second copy is blocked while the first runs | Works |
| A finished file gets a suffix: `name 2.pkg` | Works |
| Long names are cut in the middle, like Safari | Works |

Built and running, but **not tested by hand after the rewrite**:

1. Search, and the PSP, PSX and PS3 lists
2. Bookmarks (add, remove, download from the list)
3. Preferences (library folder, source URLs, extraction options)
4. PS3 RAP downloads, and PSP and PSX extraction
5. Pause and resume, resume after an app restart, network loss

Known problem:

* Some names show `â¢` instead of `™`. The list text is decoded with the wrong encoding.

## Install

This app is **not notarized**. macOS blocks the first start. Follow these steps once.

1. Open the `.dmg` and drag `NPS Browser` to `Applications`.
2. Open `NPS Browser`. macOS shows a warning. Click **Done**.
3. Open **System Settings > Privacy & Security**.
4. Scroll down and click **Open Anyway** for `NPS Browser`.

Terminal alternative:

```
xattr -dr com.apple.quarantine "/Applications/NPS Browser.app"
```

## Features
* Localization in Simplified Chinese
* Bookmarks can be saved by clicking the star icon in the corner of the details panel
* Downloads can be started from the bookmark list
* Downloads can be stopped and resumed at any point, and resumed after the app closes
* Compatibility pack support for FW 3.61+
* Game updates are always the latest version
* Game artwork is displayed
* Downloads retry on network errors and wait for the network to return
* Games, updates and compatibility packs are checked with SHA256 when the list has a hash
* A Cancel button in the download list removes a download
* An animation shows the artwork flying to the Downloads button
* The search text stays when you change the console or the region

## Usage
1. Open **Preferences** and set the source URLs and the extraction options.
2. Select **Database > Reload** or press ⌘R to load the lists.
3. Select a game and click **Download**.

Compatibility pack URLs must point to the raw text file.

## How this fork was made

This fork was updated with **Claude**, an AI assistant from Anthropic.
The maintainer ([carVaba][fork]) supervised all the work.

* Claude wrote the code changes.
* The maintainer set the goals, reviewed the changes, and tested the app by hand.

What changed from the original:

* New toolchain: Swift Package Manager instead of Carthage, Xcode 27, macOS 12 as the minimum
* The storyboard is gone. The whole UI is AppKit code.
* Alamofire and the Promises library are gone. Networking uses `URLSession` with `async/await`.
* Table views use `NSTableViewDiffableDataSource`.
* The list screen has a view model. Services use protocols and dependency injection.
* The force unwraps (`!`, `as!`, `try!`) are removed.

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
1. Install Xcode 26 or later.
2. Open `NPS Browser.xcodeproj`. Xcode fetches the packages on its own.
3. Select **Product > Build**.

To make an app bundle, select **Product > Archive > Distribute App**.

#### [Changelog][changelog]

## Thanks
* **JK3Y** for the [original NPS Browser for macOS][upstream]
* Ann0ying for the app icon
* Luro02 for the [pkg2zip][] fork
* devnoname120 for [vitanpupdatelinks][]
* L1cardo for the Simplified Chinese translation

## License
Public domain. See [LICENSE.md](LICENSE.md).

[upstream]: https://github.com/JK3Y/NPS-Browser-macOS
[fork]: https://github.com/carVaba/NPS-Browser-macOS
[releases]: https://github.com/carVaba/NPS-Browser-macOS/releases
[changelog]: https://github.com/carVaba/NPS-Browser-macOS/blob/master/CHANGELOG.md
[pkg2zip]: https://github.com/Luro02/pkg2zip
[vitanpupdatelinks]: https://github.com/devnoname120/vitanpupdatelinks
