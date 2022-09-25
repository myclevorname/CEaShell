; Copyright 2015-2021 Matt "MateoConLechuga" Waltz
;
; Redistribution and use in source and binary forms, with or without
; modification, are permitted provided that the following conditions are met:
;
; 1. Redistributions of source code must retain the above copyright notice,
;    this list of conditions and the following disclaimer.
;
; 2. Redistributions in binary form must reproduce the above copyright notice,
;    this list of conditions and the following disclaimer in the documentation
;    and/or other materials provided with the distribution.
;
; 3. Neither the name of the copyright holder nor the names of its contributors
;    may be used to endorse or promote products derived from this software
;    without specific prior written permission.
;
; THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
; AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
; IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
; ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
; LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
; CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
; SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
; INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
; CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
; ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
; POSSIBILITY OF SUCH DAMAGE.

; Running program stuff. A lot of the code is slightly modified from Cesium.

	assume adl=1

	section .text

include 'include/ti84pceg.inc'

	public _runProgram
    extern app
    extern _appMainStart

backupPrgmName := ti.appData

_runProgram:
    push ix
    ld ix, 0
    add ix, sp
    ld c, (ix + 12) ; get asm status
	ld a, (ix + 9) ; get type
    ld hl, (ix + 6) ; get name
    pop ix
	push bc
    ld (ti.OP1), a ; move type to OP1
    ld de, ti.OP1 + 1
    ld bc, 8
    ldir ; move name to OP1
	call _utilBackupPrgmName

	pop bc
    ld a, c
    cp a, 2 ; check for a basic program
    jp z, _basicProgram

_asmProgram:
    call ti.ChkFindSym
    call ti.ChkInRam
    jr z, .inRam ; same as in getPrgmType
    ld hl, 10
    add hl, de
    ld a, c
    ld bc, 0
    ld c, a
    add hl, bc
    ex de, hl

.inRam:
    ex de, hl
    ld de, 0
    ld e, (hl)
    inc hl
    ld d, (hl) ; figure out the size
    inc hl
    ex de, hl
    push de
    call _checkMemSpace
	pop bc
    ret c
	push bc
    ld de, ti.userMem
	push hl
	push de
	ld hl, (ti.asm_prgm_size)
	ex de, hl
	call ti.DelMem
	pop de
	pop hl
    ld (ti.asm_prgm_size), hl
    call ti.InsertMem
    pop hl
	ex de, hl
	call ti.ChkInRam
	jp nz, .continue
	call z, ti.ChkFindSym
	inc de
	inc de

.continue:
	ex de, hl
    inc hl
    inc hl
	ld bc, (ti.asm_prgm_size)
    ld de, ti.userMem
    ldir

_asmProgram.run:
    call ti.DisableAPD
	set	ti.appAutoScroll, (iy + ti.appFlags)
    call _clearUsedMem
	ld hl, _return.error
	call ti.PushErrorHandler
    call ti.userMem
    jp _return

_basicProgram:
	call ti.ChkFindSym
	call ti.ChkInRam
	jr z, .continue
    ld hl, 10
    add hl, de
    ld a, c
    ld bc, 0
    ld c, a
    add hl, bc
	ex de, hl

.continue:
	push de ; preserve data pointer
	inc de
	inc de
	ld a, (de)
	cp a, ti.tExtTok
	jp nz, .notSquished
	inc de
	ld a, (de)
	cp a, ti.tAsm84CePrgm
	jp nz, .notSquished

.squished:
	ld de, ti.basic_prog
	ld hl, ti.OP1
	call ti.Mov9b
	pop de
	push de
	ld bc, 0
	ld a, (de)
	ld c, a
	inc de
	ld a, (de)
	ld b, a
	dec bc
	dec bc
	push bc
	bit 0, c
	jp nz, ti.ErrSyntax
	srl b
	rr c
	push bc
	push bc
	pop hl
	call _checkMemSpace
	pop hl
	pop bc
	ret c
	push bc
	ld de, ti.userMem
	push hl
	push de
	ld hl, (ti.asm_prgm_size)
	ex de, hl
	call ti.DelMem
	pop de
	pop hl
	ld (ti.asm_prgm_size), hl
	call ti.InsertMem
	pop bc
	pop hl ; get data pointer
	push bc
	call ti.SetAToHLU
	cp a, $d0
	jr c, .notRamSquishy
	call ti.ChkFindSym
	ex de, hl

.notRamSquishy:
	inc hl
	inc hl
	inc hl
	inc hl
	ld (ti.begPC), hl
	ld (ti.curPC), hl
	ld de, ti.userMem
	pop bc

