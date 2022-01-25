
; RMC Retro Amiga Demo
; https://www.rmcretro.com/
;
; Coding - haiZe (thanks to Photon from Scoopex for 
;	   the AsmSkool youtube series and the Developing 
;          Demo Effects magazine articles)
; Music  - "Logos & Scrollers" by H0ffman
;
; Set tab size 8 for correct alignment
; Assemble with asmtwo

	INCLUDE "PhotonsMiniWrapper1.04!.S"
	INCLUDE "Blitter-Register-List.S"
	INCLUDE "P61-Options.S"

screenw 	= 320
screenh		= 256

; Font bitmap dims
fontw		= 288
fonth		= 130
fontbpls 	= 1
fontwb		= fontw/8
charw		= 32
charh		= 26

; Logo screen area dims
logow   	= 320			;logo width
logoh		= 44			;logo height
logowb  	= logow/8		;byte-width of logo
logobpls	= 3			;logo bitplanes

; Scrolltext screen area dims
scrollw		= screenw+charw		; width includes offscreen space to plot char
scrollh		= charh
scrollwb	= scrollw/8
scrollbpls	= 1
sbwid		= scrollwb*scrollbpls	; byte-width of 1 line, all bpls

; Bob screen area dims
bufferw		= screenw		;buffer width
bufferh		= screenh-logoh-scrollh	;height
bpls		= 4			;bitplanes
bplwb		= bufferw/8		;byte-width of 1 bitplane line
bwid		= bplwb*bpls		;byte-width of 1 line, all bpls

; Starfield
starsvstart	= $58			;vpos to start starfield

MaxBobs	= 8
playMusic = 1

; Demo - routine is called from PhotonsMiniWrapper
; a4: VBR
; a6: Custom Registers Base addr
Demo:					
	bsr Init
	move.w #0,d4			; index into sine table
MainLoop:
  *--- wait for vblank ---*
	move.w #$12c,d0			; Wait until raster is below the Display Window 
	bsr.w WaitRaster		; vpos start: 44, end: 300 ($12c)
	
  *--- play music ---*
	jsr P61_Music			;and call the playroutine manually.

  *--- swap buffers ---*
	movem.l DrawBuffer(PC),a2-a3
	exg a2,a3
	movem.l a2-a3,DrawBuffer	;draw into a2, show a3
  *--- show one... ---*
	move.l a3,a0
	moveq #bplwb,d0
	lea BplPtrs+2,a1
	moveq #bpls-1,d1
	bsr.w PokePtrs
  *--- ...draw into the other ---*

  *--- move starfield sprites ---*
  *--- even lines sprite ---*
	lea StarSpr+1,a1
	bsr MoveSprite

  *--- odd lines sprite ---*
	lea StarSpr2+1,a1
	bsr MoveSprite

  *--- Move scrolltext ---*
	bsr Scrollit

  *--- Plot next scrolltext char ---*
	move.w ScrollCtr(PC),d0		; ScrollCounter
	addq.w #4,d0			; Scrolled 4 pixels
	cmp.w #32,d0			; Don't plot until scrolled 32 px
	blo.s .noplot

	clr.w d0			; Reset ScrollCounter
	move.l ScrollPtr(PC),a0		; Pointer to the char to plot
	bsr PlotChar			; Plot it	
	addq.l #1,a0			; Next char
	cmp.l #ScrollTextWrap,a0	; Check if we're at the end of the
	bne.s .nowrap			; scrolltxt.
	lea Scrolltext,a0		; Yes, go back to the start
.nowrap
	move.l a0,ScrollPtr		; Store ptr to the next char to plot

