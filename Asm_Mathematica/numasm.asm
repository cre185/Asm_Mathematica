.386
.model flat, stdcall
option casemap: none

include  		calculate.inc
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

maximumTolerableErr REAL8 1e-6

.code
;---------------------------------------------------------------------------
; In this section we aim to support the calulation of some mathematic funcs
; and the definition of several constants
; and some other useful features
;---------------------------------------------------------------------------
; foundamental functions:
; 1. Series: calculate the sum of a series, according to the given coefficient at the given x
; 2. derivative: calculate the derivative of a function at the given x
;---------------------------------------------------------------------------
; constants:
; 1. e: Euler's number
; 2. pi: the ratio of a circle's circumference to its diameter
; 3. ln10: the natural logarithm of 10
; 4. ln2: the natural logarithm of 2
; 5. c0: the speed of light in vacuum
; 6. h: Planck constant
; 7. G: the gravitational constant
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
; TODO: Series x, n, coefficientArrayAddr
; param explanation:
; x: where the series is expanded
; n: the highest power of the series
; coefficientArrayAddr: this ptr provides an array of n+1 coefficients
;
; method:
; we use the Horner's method to calculate the sum of the series
; 1. let b_{n} = a_{n}
; 2. recursively: b_{n-1} = a_{n-1} + x*b_{n}
; 3. stop when b_{0} is calculated
;
; PROOF:
; apparently, the sum of the series is:
; f(x) = a_{0} + a_{1}x + a_{2}x^2 + ... + a_{n}x^n
; f(x) = a_{0} + x(a_{1} + x(a_{2} + ... + x(a_{n-1} + x*a_{n})...))
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
; h = 6.62607004e-34 (J*s)
; G = 6.67408e-11 (m^3/(kg*s^2))
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
    mov eax, x
    dec eax ; eax = x-1
    INVOKE Fact, eax, ansAddr ; get (x-1)! into ansAddr
    lea ebx, tmpLong
    mov edx, x
    mov DWORD PTR[ebx], 0
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
    LOCAL t: QWORD, tNext: QWORD
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
        fld maximumTolerableErr ; stack:  BOTTOM: |t_{n+1} - t_{n}|, 1e-6 :TOP
        fcomp st(1), st(0) ; st(1) = |t_{n+1} - t_{n}|, st(0) = 1e-6
        .IF CARRY? == 0
            ; || > 1e-6
            ; recursively calculate
            fld tNext
            fstp t
            jmp Recursively
        .ELSE
            ; || < 1e-6
            ; stop
            fld tNext
            mov edx, ansAddr
            fstp REAL8 PTR [edx]
            popad
            ret
        .ENDIF
    popad
    ret
Sqrt ENDP

;---------------------------------------------------------------------------
; TODO: SIN x
; the sine of x
; method:
; 1. first, calculate x / (2*pi), get the remainder dx
; 2. use sin(dx) = dx - dx^3/3! + dx^5/5! - dx^7/7! + ... to calculate sin(dx)
; 3. stop calculating the series when the absolute value of the term is less than 1e-6
;---------------------------------------------------------------------------

;---------------------------------------------------------------------------
; TODO: COS x
; the cosine of x
; method:
; 1. first, calculate x / (2*pi), get the remainder dx
; 2. use cos(dx) = 1 - dx^2/2! + dx^4/4! - dx^6/6! + ... to calculate cos(dx)
; 3. stop calculating the series when the absolute value of the term is less than 1e-6
;---------------------------------------------------------------------------

;---------------------------------------------------------------------------
; TODO: TAN x
; the tangent of x
; method:
; 1. tan(x) = sin(x) / cos(x)
; WARNING: never use this function when cos(x) is close to 0, since 
; the result can be highly inaccurate
;---------------------------------------------------------------------------

;---------------------------------------------------------------------------
; TODO: LN x
; the natural logarithm of x
; method:
; 1. find the integer n such that e^{n} < x < e^{n+1}
; 2. expand at (e^n, n), we have:
; 3. ln(x) = n + e^{-n}(x - e^n) - e^{-2n}(x - e^n)^2/2 + e^{-3n}(x - e^n)^3/3 - ...
; 4. stop calculating the series when the absolute value of the term is less than 1e-6
;---------------------------------------------------------------------------

;---------------------------------------------------------------------------
; TODO: LG x
; the logarithm of x to base 10
; method:
; 1. lg(x) = ln(x) / ln(10)
;---------------------------------------------------------------------------

;---------------------------------------------------------------------------
; TODO: LOG x
; the logarithm of x to base 2
; method:
; 1. log(x) = ln(x) / ln(2)
;---------------------------------------------------------------------------

;---------------------------------------------------------------------------
; TODO: EXP x
; the exponential function e^x
; method:
; 1. get dx = decimal part of x (i.e. x = floor(x)+dx)
; 2. expand at (floor(x), e^{floor(x)}), we have:
; 3. e^x = e^{floor(x)}(1 + dx + dx^2/2! + dx^3/3! + ...)
; 4. stop calculating the series when the absolute value of the term is less than 1e-6
;---------------------------------------------------------------------------

;---------------------------------------------------------------------------
; TODO: POW x y
; x^y
; method:
; 1. pow(x, y) = exp(y * ln(x))
;---------------------------------------------------------------------------


END