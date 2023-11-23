.386
.model flat, stdcall
option casemap: none

include  		core.inc
include			macro.inc
include			longInt.inc
include			double.inc
include         variables.inc
strncpy			PROTO C :ptr sbyte, :ptr sbyte, :DWORD
strcpy			PROTO C :ptr sbyte, :ptr sbyte
strcat			PROTO C :ptr sbyte, :ptr sbyte
memset			PROTO C :ptr sbyte, :DWORD, :DWORD
strlen			PROTO C :ptr sbyte

.data
factorialTable DWORD 1, 1, 2, 6, 24, 120, 720, 5040, 40320, 362880, 3628800, 39916800, 479001600

eName BYTE "e", 0
piName BYTE "pi", 0
ln10Name BYTE "ln10", 0
ln2Name BYTE "ln2", 0
c0Name BYTE "c0", 0

eValue BYTE "2.7182818284590452353602874713527", 0
piValue BYTE "3.1415926535897932384626433832795", 0
ln10Value BYTE "2.3025850929940456840179914546844", 0
ln2Value BYTE "0.69314718055994530941723212145818", 0
c0Value BYTE "299792458", 0

maximumTolerableErr REAL8 0.0000000001
public maximumTolerableErr

pi REAL8 3.141592653589
e REAL8 2.718281828459
ln2 REAL8 0.693147180559
ln10 REAL8 2.302585092994

.code
;---------------------------------------------------------------------------
; In this section we aim to support the calulation of some mathematic funcs
; and the definition of several constants
; and some other useful features
;---------------------------------------------------------------------------
; fundamental functions:
; 1. derivative: calculate the derivative of a function at the given x
;---------------------------------------------------------------------------
; constants:
; 1. e: Euler's number
; 2. pi: the ratio of a circle's circumference to its diameter
; 3. ln10: the natural logarithm of 10
; 4. ln2: the natural logarithm of 2
; 5. c0: the speed of light in vacuum
;---------------------------------------------------------------------------
; functions:
; 1. FACT x ===>     the factorial of x
; 2. SQRT x ===>    the square root of x
; 3. SIN x ===>     the sine of x
; 4. COS x ===>     the cosine of x
; 5. TAN x ===>     the tangent of x
; 6. LN x ===>     the natural logarithm of x
; 7. LG x ===>     the logarithm of x to base 10
; 8. LOG x ===>     the logarithm of x to base 2
; 9. EXP x ===>     the exponential function e^x
; 10. POW x y ===>     x^y
;---------------------------------------------------------------------------

;---------------------------------------------------------------------------
; TODO: derivative x, f, n
;---------------------------------------------------------------------------

;---------------------------------------------------------------------------
SetConstant PROC
; e = 2.7182818284590452353602874713527
; pi = 3.1415926535897932384626433832795
; ln10 = 2.3025850929940456840179914546844
; ln2 = 0.69314718055994530941723212145818
; c0 = 299792458 (m/s)
;---------------------------------------------------------------------------
    LOCAL constantValue:QWORD
    pushad
    ; 1. e=2.7182818284590452353602874713527
    INVOKE StrToDouble, ADDR eValue, ADDR constantValue
    INVOKE HashTableInsert, ADDR eName, TYPE_DOUBLE, 8, ADDR constantValue
    ; 2. pi=3.1415926535897932384626433832795
    INVOKE StrToDouble, ADDR piValue, ADDR constantValue
    INVOKE HashTableInsert, ADDR piName, TYPE_DOUBLE, 8, ADDR constantValue
    ; 3. ln10=2.3025850929940456840179914546844
    INVOKE StrToDouble, ADDR ln10Value, ADDR constantValue
    INVOKE HashTableInsert, ADDR ln10Name, TYPE_DOUBLE, 8, ADDR constantValue
    ; 4. ln2=0.69314718055994530941723212145818
    INVOKE StrToDouble, ADDR ln2Value, ADDR constantValue
    INVOKE HashTableInsert, ADDR ln2Name, TYPE_DOUBLE, 8, ADDR constantValue
    ; 5. c0=299792458 (m/s)
    INVOKE StrToLong, ADDR c0Value, ADDR constantValue
    INVOKE HashTableInsert, ADDR c0Name, TYPE_INT, 8, ADDR constantValue
    
    popad
    ret
SetConstant ENDP

;---------------------------------------------------------------------------
Fact PROC,
    x: DWORD, ansAddr:DWORD
