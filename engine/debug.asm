;
; Just debugging stuff.
;

.struct Debug
    disable_bg db
    counter db
.endst

.ramsection "DebugRAM" appendto "RAM"
    dbg instanceof Debug
.ends

.section "Debug" bank 0 slot "ROM"

;
; Called at the start of VBlank when the stack has been set up.
;
Debug_VBlankStart:
    inc dbg.counter.w
    rts

;
; Called at the end of VBlank before the stack is restored.
;
Debug_VBlankEnd:
    rts

;
; Called at the start of the main loop
;
Debug_FrameStart:
    rts


;
; Called at the end of the main loop
;
Debug_FrameEnd:
    rts

.ends