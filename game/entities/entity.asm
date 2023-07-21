;
; An entity is the base class for all objects.
; It is the base class for all objects that can be placed in the world.
; They do not necessarily have to be visible.
;

.struct Entity
    type      db     ; The type of the entity
    size      db     ; Size in bytes of the entity
    allocated db     ; Whether the entity is allocated or not
    enabled   db     ; Whether the entity is enabled or not
    name      ds 16  ; The name of the entity
    x         dw     ; The x position of the entity
    y         dw     ; The y position of the entity
    w         db     ; The width of the entity
    h         db     ; The height of the entity
.endst

.struct EntityManager