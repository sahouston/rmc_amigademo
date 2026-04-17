        INCLUDE whdload.i
        INCLUDE whdmacros.i

; ====== Header ======
_base		SLAVE_HEADER				;ws_Security + ws_ID
		dc.w	17				;ws_Version
		dc.w	WHDLF_NoError              	;ws_flags
		dc.l	512*1024                        ;ws_BaseMemSize
		dc.l	0				;ws_ExecInstall
		dc.w	start-_base			;ws_GameLoader
		dc.w	0				;ws_CurrentDir
		dc.w	0				;ws_DontCache
_keydebug	dc.b	0				;ws_keydebug
_keyexit	dc.b	$59				;ws_keyexit = F10
_expmem		dc.l	$0                         	;ws_ExpMem
		dc.w	_name-_base			;ws_name
		dc.w	_copy-_base			;ws_copy
		dc.w	_info-_base			;ws_info
		dc.w    $0               		;kickstart name
		dc.l    $0                              ;Kickstart size (512KB)
		dc.w    $0      			;Kickstart CRC (0 = ignore/auto)
    		dc.w    _config-_base
_config
		dc.b	0
_name	dc.b	"WHDLoad Example",0
_copy	dc.b	"2024 paraj",0
_info	dc.b	"Fixed by you",10
        dc.b    "Version 1.0",10
	dc.b	0

_kickname:
        dc.b    "34005.A500",0 ; Standard WHDLoad Kickstart filename
        EVEN

; ====== Slave ======

LOADDR=$1000

start   ;A0 = resident loader
	lea	_resload(pc),a1
	move.l	a0,(a1)

        move.l	_resload(pc),a2
        ; load the demo binary
        lea     filename(pc),a0
        move.l  #LOADDR,a1      ; load it to this address
        jsr     resload_LoadFile(a2)

        move.l	_resload(pc),a2
        move.l  #LOADDR,a0      ; destination address
        sub.l   a1,a1           ; tags
        jsr     resload_Relocate(a2)

        ; jump to the loaded demo
        move.l  #LOADDR,a5
        jmp     (a5)

filename:
        dc.b    "rmcdemo",0
        even

_resload:
        ds.l    1