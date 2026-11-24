import SwiftUI

/// Info panel of the bag (ART_BIBLE §14.2): icon, name, count, description, effect chip, and the
/// Use / Put in quick slot / Drop 1 / Drop all buttons (all ≥ 64 pt high). With nothing selected it
/// shows Pixel and "Tap a thing".
struct ItemInfoPanel: View {
    @Environment(GameModel.self) private var model
    let slot: Int?
    @Binding var assigning: Bool
    var onDropped: (Int) -> Void = { _ in }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14).fill(HUDColors.dim.opacity(0.85))
            RoundedRectangle(cornerRadius: 14).stroke(HUDColors.line, lineWidth: 2)
            if let slot, model.bag.slots.indices.contains(slot), let stack = model.bag.slots[slot],
               let item = model.data.items[stack.itemId] {
                details(slot, stack, item)
            } else {
                VStack(spacing: 14) {
                    Image(uiImage: AtlasImageCache.image("pixel_idle_01", atlas: "pixel"))
                        .resizable().aspectRatio(contentMode: .fit)
                        .frame(width: 72, height: 72)
                        .accessibilityHidden(true)
                    Text("inventory.pickHint")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundStyle(HUDColors.desc)
                }
            }
        }
    }

    private func details(_ slot: Int, _ stack: ItemStack, _ item: ItemDef) -> some View {
        let hpFull = model.hud.hp >= model.hud.maxHp && model.hud.maxHp > 0
        let usable = item.usable && item.category != .puzzle
        let refused = (item.category == .heal || item.category == .food) && hpFull
        return VStack(spacing: 4) {
            ZStack {
                Circle().fill(HUDColors.panel)
                Circle().stroke(HUDColors.line, lineWidth: 2)
                AtlasImage("pickup_\(item.id)", atlas: "items").frame(width: 44, height: 44)
            }
            .frame(width: 56, height: 56)
            Text(LocalizedStringKey(item.nameKey))
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(String(format: String(localized: "inventory.count"), stack.count))
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundStyle(HUDColors.cyanLight)
            Text(LocalizedStringKey(item.category == .puzzle ? "inventory.puzzleHint" : item.descKey))
                .font(.system(size: 14, design: .rounded))
                .foregroundStyle(HUDColors.desc)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
                .multilineTextAlignment(.center)
                .frame(height: 36)
            if assigning {
                Text("inventory.assignPrompt")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(HUDColors.star)
                    .frame(height: 22)
            } else {
                effectChip(item).frame(height: 22)
            }
            Spacer(minLength: 0)
            HStack(spacing: 12) {
                if usable {
                    action("inventory.use", id: "inventory.use", fill: HUDColors.heal, enabled: !refused) {
                        model.send(.useItem(slot: slot))
                    }
                }
                action(assigning ? "inventory.cancel" : "inventory.assign", id: "inventory.assign", fill: HUDColors.blue,
                       enabled: true) { assigning.toggle() }
            }
            HStack(spacing: 12) {
                action(stack.count > 1 ? "inventory.dropOne" : "inventory.drop", id: "inventory.drop", fill: HUDColors.accent, enabled: item.droppable) {
                    model.send(.dropItem(slot: slot, count: 1))
                    onDropped(slot)
                }
                if stack.count > 1 {
                    action("inventory.dropAll", id: "inventory.dropAll", fill: HUDColors.accent, enabled: item.droppable) {
                        model.send(.dropItem(slot: slot, count: stack.count))
                        onDropped(slot)
                    }
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private func effectChip(_ item: ItemDef) -> some View {
        if let heal = item.healAmount, heal > 0 {
            chip(icon: "ui_icon_heart", text: "+\(heal)")
        } else if let ammo = item.ammoAmount, ammo > 0 {
            chip(icon: "ui_icon_ammo", text: "+\(ammo)")
        } else {
            Color.clear
        }
    }

    private func chip(icon: String, text: String) -> some View {
        HStack(spacing: 6) {
            AtlasImage(icon).frame(width: 18, height: 18)
            Text(verbatim: text).font(.system(size: 14, weight: .bold, design: .rounded)).foregroundStyle(.white)
        }
        .padding(.horizontal, 12)
        .frame(height: 24)
        .background(Capsule().fill(HUDColors.heal.opacity(0.25)))
        .overlay(Capsule().stroke(HUDColors.heal, lineWidth: 1.5))
    }

    private func action(_ title: LocalizedStringKey, id: String, fill: Color, enabled: Bool,
                        _ run: @escaping () -> Void) -> some View {
        Button {
            AudioManager.shared.play(.uiTap)
            run()
        } label: {
            Text(title)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .padding(.horizontal, 6)
                .frame(width: 110, height: 64)
                .background(RoundedRectangle(cornerRadius: 20).fill(fill))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(HUDColors.outline, lineWidth: 2))
        }
        .buttonStyle(HUDButtonStyle())
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.4)
        .accessibilityIdentifier(id)
    }
}