.noplot:
	move.w d0,ScrollCtr		; Store the ScrollCounter
	
  *--- move start of curves ---*	;the "nose" of the snake
	move.w #1023*2,d3		;keep within curve size, used below
	lea WaveSpeeds(PC),a0
	lea WaveOffsets(PC),a1
	REPT 4
	move.w (a0)+,d0
	add.w d0,(a1)
	and.w d3,(a1)+
	ENDR

  *--- init for bob blits ---*
	bsr WaitBlitter
	; Note: the graphic is only 3 words (48 px) wide
	; but we read an extra word and mask it out to 
	; allow for scrolling using bit shifting.
	; This means the blt src modulos are -2 bytes
	; to correctly re-align with the start of the next
	; row.	
	move.l #$ffff0000,BLTAFWM(a6)	;mask extra word added for shifting
	move.w #-2,BLTAMOD(a6)
	move.w #-2,BLTBMOD(a6)
	move.w #bplwb-6-2,BLTCMOD(a6)	; 6 bytes: 48 pixels
	move.w #bplwb-6-2,BLTDMOD(a6)
	move.w #45*bpls*64+4,d2		; blit size
					; height: (45px * 4 bpls) << 6 
					; width:  4 words (64 px)

  *--- clear old bobs ---*		;the old ones left on this screen
	move.l DrawBuffer(PC),a4
	lea -MaxBobs*4(a4),a4		;Old bob mem locations are stored just
					;before the start of the screen

	REPT MaxBobs
	bsr WaitBlitter
	move.l #$01000000,BLTCON0(a6)
	move.l (a4)+,BLTDPTH(a6)
	beq.s *+6 			; If old blt locations are 0 (first 
					; draw), skip the clear
	move.w d2,BLTSIZE(a6)
	ENDR

	; Setup blit addresses for dest and mask.
	; Bob src is set in bob loop
	move.l DrawBuffer(PC),a1
	; Central bob position
	; y = 120
	; x = bitplanewidth in bytes of all planes / 2 - 4 bytes (half of bob 
	;     width)
	add.l #120*bwid+bplwb/2-4,a1
	lea Mask,a2

  *--- draw new bobs ---*
	lea Sin(PC),a5			;sine table	
	movem.w WaveOffsets(PC),d4-d7	;our offset values into said table
	move.l DrawBuffer(PC),a4
	lea -MaxBobs*4(a4),a4		;Old bob mem locations are stored just
					;before the start of the screen	

  * --- bob loop ---*
	move.w #0,BobIdx		; Which bob are we drawing?	
bobloop:
	lea BobPtrs,a3			; Start of array of pointers to bobs
	; 8 bobs total, we want to draw 4 with the R logo and 4 with Neil.
	; We want to cycle them along the bob snake using BobShift.
	move.w BobIdx,d0
	addi.w BobShift,d0		; Shift the bobs along the snake
	and.l #4, d0			; 3rd bit of BobIdx + BobShift tells us
					; which bob to use
	move.l (a3,d0),a0		; Can use d0 as-is as it's either 0 or
					; 4 which gives us the correct index 
					; into the bob pointer array (0 or 4 
					; byte offset)
	move.w (a5,d4.w),d0		;x
	move.w (a5,d5.w),d1		;y
	add.w d1,d1
	add.w (a5,d6.w),d0		;x
	add.w (a5,d7.w),d1		;y

	asr.w #1,d0			;scaled add for variation
	asr.w #3,d1			;feel free to scale with muls
	sub.w #50,d1

	bsr.w DrawBob
	move.l a3,(a4)+			;save bob's screen addr
	;step to next bob
	lea WaveSteps(PC),a3
	add.w (a3)+,d4
	add.w (a3)+,d5
	add.w (a3)+,d6
	add.w (a3)+,d7
	move.w #1023*2,d3		;keep within curve size, used below
	and.w d3,d4
	and.w d3,d5
	and.w d3,d6
	and.w d3,d7
	addi.w #1,BobIdx
	cmpi.w #MaxBobs,BobIdx
	blt bobloop
  * --- end bob loop --- *

	add.w #1,FrameCounter		; FrameCounter++
	cmp.w #10,FrameCounter		; Test if 10 frames have elapsed
	bne testMouse
					; Yes, shift the bobs
	move.w #0,FrameCounter 		; Reset frame counter
	add.w #1,BobShift		; Shift bobs
	cmp.w #8,BobShift	
	bne testMouse
	move.w #0,BobShift		; Reset bob shift

	; Cycle the logo palette
	lea LogoColors,a0
	move.l LogoColorOffset,d0
	addq.l #2,d0			; increment offset (1 word, 2 bytes)
	cmp.l #14,d0			; only 7 colors (14 bytes)
	bne .noresetoffset
	moveq.l #0,d0			; if 8 reset to 0
