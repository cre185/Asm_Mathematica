.386
.model flat, stdcall
option casemap: none

include         windows.inc
include         gdi32.inc
includelib      gdi32.lib
include         user32.inc
includelib      user32.lib
include         kernel32.inc
includelib      kernel32.lib
include         masm32.inc
includelib      masm32.lib
include         msvcrt.inc
includelib      msvcrt.lib
include         shell32.inc
includelib      shell32.lib
include  		calculate.inc
include			macro.inc
include			mathStack.inc
include			longInt.inc
strncpy			PROTO C :ptr sbyte, :ptr sbyte, :DWORD
strcpy			PROTO C :ptr sbyte, :ptr sbyte
strcat			PROTO C :ptr sbyte, :ptr sbyte
memset			PROTO C :ptr sbyte, :DWORD, :DWORD
strlen			PROTO C :ptr sbyte

.data
recvBuffer BYTE MaxBufferSize DUP(0)
ansBuffer BYTE MaxBufferSize DUP(0)
public recvBuffer, ansBuffer

OperatorTable BYTE "* / ^                          ",0
			  BYTE "+ -                            ",0
			  BYTE "ABS NEG                        ",0
; Type: lower bit 0 for binary, 1 for unary; second bit 0 for operator, 1 for function
OperatorType  BYTE " 0 0 0                         ",0
			  BYTE " 0 0                           ",0
			  BYTE "   3   3                       ",0
OperatorList BYTE OperatorListLength DUP(0)
OpTypeList   BYTE OperatorListLength DUP(0)

TestTitle BYTE "test",0
TestText BYTE "reached here!",0
FailureText BYTE "!Calculation failed!",0
FailureSign BYTE 0
public FailureSign

CalCount DWORD 0
public CalCount

EXTERN calculationStack:BYTE, calculationStackTop:DWORD

.code
;-----------------------------------------------------
ParseFailure PROC
; Generate an output representing that some exception 
; occured in the parsing process
;-----------------------------------------------------
	INVOKE MessageBox, NULL, ADDR FailureText, ADDR FailureText, MB_ICONERROR+MB_OK
	mov FailureSign, 1
	ret
ParseFailure ENDP

.code
;-----------------------------------------------------
UpdateOperator PROC,
	index:DWORD
; Update the OperatorList using the designated line of OperatorTable
;-----------------------------------------------------
	pushad
	mov eax, index
	mov edx, OperatorListLength
	mul edx
	mov ecx, offset OperatorTable
	add ecx, eax
	INVOKE strncpy, ADDR OperatorList, ecx, OperatorListLength 
	mov eax, index
	mov edx, OperatorListLength
	mul edx
	mov ecx, offset OperatorType
	add ecx, eax
	INVOKE strncpy, ADDR OpTypeList, ecx, OperatorListLength 
	popad
	ret
UpdateOperator ENDP

;-----------------------------------------------------
IsOperator PROC,
	array:DWORD, index:DWORD
; Examine whether the value array[index] is (or is not) an operator
; returns length and start of operator or 0 if is not
;-----------------------------------------------------
	LOCAL len:DWORD, j:DWORD
	pushad
	mov ecx, 0
	mov ebx, array
	add ebx, index
	mov al, BYTE PTR [OperatorTable]
	.WHILE ecx < OperatorTableLength
		.IF al == BYTE PTR [ebx] && al != 0
			pushad
			mov esi, ecx
			dec ecx
			.IF BYTE PTR [OperatorTable+ecx] == 32 || BYTE PTR [OperatorTable+ecx] == 0
				mov ecx, 0
				.REPEAT
					inc ecx
					inc esi
					mov ebx, array
					add ebx, index
					mov al, BYTE PTR [ebx+ecx]
					mov dl, BYTE PTR [OperatorTable+esi]
				.UNTIL dl == 32 || dl != al
				.IF dl == 32
					mov len, ecx
					sub esi, ecx
					mov j, esi
					popad
					popad
					mov eax, len
					mov ebx, j
					ret
				.ENDIF
			.ENDIF
			popad
			.REPEAT
				inc ecx
				mov al, BYTE PTR [OperatorTable+ecx]
			.UNTIL al == 32
		.ENDIF
		inc ecx
		mov al, BYTE PTR [OperatorTable+ecx]
	.ENDW
	popad
	mov eax, 0
	ret
