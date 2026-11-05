// SPDX-License-Identifier: MIT
//
// KWin scripts cannot read the keyboard, scripted effects can. While a modifier
// is held, the matching flag effect "unitedsetsx_mod_<key>" is loaded; the
// United Sets X script asks KWin over D-Bus (org.kde.kwin.Effects.isEffectLoaded)
// whether it is. The flag effects themselves do nothing.

const flags = [
    { mask: 0x02000000, name: "unitedsetsx_mod_shift" }, // Qt::ShiftModifier
    { mask: 0x04000000, name: "unitedsetsx_mod_ctrl" },  // Qt::ControlModifier
    { mask: 0x08000000, name: "unitedsetsx_mod_alt" },   // Qt::AltModifier
    { mask: 0x10000000, name: "unitedsetsx_mod_meta" },  // Qt::MetaModifier
];

let held = 0;

function update(modifiers) {
    modifiers = Number(modifiers);
    if (modifiers === held) {
        return;
    }
    for (const flag of flags) {
        const now = (modifiers & flag.mask) !== 0;
        if (now !== ((held & flag.mask) !== 0)) {
            if (now) {
                effects.loadEffect(flag.name);
            } else {
                effects.unloadEffect(flag.name);
            }
        }
    }
    held = modifiers;
}

effects.mouseChanged.connect((pos, oldPos, buttons, oldButtons, modifiers, oldModifiers) => update(modifiers));
