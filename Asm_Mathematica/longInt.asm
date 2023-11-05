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
    push eax
    ; clear the answer
    MOV ansLongAddr, 0 
    MOV ansLongAddr + 4, 0 
    TEST eax, eax
    MOV eax, [longAddr1 + 4] ; the lower 32 bits of longAddr1
    ADD eax, [longAddr2 + 4] ; ................. of longAddr2
    JNC NO_CARRY
    ; if carry, then add 1 to the higher 32 bits
    INC [ansLongAddr + 4]
    NO_CARRY:
    MOV [ansLongAddr + 4], eax ; store the lower 32 bits of ansLongAddr

    MOV eax, [longAddr1] ; the higher 32 bits of longAddr1
    ADD eax, [longAddr2] ; the higher 32 bits of longAddr2
    ADD eax, [ansLongAddr] ; add the carry
    MOV [ansLongAddr], eax ; store the higher 32 bits of ansLongAddr
    pop eax
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
    push eax
    push ecx
    ; a simple method: 111...1 (n 1's)  = 1<<n - 1
    .IF n < 32
        ; put 1 in longAddr + 4 's higher n bits
        MOV [longAddr], 0
        MOV [longAddr + 4], 0 ; set to 64-bit 0's
        MOV eax, 1
        MOV ecx, n
        SHL eax, cl
        DEC eax
        MOV [longAddr + 4], eax
    .ELSE
        ; n >= 32
        ; put 1 in longAddr + 4
        MOV [longAddr + 4], 0FFFFFFFFh
        MOV [longAddr], 0
        MOV eax, 1
        MOV ecx, n
        SUB ecx, 32
        SHL eax, cl
        DEC eax
        MOV [longAddr], eax
    .ENDIF
    pop ecx
    pop eax
    RET
LongMaskLastNBits ENDP

;---------------------------------------------------------------------------
LongMaskNotLastNBits PROC,
    longAddr: DWORD, n: DWORD
; This procedure masks the not-last n bits of a QWORD.
;---------------------------------------------------------------------------
    push eax
    INVOKE LongMaskLastNBits, longAddr, n
    MOV eax, [longAddr]
    NOT eax
    MOV [longAddr], eax
    MOV eax, [longAddr + 4]
    NOT eax
    MOV [longAddr + 4], eax
    pop eax
    RET
LongMaskNotLastNBits ENDP

;---------------------------------------------------------------------------
LongLShift PROC,
    longAddr: DWORD, shiftCount: DWORD, ansLongAddr: DWORD
; This procedure shifts a QWORD to the left by shiftCount bits.
;---------------------------------------------------------------------------
    ; use rotate left
    ; bits rotated to the right 
    LOCAL tmp1: DWORD, tmp1Addr: DWORD, tmp2: DWORD, tmp2Addr: DWORD
    LOCAL tmpLong: QWORD, tmpLongAddr: DWORD
    push eax
    push ecx
    push edx
    LEA eax, tmp1
    MOV tmp1Addr, eax
    LEA eax, tmp2
    MOV tmp2Addr, eax
    LEA eax, tmpLong
    MOV tmpLongAddr, eax
    .IF shiftCount < 32
        ; shiftCount < 32
        ; for the right 32 bits:
        ; ROL shiftCount bits, then:
        ; INVOKE LongMaskLastNbits, longAddr, shiftCount   to get the last shiftCount bits
        ; then turn the last shiftCount bits to 0
        ; for the left 32 bits:
        ; SHL the higher 32 bits by shiftCount
        ; copy the last shiftCount bits to the higher 32 bits (via OR)
        MOV eax, [longAddr + 4]
        MOV ecx, shiftCount
        ROL eax, cl
        INVOKE LongMaskNotLastNBits, tmpLongAddr, shiftCount
        MOV edx, eax
        AND edx, [tmpLongAddr + 4] ; edx = the last 32 bits of new longAddr
        MOV [ansLongAddr + 4], edx
        INVOKE LongMaskLastNBits, tmpLongAddr, shiftCount
        MOV edx, eax
        AND edx, [tmpLongAddr] ; edx = the part that need to be added to the higher 32 bits
        MOV eax, [longAddr]
        SHL eax, cl
        OR eax, edx
        MOV[ansLongAddr], eax
    .ELSE
        ; put the last 64-shiftCount bits to the higher 32 bits
        MOV ecx, 64
        SUB ecx, shiftCount ; ecx = 64 - shiftCount
        INVOKE LongMaskNotLastNBits, tmpLongAddr, ecx
        MOV edx, [longAddr + 4]
        AND edx, [tmpLongAddr + 4]
        MOV ecx, shiftCount
        SUB ecx, 32
        SHL edx, cl
        MOV [ansLongAddr], edx
        MOV [ansLongAddr + 4], 0
    .ENDIF
    pop edx
    pop ecx
    pop eax
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
    push eax
    MOV eax, [longAddr2]
    MOV [longAddr1], eax
    MOV eax, [longAddr2 + 4]
    MOV [longAddr1 + 4], eax
    pop eax
    RET
LongAssign ENDP

;---------------------------------------------------------------------------
LongMul PROC,
    longAddr1: DWORD, longAddr2: DWORD, ansLongAddr: DWORD
; This procedure multiplies two QWORDs, answer is in ansLongAddr.
;---------------------------------------------------------------------------
    ; for every bit in longAddr2, if it is 1, then add longAddr1 << i to ansLongAddr
    LOCAL i: DWORD, tmpLong: QWORD, tmpLongAddr: DWORD, sumLong: QWORD, sumLongAddr: DWORD, tmpLong2: QWORD, tmpLong2Addr: DWORD
    push eax
    LEA eax, tmpLong
    MOV tmpLongAddr, eax
    LEA eax, sumLong
    MOV sumLongAddr, eax
    LEA eax, tmpLong2
    MOV tmpLong2Addr, eax
    MOV i, 0 ; start from the lowest bit
    MOV [ansLongAddr], 0
    MOV [ansLongAddr + 4], 0 ; set to 64-bit 0's
    MOV [sumLongAddr], 0
    MOV [sumLongAddr + 4], 0 ; set to 64-bit 0's
    .WHILE i < 64
        ; step 1: check if the i-th bit of longAddr2 is 1
        MOV [tmpLongAddr], 0
        MOV [tmpLongAddr + 4], 1 ; set to 63 0's and one 1
        INVOKE LongLShift, tmpLongAddr, i, tmpLong2Addr
        INVOKE LongAssign, tmpLongAddr, tmpLong2Addr
        INVOKE LongAnd, tmpLongAddr, longAddr2, tmpLong2Addr
        ; step 2: if the i-th bit is 1, then add longAddr1 << i to ansLongAddr
        .IF i < 32
            ; 1 in lower 32 bits
            MOV eax, [tmpLong2Addr + 4]
            TEST eax, eax
            JZ NO_ADD
            ; if the i-th bit is 1, then add longAddr1 << i to ansLongAddr
            INVOKE LongLShift, longAddr1, i, tmpLongAddr
            INVOKE LongAdd, sumLongAddr, tmpLongAddr, ansLongAddr
            INVOKE LongAssign, sumLongAddr, ansLongAddr
            NO_ADD:
        .ELSE
            ; 1 in higher 32 bits
            MOV eax, [tmpLong2Addr]
            TEST eax, eax
            JZ NO_ADD2
            ; if the i-th bit is 1, then add longAddr1 << i to ansLongAddr
            INVOKE LongLShift, longAddr1, i, tmpLongAddr
            INVOKE LongAdd, sumLongAddr, tmpLongAddr, ansLongAddr
            INVOKE LongAssign, sumLongAddr, ansLongAddr
            NO_ADD2:
        .ENDIF
        INC i
    .ENDW
    ; reaching here, ansLongAddr is the answer
    pop eax
    RET
LongMul ENDP

;---------------------------------------------------------------------------
LongDiv PROC,
    longAddr1: DWORD, longAddr2: DWORD, ansLongAddr: DWORD, remainderLongAddr: DWORD
; This procedure divides two QWORDs, answer is in ansLongAddr, remainder is in remainderLongAddr.
;---------------------------------------------------------------------------
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
    mov ebx, [i]
    ; search for the end of str, i.e. where the null terminator is
    .WHILE BYTE PTR [eax + ebx] != 0 && BYTE PTR [eax + ebx] != 32
        INC ebx
    .ENDW
    mov i, ebx
    .IF i==0
        ; empty string
        MOV [longAddr], 0
        MOV [longAddr + 4], 0
    .ELSE
        ; non-empty
        DEC i ; i is the index of the last char
        ; for each char, if is a digit , add (ch - '0') * 10^digit to tmpLong
        ; then dec i and inc digit
        .WHILE i != -1
            ; for each char within
            ; tmpLong = (ch - '0') * 10^digit
            mov esi, [strAddr]
            add esi, [i]
            MOV al, BYTE PTR [esi] ; the i-th char
            SUB al, '0'
            lea esi, tmpLong
            MOV DWORD PTR [esi], 0
            MOV DWORD PTR [esi+4], eax
            INVOKE LongMul, tmpLongAddr, power_of_10Addr, tmpLong2Addr
            INVOKE LongAdd , sumLongAddr, tmpLong2Addr, longAddr
            INVOKE LongAssign, sumLongAddr, longAddr
            ; update power_of_10
            lea eax, tmpLong
            MOV DWORD PTR [eax], 0
            MOV DWORD PTR [eax+4], 10
            INVOKE LongMul, power_of_10Addr, tmpLongAddr, tmpLong2Addr
            INVOKE LongAssign, power_of_10Addr, tmpLong2Addr
            ; update i
            DEC i
        .ENDW
    .ENDIF
    pop eax
    RET
StrToLong ENDP

;---------------------------------------------------------------------------
LongToStr PROC,
    longAddr: DWORD, strAddr: DWORD
; This procedure converts a QWORD into a string.
;---------------------------------------------------------------------------
    RET
LongToStr ENDP
END