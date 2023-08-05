.struct Character_2
    id         db ; Character ID
    character_attr instanceof Character_Attr
    sprite_ptr dw ; Sprite pointer
    name_ptr dw ; Name pointer
.endst

.enum $0000
    character_2 instanceof Character_2
.ende

.section "Character_2" BANK 0 SLOT "ROM"
nop

Character_2_Init:
    phx
    phy

    A8
    lda #2
    sta character_2.id, X

    lda #100
    sta character_2.character_attr.health, X

    lda #100
    sta character_2.character_attr.max_health, X

    lda #1
    sta character_2.character_attr.speed, X

    lda #2
    sta character_1.character_attr.turbo_multi, X
    A16

    ; Load a sprite
    phx
    jsr SpriteManager_Request
    lda #Sprite_Plane@Bank
    ldx #Sprite_Plane@Data
    jsr Sprite_Load 
    plx

    ; Save pointer to the sprite
    sty character_2.sprite_ptr.w, X

    A8
    lda #50
    sta sprite_desc.x, Y

    lda #100
    sta sprite_desc.y, Y
    A16

    ; Set the tag of the sprite to the Forward animation
    lda #Sprite_Plane@Tag@Forward
    jsr Sprite_SetTag

    ; Set the frame of the sprite to 0
    lda #0
    jsr Sprite_SetFrame

    phx
    tyx
    jsr Sprite_MarkDirty
    plx

    ; Load name sprite
    @LoadNames:
        phx
        jsr SpriteManager_Request

        lda #$7E00
        sta sprite_desc.vram, Y

        A8
        lda #1
        sta sprite_desc.page, Y
        A16

        lda #Sprite_Names@Bank
        ldx #Sprite_Names@Data
        jsr Sprite_Load 
        plx

        ; Save pointer to the sprite
        sty character_2.name_ptr.w, X

        A8
        lda #70
        sta sprite_desc.x, Y

        lda #124
        sta sprite_desc.y, Y
        A16

        tyx

        ; Set the tag of the sprite to the Forward animation
        lda #Sprite_Names@Tag@Ice
        jsr Sprite_SetTag

        ; Set the frame of the sprite to 0
        lda #0
        jsr Sprite_SetFrame
        jsr Sprite_MarkDirty

    ply
    plx
    rts

.ends