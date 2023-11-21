.386
.model flat, stdcall
option casemap: none

include  		calculate.inc
include			macro.inc
strcmp          PROTO C :ptr sbyte, :ptr sbyte
strncpy			PROTO C :ptr sbyte, :ptr sbyte, :DWORD
strcpy			PROTO C :ptr sbyte, :ptr sbyte
strcat			PROTO C :ptr sbyte, :ptr sbyte
memset			PROTO C :ptr sbyte, :DWORD, :DWORD
strlen			PROTO C :ptr sbyte

.data
variableHashTable BYTE MaxVariableHashTableSize*256 DUP(0) ; MaxVariableHashTableSize elems, each elem is 256 bytes

.code
;---------------------------------------------------------------------------
; in this source file, we wish to establish a hash table for variables, that
; is able to store the variable name and its value. 
; We are using hash Table in that it is highly efficient in searching, 
; at the cost of a higher rate of memory usage.
; 
; In this source file we have a Hash() to calculate the hash value of a
; given variable nam; a HashTableInsert() to insert a variable into
; the hash table; and a HashTableSearch() to search for a variable in the hash table.
;---------------------------------------------------------------------------
; the elems in hash table are in the form of:
; LOW:|<--VAR NAME SIZE-->|<--VAR NAME-->|<--VAR TYPE-->|<--VAR SIZE-->|<--VAR VALUE-->|:HIGH
; 1. VAR NAME SIZE (2 bytes): the size of the variable name
; 2. VAR NAME (VAR NAME SIZE bytes): the variable name
; 3. VAR TYPE (1 byte): the type of the variable
; 4. VAR SIZE (2 bytes): the size of the variable
; 5. VAR VALUE (VAR SIZE bytes): the value of the variable
;---------------------------------------------------------------------------

;---------------------------------------------------------------------------
Hash PROC,
    inStrAddr: DWORD, outHashAddr: DWORD
; gets a string from inStrAddr, and calculates its hash value
; puts the hash value in outHashAddr
;---------------------------------------------------------------------------
    ; e.g. for varName = "Example":
    ; hashVal = ("E"*2^10 + "x"*2^9 + "a"*2^8 + "m"*2^7 + "p"*2^6 + "l"*2^5 + "e"*2^4) % MaxVariableHashTableSize
    ; using the formula: hashVal = sum(varName[i]*2^(n-i-1)), where n = SIZEOF(varName)
    ; hashVal in [0, MaxVariableHashTableSize-1]
    LOCAL sum: DWORD, i:DWORD
    pushad
    mov ebx, inStrAddr
    mov ecx, MaxVariableHashTableSize
    shr ecx, 1 ; ecx = MaxVariableHashTableSize / 2
    mov sum, 0 ; set sum to 0
    mov i, 0 ; set i to 0
    .WHILE ecx != 0 && BYTE PTR [ebx] != 0
        mov al, BYTE PTR [ebx]
        mul ecx ; eax = al*2^l
        add sum, eax ; sum = sum + al*2^cl
        inc ebx
        inc i
        shr ecx, 1
    .ENDW
    ; then: get sum % MaxVariableHashTableSize into outHashAddr
    mov eax, sum
    mov ebx, MaxVariableHashTableSize
    div ebx ; eax = sum / MaxVariableHashTableSize, edx = sum % MaxVariableHashTableSize
    mov ecx, outHashAddr
    mov [ecx], edx ; put remainder in outHashAddr
    popad
    ret
Hash ENDP

;---------------------------------------------------------------------------
GetElemVarNameSize PROC,
    elemPtr: DWORD, varNameSizeAddr: DWORD
; puts the variable name size of the element pointed by elemPtr in varNameSizeAddr
;---------------------------------------------------------------------------
    pushad
    mov ebx, elemPtr ; points at the element head, then:
    mov ax, WORD PTR [ebx] ; read 2 bytes from [ebx] to ax
    mov edx, varNameSizeAddr
    mov [edx], ax
    popad
    ret
GetElemVarNameSize ENDP

;---------------------------------------------------------------------------
GetElemVarName PROC,
    elemPtr: DWORD, varNameAddr: DWORD
