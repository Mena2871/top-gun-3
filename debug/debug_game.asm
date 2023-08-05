; Initially, no debug hooks are enabled
; You do not have to modify these except when adding more hooks
.define DEBUG_Game_Init 0
.define DEBUG_Game_Frame 0

; If debug.asm doesn't define DEBUG_HOOKS as 1 then none of the debug hooks
; will be compiled below.
.ifeq DEBUG_HOOKS 1

.print "debug_game.asm: Enabling debug hooks\n"

; Required hooks to debug the map manager
.ifeq DEBUG_SKYSCRAPER_MAP 1
    .print "debug_game.asm: Enabling skyscraper map debug hooks\n"
    .redefine DEBUG_Game_Init 1
.endif

; Required hooks to debug the map manager
.ifeq DEBUG_SYNTHSCRAPER_MAP 1
    .print "debug_game.asm: Enabling synthscraper map debug hooks\n"
    .redefine DEBUG_Game_Init 1
.endif

; Required hooks to debug the UI text drawing functionality
.ifeq DEBUG_UI_LOADING 1
    .print "debug_game.asm: Enabling UI debug hooks\n"
    .redefine DEBUG_Game_Init 1
    .redefine DEBUG_Game_Frame 1
.endif

; Required hooks to debug sprite loading functionality
.ifeq DEBUG_PLANE_SPRITE_LOADING 1
    .print "debug_game.asm: Enabling plane sprite debug hooks\n"
    .redefine DEBUG_Game_Init 1
    .redefine DEBUG_Game_Frame 1
.endif

; Required hooks to debug sprite loading functionality
.ifeq DEBUG_BOSS_SPRITE_LOADING 1
    .print "debug_game.asm: Enabling boss sprite debug hooks\n"
    .redefine DEBUG_Game_Init 1
    .redefine DEBUG_Game_Frame 1
.endif

.struct DebugGame
    empty db

    .ifeq DEBUG_PLANE_SPRITE_LOADING 1
    plane1_sprite_ptr dw
    plane2_sprite_ptr dw
    plane3_sprite_ptr dw
    plane4_sprite_ptr dw
    .endif

    .ifeq DEBUG_BOSS_SPRITE_LOADING 1
    boss_sprite_ptr dw
    .endif

    .ifeq DEBUG_UI_LOADING 1
    test_ui_ptr dw              ; Pointer to the requested test UI component
    dynamic_text_buffer ds 8    ; Buffer for dynamic text
    .endif
.endst

.ramsection "DebugGameRAM" appendto "RAM"
    dbg_game instanceof DebugGame
.ends

.section "DebugGameROM" bank 0 slot "ROM"

Game_Init@DebugStart:

    .ifeq DEBUG_SKYSCRAPER_MAP 1
    jsr Debug_LoadSkyscraperMap
    .endif

    .ifeq DEBUG_SYNTHSCRAPER_MAP 1
    jsr Debug_LoadSynthscraperMap
    .endif

    .ifeq DEBUG_PLANE_SPRITE_LOADING 1
    jsr Debug_TestPlaneSpriteLoadingInit
    .endif

    .ifeq DEBUG_BOSS_SPRITE_LOADING 1
    jsr Debug_TestBossSpriteLoadingInit
    .endif

    .ifeq DEBUG_UI_LOADING 1
    jsr Debug_TestClockUIInit
    .endif

    rts

Game_Init@DebugEnd:
    rts

;
; Called at the start of the main game frame loop
;
Game_Frame@DebugStart:
    rts

;
; Called at the end of the main game frame loop
;
Game_Frame@DebugEnd:
    .ifeq DEBUG_PLANE_SPRITE_LOADING 1
    jsr Debug_TestPlaneSpriteLoadingFrame
    .endif

    .ifeq DEBUG_UI_LOADING 1
    jsr Debug_TestClockUIFrame
    .endif

    rts

