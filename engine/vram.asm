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

.define BG1_TILEMAP_VRAM    $1000
.define BG2_TILEMAP_VRAM    $1400
.define BG3_TILEMAP_VRAM    $1800

.define BG1_CHAR_VRAM       $3000
.define BG2_CHAR_VRAM       $3000
.define BG3_CHAR_VRAM       $5000
.define BG4_CHAR_VRAM       $5000

; OAM page 0 can be aligned at $0000, $2000, $4000, or $6000 word
; OAM page 1 can be aligned at page 0 + $1000, $2000, $3000, or $4000 word
.define OAM_PAGE1_ADDR      $6000      ; BBB = 011 ($6000)
.define OAM_PAGE2_ADDR      $7000      ; PP  = 00  ($6000 + $1000)
.define OAM_DEFAULT_OBJSEL  %00100011  ; 8x8/16x16 Page 0 @ $6000, Page 1 @ $7000

.define VRAM_SIZE           $8000      ; 32KB
.define VRAM_CHUNK_SIZE     $0400      ; 1KB
.define VRAM_CHUNKS         VRAM_SIZE / VRAM_CHUNK_SIZE

;
; This is a VRAM memory pool manager
; It doesn't do anything fancy beyond let the developer specify how much
; memory they want, then it will allocate it from the pool and split it.
; You end up with a linked list of pool chunks. Then you can free the pool
; and it will merge the chunks back together.
;

.struct VRAMPoolChunk
    free dw
    allocated dw
    base dw
    size dw
    next dw
.endst
.enum $0000
    vram_chunk instanceof VRAMPoolChunk
.ende

; Smallest granularity is 1KB chunks

.struct VRAMManager
    pool instanceof VRAMPoolChunk VRAM_CHUNKS
.endst

.ramsection "VRAMPoolRAM" appendto "RAM"
    vram_manager instanceof VRAMManager
.ends

.section "VRAMPool" bank 0 slot "ROM"

VRAMManager_Init:
    pha

    ; Set the pool to be available
    lda #1
    sta vram_manager.pool.1.free

    ; Pool is allocated and free
    sta vram_manager.pool.1.allocated

    ; Make the pool size be the entire VRAM
    lda #VRAM_SIZE
    sta vram_manager.pool.1.size

    ; Set the base address to be the start of VRAM
    lda #0
    sta vram_manager.pool.1.base

    ; Set the next and prev pointer to be null
    stz vram_manager.pool.1.next
    pla
    rts

;
; Allocate a chunk of VRAM from the pool
; A is the size of the allocation
; X is the starting address in VRAM
;
VRAMManager_Allocate:
    phx ; desired_base (11): Base address of the chunk we want
    pha ; desired_size (9): Size of the chunk we want

    ; Temporary variables
    ; Calculate the end address and store it
    clc
    adc 3, S
    pha ; desired_end (7): End address of the chunk we want

    lda #0
    pha ; next_size (5): Size of the chunk we end up finding
    pha ; next_base (3): New base address of the chunk we end up finding
    pha ; chunk_addr (1):  Address of the chunk we end up finding
    
    ; First, find a chunk that is free and big enough
    ldx #vram_manager.pool.1

    @Loop:
        ; if (!chunk.allocated) { Go to the next chunk if available }
        lda vram_chunk.allocated, X
        bne @@NextChunk

        ; if (chunk.free) { We might have found a chunk! }
        lda vram_chunk.free, X
        beq @@PossibleChunk

        ; Attempt to go to the next pointer
        @@NextChunk:
            ; if (!chunk.next) { We're out of chunks, return null }
            lda vram_chunk.next, X
            cmp #0
            bra @ErrorFindingFreeChunk

            ; chunk = chunk.next
            tax
            bra @Loop

        @@PossibleChunk:
            ; if (chunk.size < desired_size) { We can't use this chunk }
            lda vram_chunk.size, X
            cmp 9, S      ; desired_size: We need to compare to the stack
            bcc @@NextChunk

            ; if (chunk.base < desired_base) { We can't use this chunk }
            lda vram_chunk.base, X
            cmp 11, S               ; desired_base: We need to compare to the stack
            bcs @@NextChunk

            ; if (desired_size + chunk.base > chunk.end) { We can't use this chunk }
            clc
            lda 9, S                ; desired_size
            adc vram_chunk.base, X  ; chunk_end = chunk.base + chunk.size
            cmp 7, S                ; desired_end: We need to compare to the stack
            bcs @@NextChunk

    @FoundChunk:
        ; We found a chunk!  Mark it as used
        stz vram_chunk.free, X

        ; Calculate the split size of the chunk, since this will be the
        ; size of the next chunk
        ; next_size = chunk.size - desired_size
        lda vram_chunk.size, X
        sec
        sbc 9, S    ; desired_size: We need to subtract from the stack
        sta 5, S    ; next_size: We need to store this on the stack

        ; Save the current chunk with the new size
        lda 9, S
        sta vram_chunk.size, X ; chunk.size = desired_size

        ; Calculate the base address for the next chunk
        ; next_base = chunk.base + desired_size
        clc
        lda vram_chunk.base, X
        adc 9, S
        sta 3, S    ; next_base = chunk.base + desired_size

        ; Now we need to create a new node for the remaining space
        txa
        sta 1, S    ; chunk_addr = chunk

        ; Iterate through the pool and find a free node to use
        ; This isn't the most efficient way to do this, but it's simple
        ; A free node here means allocatable WRAM node for this manager
        ldy #0
        lda #vram_manager.pool.1
        tax
        @@CreateNewNodeLoop:
            ; if (y >= VRAM_CHUNKS) { We're out of chunks, return null }
            cpy #VRAM_CHUNKS
            bcs @ErrorFindingNewNode

            ; if (!chunk.allocated) { We can use this chunk }
            lda vram_chunk.allocated, X
            cmp #0
            beq @FoundFreeNode

            ; chunk += sizeof(VRAMPoolChunk)
            ; y++
            txa
            clc
            adc #_sizeof_VRAMPoolChunk
            tax
            iny
            bra @@CreateNewNodeLoop

    ; Now we have a free chunk, so let's set it up
    ; Stack is now advanced 2 bytes because we saved the chunk address
    @FoundFreeNode:
        ; chunk.free = true, chunk.allocated = true
        lda #1
        sta vram_chunk.free, X
        sta vram_chunk.allocated, X

        ; Load the calculated base address of the remaining chunk
        ; next_chunk.base = next_base
        lda 3, S
        sta vram_chunk.base, X

        ; Load the calculated size of the remaining chunk
        ; next_chunk.size = next_size
        lda 5, S
        sta vram_chunk.size, X

        ; Swap X back to the chunk we previously found
        ; chunk.next = chunk_addr
        txa
        pha
        lda 1, S ; chunk_addr
        tax
        pla

        sta vram_chunk.next, X

        ; Store the result in Y
        txy
        bra @Done

    @ErrorFindingNewNode:
        brk
    @ErrorFindingFreeChunk:
        brk

    ; Make sure we set y to 0 for any error
    ldy #0

    ; Success above will set y correctly
    @Done:
        pla ; chunk_addr
        pla ; next_base
        pla ; next_size
        pla ; desired_end
        pla ; desired_size
        plx ; desired_base
        rts

.ends