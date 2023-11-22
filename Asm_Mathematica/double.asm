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
	doubleAddr1:DWORD, long2Addr:DWORD
;-----------------------------------------------------
	LOCAL product:QWORD, tmpDouble:QWORD, tmpExp:QWORD
	pushad
	mov ebx, long2Addr
	add ebx, 4 ; ebx points at the lower 32 bits of the exponent
	mov eax, [ebx] ; eax = lower 32 bits of the exponent
	.IF eax == 1
		; do nothing
		popad
		ret
	.ENDIF
	.IF eax == 0
		; put 1 in [doubleAddr1]
		fld1
		fstp REAL8 PTR [doubleAddr1]
		popad
		ret
	.ENDIF
	.IF eax == 0ffffffffh
		fld1
		fld REAL8 PTR [doubleAddr1]
		fdiv
		fstp REAL8 PTR [doubleAddr1]
		popad
		ret
	.ENDIF
	
	fld1
	fstp product ; product = 1

	mov edx, eax
	shr edx, 1
	shl edx, 1
	.IF eax != edx
		; that eax is odd
		mov ecx, eax
		shl ecx, 1
		shr ecx, 1
		.IF ecx == eax
			; that eax represents a positive number
			fld REAL8 PTR [doubleAddr1]
			fstp product
		.ELSE
			; that eax represents a negative number
			fld1
			fld REAL8 PTR [doubleAddr1]
			fdiv
			fstp product
		.ENDIF
	.ENDIF
	; put eax >> 1 in tmpExp
	sar eax, 1
	lea ebx, tmpExp
	add ebx, 4
	mov [ebx], eax
	
	fld REAL8 PTR [doubleAddr1]
	fstp tmpDouble
	INVOKE DoubleExp, ADDR tmpDouble, ADDR tmpExp
	fld product
	fld tmpDouble
	fld tmpDouble
	fmul
	fmul
	fstp REAL8 PTR [doubleAddr1]
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