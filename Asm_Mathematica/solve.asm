.386
.model flat, stdcall
option casemap: none

include  		calculate.inc
include			macro.inc
include         mathStack.inc
include         numasm.inc
strncpy			PROTO C :ptr sbyte, :ptr sbyte, :DWORD
strcpy			PROTO C :ptr sbyte, :ptr sbyte
strcat			PROTO C :ptr sbyte, :ptr sbyte
memset			PROTO C :ptr sbyte, :DWORD, :DWORD
strlen			PROTO C :ptr sbyte

.data

.code
;---------------------------------------------------------------------------
; in this section we will 

END