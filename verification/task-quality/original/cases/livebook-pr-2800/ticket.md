# Erlang syntax errors fail while formatting the diagnostic

Evaluating an Erlang cell with a syntax error can raise an additional ArgumentError while constructing the error message, obscuring the original problem.

Examples include incomplete input `X =`, invalid syntax `X ==/== a.`, and an unterminated character literal `$a$`. The evaluation response should contain a readable diagnostic for the original Erlang error, with the offending source line and location. It must not fail while rendering that diagnostic. Ordinary Erlang runtime exceptions should still be reported correctly.

Repair the error reporting and add regression coverage through cell evaluation.
