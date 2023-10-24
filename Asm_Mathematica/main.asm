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
include			resource.inc

MSGStruct STRUCT
  msgWnd        DWORD ?
  msgMessage    DWORD ?
  msgWparam     DWORD ?
  msgLparam     DWORD ?
  msgTime       DWORD ?
  msgPt         POINT <>
MSGStruct ENDS

MAIN_WINDOW_STYLE = WS_VISIBLE+WS_DLGFRAME+WS_CAPTION+WS_BORDER+WS_SYSMENU \
	+WS_MAXIMIZEBOX+WS_MINIMIZEBOX+WS_THICKFRAME

;==================== DATA =======================
.data
FromEdit DWORD 10000h

AppLoadMsgTitle BYTE "Application Loaded",0
AppLoadMsgText  BYTE "This window displays when the WM_CREATE "
	            BYTE "message is received",0

PopupTitle BYTE "Popup Window",0
PopupText  BYTE "This window was activated by a "
	       BYTE "WM_LBUTTONDOWN message",0

GreetTitle BYTE "Main Window Active",0
GreetText  BYTE "This window is shown immediately after "
	       BYTE "CreateWindow and UpdateWindow are called.",0

ErrorTitle  BYTE "Error",0
EmptyText BYTE 0
public EmptyText

WindowName  BYTE "Asm Mathematica",0
className   BYTE "ASMWin",0

fileMsg    BYTE "文件",0
subMsg     BYTE "新建",0
sub2ndMsg  BYTE "打开",0
EDIT	   BYTE "Edit",0

msg	      MSGStruct <>
winRect   RECT <>
hMainWnd  DWORD 0
hEditWnd  DWORD ?
public hMainWnd, hEditWnd

hFileMenu DWORD ?
hSubMenu  DWORD ?
public hFileMenu, hSubMenu

hInstance DWORD ?

; Define the Application's Window class structure.
MainWin WNDCLASS <NULL,WinProc,NULL,NULL,NULL,NULL,NULL, \
	COLOR_WINDOW,NULL,className>

;=================== CODE =========================
.code

InitMenu PROTO 

WinMain PROC
; Get a handle to the current process.
	INVOKE GetModuleHandle, NULL
	mov hInstance, eax
	mov MainWin.hInstance, eax

; Load the program's icon and cursor.
	INVOKE LoadIcon, hInstance, IDI_ICON1
	mov MainWin.hIcon, eax
	INVOKE LoadCursor, NULL, IDC_ARROW
	mov MainWin.hCursor, eax

; Initialize brush for main window 
	INVOKE CreateSolidBrush, 0ffffffh
	mov MainWin.hbrBackground, eax

; Register the window class.
	INVOKE RegisterClassA, ADDR MainWin
	.IF eax == 0
	  call ErrorHandler
	  jmp Exit_Program
	.ENDIF

; Create the application's main window.
; Returns a handle to the main window in EAX.
	INVOKE CreateWindowEx, 0, ADDR className,
	  ADDR WindowName,MAIN_WINDOW_STYLE,
	  CW_USEDEFAULT,CW_USEDEFAULT,CW_USEDEFAULT,
	  CW_USEDEFAULT,NULL,NULL,hInstance,NULL
	mov hMainWnd,eax

; If CreateWindowEx failed, display a message & exit.
	.IF eax == 0
	  call ErrorHandler
	  jmp  Exit_Program
	.ENDIF

; Create a menu
	INVOKE InitMenu

; Show and draw the window.
	INVOKE ShowWindow, hMainWnd, SW_SHOW
	INVOKE UpdateWindow, hMainWnd

; Begin the program's message-handling loop.
Message_Loop:
	; Get next message from the queue.
	INVOKE GetMessage, ADDR msg, NULL,NULL,NULL

	; Quit if no more messages.
	.IF eax == 0
		jmp Exit_Program
	.ENDIF

	; Translate the message for edit to receive it 
	INVOKE TranslateMessage, ADDR msg

	; Relay the message to the program's WinProc.
	INVOKE DispatchMessage, ADDR msg
    jmp Message_Loop

Exit_Program:
	  INVOKE ExitProcess,0
WinMain ENDP