.squishMe:
	ld a, b
	or a, c
	jp z, _asmProgram.run
	push hl
	ld hl, (ti.curPC)
	inc hl
	ld (ti.curPC), hl
	pop hl
	dec bc
	ld a, (hl)
	inc hl
	cp a, $3f
	jr z, .squishMe
	push de
	call _utilSquishyCheckByte
	ex de, hl
	ld (hl), 0
	call _utilSquishyConvertByte
	push bc
	sla a
	sla a
	sla a
	sla a
	push af
	ld a, (de)
	call _utilSquishyCheckByte
	call _utilSquishyConvertByte
	ld b, a
	pop af
	add a, b
	ld (hl), a
	pop bc
	ex de, hl
	inc de
	inc hl
	dec bc
	jr .squishMe

.notSquished:
	call ti.RunIndicOn
	call ti.DisableAPD
	pop de
	push de ; preserve data pointer

.temp:
	ld hl, 0
	ld a, (de)
	ld l, a
	inc de
	ld a, (de)
	ld h, a
	dec de
	push hl
	ld hl, tempProgram
	call ti.Mov9ToOP1
	call ti.ChkFindSym
	call nc, ti.DelVarArc
	pop hl
	push hl ; preserve size
	ld a, ti.TempProgObj
	call ti.CreateVar
	inc de
	inc de
	pop bc
	call ti.ChkBCIs0
	jr z, .inRom
	pop hl ; get data pointer
	inc hl
	inc hl
	ldi
	jq po, .inRom
	ldir

.inRom:
	call ti.OP4ToOP1

.inRam:
	set	ti.progExecuting, (iy + ti.newDispF)
	set	ti.cmdExec, (iy + ti.cmdFlags)
	set	ti.allowProgTokens, (iy + ti.newDispF)
	call _clearUsedMem
	ld hl, _return.error
	call ti.PushErrorHandler
	call ti.EnableAPD
	ei
	ld hl, _return
	push hl
	call ti.DrawStatusBar
	jp ti.ParseInp

_return:
	call ti.PopErrorHandler
	xor a, a

_return.error:
	push	af
	res	ti.progExecuting,(iy + ti.newDispF)
	res	ti.cmdExec,(iy + ti.cmdFlags)
	res	ti.allowProgTokens,(iy + ti.newDispF)
	res	ti.textInverse,(iy + ti.textFlags)
	res	ti.onInterrupt,(iy + ti.onFlags)
	call	ti.ReloadAppEntryVecs
	pop	bc
	ld a, b
	or	a,a
	jr	z, .quit
	call	_showError

.quit:
    ld de, (ti.asm_prgm_size)
    or a, a
    sbc hl, hl
    ld (ti.asm_prgm_size), hl
    ld hl, ti.userMem
    call ti.DelMem
    jq _reloadApp

_getRealSize: ; get the real size of the program in OP1, stored in hl
	call ti.ChkFindSym
    push bc
    call ti.ChkInRam
    jr z, .inRam
    ld hl, 10
    add hl, de
    ld a, c
    ld bc, 0
    ld c, a
    add hl, bc
    ex de, hl

.inRam:
    ld hl, 0
    ld a, (de)
    ld l, a
    inc de
    ld a, (de)
    ld h, a
    pop bc
    ld a, c
    ld bc, 0
    ld c, a
    add hl, bc
    ld bc, 9
    add hl, bc
    ret

_checkMemSpace:
    push hl
	ld de, 128
	add	hl, de ; do this for safety like Mateo
	call ti.EnoughMem
	pop	hl
	ret	nc
	scf
	ret

_clearUsedMem:
    xor	a,a
	ld	(ti.appErr1),a
	ld	(ti.kbdGetKy),a
	call	ti.ForceFullScreen
	call	ti.ClrScrn
	call	ti.HomeUp
	ld	hl,ti.pixelShadow
	ld	bc,8400 * 3
	call	ti.MemClear
	call	ti.ClrTxtShd
	ld	hl,ti.textShadow
	ld	de,ti.cmdShadow
	ld	bc,$104
	ldir
	ret

_utilBackupPrgmName:
	ld	hl,ti.OP1
.entry:
	ld	de,backupPrgmName
	jp	ti.Mov9b

_utilSquishyConvertByte:
	sub a, $30
	cp a, 10
	ret c
	sub a, 7
	ret

_utilSquishyCheckByte:
	cp	a,$30
	jp	c,.error
	cp	a,$3A
	jr	nc,.skip
	;sub	a,$30
	ret

.error:
	call ti.DrawStatusBar
	jp ti.ErrSyntax

.skip:
	cp	a,$41
	jp	c,ti.ErrSyntax
	cp	a,$47
	jp	nc,ti.ErrSyntax
	;sub	a,$37
	ret

