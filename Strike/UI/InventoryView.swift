import SwiftUI

/// The bag (GDD §7, ART_BIBLE §7 / §14.2): a modal over the dimmed, frozen level. Quick-slot
/// column (drop targets), 5 × 5 grid of 64 pt slots, info panel, Close and Tidy. Tap flow: tap an
/// item → Use / Drop / Put in quick slot → tap Q1–Q4. Items can also be dragged onto a quick slot.
struct InventoryView: View {
    @Environment(GameModel.self) private var model
    @State private var selected: Int?
    @State private var assigning = false

    enum Layout {
        static let panel = CGSize(width: 900, height: 500)
        static let slot: CGFloat = 64
        static let gap: CGFloat = 8
        static let quick: CGFloat = 72
        static let quickGap: CGFloat = 12
        static let info = CGSize(width: 260, height: 352)
        static let columns = 5
    }

    var body: some View {
        let bag = model.bag
        ZStack {
            HUDColors.dim.opacity(0.7)
                .ignoresSafeArea()
                .onTapGesture { close() }
            VStack(alignment: .leading, spacing: 20) {
                Text("inventory.title")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .accessibilityAddTraits(.isHeader)
                HStack(alignment: .top, spacing: 24) {
                    quickColumn(bag)
                    grid(bag)
                    ItemInfoPanel(slot: selected, assigning: $assigning, onDropped: { if bag.slots.indices.contains($0), bag.slots[$0] == nil { selected = nil } })
                        .frame(width: Layout.info.width, height: Layout.info.height)
                    buttonColumn
                }
                footer(bag)
            }
            .padding(24)
            .frame(width: Layout.panel.width, height: Layout.panel.height, alignment: .topLeading)
            .background(RoundedRectangle(cornerRadius: 20).fill(HUDColors.panel.opacity(0.95))
                .shadow(color: HUDColors.outline.opacity(0.3), radius: 12))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(HUDColors.line, lineWidth: 3))
            .scaleEffect(scaleToFit)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("inventory.view")
        .onChange(of: model.bag) { _, bag in
            if let s = selected, !(bag.slots.indices.contains(s) && bag.slots[s] != nil) { selected = nil; assigning = false }
        }
    }

    /// ART_BIBLE §14.2: 900 wide at 1194, scaled down on smaller screens.
    private var scaleToFit: CGFloat {
        let w = UIScreen.main.bounds.width
        return min(1, max(0.7, (w - 40) / Layout.panel.width))
    }

    private func close() {
        AudioManager.shared.play(.uiBack)
        assigning = false
        model.closeInventory()
    }

    // MARK: Quick slots (drop targets)

    private func quickColumn(_ bag: Inventory) -> some View {
        VStack(spacing: Layout.quickGap) {
            ForEach(0..<bag.quickCount, id: \.self) { q in
                let id = bag.quickItem(q)
                Button {
                    guard assigning, let s = selected, let item = bag.slots[s]?.itemId else { return }
                    AudioManager.shared.play(.uiTap)
                    model.send(.assignQuick(itemId: item, slot: q))
                    assigning = false
                } label: {
                    ZStack(alignment: .topLeading) {
                        AtlasImage(assigning ? "ui_quickslot_sel" : "ui_quickslot")
                            .frame(width: Layout.quick, height: Layout.quick)
                        if let id {
                            AtlasImage("pickup_\(id)", atlas: "items")
                                .frame(width: 44, height: 44)
                                .frame(width: Layout.quick, height: Layout.quick)
                                .opacity(bag.count(of: id) == 0 ? 0.35 : 1)
                        }
                        Text(verbatim: "\(q + 1)")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(HUDColors.dash)
                            .padding(6)
                    }
                    .frame(width: Layout.quick, height: Layout.quick)
                    .scaleEffect(assigning ? 1.08 : 1)
                    .animation(.easeOut(duration: 0.15), value: assigning)
                }
                .buttonStyle(QuickSlotButtonStyle())
                .dropDestination(for: String.self) { ids, _ in
                    guard let item = ids.first, bag.canStore(item) else { return false }
                    model.send(.assignQuick(itemId: item, slot: q))
                    assigning = false
                    return true
                }
                .accessibilityIdentifier("inventory.quick.\(q)")
                .accessibilityLabel(Text(verbatim: id.flatMap { model.data.items[$0] }
                    .map { String(format: String(localized: "hud.quickSlot.accessibility"), q + 1,
                                  String(localized: String.LocalizationValue($0.nameKey)), bag.count(of: $0.id)) }
                    ?? String(format: String(localized: "hud.quickSlot.empty.accessibility"), q + 1)))
            }
        }
    }

    // MARK: Grid

