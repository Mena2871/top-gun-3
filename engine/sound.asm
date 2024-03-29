.16bit
.ACCU  16
.INDEX 16

.define SCMD_NONE               $00
.define SCMD_INITIALIZE         $01
.define SCMD_LOAD               $02
.define SCMD_STEREO             $03
.define SCMD_GLOBAL_VOLUME      $04
.define SCMD_CHANNEL_VOLUME     $05
.define SCMD_MUSIC_PLAY         $06
.define SCMD_MUSIC_STOP         $07
.define SCMD_MUSIC_PAUSE        $08
.define SCMD_SFX_PLAY           $09
.define SCMD_STOP_ALL_SOUNDS    $0A
.define SCMD_STREAM_START       $0B
.define SCMD_STREAM_STOP        $0C
.define SCMD_STREAM_SEND        $0D

.define FULL_VOL                127
.define PAN_CENTER              128
.define PAN_LEFT                0
.define PAN_RIGHT               255

.define APU0                    $2140
.define APU1                    $2141
.define APU01                   $2140
.define APU2                    $2142
.define APU3                    $2143
.define APU23                   $2142

.include "engine/drivers/spc700/driver.asm"

.struct SoundManager
    spc_temp            dw
    gss_param           dw
    gss_command         dw
    save_stack          dw
    spc_music_load_adr  dw
    echo_pointer        dw
.endst

.ramsection "SoundRAM" appendto "RAM"
    sound_mgr instanceof SoundManager
.ends

.include "debug/debug_sound.asm"

.section "SoundROM" bank 0 slot "ROM"

;
; Use the default spc700_code_1 generated by GSS
;
SoundManager_Init:
    A16
    lda #SPC700Driver@Data
    ldx #SPC700Driver@Bank
    jsr SPC700_Init
    rts


;
; spc700.bin is the code and BRR samples
; code loads to $200
; stereo, 0 is off (mono), 1 is on;
; volume 127 = max
; pan 128 = center
;
; A - Address of the SPC700.bin
; X - Bank of the SPC700.bin
;
; @example:
;   nmi should be disabled
;   A16
;   lda # address of spc700.bin
;   ldx # bank of spc700.bin
;   jsr SPC700_Init
;
SPC700_Init:
    php
    A16

    ; Load the address and bank of the music
    sta spc700_data
    stx spc700_data + 2

    tsx
    stx sound_mgr.save_stack

    ; Hack for music for now
    ldy #14
    lda [spc700_data], Y
    sta sound_mgr.spc_music_load_adr

    lda spc700_data + 2
    pha

    ; Remember, actual code is the spc700 data + 2 bytes
    lda spc700_data
    ina
    ina
    pha

    ; Read the size from the SPC700 block
    lda [spc700_data]
    pha

    ; $0200 is the address in the APU we will write the data to
    lda #$0200
    pha

    ; Kick off the SPC700 data loading process
    jsr SPC700_LoadData

    ; Restore the stack
    ldx sound_mgr.save_stack
    txs

    ; Initialize the sound driver
    lda #SCMD_INITIALIZE
    sta sound_mgr.gss_command
    stz sound_mgr.gss_param
    jmp SPC700_Commit

;
; SPC700 Load Data function
; This loads the SPC700 binary and sets up the sound driver so we can play
; sounds, music, etc.
;
; 3,  S - Address in the APU
; 5,  S - Size of the SPC700 binary to load
; 7,  S - Low byte source of the data
; 9, S - High byte source of the data
;
SPC700_LoadData:

    php
    A16
    
    ; make sure no irq's fire during this transfer
    sei

    ; Wait for the SPC700 to become ready ($AA)
    A8
    lda.b #$AA
    @WaitForAPUInit:
        cmp.l APU0
        bne @WaitForAPUInit

    @SetPointers:
        A16

        ; Source High Bytes
        lda 10, S
        sta.b spc700_data + 2

        ; Source Low Bytes
        lda 8, S
        sta.b spc700_data + 0

        ; Size of the data
        lda 6, S
        tax

        ; APU load address
        lda.b 4,S
        sta.l APU23
    
        ; Tell the APU we are ready
        A8
        lda.b #$01
        sta.l APU1
        lda.b #$CC
        sta.l APU0

    @WaitForAPUWriteReady:
        cmp APU0
        bne @WaitForAPUWriteReady
    
    ldy.w #0
    ; X contains the number of bytes to load
    @Loop:
        xba
        lda.b [spc700_data], Y
        xba
        tya
        
        A16
        sta.l APU01
        A8
        
        ; Wait for the APU to be ready to load next word
        @@Wait:
            cmp.l APU0
            bne @@Wait
        
        iny
        dex
        bne @Loop

    ; Prepare index register for APU
    xba
    lda.b #$00
    xba
    clc
    adc.b #$02
    A16
    tax

    ; Inform where it should write data for APU
    lda.w #$0200
    sta.l APU23

    ; Save index register for APU reads
    txa
    sta.l APU01
    A8
        
    @WaitAPULoadFinished:
        cmp.l APU0
        bne @WaitAPULoadFinished

    A16

    ; Wait until SPC700 clears all communication ports,
    ; confirming that code has started running.
    @WaitForAPUReset:
        lda.l APU0
        ora.l APU2
        bne @WaitForAPUReset

    cli

    ; plp will re-enable interrupts
    plp
    rts

