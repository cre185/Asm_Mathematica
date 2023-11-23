.386
.model flat, stdcall
option casemap: none

include  		core.inc
include			macro.inc
include			mathStack.inc
include			longInt.inc
include			double.inc
include			boolean.inc
include			variables.inc
include			numasm.inc
strncpy			PROTO C :ptr sbyte, :ptr sbyte, :DWORD
strcpy			PROTO C :ptr sbyte, :ptr sbyte
strcat			PROTO C :ptr sbyte, :ptr sbyte
memset			PROTO C :ptr sbyte, :DWORD, :DWORD
strlen			PROTO C :ptr sbyte
strchr			PROTO C :ptr sbyte, :DWORD

.data
recvBuffer BYTE MaxBufferSize DUP(0)
ansBuffer BYTE MaxBufferSize DUP(0)
public recvBuffer, ansBuffer

OperatorTable BYTE "FACT SQRT SIN COS TAN LN LG LOG EXP                            ",0
			  BYTE "* / ^ %                                                        ",0
			  BYTE "+ -                                                            ",0
			  BYTE "ABS NEG IN OUT FL                                              ",0
			  BYTE "== !=                                                          ",0
			  BYTE "&& ||                                                          ",0
			  BYTE ":=                                                             ",0
; Type: lower bit 0 for binary, 1 for unary; second bit 0 for operator, 1 for function
OperatorType  BYTE "    3    3   3   3   3  3  3   3   3                           ",0
			  BYTE " 0 0 0 0                                                       ",0
			  BYTE " 0 0                                                           ",0
			  BYTE "   3   3  3   3  3                                             ",0
			  BYTE "  0  0                                                         ",0
			  BYTE "  0  0                                                         ",0
			  BYTE "  0                                                            ",0
OperatorList BYTE OperatorListLength DUP(0)
OpTypeList   BYTE OperatorListLength DUP(0)

TestTitle BYTE "test",0
TestText BYTE "reached here!",0
InOutError BYTE "Invalid use of IN/OUT!",0
TrueText BYTE "True",0
FalseText BYTE "False",0
VarUndefinedText BYTE "Variable referenced before assigned!",0
variableOutOfDomainText BYTE "Variable out of domain!",0
Zero REAL8 0.0
pi REAL8 3.14159265358979323846264338328

CalCount DWORD 0
public CalCount

EXTERN calculationStack:BYTE, calculationStackTop:DWORD, calculationStackBase:DWORD

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
	array:DWORD, index:DWORD, targetList:DWORD, targetLength:DWORD
; Examine whether the value array[index] is (or is not) in targetList
; returns length and start of operator or 0 if is not
;-----------------------------------------------------
	LOCAL len:DWORD, j:DWORD
	pushad
	mov edi, [targetList]
	mov ecx, 0
	mov ebx, array
	add ebx, index
	mov al, BYTE PTR [edi]
	.WHILE ecx < targetLength
		.IF al == BYTE PTR [ebx] && al != 0
			pushad
			mov esi, ecx
			dec ecx
			.IF BYTE PTR [edi+ecx] == 32 || BYTE PTR [edi+ecx] == 0
				mov ecx, 0
				.REPEAT
					inc ecx
					inc esi
					mov ebx, array
					add ebx, index
					mov al, BYTE PTR [ebx+ecx]
					mov dl, BYTE PTR [edi+esi]
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
				mov al, BYTE PTR [edi+ecx]
			.UNTIL al == 32
		.ENDIF
		inc ecx
		mov al, BYTE PTR [edi+ecx]
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
			; should pass: 65-90 functions (as a whole, so special treat 91'[', 93']'), 46'.', 48-57 numbers and 97-122 values, 32' '
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
		.UNTIL ecx >= MaxBufferSize || (bl != 46 && (bl < 48 || bl > 57) && (bl < 65 || bl > 90) && bl != 32 && (bl < 97 || bl > 122) && bl != 91 && bl != 93 && eax == 0)
		INVOKE InsertChar, array, ecx, 41
	.ENDIF
	ret
RightBrace ENDP

;-----------------------------------------------------
AddBrace PROC,
	array:DWORD, i:DWORD, j:DWORD, k:DWORD 
