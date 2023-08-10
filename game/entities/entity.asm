;
; An entity is the base class for all objects.
; It is the base class for all objects that can be placed in the world.
; They do not necessarily have to be visible.
;


.define MAX_ENTITIES 16

;
; This is the base class for all entities.
; Treat it like a pure virtual class
;
.struct Entity
    ; Base data for all entities
    id        ds 4   ; Unique ID of the entity (for easy lookup)
    type      dw     ; The type of the entity
    allocated db     ; Whether the entity is allocated or not
    enabled   db     ; Whether the entity is enabled or not
    dirty     db     ; Whether the entity needs to be redrawn or not

    ; Health data for the entity
    health     db    ; The current health of the entity
    max_health db    ; The maximum health of the entity

    ; Position data for aabb collision
    x         db     ; The x position of the entity
    y         db     ; The y position of the entity
    width         db     ; The width of the entity
    height         db     ; The height of the entity

    ; Rendering attributes
    sprite_ptr  dw    ; Pointer to the sprite descriptor
.endst
.enum $0000
    entity instanceof Entity
.ende

.struct FakeEntity
    base instanceof Entity
    cls   ds  16
.endst

.struct EntityManager
    entities instanceof FakeEntity MAX_ENTITIES
    num_allocated   dw
    temp_jmp        dw
.endst

.ramsection "EntityRAM" appendto "RAM"
    entity_manager instanceof EntityManager
.ends

.include "debug/debug_entity.asm"

.section "EntityROM" bank 0 slot "ROM"

.dstruct EntityBase instanceof FakeEntity values
    base.id:            .db "ENTY"
    base.type:          .dw ENTITY_TYPE_NONE
    base.health:        .db 100
    base.max_health:    .db 100
    base.width:             .db 8
    base.height:             .db 8
.endst

EntityManager_Init:
    stz entity_manager.num_allocated.w
    rts

;
; Request an entity object from the entity manager
; Y = The pointer to the entity object, otherwise 0 if no free objects
;
EntityManager_Request:
    pha
    phx

    ; Advance the pointer to the first entity object in the struct
    clc
    lda #entity_manager.entities
    tax

    ; Stupidly simple, just iterate through the OAM objects and
    ; return the first one that is not allocated
    ldy #0

    A8
    @FindNextFreeObject:
        ; Check if the sprite descriptor is allocated
        lda entity.allocated, X
        beq @MarkAllocated

        ; Advance the pointer
        A16
        clc
        txa
        adc #_sizeof_EntityBase
        tax
        A8

        ; Did we reach the end of the sprite object space?
        iny
        cpy #MAX_ENTITIES
        beq @OutOfSpace

        ; Continue to the next iteration
        bra @FindNextFreeObject

    ; If we got here, then we found a free object. Mark it allocated
    @MarkAllocated:
        lda #1
        sta entity.allocated, X
        stz entity.dirty, X
        inc entity_manager.num_allocated.w

        ; Return the address of the sprite object
        txy
        bra @Done

    ; If we got here, then we did not find a free object
    @OutOfSpace:
        ldy #0

    ; Common exit point. We do not restore Y because we want to return it.
    @Done:
        A16
        plx
        pla

    rts

;
; Releases an entity object back to the entity manager
;
EntityManager_Release:
    phx
    tyx
    A8
    stz entity.allocated, X
    stz entity.dirty, X
    stz entity.enabled, X
    A16
    dec entity_manager.num_allocated.w
    plx
    rts

;
; Similar to a request, but spawns an enemy into the screen now
; A should be the type of the entity to spawn
;
EntityManager_Spawn:
    pha
    phx

    jsr EntityManager_Request
    cpy #0
    beq @Failed

    ; Set the type of the entity
    sta entity.type, Y

    ; Y = Pointer to the entity object
    jsr Entity_Load
    bra @Done

    @Failed:
        brk

    @Done:
    plx
    pla
    rts

;
; Handles the frame of all entities
;
EntityManager_Frame:
    pha
    phx
    phy

    ; Advance the pointer to the first entity object in the struct
    clc
    lda #entity_manager.entities
    tay

    ldx #0

    @Loop:
        ; Check if the sprite descriptor is allocated
        A8
        lda entity.enabled, Y
        beq @@Next

        A16
        phx
        ldx entity.type, Y
        jsr (EntityVTable@Frame, X)
        plx

        ; Advance the pointer
        @@Next:
        A16
        clc
        tya
        adc #_sizeof_EntityBase
        tay

        ; Did we reach the end of the sprite object space?
        inx
        cpx entity_manager.num_allocated.w
        bcs @Done

        ; Continue to the next iteration
        bra @Loop

    @Done:
        A16
        ply
        plx
        pla
        rts