.ifeq DEBUG_PLANE_SPRITE_LOADING 1
Debug_TestPlaneSpriteLoadingFrame:
    phx
    phy
    pha

    A8

    ldx dbg_game.plane1_sprite_ptr.w
    inc sprite_desc.x, X

    ldx dbg_game.plane2_sprite_ptr.w
    inc sprite_desc.x, X

    ldx dbg_game.plane3_sprite_ptr.w
    inc sprite_desc.x, X

    ldx dbg_game.plane4_sprite_ptr.w
    inc sprite_desc.x, X

    A16

    ldx dbg_game.plane1_sprite_ptr.w
    jsr Sprite_MarkDirty

    ldx dbg_game.plane2_sprite_ptr.w
    jsr Sprite_MarkDirty

    ldx dbg_game.plane3_sprite_ptr.w
    jsr Sprite_MarkDirty

    ldx dbg_game.plane4_sprite_ptr.w
    jsr Sprite_MarkDirty

    pla
    ply
    plx
    rts

;
; A few test functions for exercising the sprite manager
;
Debug_TestPlaneSpriteLoadingInit:
    A16
    pha
    phx
    phy

    ; Load a demo sprite
    jsr SpriteManager_Request
    lda #Sprite_Plane@Bank
    ldx #Sprite_Plane@Data
    jsr Sprite_Load 

    ; Save pointer to the sprite
    sty dbg_game.plane1_sprite_ptr.w

    A8
    lda #50
    sta sprite_desc.x, Y

    lda #10
    sta sprite_desc.y, Y
    A16

    ; Set the tag of the sprite to the Forward animation
    lda #Sprite_Plane@Tag@Forward_Afterburner
    jsr Sprite_SetTag

    ; Set the frame of the sprite to 0
    lda #0
    jsr Sprite_SetFrame

    ; Request another sprite descriptor
    jsr SpriteManager_Request
    sty dbg_game.plane2_sprite_ptr.w

    ; Copy from X -> Y
    ldx dbg_game.plane1_sprite_ptr.w
    jsr Sprite_DeepCopy

    A8
    lda #15
    sta sprite_desc.x, Y

    lda #50
    sta sprite_desc.y, Y
    A16

    tyx
    jsr Sprite_MarkDirty

    ; Request another sprite descriptor
    jsr SpriteManager_Request
    sty dbg_game.plane3_sprite_ptr.w

    ; Copy from X -> Y
    ldx dbg_game.plane1_sprite_ptr.w
    jsr Sprite_DeepCopy

    A8
    lda #15
    sta sprite_desc.x, Y

    lda #100
    sta sprite_desc.y, Y
    A16

    tyx
    jsr Sprite_MarkDirty

    ; Request another sprite descriptor
    jsr SpriteManager_Request
    sty dbg_game.plane4_sprite_ptr.w

    ; Cache should kick in
    @CacheTest:
        lda #Sprite_Plane@Bank
        ldx #Sprite_Plane@Data
        jsr Sprite_Load 

        A8
        lda #50
        sta sprite_desc.x, Y

        lda #150
        sta sprite_desc.y, Y
        A16

        tyx
        jsr Sprite_MarkDirty

        A16

    ply
    plx
    pla

    rts
.endif ; DEBUG_PLANE_SPRITE_LOADING

.ifeq DEBUG_BOSS_SPRITE_LOADING 1
Debug_TestBossSpriteLoadingInit:
    pha
    phx
    phy

    A16
    jsr SpriteManager_Request
    lda #$7000
    sta sprite_desc.vram, Y

    A8
    lda #1
    sta sprite_desc.page, Y
    A16

    lda #Sprite_Boss@Bank
    ldx #Sprite_Boss@Data
    jsr Sprite_Load 

    ; Save pointer to the sprite
    sty dbg_game.boss_sprite_ptr.w

    A8
    lda #150
    sta sprite_desc.x, Y

    lda #10
    sta sprite_desc.y, Y
    A16

    ; Set the tag of the sprite to the Forward animation
    lda #Sprite_Boss@Tag@Idle
    jsr Sprite_SetTag

    ; Set the frame of the sprite to 0
    lda #0
    jsr Sprite_SetFrame

    A8
    lda #100
    sta sprite_desc.x, Y

    lda #75
    sta sprite_desc.y, Y

    A16
    ply
    plx
    pla
    rts
