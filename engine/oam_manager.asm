;
; This module is responsible for managing the OAM object requests. It is meant
; to be used in conjunction with Sprites that need a number of OAM objects to
; represent its sprite. Sprites are expected to call OAMManager_Request() to
; be provided a pointer to an OAM object in RAM. When the Sprite is not needed
; it should call OAMManager_Release() to release the OAM object back to the
; OAMManager.
;
.section "OAMManager" BANK 0 SLOT "ROM"

.define MAX_OAM_OBJECTS 128

.struct OAMManager
    oam_objects instanceof OAMObject MAX_OAM_OBJECTS ; Represents OAM space
.endst

.enum $00
    oam_manager instanceof OAMManager
.ende

; We will also use oam_object from oam.asm
; @see oam.asm

;
; Iterate through each OAM object and set it to be unused, additionally
; set its index to its position in the array
; Expects X to be set to the address of the OAMManager
;
OAMManager_Init:
    pha
    phy
    phx

    ; Initialize the OAM space
    jsr OAM_Init

    ; Advance the pointer to the first OAM object in the struct
    txa
    adc #OAMManager.oam_objects
    tax

    clc

    ; This will be the counter for number of objects
    ldy #0

    @Loop:
        jsr OAMObject_Init      ; Initialize the current OAM object (X register points to it)
        sty oam_object.index, X ; Set the index of the object to its position in the array
        adc #_sizeof_OAMObject   ; Advance the pointer
        tax                     ; Make it the new X register
        iny                     ; Advance counter
        cpy #MAX_OAM_OBJECTS    ; Iterate until we filled out the objects
        bne @Loop 

    plx
    ply
    pla

    rts

;
; This function will return a pointer to the next free OAM object.
; And mark it allocated. If there are no free OAM objects, then
; it will return 0x0000 into Y. Otherwise it will return the address.
;
OAMManager_Request:
    pha
    phx

    ; Advance the pointer to the first OAM object in the struct
    txa
    adc #OAMManager.oam_objects
    sec
    sbc #_sizeof_OAMObject       ; Intentionally start at -1
    tax

    ; Stupidly simple, just iterate through the OAM objects and
    ; return the first one that is not allocated
    ldy #0

    @Next:
        clc
        txa
        adc #_sizeof_OAMObject   ; Advance the pointer
        tax

        ; Did we reach the end of the OAM object space?
        iny
        cpy #MAX_OAM_OBJECTS
        beq @Error

        ; Otherwise check if the object is allocated
        lda oam_object.allocated, X
        and #$00FF

        bne @Next

    ; If we got here, then we found a free object. Mark it allocated
    lda #1
    sta oam_object.allocated, X

    ; Return the address of the OAM object
    txy
    bra @Done

    ; If we got here, then we did not find a free object
    @Error:
        ldy #0

    ; Common exit point. We do not restore Y because we want to return it.
    @Done:
        plx
        pla

    rts

;
; This function will release an OAM object back to the OAMManager.
; It will mark the OAM object as not allocated.
; Expects Y to be set to the address of the OAM object to release
;
OAMManager_Release:
    pha
    phx
    phy

    A8

    ; Mark the OAM object as not allocated. stz only works with X register.
    tyx
    stz oam_object.allocated, X

    A16

    ply
    plx
    pla

    rts

;
; Render the OAM objects that are allocated
; Expects X to be set to the address of the OAMManager
;
OAMManager_VBlank:
    pha
    phx
    phy

    ; Advance the pointer to the first OAM object in the struct
    txa
    adc #OAMManager.oam_objects
    sec
    sbc #_sizeof_OAMObject       ; Intentionally start at -1
    tax

    ; Stupidly simple, just iterate through the OAM objects and
    ; render dirty ones
    ldy #0

    @Next:
        clc
        txa
        adc #_sizeof_OAMObject   ; Advance the pointer
        tax

        ; Did we reach the end of the OAM object space?
        iny
        cpy #MAX_OAM_OBJECTS
        beq @Done

        ; Otherwise check if the object is clean
        lda oam_object.clean, X
        and #$FF
        cmp #1

        ; Prepare accumulator for next iteration
        beq @Next

        ; If we got here, then we found a dirty object. Render it.
        jsr OAMObject_Write
        bra @Next

    @Done:

    ply
    plx
    pla
    rts
.ends