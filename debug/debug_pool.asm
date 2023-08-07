; Initially, no debug hooks are enabled
; You do not have to modify these except when adding more hooks
.define DEBUG_PoolTest 0

; If debug.asm doesn't define DEBUG_HOOKS as 1 then none of the debug hooks
; will be compiled below.
.ifeq DEBUG_HOOKS 1

.print "debug_vram.asm: Enabling debug hooks\n"

; Required hooks to debug the VRAM manager
.ifeq DEBUG_VRAM_ALLOCATOR 1
    .print "debug_vram.asm: Enabling vram manager debug hooks\n"
    .redefine DEBUG_PoolTest 1
.endif

.struct DebugPool
    empty db

    .ifeq DEBUG_VRAM_ALLOCATOR 1
    pool instanceof Pool
    .endif
.endst

.ramsection "DebugVRAMRAM" appendto "RAM"
    dbg_vram instanceof DebugPool
.ends

.section "DebugVRAMROM" bank 0 slot "ROM"

nop

Main@PoolTest:
    pha
    phx

    brk

    ldx #dbg_vram.pool
    pea $0000
    pea $8000
    jsr Pool_AllocateBlock
    pla
    pla

    ; Intentionally mark the block free, so that we can
    ; attempt to split it below
    ldx #dbg_vram.pool.chunks.1
    lda #1
    sta pool_chunk.free, X

    ; Attempt to allocate an entire block
    @AllocateBlock:
        ldx #dbg_vram.pool

        pea $2000
        pea $27FF
        jsr Pool_AllocateBlock
        pla
        pla

        cpy #0
        beq @FailedAllocateBlock

        ; Confirm the pool was correctly allocated
        ldx #dbg_vram.pool.chunks.1

        lda pool_chunk.free, X
        cmp #$0
        bne @FailedAllocateBlock

        lda pool_chunk.allocated, X
        cmp #$1
        bne @FailedAllocateBlock

        lda pool_chunk.start, X
        cmp #$2000
        bne @FailedAllocateBlock

        lda pool_chunk.end, X
        cmp #$27FF
        bne @FailedAllocateBlock

        ; Look at the "prev" block and confirm it was correctly allocated
        ldx #dbg_vram.pool.chunks.2

        lda pool_chunk.start, X
        cmp #$0
        bne @FailedAllocateBlock

        lda pool_chunk.end, X
        cmp #$1FFF

        lda pool_chunk.free, X
        cmp #$1
        bne @FailedAllocateBlock

        lda pool_chunk.allocated, X
        cmp #$1
        bne @FailedAllocateBlock

        ; Look at the "next" block and confirm it was correctly allocated
        ldx #dbg_vram.pool.chunks.3

        lda pool_chunk.start, X
        cmp #$2800
        bne @FailedAllocateBlock

        lda pool_chunk.end, X
        cmp #$8000

        lda pool_chunk.free, X
        cmp #$1
        bne @FailedAllocateBlock

        lda pool_chunk.allocated, X
        cmp #$1
        bne @FailedAllocateBlock

        bra @AllocateWithinBlock1

    @FailedAllocateBlock:
        brk
        jmp @FailedTests

    ; Attempt to allocate within a block
    @AllocateWithinBlock1:
        ldx #dbg_vram.pool
        pea $100
        pea $2800
        pea $4000
        jsr Pool_AllocateWithinBlock
        pla
        pla
        pla

        tyx

        lda pool_chunk.free, X
        cmp #$0
        bne @FailedAllocateWithinBlock1

        lda pool_chunk.allocated, X
        cmp #$1
        bne @FailedAllocateWithinBlock1

        lda pool_chunk.start, X
        cmp #$2800
        bne @FailedAllocateWithinBlock1

        lda pool_chunk.end, X
        cmp #$28FF
        bne @FailedAllocateWithinBlock1

    bra @AllocateWithinBlock2

    @FailedAllocateWithinBlock1:
        brk
        jmp @FailedTests

    ; Attempt to allocate within a block
    @AllocateWithinBlock2:
        ldx #dbg_vram.pool
        pea $100
        pea $2800
        pea $4000
        jsr Pool_AllocateWithinBlock
        pla
        pla
        pla

        tyx

        lda pool_chunk.free, X
        cmp #$0
        bne @FailedAllocateWithinBlock2

        lda pool_chunk.allocated, X
        cmp #$1
        bne @FailedAllocateWithinBlock2

        lda pool_chunk.start, X
        cmp #$2900
        bne @FailedAllocateWithinBlock2

        lda pool_chunk.end, X
        cmp #$29FF
        bne @FailedAllocateWithinBlock2

    bra @FreeVRAM

    @FailedAllocateWithinBlock2:
        brk
        jmp @FailedTests    

    @FreeVRAM:
        ldx #dbg_vram.pool
        pea $2000 ; Start
        pea $8000 ; End
        jsr Pool_Free
        pla
        pla

        ldx dbg_vram.pool.head.w

        lda pool_chunk.free, X
        cmp #1
        bne @FailedFreeVRAM

        lda pool_chunk.allocated, X
        cmp #1
        bne @FailedFreeVRAM

        lda pool_chunk.start, X
        cmp #$0
        bne @FailedFreeVRAM

        lda pool_chunk.end, X
        cmp #$1FFF
        bne @FailedFreeVRAM

        lda pool_chunk.next, X
        cmp #$0
        bne @FailedFreeVRAM

    bra @FreeAllVRAM
    @FailedFreeVRAM:
        brk
        jmp @FailedTests

    @FreeAllVRAM:
        brk
        ldx #dbg_vram.pool
        pea $0 ; Start
        pea $8000 ; End
        jsr Pool_Free
        pla
        pla

        lda dbg_vram.pool.head.w
        cmp #$0
        bne @FailedFreeAllVRAM

    bra @Done
    @FailedFreeAllVRAM:
        brk
        jmp @FailedTests

    @FailedTests:
        brk
    
    @Done:
        plx
        pla
        rts

.ends

.endif ; DEBUG_HOOKS