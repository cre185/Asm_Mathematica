.386
.model flat, stdcall
option casemap: none

include  		calculate.inc
include			macro.inc
strncpy			PROTO C :ptr sbyte, :ptr sbyte, :DWORD
strcpy			PROTO C :ptr sbyte, :ptr sbyte
strcat			PROTO C :ptr sbyte, :ptr sbyte
memset			PROTO C :ptr sbyte, :DWORD, :DWORD
strlen			PROTO C :ptr sbyte

.data

.code
;---------------------------------------------------------------------------
; In this section we wish to design a way for a 32-bit machine to be able to
; calculate 64-bit long int, using QWORDs. 
; The key is to design a way to convert a string into a QWORD, and vice versa.
; The add, sub, mul, div is easily(?) expanded to 64-bit.
;---------------------------------------------------------------------------

;---------------------------------------------------------------------------
LongAssign PROC,
    longAddr1: DWORD, longAddr2: DWORD
; This procedure assigns longAddr2 to longAddr1.
;---------------------------------------------------------------------------
    pushad
    mov ebx, [longAddr2]
    mov eax, [ebx]
    mov ebx, [longAddr1]
    mov [ebx], eax
    mov ebx, [longAddr2]
    mov eax, [ebx + 4]
    mov ebx, [longAddr1]
    mov [ebx + 4], eax
    popad
    ret
LongAssign ENDP

;---------------------------------------------------------------------------
LongNeg PROC,
    longAddr: DWORD
; This procedure calculate the negative value of QWORD in longAddr
;---------------------------------------------------------------------------
    pushad
    mov eax, [longAddr]
    mov edx, [eax+4]
    not edx
    mov [eax+4], edx
    mov edx, [eax]
    not edx
    mov [eax], edx
    add DWORD PTR [eax + 4], 1
    .IF CARRY?
        ; if carry, then add 1 to the higher 32 bits
        add DWORD PTR [eax], 1
    .ENDIF
    popad
    ret
LongNeg ENDP

;---------------------------------------------------------------------------
LongAbs PROC,
    longAddr: DWORD
; This procedure calculate the abs value of QWORD in longAddr
;---------------------------------------------------------------------------
    pushad
    mov eax, [longAddr]
    mov edx, [eax]
    .IF edx >= 80000000h
        INVOKE LongNeg, longAddr
    .ENDIF
    popad
    ret
LongAbs ENDP

;---------------------------------------------------------------------------
LongAdd PROC,
    longAddr1: DWORD, longAddr2: DWORD
; This procedure adds two QWORDs
;---------------------------------------------------------------------------
    LOCAL Increase:DWORD
    pushad
    mov Increase, 0
    mov ebx, [longAddr1]
    mov eax, [ebx+4] ; the lower 32 bits of longAddr1
    mov ebx, [longAddr2]
    ADD eax, [ebx+4] ; ................. of longAddr2
    .IF CARRY?
        INC Increase
    .ENDIF
    mov ebx, [longAddr1]
    mov [ebx+4], eax

    mov ebx, [longAddr1]
    mov eax, [ebx] ; the higher 32 bits of longAddr1
    mov ebx, [longAddr2]
    ADD eax, [ebx] ; the higher 32 bits of longAddr2
    ADD eax, Increase ; add the carry
    mov ebx, [longAddr1]
    mov [ebx], eax ; store the higher 32 bits of ansLongAddr
    popad
    ret
LongAdd ENDP


;---------------------------------------------------------------------------
LongSub PROC,
    longAddr1: DWORD, longAddr2: DWORD
; This procedure subtracts two QWORDs
;---------------------------------------------------------------------------
    ; -longAddr2 = ~longAddr2 + 1
    LOCAL tmpLong: QWORD
    pushad
    lea ebx, tmpLong
    INVOKE LongAssign, ebx, longAddr2
    INVOKE LongNeg, ebx
    INVOKE LongAdd, longAddr1, ebx
    popad
    ret
LongSub ENDP

;---------------------------------------------------------------------------
LongEqu PROC,
    longAddr1: DWORD, longAddr2:DWORD
; This procedure determines whether long1 equals to long2
;---------------------------------------------------------------------------
    pushad
    mov esi, [longAddr1]
    mov edi, [longAddr2]
    mov eax, [esi]
    mov edx, [edi]
    .IF eax == edx
        mov eax, [esi+4]
        mov edx, [edi+4]
        .IF eax == edx 
            mov BYTE PTR [esi], 1
        .ELSE
            mov BYTE PTR [esi], 0
        .ENDIF
    .ELSE
        mov BYTE PTR [esi], 0
    .ENDIF
    popad
    ret
LongEqu ENDP

;---------------------------------------------------------------------------
LongAnd PROC,
    longAddr1: DWORD, longAddr2: DWORD, ansLongAddr: DWORD
