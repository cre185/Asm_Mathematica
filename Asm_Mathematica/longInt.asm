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
LongAdd PROC,
    longAddr1: DWORD, longAddr2: DWORD, ansLongAddr: DWORD
; This procedure adds two QWORDs, answer is in ansLongAddr.
;---------------------------------------------------------------------------
    LOCAL Increase:DWORD
    pushad

    mov Increase, 0
    ; clear the answer
    mov eax, [ansLongAddr]
    MOV DWORD PTR [eax], 0 
    MOV DWORD PTR [eax+4], 0 
    mov ebx, [longAddr1]
    MOV eax, [ebx + 4] ; the lower 32 bits of longAddr1
    mov ebx, [longAddr2]
    ADD eax, [ebx + 4] ; ................. of longAddr2
    .IF CARRY?
        INC Increase
    .ENDIF
    mov ebx, [ansLongAddr]
    MOV [ebx+4], eax ; store the lower 32 bits of ansLongAddr

    mov ebx, [longAddr1]
    MOV eax, [ebx] ; the higher 32 bits of longAddr1
    mov ebx, [longAddr2]
    ADD eax, [ebx] ; the higher 32 bits of longAddr2
    ADD eax, Increase ; add the carry
    mov ebx, [ansLongAddr]
    MOV [ebx], eax ; store the higher 32 bits of ansLongAddr
    popad
    RET
LongAdd ENDP


;---------------------------------------------------------------------------
LongSub PROC,
    longAddr1: DWORD, longAddr2: DWORD, ansLongAddr: DWORD
; This procedure subtracts two QWORDs, answer is in ansLongAddr.
;---------------------------------------------------------------------------
    ; -longAddr2 = ~longAddr2 + 1
    LOCAL tmpLong: QWORD, tmpLongAddr: DWORD
    push ebx
    push eax
    LEA ebx, tmpLong
    MOV tmpLongAddr, ebx
    ; step1: tmp = ~long2
    MOV eax, [longAddr2 + 4]
    NOT eax
    MOV [tmpLongAddr + 4], eax
    MOV eax, [longAddr2]
    NOT eax
    MOV [tmpLongAddr], eax

    ; step2: tmp = tmp + 1
    TEST eax, eax
    INC [tmpLongAddr + 4]
    JNC NO_CARRY
    ; if carry, then add 1 to the higher 32 bits
    INC [tmpLongAddr]
    NO_CARRY:
    ; step3: ans = long1 + tmp
    INVOKE LongAdd, longAddr1, ADDR tmpLong, ansLongAddr
    pop eax
    pop ebx
    RET
LongSub ENDP

;---------------------------------------------------------------------------
LongMaskLastNBits PROC,
    longAddr: DWORD, n: DWORD
