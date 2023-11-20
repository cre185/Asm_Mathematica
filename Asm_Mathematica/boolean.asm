.386
.model flat, stdcall
option casemap: none

include  		calculate.inc
include			macro.inc

.data

.code
;---------------------------------------------------------------------------
BoolAnd PROC,
    bool1: BYTE, bool2: BYTE
;---------------------------------------------------------------------------
    .IF bool1 == 0 || bool2 == 0
        mov eax, 0
    .ELSE 
        mov eax, 1
    .ENDIF
    ret
BoolAnd ENDP

;---------------------------------------------------------------------------
BoolOr PROC,
    bool1: BYTE, bool2: BYTE
;---------------------------------------------------------------------------
    .IF bool1 == 1 || bool2 == 1
        mov eax, 1
    .ELSE 
        mov eax, 0
    .ENDIF
    ret
BoolOr ENDP

;---------------------------------------------------------------------------
BoolXor PROC,
    bool1: BYTE, bool2: BYTE
;---------------------------------------------------------------------------
    pushad
    ; todo
    popad
    ret
BoolXor ENDP

;---------------------------------------------------------------------------
LongToBool PROC,
    longAddr:DWORD
;---------------------------------------------------------------------------
    pushad
    mov eax, [longAddr]
    mov ebx, [eax+4]
    .IF ebx == 0
        mov ebx, [eax]
        .IF ebx == 0
            mov BYTE PTR [eax], 1
        .ENDIF
    .ENDIF
    mov DWORD PTR [eax], 0
    popad
    ret
LongToBool ENDP

;---------------------------------------------------------------------------
DoubleToBool PROC,
    longAddr:DWORD
;---------------------------------------------------------------------------
    pushad
    mov eax, [longAddr]
    mov ebx, [eax+4]
    .IF ebx == 0
        mov ebx, [eax]
        .IF ebx == 0
            mov BYTE PTR [eax], 1
        .ENDIF
    .ENDIF
    mov DWORD PTR [eax], 0
    popad
    ret
DoubleToBool ENDP

END