.noresetoffset:
	move.l d0,LogoColorOffset	; Store incremented offset
	add.l d0,a0			; Add offset to color array ptr
	lea LogoPalette+6,a1		; 1st non background color addr 
	moveq #7-1,d1
.palloop:	
	move.w (a0)+,(a1)		; Move logo color into palette
	addq.l #4,a1
	cmp.l #LogoColorsEnd,a0
	bne .nowrap
	lea LogoColors,a0		; We've come to the end of the
					; logo colors, wrap back to start
.nowrap:	
	dbf d1,.palloop

  *--- main loop end ---*
testMouse:
	;move.w #$323,$180(a6)		;show rastertime left down to $12c
	btst #6,$bfe001			;Left mouse button not pressed?
	bne.w MainLoop			;then loop	
  *--- exit ---*
  	IFNE playMusic 			; playMusic ne 0
	movem.l d0-a6,-(sp)
	jsr P61_End
	movem.l (sp)+,d0-a6  
	ENDC
	rts

********** Demo Routines **********

; Init - One time initialization code
; a4: VBR
; a6: Custom Registers Base addr
Init:
	move.w #$87e0,DMACON(a6)
    *--- clear last bob ptrs ---*
	lea LastBobs,a0
	lea LastBobs2,a1
	moveq #MaxBobs-1,d0
.l0:	clr.l (a0)+
	clr.l (a1)+
	dbf d0,.l0
    *--- clear screens ---*
	lea Screen,a1
	move.w #bufferw,d0
	move.w #bufferh,d1
	move.w #bpls,d2	
	bsr.w ClearScreen

	lea Screen2,a1
	move.w #bufferw,d0
	move.w #bufferh,d1
	move.w #bpls,d2	
	bsr.w ClearScreen

	lea ScrollArea,a1
	move.w #scrollw,d0
	move.w #scrollh,d1
	move.w #scrollbpls,d2
	bsr.w ClearScreen
	bsr WaitBlitter

	IFNE playMusic 		; playMusic ne 0
    *--- Call P61_Init ---*
	movem.l d0-a6,-(sp)

	lea Module1,a0
	sub.l a1,a1
	sub.l a2,a2
	moveq #0,d0
	jsr P61_Init

	movem.l (sp)+,d0-a6
	ENDC

    *--- init sprites ---*
	; Setup copper list to write sprite
	; pointers each frame.
	lea SprP,a1			; Pos in copper list that 
					; writes sprite pointers
	lea StarSpr,a0			; The sprite address in chip mem
	move.l a0,d1
	moveq #2-1,d0			; 2 sprites
.sprpl:
	swap d1
	move.w d1,2(a1)			; sprite address high bits
	swap d1
	move.w d1,6(a1)			; sprite address low bits
	addq.w #8,a1
	add.l #(StarSpr2-StarSpr),d1	; Move to next sprite
	dbf d0,.sprpl			

	; Sprites can't be turned off. Unused sprites are just
	; empty data lists: dc.w 0,0
	lea NullSpr,a0
	move.l a0,d1
	moveq #6-1,d0			; 6 unused sprites