IsOperator ENDP

;-----------------------------------------------------
InsertChar PROC,
	array:DWORD, index:DWORD, char:BYTE
; Insert the char into the array at the disignated place
;-----------------------------------------------------
	LOCAL tmp[MaxBufferSize]:BYTE 
	pushad
	INVOKE memset, ADDR tmp, 0, MaxBufferSize
	INVOKE strncpy, ADDR tmp, array, index
	mov eax, index
	mov dl,char
	mov [tmp+eax], dl
	mov ebx, array
	add ebx, index
	INVOKE strcat, ADDR tmp, ebx
	INVOKE strcpy, array, ADDR tmp
	popad
	ret
InsertChar ENDP

;-----------------------------------------------------
RemoveChar PROC,
	array:DWORD, index:DWORD
; Remove the char from the array at the disignated place
;-----------------------------------------------------
	LOCAL tmp[MaxBufferSize]:BYTE 
	pushad
	INVOKE memset, ADDR tmp, 0, MaxBufferSize
	INVOKE strncpy, ADDR tmp, array, index
	mov ebx, array
	add ebx, index
	inc ebx
	INVOKE strcat, ADDR tmp, ebx
	INVOKE strcpy, array, ADDR tmp
	popad
	ret
RemoveChar ENDP

;-----------------------------------------------------
RightBrace PROC,
	array:DWORD, i:DWORD, j:DWORD, k:DWORD 
; Add braces on the right side
; only used in AddBrace PROC
;-----------------------------------------------------
	; right
	mov ecx, i
	add ecx, k
	mov edx, array
	mov bl, BYTE PTR [edx+ecx]
	.IF bl == 40 ; (
		mov ecx, i
		add ecx, k
		inc ecx
		mov eax, 1
		mov bl, BYTE PTR [edx+ecx]
		.WHILE bl != 0 && eax > 0
			.IF bl == 40
				inc eax
			.ELSEIF bl == 41 ; )
				dec eax
			.ENDIF
			inc ecx
			mov bl, BYTE PTR [edx+ecx]
		.ENDW
		.IF eax != 0
			; exception
		.ENDIF
		INVOKE InsertChar, array, ecx, 41
	.ELSE
		mov ecx, i
		add ecx, k
		dec ecx
		mov eax, 0
		.REPEAT
			inc ecx
			mov bl, BYTE PTR [edx+ecx]
			; should pass: 65-90 functions (as a whole, so special treat 91'[', 93']'), 48-57 numbers and 97-122 values, 32' '
			.IF bl == 91
				inc eax
				inc ecx
				mov bl, BYTE PTR [edx+ecx]
			.ELSEIF bl == 93
				.IF eax == 0
					INVOKE InsertChar, array, ecx, 41
					ret
				.ENDIF
				dec eax
			.ENDIF
		.UNTIL ecx >= MaxBufferSize || ((bl < 48 || bl > 57) && (bl < 65 || bl > 90) && bl != 32 && (bl < 97 || bl > 122) && bl != 91 && bl != 93 && eax == 0)
		INVOKE InsertChar, array, ecx, 41
	.ENDIF
	ret
RightBrace ENDP

;-----------------------------------------------------
AddBrace PROC,
	array:DWORD, i:DWORD, j:DWORD, k:DWORD 
