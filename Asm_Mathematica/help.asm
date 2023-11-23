.386
.model flat, stdcall
option casemap: none

.data
helpText    BYTE "Operators Definition Rules",0dh,0ah,0dh,0ah
			BYTE "This document describes the definition rules of the operators used in this assembly language program. The operators are classified into seven groups"
			BYTE " according to their precedence and functionality. The higher the precedence, the earlier the operator is evaluated.",0dh,0ah,0dh,0ah
			BYTE "Group 1: Mathematical Functions",0dh,0ah,0dh,0ah
			BYTE "The operators in this group are used to perform various mathematical functions on the operands. They have the highest precedence."
			BYTE "The operands must be numerical values or expressions that can be evaluated to numerical values. The operators and their definitions are as follows:",0dh,0ah,0dh,0ah
			BYTE "FACT: This operator calculates the factorial of the operand. For example, FACT 5 returns 120, which is 5!.",0dh,0ah
			BYTE "SQRT: This operator calculates the square root of the operand. For example, SQRT 25 returns 5.",0dh,0ah
			BYTE "SIN: This operator calculates the sine of the operand in radians. For example, SIN 3.14159 returns 0, which is sin(pi).",0dh,0ah
			BYTE "COS: This operator calculates the cosine of the operand in radians. For example, COS 3.14159 returns -1, which is cos(pi).",0dh,0ah
			BYTE "TAN: This operator calculates the tangent of the operand in radians. For example, TAN 0.7854 returns 1, which is tan(pi/4).",0dh,0ah
			BYTE "LN: This operator calculates the natural logarithm of the operand. For example, LN 2.71828 returns 1, which is ln(e).",0dh,0ah
			BYTE "LG: This operator calculates the common logarithm of the operand. For example, LG 10 returns 1, which is log10(10).",0dh,0ah
			BYTE "LOG: This operator calculates the logarithm of operand to base 2. For example, LOG 8 returns 3, which is log2(8).",0dh,0ah
			BYTE "EXP: This operator calculates the exponential function of the operand. For example, EXP 1 returns 2.71828, which is e^1.",0dh,0ah,0dh,0ah
			BYTE "Group 2: Multiplicative Operators",0dh,0ah,0dh,0ah
			BYTE "The operators in this group are used to perform multiplication, division, exponentiation, and modulo operations on the operands. They have the second highest precedence.",0dh,0ah
			BYTE "The operands must be numerical values or expressions that can be evaluated to numerical values. The operators and their definitions are as follows:",0dh,0ah
			BYTE "*: This operator multiplies the first operand by the second operand. For example, 3 * 4 returns 12.",0dh,0ah
			BYTE "/: This operator divides the first operand by the second operand. For example, 12 / 4 returns 3.",0dh,0ah
			BYTE "^: This operator raises the first operand to the power of the second operand. For example, 2 ^ 3 returns 8",0dh,0ah
			BYTE "%: This operator calculates the remainder of the division of the first operand by the second operand. For example, 7 % 3 returns 1, which is 7 mod 3.",0dh,0ah,0dh,0ah
			BYTE "Group 3: Additive Operators",0dh,0ah,0dh,0ah
			BYTE "The operators in this group are used to perform addition and subtraction operations on the operands. They have the third highest precedence. ",0dh,0ah
			BYTE "The operands must be numerical values or expressions that can be evaluated to numerical values. The operators and their definitions are as follows:",0dh,0ah
			BYTE "+: This operator adds the first operand to the second operand. For example, 3 + 4 returns 7, which is 3 + 4.",0dh,0ah
			BYTE "-: This operator subtracts the second operand from the first operand. For example, 7 - 4 returns 3, which is 7 - 4.",0dh,0ah,0dh,0ah
			BYTE "Group 4: Unary Operators" ,0dh,0ah,0dh,0ah
			BYTE "The operators in this group are used to perform unary operations on the operand. They have the fourth highest precedence. ",0dh,0ah
			BYTE "The operand must be a numerical value or an expression that can be evaluated to a numerical value. The operators and their definitions are as follows:",0dh,0ah
			BYTE "ABS: This operator returns the absolute value of the operand. For example, ABS -5 returns 5, which is |-5|.",0dh,0ah
			BYTE "NEG: This operator returns the negative value of the operand. For example, NEG 5 returns -5, which is -5.",0dh,0ah
			BYTE "IN: This operator returns the ith history of calculation in accordance with the number shown on the screen. For example, IN 1 returns the calculation result of the line with IN[1].",0dh,0ah
			BYTE "OUT: This operator returns the same as IN. For example, OUT 5 returns the calculation result of the line with OUT[5].",0dh,0ah
			BYTE "FL: This operator returns the floor value of the operand, which is the largest integer that is less than or equal to the operand. For example, FL 3.14 returns 3.",0dh,0ah,0dh,0ah
			BYTE "Group 5: Equality Operators",0dh,0ah,0dh,0ah
			BYTE "The operators in this group are used to compare the equality of the operands. They have the fifth highest precedence. ",0dh,0ah
			BYTE "The operands must be numerical values or expressions that can be evaluated to numerical values. The operators and their definitions are as follows:",0dh,0ah
			BYTE "==: This operator returns 1 if the first operand is equal to the second operand, or 0 otherwise. For example, 3 == 4 returns 0, or false.",0dh,0ah
			BYTE "!=: This operator returns 1 if the first operand is not equal to the second operand, or 0 otherwise. For example, 3 != 4 returns 1, or true.",0dh,0ah,0dh,0ah
			BYTE "Group 6: Logical Operators",0dh,0ah,0dh,0ah
			BYTE "The operators in this group are used to perform logical operations on the operands. They have the sixth highest precedence. ",0dh,0ah
			BYTE "The operands must be numerical values or expressions that can be evaluated to numerical values. The operators and their definitions are as follows:",0dh,0ah
			BYTE "&&: This operator returns 1 if both operands are true, or 0 otherwise. For example, 1 && 0 returns 0, or false.",0dh,0ah
			BYTE "||: This operator returns 1 if either operand is true, or 0 otherwise. For example, 1 || 0 returns 1, or true.",0dh,0ah,0dh,0ah
			BYTE "Group 7: Assignment Operator",0dh,0ah,0dh,0ah
			BYTE "The operator in this group is used to assign the value of the second operand to the first operand. It has the lowest precedence. ",0dh,0ah
			BYTE "The first operand must be a variable name, and the second operand must be a numerical value or an expression that can be evaluated to a numerical value. The operator and its definition are as follows:",0dh,0ah
			BYTE ":=: This operator assigns the value of the second operand to the first operand. For example, x := 5 assigns 5 to the variable x.",0dh,0ah,0
public helpText
END