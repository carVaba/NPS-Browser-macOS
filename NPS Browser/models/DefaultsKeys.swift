//
//  DefaultsKeys.swift
//  NPS Browser
//
//  Created by JK3Y on 8/17/18.
//  Copyright © 2018 JK3Y. All rights reserved.
//
import Foundation

struct DefaultsKey<Value> {
    let _key: String
    let defaultValue: Value

    init(_ key: String, defaultValue: Value) {
        self._key = key
        self.defaultValue = defaultValue
    }
}

// Thin UserDefaults wrapper that keeps the old SwiftyUserDefaults call sites unchanged.
enum Defaults {
    private static var store: UserDefaults { .standard }

    static subscript(key: DefaultsKey<URL?>) -> URL? {
        get {
            if let url = store.url(forKey: key._key) {
                return url
            }
            // SwiftyUserDefaults 4 stored URLs as keyed archives.
            if let data = store.data(forKey: key._key),
               let url = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSURL.self, from: data) {
                return url as URL
            }
            return key.defaultValue
        }
        set { store.set(newValue, forKey: key._key) }
    }

    static subscript(key: DefaultsKey<Bool>) -> Bool {
        get { store.object(forKey: key._key) as? Bool ?? key.defaultValue }
        set { store.set(newValue, forKey: key._key) }
    }

    static subscript(key: DefaultsKey<Int>) -> Int {
        get { store.object(forKey: key._key) as? Int ?? key.defaultValue }
        set { store.set(newValue, forKey: key._key) }
    }

    static func set(_ value: URL?, forKey key: String) {
        store.set(value, forKey: key)
    }

    static func removeAll() {
        guard let domain = Bundle.main.bundleIdentifier else { return }
        store.removePersistentDomain(forName: domain)
    }
}

private let homeURL = URL(fileURLWithPath: NSHomeDirectory())

extension DefaultsKey where Value == URL? {
    static var sourcePSVGames: Self   { .init("src_psv_games", defaultValue: URL(string: "http://nopaystation.com/tsv/PSV_GAMES.tsv")) }
    static var sourcePSVDLCs: Self    { .init("src_psv_dlcs", defaultValue: URL(string: "http://nopaystation.com/tsv/PSV_DLCS.tsv")) }
    static var sourcePSVThemes: Self  { .init("src_psv_themes", defaultValue: URL(string: "http://nopaystation.com/tsv/PSV_THEMES.tsv")) }
    static var sourcePSPGames: Self   { .init("src_psp_games", defaultValue: URL(string: "http://nopaystation.com/tsv/PSP_GAMES.tsv")) }
    static var sourcePSXGames: Self   { .init("src_psx_games", defaultValue: URL(string: "http://nopaystation.com/tsv/PSX_GAMES.tsv")) }
    static var sourcePS3Games: Self   { .init("src_ps3_games", defaultValue: URL(string: "http://nopaystation.com/tsv/PS3_GAMES.tsv")) }
    static var sourcePS3DLCs: Self    { .init("src_ps3_dlcs", defaultValue: URL(string: "http://nopaystation.com/tsv/PS3_DLCS.tsv")) }
    static var sourcePS3Themes: Self  { .init("src_ps3_themes", defaultValue: URL(string: "http://nopaystation.com/tsv/PS3_THEMES.tsv")) }
    static var sourcePS3Avatars: Self { .init("src_ps3_avatars", defaultValue: URL(string: "http://nopaystation.com/tsv/PS3_AVATARS.tsv")) }
    static var sourceCompatPacks: Self { .init("src_compatPacks", defaultValue: URL(string: "https://gitlab.com/nopaystation_repos/nps_compati_packs/raw/master/entries.txt")) }
    static var sourceCompatPatch: Self { .init("src_compatPatch", defaultValue: URL(string: "https://gitlab.com/nopaystation_repos/nps_compati_packs/raw/master/entries_patch.txt")) }

    static var libraryLocation: Self { .init("dl_library_location", defaultValue: homeURL.appendingPathComponent("Downloads")) }
    static var libraryFolder: Self {
        .init("dl_library_folder", defaultValue: homeURL.appendingPathComponent("Downloads").appendingPathComponent("NPS Downloads", isDirectory: true))
    }
}

extension DefaultsKey where Value == Int {
    static var concurrentDownloads: Self { .init("dl_concurrent_downloads", defaultValue: 3) }
    static var compressionFactor: Self   { .init("xt_compression_factor", defaultValue: 1) }
}

extension DefaultsKey where Value == Bool {
    static var extractsAfterDownloading: Self { .init("xt_extract_after_downloading", defaultValue: true) }
    static var keepsPackage: Self                  { .init("xt_keep_pkg", defaultValue: false) }
    static var savesAsZip: Self               { .init("xt_save_as_zip", defaultValue: false) }
    static var createsLicense: Self            { .init("xt_create_license", defaultValue: true) }
    static var compressesPSPISO: Self          { .init("xt_compress_psp_iso", defaultValue: false) }
    static var unpacksPS3Packages: Self       { .init("xt_unpack_ps3_packages", defaultValue: false) }
    static var hidesInvalidURLItems: Self   { .init("dsp_hide_invalid_url_items", defaultValue: true) }
}