; Add braces on both side of an operator
; i: position of operator in buffer, j: position of op in oplist k: op length
;-----------------------------------------------------
	pushad
	mov ecx, j
	add ecx, k
	mov edx, offset OpTypeList
	mov bl, BYTE PTR [edx+ecx]
	and bl, 1
	.IF bl > 0 ; is unary
		INVOKE RightBrace, array, i, j, k ; 'Op''num') or 'Fun'['num'])
		INVOKE InsertChar, array, i, 40   ; ('Op''num') or ('Fun'['num']) -- fine
		popad 
		ret
	.ENDIF

	mov ecx, j
	add ecx, k
	mov edx, offset OpTypeList
	mov bl, BYTE PTR [edx+ecx]
	and bl, 2
	.IF bl > 0 ; is a function: 'Fun'('a','b')
		mov ecx, i
		add ecx, k
		mov edx, array
		.REPEAT
			inc ecx
			mov bl, BYTE PTR [edx+ecx]
		.UNTIL bl == 44 ; ,
		INVOKE RemoveChar, array, ecx ; 'Fun'('a''b')
		mov eax, 0
		mov edx, offset OpTypeList
		.WHILE eax < k
			mov bl, [edx+eax]
			INVOKE InsertChar, array, ecx, bl
			inc ecx
			inc eax
		.ENDW ; ('a''Fun''b') -- fine
		popad
		ret
	.ENDIF

	; finally -- the regular case
	INVOKE RightBrace, array, i, j, k
	; left
	mov ecx, i
	dec ecx
	mov edx, array
	mov bl, BYTE PTR [edx+ecx]
	.IF bl == 41 ; )
		mov ecx, i
		sub ecx, 2
		mov eax, 1
		mov bl, BYTE PTR [edx+ecx]
		.WHILE ecx >= 0 && eax > 0
			.IF bl == 41
				inc eax
			.ELSEIF bl == 40 ; (
				dec eax
			.ENDIF
			dec ecx
			mov bl, BYTE PTR [edx+ecx]
		.ENDW
		.IF ecx < 0
			; exception
		.ENDIF
		inc ecx
		INVOKE InsertChar, array, ecx, 40
	.ELSE
		mov ecx, i
		mov eax, 0
		.REPEAT
			dec ecx
			mov bl, BYTE PTR [edx+ecx]
			.IF bl == 93
				inc eax
				dec ecx
				mov bl, BYTE PTR [edx+ecx]
			.ELSEIF bl == 91
				.IF eax == 0
					inc ecx
					INVOKE InsertChar, array, ecx, 40
					ret
				.ENDIF
				dec eax
			.ENDIF
		.UNTIL ecx > 80000000h || ((bl < 48 || bl > 57) && (bl < 65 || bl > 90) && bl != 32 && (bl < 97 || bl > 122) && bl != 91 && bl != 93 && eax == 0)
		inc ecx
		.IF ecx > 80000000h
			; exception
		.ENDIF
		INVOKE InsertChar, array, ecx, 40
	.ENDIF

	popad
	ret
AddBrace ENDP

;-----------------------------------------------------
PolishNotation PROC
; Transfer the recvBuffer into reverse PN format
; result still stored in recvBuffer
;-----------------------------------------------------
	LOCAL i:DWORD, j:DWORD, k:DWORD

; step 1: treat space
	mov ecx, 0
	mov al, BYTE PTR [recvBuffer]
	.WHILE al != 0
		.IF al == 32 ; space
			INVOKE RemoveChar, ADDR recvBuffer, ecx
			dec ecx
		.ENDIF
		inc ecx
		mov al, BYTE PTR [recvBuffer+ecx]
	.ENDW

; step 2: add () for every operator
	mov ecx, 0
	.WHILE ecx < OperatorTableHeight
		push ecx
		INVOKE UpdateOperator, ecx
		mov i, 0
		mov bl, BYTE PTR [recvBuffer]
		.WHILE bl != 0
			mov j, 0
			mov al, BYTE PTR [OperatorList]
			.WHILE al != 0
				.IF bl == al && al != 32
					pushad
					mov k, 1
					mov ecx, j
					inc ecx
					mov al, BYTE PTR [OperatorList+ecx]
					mov ecx, i
					inc ecx 
					mov bl, BYTE PTR [recvBuffer+ecx]
					.WHILE al == bl && al != 0 && bl != 0 && al != 32
						inc k
						mov ecx, j
						add ecx, k
						mov al, BYTE PTR [OperatorList+ecx]
						mov ecx, i
						add ecx, k
						mov bl, BYTE PTR [recvBuffer+ecx]
					.ENDW
					.IF al == 32 ; i: position of operator in buffer, j: position of op in oplist k: op length
						INVOKE AddBrace, ADDR recvBuffer, i, j, k
						mov eax, i
						add eax, k
						mov i, eax
						popad
						jmp restart
					.ENDIF
					popad
				.ENDIF
				inc j
				mov ecx, j
				mov al, BYTE PTR [OperatorList+ecx]
			.ENDW
			restart:
			inc i
			mov ecx, i
			mov bl, BYTE PTR [recvBuffer+ecx]
		.ENDW
		pop ecx 
		inc ecx
	.ENDW

; step 3: move operators to the right and remove all the braces
	mov ecx, 0
	mov edx, offset recvBuffer
	.WHILE ecx < MaxBufferSize
		mov bl, BYTE PTR [edx+ecx]
		.IF bl == 91 ; [
			mov BYTE PTR [edx+ecx], 40 ; (
		.ELSEIF bl == 93 ; ]
			mov BYTE PTR [edx+ecx], 41 ; )
		.ENDIF
		inc ecx
	.ENDW
	mov ecx, MaxBufferSize
	.REPEAT
		dec ecx
		INVOKE IsOperator, ADDR recvBuffer, ecx
		.IF eax != 0
			pushad ; ecx -> 'Op'...)
			mov esi, ecx
			mov ebx, 1
			.WHILE ebx > 0
				inc ecx
				mov dl, BYTE PTR [recvBuffer+ecx]
				.IF dl == 41
					dec ebx
				.ELSEIF dl == 40
					inc ebx
				.ENDIF
			.ENDW ;'Op'...) <- ecx
			inc ecx
			mov edi, ecx 
			.WHILE eax > 0
				mov bl, BYTE PTR [recvBuffer+esi]
				push eax
				INVOKE InsertChar, ADDR recvBuffer, edi, bl
				pop eax
				inc edi
				inc esi
				dec eax
			.ENDW
			INVOKE InsertChar, ADDR recvBuffer, ecx, 32 ; ...'Op'...) 'Op'...
			popad ; ecx -> 'Op'...) 'Op'...

			; eax = k, ebx = j
			mov edx, offset OperatorType
			add edx, ebx
			mov bl, BYTE PTR [edx+eax]
			.WHILE eax > 0
				push eax
				INVOKE RemoveChar, ADDR recvBuffer, ecx
				pop eax
				dec eax
			.ENDW ; ......) 'Op'... ? not always! 
			and bl, 1
			.IF bl == 0
				INVOKE InsertChar, ADDR recvBuffer, ecx, 32
			.ENDIF
		.ENDIF
	.UNTIL ecx == 0
	mov ecx, 0
	mov al, BYTE PTR [recvBuffer]
	.WHILE al != 0
		.IF al == 40 || al == 41
			INVOKE RemoveChar, ADDR recvBuffer, ecx
			dec ecx
		.ENDIF
		inc ecx
		mov al, BYTE PTR [recvBuffer+ecx]
	.ENDW
	ret