;
; Plays a song with the driver
;
; nmi should be disabled
; A16
; lda # address of song
; ldx # bank of song
; jsr SoundManager_PlayMusic
; 1st 2 bytes of song are size, then song+2 is address of song data
;
SoundManager_PlayMusic:
    php

    A16
    sta spc700_data
    stx spc700_data + 2
    
    jsr SoundManager_StopMusic
    
    ; Prepare the SPC700 state machine to load music
    lda #SCMD_LOAD
    sta sound_mgr.gss_command
    stz sound_mgr.gss_param
    jsr SPC700_Command
    
    ; Save stack pointer
    A16
    tsx
    stx sound_mgr.save_stack

    ; Similar to before, data + bank
    lda spc700_data + 2
    pha

    ; Load the loword (at data + 2)
    lda spc700_data
    ina
    ina
    pha

    ; And then load the first 2 bytes as the size
    lda [spc700_data]
    pha

    ; Address in the APU for this
    lda sound_mgr.spc_music_load_adr
    pha

    ; Kick off the SPC700 process to load data
    jsr SPC700_LoadData

    ; Restore the stack
    ldx sound_mgr.save_stack
    txs

    ; Tell the SPC700 to play music
    stz sound_mgr.gss_param
    lda #SCMD_MUSIC_PLAY
    sta sound_mgr.gss_command
    jmp SPC700_Commit

;
; Send a command to the SPC driver
;
; @Example:
;   A16
;   lda #command
;   sta gss_command
;   lda #parameter
;   sta gss_param
;   jsr SPC700_Command
;
SPC700_Command:
    php
    A8

    @WaitForAPUInit:
        lda APU0
        bne @WaitForAPUInit

    @SendCommand:
        A16
        lda sound_mgr.gss_param
        sta APU23

        lda sound_mgr.gss_command
        A8
        xba
        sta APU1
        xba
        sta APU0

        ; If true, then we don't need to wait for an ack
        cmp #SCMD_LOAD
        beq @Done

    @WaitForAPUAck:
        lda APU0
        beq @WaitForAPUAck

    @Done:
        A16
        plp
        rts

;
; Enable Stereo Sound
; lda #0 (mono) or 1 (stereo)
; jsr SPC_Stereo
;
SoundManager_Stereo:
    php

    A16

    ; Send mono or stereo as parameter
    and #$00ff
    sta sound_mgr.gss_param

    ; Send command
    lda #SCMD_STEREO
    sta sound_mgr.gss_command

    jmp SPC700_Commit

;
; Set global volume and fade time
;
; @example:
;   lda #speed, how quickly the volume fades, 1-255*
;   ldx #volume, 0-127
;   jsr SoundManager_GlobalVolume
;
; *255 is default = instant (any value >= 127 is instant)
; speed = 7 is about 2 seconds, and is a medium fade in/out
;
SoundManager_GlobalVolume:
    php
    A16    

    ; Setup speed
    xba
    and #$ff00
    sta sound_mgr.gss_param

    ; Setup volume
    txa
    and #$00ff
    ora sound_mgr.gss_param
    sta sound_mgr.gss_param
    lda #SCMD_GLOBAL_VOLUME
    sta sound_mgr.gss_command

    jmp SPC700_Commit

SoundManager_StopMusic:
    php
    A16
    lda #SCMD_MUSIC_STOP
    sta sound_mgr.gss_command
    stz sound_mgr.gss_param
    jmp SPC700_Commit


; Pause or unpause music
; @example:
;   lda #0 (unpause) or 1 (pause)
;   jsr Music_Pause
SoundManager_Pause:
    php
    A16
    and #$00ff
    sta sound_mgr.gss_param
    lda #SCMD_MUSIC_PAUSE
    sta sound_mgr.gss_command
    jmp SPC700_Commit

;
; Stop all sounds
;
SoundManager_StopAll:
    php
    A16
    lda #SCMD_STOP_ALL_SOUNDS
    sta sound_mgr.gss_command
    stz sound_mgr.gss_param
    jmp SPC700_Commit


;AXY8 or A16
;in a= sfx #
;    x= volume 0-127
;    y= sfx channel 0-7, needs to be > than max song channel
;pan center
SoundManager_PlaySound:
    php

    A8
    sta sound_mgr.spc_temp
    stx sound_mgr.spc_temp+1

    A16
    tsx
    stx sound_mgr.save_stack

    ; Use center channel
    lda #128
    pha

    ; Volume range (X)
    lda sound_mgr.spc_temp + 1
    and #$00ff
    pha

    ; SFX to play
    lda sound_mgr.spc_temp
    and #$00ff
    pha

    ; Channel to be used (needs to be > the song channels)
    tya
    and #$0007
    pha

    ; Play it
    jsr SPC700_SFXPlay

    ; Restore the stack
    ldx sound_mgr.save_stack
    txs
    plp
    rts

;
; SPC700 SFX play
;
; Expects the stack:
; 3, S  = chn last in
; 5, S  = volume
; 7, S  = sfx
; 9, S = pan
SPC700_SFXPlay:
    php
    A16

    ; Pan
    lda 10, S
    bpl @SetPan
    lda #0

    @SetPan:
        cmp #255
        bcc @Skip
        lda #255
    @Skip:

    ; Pan
    xba
    and #$FF00
    sta sound_mgr.gss_param
    
    ; SFX number
    lda 6, S
    and #$00FF
    ora sound_mgr.gss_param
    sta sound_mgr.gss_param

    ; Volume
    lda 8, S
    xba
    and #$ff00
    sta sound_mgr.gss_command

    ; Channel
    lda 4, S
    asl a
    asl a
    asl a
    asl a
    and #$0070

    ora #SCMD_SFX_PLAY
    ora sound_mgr.gss_command
    sta sound_mgr.gss_command

    jmp SPC700_Commit

;
; Quick wrapper for commiting changes. Makes an easy breakpoint.
;
SPC700_Commit:
    jsr SPC700_Command
    plp
    rts

.ends