_showError:
	xor	a,a
	ld	(ti.menuCurrent),a
	ld	a,(ti.errNo)
	cp	a,ti.E_AppErr1
	ret	z			; if stop token, ignore
	call	ti.boot.ClearVRAM
	ld	a,$2d
	ld	(ti.mpLcdCtrl),a
	call	ti.CursorOff
	call	ti.DrawStatusBar
	call	ti.DispErrorScreen
	ld	hl,1
	ld	(ti.curRow),hl
	ld	hl,data_string_quit1
	set	ti.textInverse,(iy + ti.textFlags)
	call	ti.PutS
	res	ti.textInverse,(iy + ti.textFlags)
	call	ti.PutS
	ld	hl, backupPrgmName
	ld	a,(hl)			; check if correct program
	cp	a,ti.ProtProgObj
	jr	nz,.next
	ld	b,a
	ld	a,(ti.basic_prog)
	cp	a,b
	jp	nz,.only_allow_quit

.next:
	xor	a,a
	ld	(ti.curCol),a
	ld	a,2
	ld	(ti.curRow),a
	ld	hl,data_string_quit2
	call	ti.PutS
	call	ti.PutS
	call	ti.GetCSC
.input:
	call	ti.GetCSC
	cp	a,ti.skUp
	jr	z,.highlight_1
	cp	a,ti.skDown
	jr	z,.highlight_2
	cp	a,ti.sk2
	jr	z,.goto
	cp	a,ti.sk1
	jp	z,.exit
	cp	a,ti.skEnter
	jr	z,.get_option
	jr	.input
.highlight_1:
	ld	hl,1
	ld	de,2
	ld	a,'1'
	ld	b,'2'
	jr	.highlight
.highlight_2:
	ld	hl,2
	ld	de,1
	ld	a,'2'
	ld	b,'1'
.highlight:
	push	bc
	push	de
	ld.sis	(ti.curRow and $ffff),hl
	ld	hl,ti.OP6
	ld	(hl),a
	inc	hl
	ld	(hl),':'
	inc	hl
	ld	(hl),0
	dec	hl
	dec	hl
	push	hl
	scf
	sbc	hl,hl
	ld	(ti.fillRectColor),hl
	inc	hl
	ld	de,25
	ld	bc,(55 shl 8) or 96
	call	ti.FillRect
	pop	hl
	set	ti.textInverse,(iy + ti.textFlags)
	call	ti.PutS
	res	ti.textInverse,(iy + ti.textFlags)
	pop	de
	pop	bc
	ld.sis	(ti.curRow and $ffff),de
	ld	hl,ti.OP6
	ld	(hl),b
	call	ti.PutS
	jr	.input
.get_option:
	ld	a,(ti.curRow)
	dec	a
	jr	nz,.exit
.goto:
	;ld	a,return_goto (We'll add this later when we support editing programs)
	ret
.only_allow_quit:
	call	ti.GetCSC
	cp	a,ti.sk1
	jr	z,.exit
	cp	a,ti.skEnter
	jr	z,.exit
	jr	.only_allow_quit
.exit:
	ret

_reloadApp:
	call	ti.ClrAppChangeHook
	res	ti.useTokensInString,(iy + ti.clockFlags)
	res	ti.onInterrupt,(iy + ti.onFlags)
	set	ti.graphDraw,(iy + ti.graphFlags)
	call	ti.ResetStacks
	call	ti.ReloadAppEntryVecs
	call	ti.AppSetup
	set	ti.appRunning,(iy + ti.APIFlg)		; turn on apps
	set	6,(iy + $28)
	res	0,(iy + $2C)				; set some app flags
	set	ti.appAllowContext,(iy + ti.APIFlg)	; turn on apps
	call	_clearUsedMem
	ld	hl,$d1787c				; copy to ram data location
	ld	bc,$fff
	call	ti.MemClear				; zero out the ram data section
	ld hl, _appMainStart				; hl -> start of app
    ld bc, app+256-_appMainStart
	add hl, bc
    push	hl					; de -> start of code for app
	ex	de,hl
	ld	hl,$18					; find the start of the data to copy to ram
	add	hl,de
	ld	hl,(hl)
    ; compare_hl_zero
	add	hl,de
	or	a,a
	sbc	hl,de					; initialize the bss if it exists
	jr	z,.no_bss
	push	hl
	pop	bc
	ld	hl,$15
	add	hl,de
	ld	hl,(hl)
	add	hl,de
	ld	de,$d1787c				; copy it in
	ldir

.no_bss:
	pop	hl
	push	hl
	pop	de
	ld	bc,$1b					; offset
	add	hl,bc
	ld	hl,(hl)
	add	hl,de
	jp	(hl)

tempProgram:
	db	ti.TempProgObj, 'CEASHTMP', 0

data_string_quit1:
	db	'1:',0,'Quit',0
data_string_quit2:
	db	'2:',0,'Goto',0