PolishNotation ENDP

;-----------------------------------------------------
CalculateOp PROC,
	Op: DWORD
; Calculate the top two elements in the stack and push the answer back
;-----------------------------------------------------
	LOCAL type1:DWORD, type2:DWORD
	LOCAL type1Addr:DWORD, type2Addr:DWORD
	LOCAL long1:QWORD, long2:QWORD
	LOCAL long1Addr:DWORD, long2Addr:DWORD
	LOCAL tmpLong:QWORD, tmpLongAddr:DWORD
	pushad
	LEA eax, type1
	mov type1Addr, eax
	LEA eax, type2
	mov type2Addr, eax
	LEA eax, long1
	mov long1Addr, eax
	LEA eax, long2
	mov long2Addr, eax
	LEA eax, tmpLong
	mov tmpLongAddr, eax
	mov type1, 0
	mov type2, 0

	; TODO: more types
	INVOKE TopType, type1Addr
	INVOKE TopData, long1Addr
	INVOKE TopPop

	mov eax, [Op]
	.IF DWORD PTR [eax] == 20534241h || DWORD PTR [eax] == 534241h
		INVOKE LongAbs, long1Addr
		INVOKE TopPush, long1Addr, 8, TYPE_INT
	.ELSEIF DWORD PTR [eax] == 2047454eh || DWORD PTR [eax] == 47454eh
		INVOKE LongNeg, long1Addr
		INVOKE TopPush, long1Addr, 8, TYPE_INT
	.ELSE
		jmp BinaryOp
	.ENDIF 
	popad 
	ret

	BinaryOp:
	INVOKE TopType, type2Addr
	INVOKE TopData, long2Addr
	INVOKE TopPop
	mov eax, [Op]
	.IF BYTE PTR [eax] == 43
		INVOKE LongAdd, long1Addr, long2Addr
		INVOKE TopPush, long1Addr, 8, TYPE_INT
	.ELSEIF BYTE PTR [eax] == 42
		INVOKE LongMul, long1Addr, long2Addr
		INVOKE TopPush, long1Addr, 8, TYPE_INT
	.ELSEIF BYTE PTR [eax] == 45
		INVOKE LongSub, long2Addr, long1Addr
		INVOKE TopPush, long2Addr, 8, TYPE_INT
	.ELSEIF BYTE PTR [eax] == 47
		INVOKE LongDiv, long2Addr, long1Addr, tmpLongAddr
		INVOKE TopPush, long2Addr, 8, TYPE_INT
	.ELSEIF BYTE PTR [eax] == 94
		INVOKE LongExp, long2Addr, long1Addr
		INVOKE TopPush, long2Addr, 8, TYPE_INT
	.ENDIF
	popad
	ret