; the factorial of x(being a non-negative 32-bit integer), puts ans into ansAddr
; method:
; we have factorialTable, (0! to 12!), to accelerate the calculation
; 12! can be stored in eax, which is convenient.
; for any x > 12, we use the recursive method to calculate the factorial of x
; plus, higher 32 bits might count when x>12, so be careful.
; WARNING: FACT x grows very fast, so overflow is highly possible
;---------------------------------------------------------------------------
    LOCAL tmpLong: QWORD
    pushad
    .IF x <= 12
        lea ebx, factorialTable
        mov eax, x
        shl eax, 2 ; x *= 4
        add ebx, eax
        mov edi, ansAddr
        add edi, 4
        mov edx, [ebx] ; [ebx] = factorialTable[x]
        mov [edi], edx
        popad
        ret
    .ENDIF
    ; x > 12
    mov eax, [ansAddr]
    mov DWORD PTR [eax], 0
    mov eax, x
    dec eax ; eax = x-1
    INVOKE Fact, eax, ansAddr ; get (x-1)! into ansAddr
    lea ebx, tmpLong
    mov edx, x
    mov DWORD PTR [ebx], 0
    mov DWORD PTR [ebx+4], edx ; tmpLong = x
    INVOKE LongMul, ansAddr, ADDR tmpLong ; ans = (x-1)! * x
    popad
    ret
Fact ENDP

;---------------------------------------------------------------------------
Sqrt PROC,
    x: QWORD, ansAddr:DWORD
; the square root of x
; method:
; we use the Newton's method to calculate the square root of x recursively
; 1. let t_{0} = x
; 2. recursively: t_{n+1} = (t_{n} + x/t_{n})/2, until |t_{n+1} - t_{n}| < 1e-6
;
; PROOF:
; we are actually using newton method to solve the function f(t) = t^2 - x = 0
; then f'(t) = 2t
; the tangent line at t_{n}:
; l_n(t) = 2t_{n}(t-t{n}) + t_{n}^2 - x = 2t_{n}t - t_{n}^2 - x = 0
; its intersection with t-axis:
; l_n(t_{n+1}) = 0 <==> t_{n+1} = (t_{n} + x/t_{n})/2
; t_{n} shall --> \sqrt{x}
;---------------------------------------------------------------------------
    LOCAL t: QWORD, tNext: QWORD, tmp:QWORD
    pushad
    fld x
    fstp t ; t_{0} = x
    Recursively:
        fld x   ; stack:  BOTTOM: x                 :TOP
        fld t   ; stack:  BOTTOM: x, t              :TOP
        fdiv    ; stack:  BOTTOM: x/t               :TOP 
        fld t   ; stack:  BOTTOM: x/t, t            :TOP
        fadd    ; stack:  BOTTOM: x/t + t           :TOP
        fld1    ; stack:  BOTTOM: x/t + t, 1        :TOP
        fld1    ; stack:  BOTTOM: x/t + t, 1, 1     :TOP
        fadd    ; stack:  BOTTOM: x/t + t, 2        :TOP
        fdiv    ; stack:  BOTTOM: (x/t + t)/2       :TOP
        fstp tNext ; t_{n+1} = (t_{n} + x/t_{n})/2
        fld t   ; stack:  BOTTOM: t_{n}             :TOP
        fld tNext ; stack:  BOTTOM: t_{n}, t_{n+1}  :TOP
        fsub    ; stack:  BOTTOM: t_{n+1} - t_{n}   :TOP
        fabs    ; stack:  BOTTOM: |t_{n+1} - t_{n}| :TOP
        fcomp maximumTolerableErr ; compare |t_{n+1} - t_{n}| with 1e-6
        fnstsw ax
        sahf
        .IF CARRY?
            ; |t_{n+1} - t_{n}| < 1e-6
            ; stop
            fld tNext
            mov ebx, ansAddr
            fstp QWORD PTR [ebx]
            popad 
            ret
        .ELSE
            ; |t_{n+1} - t_{n}| >= 1e-6
            fld tNext
            fstp t ; t = t_{n+1}
            jmp Recursively 
        .ENDIF
    popad
    ret
Sqrt ENDP

;---------------------------------------------------------------------------
Sin PROC,
    x: QWORD, ansAddr:DWORD
