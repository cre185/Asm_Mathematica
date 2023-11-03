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
; 2. DATA SIZE, a DWORD to store the size of the data body
; 3. DATA TYPE, a DWORD to store the type of the data body
;---------------------------------------------------------------------------

;---------------------------------------------------------------------------


END