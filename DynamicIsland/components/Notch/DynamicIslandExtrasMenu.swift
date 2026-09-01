/*
 * Atoll (DynamicIsland)
 * Copyright (C) 2024-2026 Atoll Contributors
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program. If not, see <https://www.gnu.org/licenses/>.
 */

import SwiftUI

struct DynamicIslandLargeButtons<Icon: View>: View {
    var action: () -> Void
    var icon: Icon
    var title: String
    var body: some View {
        Button (
            action:action,
            label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 12.0).fill(.black).frame(width: 70, height: 70)
                    VStack(spacing: 8) {
                        icon.frame(width: 22, height: 22)
                        Text(title).font(.body)
                    }
                }
            }).buttonStyle(PlainButtonStyle()).shadow(color: .black.opacity(0.5), radius: 10)
    }
}

struct DynamicIslandExtrasMenu : View {
    @ObservedObject var vm: DynamicIslandViewModel
    
    var body: some View {
        VStack{
            HStack(spacing: 20)  {
                hide
                settings
                close
            }
        }
    }
    
    var github: some View {
        DynamicIslandLargeButtons(
            action: {
                NSWorkspace.shared.open(productPage)
            },
            icon: Image(.github)
                .resizable()
                .aspectRatio(contentMode: .fit),
            title: "Checkout"
        )
    }
    
    var donate: some View {
        DynamicIslandLargeButtons(
            action: {
                NSWorkspace.shared.open(sponsorPage)
            },
            icon: AtollCuteIcon(
                symbolName: "heart.fill",
                size: 22,
                accent: .pink,
                showsPlate: false
            ),
            title: "Love Us"
        )
    }
    
    var settings: some View {
        Button(action: {
            SettingsWindowController.shared.showWindow()
        }) {
            ZStack {
                RoundedRectangle(cornerRadius: 12.0).fill(.black).frame(width: 70, height: 70)
                VStack(spacing: 8) {
                    AtollCuteIcon(
                        symbolName: "gear",
                        size: 22,
                        accent: .white,
                        showsPlate: false
                    )
                    Text("Settings").font(.body)
                }
            }
        }
        .buttonStyle(PlainButtonStyle()).shadow(color: .black.opacity(0.5), radius: 10)
    }
    
    var hide: some View {
        DynamicIslandLargeButtons(
            action: {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    //vm.openMusic()
                }
            },
            icon: AtollCuteIcon(
                symbolName: "arrow.down.forward.and.arrow.up.backward",
                size: 22,
                accent: .white,
                showsPlate: false
            ),
            title: "Hide"
        )
    }
    
    var close: some View {
        DynamicIslandLargeButtons(
            action: {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        NSApp.terminate(nil)
                    }
                }
            },
            icon: AtollCuteIcon(
                symbolName: "xmark",
                size: 22,
                accent: .red,
                showsPlate: false
            ),
            title: "Exit"
        )
    }
}


#Preview {
    DynamicIslandExtrasMenu(vm: DynamicIslandViewModel())
}
