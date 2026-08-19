%{
/* =============================================================
 * lexer.l  -  Phase 1: Standalone Lexer for a Minimal Modula-2 Subset
 * Compiler Construction (CS F363) - Group 13
 *
 * Reads a source file (argv[1], or stdin if omitted), prints one
 * line per recognized token, and reports every lexical error
 * (unrecognized character) without stopping the scan. Exit status
 * is the number of lexical errors found (0 = clean scan), so this
 * can be used directly in a test script.
 * =============================================================
 */
#include <stdio.h>
#include <stdlib.h>

static int error_count = 0;
static int token_count = 0;

static void emit(const char *type) {
    printf("%-6d %-12s %s\n", yylineno, type, yytext);
    token_count++;
}
%}

%option yylineno
%x COMMENT

%%

    /* -- Block comments: (* ... *) -------------------------- */
"(*"                    { BEGIN(COMMENT); }
<COMMENT>"*)"           { BEGIN(INITIAL); }
<COMMENT>.|\n           { /* ignore everything inside a comment */ }

    /* -- Keywords --------------------------------------------- */
"MODULE"                { emit("KEYWORD"); }
"BEGIN"                 { emit("KEYWORD"); }
"END"                   { emit("KEYWORD"); }
"VAR"                   { emit("KEYWORD"); }
"INTEGER"               { emit("KEYWORD"); }
"BOOLEAN"               { emit("KEYWORD"); }
"IF"                    { emit("KEYWORD"); }
"THEN"                  { emit("KEYWORD"); }
"ELSE"                  { emit("KEYWORD"); }
"WHILE"                 { emit("KEYWORD"); }
"DO"                    { emit("KEYWORD"); }
"AND"                   { emit("KEYWORD"); }
"OR"                    { emit("KEYWORD"); }
"NOT"                   { emit("KEYWORD"); }
"TRUE"                  { emit("KEYWORD"); }
"FALSE"                 { emit("KEYWORD"); }

    /* -- Multi-character operators ----------------------------- */
":="                    { emit("OPERATOR"); }
"<="                    { emit("OPERATOR"); }
">="                    { emit("OPERATOR"); }
"<>"                    { emit("OPERATOR"); }

    /* -- Single-character operators ------------------------------ */
"+"                     { emit("OPERATOR"); }
"-"                     { emit("OPERATOR"); }
"*"                     { emit("OPERATOR"); }
"/"                     { emit("OPERATOR"); }
"="                     { emit("OPERATOR"); }
"<"                     { emit("OPERATOR"); }
">"                     { emit("OPERATOR"); }

    /* -- Punctuation ------------------------------------------- */
";"                     { emit("PUNCT"); }
":"                     { emit("PUNCT"); }
","                     { emit("PUNCT"); }
"("                     { emit("PUNCT"); }
")"                     { emit("PUNCT"); }
"."                     { emit("PUNCT"); }

    /* -- Identifiers and numeric literals ------------------------ */
[a-zA-Z][a-zA-Z0-9]*    { emit("IDENTIFIER"); }
[0-9]+                  { emit("NUMBER"); }

    /* -- Whitespace: skip silently ------------------------------ */
[ \t\r]+                { /* skip */ }
\n                      { /* skip - yylineno advances automatically */ }

    /* -- Catch-all: lexical error -------------------------------- */
.                       {
                            fprintf(stderr, "Lexical error at line %d: unexpected character '%s'\n",
                                    yylineno, yytext);
                            error_count++;
                        }

%%

int yywrap(void) {
    return 1;
}

int main(int argc, char **argv) {
    if (argc > 1) {
        yyin = fopen(argv[1], "r");
        if (!yyin) {
            fprintf(stderr, "Error: could not open '%s'\n", argv[1]);
            return 1;
        }
    }

    printf("%-6s %-12s %s\n", "LINE", "TOKEN", "LEXEME");
    printf("--------------------------------\n");

    yylex();

    printf("--------------------------------\n");
    printf("%d token(s), %d lexical error(s).\n", token_count, error_count);

    if (argc > 1) {
        fclose(yyin);
    }

    return error_count > 0 ? 1 : 0;
}