; This procedure performs a bitwise AND on two QWORDs, answer is in ansLongAddr.
;---------------------------------------------------------------------------
    push eax
    mov eax, [longAddr1]
    AND eax, [longAddr2]
    mov [ansLongAddr], eax
    mov eax, [longAddr1 + 4]
    AND eax, [longAddr2 + 4]
    mov [ansLongAddr + 4], eax
    pop eax
    ret
LongAnd ENDP

;---------------------------------------------------------------------------
LongMul PROC,
    longAddr1: DWORD, longAddr2: DWORD
; This procedure multiplies two QWORDs.
;---------------------------------------------------------------------------
    LOCAL isNegative:BYTE, tmpLong:QWORD
    pushad
    mov isNegative, 0
    lea esi, tmpLong
    INVOKE LongAssign, esi, longAddr1
    mov eax, [esi]
    .IF eax >= 80000000h
        xor isNegative, 1
        INVOKE LongNeg, longAddr1
    .ENDIF
    INVOKE LongAssign, esi, longAddr2
    mov eax, [esi]
    .IF eax >= 80000000h
        xor isNegative, 1
        INVOKE LongNeg, esi
    .ENDIF
    mov esi, [longAddr1]
    lea edi, tmpLong
    mov eax, [esi+4]
    mov edx, [edi+4]
    mul edx
    mov ebx, eax ; low
    mov ecx, edx ; high

    mov eax, [esi]
    mov edx, [edi+4]
    mul edx
    add ecx, eax
    mov eax, [esi+4]
    mov edx, [edi]
    mul edx
    add ecx, eax

    mov [esi], ecx
    mov [esi+4], ebx
    .IF isNegative != 0
        INVOKE LongNeg, longAddr1
    .ENDIF
    popad
    ret
LongMul ENDP

;---------------------------------------------------------------------------
LongDiv PROC,
    longAddr1: DWORD, longAddr2: DWORD, remainderAddr: DWORD
; This procedure divides two QWORDs, answer is in longAddr1, remainder is in remainderAddr.
;---------------------------------------------------------------------------
    LOCAL isNegative:BYTE, tmpLong:QWORD, tmpLong2:QWORD
    pushad
    mov isNegative, 0
    lea esi, tmpLong
    INVOKE LongAssign, esi, longAddr1
    mov eax, [esi]
    .IF eax >= 80000000h
        xor isNegative, 1
        INVOKE LongNeg, longAddr1
    .ENDIF
    lea edi, tmpLong2
    INVOKE LongAssign, edi, longAddr2
    mov eax, [edi]
    .IF eax >= 80000000h
        xor isNegative, 1
        INVOKE LongNeg, edi
    .ENDIF
    lea ebx, tmpLong2
    mov edx, [ebx]
    .IF edx != 0
        mov ecx, edx
        mov edx, 0
        mov ebx, [longAddr1]
        mov eax, [ebx]
        div ecx
        mov [esi], edx
        mov ecx, [ebx+4]
        mov [esi+4], ecx
        lea ebx, tmpLong2
        INVOKE LongSub, esi, ebx
        .IF DWORD PTR [esi] < 80000000h
            inc eax
        .ELSE
            INVOKE LongAdd, esi, ebx
        .ENDIF
        mov edi, [remainderAddr]
        INVOKE LongAssign, edi, esi
        mov ebx, [longAddr1]
        mov DWORD PTR [ebx], 0
        mov [ebx+4], eax
    .ELSE
        mov ecx, [ebx+4]
        mov ebx, [longAddr1]
        mov edx, 0
        mov eax, [ebx] ; div high first
        div ecx
        mov [ebx], eax
        mov eax, [ebx+4]
        div ecx ; will not overflow again
        mov [ebx+4], eax
        mov ebx, [remainderAddr]
        mov DWORD PTR [ebx], 0
        mov [ebx+4], edx
    .ENDIF
    .IF isNegative != 0
        INVOKE LongNeg, longAddr1
        INVOKE LongNeg, remainderAddr
    .ENDIF
    popad
    ret
LongDiv ENDP

;---------------------------------------------------------------------------
LongExp PROC,
    longAddr1: DWORD, longAddr2: DWORD
; This procedure calculates long1 Exp long2
;---------------------------------------------------------------------------
    LOCAL tmpLong:QWORD
    pushad
    lea esi, tmpLong
    mov DWORD PTR [esi], 0
    mov DWORD PTR [esi+4], 1
    mov ecx, 0
    mov eax, [longAddr2]
    mov edx, [eax+4]
    .WHILE ecx < edx
        inc ecx
        INVOKE LongMul, esi, longAddr1
    .ENDW
    INVOKE LongAssign, longAddr1, esi
    popad
    ret
LongExp ENDP

;---------------------------------------------------------------------------
StrToLong PROC,
    strAddr: DWORD, longAddr: DWORD
