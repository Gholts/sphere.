//
//  ContentView.swift
//  Sphere
//
//  Created by Gholts Li on 5/11/26.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        RootView()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        let app = PreviewFixtures.app()
        Group {
            ContentView()
            AppTabView()
                .environmentObject(app)
                .environmentObject(app.liveStore)
                .environmentObject(app.logStore)
        }
    }
}
