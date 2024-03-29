; You must enable this to enable debug features, otherwise they will not be
; compiled into the code.
.define DEBUG_HOOKS 1

; Debug feature flags that can be enabled/disabled
; ======================== GAME =======================================
.define DEBUG_PLANE_SPRITE_LOADING  0   ; Renders four planes on the screen and moves them
.define DEBUG_BOSS_SPRITE_LOADING   0   ; Renders a large boss on the screen
.define DEBUG_UI_LOADING            0   ; Render a UI text scrolling
.define DEBUG_SKYSCRAPER_MAP        0   ; Renders a test skyscraper map
.define DEBUG_SYNTHSCRAPER_MAP      1   ; Renders a test synthscraper map

; ======================== POOL =======================================
.define DEBUG_POOL_ALLOCATOR        0   ; Exercises the pool allocator

; ======================== ENTITIES =======================================
.define DEBUG_ENTITY_MANAGER        0   ; Exercises the entity allocator

; ======================== SOUND =======================================
.define DEBUG_SOUND_SONG_OF_JOSIAH  0   ; Play the mating call