; Add braces on both side of an operator
; i: position of operator in buffer, k: op length
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
		.UNTIL ecx > 80000000h || (bl != 46 && (bl < 48 || bl > 57) && (bl < 65 || bl > 90) && bl != 32 && (bl < 97 || bl > 122) && bl != 91 && bl != 93 && eax == 0)
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
		mov al, BYTE PTR [recvBuffer]
		.WHILE al != 0
			INVOKE IsOperator, ADDR recvBuffer, i, ADDR OperatorList, OperatorListLength
			.IF eax != 0
				pushad
				mov k, eax
				mov j, ebx
				mov ecx, i
				dec ecx
				.IF ecx < 80000000h
					INVOKE IsOperator, ADDR recvBuffer, ecx, ADDR OperatorTable, OperatorTableLength
					.IF eax >= 2; the op is another op's suffix and has been treated
						popad
						jmp restart
					.ENDIF
				.ENDIF
				popad
				INVOKE AddBrace, ADDR recvBuffer, i, j, k
				mov ecx, k
				add i, ecx
			.ENDIF
			restart:
			inc i
			mov ecx, i
			mov al, BYTE PTR [recvBuffer+ecx]
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
		INVOKE IsOperator, ADDR recvBuffer, ecx, ADDR OperatorTable, OperatorTableLength
		.IF eax != 0
			pushad ; ecx -> 'Op'...)
			pushad
			dec ecx
			.IF ecx < 80000000h
				INVOKE IsOperator, ADDR recvBuffer, ecx, ADDR OperatorTable, OperatorTableLength
				.IF eax >= 2; the op is another op's suffix and has been treated
					popad
					jmp removeStart
				.ENDIF
			.ENDIF
			popad
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
		removeStart:
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
; Calculate the ans according to Op and push back ans
;-----------------------------------------------------
	LOCAL type1:BYTE, type2:BYTE
	LOCAL type1Addr:DWORD, type2Addr:DWORD
	LOCAL size1:WORD, size2:WORD
	LOCAL size1Addr:DWORD, size2Addr:DWORD
	LOCAL operand1[128]:BYTE, operand2[128]:BYTE
	LOCAL operand1Addr:DWORD, operand2Addr:DWORD
	LOCAL tmpOperand:QWORD, tmpOperandAddr:DWORD, tmpPtr:DWORD
	LOCAL tmpBool:BYTE, tmpBoolAddr:DWORD
	pushad
	LEA eax, type1
	mov type1Addr, eax
	LEA eax, type2
	mov type2Addr, eax
	LEA eax, size1
	mov size1Addr, eax
	LEA eax, size2
	mov size2Addr, eax
	LEA eax, operand1
	mov operand1Addr, eax
	LEA eax, operand2
	mov operand2Addr, eax
	LEA eax, tmpOperand
	mov tmpOperandAddr, eax
	LEA eax, tmpBool
	mov tmpBoolAddr, eax
	INVOKE memset, ADDR operand1, 0, 128
	INVOKE memset, ADDR operand2, 0, 128

	INVOKE TopType, type1Addr
	INVOKE TopSize, size1Addr
	INVOKE TopData, operand1Addr
	INVOKE TopPop
	; Replace var by correct value first
	mov eax, [Op]
	.IF type1 == TYPE_VAR
		INVOKE HashTableSearch, operand1Addr, ADDR tmpPtr
		.IF tmpPtr != 0
			INVOKE GetElemVarType, tmpPtr, type1Addr
			INVOKE GetElemVarSize, tmpPtr, size1Addr
			INVOKE GetElemVarValue, tmpPtr, operand1Addr
		.ELSE
			INVOKE TopPushError, ADDR VarUndefinedText
			jmp endFlag
		.ENDIF
	.ENDIF
	; Ops that can calculate using all types
	mov eax, [Op]
	.IF WORD PTR [eax] == 4c46h ; FL
		INVOKE ToLong, operand1Addr, size1Addr, type1Addr
		INVOKE TopPush, operand1Addr, 8, TYPE_INT
	.ELSEIF DWORD PTR [eax] == 54525153h ; SQRT
		INVOKE ToDouble, operand1Addr, size1Addr, type1Addr
		; domain: operand1 >= 0
		fld QWORD PTR operand1
		fcomp Zero
		fstsw ax
		sahf
		; if operand1 < 0, then error
		.IF CARRY?
			INVOKE TopPushError, ADDR variableOutOfDomainText
			jmp endFlag
		.ENDIF
		INVOKE Sqrt, QWORD PTR operand1, tmpOperandAddr
		INVOKE TopPush, tmpOperandAddr, 8, TYPE_DOUBLE
	.ELSEIF DWORD PTR [eax] == 4e4953h || DWORD PTR [eax] == 204e4953h ; SIN
		INVOKE ToDouble, operand1Addr, size1Addr, type1Addr
		INVOKE Sin, QWORD PTR operand1, tmpOperandAddr
		INVOKE TopPush, tmpOperandAddr, 8, TYPE_DOUBLE
	.ELSEIF DWORD PTR [eax] == 534f43h || DWORD PTR [eax] == 20534f43h ; COS
		INVOKE ToDouble, operand1Addr, size1Addr, type1Addr
		INVOKE Cos, QWORD PTR operand1, tmpOperandAddr
		INVOKE TopPush, tmpOperandAddr, 8, TYPE_DOUBLE
	.ELSEIF DWORD PTR [eax] == 4e4154h || DWORD PTR [eax] == 204e4154h ; TAN
		INVOKE ToDouble, operand1Addr, size1Addr, type1Addr
		INVOKE Tan, QWORD PTR operand1, tmpOperandAddr
		INVOKE TopPush, tmpOperandAddr, 8, TYPE_DOUBLE
	.ELSEIF WORD PTR [eax] == 4e4ch ; LN
		INVOKE ToDouble, operand1Addr, size1Addr, type1Addr
		; domain: operand1 > 0
		fld QWORD PTR operand1
		fcomp Zero
		fstsw ax
		sahf
		; if operand1 <= 0, then error
		.IF CARRY? || ZERO?
			INVOKE TopPushError, ADDR variableOutOfDomainText
			jmp endFlag
		.ENDIF
		INVOKE Ln, QWORD PTR operand1, tmpOperandAddr
		INVOKE TopPush, tmpOperandAddr, 8, TYPE_DOUBLE
	.ELSEIF WORD PTR [eax] == 474ch ; LG
		INVOKE ToDouble, operand1Addr, size1Addr, type1Addr
		; domain: operand1 > 0
		fld QWORD PTR operand1
		fcomp Zero
		fstsw ax
		sahf
		; if operand1 <= 0, then error
		.IF CARRY? || ZERO?
			INVOKE TopPushError, ADDR variableOutOfDomainText
			jmp endFlag
		.ENDIF
		INVOKE Lg, QWORD PTR operand1, tmpOperandAddr
		INVOKE TopPush, tmpOperandAddr, 8, TYPE_DOUBLE
	.ELSEIF DWORD PTR [eax] == 474f4ch || DWORD PTR [eax] == 20474f4ch ; LOG
		INVOKE ToDouble, operand1Addr, size1Addr, type1Addr
		; domain: operand1 > 0
		fld QWORD PTR operand1
		fcomp Zero
		fstsw ax
		sahf
		; if operand1 <= 0, then error
		.IF CARRY? || ZERO?
			INVOKE TopPushError, ADDR variableOutOfDomainText
			jmp endFlag
		.ENDIF
		INVOKE Log, QWORD PTR operand1, tmpOperandAddr
		INVOKE TopPush, tmpOperandAddr, 8, TYPE_DOUBLE
	.ELSEIF DWORD PTR [eax] == 505845h || DWORD PTR [eax] == 20505845h ; EXP
		INVOKE ToDouble, operand1Addr, size1Addr, type1Addr
		INVOKE Exp, QWORD PTR operand1, tmpOperandAddr
		INVOKE TopPush, tmpOperandAddr, 8, TYPE_DOUBLE
	.ELSE
		jmp TypeDif1
	.ENDIF
	jmp endFlag
	; These ops cares!
	TypeDif1:
	mov eax, [Op]
	.IF type1 == TYPE_INT
		.IF DWORD PTR [eax] == 20534241h || DWORD PTR [eax] == 534241h ; ABS
			INVOKE LongAbs, operand1Addr
			INVOKE TopPush, operand1Addr, 8, TYPE_INT
		.ELSEIF DWORD PTR [eax] == 2047454eh || DWORD PTR [eax] == 47454eh ; NEG
			INVOKE LongNeg, operand1Addr
			INVOKE TopPush, operand1Addr, 8, TYPE_INT
		.ELSEIF WORD PTR [eax] == 4e49h || DWORD PTR [eax] == 54554fh || DWORD PTR [eax] == 2054554fh ; IN/OUT
			mov edx, CalCount
			mov eax, operand1Addr
			sub edx, DWORD PTR [eax+4]
			.IF edx == 0 || edx >= CalCount
				INVOKE TopPushError, ADDR InOutError
			.ELSE 
				INVOKE GetHistory, edx
			.ENDIF
		.ELSEIF DWORD PTR [eax] == 54434146h ; FACT
			mov edx, operand1Addr
			add edx, 4
			mov ebx, [edx]
			INVOKE Fact, ebx, tmpOperandAddr
			INVOKE TopPush, tmpOperandAddr, 8, TYPE_INT
		.ELSE
			jmp BinaryOp
		.ENDIF
	.ELSEIF type1 == TYPE_DOUBLE
		.IF DWORD PTR [eax] == 20534241h || DWORD PTR [eax] == 534241h ; ABS
			INVOKE DoubleAbs, operand1Addr
			INVOKE TopPush, operand1Addr, 8, TYPE_DOUBLE
		.ELSEIF DWORD PTR [eax] == 2047454eh || DWORD PTR [eax] == 47454eh ; NEG
			INVOKE DoubleNeg, operand1Addr
			INVOKE TopPush, operand1Addr, 8, TYPE_DOUBLE
		.ELSEIF WORD PTR [eax] == 4e49h || DWORD PTR [eax] == 54554fh || DWORD PTR [eax] == 2054554fh ; IN/OUT
			INVOKE TopPushError, ADDR InOutError
		.ELSE
			jmp BinaryOp
		.ENDIF 
	.ELSEIF type1 == TYPE_BOOL
		jmp BinaryOp
	.ELSEIF type1 == TYPE_ERROR
		INVOKE TopPush, operand1Addr, size1, type1
	.ELSE 
		INVOKE TopPushStandardError
	.ENDIF
	popad 
	ret

	BinaryOp:
	INVOKE TopType, type2Addr
	INVOKE TopSize, size2Addr
	INVOKE TopData, operand2Addr
	INVOKE TopPop
	; Replace var by correct value first
	.IF type1 == TYPE_VAR
		INVOKE HashTableSearch, operand1Addr, ADDR tmpPtr
		.IF tmpPtr != 0
			INVOKE GetElemVarType, tmpPtr, type1Addr
			INVOKE GetElemVarSize, tmpPtr, size1Addr
			INVOKE GetElemVarValue, tmpPtr, operand1Addr
		.ELSE
			INVOKE TopPushError, ADDR VarUndefinedText
			jmp endFlag
		.ENDIF
	.ELSEIF type2 == TYPE_VAR
		mov eax, [Op]
		.IF WORD PTR [eax] == 3d3ah ; :=
			INVOKE HashTableInsert, operand2Addr, type1, size1, operand1Addr
			INVOKE TopPush, operand1Addr, size1, type1
			jmp endFlag
		.ELSE
			INVOKE HashTableSearch, operand2Addr, ADDR tmpPtr
			.IF tmpPtr != 0
				INVOKE GetElemVarType, tmpPtr, type2Addr
				INVOKE GetElemVarSize, tmpPtr, size2Addr
				INVOKE GetElemVarValue, tmpPtr, operand2Addr
			.ELSE
				INVOKE TopPushError, ADDR VarUndefinedText
				jmp endFlag
			.ENDIF
		.ENDIF
	.ENDIF
	.IF type1 == TYPE_ERROR
		INVOKE TopPush, operand1Addr, size1, type1
	.ELSEIF type2 == TYPE_ERROR
		INVOKE TopPush, operand2Addr, size2, type2
	.ENDIF
	; Ops that can calculate using all types
	mov eax, [Op]
	.IF BYTE PTR [eax] == 94 ; ^
		INVOKE ToDouble, operand1Addr, size1Addr, type1Addr
		INVOKE ToDouble, operand2Addr, size2Addr, type2Addr
		INVOKE Pow, QWORD PTR operand2, QWORD PTR operand1, tmpOperandAddr
		INVOKE TopPush, tmpOperandAddr, 8, TYPE_DOUBLE
	.ELSEIF WORD PTR [eax] == 2626h ; &&
		INVOKE ToBool, operand1Addr, size1Addr, type1Addr
		INVOKE ToBool, operand2Addr, size2Addr, type2Addr
		INVOKE BoolAnd, operand1, operand2
		mov operand1, al
		INVOKE TopPush, operand1Addr, 1, TYPE_BOOL
	.ELSEIF WORD PTR [eax] == 7c7ch ; ||
		INVOKE ToBool, operand1Addr, size1Addr, type1Addr
		INVOKE ToBool, operand2Addr, size2Addr, type2Addr
		INVOKE BoolOr, operand1, operand2
		mov operand1, al
		INVOKE TopPush, operand1Addr, 1, TYPE_BOOL
	.ELSEIF DWORD PTR [eax] == 574f50h || DWORD PTR [eax] == 20574f50h ; POW
		; todo
	.ELSE
		jmp TypeDif2
	.ENDIF
	jmp endFlag
	; These ops cares!
	TypeDif2:
	mov eax, [Op]
	.IF type1 == TYPE_DOUBLE || type2 == TYPE_DOUBLE
		mov eax, [Op]
		INVOKE ToDouble, operand1Addr, size1Addr, type1Addr
		INVOKE ToDouble, operand2Addr, size2Addr, type2Addr
		mov eax, [Op]
		.IF BYTE PTR [eax] == 43 ; +
			INVOKE DoubleAdd, operand1Addr, operand2Addr
			INVOKE TopPush, operand1Addr, 8, TYPE_DOUBLE
		.ELSEIF BYTE PTR [eax] == 42 ; *
			INVOKE DoubleMul, operand1Addr, operand2Addr
			INVOKE TopPush, operand1Addr, 8, TYPE_DOUBLE
		.ELSEIF BYTE PTR [eax] == 45 ; -
			INVOKE DoubleSub, operand2Addr, operand1Addr
			INVOKE TopPush, operand2Addr, 8, TYPE_DOUBLE
		.ELSEIF BYTE PTR [eax] == 47 ; /
			INVOKE DoubleDiv, operand2Addr, operand1Addr
			INVOKE TopPush, operand2Addr, 8, TYPE_DOUBLE
		.ELSEIF WORD PTR [eax] == 3d3dh ; ==
			INVOKE DoubleEqu, QWORD PTR operand1, QWORD PTR operand2, tmpBoolAddr
			INVOKE TopPush, tmpBoolAddr, 1, TYPE_BOOL
		.ELSEIF WORD PTR [eax] == 3d21h ; !=
			INVOKE DoubleEqu, QWORD PTR operand1, QWORD PTR operand2, tmpBoolAddr
			INVOKE BoolNot, tmpBool
			mov tmpBool, al
			INVOKE TopPush, tmpBoolAddr, 1, TYPE_BOOL
		.ELSE
			INVOKE TopPushStandardError
		.ENDIF
	.ELSE
		INVOKE ToLong, operand1Addr, size1Addr, type1Addr
		INVOKE ToLong, operand2Addr, size2Addr, type2Addr
		mov eax, [Op]
		.IF BYTE PTR [eax] == 43 ; +
			INVOKE LongAdd, operand1Addr, operand2Addr
			INVOKE TopPush, operand1Addr, 8, TYPE_INT
		.ELSEIF BYTE PTR [eax] == 42 ; *
			INVOKE LongMul, operand1Addr, operand2Addr
			INVOKE TopPush, operand1Addr, 8, TYPE_INT
		.ELSEIF BYTE PTR [eax] == 45 ; -
			INVOKE LongSub, operand2Addr, operand1Addr
			INVOKE TopPush, operand2Addr, 8, TYPE_INT
		.ELSEIF BYTE PTR [eax] == 47 ; /
			INVOKE LongToDouble, operand1Addr
			INVOKE LongToDouble, operand2Addr
			INVOKE DoubleDiv, operand2Addr, operand1Addr
			INVOKE TopPush, operand2Addr, 8, TYPE_DOUBLE
		.ELSEIF BYTE PTR [eax] == 37 ; &
			INVOKE LongDiv, operand2Addr, operand1Addr
			INVOKE TopPush, operand1Addr, 8, TYPE_INT
		.ELSEIF BYTE PTR [eax] == 94 ; ^
			INVOKE LongExp, operand2Addr, operand1Addr
			INVOKE TopPush, operand2Addr, 8, TYPE_INT
		.ELSEIF WORD PTR [eax] == 3d3dh ; ==
			INVOKE LongEqu, operand1Addr, operand2Addr
			INVOKE TopPush, operand1Addr, 1, TYPE_BOOL
		.ELSEIF WORD PTR [eax] == 3d21h ; !=
			INVOKE LongEqu, operand1Addr, operand2Addr
			INVOKE BoolNot, operand1
			mov operand1, al
			INVOKE TopPush, operand1Addr, 1, TYPE_BOOL
		.ELSE 
			INVOKE TopPushStandardError
		.ENDIF
	.ENDIF
	endFlag:
	popad
	ret
