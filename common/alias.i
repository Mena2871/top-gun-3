INIDISP     = $2100    ; Screen Display Register
OBSEL       = $2101    ; Object Size and Character Size Register
OAMADDL     = $2102    ; OAM Address Registers (Low)
OAMADDH     = $2103    ; OAM Address Registers (High)
OAMDATA     = $2104    ; OAM Data Write Register
BGMODE      = $2105    ; BG Mode and Character Size Register
MOSAIC      = $2106    ; Mosaic Register
BG1SC       = $2107    ; BG Tilemap Address Registers (BG1)
BG2SC       = $2108    ; BG Tilemap Address Registers (BG2)
BG3SC       = $2109    ; BG Tilemap Address Registers (BG3)
BG4SC       = $210A    ; BG Tilemap Address Registers (BG4)
BG12NBA     = $210B    ; BG Character Address Registers (BG1&2)
BG34NBA     = $210C    ; BG Character Address Registers (BG3&4)
BG1HOFS     = $210D    ; BG Scroll Registers (BG1)
BG1VOFS     = $210E    ; BG Scroll Registers (BG1)
BG2HOFS     = $210F    ; BG Scroll Registers (BG2)
BG2VOFS     = $2110    ; BG Scroll Registers (BG2)
BG3HOFS     = $2111    ; BG Scroll Registers (BG3)
BG3VOFS     = $2112    ; BG Scroll Registers (BG3)
BG4HOFS     = $2113    ; BG Scroll Registers (BG4)
BG4VOFS     = $2114    ; BG Scroll Registers (BG4)
VMAIN       = $2115    ; Video Port Control Register
VMADDL      = $2116    ; VRAM Address Registers (Low)
VMADDH      = $2117    ; VRAM Address Registers (High)
VMDATAL     = $2118    ; VRAM Data Write Registers (Low)
VMDATAH     = $2119    ; VRAM Data Write Registers (High)
M7SEL       = $211A    ; Mode 7 Settings Register
M7A         = $211B    ; Mode 7 Matrix Registers
M7B         = $211C    ; Mode 7 Matrix Registers
M7C         = $211D    ; Mode 7 Matrix Registers
M7D         = $211E    ; Mode 7 Matrix Registers
M7X         = $211F    ; Mode 7 Matrix Registers
M7Y         = $2120    ; Mode 7 Matrix Registers
CGADD       = $2121    ; CGRAM Address Register
CGDATA      = $2122    ; CGRAM Data Write Register
W12SEL      = $2123    ; Window Mask Settings Registers
W34SEL      = $2124    ; Window Mask Settings Registers
WOBJSEL     = $2125    ; Window Mask Settings Registers
WH0         = $2126    ; Window Position Registers (WH0)
WH1         = $2127    ; Window Position Registers (WH1)
WH2         = $2128    ; Window Position Registers (WH2)
WH3         = $2129    ; Window Position Registers (WH3)
WBGLOG      = $212A    ; Window Mask Logic registers (BG)
WOBJLOG     = $212B    ; Window Mask Logic registers (OBJ)
TM          = $212C    ; Screen Destination Registers
TS          = $212D    ; Screen Destination Registers
TMW         = $212E    ; Window Mask Destination Registers
TSW         = $212F    ; Window Mask Destination Registers
CGWSEL      = $2130    ; Color Math Registers
CGADSUB     = $2131    ; Color Math Registers
COLDATA     = $2132    ; Color Math Registers
SETINI      = $2133    ; Screen Mode Select Register
MPYL        = $2134    ; Multiplication Result Registers
MPYM        = $2135    ; Multiplication Result Registers
MPYH        = $2136    ; Multiplication Result Registers
SLHV        = $2137    ; Software Latch Register
OAMDATAREAD = $2138    ; OAM Data Read Register
VMDATALREAD = $2139    ; VRAM Data Read Register (Low)
VMDATAHREAD = $213A    ; VRAM Data Read Register (High)
CGDATAREAD  = $213B    ; CGRAM Data Read Register
OPHCT       = $213C    ; Scanline Location Registers (Horizontal)
OPVCT       = $213D    ; Scanline Location Registers (Vertical)
STAT77      = $213E    ; PPU Status Register
STAT78      = $213F    ; PPU Status Register
APUIO0      = $2140    ; APU IO Registers
APUIO1      = $2141    ; APU IO Registers
APUIO2      = $2142    ; APU IO Registers
APUIO3      = $2143    ; APU IO Registers
WMDATA      = $2180    ; WRAM Data Register
WMADDL      = $2181    ; WRAM Address Registers
WMADDM      = $2182    ; WRAM Address Registers
WMADDH      = $2183    ; WRAM Address Registers
JOYSER0     = $4016    ; Old Style Joypad Registers
JOYSER1     = $4017    ; Old Style Joypad Registers
NMITIMEN    = $4200    ; Interrupt Enable Register
WRIO        = $4201    ; IO Port Write Register
WRMPYA      = $4202    ; Multiplicand Registers
WRMPYB      = $4203    ; Multiplicand Registers
WRDIVL      = $4204    ; Divisor & Dividend Registers
WRDIVH      = $4205    ; Divisor & Dividend Registers
WRDIVB      = $4206    ; Divisor & Dividend Registers
HTIMEL      = $4207    ; IRQ Timer Registers (Horizontal - Low)
HTIMEH      = $4208    ; IRQ Timer Registers (Horizontal - High)
VTIMEL      = $4209    ; IRQ Timer Registers (Vertical - Low)
VTIMEH      = $420A    ; IRQ Timer Registers (Vertical - High)
MDMAEN      = $420B    ; DMA Enable Register
HDMAEN      = $420C    ; HDMA Enable Register
MEMSEL      = $420D    ; ROM Speed Register
RDNMI       = $4210    ; Interrupt Flag Registers
TIMEUP      = $4211    ; Interrupt Flag Registers
HVBJOY      = $4212    ; PPU Status Register
RDIO        = $4213    ; IO Port Read Register
RDDIVL      = $4214    ; Multiplication Or Divide Result Registers (Low)
RDDIVH      = $4215    ; Multiplication Or Divide Result Registers (High)
RDMPYL      = $4216    ; Multiplication Or Divide Result Registers (Low)
RDMPYH      = $4217    ; Multiplication Or Divide Result Registers (High)
JOY1L       = $4218    ; Controller Port Data Registers (Pad 1 - Low)
JOY1H       = $4219    ; Controller Port Data Registers (Pad 1 - High)
JOY2L       = $421A    ; Controller Port Data Registers (Pad 2 - Low)
JOY2H       = $421B    ; Controller Port Data Registers (Pad 2 - High)
JOY3L       = $421C    ; Controller Port Data Registers (Pad 3 - Low)
JOY3H       = $421D    ; Controller Port Data Registers (Pad 3 - High)
JOY4L       = $421E    ; Controller Port Data Registers (Pad 4 - Low)
JOY4H       = $421F    ; Controller Port Data Registers (Pad 4 - High)
DMAP0       = $4300    ; Control Register
A1T0L       = $4302    ; DMA Source Address Registers
A1B0        = $4304    ; DMA Source Address Registers
DAS0H       = $4306    ; DMA Size Registers (High)
A2A0L       = $4308    ; HDMA Mid Frame Table Address Registers (Low)
NTLR0       = $430A    ; HDMA Line Counter Register
DMAP1       = $4310    ; Control Register
A1T1L       = $4312    ; DMA Source Address Registers
A1B1        = $4314    ; DMA Source Address Registers
DAS1H       = $4316    ; DMA Size Registers (High)
A2A1L       = $4318    ; HDMA Mid Frame Table Address Registers (Low)
NTLR1       = $431A    ; HDMA Line Counter Register
DMAP2       = $4320    ; Control Register
A1T2L       = $4322    ; DMA Source Address Registers
A1B2        = $4324    ; DMA Source Address Registers
DAS2H       = $4326    ; DMA Size Registers (High)
A2A2L       = $4328    ; HDMA Mid Frame Table Address Registers (Low)
NTLR2       = $432A    ; HDMA Line Counter Register
DMAP3       = $4330    ; Control Register
A1T3L       = $4332    ; DMA Source Address Registers
A1B3        = $4334    ; DMA Source Address Registers
DAS3H       = $4336    ; DMA Size Registers (High)
A2A3L       = $4338    ; HDMA Mid Frame Table Address Registers (Low)
NTLR3       = $433A    ; HDMA Line Counter Register
DMAP4       = $4340    ; Control Register
A1T4L       = $4342    ; DMA Source Address Registers
A1B4        = $4344    ; DMA Source Address Registers
DAS4H       = $4346    ; DMA Size Registers (High)
A2A4L       = $4348    ; HDMA Mid Frame Table Address Registers (Low)
NTLR4       = $434A    ; HDMA Line Counter Register
DMAP5       = $4350    ; Control Register
A1T5L       = $4352    ; DMA Source Address Registers
A1B5        = $4354    ; DMA Source Address Registers
DAS5H       = $4356    ; DMA Size Registers (High)
A2A5L       = $4358    ; HDMA Mid Frame Table Address Registers (Low)
NTLR5       = $435A    ; HDMA Line Counter Register
DMAP6       = $4360    ; Control Register
A1T6L       = $4362    ; DMA Source Address Registers
A1B6        = $4364    ; DMA Source Address Registers
DAS6H       = $4366    ; DMA Size Registers (High)
A2A6L       = $4368    ; HDMA Mid Frame Table Address Registers (Low)
NTLR6       = $436A    ; HDMA Line Counter Register
DMAP7       = $4370    ; Control Register
A1T7L       = $4372    ; DMA Source Address Registers
A1B7        = $4374    ; DMA Source Address Registers
DAS7H       = $4376    ; DMA Size Registers (High)
A2A7L       = $4378    ; HDMA Mid Frame Table Address Registers (Low)
NTLR7       = $437A    ; HDMA Line Counter Register