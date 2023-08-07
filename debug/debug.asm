; You must enable this to enable debug features, otherwise they will not be
; compiled into the code.
.define DEBUG_HOOKS 1

; Debug feature flags that can be enabled/disabled
; ======================== GAME =======================================
.define DEBUG_PLANE_SPRITE_LOADING  0   ; Renders four planes on the screen and moves them
.define DEBUG_BOSS_SPRITE_LOADING   1   ; Renders a large boss on the screen
.define DEBUG_UI_LOADING            0   ; Render a UI text scrolling
.define DEBUG_SKYSCRAPER_MAP        0   ; Renders a test skyscraper map
.define DEBUG_SYNTHSCRAPER_MAP      1   ; Renders a test synthscraper map

; ======================== VRAM =======================================
.define DEBUG_VRAM_ALLOCATOR        1   ; Exercises the VRAM allocator