; the sine of x
; method:
; 1. first, calculate x / (2*pi), get the remainder deltax
; 2. use sin(deltax) = deltax - deltax^3/3! + deltax^5/5! - deltax^7/7! + deltax^9/9! -...- deltax^21/21! + o(deltax^23)
; 3. we stop at deltax^11/11! since deltax^13/13! is too small to be significant
;---------------------------------------------------------------------------
    LOCAL sum:QWORD, deltax: QWORD, deltaxPower: QWORD, factVal: QWORD, tmp: QWORD, i:QWORD
    pushad
    fldz
    fstp sum           ; sum = 0
    fld x              ; stack:  BOTTOM: x                         :TOP
    fld pi             ; stack:  BOTTOM: x, pi                     :TOP
    fld1
    fld1               ; stack:  BOTTOM: x, pi, 1, 1               :TOP
    fadd               ; stack:  BOTTOM: x, pi, 2                  :TOP
    fmul               ; stack:  BOTTOM: x, 2*pi                   :TOP
    fdiv               ; stack:  BOTTOM: x/(2*pi)                  :TOP
    frndint            ; stack:  BOTTOM: floor(x/(2*pi))           :TOP
    fstp tmp           ; tmp = floor(x/(2*pi))
    fld pi             ; stack:  BOTTOM: pi                        :TOP
    fld1               ; stack:  BOTTOM: pi, 1                     :TOP
    fld1               ; stack:  BOTTOM: pi, 1, 1                  :TOP
    fadd               ; stack:  BOTTOM: pi, 2                     :TOP
    fmul               ; stack:  BOTTOM: 2*pi                      :TOP
    fld tmp            ; stack:  BOTTOM: 2*pi, floor(x/(2*pi))     :TOP
    fmul               ; stack:  BOTTOM: 2*pi*floor(x/(2*pi))      :TOP
    fld x              ; stack:  BOTTOM: 2*pi*floor(x/(2*pi)), x   :TOP
    fsub               ; stack:  BOTTOM: 2*pi*floor(x/(2*pi)) - x  :TOP
    fchs               ; stack:  BOTTOM: x - 2*pi*floor(x/(2*pi))  :TOP
    fstp deltax        ; deltax = x - 2*pi*floor(x/(2*pi))
    fld deltax
    fstp deltaxPower   ; deltaxPower = deltax
    fld1
    fstp factVal       ; factVal = 1 = 1!
    fld1
    fstp i             ; i = 1
    mov ecx, 1         ; ecx = 1
    Repeatedly:
        fld sum        ; stack:  BOTTOM: sum                                :TOP
        fld deltaxPower; stack:  BOTTOM: sum, deltaxPower               :TOP
        fld factVal    ; stack:  BOTTOM: sum, deltaxPower, factVal          :TOP
        fdiv           ; stack:  BOTTOM: sum, deltaxPower/factVal           :TOP
        fadd           ; stack:  BOTTOM: sum + deltaxPower/factVal          :TOP
        fstp sum       ; sum = sum + deltaxPower/factVal
        ; refresh deltaxPower, factVal, i
        ; 1. deltaxPower = deltaxPower * deltax^2
        fld deltaxPower; stack:  BOTTOM: deltaxPower                    :TOP
        fld deltax     ; stack:  BOTTOM: deltaxPower, deltax            :TOP
        fld deltax     ; stack:  BOTTOM: deltaxPower, deltax, deltax    :TOP
        fmul           ; stack:  BOTTOM: deltaxPower, deltax^2              :TOP
        fmul           ; stack:  BOTTOM: deltaxPower * deltax^2             :TOP
        fstp deltaxPower   ; deltaxPower = deltaxPower * deltax^2
        ; 2. factVal = (-) * factVal * (i+1) * (i+2)
        fld factVal    ; stack:  BOTTOM: factVal                            :TOP
        fchs           ; stack:  BOTTOM: -factVal                           :TOP
        fld i          ; stack:  BOTTOM: -factVal, i                        :TOP
        fld1           ; stack:  BOTTOM: -factVal, i, 1                     :TOP
        fadd           ; stack:  BOTTOM: -factVal, i+1                      :TOP
        fld i          ; stack:  BOTTOM: -factVal, i+1, i                   :TOP
        fld1           ; stack:  BOTTOM: -factVal, i+1, i, 1                :TOP
        fld1           ; stack:  BOTTOM: -factVal, i+1, i, 1, 1             :TOP
        fadd           ; stack:  BOTTOM: -factVal, i+1, i, 2                :TOP
        fadd           ; stack:  BOTTOM: -factVal, i+1, i+2                 :TOP
        fmul           ; stack:  BOTTOM: -factVal, (i+1)*(i+2)              :TOP
        fmul           ; stack:  BOTTOM: (-) * factVal * (i+1)*(i+2)        :TOP
        fstp factVal   ; factVal = (-) * factVal * (i+1)*(i+2)
        ; 3. i = i + 2
        fld i          ; stack:  BOTTOM: i                                 :TOP
        fld1           ; stack:  BOTTOM: i, 1                              :TOP
        fld1           ; stack:  BOTTOM: i, 1, 1                           :TOP
        fadd           ; stack:  BOTTOM: i, 2                              :TOP
        fadd           ; stack:  BOTTOM: i + 2                             :TOP
        fstp i         ; i = i + 2
        add ecx, 2
        .IF ecx <= 21
            ; x^i (i <= 21)
            jmp Repeatedly
        .ENDIF
    ; ends
    ; put sum into ansAddr
    mov ebx, ansAddr
    fld sum
    fstp QWORD PTR [ebx]
    popad
    ret
