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
variableHashTable BYTE MaxVariableHashTableSize DUP(48)

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
    ret
Hash ENDP

;---------------------------------------------------------------------------
GetElemVarNameSize PROC,
    ptrAddr: DWORD, varNameSizeAddr: DWORD
; puts the variable name size of the element pointed by ptrAddr in varNameSizeAddr
;---------------------------------------------------------------------------
    ret
GetElemVarNameSize ENDP

;---------------------------------------------------------------------------
GetElemVarName PROC,
    ptrAddr: DWORD, varNameAddr: DWORD
; puts the variable name of the element pointed by ptrAddr in varNameAddr
;---------------------------------------------------------------------------
    ret
GetElemVarName ENDP

;---------------------------------------------------------------------------
GetElemVarType PROC,
    ptrAddr: DWORD, varTypeAddr: DWORD
; puts the variable type of the element pointed by ptrAddr in varTypeAddr
;---------------------------------------------------------------------------
    ret
GetElemVarType ENDP

;---------------------------------------------------------------------------
GetElemVarSize PROC,
    ptrAddr: DWORD, varSizeAddr: DWORD
; puts the variable size of the element pointed by ptrAddr in varSizeAddr
;---------------------------------------------------------------------------
    ret
GetElemVarSize ENDP

;---------------------------------------------------------------------------
GetElemVarValue PROC,
    ptrAddr: DWORD, varValueAddr: DWORD
; puts the variable value of the element pointed by ptrAddr in varValueAddr
;---------------------------------------------------------------------------
    ret
GetElemVarValue ENDP

;---------------------------------------------------------------------------
ToNextElem PROC,
    ptrAddr: DWORD
; let ptrAddr point to the next element in the hash table
;---------------------------------------------------------------------------
    ret
ToNextElem ENDP

;---------------------------------------------------------------------------
HashTableInsert PROC,
    inStrAddr: DWORD, inType: BYTE, inSize: WORD, inValueAddr: DWORD
; inserts a variable into the hash table
; VAR_NAME_SIZE = SIZEOF(inStrAddr), VAR_NAME = inStrAddr
; VAR_TYPE = inType, VAR_SIZE = inSize, VAR_VALUE = inValueAddr
;---------------------------------------------------------------------------
    ret
HashTableInsert ENDP

;---------------------------------------------------------------------------
HashTableSearch PROC,
    inStrAddr: DWORD, outAddr: DWORD
; returns the address of the variable in the hash table
;---------------------------------------------------------------------------
    ret
HashTableSearch ENDP


END