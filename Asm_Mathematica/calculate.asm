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
strncpy			PROTO C :ptr sbyte, :ptr sbyte, :DWORD
strcpy			PROTO C :ptr sbyte, :ptr sbyte
strcat			PROTO C :ptr sbyte, :ptr sbyte
memset			PROTO C :ptr sbyte, :DWORD, :DWORD
strlen			PROTO C :ptr sbyte

.data
recvBuffer BYTE MaxBufferSize DUP(0)
ansBuffer BYTE MaxBufferSize DUP(0)
public recvBuffer, ansBuffer

OperatorTable BYTE "* /                            ",0
			  BYTE "+ -                            ",0
OperatorList BYTE OperatorListLength DUP(0)

TestTitle BYTE "test",0
TestText BYTE "reached here!",0
FailureText BYTE "!Calculation failed!",0
FailureSign BYTE 0
public FailureSign

CalCount DWORD 0
public CalCount

calculationStack BYTE MaxMathStackSize DUP(0)
calculationStackTop DWORD calculationStack
public calculationStack, calculationStackTop

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
	popad
	ret
UpdateOperator ENDP

;-----------------------------------------------------
IsOperator PROC,
	array:DWORD, index:DWORD
; Examine whether the value array[index] is (or is not) an operator
; returns length of operator or 0 if is not
;-----------------------------------------------------
	LOCAL len:DWORD
	pushad
	mov ecx, 0
	mov ebx, array
	add ebx, index
	mov al, BYTE PTR [OperatorTable]
	.WHILE ecx < OperatorTableLength
		.IF al == BYTE PTR [ebx]
			pushad
			mov ecx, 0
			.REPEAT
				inc ecx
				mov ebx, array
				add ebx, index
				mov al, BYTE PTR [ebx+ecx]
				mov dl, BYTE PTR [OperatorTable+ecx]
			.UNTIL dl == 32 || dl != al
			.IF dl == 32
				mov len, ecx
				popad
				popad
				mov eax, len
				ret
			.ENDIF
			popad
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
AddBrace PROC,
	array:DWORD, j:DWORD, k:DWORD
; Add braces on both side of an operator
;-----------------------------------------------------
	pushad
	
	; right
	mov ecx, j
	add ecx, k
	mov edx, array
	mov bl, BYTE PTR [edx+ecx]
	.IF bl == 40 ; (
		mov ecx, j
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
		mov ecx, j
		add ecx, k
		inc ecx
		mov bl, BYTE PTR [edx+ecx]
		.WHILE ecx >= 0 && ((bl >= 48 && bl <= 57) || (bl >= 97) && (bl <= 122) || bl == 32)
			inc ecx
			mov bl, BYTE PTR [edx+ecx]
		.ENDW
		INVOKE InsertChar, array, ecx, 41
	.ENDIF

	; left
	mov ecx, j
	dec ecx
	mov bl, BYTE PTR [edx+ecx]
	.IF bl == 41 ; )
		mov ecx, j
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
		mov ecx, j
		sub ecx, 2
		mov bl, BYTE PTR [edx+ecx]
		.WHILE ecx >= 0 && ((bl >= 48 && bl <= 57) || (bl >= 97) && (bl <= 122) || bl == 32)
			dec ecx
			mov bl, BYTE PTR [edx+ecx]
		.ENDW
		.IF ecx < 0
			; exception
		.ENDIF
		inc ecx
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
					.IF al == 32 ; i: position of operator, k: op length
						INVOKE AddBrace, ADDR recvBuffer, i, k
						popad
						inc i
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
	mov eax, offset recvBuffer
	mov al, BYTE PTR [OperatorTable]
	.WHILE ecx < OperatorTableLength
		.IF al != 32 && al != 0
			pushad
			mov ecx, SIZE recvBuffer
			.REPEAT
				dec ecx
				mov bl, BYTE PTR [recvBuffer+ecx]
				.IF bl == al
					pushad
					mov eax, 1
					.WHILE eax > 0
						inc ecx
						mov dl, BYTE PTR [recvBuffer+ecx]
						.IF dl == 41
							dec eax
						.ELSEIF dl == 40
							inc eax
						.ENDIF
					.ENDW
					inc ecx
					INVOKE InsertChar, ADDR recvBuffer, ecx, bl
					INVOKE InsertChar, ADDR recvBuffer, ecx, 32
					popad
					; INVOKE RemoveChar, ADDR recvBuffer, ecx
					mov recvBuffer[ecx], 32
				.ENDIF
			.UNTIL ecx == 0
			popad
		.ENDIF
		inc ecx
		mov al, BYTE PTR [OperatorTable+ecx]
	.ENDW
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
CalculatePlusMinus PROC
	RET
CalculatePlusMinus ENDP

;-----------------------------------------------------
CalculatePN PROC
; After treated by PolishNotation PROC, calculate answer
;-----------------------------------------------------
	LOCAL currentInt: QWORD, currentFloat: QWORD
	LOCAL ansBufferLoc: DWORD, ansBufferStartingLoc: DWORD
	INVOKE strcpy, ADDR ansBuffer, ADDR recvBuffer ; load the recvBuffer into ansBuffer
	MOV ansBufferLoc, offset ansBuffer
	; for each elem seperated by space:
	; if is operand, push into stack
	; if is operator, pop operands in accordance with the operator, then calc and push
	; finally: pop the last operand, which is the answer
	L1:	
		; for each elem:
		; loop to search:
		.IF [ansBufferLoc] == 0 ; end of the elem
			JMP END_LOOP
		.ENDIF
		MOV eax, ansBufferLoc
		MOV ansBufferStartingLoc, eax ; save the starting location of the elem
		L2:
			.IF BYTE PTR [ansBufferLoc] == 0 ; end of the elem
				JMP L3
			.ENDIF
			.IF BYTE PTR [ansBufferLoc] == 32 ; end of the elem
				JMP L3
			.ENDIF
			; else:
			INC ansBufferLoc
			JMP L2
		L3:
		; now ansBufferLoc points to the end() of the elem
		; and ansBufferStartingLoc points to the start() of the elem
		; so the elem is [ansBufferStartingLoc, ansBufferLoc)
		; now we need to determine whether it is an operand or an operator
		
		INVOKE IsOperator, ADDR ansBuffer, ansBufferStartingLoc
		; if eax == 0, then it is an operand
		.IF eax == 0
			; TODO: push the operand into stack
			JMP L4
		.ENDIF
		; else it is an operator
		; TODO: pop operands in accordance with the operator, then calc and push
		L4:
		INC ansBufferLoc
		JMP L1
		



	END_LOOP:
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