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
BoolNot PROC,
    bool: BYTE
;---------------------------------------------------------------------------
    .IF bool == 1
        mov eax, 0
    .ELSE 
        mov eax, 1
    .ENDIF
    ret
BoolNot ENDP

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
            mov BYTE PTR [eax], 0
            popad
            ret
        .ENDIF
    .ENDIF
    mov DWORD PTR [eax], 1
    popad
    ret
LongToBool ENDP

;---------------------------------------------------------------------------
DoubleToBool PROC,
    longAddr:DWORD
;---------------------------------------------------------------------------
    pushad
    fldz
    mov eax, [longAddr]
    fcomp REAL8 PTR [eax]
    fnstsw ax
    sahf
    mov eax, [longAddr]
    .IF ZERO?
        mov BYTE PTR [eax], 0
    .ELSE
        mov BYTE PTR [eax], 1
    .ENDIF
    popad
    ret
DoubleToBool ENDP

;---------------------------------------------------------------------------
ToBool PROC,
    dataAddr:DWORD, sizeAddr:DWORD, typeAddr:DWORD
;---------------------------------------------------------------------------
    pushad
    mov esi, [sizeAddr]
    mov edi, [typeAddr]
    mov edx, [dataAddr]
    mov bl, [edi]
    .IF bl == TYPE_BOOL
        popad
        ret
    .ELSEIF bl == TYPE_INT
        INVOKE LongToBool, dataAddr
    .ELSEIF bl == TYPE_DOUBLE
        INVOKE DoubleToBool, dataAddr
    .ENDIF
    mov WORD PTR [esi], 1
    mov BYTE PTR [edi], TYPE_BOOL
    popad
    ret
ToBool ENDP

END