.sprpl2:
	swap d1
	move.w d1,2(a1)
	swap d1
	move.w d1,6(a1)
	addq.w #8,a1
	dbf d0,.sprpl2

    *--- even lines sprites ---*	
    	; Init the sprite data 
	lea StarSpr,a1
	moveq #$58,d0			; $58 for below logo
	bsr InitSpriteData

    *--- odd lines sprites ---*
	lea StarSpr2,a1
	moveq #$59,d0			; $59 for below logo
	bsr InitSpriteData

    *--- setup and start copper ---*
	; Setup bitplane pointers for logo area
	lea Logo,a0
	moveq #logowb,d0
	lea LogoBplPtrs+2,a1
	moveq #logobpls-1,d1
	bsr.w PokePtrs

	; Setup bitplane pointers for bob area
	lea Screen,a0
	moveq #bplwb,d0
	lea BplPtrs+2,a1
	moveq #bpls-1,d1
	bsr.w PokePtrs	

	; Setup bitplane pointers for scrolltext area
	lea ScrollArea,a0
	moveq #scrollwb,d0
	lea ScrollBplPtrs+2,a1
	moveq #scrollbpls-1,d1
	bsr.w PokePtrs

	move.l #Copper,$80(a6)
	rts

; *** InitSpriteData ***
; a1: ptr to SpriteData array to initialize
; d0: sprint start vpos
InitSpriteData:
	; Init the sprite data 
	moveq #23-1,d7			; reps, calculated from starfield height
.l1:
	lea StarSpeeds,a2
	moveq #4-1,d5
.l2:	
	moveq #0,d2			;d2 to contain E8 and L8 bits
	move.b d0,(a1)+			;vstart
	btst #8,d0
	beq .eaboveff
	bset #2,d2			;vstart below ff, set E8 bit
.eaboveff	
	move.b (a2)+,d1			;read star speed
	add.b d1,(a1)+			;add speed to hpos
	addq.w #1,d0			;increase vstop value
	move.b d0,(a1)+			;vstop
	btst #8,d0
	beq .laboveff
	bset #1,d2			;vstart below ff, set L8 bit
.laboveff
	addq.w #1,d0			;increase vstop value
	move.b d2,(a1)+
	addq.w #4,a1			;skip to next sprite control words
	dbf d5,.l2
	dbf d7,.l1
	rts

; *** MoveSprite ***
; a1: ptr to SpriteData array
MoveSprite:
	moveq #23-1,d7
.movel:	
	addq.b #1,(a1)			;add speed to hpos
	addq.w #8,a1			;skip to next sprite control words
	addq.b #2,(a1)			;add speed to hpos
	addq.w #8,a1			;skip to next sprite control words
	addq.b #1,(a1)			;add speed to hpos
	addq.w #8,a1			;skip to next sprite control words
	addq.b #3,(a1)			;add speed to hpos
	addq.w #8,a1			;skip to next sprite control words

	dbf d7,.movel
	rts

; *** PlotChar ***
; blt a character from the font to the scrolltext 
; offscreen area
; a0: ptr to ascii value of char
PlotChar:
row 	= fontw*fontbpls*charh/8
col 	= charw/8
plotY 	= 0
plotX 	= scrollw-charw

	movem.l d0-a6,-(sp)
	lea $dff000,a6
	bsr WaitBlitter

	moveq #0,d0
	move.b (a0),d0			;ASCII value

	sub.w #32,d0
	lea FontTbl(PC),a0		;Get position of char
	move.b (a0,d0.w),d0		;in the font bitmap
	divu #9,d0			;row
	move.l d0,d1
	swap d1				;remainder (column)	

	mulu #row,d0
	mulu #col,d1

	add.l d1,d0			;offset into font bitmap
	add.l #Font,d0

	move.l #$09f00000,BLTCON0(a6)
	move.l #$ffffffff,BLTAFWM(a6)
	move.l d0,BLTAPTH(a6)
	lea ScrollArea,a1
	add.l #sbwid*plotY+plotX/8,a1	;Blt Dest
	move.l a1,BLTDPTH(a6)
	move.w #fontwb-col,BLTAMOD(a6)
	move.w #scrollwb-col,BLTDMOD(a6)

	move.w #charh*fontbpls*64+charw/16,BLTSIZE(a6) ; /16 because w in words
	movem.l (sp)+,d0-a6
	rts

