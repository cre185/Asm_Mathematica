.386
.model flat, stdcall
option casemap: none

include  		core.inc
include			macro.inc
include			double.inc
memset			PROTO C :ptr sbyte, :DWORD, :DWORD
sscanf			PROTO C :ptr sbyte, :ptr sbyte, :VARARG
sprintf         PROTO C :ptr sbyte, :ptr sbyte, :VARARG
strcpy			PROTO C :ptr sbyte, :ptr sbyte

.data
doubleStr BYTE "%lf",0
longStr BYTE "%lld",0
infStr BYTE "Inf",0

extern maximumTolerableErr:REAL8

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
		mov esi, [doubleAddr1]
		fstp REAL8 PTR [esi]
		popad
		ret
	.ENDIF
	.IF eax == 0ffffffffh
		fld1
		mov esi, [doubleAddr1]
		fld REAL8 PTR [esi]
		fdiv
		mov esi, [doubleAddr1]
		fstp REAL8 PTR [esi]
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
			mov esi, [doubleAddr1]
			fld REAL8 PTR [esi]
			fstp product
		.ELSE
			; that eax represents a negative number
			fld1
			mov esi, [doubleAddr1]
			fld REAL8 PTR [esi]
			fdiv
			fstp product
		.ENDIF
	.ENDIF
	; put eax >> 1 in tmpExp
	.IF eax != edx && eax != ecx
		; that eax is a negative odd number
		sar eax, 1
		inc eax
	.ELSE
		sar eax, 1
	.ENDIF
	lea ebx, tmpExp
	add ebx, 4
	mov [ebx], eax
	
	mov esi, [doubleAddr1]
	fld REAL8 PTR [esi]
	fstp tmpDouble
	INVOKE DoubleExp, ADDR tmpDouble, ADDR tmpExp
	fld product
	fld tmpDouble
	fld tmpDouble
	fmul
	fmul
	mov esi, [doubleAddr1]
	fstp REAL8 PTR [esi]
	popad
	ret
DoubleExp ENDP

;-----------------------------------------------------
DoubleEqu PROC,
	double1:QWORD, double2:QWORD, ansAddr:DWORD
;-----------------------------------------------------
	pushad
	fld double1
	fld double2
	fsub
	fabs ; |double1 - double2|
	fcomp maximumTolerableErr
	fnstsw ax
    sahf
	.IF CARRY?
		; |double1 - double2| < maximumTolerableErr
		; put 1 in [ansAddr]
		mov ebx, ansAddr
		mov BYTE PTR [ebx], 1
	.ELSE
		; |double1 - double2| >= maximumTolerableErr
		; put 0 in [ansAddr]
		mov ebx, ansAddr
		mov BYTE PTR [ebx], 0
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
	mov eax, [ansAddr]
	.IF DWORD PTR [eax+4] == 7ff00000h && DWORD PTR [eax] == 0
		INVOKE memset, ansAddr, 0, MaxBufferSize
		mov eax, [ansAddr]
		mov BYTE PTR [eax], 43 ; +
		inc eax
		INVOKE strcpy, eax, ADDR infStr
	.ELSEIF DWORD PTR [eax+4] == 0fff00000h && DWORD PTR [eax] == 0
		INVOKE memset, ansAddr, 0, MaxBufferSize
		mov eax, [ansAddr]
		mov BYTE PTR [eax], 45 ; -
		inc eax
		INVOKE strcpy, eax, ADDR infStr
	.ELSE
		INVOKE memset, ansAddr, 0, MaxBufferSize
		INVOKE sprintf, ansAddr, ADDR doubleStr, doubleNum
	.ENDIF
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
	mov BYTE PTR [edi], TYPE_DOUBLE
	mov WORD PTR [esi], 8
	popad
	ret
ToDouble ENDP

END