; This procedure converts a string into a QWORD.
;---------------------------------------------------------------------------
    LOCAL i:DWORD, tmpLong: QWORD, tmpLongAddr: DWORD, sumLong: QWORD, sumLongAddr: DWORD, power_of_10: QWORD, power_of_10Addr: DWORD
    pushad
    LEA eax, tmpLong
    mov tmpLongAddr, eax
    mov DWORD PTR [eax], 0
    mov DWORD PTR [eax+4], 0
    LEA eax, sumLong
    mov sumLongAddr, eax
    mov DWORD PTR [eax], 0
    mov DWORD PTR [eax+4], 0
    LEA eax, power_of_10
    mov power_of_10Addr, eax
    mov DWORD PTR [eax], 0
    mov DWORD PTR [eax+4], 0
    mov i, 0
    mov eax, [strAddr]
    mov ebx, i
    ; search for the end of str, i.e. where the null terminator is
    .WHILE BYTE PTR [eax + ebx] != 0 && BYTE PTR [eax + ebx] != 32
        inc ebx
    .ENDW
    mov i, ebx
    .IF i==0
        ; empty string
        mov [longAddr], 0
        mov [longAddr + 4], 0
    .ELSE
        ; non-empty
        ; for each char, if is a digit , add (ch - '0') * 10^digit to tmpLong
        ; then dec i and inc digit
        mov ecx, 0
        .WHILE ecx < i
            ; for each char within
            ; tmpLong = (ch - '0') * 10^digit
            mov esi, [strAddr]
            add esi, ecx
            mov eax, 0
            mov al, BYTE PTR [esi] ; the i-th char
            SUB al, '0'
            lea esi, tmpLong
            mov DWORD PTR [esi], 0
            mov DWORD PTR [esi+4], eax
            ; update power_of_10
            lea eax, power_of_10
            mov DWORD PTR [eax], 0
            mov DWORD PTR [eax+4], 10
            INVOKE LongMul, sumLongAddr, power_of_10Addr
            INVOKE LongAdd, sumLongAddr, tmpLongAddr
            ; update i
            inc ecx
        .ENDW
    .ENDIF
    INVOKE LongAssign, longAddr, sumLongAddr
    popad
    ret
StrToLong ENDP

;---------------------------------------------------------------------------
LongToStr PROC,
    longAddr:DWORD
; This procedure converts a QWORD into a string.
;---------------------------------------------------------------------------
    LOCAL tmpStr[MaxBufferSize]:BYTE, tmpInt:DWORD, negative: BYTE, tmpLong: QWORD
    pushad
    mov negative, 0
    lea esi, tmpStr
    INVOKE memset, esi, 0, MaxBufferSize
    mov ebx, [longAddr]
    ; check if is negative
    mov eax, [ebx]
    and eax, 80000000h
    JZ NON_NEGATIVE
    ; negative
    mov negative, 1
    pushad
    lea ebx, tmpLong
    mov DWORD PTR [ebx], 00000000h
    mov DWORD PTR [ebx + 4], 00000000h
    INVOKE LongSub, ebx, longAddr
    INVOKE LongAssign, longAddr, ebx ; now we get -Long
    popad
    NON_NEGATIVE:
    mov eax, [ebx + 4] ; TODO: expand to REAL 64-bit division
    .WHILE eax > 0
        lea ebx, tmpLong
        mov DWORD PTR [ebx], 00000000h
        mov DWORD PTR [ebx + 4], 0000000ah
        INVOKE LongDiv, longAddr, ebx, ADDR tmpLong
        mov ebx, [longAddr]
        mov eax, [ebx + 4]
        lea edi, tmpLong
        mov edx, [edi+4]
        add dl, '0'
        push eax
        INVOKE InsertChar, esi, 0, dl
        pop eax
        mov edx, 0
        inc ecx
    .ENDW
    .IF negative == 1
        ; negative, add a '-'
        INVOKE InsertChar, esi, 0, '-'
        inc ecx
    .ENDIF  
    push ecx
    INVOKE memset, longAddr, 0, MaxBufferSize
    pop ecx
    INVOKE strncpy, longAddr, esi, ecx
    popad
    ret
LongToStr ENDP

;---------------------------------------------------------------------------
ToLong PROC,
    dataAddr:DWORD, sizeAddr:DWORD, typeAddr:DWORD
; This procedure calculates long1 Exp long2
;---------------------------------------------------------------------------
    pushad
    mov esi, [sizeAddr]
    mov edi, [typeAddr]
    mov edx, [dataAddr]
    mov bl, [edi]
    .IF bl == TYPE_INT
        popad
        ret
    .ELSEIF bl == TYPE_BOOL
        mov al, [edx]
        .IF al == 0
            mov DWORD PTR [edx], 0
            mov DWORD PTR [edx+4], 0
        .ELSE
            mov DWORD PTR [edx], 0
            mov DWORD PTR [edx+4], 1
        .ENDIF
    .ENDIF
    mov BYTE PTR [edi], TYPE_INT
    mov WORD PTR [esi], 8
    popad
    ret
ToLong ENDP

END