Sin ENDP

;---------------------------------------------------------------------------
Cos PROC,
    x: QWORD, ansAddr:DWORD
; the cosine of x
; method:
; 1. first, calculate x / (2*pi), get the remainder deltax
; 2. use cos(deltax) = 1 - deltax^2/2! + deltax^4/4! - deltax^6/6! + deltax^8/8! - deltax^10/10! +...+ deltax^20/20! + o(deltax^22)
; 3. we stop at deltax^12/12! since deltax^14/14! is too small to be significant
;---------------------------------------------------------------------------
    LOCAL sum:QWORD, deltax: QWORD, deltaxPower: QWORD, factVal: QWORD, tmp: QWORD, i:QWORD
    pushad
    fldz
    fstp sum           ; sum = 0
    fld x              ; stack:  BOTTOM: x                         :TOP
    fld pi             ; stack:  BOTTOM: x, pi                     :TOP
    fld1               ; stack:  BOTTOM: x, pi, 1                  :TOP
    fld1               ; stack:  BOTTOM: x, pi, 1, 1               :TOP
    fadd               ; stack:  BOTTOM: x, pi, 2                  :TOP
    fmul               ; stack:  BOTTOM: x, 2*pi                   :TOP
    fdiv               ; stack:  BOTTOM: x/(2*pi)                  :TOP
    frndint            ; stack:  BOTTOM: floor(x/(2*pi))           :TOP
    fstp tmp           ; tmp = floor(x/(2*pi))
    fld pi             ; stack:  BOTTOM: pi                        :TOP
    fld1               ; stack:  BOTTOM: pi, 1                     :TOP
    fld1               ; stack:  BOTTOM: pi, 1, 1                  :TOP
    fadd               ; stack:  BOTTOM: pi, 2                     :TOP
    fmul               ; stack:  BOTTOM: 2*pi                      :TOP
    fld tmp            ; stack:  BOTTOM: 2*pi, floor(x/(2*pi))     :TOP
    fmul               ; stack:  BOTTOM: 2*pi*floor(x)/(2*pi)      :TOP
    fld x              ; stack:  BOTTOM: 2*pi*floor(x)/(2*pi), x   :TOP
    fsub               ; stack:  BOTTOM: x - 2*pi*floor(x)/(2*pi)  :TOP
    fstp deltax        ; deltax = x - 2*pi*floor(x)/(2*pi)
    fld1
    fstp deltaxPower   ; deltaxPower = 1 = deltax^0
    fld1
    fstp factVal       ; factVal = 1 = 0!
    fldz
    fstp i             ; i = 0
    mov ecx, 0         ; ecx = 0
    Repeatedly:
        fld sum        ; stack:  BOTTOM: sum                                :TOP
        fld deltaxPower; stack:  BOTTOM: sum, deltaxPower                   :TOP
        fld factVal    ; stack:  BOTTOM: sum, deltaxPower, factVal          :TOP
        fdiv           ; stack:  BOTTOM: sum, deltaxPower/factVal           :TOP
        fadd           ; stack:  BOTTOM: sum + deltaxPower/factVal          :TOP
        fstp sum       ; sum = sum + deltaxPower/factVal
        ; refresh deltaxPower, factVal, i
        ; 1. deltaxPower = deltaxPower * deltax^2
        fld deltaxPower; stack:  BOTTOM: deltaxPower                        :TOP
        fld deltax     ; stack:  BOTTOM: deltaxPower, deltax                :TOP
        fld deltax     ; stack:  BOTTOM: deltaxPower, deltax, deltax        :TOP
        fmul           ; stack:  BOTTOM: deltaxPower, deltax^2              :TOP
        fmul           ; stack:  BOTTOM: deltaxPower * deltax^2             :TOP
        fstp deltaxPower   ; deltaxPower = deltaxPower * deltax^2
        ; 2. factVal = (-) * factVal * (i+1) * (i+2)
        fld factVal    ; stack:  BOTTOM: factVal                            :TOP
        fchs           ; stack:  BOTTOM: -factVal                           :TOP
        fld i          ; stack:  BOTTOM: -factVal, i                        :TOP
        fld1           ; stack:  BOTTOM: -factVal, i, 1                     :TOP
        fadd           ; stack:  BOTTOM: -factVal, i+1                      :TOP
        fld i          ; stack:  BOTTOM: -factVal, i+1, i                   :TOP
        fld1           ; stack:  BOTTOM: -factVal, i+1, i, 1                :TOP
        fld1           ; stack:  BOTTOM: -factVal, i+1, i, 1, 1             :TOP
        fadd           ; stack:  BOTTOM: -factVal, i+1, i, 2                :TOP
        fadd           ; stack:  BOTTOM: -factVal, i+1, i+2                 :TOP
        fmul           ; stack:  BOTTOM: -factVal, (i+1)*(i+2)              :TOP
        fmul           ; stack:  BOTTOM: (-) * factVal * (i+1)*(i+2)        :TOP
        fstp factVal   ; factVal = (-) * factVal * (i+1)*(i+2)
        ; 3. i = i + 2
        fld i          ; stack:  BOTTOM: i                                 :TOP
        fld1           ; stack:  BOTTOM: i, 1                              :TOP
        fld1           ; stack:  BOTTOM: i, 1, 1                           :TOP
        fadd           ; stack:  BOTTOM: i, 2                              :TOP
        fadd           ; stack:  BOTTOM: i + 2                             :TOP
        fstp i         ; i = i + 2
        add ecx, 2
        .IF ecx <= 20
            ; x^i (i <= 20)
            jmp Repeatedly
        .ENDIF
    ; ends
    ; put sum into ansAddr
    mov ebx, ansAddr
    fld sum
    fstp QWORD PTR [ebx]
    popad
    ret
