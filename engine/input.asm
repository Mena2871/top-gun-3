.include "engine/drivers/input/interface.asm"

.ACCU   16
.INDEX  16

.define MAX_INPUTS 2

.struct InputState
    index  db
    allocated db
    rbtn   db
    lbtn   db
    xbtn   db
    abtn   db
    rhtbtn db
    lftbtn db   
    dnbtn  db
    upbtn  db
    start  db
    select db
    ybtn   db
    bbtn   db
.endst

.enum $00
    inputstate instanceof InputState
.ende

.struct InputManager
    input_objects instanceof InputState MAX_INPUTS

    input_queue instanceof Queue
    input_queue_memory  ds (2 * MAX_INPUTS)

.endst

.ramsection "InputRAM" appendto "RAM"
    input_manager instanceof InputManager
.ends

.section "Input" BANK 0 SLOT "ROM"

nop

Input_Init:
    A8
    stz inputstate.bbtn, X
    stz inputstate.ybtn, X
    stz inputstate.select, X
    stz inputstate.start, X
    stz inputstate.upbtn, X
    stz inputstate.dnbtn, X
    stz inputstate.lftbtn, X
    stz inputstate.rhtbtn, X
    stz inputstate.abtn, X
    stz inputstate.xbtn, X
    stz inputstate.lbtn, X
    stz inputstate.rbtn, X
    stz inputstate.index, X
    A16
    rts

Input_Frame:
    rts

Input_VBlank:
    pha

    ; Wait until the HVBJOY shows that the controllers are ready to be read
    @WaitForJoyReady:
        lda HVBJOY
        and #1
        bne @WaitForJoyReady

    ; Advance the pointer to the first joypad input object in the struct
    clc
    lda #input_manager.input_objects
    tax
    pha
    lda #JOY1L
    pha
    ldy #0
        @Loop:
            pla
            jsr Input_Buttons
            adc #2
            pha
            lda 3, s
            clc
            adc #_sizeof_InputState 
            sta 3, s
            tax 
            iny                     
            cpy #MAX_INPUTS    
            bne @Loop
    pla
    pla
    pla
    rts

Input_Buttons:
    pha
    phy

    phx
    tax
    lda $00, x
    plx

    ; Skip controller id
    lsr A
    lsr A
    lsr A
    lsr A

    ldy #12
    pha
    txa
    adc #inputstate
    tax
    pla
    clc
    inx
    inx
    @Loop:
        stz inputstate, X ; 5 cycles
        lsr A                   ; 2 cycles
        rol inputstate, X ; 7 cycles
        inx
        dey
        bne @Loop

    bra @Done

    @Done:
        A16
        ply
        pla
        rts

InputManager_Init:
    pha
    phy
    phx

    ; Initialize the queue
    lda #input_manager.input_queue_memory       ; Set the base address of the queue 
    sta input_manager.input_queue.start_addr.w 

    ; Calculate the end address of the queue
    clc
    adc #(MAX_INPUTS * 2)
    sta input_manager.input_queue.end_addr.w 

    ; Set the element size to 1 bytes
    lda #1
    sta input_manager.input_queue.element_size.w 

    ; Initialize the queue
    ldx #input_manager.input_queue               ; Set the Queue "this" pointer
    jsr Queue_Init

    ; Advance the pointer to the first Input object in the struct
    clc
    lda #input_manager.input_objects
    tax

    ; This will be the counter for number of objects
    ldy #0

    @Loop:
        jsr Input_Init 
        sty inputstate.index, X
        clc
        adc #_sizeof_InputState 
        tax 
        iny                     
        cpy #MAX_INPUTS    
        bne @Loop 

    plx
    ply
    pla
    rts

InputManager_Request:
    pha
    phx

    ; Advance the pointer to the first OAM object in the struct
    clc
    lda #input_manager.input_objects
    sec
    sbc #_sizeof_InputState       ; Intentionally start at -1
    tax

    ldy #0

    @Next:
        clc
        txa
        adc #_sizeof_InputState   ; Advance the pointer
        tax

        ; Did we reach the end of the INPUT object space?
        iny
        cpy #MAX_INPUTS
        beq @Error

        ; Otherwise check if the object is allocated
        lda inputstate.allocated, X
        and #$00FF

        bne @Next

    ; If we got here, then we found a free object. Mark it allocated
    lda #1
    sta inputstate.allocated, X

    ; Return the address of the INPUT object
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
.ends