CalculateOp ENDP

;-----------------------------------------------------
CalculatePN PROC
; After treated by PolishNotation PROC, calculate answer
;-----------------------------------------------------
	LOCAL currentNum: QWORD
	LOCAL ansBufferLen: DWORD, ansBufferStartingLoc: DWORD
	LOCAL tmpArray[MaxBufferSize]:BYTE, finalType:BYTE
	LOCAL tmpType: BYTE, tmpSize: WORD, tmpData[128]:BYTE, tmpPtr:DWORD
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
		INVOKE IsOperator, ADDR ansBuffer, ansBufferStartingLoc, ADDR OperatorTable, OperatorTableLength
		; if eax == 0, then it is an operand
		.IF eax == 0
			; put the [ansBufferStartingLoc, ansBufferLoc) into tmpArray
			mov esi, offset ansBuffer
			add esi, ansBufferStartingLoc
			lea edi, tmpArray
			mov ecx, ansBufferLen
			INVOKE strncpy, edi, esi, ecx
			mov ecx, ansBufferLen
			mov BYTE PTR [tmpArray+ecx], 0
			; convert tmpArray into a number
			; determine the type first
			mov ecx, 97 ; a
			.WHILE ecx <= 122 ; z
				push ecx
				INVOKE strchr, ADDR tmpArray, cl
				pop ecx
				.IF eax != 0 ; all strings containing lowercase letters are interpreted as variable
					INVOKE strlen, ADDR tmpArray ; get the length of the string into eax
					INVOKE TopPush, ADDR tmpArray, ax, TYPE_VAR ; push the var into stack
					jmp L4
				.ENDIF
				inc ecx
			.ENDW
			INVOKE strchr, ADDR tmpArray, 46 ; .
			.IF eax == 0 ; integer
				lea eax, currentNum
				INVOKE StrToLong, ADDR tmpArray, eax
				; push the number into stack
				lea eax, currentNum
				INVOKE TopPush, eax, 8, TYPE_INT
			.ELSE ; float number
				lea eax, currentNum
				INVOKE StrToDouble, ADDR tmpArray, eax
				lea eax, currentNum
				INVOKE TopPush, eax, 8, TYPE_DOUBLE
			.ENDIF
			JMP L4
		.ENDIF
		; else it is an operator
		mov eax, offset ansBuffer
		add eax, ansBufferStartingLoc
		INVOKE CalculateOp, eax
		L4:
		mov ecx, ansBufferLen
		add ansBufferStartingLoc, ecx
		inc ansBufferStartingLoc
		jmp L1
	END_LOOP:
	INVOKE TopType, ADDR finalType
	INVOKE TopData, ADDR ansBuffer
	.IF finalType == TYPE_INT
		INVOKE LongToStr, ADDR ansBuffer
	.ELSEIF finalType == TYPE_DOUBLE
		INVOKE DoubleToStr, ADDR ansBuffer
	.ELSEIF finalType == TYPE_BOOL
		mov eax, offset ansBuffer
		mov bl, [eax]
		INVOKE memset, ADDR ansBuffer, 0, MaxBufferSize
		.IF bl == 0
			INVOKE strcpy, ADDR ansBuffer, ADDR FalseText
		.ELSE
			INVOKE strcpy, ADDR ansBuffer, ADDR TrueText
		.ENDIF
	.ELSEIF finalType == TYPE_VAR
		INVOKE TopPop
		INVOKE HashTableSearch, ADDR tmpArray, ADDR tmpPtr
		.IF tmpPtr == 0
			INVOKE TopPushError, ADDR VarUndefinedText
		.ELSE
			INVOKE GetElemVarType, tmpPtr, ADDR tmpType
			INVOKE GetElemVarSize, tmpPtr, ADDR tmpSize
			INVOKE GetElemVarValue, tmpPtr, ADDR tmpData
			INVOKE TopPush, ADDR tmpData, tmpSize, tmpType
		.ENDIF
		jmp END_LOOP
	.ELSEIF finalType == TYPE_ERROR || finalType == TYPE_VOID
		; actually nothing is needed. 
	.ENDIF
	; Store the record under the stack
	mov eax, calculationStackTop
	mov calculationStackBase, eax

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