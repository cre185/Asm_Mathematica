IFNDEF MACRO_INC
MACRO_INC equ <1>

IDI_ICON1 EQU 101

IDM_ABOUT EQU 1000
IDM_DOCUMENT EQU 1001

RowBoxMax EQU 1024
MY_CHANGESTATIC EQU 1000h

MaxBufferSize EQU 1024
OperatorListLength EQU 64
OperatorTableHeight EQU 7
OperatorTableLength EQU OperatorListLength*OperatorTableHeight

MaxMathStackSize EQU 32768
TYPE_INT        EQU     0
TYPE_DOUBLE     EQU     1
TYPE_STRING     EQU     2
TYPE_STRUCT     EQU     3
TYPE_FUNCTION   EQU     4
TYPE_VOID       EQU     5
TYPE_BOOL       EQU     6
TYPE_VAR        EQU     7
TYPE_EXPR       EQU     8
TYPE_ARRAY      EQU     9
TYPE_ERROR      EQU     10

MaxVariableHashTableSize EQU 1024
MaxVariableHashTableElemSize EQU 256

ENDIF