; *** Scrollit ***
Scrollit:
bltoffs	=0
blth	=charh
bltw	=scrollw/16
bltskip	=0				;modulo
brcorner=blth*scrollwb*scrollbpls-2	;bottom right corner

	movem.l d0-a6,-(sp)
	lea $dff000,a6
	bsr WaitBlitter

	move.l #$49f00002,BLTCON0(a6)	; Shift by 4 pixels
	move.l #$ffffffff,BLTAFWM(a6)
	move.l #ScrollArea+bltoffs+brcorner,BLTAPTH(a6)
	move.l #ScrollArea+bltoffs+brcorner,BLTDPTH(a6)
	move.w #bltskip,BLTAMOD(a6)
	move.w #bltskip,BLTDMOD(a6)

	move.w #blth*scrollbpls*64+bltw,BLTSIZE(a6)
	movem.l (sp)+,d0-a6
	rts


; *** DrawBob ***
; a0: bob
; a1: screen
; a2: mask
; d0: x (word)
; d1: y (word)
; d2: blit size (word)
DrawBob:
    *--- calc shift ---*
	moveq #15,d3
	and.w d0,d3
	add.w d3,d3
	add.w d3,d3
    *--- calc screen addr ---*
	asr.w #4,d0
	add.w d0,d0			;horizontal byte offset
	muls #bwid,d1			;vertical line offset, table possible
	add.w d0,d1
	lea (a1,d1.w),a3
    *--- last:poke only nec. regs ---*
	bsr WaitBlitter
	move.l XtblCookie(PC,d3.w),BLTCON0(a6)	;shifts+minterm
	move.l a3,BLTCPTH(a6)		;C dest
	move.l a0,BLTBPTH(a6)		;B mask (movem.l possible for these 3)
	move.l a2,BLTAPTH(a6)		;A src
	move.l a3,BLTDPTH(a6)		;D dest
	move.w d2,BLTSIZE(a6)		;blit size
	rts				;a3=screen address of bob

XtblCookie:				;look up BLTCON0+1 from X-shift
	dc.l $0fca0000,$1fca1000,$2fca2000,$3fca3000
	dc.l $4fca4000,$5fca5000,$6fca6000,$7fca7000
	dc.l $8fca8000,$9fca9000,$afcaa000,$bfcab000
	dc.l $cfcac000,$dfcad000,$efcae000,$ffcaf000	


PokePtrs:				;Generic, poke ptrs into copper list
.bpll:	move.l a0,d2
	swap d2
	move.w d2,(a1)			;high word of address
	move.w a0,4(a1)			;low word of address
	addq.w #8,a1			;skip two copper instructions
	add.l d0,a0			;next ptr
	dbf d1,.bpll
	rts

; *** ClearScreen ***
; a1: address of screen buffer to clear
; d0: bufferw
; d1: bufferh
; d2: number of bitplanes
ClearScreen:
	mulu.w d2,d1			; d1 = bufferh * bpls
	lsl.w #6,d1
	lsr.w #4,d0			; bufferw / 16 (width in words)
	add.w d0,d1
	bsr WaitBlitter
	clr.w $66(a6)			;destination modulo
	move.l #$01000000,$40(a6)	;set operation type in BLTCON0/1
	move.l a1,$54(a6)		;destination address
	move.l d1,$58(a6)
	rts

********** PLAYROUTINE CODE **********	
	even
Playrtn:
	include "P6112/P6112-Play.i"	

********** Fastmem Data **********

DrawBuffer:	dc.l Screen2		;pointers to buffers to be swapped
ViewBuffer:	dc.l Screen

FrameCounter:	dc.w 0
BobShift:	dc.w 0			; Shift bobs by this amount along
					; the snake
BobPtrs:	
		dc.l	RBob		; Pointer to the R logo bob
		dc.l	NeilBob		; Pointer to the Neil bob