.endif ; DEBUG_BOSS_SPRITE_LOADING

.ifeq DEBUG_UI_LOADING 1
Debug_TestClockUIInit:
    pha
    phx
    phy

    ldx #dbg_game.dynamic_text_buffer
    ldy #_sizeof_DebugGame.dynamic_text_buffer
    lda #0
    jsr Memset


    ;Save pointer to font VRAM info
    lda #font_manager.fonts.1
    pha

    ; Request a FontSurface
    jsr FontManager_RequestSurface

    ; Save pointer to test ui component
    phx
    lda 3, S
    tax
    tya
    sta dbg_game.test_ui_ptr.w
    plx

    ; Store pointer to font VRAM info
    pla
    tyx
    sta font_surface.font_ptr, X

    ; Enable the font surface (this will cause it to be drawn)
    lda #1
    sta font_surface.enabled, X

    ; Provide pointer to text to draw
    lda #Text_TopGun3@Data
    sta font_surface.data_ptr, X

    lda #Tile8x8(128, 128)
    sta font_surface.tile_index, X

    ; Provide bank of text to draw
    A8
    lda #Text_TopGun3@Bank
    sta font_surface.data_bank, X

    lda #9
    sta font_surface.data_len, X

    ; Set 50ms timer to 1
    lda #1
    sta font_surface.time, X
    sta font_surface.remaining_time, X

    ; Mark surface dirty and unlock it
    lda #1
    sta font_surface.dirty, X
    stz font_surface.locked, X

    A16

    ply
    plx
    pla
    rts

Debug_TestClockUIFrame:
    pha
    phx
    phy

    ldx dbg_game.test_ui_ptr.w

    A8
    lda #1
    sta font_surface.locked, X

    ; Mark the font surface locked and convert the clock counter
    A16
    lda timer_manager.clock.s.w
    and #$00FF
    ldx game.game_clock_ptr.w
    lda timer.elapsed_ms, X
    stz timer.elapsed_ms, X
    ldx #dbg_game.dynamic_text_buffer
    jsr String_FromInt

    ; Unlock the font surface and mark it dirty
    A8
    ldx dbg_game.test_ui_ptr.w
    lda #1
    sta font_surface.dirty, X
    stz font_surface.locked, X

    A16

    ply
    plx
    pla
    rts
.endif ; DEBUG_UI_LOADING

.ifeq DEBUG_SKYSCRAPER_MAP 1
Debug_LoadSkyscraperMap:
    pha
    phx
    phy

    ; Just to make the vertical offset pretty for now
    lda #255
    sta renderer.bg_screen.1.v_offset.w

    ; Load a demo map
    lda #Map_Skyscraper@Bank
    ldy #Map_Skyscraper@Data
    jsr MapManager_Load

    ply
    plx
    pla
    rts
.endif ; DEBUG_SKYSCRAPER_MAP

.ifeq DEBUG_SYNTHSCRAPER_MAP 1
Debug_LoadSynthscraperMap:
    pha
    phx
    phy

    ; Just to make the vertical offset pretty for now
    lda #255
    sta renderer.bg_screen.1.v_offset.w
    sta renderer.bg_screen.2.v_offset.w

    ; Load a demo map
    lda #Map_Synthscraper@Bank
    ldy #Map_Synthscraper@Data
    jsr MapManager_Load

    ply
    plx
    pla
    rts
.endif ; DEBUG_SYNTHSCRAPER_MAP

.ends

.endif ; DEBUG_HOOKS