;-----------------------------------------------------
InitMenu PROC
; Initialize the menu
;-----------------------------------------------------
	INVOKE CreateMenu
	mov hFileMenu, eax
	INVOKE CreateMenu
	mov hSubMenu, eax
	INVOKE AppendMenuA, hSubMenu, 0, NULL, ADDR subMsg
	INVOKE AppendMenuA, hSubMenu, 0, NULL, ADDR sub2ndMsg
	INVOKE AppendMenuA, hFileMenu, 10h, hSubMenu, ADDR fileMsg
	INVOKE SetMenu, hMainWnd, hFileMenu
InitMenu ENDP

;-----------------------------------------------------
EditSize PROC
; Change the size of edit based on the window size
;-----------------------------------------------------
.data 
	WndRect RECT <>

.code
	.IF hMainWnd == 0 
		ret
	.ENDIF
	push eax
	push ebx
	mov eax, hMainWnd
	mov eax, hEditWnd
	INVOKE GetWindowRect, hMainWnd, ADDR WndRect
	.IF eax == 0
		 call ErrorHandler
	.ENDIF
	mov eax, WndRect.right
	sub eax, WndRect.left
	mov ebx, WndRect.bottom
	sub ebx, WndRect.top
	sub eax, 100
	sub ebx, 120
	INVOKE MoveWindow, hEditWnd, 30, 30, eax, ebx, 1
	pop ebx
	pop eax
	ret
EditSize ENDP

;-----------------------------------------------------
EditProc PROC,
	hWnd:DWORD, localMsg:DWORD, wParam:DWORD, lParam:DWORD
; The edit box's message handler, which handles
; application-specific messages. All other messages
; are forwarded to the default Windows message
; handler.
;-----------------------------------------------------
	ret
EditProc ENDP

;-----------------------------------------------------
WinProc PROC,
	hWnd:DWORD, localMsg:DWORD, wParam:DWORD, lParam:DWORD
; The application's message handler, which handles
; application-specific messages. All other messages
; are forwarded to the default Windows message
; handler.
;-----------------------------------------------------
	mov eax, localMsg

	.IF eax == WM_CREATE		; create window
		INVOKE MessageBox, hWnd, ADDR AppLoadMsgText,
			ADDR AppLoadMsgTitle, MB_OK

		; The edit box
		INVOKE CreateWindowExA, 0, ADDR EDIT,
			ADDR EDIT, WS_CHILD+WS_VISIBLE+ES_LEFT+ES_MULTILINE, 
			CW_USEDEFAULT, CW_USEDEFAULT, CW_USEDEFAULT, 
			CW_USEDEFAULT,hWnd,FromEdit,hInstance,NULL
		.IF eax == 0
			call ErrorHandler
		.ENDIF
		mov hEditWnd, eax
		INVOKE ShowWindow, hEditWnd, SW_SHOW
		INVOKE SendMessage, hEditWnd, WM_SETTEXT, 0, ADDR EmptyText

		jmp WinProcExit
	.ELSEIF eax == WM_CLOSE		; close window
		INVOKE PostQuitMessage,0
		jmp WinProcExit
	.ELSEIF eax == WM_SIZE
		INVOKE EditSize
	.ELSE		; other message?
		INVOKE DefWindowProc, hWnd, localMsg, wParam, lParam
		jmp WinProcExit
	.ENDIF

WinProcExit:
	ret
WinProc ENDP

;---------------------------------------------------
ErrorHandler PROC
; Display the appropriate system error message.
;---------------------------------------------------
.data
pErrorMsg  DWORD ?		; ptr to error message
messageID  DWORD ?
.code
	INVOKE GetLastError	; Returns message ID in EAX
	mov messageID,eax

	; Get the corresponding message string.
	INVOKE FormatMessage, FORMAT_MESSAGE_ALLOCATE_BUFFER + \
	  FORMAT_MESSAGE_FROM_SYSTEM,NULL,messageID,NULL,
	  ADDR pErrorMsg,NULL,NULL

	; Display the error message.
	INVOKE MessageBox, NULL, pErrorMsg, ADDR ErrorTitle,
	  MB_ICONERROR+MB_OK

	; Free the error message string.
	INVOKE LocalFree, pErrorMsg
	ret
ErrorHandler ENDP

; INVOKE SendMessage, hEditWnd, WM_SETTEXT, 0, ADDR TestText

END WinMain