BobIdx:		dc.w 0			; Index into BobPtrs (used in bob draw
					; loop as no registers free)

; FontTbl maps char to position in font
FontTbl:	dc.b  43,38
		blk.b 5,0
		dc.b  42
		blk.b 4,0
		dc.b  37,40,36,41
		dc.b  26,27,28,29,30,31,32,33,34,35
		blk.b 5,0
		dc.b  39,0
		dc.b  0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21
		dc.b  22,23,24,25
		EVEN

ScrollPtr:
		dc.l ScrollText
ScrollText:
		dc.b "WELCOME TO RMC RETRO!!! THE CAVE IS NOW OPEN AND WE INVITE YOU "
		dc.b "TO ENJOY THE COLLECTION OF AMAZING RETRO COMPUTERS, CONSOLES, GAMES, MAGAZINES "
		dc.b "AND MORE! VISIT RMCRETRO.COM TO CATCH UP ON RMC VIDEOS AND FIND OUT MORE. "
		dc.b "    THIS RETRO AMIGA DEMO WAS CODED BY HAIZE AND THE MUSIC IS THE TRACK "
		dc.b "LOGOS AND SCROLLERS BY THE LEGENDARY DJ H0FFMAN. SEARCH GITHUB FOR RMC AMIGADEMO "
		dc.b "TO GET THE CODE. A BIG THANKS TO PHOTON OF SCOOPEX FOR HIS ASMSKOOL SERIES ON "
		dc.b "YOUTUBE, KEEPING AMIGA CODING ALIVE IN 2022!    "
		dc.b "SHOUT OUT TO THE BOSSMAN NEIL, RICHARD AT HEBER, MARK FIXES "
		dc.b "STUFF, AMIGOS RETRO GAMING, STOO AND THE WHOLE RMC DISCORD POSSE. "
		dc.b "   WE'VE GOT SOME MESSAGES FROM DISCORD - WSTLR SAYS 'CULT OF THE SCOTCH EGG 0WNS. "
		dc.b "ACCEPT NO IMITATIONS. WE ARE WORLDS NUMBER ONE!', RICH SAYS 'THEM THERE "
		dc.b "LEGIONSOFSORBUMS ARE PROPER LAME!' AND GARY SCHOLZ SAYS 'BIG UP DA PORK PIE "
		dc.b "MASSIVE!'. DID HE MEAN MASSIVE PORK PIE?"
		dc.b "    WE HOPE YOU ARE ENJOYING THIS SLICE OF AMIGA NOSTALGIA. "
		dc.b "IF YOU WANT TO GET IN TOUCH CONNECT TO OUR 2400 BAUD BBS ON..... "
		dc.b "NO WAIT.... THE CONTACT PAGE ON RMCRETRO.COM WOULD BE EASIER, OR EMAIL ME  "
		dc.b "HAIZE AT SHOUSTON.NET     OVER AND OUT...."
		blk.b bufferw/32,' '
ScrollTextWrap:
		EVEN

ScrollCtr:
		dc.w 0

WaveSpeeds:	;all numbers must be even, since the sine values are word size.
		dc.w -9*2,5*2,7*2,-11*2
WaveOffsets:
		dc.w 400*2,300*2,200*2,100*2
WaveSteps:
		dc.w -75*2,-36*2,57*2,-105*2

StarSpeeds:
		dc.b 1,2,1,3

LogoColors:
        	dc.w $03c2,$02bc,$023c,$0c2d,$0e03,$0ed2,$0f80			
LogoColorsEnd:
LogoColorOffset:dc.l 0

Sin:
	INCBIN "Sine1024w.bin"		;amplitude 512 for precision
SinEnd:

*******************************************************************************
	SECTION ChipData,DATA_C		;declared data that must be in chipmem
*******************************************************************************
; Sprites for starfield
StarSpr:
.x:	SET 1
	REPT 23
.tmpx:	SET ((.x*$751+$deadbeef)/(.x&$55))&$ff
	dc.w $2c00+.tmpx,$2d00	;Vstart.b,Hstart/2.b,Vstop.b,%A0000SEH
	dc.w $8000,$0000
