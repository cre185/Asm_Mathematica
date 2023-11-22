.386
.model flat, stdcall
option casemap: none

include  		calculate.inc
include			macro.inc
include			double.inc
memset			PROTO C :ptr sbyte, :DWORD, :DWORD
sscanf			PROTO C :ptr sbyte, :ptr sbyte, :VARARG
sprintf         PROTO C :ptr sbyte, :ptr sbyte, :VARARG

.data
doubleStr BYTE "%lf",0
longStr BYTE "%lld",0

.code
;-----------------------------------------------------
StrToDouble PROC,
	strAddr: DWORD, numAddr: DWORD
;-----------------------------------------------------
	pushad
	INVOKE sscanf, strAddr, ADDR doubleStr, numAddr
	popad
	ret
StrToDouble ENDP

;-----------------------------------------------------
DoubleNeg PROC,
	numAddr: DWORD
;-----------------------------------------------------
	pushad
	mov eax, [numAddr]
	fld REAL8 PTR [eax]
	fchs
	fstp REAL8 PTR [eax]
	popad
	ret
DoubleNeg ENDP

;-----------------------------------------------------
DoubleAbs PROC,
	numAddr: DWORD
;-----------------------------------------------------
	pushad
	mov eax, [numAddr]
	fld REAL8 PTR [eax]
	fabs
	fstp REAL8 PTR [eax]
	popad
	ret
DoubleAbs ENDP

;-----------------------------------------------------
DoubleAdd PROC,
	doubleAddr1:DWORD, doubleAddr2:DWORD
;-----------------------------------------------------
	pushad
	mov eax, [doubleAddr2]
	fld REAL8 PTR [eax]
	mov eax, [doubleAddr1]
	fld REAL8 PTR [eax]
	fadd
	fstp REAL8 PTR [eax]
	popad
	ret
DoubleAdd ENDP

;-----------------------------------------------------
DoubleSub PROC,
	doubleAddr1:DWORD, doubleAddr2:DWORD
;-----------------------------------------------------
	pushad
	mov eax, [doubleAddr1]
	fld REAL8 PTR [eax]
	mov eax, [doubleAddr2]
	fld REAL8 PTR [eax]
	fsub
	mov eax, [doubleAddr1]
	fstp REAL8 PTR [eax]
	popad
	ret
DoubleSub ENDP

;-----------------------------------------------------
DoubleMul PROC,
	doubleAddr1:DWORD, doubleAddr2:DWORD
;-----------------------------------------------------
	pushad
	mov eax, [doubleAddr2]
	fld REAL8 PTR [eax]
	mov eax, [doubleAddr1]
	fld REAL8 PTR [eax]
	fmul
	fstp REAL8 PTR [eax]
	popad
	ret
DoubleMul ENDP

;-----------------------------------------------------
DoubleDiv PROC,
	doubleAddr1:DWORD, doubleAddr2:DWORD
;-----------------------------------------------------
	pushad
	mov eax, [doubleAddr1]
	fld REAL8 PTR [eax]
	mov eax, [doubleAddr2]
	fld REAL8 PTR [eax]
	fdiv
	mov eax, [doubleAddr1]
	fstp REAL8 PTR [eax]
	popad
	ret
DoubleDiv ENDP

;-----------------------------------------------------
DoubleExp PROC,
	doubleAddr1:DWORD, doubleAddr2:DWORD
;-----------------------------------------------------
	pushad
	mov eax, [doubleAddr1]
	fld REAL8 PTR [eax]
	mov eax, [doubleAddr2]
	mov ecx, [eax+4]
	.IF ecx == 0
		fld1
		mov eax, [doubleAddr1]
		fstp REAL8 PTR [eax]
		popad
		ret
	.ENDIF
	dec ecx
	.WHILE ecx > 0
		mov eax, [doubleAddr1]
		fld REAL8 PTR [eax]
		fmul
		dec ecx
	.ENDW
	mov eax, [doubleAddr1]
	fstp REAL8 PTR [eax]
	popad
	ret
DoubleExp ENDP

;-----------------------------------------------------
DoubleEqu PROC,
	doubleAddr1:DWORD, doubleAddr2:DWORD
;-----------------------------------------------------
	pushad
	mov eax, [doubleAddr1]
	fld REAL8 PTR [eax]
	mov eax, [doubleAddr2]
	fcomp REAL8 PTR [eax]
	fnstsw ax
    sahf
	.IF ZERO?
		mov eax, [doubleAddr1]
		mov BYTE PTR [eax], 1
	.ELSE
		mov eax, [doubleAddr1]
		mov BYTE PTR [eax], 0
	.ENDIF
	popad
	ret
DoubleEqu ENDP

;-----------------------------------------------------
DoubleToStr PROC,
	ansAddr: DWORD
;-----------------------------------------------------
	LOCAL doubleNum:REAL8
	pushad
	mov eax, [ansAddr]
	fld REAL8 PTR [eax]
	fstp doubleNum
	INVOKE memset, ansAddr, 0, MaxBufferSize
	INVOKE sprintf, ansAddr, ADDR doubleStr, doubleNum
	popad
	ret
DoubleToStr ENDP

;-----------------------------------------------------
LongToDouble PROC,
	longAddr: DWORD
;-----------------------------------------------------
	LOCAL tmpArray[128]:BYTE, doubleNum:REAL8, longNum:QWORD
	pushad
	INVOKE memset, ADDR tmpArray, 0, 128
	mov eax, [longAddr]
	lea ebx, longNum
	mov edx, [eax]
	mov [ebx+4], edx
	mov edx, [eax+4]
	mov [ebx], edx
	INVOKE sprintf, ADDR tmpArray, ADDR longStr, longNum
	INVOKE sscanf, ADDR tmpArray, ADDR doubleStr, ADDR doubleNum
	fld doubleNum
	mov eax, [longAddr]
	fstp REAL8 PTR [eax]
	popad
	ret
LongToDouble ENDP

;-----------------------------------------------------
ToDouble PROC,
	dataAddr: DWORD, sizeAddr: DWORD, typeAddr:DWORD
;-----------------------------------------------------
	pushad
	mov esi, [sizeAddr]
    mov edi, [typeAddr]
    mov edx, [dataAddr]
	mov bl, [edi]
	.IF bl == TYPE_DOUBLE
		popad
		ret
	.ELSEIF bl == TYPE_INT
		INVOKE LongToDouble, dataAddr
	.ELSEIF bl == TYPE_BOOL
		mov al, BYTE PTR [edx]
		.IF al == 0
			fldz
		.ELSE
			fld1
		.ENDIF
		fstp REAL8 PTR [edx]
	.ENDIF
	mov BYTE PTR [edx], TYPE_BOOL
	mov WORD PTR [esi], 8
	popad
	ret
ToDouble ENDP

END