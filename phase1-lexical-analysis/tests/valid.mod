(* ============================================================
 * valid.mod  –  VALID Modula-2 test program
 * Expected result: "Parse successful – valid Modula-2 program."
 * ============================================================ *)

MODULE Sample;
BEGIN
    VAR x : INTEGER;
    VAR flag : BOOLEAN;
    x := 10;
    x := x + 5 * 2;
    flag := x > 12;
    IF flag THEN
        x := x - 1;
    ELSE
        x := x + 1;
    END;
    WHILE x > 0 DO
        x := x - 1;
    END;
END Sample.
