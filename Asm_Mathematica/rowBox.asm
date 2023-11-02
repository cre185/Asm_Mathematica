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
include			main.inc
include			macro.inc
includelib      msvcrt.lib
sprintf         PROTO C :ptr sbyte, :ptr sbyte, :VARARG
strlen			PROTO C :ptr sbyte
memset			PROTO C :ptr sbyte, :DWORD, :DWORD

;==================== DATA =======================
.data
ToMain DWORD 10001h
ToRowBox DWORD 10002h

RowBoxName BYTE "RowBox",0
ErrorTitle BYTE "Error",0
EDIT BYTE "Edit",0
STATIC BYTE "Static",0
SizeError BYTE "The buffer is not large enough for text in the Edit Wnd!",0
EmptyText BYTE 0
PngIn BYTE "in.bmp",0
PopupTitle BYTE "Popup Window",0
PopupText  BYTE "This window was activated by a "
	       BYTE "WM_LBUTTONDOWN message",0

InputMsg BYTE "In:[%d]",0
OutputMsg BYTE "Out:[%d]",0
TmpMsg BYTE 64 DUP(0)
public TmpMsg

RowBox WNDCLASS <NULL,BoxProc,NULL,NULL,NULL,NULL,NULL, \
	NULL,NULL,RowBoxName>
hRowBox DWORD RowBoxMax DUP(0)
hStatic DWORD RowBoxMax DUP(0)
hEditWnd DWORD RowBoxMax DUP(0)
originalEditProc DWORD ?
RowBoxCount DWORD 0

WndRect RECT <>
boxHeight DWORD 20
currentY DWORD 30
marginY DWORD 20
staticWidth DWORD 64
marginEdit DWORD 0
public WndRect, boxHeight, currentY, marginY, staticWidth, marginEdit

DRAWItemStruct STRUCT
	CtlType	DWORD      ?
	CtlID	DWORD      ?
	itemID  DWORD      ?
	itemAction DWORD    ?  
	itemState DWORD     ?
	hwndItem DWORD     ?
	hDC DWORD      ?
	rcItem DWORD    ?  
	itemData DWORD   ?   
DRAWItemStruct ENDS

extern hMainWnd:DWORD, hInstance:DWORD
extern recvBuffer:BYTE, ansBuffer:BYTE
extern CalCount:DWORD
;=================== CODE =========================
.code
CreateNewBox PROTO

;-----------------------------------------------------
GetEditIndex PROC,
	hWnd:DWORD
; Searching the hEditWnd for the index of hWnd in the array
; return value stored in ecx
;-----------------------------------------------------
	push eax
	push ebx
	mov eax, offset hEditWnd
	mov ecx, 0
L1:
	mov ebx, [eax]
	.IF ebx != hWnd && ecx < RowBoxMax
		add eax, 4
		inc ecx
		jmp L1
	.ENDIF
	pop ebx
	pop eax
	ret
GetEditIndex ENDP

;-----------------------------------------------------
BoxProc PROC,
	hWnd:DWORD, localMsg:DWORD, wParam:DWORD, lParam:DWORD
; A simple default Proc, only have to control the Static window
;-----------------------------------------------------
	mov eax, localMsg

	.IF eax == WM_CTLCOLORSTATIC
		mov eax, wParam
		mov edx, 0ff0000h
		invoke SetTextColor, eax, edx 
		mov edx, 0ffffffh
		invoke CreateSolidBrush, edx
		ret
	.ENDIF
	INVOKE DefWindowProc, hWnd, localMsg, wParam, lParam
	ret
BoxProc ENDP

;-----------------------------------------------------
EditProc PROC,
	hWnd:DWORD, localMsg:DWORD, wParam:DWORD, lParam:DWORD
; The edit box's message handler, which handles
; application-specific messages. All other messages
; are forwarded to the default Windows message
; handler.
;-----------------------------------------------------
	LOCAL EditIndex:DWORD
	mov eax, localMsg

	; Call the default Edit control under most situations
	.IF eax == WM_KEYDOWN && wParam == VK_RETURN
		INVOKE GetKeyState, VK_SHIFT
		and eax, 8000h
		.IF eax != 0
			INVOKE GetWindowTextLength, hEditWnd
			inc eax
			.IF eax > MaxBufferSize
				INVOKE MessageBox, NULL, addr ErrorTitle, addr SizeError, MB_OK
				ret
			.ENDIF

			INVOKE memset, ADDR recvBuffer, 0, MaxBufferSize
			INVOKE GetEditIndex, hWnd
			mov EditIndex, ecx
			INVOKE GetWindowText, [hEditWnd+4*ecx], ADDR recvBuffer, eax
			INVOKE CalculateResult

			; if the box is the latest: generate one extra box to show the calculate result
			mov ecx, EditIndex
			inc ecx
			.IF ecx == RowBoxCount
				INVOKE CreateNewBox
			.ENDIF

			; change the static content
			INVOKE sprintf, ADDR TmpMsg, ADDR InputMsg, CalCount
			mov ecx, EditIndex
			INVOKE SetWindowText, [hStatic+4*ecx], ADDR TmpMsg

			INVOKE sprintf, ADDR TmpMsg, ADDR OutputMsg, CalCount
			mov ecx, EditIndex
			inc ecx
			INVOKE SetWindowText, [hStatic+4*ecx], ADDR TmpMsg
			
			; get result in ansBuffer
			mov ecx, EditIndex
			inc ecx
			INVOKE SetWindowText, [hEditWnd+4*ecx], ADDR ansBuffer

			; ensure we have an empty box for new input
			mov ecx, EditIndex
			add ecx, 2
			.IF ecx == RowBoxCount
				INVOKE CreateNewBox
			.ENDIF
		.ENDIF
		ret
	.ELSEIF eax == WM_CHAR && wParam == VK_RETURN
		ret
	.ENDIF
	INVOKE CallWindowProc, originalEditProc, hWnd, localMsg, wParam, lParam
	ret
