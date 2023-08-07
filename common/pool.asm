;
; Module that can help with the management of vram buy allocating 1KB chunks
; across the standard spaces the engine uses for vram.
;
; Remember, these are 16-bit words
;
.ACCU   16
.INDEX  16
.16bit

.define OAM_DATA            $0000

; OAM page 0 can be aligned at $0000, $2000, $4000, or $6000 word
; OAM page 1 can be aligned at page 0 + $1000, $2000, $3000, or $4000 word
.define OAM_PAGE1_ADDR      $6000      ; BBB = 011 ($6000)
.define OAM_PAGE2_ADDR      $7000      ; PP  = 00  ($6000 + $1000)
.define OAM_DEFAULT_OBJSEL  %00100011  ; 8x8/16x16 Page 0 @ $6000, Page 1 @ $7000

.define POOL_CHUNKS         64

;
; This is a memory pool manager
; It doesn't do anything fancy beyond let the developer specify how much
; memory they want, then it will allocate it from the pool and split it.
; You end up with a linked list of pool chunks. Then you can free the pool
; and it will merge the chunks back together.
;

.struct PoolChunk
    allocated   dw
    free        dw
    start       dw
    end         dw
    next        dw
.endst
.enum $0000
    pool_chunk instanceof PoolChunk
.ende

; Smallest granularity is 1KB chunks

.struct Pool
    chunks instanceof PoolChunk POOL_CHUNKS
    head dw ; Pointer to the head of the pool
.endst
.enum $0000
    pool instanceof Pool
.ende

.include "debug/debug_pool.asm"

.section "PoolManagerROM" bank 0 slot "ROM"

;
; Initializes a pool
; X is the allocation to the pool itself
;
Pool_Init:
    pha
    phx

    stz pool.head, X

    plx
    pla
    rts

;
;
; Expects the stack to have the start and end address on it
;
; This can only be called from a typical jsr
; X is the index of the chunk to allocate
; 3, S -> start
; 5, S -> end
;
;
PoolChunk_Init:
    ; Get the start and end address
    lda 5, S
    sta pool_chunk.start, X
    lda 3, s
    sta pool_chunk.end, X

    ; Pool is allocated and free
    lda #1
    sta pool_chunk.free, X
    sta pool_chunk.allocated, X

    ; Set the next and prev pointer to be null
    stz pool_chunk.next, X
    rts

;
; Find a chunk that is allocatable
; Expects X to the pool pointer
;
Pool_AllocateChunk:
    pha
    phx

    ldy #0
    txa
    clc
    adc #pool.chunks.1
    tax

    ; while (y < POOL_CHUNKS)
    @Loop:
        ; if (!chunk.allocated) { return chunk; }
        lda pool_chunk.allocated, X
        beq @FoundChunk
        iny
        txa
        clc
        adc #_sizeof_PoolChunk
        tax
        cpy #POOL_CHUNKS
        bne @Loop

    ; return null
    @Error:
        plx
        pla
        ldy #0
        rts

    ; return chunk
    @FoundChunk:
        lda #1
        sta pool_chunk.allocated, X
        stz pool_chunk.free, X
        stz pool_chunk.start, X
        stz pool_chunk.end, X
        stz pool_chunk.next, X

        txy
        plx
        pla
        rts

;
; Look for a chunk that is within the range specified
; 
; X is the pool index
; 7, S -> size
; 5, S -> start
; 3, S -> end
;
Pool_FindChunk:
    lda pool.head, X
    tax

    pha ; Temporary variable for chunk size

    ; while (chunk != null)
    @Loop:
        @@CheckFree:
            lda pool_chunk.free, X
            cmp #1
            bne @@NextChunk

        @@CheckAllocated:
            lda pool_chunk.allocated, X
            cmp #1
            bne @@NextChunk

        ; available: Store the calculated chunk size
        lda pool_chunk.end, X
        sec
        sbc pool_chunk.start, X
        sta 1, S

        ; if available = available - size
        ; Determine if the chunk is large enough to hold the range specified
        @@CheckSize:
            lda 1, S
            sec
            sbc 9, S
            sta 1, S
            bmi @@NextChunk

        ; if (start >= chunk.start) { check if enough space to allocate }
        @@CheckStart:
            lda 7, S
            cmp pool_chunk.start, X
            bcs @@CheckEnd
            ; else
            ; available = available - chunk.start + start
            lda 1, S
            sec
            sbc pool_chunk.start, X
            clc
            adc 7, S
            sta 1, S
            bmi @@NextChunk

        ; if (chunk.end >= end)
        @@CheckEnd:
            lda pool_chunk.end, X
            cmp 5, S
            bcs @FoundChunk
            ; else
            ; available = available - end + chunk.end
            lda 1, S
            sec
            sbc 5, S
            clc
            adc pool_chunk.end, X
            sta 1, S
            bpl @FoundChunk

        ; chunk = chunk.next
        @@NextChunk:
            lda pool_chunk.next, X
            beq @NotFound
            tax
            bra @Loop

    ; return chunk
    @FoundChunk:
        pla
        rts

    ; return null
    @NotFound:
        ldx #0
        pla
        rts

