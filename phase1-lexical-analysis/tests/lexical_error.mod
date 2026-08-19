(* ============================================================
 * lexical_error.mod - contains characters outside the language's
 * alphabet, so the LEXER itself must reject them (distinct from
 * invalid.mod in phase2, which is syntactically wrong but
 * lexically clean).
 * ============================================================ *)

MODULE Bad;
BEGIN
    VAR x : INTEGER;
    x := 5 @ 3;
    x := x # 1;
    y := $10;
END Bad.