CalculateOp ENDP

;-----------------------------------------------------
CalculatePN PROC
; After treated by PolishNotation PROC, calculate answer
;-----------------------------------------------------
	LOCAL currentInt: QWORD
	LOCAL ansBufferLen: DWORD, ansBufferStartingLoc: DWORD
	LOCAL tmpArray[MaxBufferSize]:BYTE
	INVOKE strcpy, ADDR ansBuffer, ADDR recvBuffer ; load the recvBuffer into ansBuffer
	mov ecx, 0
	mov ansBufferStartingLoc, 0
	; for each elem seperated by space:
	; if is operand, push into stack
	; if is operator, pop operands in accordance with the operator, then calc and push
	; finally: pop the last operand, which is the answer
	L1:	
		mov ecx, ansBufferStartingLoc
		; for each elem:
		; loop to search:
		.IF [ansBuffer+ecx] == 0 ; end of the elem
			JMP END_LOOP
		.ENDIF
		mov ansBufferStartingLoc, ecx ; save the starting location of the elem
		L2:
			.IF BYTE PTR [ansBuffer+ecx] == 0 ; end of the elem
				JMP L3
			.ENDIF
			.IF BYTE PTR [ansBuffer+ecx] == 32 ; end of the elem
				JMP L3
			.ENDIF
			; else:
			INC ecx
			JMP L2
		L3:
		; now ansBufferLoc points to the end() of the elem
		; and ansBufferStartingLoc points to the start() of the elem
		; so the elem is [ansBufferStartingLoc, ansBufferLoc)
		; now we need to determine whether it is an operand or an operator
		sub ecx, ansBufferStartingLoc
		mov ansBufferLen, ecx
		INVOKE IsOperator, ADDR ansBuffer, ansBufferStartingLoc
		; if eax == 0, then it is an operand
		.IF eax == 0
			; TODO: push the operand into stack
			; .IF 
				; TODO: support more types
				; put the [ansBufferStartingLoc, ansBufferLoc) into tmpArray
				mov esi, offset ansBuffer
				add esi, ansBufferStartingLoc
				lea edi, tmpArray
				mov ecx, ansBufferLen
				INVOKE strncpy, edi, esi, ecx
				mov ecx, ansBufferLen
				mov BYTE PTR [tmpArray+ecx], 0
				; convert tmpArray into a number
				lea eax, currentInt
				INVOKE StrToLong, ADDR tmpArray, eax
				; push the number into stack
				lea eax, currentInt
				INVOKE TopPush, eax, 8, TYPE_INT
			; .ENDIF
			JMP L4
		.ENDIF
		; else it is an operator
		mov eax, offset ansBuffer
		add eax, ansBufferStartingLoc
		INVOKE CalculateOp, eax
		L4:
		mov ecx, ansBufferLen
		add ansBufferStartingLoc, ecx
		INC ansBufferStartingLoc
		JMP L1
	END_LOOP:
	INVOKE TopData, ADDR ansBuffer
	INVOKE TopPop
	INVOKE LongToStr, ADDR ansBuffer
	ret
CalculatePN ENDP

;-----------------------------------------------------
CalculateResult PROC
; Analyze the buffer and calculate the answer
; Answer storing in ansBuffer
;-----------------------------------------------------
	inc CalCount
	INVOKE memset, ADDR ansBuffer, 0, MaxBufferSize
	INVOKE PolishNotation
	INVOKE CalculatePN
	ret
CalculateResult ENDP

END