    private func grid(_ bag: Inventory) -> some View {
        let cols = Array(repeating: GridItem(.fixed(Layout.slot), spacing: Layout.gap), count: Layout.columns)
        return LazyVGrid(columns: cols, spacing: Layout.gap) {
            ForEach(0..<bag.slotCount, id: \.self) { i in
                gridSlot(i, bag)
            }
        }
        .frame(width: Layout.slot * 5 + Layout.gap * 4)
    }

    private func gridSlot(_ i: Int, _ bag: Inventory) -> some View {
        let stack = bag.slots[i]
        let isSel = selected == i
        let quickIndex = stack.flatMap { s in bag.quick.firstIndex(of: s.itemId) }
        let name = stack.flatMap { model.data.items[$0.itemId] }.map { String(localized: String.LocalizationValue($0.nameKey)) }
        return Button {
            AudioManager.shared.play(.uiTap)
            assigning = false
            selected = stack == nil ? nil : (isSel ? nil : i)
        } label: {
            ZStack {
                AtlasImage(isSel ? "ui_invslot_sel" : "ui_invslot")
                    .frame(width: Layout.slot, height: Layout.slot)
                if let stack {
                    AtlasImage("pickup_\(stack.itemId)", atlas: "items")
                        .frame(width: 44, height: 44)
                        .scaleEffect(isSel ? 1.1 : 1)
                    if stack.count > 1 {
                        CountBadge(count: stack.count, size: 20, font: 13)
                            .offset(x: Layout.slot / 2 - 12, y: Layout.slot / 2 - 12)
                    }
                    if let q = quickIndex {
                        Text(verbatim: "\(q + 1)")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .frame(width: 18, height: 18)
                            .background(Circle().fill(HUDColors.cyan))
                            .overlay(Circle().stroke(HUDColors.outline, lineWidth: 2))
                            .offset(x: -Layout.slot / 2 + 11, y: -Layout.slot / 2 + 11)
                    }
                }
            }
            .frame(width: Layout.slot, height: Layout.slot)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .draggable(stack?.itemId ?? "") {
            if let id = stack?.itemId {
                AtlasImage("pickup_\(id)", atlas: "items").frame(width: 56, height: 56)
            }
        }
        .accessibilityIdentifier("inventory.slot.\(i)")
        .accessibilityLabel(Text(verbatim: name.map { String(format: String(localized: "inventory.slot.accessibility"), $0, stack?.count ?? 0) }
            ?? String(localized: "inventory.emptySlot.accessibility")))
        .accessibilityValue(Text(verbatim: stack.map { "\($0.itemId) \($0.count)" } ?? ""))
    }

    // MARK: Buttons, footer

    private var buttonColumn: some View {
        VStack(spacing: 12) {
            Button { close() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 26, weight: .heavy))
                    .foregroundStyle(HUDColors.outline)
                    .frame(width: 64, height: 64)
                    .background(Circle().fill(HUDColors.star))
                    .overlay(Circle().stroke(HUDColors.outline, lineWidth: 2))
            }
            .buttonStyle(HUDButtonStyle())
            .accessibilityIdentifier("inventory.close")
            .accessibilityLabel(Text("inventory.close"))
            Button {
                AudioManager.shared.play(.uiTap)
                selected = nil
                assigning = false
                model.send(.tidy)
            } label: {
                Image(systemName: "line.3.horizontal.decrease")
                    .font(.system(size: 26, weight: .heavy))
                    .foregroundStyle(.white)
                    .frame(width: 64, height: 64)
                    .background(Circle().fill(HUDColors.blue))
                    .overlay(Circle().stroke(HUDColors.outline, lineWidth: 2))
            }
            .buttonStyle(HUDButtonStyle())
            .accessibilityIdentifier("inventory.tidy")
            .accessibilityLabel(Text("inventory.tidy"))
        }
        .frame(width: 100)
    }

    private func footer(_ bag: Inventory) -> some View {
        let full = bag.freeSlots <= 1
        return HStack(spacing: 8) {
            if bag.freeSlots == 0 { BangBadge(size: 22) }
            Text(verbatim: "\(bag.usedSlots) / \(bag.slotCount)")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(full ? HUDColors.star : .white)
                .accessibilityIdentifier("inventory.capacity")
            if bag.isEmpty {
                Text("inventory.empty")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(HUDColors.desc)
            }
        }
    }
}

/// Yellow "!" badge (ART_BIBLE §14.3): bag full.
struct BangBadge: View {
    let size: CGFloat

    var body: some View {
        Text(verbatim: "!")
            .font(.system(size: size * 0.67, weight: .heavy, design: .rounded))
            .foregroundStyle(HUDColors.outline)
            .frame(width: size, height: size)
            .background(Circle().fill(HUDColors.star))
            .overlay(Circle().stroke(HUDColors.outline, lineWidth: 2))
            .accessibilityHidden(true)
    }
}
