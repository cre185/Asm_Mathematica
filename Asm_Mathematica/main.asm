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
include			rowBox.inc
include			macro.inc
include    		numasm.inc

MSGStruct STRUCT
	msgWnd        DWORD ?
	msgMessage    DWORD ?
	msgWparam     DWORD ?
	msgLparam     DWORD ?
	msgTime       DWORD ?
	msgPt         POINT <>
MSGStruct ENDS

SCROLLINFO STRUCT
	cbSize        DWORD ?
	fMask		  DWORD ?
	nMin		  DWORD ?
	nMax		  DWORD ?
	nPage		  DWORD ?
	nPos		  DWORD ?
	nTrackPos	  DWORD ?
SCROLLINFO ENDS

MAIN_WINDOW_STYLE = WS_VISIBLE+WS_DLGFRAME+WS_CAPTION+WS_BORDER+WS_SYSMENU \
	+WS_MAXIMIZEBOX+WS_MINIMIZEBOX+WS_THICKFRAME+WS_VSCROLL
HELP_WINDOW_STYLE = WS_VISIBLE+WS_CAPTION+WS_SYSMENU

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

WindowName  BYTE "Asm Mathematica",0
className   BYTE "ASMWin",0
helpWindow BYTE "HelpWindow",0
HelpName   BYTE "Documentation for Asm Mathematica",0
helpMsg    BYTE "Help",0
subMsg     BYTE "About",0
sub2ndMsg  BYTE "Document",0
openText   BYTE "open",0
urlText    BYTE "https://github.com/cre185/Asm_Mathematica",0
STATIC     BYTE "Static",0
helpText   BYTE "asdfsad",0dh,0ah,"another",4096 DUP(0)

msg	      MSGStruct <>
winRect   RECT <>
mainScroll    SCROLLINFO <>

hMainWnd  DWORD 0
hHelpWnd  DWORD 0
public hMainWnd, hHelpWnd

hHelpMenu DWORD ?
hSubMenu  DWORD ?
public hHelpMenu, hSubMenu

hInstance DWORD ?
public hInstance

scrollHeight DWORD 40h
public scrollHeight

FontText BYTE "Arial",0
StandardFont DWORD ?

; Define the Application's Window class structure.
MainWin WNDCLASS <NULL,WinProc,NULL,NULL,NULL,NULL,NULL, \
	COLOR_WINDOW,NULL,className>
HelpWin WNDCLASS <NULL,HelpWinProc,NULL,NULL,NULL,NULL,NULL, \
	COLOR_WINDOW,NULL,helpWindow>
;=================== CODE =========================
.code

InitMenu PROTO 
ErrorHandler PROTO
WinMain PROC

; init the FPU
	finit

; init constants
	INVOKE SetConstant

; Get a handle to the current process.
	INVOKE GetModuleHandle, NULL
	mov hInstance, eax
	mov MainWin.hInstance, eax
	mov HelpWin.hInstance, eax

; Load the program's icon and cursor.
	INVOKE LoadIcon, hInstance, IDI_ICON1
	mov MainWin.hIcon, eax
	mov HelpWin.hIcon, eax
	INVOKE LoadCursor, NULL, IDC_ARROW
	mov MainWin.hCursor, eax
	mov HelpWin.hCursor, eax

; Initialize brush for main window 
	INVOKE CreateSolidBrush, 0ffffffh
	mov MainWin.hbrBackground, eax
	mov HelpWin.hbrBackground, eax

; Register the window class.
	INVOKE RegisterClassA, ADDR MainWin
	.IF eax == 0
	  call ErrorHandler
	  jmp Exit_Program
	.ENDIF

; Register the help window class.
	INVOKE RegisterClassA, ADDR HelpWin
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

; init scrollbar
	mov eax, SIZE mainScroll
	mov mainScroll.cbSize, eax
	mov mainScroll.fMask, SIF_ALL
	mov mainScroll.nMin, 0
	mov mainScroll.nMax, 0
	mov mainScroll.nPage, 1
	INVOKE SetScrollInfo, hMainWnd, SB_VERT, ADDR mainScroll, 1

; Show and draw the window.
	INVOKE ShowWindow, hMainWnd, SW_SHOW
	INVOKE UpdateWindow, hMainWnd

; Initialize boxes and create the default one
	INVOKE InitRowBox
	INVOKE CreateNewBox

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
	mov hHelpMenu, eax
	INVOKE CreateMenu
	mov hSubMenu, eax
	INVOKE AppendMenuA, hSubMenu, 0, IDM_ABOUT, ADDR subMsg
	INVOKE AppendMenuA, hSubMenu, 0, IDM_DOCUMENT, ADDR sub2ndMsg
	INVOKE AppendMenuA, hHelpMenu, 10h, hSubMenu, ADDR helpMsg
	INVOKE SetMenu, hMainWnd, hHelpMenu
	ret
InitMenu ENDP

;-----------------------------------------------------
ScrollingWindow PROC,
	dist:DWORD
