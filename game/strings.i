.macro definetext args _bank, _short, _text
    .define Text_{_short}@Bank _bank
    Text_{_short}@Data: .ascstr _text, $0
.endm

.section "Strings" bank 1 slot "ROM"

definetext(1, "TopGun3", "Top Gun 3: The Final Mission")
definetext(1, "Character1", "Maverick")
definetext(1, "Character2", "Sky Shadow")
definetext(1, "CallSign", "Call Sign")
definetext(1, "Health", "Health")
definetext(1, "Bombs", "Bombs")

.ends