;
; Split a chunk
;
; X is the index of the chunk to split
; 5, S -> start
; 3, S -> end
;
Pool_SplitChunk:
    phx

    ; if (chunk.start < start)
    @SplitStart:
        lda pool_chunk.start, X
        cmp 7, S
        bcs @SplitEnd

        ; Allocate to Y (left)
        jsr Pool_AllocateChunk

        ; if (chunk == NULL) error
        tya
        beq @SplitErrorCreateChunk

        lda #1
        sta pool_chunk.free, Y

        ; left.start = right.start
        lda pool_chunk.start, X
        sta pool_chunk.start, Y

        ; left.end = start - 1
        lda 7, S
        dea
        sta pool_chunk.end, Y

        ; left.next = chunk
        txa
        sta pool_chunk.next, Y

        ; if X == head, then head = left
        lda 1, S
        tax
        cmp pool.head, X
        bne @SplitEnd
        tya
        sta pool.head, X

    ; if (chunk.end > end)
    @SplitEnd:
        lda pool_chunk.end, X
        cmp 5, S
        bcc @Done

        ; Allocate to Y (Right)
        jsr Pool_AllocateChunk

        ; if (chunk == NULL) error
        tya
        beq @SplitErrorCreateChunk

        lda #1
        sta pool_chunk.free, Y

        ; right.start = end + 1
        lda 5, S
        ina
        sta pool_chunk.start, Y

        ; right.end = chunk.end
        lda pool_chunk.end, X
        sta pool_chunk.end, Y

        ; chunk.next = right
        tya
        sta pool_chunk.next, X
        bra @Done

    @SplitErrorCreateChunk:
        brk
        plx
        ldx #0
        rts

    @Done:
        pla ; Remove X from the stack, since we're replacing it

        lda 5, S
        sta pool_chunk.start, X

        lda 3, S
        sta pool_chunk.end, X
        rts

;
; Allocate a chunk of memory within the bounds specified
;
; X is the pool index
; 7, S -> length
; 5, S -> start
; 3, S -> end
;
Pool_AllocateWithinBlock:
    phx

    ; Setup stack for FindChunk
    @FindChunk:
        lda 9, S ; Length
        pha
        lda 9, S ; Start
        pha 
        lda 9, S ; End
        pha 
        jsr Pool_FindChunk
        pla
        pla
        pla

        ; if (chunk == null) error
        cpx #0
        beq @NoExistingChunkFound

    ; Split the chunk
    @SplitChunk:
        lda 7, S
        cmp pool_chunk.start, X
        bcs @@PushStart
        bra @@PushChunkStart

        @@PushStart:
            lda 7, S
            pha
            bra @@Next

        @@PushChunkStart:
            lda pool_chunk.start, X
            pha

        @@Next:
            clc
            adc 11, S    ; End (Start + length - 1)
            dea
            pha

        jsr Pool_SplitChunk

        @@Cleanup:
            pla
            pla
            ; if (chunk == null) error
            cpx #0
            beq @ErrorSplitChunk
            bra @Done

    @NoExistingChunkFound:
        ; Allocate a new chunk
        plx
        jsr Pool_AllocateChunk

        ; if (chunk == null) error
        cpy #0
        beq @ErrorCreateChunk

        ; Chunk is allocated, so it covers the entire range
        lda 5, S
        sta pool_chunk.start, Y
        lda 3, S
        sta pool_chunk.end, Y

        ; Update head
        tya
        sta pool.head, X

        rts

    @ErrorCreateChunk:
        brk
        plx
        rts

    @ErrorSplitChunk:
        brk
        plx
        rts

    @Done:
        ; Mark the block not free
        lda #0
        sta pool_chunk.free, X
        txy
        plx
        rts


;
; Allocate an entire block
;
; X is the pool index
; 5, S -> start
; 3, S -> end
;
Pool_AllocateBlock:
    lda 3, S
    sec
    sbc 5, S
    ina
    pha      ; Push Length + 1 (since this wants the whole block)

    lda 7, S ; Push Start
    pha

    lda 7, S ; Push End
    pha

    jsr Pool_AllocateWithinBlock

    ; Clean up arguments
    pla
    pla
    pla
    rts