; puts the variable name of the element pointed by elemPtr in varNameAddr
;---------------------------------------------------------------------------
    LOCAL varNameSize: WORD
    pushad
    INVOKE GetElemVarNameSize, elemPtr, ADDR varNameSize
    ; now in varNameSize we have the variable name size
    ; load varNameSize bytes from elemPtr + 2 to varNameAddr
    mov esi, elemPtr
    add esi, 2 ; esi points at the variable name
    mov edi, varNameAddr
    mov cx, varNameSize
    .WHILE ecx > 0
        mov al, BYTE PTR [esi]
        mov BYTE PTR [edi], al
        inc esi
        inc edi
        dec ecx
    .ENDW
    mov BYTE PTR [edi], 0 ; terminate the string
    popad
    ret
GetElemVarName ENDP

;---------------------------------------------------------------------------
GetElemVarType PROC,
    elemPtr: DWORD, varTypeAddr: DWORD
; puts the variable type of the element pointed by elemPtr in varTypeAddr
;---------------------------------------------------------------------------
    LOCAL varNameSize: WORD
    pushad
    INVOKE GetElemVarNameSize, elemPtr, ADDR varNameSize
    mov ebx, elemPtr
    add ebx, 2 ; ebx points at the variable name
    mov edx, 0
    mov dx, varNameSize
    add ebx, edx ; ebx points at the variable type
    ; read 1 byte from [ebx] to varTypeAddr
    mov edx, [varTypeAddr]
    mov al, BYTE PTR [ebx]
    mov BYTE PTR [edx], al
    popad
    ret
GetElemVarType ENDP

;---------------------------------------------------------------------------
GetElemVarSize PROC,
    elemPtr: DWORD, varSizeAddr: DWORD
; puts the variable size of the element pointed by elemPtr in varSizeAddr
;---------------------------------------------------------------------------
    LOCAL varNameSize: WORD
    pushad
    INVOKE GetElemVarNameSize, elemPtr, ADDR varNameSize
    mov ebx, elemPtr
    add ebx, 2 ; ebx points at the variable name
    mov edx, 0
    mov dx, varNameSize
    add ebx, edx ; ebx points at the variable type
    inc ebx ; ebx points at the variable size
    ; read 2 bytes from [ebx] to varSizeAddr
    mov edx, varSizeAddr
    mov ax, WORD PTR [ebx]
    mov WORD PTR [edx], ax
    popad
    ret
GetElemVarSize ENDP

;---------------------------------------------------------------------------
GetElemVarValue PROC,
    elemPtr: DWORD, varValueAddr: DWORD
; puts the variable value of the element pointed by elemPtr in varValueAddr
;---------------------------------------------------------------------------
    LOCAL varNameSize: WORD, varSize: WORD
    pushad
    INVOKE GetElemVarNameSize, elemPtr, ADDR varNameSize
    INVOKE GetElemVarSize, elemPtr, ADDR varSize
    mov ebx, elemPtr
    add ebx, 2 ; ebx points at the variable name
    mov edx, 0
    mov dx, varNameSize
    add ebx, edx ; ebx points at the variable type
    add ebx, 3 ; ebx points at the variable value
    ; read varSize bytes from [ebx] to varValueAddr
    mov esi, ebx
    mov edi, varValueAddr
    mov cx, varSize
    .WHILE ecx > 0
        mov al, BYTE PTR [esi]
        mov BYTE PTR [edi], al
        inc esi
        inc edi
        dec ecx
    .ENDW
    popad
    ret
GetElemVarValue ENDP

;---------------------------------------------------------------------------
HashTableInsert PROC,
    inStrAddr: DWORD, inType: BYTE, inSize: WORD, inValueAddr: DWORD
