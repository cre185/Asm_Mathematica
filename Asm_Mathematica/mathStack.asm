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
; in this source file we mainly wish to manage stack in a more accurate way.
; To achieve this, we defined a specific way to store infos in the stack
; From the bottom to the top of the stack, we have:
; 1. DATA BODY, which is the data we want to store, and
; 2. DATA SIZE, a WORD (2 BYTES) to store the size (i.e. the number of BYTES) of the data body
; 3. DATA TYPE, a BYTE to store the type of the data body
;    ----ALL---POSSIBLE---TYPES----------
;    TYPE 00: INT           ---> integer    ---> 8 BYTES
;    TYPE 01: FLOAT         ---> float      ---> 8 BYTES
;    TYPE 02: STRING        ---> string     ---> ? BYTES
;    TYPE 03: STRUCT        ---> structure  ---> ? BYTES
;    TYPE 04: FUNCTION      ---> function   ---> ? BYTES
;    TYPE 05: VOID          ---> void       ---> 0 BYTES
;    TYPE 06: BOOL          ---> boolean    ---> 1 BYTE
;    TYPE 07: VAR           ---> variable   ---> ? BYTES
;    TYPE 08: EXPR          ---> expression ---> ? BYTES
;    TYPE 09: ARRAY         ---> array      ---> ? BYTES
;    TYPE 10: ERROR         ---> error      ---> ? BYTES
; The stack is a long array, consisting of MaxMathStackSize DWORDs
; Each time we want to operate the stack, 
;---------------------------------------------------------------------------

;---------------------------------------------------------------------------
TopType PROC,
    topAddr: DWORD, typeAddr: DWORD
; put the type of stack top to typeAddr
;---------------------------------------------------------------------------
    push ebx
    push eax
    MOV ebx, topAddr
    DEC ebx ; minus 1, since we only uses a BYTE to store the type
    MOV al, [ebx] ; get the type no.
    MOV BYTE PTR [typeAddr], al ; put the type no. into the buffer
    pop eax
    pop ebx
    RET
TopType ENDP

;---------------------------------------------------------------------------
TopSize PROC,
    topAddr: DWORD, sizeAddr: DWORD
; put the size of stack top to sizeAddr
;---------------------------------------------------------------------------
    push ebx
    push eax
    MOV ebx, topAddr
    SUB ebx, 3 ; minus 3, since we only uses a WORD to store the size, and a BYTE to store the type
    MOV ax, [ebx] ; get the size
    MOV WORD PTR [sizeAddr], ax ; put the size into the buffer
    pop eax
    pop ebx
    RET
TopSize ENDP

;---------------------------------------------------------------------------
TopData PROC,
    topAddr: DWORD, dataAddr: DWORD
; put the data of stack top to dataAddr
;---------------------------------------------------------------------------
    LOCAL dataSize: WORD
    INVOKE TopSize, topAddr, ADDR dataSize ; put the size of stack top to dataSize
    push esi
    push edi
    push eax
    push ecx
    MOV esi, topAddr
    SUB esi, 3
    MOV eax, 0
    MOV ax, dataSize ; now eax = dataSize
    SUB esi, eax ; esi points to the data body
    MOV edi, dataAddr ; edi points to the buffer
    MOV ecx, 0
    MOV cx, dataSize ; ecx is the size of data body
    CLD ; clear the direction flag, making the copy process from low address to high address
    REP MOVSB ; copy from esi to edi, ecx bytes; i.e. copy the data body to the buffer, dataSize times
    pop ecx
    pop eax
    pop edi
    pop esi
    RET
TopData ENDP

;---------------------------------------------------------------------------
TopPop PROC,
    topAddrAddr: DWORD
; pop the stack top, and put new top address into topAddrAddr
;---------------------------------------------------------------------------
    LOCAL dataSize: WORD
    INVOKE TopSize, [topAddrAddr], ADDR dataSize ; put the size of stack top to dataSize
    push ebx
    MOV bx, WORD PTR [topAddrAddr]
    SUB bx, 3
    SUB bx, dataSize ; ebx points to the data body
    MOV WORD PTR [topAddrAddr], bx ; put the address of data body into topAddr
    pop ebx
    RET
TopPop ENDP

;---------------------------------------------------------------------------
TopPush PROC,
    topAddrAddr: DWORD, dataAddr: DWORD, sizeAddr: DWORD, typeAddr: DWORD
; push data into stack top, and put new top address into topAddrAddr
;---------------------------------------------------------------------------
    LOCAL dataSize: WORD
    push eax
    push ecx
    push esi
    push edi
    MOV ax, WORD PTR [sizeAddr]
    MOV dataSize, ax 
    ; step1: put data into stack top
    MOV esi, dataAddr
    MOV edi, [topAddrAddr]
    MOV ecx, 0
    MOV cx, dataSize ; set ecx as dataSize
    CLD ; clear the direction flag, making the copy process from low address to high address
    REP MOVSB ; copy from esi to edi, ecx bytes; i.e. copy the data body to the stack top
    MOV eax, 0
    MOV ax, dataSize
    ADD [topAddrAddr], eax ; update stack top

    ; step2: put size into stack top
    MOV esi, sizeAddr
    MOV edi, [topAddrAddr]
    MOV ecx, 2
    CLD
    REP MOVSB
    ADD [topAddrAddr], 2 ; update the top addr

    ; step3: put type into stack top
    MOV esi, typeAddr
    MOV edi, [topAddrAddr]
    MOV ecx, 1
    CLD
    REP MOVSB
    ADD [topAddrAddr], 1 ; update the top addr
    pop edi
    pop esi
    pop ecx
    pop eax
    RET
TopPush ENDP


END