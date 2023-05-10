.macro definetext args _bank, _short, _text
    .define Text_{_short}@Bank _bank
    Text_{_short}@Data: .ascstr _text, $0
.endm

.section "Strings" bank 1 slot "ROM"

definetext(1, "TopGun3", "Test Text")

.ends