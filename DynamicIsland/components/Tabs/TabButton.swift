/*
 * Atoll (DynamicIsland)
 * Copyright (C) 2024-2026 Atoll Contributors
 *
 * Originally from boring.notch project
 * Modified and adapted for Atoll (DynamicIsland)
 * See NOTICE for details.
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

struct TabButton: View {
    let label: String
    let icon: String
    let selected: Bool
    let onClick: () -> Void
    
    var body: some View {
        Button(action: onClick) {
            // Runtime notch tabs must use a bounded view. `Image.cuteSymbol`
            // can resolve to 1024px raster assets; without an explicit frame
            // those natural-size images spill across the opened notch on hover
            // (giant robot/cloud art, black camera spacer pushed to the right).
            AtollCuteIcon(
                symbolName: icon,
                size: 18,
                accent: selected ? .white : .gray,
                secondary: selected ? Color(red: 0.45, green: 0.9, blue: 1.0) : .gray,
                showsPlate: false,
                animated: selected,
                weight: .semibold
            )
            .frame(width: 26, height: 26)
                .contentShape(Capsule())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    TabButton(label: "Home", icon: "tray.fill", selected: true) {
        print("Tapped")
    }
}
