//
//  SphereApp.swift
//  Sphere
//
//  Created by Gholts Li on 5/11/26.
//

import SwiftUI

@main
struct SphereApp: App {
    init() {
        SettingsBundleDefaults.write()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

private enum SettingsBundleDefaults {
    static func write(defaults: UserDefaults = .standard, bundle: Bundle = .main) {
        let version = bundle.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        defaults.set("LAN controller access", forKey: "sphere.settings.localNetworkUse")
        defaults.set(version, forKey: "sphere.settings.version")
        defaults.set("CC BY 4.0", forKey: "sphere.settings.iconLicense")
        defaults.set("Icon illustration by Figma Community author @brixtemplates", forKey: "sphere.settings.iconAttribution")
        defaults.set("MIT License", forKey: "sphere.settings.zashboardLicense")
        defaults.set("Zashboard API", forKey: "sphere.settings.zashboardProject")
    }
}