;
; Handles the vblank of all entities
;
EntityManager_VBlank:
    pha
    phx
    phy

    ; Advance the pointer to the first entity object in the struct
    clc
    lda #entity_manager.entities
    tay

    ldx #0

    @Loop:
        ; Check if the sprite descriptor is allocated
        A8
        lda entity.dirty, Y
        beq @@Next

        ; Load the vtable pointer for the entity and then call its
        ; frame function
        A16
        phx
        ldx entity.type.w, Y
        jsr (EntityVTable@VBlank, X)
        plx

        ; Advance the pointer
        @@Next:
        A16
        clc
        tya
        adc #_sizeof_EntityBase
        tay

        ; Did we reach the end of the sprite object space?
        inx
        cpx entity_manager.num_allocated.w
        bcs @Done

        ; Continue to the next iteration
        bra @Loop

    @Done:
        A16
        ply
        plx
        pla
        rts

Entity_Load:
    pha

    @InitializeBase:
        phx
        phy

        ; X is the source address
        lda entity.type, Y
        tax
        lda EntityInitObject.w, X
        tax

        ; Y is the destination address
        lda #_sizeof_EntityBase
        dea

        mvn $00, $00

        ply
        plx

    @InitializeDerived:
        phx
        phy

        ; X is the source address
        ldx entity.type, Y
        jsr (EntityVTable@Init, X)

        ply
        plx

    pla
    rts

;
; Default entity initialization function
;
Entity_Init:
    pha
    phx
    phy ; entity

    ; Load the plane's sprite
    ; A = Sprite Bank
    ; X = Sprite Data
    ; Y = Sprite Descriptor
    lda EntitySpriteBank.w, X
    clc
    adc EntitySpriteData.w, X
    cmp #0
    beq @SetDefaultPosition

    @SpriteLoading:
        phx
        lda entity.type, Y
        tax

        jsr SpriteManager_Request

        ; Setup sprite bank
        lda EntitySpriteBank.w, X
        pha

        ; Setup sprite data
        lda EntitySpriteData.w, X
        tax

        ; A = Sprite Bank
        ; X = Sprite Data
        pla
        jsr Sprite_Load 
        plx

        ; If the pointer is 0, then the sprite failed to load
        cpy #0
        beq @FailedSpriteInit

        ; Swap so X is now the entity pointer since Y stores the sprite pointer
        lda 1, S
        tax
        tya
        sta entity.sprite_ptr.w, X

        ; Swap back so Y is the base pointer
        txy
        bra @SetDefaultPosition

    @FailedSpriteInit:
        brk
        bra @Done

    @SetDefaultPosition:
        A8
        lda #0
        sta entity.x, Y
        sta entity.y, Y
        A16

    @MarkDirty:
        ; Mark the entity as dirty (just calling base class)
        jsr Entity_MarkDirty
        bra @Done

    
    @Done:
        A16
        ply
        plx
        pla

    rts

;
; Default entity per-frame function
;
Entity_Frame:
    rts

;
; Default entity vblank function
;
Entity_VBlank:
    rts

;
; Marks an entity as dirty
; Additionally marks the sprite as dirty
;
Entity_MarkDirty:
    phx
    pha

    ; Mark the entity as dirty
    A8
    lda #1
    sta entity.dirty, Y
    A16

    ; Mark the sprite as dirty
    lda entity.sprite_ptr, Y
    cmp #0
    beq @Done
    tax

    A8
    lda entity.x, Y
    sta sprite_desc.x, X
    lda entity.y, Y
    sta sprite_desc.y, X
    A16

    jsr Sprite_MarkDirty

    @Done:
        pla
        plx
        rts


;
; Default entity axis-aligned bounding box check function
; X is the current entity
; Y is the entity to check against
;
Entity_AABB:
    rts

;
; X is the entity giving damage
; Y is the entity that will take damage
; Put in A the amount of damage to deal
;
; Used to calculate damage based on the entity's stats
;
Entity_GiveDamage:
    rts

;
; A is the amount of damage to give
; X is the entity to take damage
; Y is the entity that is dealing damage
;
; Used to calculate damage received based on the entity's stats
;
Entity_TakeDamage:
    rts

.ends