; inserts a variable into the hash table
; VAR_NAME_SIZE = SIZEOF(inStrAddr), VAR_NAME = inStrAddr
; VAR_TYPE = inType, VAR_SIZE = inSize, VAR_VALUE = inValueAddr
;---------------------------------------------------------------------------
    LOCAL hashVal: DWORD, inStrSize: WORD, varNameSize: WORD, tmpStr[256]: BYTE
    pushad
    INVOKE Hash, inStrAddr, ADDR hashVal ; get the hashVal of inStrAddr
    mov eax, hashVal
    shl eax, 8 ; eax = hashVal * 256
    ; now we wish to find the elem in variableHashTable[hashVal]
    mov edi, OFFSET variableHashTable
    add edi, eax ; edi points at the first elem in the hash table
    ; get the var name size
    INVOKE GetElemVarNameSize, edi, ADDR varNameSize
    mov bx, varNameSize
    cmp bx, 0
    jne collision ; if not empty, collision occurs
    insertIntoHashTable:
        ; 1. var name size
        INVOKE strlen, inStrAddr
        mov WORD PTR [edi], ax ; put the size of inStrAddr in the first 2 bytes of the elem
        add edi, 2
        ; 2. var name
        pushad
        INVOKE strcpy, edi, inStrAddr ; put inStrAddr ---> edi
        popad
        add edi, eax
        ; 3. var type
        mov al, inType
        mov BYTE PTR [edi], al
        add edi, 1 
        ; 4. var size
        mov ax, inSize
        mov WORD PTR [edi], ax
        add edi, 2
        ; 5. var value
        mov esi, inValueAddr
        mov ecx, 0
        .WHILE cx < inSize
            mov bl, [esi+ecx]
            mov [edi+ecx], bl
            inc cx
        .ENDW
        ; done
        popad
        ret
    collision:
        ; hash collision!
        ; first check if is empty
        ; then check if is the same variable. if so, update the value
        ; else: go to the next elem
        INVOKE GetElemVarNameSize, edi, ADDR varNameSize
        .IF varNameSize == 0
            ; empty
            jmp insertIntoHashTable
        .ENDIF
        INVOKE GetElemVarName, edi, ADDR tmpStr
        INVOKE strcmp, inStrAddr, ADDR tmpStr
        ; eax == 0 if the two strings are the same
        ; eax != 0 if the two strings are different
        .IF eax == 0
            ; same var
            jmp insertIntoHashTable
        .ENDIF
        ; not the same var
        ; go for next elem
        add edi, 256
        jmp collision
    popad
    ret
HashTableInsert ENDP

;---------------------------------------------------------------------------
HashTableSearch PROC,
    inStrAddr: DWORD, outPtrAddr: DWORD
; puts the pointer to the desired elem (specified by inStrAddr) in the given addr
;---------------------------------------------------------------------------
    LOCAL hashVal: DWORD, inStrSize: WORD, varNameSize: WORD, tmpStr[256]: BYTE
    pushad
    INVOKE Hash, inStrAddr, ADDR hashVal ; get the hashVal of inStrAddr
    mov eax, hashVal
    shl eax, 8 ; eax = hashVal * 256
    ; now we wish to find the elem in variableHashTable[hashVal]
    mov edi, OFFSET variableHashTable
    add edi, eax ; edi points at the first elem in the hash table
    ; get the var name size
    INVOKE GetElemVarNameSize, edi, ADDR varNameSize
    mov bx, varNameSize
    cmp bx, 0
    je Empty ; if varNameSize == 0, then the elem is empty, ==> elem not found
    ; not empty
    ; go on to check if the var name is the same
    L1:
        ; first check if is empty
        INVOKE GetElemVarNameSize, edi, ADDR varNameSize 
        .IF varNameSize == 0
            ; empty
            jmp Empty
        .ENDIF
        ; not empty
        INVOKE GetElemVarName, edi, ADDR tmpStr
        INVOKE strcmp, inStrAddr, ADDR tmpStr
        .IF eax == 0
            ; exists!
            ; put current edi in outPtrAddr
            mov ebx, outPtrAddr
            mov [ebx], edi
            popad
            ret
        .ENDIF
        ; not the same var
        ; just go on
        add edi, 256
        jmp L1   
    Empty:
        ; put 0 in  outPtrAddr 
        mov eax, 0
        mov ebx, outPtrAddr
        mov [ebx], eax
        popad
        ret
    popad
    ret
HashTableSearch ENDP

;---------------------------------------------------------------------------
HashTableDelete PROC,
    inStrAddr: DWORD
; deletes the elem specified by inStrAddr
;---------------------------------------------------------------------------
    LOCAL elemPtr: DWORD
    pushad
    INVOKE HashTableSearch, inStrAddr, ADDR elemPtr
    .IF elemPtr == 0
        ; not found
        ; do nothing
        popad
        ret
    .ENDIF
    ; found
    mov ecx, 0
    mov edi, elemPtr
    .WHILE ecx < 256
        mov BYTE PTR [edi + ecx], 0
    .ENDW
    popad
    ret
HashTableDelete ENDP

END