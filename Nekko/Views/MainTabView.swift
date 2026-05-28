//
//  MainTabView.swift
//  Nekko
//
//  Created by 湯川昇平 on 2026/02/28.
//

import SwiftData
import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            Tab("通訳", systemImage: "message.and.waveform.fill") {
                InterpreterView()
            }

            Tab("記録", systemImage: "doc.text.fill") {
                RecordsListView()
            }

            Tab("設定", systemImage: "gearshape.fill") {
                SettingsView()
            }
        }
        .tint(.blue)
    }
}

#Preview {
    MainTabView()
        .modelContainer(for: Recording.self, inMemory: true)
}