.x:	SET (.x+2)&$ffff
.tmpx:	SET ((.x*$753+$eadbeefd)/(.x&$55))&$ff
	dc.w $2c00+.tmpx,$2d00	;Vstart.b,Hstart/2.b,Vstop.b,%A0000SEH
	dc.w $0000,$8000
.x:	SET (.x+4)&$ffff
.tmpx:	SET ((.x*$755+$adbeefde)/(.x&$55))&$ff
	dc.w $2c00+.tmpx,$2d00	;Vstart.b,Hstart/2.b,Vstop.b,%A0000SEH
	dc.w $8000,$0000
.x:	SET (.x+8)&$ffff
.tmpx:	SET ((.x*$757+$dbeefdea)/(.x&$55))&$ff
	dc.w $2c00+.tmpx,$2d00	;Vstart.b,Hstart/2.b,Vstop.b,%A0000SEH
	dc.w $c000,$c000
.x:	SET (.x+16)&$ffff
	ENDR
	dc.w 0,0

StarSpr2:
.x:	SET $77
	REPT 23
.tmpx:	SET ((.x*$751+$deadbeef)/(.x&$55))&$ff
	dc.w $2c00+.tmpx,$2d00	;Vstart.b,Hstart/2.b,Vstop.b,%A0000SEH
	dc.w $8000,$0000
.x:	SET (.x+2)&$ffff
.tmpx:	SET ((.x*$753+$eadbeefd)/(.x&$55))&$ff
	dc.w $2c00+.tmpx,$2d00	;Vstart.b,Hstart/2.b,Vstop.b,%A0000SEH
	dc.w $0000,$8000
.x:	SET (.x+4)&$ffff
.tmpx:	SET ((.x*$755+$adbeefde)/(.x&$55))&$ff
	dc.w $2c00+.tmpx,$2d00	;Vstart.b,Hstart/2.b,Vstop.b,%A0000SEH
	dc.w $8000,$0000
.x:	SET (.x+8)&$ffff
.tmpx:	SET ((.x*$757+$dbeefdea)/(.x&$55))&$ff
	dc.w $2c00+.tmpx,$2d00	;Vstart.b,Hstart/2.b,Vstop.b,%A0000SEH
	dc.w $c000,$c000
.x:	SET (.x+16)&$ffff
	ENDR
	dc.w 0,0

NullSpr:
	dc.w 0,0

Copper:
	dc.w $1fc,0			;Slow fetch mode, remove if AGA demo.
	dc.w $8e,$2c81			;display window left, top: 129,44
	dc.w $90,$2cc1			;and right, bottom: 448,300 (320x256)
	dc.w $92,$38			;Standard bitplane dma fetch start
	dc.w $94,$d0			;and stop for standard screen.

	dc.w $106,$0c00			;(AGA compat. if any Dual Playf. mode)
	dc.w $102,0			;Scroll register (and playfield pri)
	dc.w $104,0			;Sprites behind playfields

	dc.w $1a2,$99b			;sprite colors
	dc.w $1a4,$cce
	dc.w $1a6,$fff
SprP:
	dc.w $120,0
	dc.w $122,0
	dc.w $124,0
	dc.w $126,0
	dc.w $128,0
	dc.w $12a,0
	dc.w $12c,0
	dc.w $12e,0
	dc.w $130,0
	dc.w $132,0
	dc.w $134,0
	dc.w $136,0
	dc.w $138,0
	dc.w $13a,0
	dc.w $13c,0
	dc.w $13e,0

	; *** Screen area for logo ***
LogoPalette:
	; Logo palette
        dc.w $0180,$0000,$0182,$03c2,$0184,$02bc,$0186,$023c
        dc.w $0188,$0c2d,$018a,$0e03,$018c,$0ed2,$018e,$0f80	