;
; Iterate through the chunks and merge any that are adjacent
;
Pool_MergeChunks:
    pha
    phx
    phy

    lda pool.head, X
    tax

    @Loop:
        ; We'll use Y to refer to chunk.next
        lda pool_chunk.next, X
        tay

        ; if (chunk.next == null) return
        @@CheckNext:
            cpy #0
            beq @Done

        @@CheckRange:
            ; if (chunk.end + 1 == chunk.next.start)
            ; Then we can merge it!
            lda pool_chunk.end, X
            ina
            cmp pool_chunk.start, Y
            bne @@NextChunk
            ; chunk.end = chunk.next.end
            lda pool_chunk.end, Y
            sta pool_chunk.end, X

            ; chunk.next = chunk.next.next
            lda pool_chunk.next, Y
            sta pool_chunk.next, X

            ; Free the chunk at Y
            ; stz blah, Y isn't a real opcode.
            lda #0
            sta pool_chunk.allocated, Y
            sta pool_chunk.free, Y
            sta pool_chunk.next, Y

            ; See if we can merge the next chunk
            bra @Loop

        @@NextChunk:
            ; chunk = chunk.next
            tya
            tax
            bra @Loop

    @Done:
        ply
        plx
        pla
        rts

;
; Free a chunk of memory
; 5, S -> start
; 3, S -> end
;
Pool_Free:
    lda #0  ; Pointer to the previous chunk
    pha

    phx
    lda pool.head, X
    tax

    ;
    ; Basic idea here is that we are in one of the three conditions:
    ;
    ; 1) The chunk is entirely within the free range
    ; 2) The beginning of the chunk is within the free range
    ; 3) The end of the chunk is within the free range
    ;
    @Loop:
        ; if (chunk == null) merge chunks and return
        cpx #0
        bne @@CheckRange
        jmp @MergeChunks

        ; if (chunk.start >= start && chunk.end - 1 < end)
        ; Then the chunk is entirely within the free range
        @@CheckRange:
            ; Check start conditions: start < chunk.start
            ; if (chunk.start < start) check start range
            lda pool_chunk.start, X
            cmp 9, S ; Start
            bcc @@CheckStart

            ; Check end conditions: ... && chunk.end - 1 < end
            lda pool_chunk.end, X
            dea
            cmp 7, S ; End
            bcs @@CheckStart

            ; Do we have a previous chunk?
            ; if (prev == NULL)
            lda 3, S
            beq @@@NoPrevChunk

            ; prev != NULL: we have a prev chunk, so bypass it
            tay

            ; prev.next = chunk.next
            lda pool_chunk.next, X
            sta pool_chunk.next, Y

            ; free(chunk)
            stz pool_chunk.allocated, X
            stz pool_chunk.free, X
            stz pool_chunk.next, X

            ; chunk = prev.next
            lda pool_chunk.next, Y
            tax
            bra @Loop

            ; Special case for the head node
            @@@NoPrevChunk:
                lda pool_chunk.next, X

                ; We can't ldy 1, S
                pha
                lda 3, S
                tay
                pla

                sta pool.head, Y

                ; free(chunk)
                stz pool_chunk.allocated, X
                stz pool_chunk.free, X
                stz pool_chunk.next, X

                ; chunk = chunk.next
                tax
                bra @Loop

        ; else if (chunk.start >= start && chunk.start - 1 < end)
        ; Then only the beginning of the chunk is within the free range
        @@CheckStart:
            ; Check start conditions: chunk.start >= start
            lda pool_chunk.start, X
            cmp 7, S ; Start
            bcc @@CheckEnd

            ; Check end conditions: ... && chunk.start - 1 < end
            lda pool_chunk.start, X
            dea
            cmp 7, S ; End
            bcs @@CheckEnd

            ; chunk.start = end + 1
            lda 7, S
            ina
            sta pool_chunk.start, X

            ; prev = chunk
            txa
            sta 3, S

            ; chunk = chunk.next
            lda pool_chunk.next, X
            tax
            bra @Loop

        ; if (chunk.end >= start && chunk.end - 1 < end)
        ; Then only the end of the chunk is within the free range
        @@CheckEnd:
            ; Check start conditions: chunk.end >= start
            lda pool_chunk.end, X
            cmp 9, S ; Start
            bcc @@OutsideRange

            ; Check end conditions: ... && chunk.end - 1 < end
            lda pool_chunk.end, X
            dea
            cmp 7, S ; End
            bcs @@OutsideRange

            ; chunk.end = start - 1
            lda 9, S
            dea
            sta pool_chunk.start, X

            ; prev = chunk
            txa
            sta 3, S

            ; chunk = chunk.next
            lda pool_chunk.next, X
            tax
            jmp @Loop

        @@OutsideRange:
            ; prev = chunk
            txa
            sta 3, S

            ; chunk = chunk.next
            lda pool_chunk.next, X
            tax
            jmp @Loop

    @MergeChunks:
        plx
        jsr Pool_MergeChunks

    pla
    rts

.ends