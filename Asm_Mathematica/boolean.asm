.386
.model flat, stdcall
option casemap: none

include  		calculate.inc
include			macro.inc

.data

.code
;---------------------------------------------------------------------------
BoolXor PROC,
    longAddr1: DWORD, longAddr2: DWORD
;---------------------------------------------------------------------------
    pushad
    ; todo
    popad
    ret
BoolXor ENDP

END