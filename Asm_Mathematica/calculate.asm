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

.data
recvBuffer BYTE MaxBufferSize DUP(0)
ansBuffer BYTE MaxBufferSize DUP(0)
public recvBuffer, ansBuffer

TestTitle BYTE "test",0
TestText BYTE "reached here!",0

CalCount DWORD 0
public CalCount
.code
;-----------------------------------------------------
CalculateResult PROC
; Analyze the buffer and calculate the answer
; Answer storing in ansBuffer
;-----------------------------------------------------
	inc CalCount
	; todo: use any treatments you like and get the result
	; following are testing information
	mov eax, offset ansBuffer
	mov BYTE PTR [eax], 72		; 'H'
	mov BYTE PTR [eax+1], 73	; 'I'
	mov BYTE PTR [eax+2], 33	; '!'
	ret
CalculateResult ENDP

END