.386
.model flat, stdcall
option casemap: none

include  		calculate.inc
include			macro.inc
include			longInt.inc
include			double.inc
strncpy			PROTO C :ptr sbyte, :ptr sbyte, :DWORD
strcpy			PROTO C :ptr sbyte, :ptr sbyte
strcat			PROTO C :ptr sbyte, :ptr sbyte
memset			PROTO C :ptr sbyte, :DWORD, :DWORD
strlen			PROTO C :ptr sbyte

.data
factorialTable DWORD 1, 1, 2, 6, 24, 120, 720, 5040, 40320, 362880, 3628800, 39916800, 479001600

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
; c0 = 299792458 (km/s)
; h = 6.62607004e-34 (J*s)
; G = 6.67408e-11 (m^3/(kg*s^2))
;---------------------------------------------------------------------------
    LOCAL tmpStr[128]:BYTE
    pushad
    popad
SetConstant ENDP

;---------------------------------------------------------------------------
; TODO: FACT x
; the factorial of x
; method:
; we have factorialTable, (0! to 12!), to accelerate the calculation
; 12! can be stored in eax, which is convenient.
; for any x > 12, we use the recursive method to calculate the factorial of x
; plus, higher 32 bits might count when x>12, so be careful.
; WARNING: FACT x grows very fast, so overflow is highly possible
;---------------------------------------------------------------------------

;---------------------------------------------------------------------------
; TODO: SQRT x
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