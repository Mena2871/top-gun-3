;
; Quick Introduction
; ==================
;  SNES does have a 24-bit memory space, but it is divied up to support
;  the number of devices.
; 
;  Each address refers to a single byte. Each 256-bytes make up a page.
; 
;  PAGE    Byte
;  00        00
; 
;  256 pages make up a bank. So, 1 bank = 65536 bytes = 64 KB
; 
;  BANK PAGE BYTE
;  $00    00    00
; 
;  Then, the entire address space is made of 256 banks.
;  1 bank = 65536 bytes = 64 KB * 256 = 16 MB of mapped regions
; 
; Note on mirrored registered
; ===========================
;  Memory and registers are mapped to the same region no matter the mapping mode.
;  S-WRAM (work ram) is 128KB. That is 2 banks of space. It is mapped to
;  7E and 7F. The first 32 pages is special and mirrored and is accessible
;  from bank 7E, but also $00 and $0E, which gives you $7E1234 = $9A1234 = $001234
;  This gives you the advantage of reading work ram quickly.
; 
;  Mapping Modes
;  =============
;  SNES games were released in 6 different memory mapping modes
;  - LoROM, HiROM, Super MMC, SAS, SFX, and ExHiROM
; 
;  Mode 0 (Mode 20) is LoROM
;  The first half is mapped to bank 80 and the second bank gets mapped to 81
; Bank $80 - $FF
; Page $80 - $FF
; 
; Since it is mirrored, you can reference this (with a caveat due to WRAM)
; Bank $00 - 7E
; 
; CPU Speed
; =========
; $80 and higher are 3.58MHz accessible. 2.68MHz are limited for $00 - $80

.LOROM
.FASTROM

.ROMBANKMAP
    BANKSTOTAL 4
    BANKSIZE $8000
    BANKS 4
.ENDRO

.MEMORYMAP
    DEFAULTSLOT 1
    ; The first 32 pages of work RAM is mirrored across $00 to $40
    SLOT 0    START $0000 SIZE $1FFF "WRAM"
    SLOT 1    START $8000 SIZE $8000 "ROM"
.ENDME

.SNESHEADER
    ; SNES game made in 'merica and Open Source
    ID "SNES"
    NAME "Top Gun 3: Bottom Gun"
    COUNTRY $01
    LICENSEECODE $00
    VERSION $00

    ; We're using pages $00 - $80, which is Mode 1 memory and is slow
    ; at 2.68MHz as opposed to 3.58MHz for the fast rom banks.
    FASTROM
    LOROM

    ; 2 Megabit ROM with no SRAM
    CARTRIDGETYPE $00
    ROMSIZE $08
    SRAMSIZE $00
.ENDSNES