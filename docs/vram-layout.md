
```
       Row = 8KB / Box = 1KB
       Word Size = 16-bit
       ┌─────────────────┬─────────────────┬─────────────────┬─────────────────┐
       │      $000-3FF   │     $400-7FF    |      $800-BFF   │     $C00-FFF    │
       ├────────┬────────┼────────┬────────┼────────┬────────┼────────┬────────┤
       │$000-1FF│200-3FF │400-5FF │600-7FF │$800-9FF│A00-BFF │C00-DFF │E00-FFF │
       ├────┬───┼────────┼────────┼────────┼────────┼────────┼────────┼────────┤
 $0000 │OO  │   │        │        │        │        │        │        │        │
       ├────┴───┼────────┼────────┼────────┼────────┼────────┼────────┼────────┤
 $1000 │T1T1T1T1│T1T1T1T1│T2T2T2T2│T2T2T2T2│T3T3T3T3│T3T3T3T3│        │        │
       ├────────┼────────┼────────┼────────┼────────┼────────┼────────┼────────┤
 $2000 │        │        │        │        │        │        │        │        │
       ├────────┼────────┼────────┼────────┼────────┼────────┼────────┼────────┤
 $3000 │12121212│12121212│12121212│12121212│12121212│12121212│12121212│12121212│
       ├────────┼────────┼────────┼────────┼────────┼────────┼────────┼────────┤
 $4000 │12121212│12121212│12121212│12121212│12121212│12121212│12121212|12121212│
       ├────────┼────────┼────────┼────────┼────────┼────────┼^^^^^^^^┼^^^^^^^^┤
 $5000 │33333333│33333333│33333333│33333333│33333333│33333333│33333333│33333333│
       ├────────┼────────┼────────┼────────┼^^^^^^^^┼^^^^^^^^┤^^^^^^^^┼^^^^^^^^┤
 $6000 │SSSSSSSS│SSSSSSSS│SSSSSSSS│SSSSSSSS│SSSSSSSS│SSSSSSSS│SSSSSSSS│SSSSSSSS│
       ├────────┼────────┼────────┼────────┼────────┼────────┼────────┼────────┤
 $7000 │SSSSSSSS│SSSSSSSS│SSSSSSSS│SSSSSSSS│SSSSSSSS│SSSSSSSS│SSSSSSSS│SSSSSSSS│
       └────────┴────────┴────────┴────────┴────────┴────────┴────────┴────────┘

       [O]   OAM Data        512 Bytes     $0000 - $0100
       Unused                1  KB         $0200 - $0FFF
       [T1]  BG1 Tile Data   2048 Bytes    $1000 - $13FF
       [T2]  BG2 Tile Data   2048 Bytes    $1400 - $17FF
       [T3]  BG3 Tile Data   2048 Bytes    $1800 - $1BFF
       Unused                2  KB         $1C00 - $1FFF
       Unused                8  KB         $2000 - $2FFF
       [12]  BG1/BG2 Chars   16 KB         $3000 - $4FFF (2KB free)
       [3]   BG3/B4 Chars    8  KB         $5000 - $5FFF (4KB free)
       [S]   Sprite Chars    16  KB        $6000 - $7FFF
```