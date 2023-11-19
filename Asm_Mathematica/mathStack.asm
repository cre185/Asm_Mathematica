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

calculationStack BYTE MaxMathStackSize DUP(48)
calculationStackTop DWORD calculationStack
calculationStackBase DWORD calculationStack
public calculationStack, calculationStackTop, calculationStackBase

standardError BYTE "Invalid expression!", 0

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
;    TYPE 01: DOUBLE        ---> float      ---> 8 BYTES
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
;---------------------------------------------------------------------------

;---------------------------------------------------------------------------
TopType PROC,
    typeAddr: DWORD
; put the type of stack top to typeAddr
;---------------------------------------------------------------------------
    pushad
    mov ebx, calculationStackTop
    .IF ebx == calculationStackBase
        ; the stack is empty
        ; put TYPE_VOID into typeAddr
        mov edx, [typeAddr]
        mov BYTE PTR [edx], TYPE_VOID
        popad
        ret
    .ENDIF
    dec ebx ; minus 1, since we only uses a BYTE to store the type
    mov al, BYTE PTR [ebx] ; get the type no.
    mov edx, [typeAddr]
    mov BYTE PTR [edx], al ; put the type no. into the buffer
    popad
    ret
TopType ENDP

;---------------------------------------------------------------------------
TopSize PROC,
    sizeAddr: DWORD
; put the size of stack top to sizeAddr
;---------------------------------------------------------------------------
    pushad
    mov ebx, calculationStackTop
    .IF ebx == calculationStackBase
        ; the stack is empty
        ; put 0 into sizeAddr
        mov edx, [sizeAddr]
        mov WORD PTR [edx], 0
        popad
        ret
    .ENDIF
    SUB ebx, 3 ; minus 3, since we only uses a WORD to store the size, and a BYTE to store the type
    mov ax, WORD PTR [ebx] ; get the size
    mov ebx, [sizeAddr]
    mov WORD PTR [ebx], ax ; put the size into the buffer
    popad
    ret
TopSize ENDP

;---------------------------------------------------------------------------
TopData PROC,
    dataAddr: DWORD
; put the data of stack top to dataAddr
;---------------------------------------------------------------------------
    LOCAL dataSize:WORD, stackData:DWORD
    pushad
    mov ebx, calculationStackTop
    .IF ebx == calculationStackBase
        ; the stack is empty
        ; put nothing into dataAddr
        popad
        ret
    .ENDIF
    INVOKE TopSize, ADDR dataSize ; put the size of stack top to dataSize
    mov eax, calculationStackTop
    sub ax, dataSize
    sub eax, 3
    mov stackData, eax
    mov ecx, 0
    .WHILE cx < dataSize
        mov ebx, [stackData]
        mov al, BYTE PTR [ebx+ecx]
        mov ebx, [dataAddr]
        mov BYTE PTR [ebx+ecx], al
        inc ecx
    .ENDW
    popad
    ret
TopData ENDP

;---------------------------------------------------------------------------
TopPop PROC
; pop the stack top
;---------------------------------------------------------------------------
    LOCAL dataSize: WORD
    pushad
    mov ebx, calculationStackTop
    .IF ebx == calculationStackBase
        ; the stack is empty
        popad
        ret
    .ENDIF
    lea eax, dataSize
    INVOKE TopSize, eax ; put the size of stack top to dataSize
    mov eax, 0
    mov ax, dataSize
    SUB calculationStackTop, eax
    SUB calculationStackTop, 3 ; ebx points to the data body
    popad
    ret
TopPop ENDP

;---------------------------------------------------------------------------
TopPush PROC,
    dataAddr: DWORD, dataSize: WORD, dataType: BYTE
; push data into stack top, and put new top address into topAddr
;---------------------------------------------------------------------------
    pushad
    ; step1: put data into stack top
    mov ecx, 0
    .WHILE cx < dataSize
        mov ebx, [dataAddr]
        mov al, BYTE PTR [ebx+ecx]
        mov ebx, [calculationStackTop]
        mov BYTE PTR [ebx+ecx], al
        inc ecx
    .ENDW
    mov eax, 0
    mov ax, dataSize
    ADD calculationStackTop, eax ; update stack top

    ; step2: put dataSize into stack top
    mov bx, dataSize
    mov eax, [calculationStackTop]
    mov WORD PTR [eax], bx
    ADD calculationStackTop, 2 ; update the top addr

    ; step3: put type into stack top
    mov bl, dataType
    mov eax, [calculationStackTop]
    mov BYTE PTR [eax], bl
    ADD calculationStackTop, 1 ; update the top addr
    popad
    ret
TopPush ENDP

;---------------------------------------------------------------------------
GetHistory PROC,
    index:DWORD
; get the ith calculated history and push it on the top of the stack
;---------------------------------------------------------------------------
    LOCAL dataSize: WORD, dataType: BYTE
    pushad
    mov ecx, index
    dec ecx
    mov ebx, calculationStackBase
    .WHILE ecx > 0
        sub ebx, 3
        mov ax, WORD PTR [ebx] ; get the size
        sub bx, ax
        dec ecx
    .ENDW
    dec ebx
    mov al, BYTE PTR [ebx]
    mov dataType, al
    sub ebx, 2
    mov ax, WORD PTR [ebx]
    mov dataSize, ax
    mov edx, 0
    mov dx, ax
    sub ebx, edx
    INVOKE TopPush, ebx, dataSize, dataType
    popad
    ret
GetHistory ENDP

;---------------------------------------------------------------------------
TopPushError PROC,
    errorAddr: DWORD
; generate an error message and push the error onto the stack
;---------------------------------------------------------------------------
    pushad
    INVOKE strlen, errorAddr
    INVOKE TopPush, errorAddr, ax, TYPE_ERROR
    popad
    ret
TopPushError ENDP

;---------------------------------------------------------------------------
TopPushStandardError PROC
; generate a standard error message and push the error onto the stack
;---------------------------------------------------------------------------
    pushad
    INVOKE TopPushError, ADDR standardError
    popad
    ret
TopPushStandardError ENDP

END