; This procedure masks the last n bits of a QWORD.
;---------------------------------------------------------------------------
    pushad
    ; a simple method: 111...1 (n 1's)  = 1<<n - 1
    .IF n < 32
        ; put 1 in longAddr + 4 's higher n bits
        mov ebx, [longAddr]
        MOV DWORD PTR [ebx], 0
        MOV DWORD PTR [ebx+4], 0 ; set to 64-bit 0's
        MOV eax, 1
        MOV ecx, n
        SHL eax, cl
        DEC eax
        mov ebx, [longAddr]
        MOV [ebx+4], eax
    .ELSE
        ; n >= 32
        ; put 1 in longAddr + 4
        mov ebx, [longAddr]
        MOV DWORD PTR [ebx+4], 0FFFFFFFFh
        MOV DWORD PTR [ebx], 0
        MOV eax, 1
        MOV ecx, n
        SUB ecx, 32
        SHL eax, cl
        DEC eax
        mov ebx, [longAddr]
        MOV [ebx], eax
    .ENDIF
    popad
    RET
LongMaskLastNBits ENDP

;---------------------------------------------------------------------------
LongMaskNotLastNBits PROC,
    longAddr: DWORD, n: DWORD
; This procedure masks the not-last n bits of a QWORD.
;---------------------------------------------------------------------------
    pushad
    INVOKE LongMaskLastNBits, longAddr, n
    MOV eax, [longAddr]
    NOT eax
    MOV [longAddr], eax
    MOV eax, [longAddr + 4]
    NOT eax
    mov ebx, [longAddr]
    MOV [ebx+4], eax
    popad
    RET
LongMaskNotLastNBits ENDP

;---------------------------------------------------------------------------
LongLShift PROC,
    longAddr: DWORD, shiftCount: DWORD
; This procedure shifts a QWORD to the left by shiftCount bits.
;---------------------------------------------------------------------------
    ; use rotate left
    ; bits rotated to the right 
    pushad
    mov ecx, shiftCount
    mov ebx, [longAddr]
    .WHILE ecx > 0
        mov eax, [ebx]
        mov edx, [ebx+4]
        shl eax, 1
        shl edx, 1
        .IF OVERFLOW?
            inc eax
        .ENDIF
        mov [ebx], eax
        mov [ebx+4], edx
        dec ecx
    .ENDW
    popad
    RET
LongLShift ENDP

;---------------------------------------------------------------------------
LongAnd PROC,
    longAddr1: DWORD, longAddr2: DWORD, ansLongAddr: DWORD
; This procedure performs a bitwise AND on two QWORDs, answer is in ansLongAddr.
;---------------------------------------------------------------------------
    push eax
    MOV eax, [longAddr1]
    AND eax, [longAddr2]
    MOV [ansLongAddr], eax
    MOV eax, [longAddr1 + 4]
    AND eax, [longAddr2 + 4]
    MOV [ansLongAddr + 4], eax
    pop eax
    RET
LongAnd ENDP

;---------------------------------------------------------------------------
LongAssign PROC,
    longAddr1: DWORD, longAddr2: DWORD
; This procedure assigns longAddr2 to longAddr1.
;---------------------------------------------------------------------------
    pushad
    mov ebx, [longAddr2]
    MOV eax, [ebx]
    mov ebx, [longAddr1]
    MOV [ebx], eax
    mov ebx, [longAddr2]
    MOV eax, [ebx + 4]
    mov ebx, [longAddr1]
    MOV [ebx + 4], eax
    popad
    RET
LongAssign ENDP

;---------------------------------------------------------------------------
LongMul PROC,
    longAddr1: DWORD, longAddr2: DWORD
; This procedure multiplies two QWORDs.
;---------------------------------------------------------------------------
    pushad
    mov esi, [longAddr1]
    mov edi, [longAddr2]
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
    popad
    RET
LongMul ENDP

;---------------------------------------------------------------------------
LongDiv PROC,
    longAddr1: DWORD, longAddr2: DWORD
; This procedure divides two QWORDs, answer is in longAddr1, remainder is in longAddr2.
;---------------------------------------------------------------------------
    pushad
    mov esi, [longAddr1]
    mov edi, [longAddr2]
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
    popad
    RET
LongDiv ENDP

;---------------------------------------------------------------------------
StrToLong PROC,
    strAddr: DWORD, longAddr: DWORD
; This procedure converts a string into a QWORD.
;---------------------------------------------------------------------------
    LOCAL i:DWORD,  tmpLong: QWORD, tmpLongAddr: DWORD, tmpLong2: QWORD, tmpLong2Addr: DWORD, sumLong: QWORD, sumLongAddr: DWORD, power_of_10: QWORD, power_of_10Addr: DWORD
    push eax
    LEA eax, tmpLong
    MOV tmpLongAddr, eax
    MOV DWORD PTR [eax], 0
    MOV DWORD PTR [eax+4], 0
    LEA eax, tmpLong2
    MOV tmpLong2Addr, eax
    MOV DWORD PTR [eax], 0
    MOV DWORD PTR [eax+4], 0
    LEA eax, sumLong
    MOV sumLongAddr, eax
    MOV DWORD PTR [eax], 0
    MOV DWORD PTR [eax+4], 0
    LEA eax, power_of_10
    MOV power_of_10Addr, eax
    MOV DWORD PTR [eax], 0
    MOV DWORD PTR [eax+4], 0
    MOV i, 0
    mov eax, [strAddr]
    mov ebx, i
    ; search for the end of str, i.e. where the null terminator is
    .WHILE BYTE PTR [eax + ebx] != 0 && BYTE PTR [eax + ebx] != 32
        inc ebx
    .ENDW
    mov i, ebx
    .IF i==0
        ; empty string
        MOV [longAddr], 0
        MOV [longAddr + 4], 0
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
            MOV al, BYTE PTR [esi] ; the i-th char
            SUB al, '0'
            lea esi, tmpLong
            MOV DWORD PTR [esi], 0
            MOV DWORD PTR [esi+4], eax
            ; update power_of_10
            lea eax, power_of_10
            MOV DWORD PTR [eax], 0
            MOV DWORD PTR [eax+4], 10
            INVOKE LongMul, sumLongAddr, power_of_10Addr
            INVOKE LongAdd, sumLongAddr, tmpLongAddr, longAddr
            INVOKE LongAssign, sumLongAddr, longAddr
            ; update i
            inc ecx
        .ENDW
    .ENDIF
    pop eax
    RET
StrToLong ENDP

;---------------------------------------------------------------------------
LongToStr PROC,
    longAddr:DWORD
; This procedure converts a QWORD into a string.
;---------------------------------------------------------------------------
    LOCAL tmpStr[MaxBufferSize]:BYTE
    pushad
    mov ebx, [longAddr]
    mov edx, [ebx] ; high
    mov eax, [ebx+4] ; low
    mov ecx, 0
    lea esi, tmpStr
    .WHILE eax > 0
        mov edi, 10
        div edi
        add dl, '0'
        push eax
        INVOKE InsertChar, esi, 0, dl
        pop eax
        mov edx, 0
        inc ecx
    .ENDW
    push ecx
    INVOKE memset, longAddr, 0, MaxBufferSize
    pop ecx
    INVOKE strncpy, longAddr, esi, ecx
    popad
    RET
LongToStr ENDP
END