Cos ENDP



;---------------------------------------------------------------------------
Tan PROC,
    x: QWORD, ansAddr:DWORD
; the tangent of x
; method:
; 1. tan(x) = sin(x) / cos(x)
; WARNING: never use this function when cos(x) is close to 0, since 
; the result can be highly inaccurate
;---------------------------------------------------------------------------
    LOCAL sinx:QWORD, cosx:QWORD
    pushad
    lea ebx, sinx
    INVOKE Sin, x, ebx
    lea ebx, cosx
    INVOKE Cos, x, ebx
    fld sinx ; stack:  BOTTOM: sinx :TOP
    fld cosx ; stack:  BOTTOM: sinx, cosx :TOP
    fdiv     ; stack:  BOTTOM: sinx/cosx :TOP
    mov edx, ansAddr
    fstp QWORD PTR [edx]
    popad
    ret
Tan ENDP

;---------------------------------------------------------------------------
Exp PROC,
    x: QWORD, ansAddr:DWORD
; the exponential function e^x
; method:
; 1. get dx = decimal part of x (i.e. x = floor(x)+dx)
; 2. expand at (floor(x), e^{floor(x)}), we have:
; 3. e^x = e^{floor(x)}(1 + dx + dx^2/2! + dx^3/3! + ...)
; 4. stop calculating the series when the absolute value of the term is less than 1e-6
;---------------------------------------------------------------------------
    LOCAL floorX: QWORD, expFloorX: QWORD, deltax: QWORD, deltaxPower: QWORD, sum: QWORD,  sumNext: QWORD, factVal: QWORD, i: QWORD
    pushad
    fld x                           ; stack:  BOTTOM: x                             :TOP
    frndint                         ; stack:  BOTTOM: floor(x)                      :TOP
    fstp floorX                     ; floorX = floor(x)
    fld x                           ; stack:  BOTTOM: x                             :TOP
    fld floorX                      ; stack:  BOTTOM: x, floor(x)                   :TOP
    fsub                            ; stack:  BOTTOM: x - floor(x)                  :TOP
    fstp deltax                     ; deltax = x - floor(x)
    fld1
    fstp deltaxPower                ; deltaxPower = 1 = deltax^0
    fldz
    fstp sum                        ; sum = 0
    fldz
    fstp sumNext                    ; sumNext = 0
    fld1
    fstp factVal                    ; factVal = 1 = 0!
    fldz
    fstp i                          ; i = 0
    INVOKE DoubleToLong, ADDR floorX ; floorX = floor(x) , from double to long
    fld e
    fstp expFloorX                  ; expFloorX = e
    INVOKE DoubleExp, ADDR expFloorX, ADDR floorX ; expFloorX = e^{floor(x)}
    Repeatedly:
        fld sum                     ; stack:  BOTTOM: sum                                       :TOP
        fld deltaxPower             ; stack:  BOTTOM: sum, deltaxPower                          :TOP
        fld expFloorX               ; stack:  BOTTOM: sum, deltaxPower, expFloorX               :TOP
        fmul                        ; stack:  BOTTOM: sum, deltaxPower*expFloorX                :TOP
        fld factVal                 ; stack:  BOTTOM: sum, deltaxPower*expFloorX, factVal       :TOP
        fdiv                        ; stack:  BOTTOM: sum, deltaxPower*expFloorX/factVal        :TOP
        fadd                        ; stack:  BOTTOM: sum + deltaxPower*expFloorX/factVal       :TOP
        fstp sumNext                ; sumNext = sum + deltaxPower*expFloorX/factVal
        fld sumNext                 ; stack:  BOTTOM: sumNext                                   :TOP
        fld sum                     ; stack:  BOTTOM: sumNext, sum                              :TOP
        fsub                        ; stack:  BOTTOM: sumNext - sum                             :TOP
        fabs                        ; stack:  BOTTOM: |sumNext - sum|                           :TOP
        fcomp maximumTolerableErr ; compare |sumNext - sum| with 1e-6
        fnstsw ax
        sahf
        .IF CARRY?
            ; |sumNext - sum| < 1e-6
            ; stop
            fld sumNext
            mov ebx, ansAddr
            fstp QWORD PTR [ebx]
            popad
            ret
        .ELSE
            ; |sumNext - sum| >= 1e-6
            ; refresh deltaxPower, factVal, i, sum
            fld deltaxPower            ; stack:  BOTTOM: deltaxPower                               :TOP
            fld deltax                 ; stack:  BOTTOM: deltaxPower, deltax                        :TOP
            fmul                       ; stack:  BOTTOM: deltaxPower*deltax                         :TOP
            fstp deltaxPower           ; deltaxPower = deltaxPower * deltax
            fld factVal                ; stack:  BOTTOM: factVal                                   :TOP
            fld i                      ; stack:  BOTTOM: factVal, i                                 :TOP
            fld1                       ; stack:  BOTTOM: factVal, i, 1                              :TOP
            fadd                       ; stack:  BOTTOM: factVal, i+1                                :TOP
            fmul                       ; stack:  BOTTOM: factVal*(i+1)                              :TOP
            fstp factVal               ; factVal = factVal * (i+1)
            fld i                      ; stack:  BOTTOM: i                                          :TOP
            fld1                       ; stack:  BOTTOM: i, 1                                       :TOP
            fadd                       ; stack:  BOTTOM: i+1                                        :TOP
            fstp i                     ; i = i + 1
            fld sumNext
            fstp sum    ; sum = sumNext
            jmp Repeatedly
        .ENDIF
    popad
    ret
