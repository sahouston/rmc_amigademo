********** relevant blitter registers **********
;base reg $dff000

BLTDDAT	=0	;result of the last word. used for bob collision detection and 
		;MFM decoding
DMACONR	=2	;bit 14=blitter busy flag

BLTCON0	=$40	;blitter operation setup
BLTCON1	=$42
BLTAFWM	=$44
BLTALWM	=$46

BLTCPTH	=$48	;sources, destination, and size
BLTCPTL	=$4a
BLTBPTH	=$4c
BLTBPTL	=$4e
BLTAPTH	=$50
BLTAPTL	=$52
BLTDPTH	=$54
BLTDPTL	=$56

BLTSIZE	=$58

BLTCON0L=$5a	;ECS/AGA registers
BLTSIZV	=$5c
BLTSIZH	=$5e

BLTCMOD	=$60	;modulos
BLTBMOD	=$62
BLTAMOD	=$64
BLTDMOD	=$66

BLTCDAT	=$70	;data to replace sources
BLTBDAT	=$72
BLTADAT	=$74

DMACON	=$96	;bit 6: enable blitter DMA. bit 10: give blitter priority over
		;the CPU.