LogoBplPtrs:
	dc.w $e0,0
	dc.w $e2,0
	dc.w $e4,0
	dc.w $e6,0
	dc.w $e8,0
	dc.w $ea,0
	dc.w $ec,0
	dc.w $ee,0
	dc.w $108,logowb*(logobpls-1)		; modulos
	dc.w $10a,logowb*(logobpls-1)
	dc.w $100,logobpls*$1000+$200		;enable bitplanes

	; *** Screen area for bobs ***

	; 1st scanline at position 44 ($2c)
	; Logo is 44 ($2c) px high
	; Scanline after logo is at $2c+$2c = $58
	dc.w $5805,$fffe		;wait for scanline after logo

BplPtrs:
	dc.w $e0,0
	dc.w $e2,0
	dc.w $e4,0
	dc.w $e6,0
	dc.w $e8,0
	dc.w $ea,0
	dc.w $ec,0
	dc.w $ee,0
	dc.w $108,bplwb*(bpls-1)		;modulos
	dc.w $10a,bplwb*(bpls-1)
	dc.w $100,bpls*$1000+$200		;enable bitplanes

	; Bobs palette
	dc.w $0180,$0000,$0182,$0ddd,$0184,$08be,$0186,$0fff
	dc.w $0188,$069b,$018a,$0d97,$018c,$0b65,$018e,$09cf
	dc.w $0190,$0eb9,$0192,$0853,$0194,$0579,$0196,$0356
	dc.w $0198,$099a,$019a,$0877,$019c,$0544,$019e,$0e00

	; *** Screen area for scrolltest ***

	; Wait for the scanline after the bob area (scrolltext area)
	; bob area height = screen height - logo height - scrolltext height
	; 256-44-26 = 186 ($BA)
	; Scanline after bob area = $58 + $BA = $112
	; Need to wait for $ff then $12
	dc.w $ffdf,$fffe		;wait for VPOS>$ff
	dc.w $1205,$fffe

ScrollBplPtrs:
	dc.w $e0,0
	dc.w $e2,0
	dc.w $e4,0
	dc.w $e6,0
	dc.w $e8,0
	dc.w $ea,0
	dc.w $ec,0
	dc.w $ee,0
	dc.w $108,scrollwb*(scrollbpls-1)+charw/8 ;modulos - takes offscreen 32
	dc.w $10a,scrollwb*(scrollbpls-1)+charw/8 ;pixels for char into consideration
	dc.w $100,scrollbpls*$1000+$200		;enable bitplanes	

	dc.w $0180,$0000,$0182,$0f33

	dc.w $ffff,$fffe		;magic value to end copperlist
CopperE:

Logo:
	INCBIN "media/RMCthecave320x44x3.raw"

NeilBob:
	INCBIN "media/LowPixelNeil_48x45.raw"

RBob:
	INCBIN "media/LowPixelR_48x45.raw"

Mask:
	INCBIN	"media/bob.mask"

Font:
	INCBIN "media/fippsfont.288x130x1.raw"

Module1:
	incbin "media/P61.logosandscrollers"

*******************************************************************************
	SECTION ChipBuffers,BSS_C	;BSS doesn't count toward exe size
*******************************************************************************

LastBobs:
	ds.l MaxBobs			; Store addresses of previous bob
					; locations
Screen:	
	ds.b bufferh*bwid		; Define storage for buffer 1, exclude
					; height of logo
LastBobs2:
	ds.l MaxBobs			; Store addresses of previous bob
					; locations
Screen2:
	ds.b bufferh*bwid		; two buffers

ScrollArea:
	ds.b scrollh*sbwid		; buffer to draw scrolltext to.
					; Unlike the bob area this is not
					; double buffered

	END

; Everything past this point treated as comments

;Channel	Function
;A		Bob
;B		Bob Mask
;C		Destination playfield
;D		Destination playfield

	1111
	ABCD -> D

0	000	0
1	001	1
2	010	0
3	011	1
4	100	0
5	101	0
6	110	1
7	111	1


%11001010	=$ca