Exp ENDP

;---------------------------------------------------------------------------
Ln PROC,
    x: QWORD, ansAddr:DWORD
; the natural logarithm of x
; method:
; 1. let t_{0} = an approximation of ln(x)
; 2. recursively: t_{n+1} = t_{n} - 1 + x/e^{t_{n}}, until |t_{n+1} - t_{n}| < 1e-6
; 
; PROOF:
; tangent line at (t_{n}, ln(t_{n})):
; e^{t_{n}}(t_{n+1} - t_{n}) + e^{t_{n}} - x = 0
; ==> t_{n+1} = t_{n} - 1 + x/e^{t_{n}}
;---------------------------------------------------------------------------
    LOCAL t:QWORD, expt:QWORD, tNext:QWORD
    pushad
    fld x
    fstp t ; t_{0} = x
    Recursively:
        INVOKE Exp, t, ADDR expt ; expt = e^{t_{n}}
        fld t               ; stack:  BOTTOM: t_{n}                                         :TOP
        fld1                ; stack:  BOTTOM: t_{n}, 1                                      :TOP
        fchs                ; stack:  BOTTOM: t_{n}, -1                                     :TOP
        fld x               ; stack:  BOTTOM: t_{n}, -1, x                                  :TOP
        fld expt            ; stack:  BOTTOM: t_{n}, -1, x, e^{t_{n}}                       :TOP
        fdiv                ; stack:  BOTTOM: t_{n}, -1, x/e^{t_{n}}                        :TOP
        fadd                ; stack:  BOTTOM: t_{n}, -1 + x/e^{t_{n}}                       :TOP
        fadd                ; stack:  BOTTOM: t_{n} - 1 + x/e^{t_{n}}                       :TOP
        fstp tNext          ; t_{n+1} = t_{n} - 1 + x/e^{t_{n}}
        fld tNext           ; stack:  BOTTOM: t_{n+1}                                       :TOP
        fld t               ; stack:  BOTTOM: t_{n+1}, t_{n}                                :TOP
        fsub                ; stack:  BOTTOM: t_{n+1} - t_{n}                               :TOP
        fabs                ; stack:  BOTTOM: |t_{n+1} - t_{n}|                             :TOP
        fcomp maximumTolerableErr ; compare |t_{n+1} - t_{n}| with 1e-6
        fnstsw ax
        sahf
        .IF CARRY?
            ; |t_{n+1} - t_{n}| < 1e-6
            ; stop
            fld tNext
            mov ebx, ansAddr
            fstp QWORD PTR [ebx]
            popad
            ret
        .ELSE
            ; |t_{n+1} - t_{n}| >= 1e-6
            ; refresh t
            fld tNext
            fstp t ; t = t_{n+1}
            jmp Recursively
        .ENDIF
    popad
    ret