; Move the window by distance, a positive value for rolling down,
; negative for rolling up.
;-----------------------------------------------------
	LOCAL oldPos:DWORD
	mov eax, SIZE mainScroll
	mov mainScroll.cbSize, eax
	mov mainScroll.fMask, SIF_ALL
	INVOKE GetScrollInfo, hMainWnd, SB_VERT, ADDR mainScroll
	mov eax, mainScroll.nPos
	mov oldPos, eax
	mov eax, dist
	add mainScroll.nPos, eax
	mov mainScroll.fMask, SIF_POS
	INVOKE SetScrollInfo, hMainWnd, SB_VERT, ADDR mainScroll, 1
	INVOKE GetScrollInfo, hMainWnd, SB_VERT, ADDR mainScroll
	INVOKE GetWindowRect, hMainWnd, ADDR winRect
	mov eax, oldPos
	sub eax, mainScroll.nPos
	INVOKE ScrollWindow, hMainWnd, 0, eax, 0, ADDR winRect
	ret
ScrollingWindow ENDP

;-----------------------------------------------------
IncreaseScrollBarParam PROC,
	difH:DWORD
; Change the height of the scrollbar
;-----------------------------------------------------
	pushad
	mov eax, difH
	add scrollHeight, eax
	INVOKE GetScrollInfo, hMainWnd, SB_VERT, ADDR mainScroll
	mov eax, SIZE mainScroll
	mov mainScroll.cbSize, eax
	mov mainScroll.fMask, SIF_ALL
	mov mainScroll.nMin, 0
	INVOKE GetWindowRect, hMainWnd, ADDR winRect
	mov eax, scrollHeight
	sub eax, winRect.bottom
	add eax, 20h
	.IF eax < 80000000h
		mov mainScroll.nMax, eax
	.ELSE
		mov mainScroll.nMax, 0
	.ENDIF
	mov mainScroll.nPage, 1
	INVOKE SetScrollInfo, hMainWnd, SB_VERT, ADDR mainScroll, 1
	popad
	ret
IncreaseScrollBarParam ENDP

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
		jmp WinProcExit
	.ELSEIF eax == WM_CLOSE		; close window
		INVOKE PostQuitMessage,0
		jmp WinProcExit
	.ELSEIF eax == WM_VSCROLL
		mov eax, SIZE mainScroll
		mov mainScroll.cbSize, eax
		mov mainScroll.fMask, SIF_ALL
		INVOKE GetScrollInfo, hWnd, SB_VERT, ADDR mainScroll
		mov ebx, wParam
		.IF bx == SB_LINEUP
			INVOKE ScrollingWindow, -30
		.ELSEIF bx == SB_LINEDOWN
			INVOKE ScrollingWindow, 30
		.ELSEIF bx == SB_PAGEUP
			INVOKE ScrollingWindow, -30
		.ELSEIF bx == SB_PAGEDOWN
			INVOKE ScrollingWindow, 30
		.ELSEIF bx == SB_THUMBPOSITION
			mov eax, mainScroll.nTrackPos
			sub eax, mainScroll.nPos
			INVOKE ScrollingWindow, eax
		.ENDIF
	.ELSEIF eax == WM_MOUSEWHEEL
		mov eax, SIZE mainScroll
		mov mainScroll.cbSize, eax
		mov mainScroll.fMask, SIF_ALL
		INVOKE GetScrollInfo, hWnd, SB_VERT, ADDR mainScroll
		mov eax, wParam
		.IF eax < 80000000h
			INVOKE ScrollingWindow, -30
		.ELSE
			INVOKE ScrollingWindow, 30
		.ENDIF
	.ELSEIF eax == WM_COMMAND
		mov eax, wParam
		.IF ax == IDM_ABOUT 
			INVOKE ShellExecute, hWnd, ADDR openText, ADDR urlText, NULL, NULL, SW_SHOWNORMAL
		.ELSEIF ax == IDM_DOCUMENT
			INVOKE CreateWindowEx, 0, ADDR helpWindow,
			    ADDR HelpName,HELP_WINDOW_STYLE,
			    50,50,800,800,
				hWnd,NULL,hInstance,NULL
			.IF eax == 0
				INVOKE ErrorHandler
			.ENDIF
			mov hHelpWnd,eax
			; Get the help text here
			INVOKE CreateFont, 20, 0, 0, 0, FW_BOLD, FALSE, FALSE, FALSE,
				ANSI_CHARSET, OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS,
				ANTIALIASED_QUALITY, FF_DONTCARE, ADDR FontText
			mov StandardFont, eax
			INVOKE CreateWindowEx, 0, ADDR STATIC, 
				ADDR helpText,WS_CHILD+WS_VISIBLE+SS_CENTER, 
				15,20,750,720,
				hHelpWnd,NULL,hInstance,NULL
			.IF eax == 0
				INVOKE ErrorHandler
			.ENDIF
			INVOKE SendMessage, eax, WM_SETFONT, StandardFont, 1
		.ENDIF
	.ENDIF
	INVOKE DefWindowProc, hWnd, localMsg, wParam, lParam

WinProcExit:
	ret
WinProc ENDP

;-----------------------------------------------------
HelpWinProc PROC,
	hWnd:DWORD, localMsg:DWORD, wParam:DWORD, lParam:DWORD
;-----------------------------------------------------
	mov eax, localMsg
	.IF eax == WM_CREATE
		INVOKE SetWindowPos, hWnd, NULL, 50, 50, 800, 800, SWP_NOZORDER
	.ELSEIF eax == WM_CLOSE
		INVOKE ShowWindow, hWnd, SW_HIDE
		jmp HelpProcExit
	.ENDIF
	INVOKE DefWindowProc, hWnd, localMsg, wParam, lParam

HelpProcExit:
	ret
HelpWinProc ENDP

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

; INVOKE MessageBox, NULL, ADDR PopupTitle, ADDR PopupText, MB_OK


END WinMain