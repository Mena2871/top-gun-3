; You must enable this to enable debug features, otherwise they will not be
; compiled into the code.
.define DEBUG_HOOKS 0

; Debug feature flags that can be enabled/disabled
.define DEBUG_PLANE_SPRITE_LOADING  0   ; Renders four planes on the screen and moves them
.define DEBUG_BOSS_SPRITE_LOADING   0   ; Renders a large boss on the screen
.define DEBUG_UI_LOADING            0   ; Render a UI text scrolling
.define DEBUG_MAP                   0   ; Renders a test map

; Debugging hooks that implement the feature flags
.include "debug/debug_game.asm"