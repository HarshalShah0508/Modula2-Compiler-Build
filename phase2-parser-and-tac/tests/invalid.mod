(* ============================================================
 * invalid.mod  –  INVALID Modula-2 test program
 * Expected result: "Syntax Error"  then  "Parsing FAILED."
 *
 * Errors introduced:
 *   1. Missing ';' after MODULE header  (should be MODULE Bad;)
 *   2. ':=' replaced with '=' in assignment
 *   3. Missing END at close of IF
 * ============================================================ *)

MODULE Bad
BEGIN
    VAR y : INTEGER;
    y = 5;
    IF y > 0 THEN
        y := y + 1;
END Bad.