EditProc ENDP

;-----------------------------------------------------
InitRowBox PROC
; Initialize works like register the rowBox class
;-----------------------------------------------------
; Get a handle to the current process.
	mov eax, hInstance
	mov RowBox.hInstance, eax

; Load the program's icon and cursor.
	INVOKE LoadCursor, NULL, IDC_ARROW
	mov RowBox.hCursor, eax

; Initialize brush for main window 
	INVOKE CreateSolidBrush, 0ffffffh
	mov RowBox.hbrBackground, eax

; Register the window class.
	INVOKE RegisterClassA, ADDR RowBox
	.IF eax == 0
	  call ErrorHandler
	.ENDIF
	ret
InitRowBox ENDP

;-----------------------------------------------------
CreateNewBox PROC
; Create a new box 
;-----------------------------------------------------
	.IF hMainWnd == 0 
		ret
	.ENDIF

	; change the predecessor's size back to normal
	; always let the last window to fill the screen
	.IF RowBoxCount != 0
		mov ebx, RowBoxCount
		dec ebx
		INVOKE GetWindowRect, [hRowBox+4*ebx], ADDR WndRect
		mov edx, WndRect.right
		sub edx, WndRect.left
		INVOKE SetWindowPos, [hRowBox+4*ebx], NULL, NULL, NULL, edx, boxHeight, SWP_NOMOVE+SWP_NOOWNERZORDER
	.ENDIF

	INVOKE GetWindowRect, hMainWnd, ADDR WndRect
	.IF eax == 0
		 call ErrorHandler
	.ENDIF
	mov eax, WndRect.right
	sub eax, WndRect.left
	sub eax, 100
	mov edx, WndRect.bottom
	sub edx, WndRect.top
	INVOKE CreateWindowEx, 0, ADDR RowBoxName,
		NULL, WS_CHILD+WS_VISIBLE, 
		20, currentY, eax, 
		edx,hMainWnd,ToMain,hInstance,NULL
	.IF eax == 0
		call ErrorHandler
		pop eax
		ret
	.ENDIF
	mov ebx, RowBoxCount
	mov [hRowBox+4*ebx], eax

	mov eax, currentY
	add eax, boxHeight
	add eax, marginY
	mov currentY, eax
	INVOKE CreateWindowEx, 0, ADDR STATIC,
		NULL, WS_CHILD+WS_VISIBLE+SS_CENTER, 
		0, 0, staticWidth, 
		boxHeight,[hRowBox+4*ebx],ToRowBox,hInstance,NULL
	.IF eax == 0
		call ErrorHandler
		pop eax
		ret
	.ENDIF
	mov [hStatic+4*ebx], eax

	mov edx, WndRect.bottom
	sub edx, WndRect.top
	INVOKE CreateWindowEx, 0, ADDR EDIT,
		NULL, WS_CHILD+WS_VISIBLE+ES_LEFT, 
		staticWidth, 0, eax, 
		edx,[hRowBox+4*ebx],ToRowBox,hInstance,NULL
	.IF eax == 0
		call ErrorHandler
		ret
	.ENDIF
	mov [hEditWnd+4*ebx], eax
	INVOKE ShowWindow, [hEditWnd+4*ebx], SW_SHOW
	INVOKE SetWindowLong, [hEditWnd+4*ebx], GWLP_WNDPROC, ADDR EditProc
	.IF eax == 0
		call ErrorHandler
	.ENDIF
	mov originalEditProc, eax

	inc RowBoxCount
	ret
CreateNewBox ENDP

;-----------------------------------------------------
ChangeBoxSize PROC
; Change the size of boxed based on the main window size
;-----------------------------------------------------
	.IF hMainWnd == 0 
		ret
	.ENDIF
	INVOKE GetWindowRect, hMainWnd, ADDR WndRect
	.IF eax == 0
		 call ErrorHandler
	.ENDIF
	mov eax, WndRect.right
	sub eax, WndRect.left
	sub eax, 100
	mov ebx, staticWidth
	add ebx, marginEdit
	sub eax, ebx
	mov ecx, RowBoxCount
	dec ecx
	INVOKE MoveWindow, [hEditWnd+4*ecx], ebx, 0, eax, boxHeight, 1
	ret
ChangeBoxSize ENDP

END