Ln ENDP

;---------------------------------------------------------------------------
Lg PROC,
    x: QWORD, ansAddr:DWORD
; the logarithm of x to base 10
; method:
; 1. lg(x) = ln(x) / ln(10)
;---------------------------------------------------------------------------
    LOCAL lnx: QWORD
    pushad
    INVOKE Ln, x, ADDR lnx ; lnx = ln(x)
    fld lnx ; stack:  BOTTOM: lnx :TOP
    fld ln10 ; stack:  BOTTOM: lnx, ln10 :TOP
    fdiv ; stack:  BOTTOM: lnx/ln10 :TOP
    mov edx, ansAddr
    fstp QWORD PTR [edx]
    popad
    ret
Lg ENDP

;---------------------------------------------------------------------------
Log PROC,
    x: QWORD, ansAddr:DWORD
; the logarithm of x to base 2
; method:
; 1. log(x) = ln(x) / ln(2)
;---------------------------------------------------------------------------
    LOCAL lnx: QWORD
    pushad
    INVOKE Ln, x, ADDR lnx ; lnx = ln(x)
    fld lnx ; stack:  BOTTOM: lnx :TOP
    fld ln2 ; stack:  BOTTOM: lnx, ln2 :TOP
    fdiv ; stack:  BOTTOM: lnx/ln2 :TOP
    mov edx, ansAddr
    fstp QWORD PTR [edx]
    popad
    ret
Log ENDP

;---------------------------------------------------------------------------
Pow PROC,
    x: QWORD, y: QWORD, ansAddr:DWORD
; x^y
; method:
; 1. pow(x, y) = exp(y * ln(x))
;---------------------------------------------------------------------------
    LOCAL lnx: QWORD, yTimesLNX: QWORD, yToTheX: QWORD
    pushad
    INVOKE Ln, x, ADDR lnx ; lnx = ln(x)
    fld y ; stack:  BOTTOM: y :TOP
    fld lnx ; stack:  BOTTOM: y, lnx :TOP
    fmul ; stack:  BOTTOM: y*lnx :TOP
    fstp yTimesLNX ; yTimesLNX = y*lnx
    INVOKE Exp, yTimesLNX, ADDR yToTheX ; yToTheX = e^{y*lnx}
    mov edx, ansAddr
    fld yToTheX
    fstp QWORD PTR [edx]
    popad
    ret
Pow ENDP


END