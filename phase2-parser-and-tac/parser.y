/* =============================================================
 * parser.y  –  Parser + Three-Address Code Generator for a
 *              Minimal Modula-2 Subset
 * Compiler Construction (CS F363) – Group 13
 *
 * Implements the CFG from docs/cfg-and-lexical-spec.md with Bison,
 * left recursion kept exactly as specified. Every expression and
 * statement rule carries a semantic action that emits three-address
 * code as it reduces; conditionals and loops use mid-rule actions to
 * emit jump/label instructions at the right point mid-parse (see the
 * comments on the `conditional` and `loop` rules below for exactly
 * which symbol position each action fires at).
 * =============================================================
 */

/* ─────────────────────────────────────────────────────────────
 * SECTION 1 – C HEADER
 * ───────────────────────────────────────────────────────────── */
%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

extern int yylex(void); //gets the next token
extern int yylineno; //shows the current line number
void yyerror(const char *s); //error function it is called when syntax error occurs 

/* ──────────────────────────────────────────────────────────────
 * TAC HELPER FUNCTIONS
 *
 *  new_temp()  – returns a fresh temporary: t1, t2, t3, …
 *  new_label() – returns a fresh label:     L1, L2, L3, …
 * ────────────────────────────────────────────────────────────── */
static int temp_count  = 0;
static int label_count = 0;

char *new_temp(void)
{
    char *buf = (char *)malloc(16);
    sprintf(buf, "t%d", ++temp_count);
    return buf;
}

char *new_label(void)
{
    char *buf = (char *)malloc(16);
    sprintf(buf, "L%d", ++label_count);
    return buf;
}
%}

/* ─────────────────────────────────────────────────────────────
 * SECTION 2 – UNION  (semantic value type)
 *
 * A single char* member covers: identifier names, number text,
 * generated temporaries, label strings, and operator symbols.
 * ───────────────────────────────────────────────────────────── */
%union {
    char *sval;
} //collection of possible data types that the semantic values of grammar can hold

/* ─────────────────────────────────────────────────────────────
 * SECTION 3 – TOKEN DECLARATIONS
 *
 * Keywords and punctuation tokens need no semantic value.
 * IDENTIFIER and NUMBER carry their matched text via sval.
 * ───────────────────────────────────────────────────────────── */

/* ── Keywords (no value) ── */
%token  MODULE
%token  KW_BEGIN
%token  END
%token  VAR
%token  INTEGER
%token  BOOLEAN
%token  IF
%token  THEN
%token  ELSE
%token  WHILE
%token  DO
%token  AND
%token  OR
%token  NOT
%token  TRUE
%token  FALSE

/* ── Multi-character operators (no value) ── */
%token  ASSIGN          /* :=  */
%token  LE              /* <=  */
%token  GE              /* >=  */
%token  NE              /* <>  */

/* ── Terminals that carry text ── */
%token  <sval>  IDENTIFIER
%token  <sval>  NUMBER

/* ── Non-terminals that produce a string (temp var or operand) ── */
%type   <sval>  expr
%type   <sval>  rel_expr
%type   <sval>  rel_op
%type   <sval>  arith_expr
%type   <sval>  add_op
%type   <sval>  term
%type   <sval>  mul_op
%type   <sval>  factor

/* ─────────────────────────────────────────────────────────────
 * SECTION 4 – GRAMMAR RULES WITH SEMANTIC ACTIONS
 * ───────────────────────────────────────────────────────────── */
%%

/* ── Program ─────────────────────────────────────────────────
 * Program -> 'MODULE' identifier ';' 'BEGIN' StatementSequence
 *            'END' identifier '.'
 */
program:
    MODULE IDENTIFIER ';' KW_BEGIN statement_sequence END IDENTIFIER '.'
    {
        printf("\n");
        printf("--------------------------------------\n");
        printf("TAC generation complete.\n");
        printf("Parse successful - valid Modula-2 program.\n");
    }
    ;

/* ── StatementSequence ──────────────────────────────────────
 * Left-recursive, as in the original CFG.
 */
statement_sequence:
      /* empty */
    | statement_sequence statement ';'
    ;

/* ── Statement ── */
statement:
      var_decl
    | assignment
    | conditional
    | loop
    ;

/* ── VarDecl ─────────────────────────────────────────────────
 * No TAC emitted for declarations (type-checking phase concern).
 */
var_decl:
    VAR IDENTIFIER ':' type
    ;

/* ── Type ── */
type:
      INTEGER
    | BOOLEAN
    ;

/* ── Assignment ──────────────────────────────────────────────
 * Assignment -> identifier ':=' Expr
 *
 * TAC:   <identifier> = <expr_temp>
 */
assignment:
    IDENTIFIER ASSIGN expr
    {
        printf("  %s = %s\n", $1, $3);
    }
    ;

/* ── Conditional ─────────────────────────────────────────────
 * Conditional -> 'IF' Expr 'THEN' StatementSeq 'ELSE' StatementSeq 'END'
 *
 * Symbol positions after mid-rule injection:
 *
 *   IF  expr  {MRA1}  THEN  stmt_seq  {MRA2}  ELSE  stmt_seq  END
 *   $1  $2    $3      $4    $5        $6      $7    $8        $9
 *
 * MRA1 (pos $3): emits  "if <cond> goto L_true"
 *                       "goto L_false"
 *                       "L_true:"
 *                packs  "L_false|L_end" into $<sval>$
 *
 * MRA2 (pos $6): unpacks MRA1 result, emits  "goto L_end"
 *                                             "L_false:"
 *                stores  L_end string into $<sval>$
 *
 * Final action:  emits  "L_end:"
 */
conditional:
    IF expr
    {
        /* ── MRA1: emit conditional jump ── */
        char *l_true  = new_label();
        char *l_false = new_label();
        char *l_end   = new_label();

        printf("  if %s goto %s\n", $2, l_true);
        printf("  goto %s\n",           l_false);
        printf("%s:\n",                 l_true);

        /* Pack both labels into one string for MRA2 to consume */
        char *packed = (char *)malloc(64);
        sprintf(packed, "%s|%s", l_false, l_end);
        $<sval>$ = packed;
    }
    THEN statement_sequence
    {
        /* ── MRA2: close true-branch, open false-branch ── */
        /* $<sval>3 is MRA1's packed "L_false|L_end" string */
        char l_false[32], l_end[32];
        sscanf($<sval>3, "%[^|]|%s", l_false, l_end);

        printf("  goto %s\n", l_end);
        printf("%s:\n",       l_false);

        $<sval>$ = strdup(l_end);   /* pass L_end to the final action */
    }
    ELSE statement_sequence END
    {
        /* ── Final: emit end label ── */
        /* $<sval>6 is MRA2's L_end string */
        printf("%s:\n", $<sval>6);
    }
    ;

/* ── Loop ────────────────────────────────────────────────────
 * Loop -> 'WHILE' Expr 'DO' StatementSequence 'END'
 *
 * Symbol positions after mid-rule injection:
 *
 *   WHILE  {MRA1}  expr  {MRA2}  DO  stmt_seq  END
 *   $1     $2      $3    $4      $5  $6        $7
 *
 * MRA1 (pos $2): emits  "L_start:"
 *                stores  L_start string
 *
 * MRA2 (pos $4): emits  "if <cond> goto L_body"
 *                       "goto L_end"
 *                       "L_body:"
 *                packs  "L_start|L_end" into $<sval>$
 *
 * Final action:  emits  "goto L_start"
 *                       "L_end:"
 */
loop:
    WHILE
    {
        /* ── MRA1: emit loop start label ── */
        char *l_start = new_label();
        printf("%s:\n", l_start);
        $<sval>$ = l_start;
    }
    expr
    {
        /* ── MRA2: emit conditional jump over loop body ── */
        /* $<sval>2 = L_start,  $3 = condition temp */
        char *l_body = new_label();
        char *l_end  = new_label();

        printf("  if %s goto %s\n", $3, l_body);
        printf("  goto %s\n",           l_end);
        printf("%s:\n",                 l_body);

        char *packed = (char *)malloc(64);
        sprintf(packed, "%s|%s", $<sval>2, l_end);
        $<sval>$ = packed;
    }
    DO statement_sequence END
    {
        /* ── Final: emit back-edge and loop-exit label ── */
        /* $<sval>4 = "L_start|L_end" */
        char l_start[32], l_end[32];
        sscanf($<sval>4, "%[^|]|%s", l_start, l_end);

        printf("  goto %s\n", l_start);
        printf("%s:\n",       l_end);
    }
    ;

/* ── Expr (Level 1 – Logical) ────────────────────────────────
 * Expr -> Expr 'OR'  RelExpr
 *       | Expr 'AND' RelExpr
 *       | RelExpr
 *
 * Left-recursive (kept as specified).
 *
 * TAC:  t_new = <left> OR/AND <right>
 */
expr:
      expr OR rel_expr
      {
          char *t = new_temp();
          printf("  %s = %s OR %s\n", t, $1, $3);
          $$ = t;
      }
    | expr AND rel_expr
      {
          char *t = new_temp();
          printf("  %s = %s AND %s\n", t, $1, $3);
          $$ = t;
      }
    | rel_expr
      { $$ = $1; }
    ;

/* ── RelExpr (Level 2 – Relational) ─────────────────────────
 * RelExpr -> ArithExpr RelOp ArithExpr | ArithExpr
 *
 * TAC:  t_new = <left> <op> <right>
 */
rel_expr:
      arith_expr rel_op arith_expr
      {
          char *t = new_temp();
          printf("  %s = %s %s %s\n", t, $1, $2, $3);
          $$ = t;
      }
    | arith_expr
      { $$ = $1; }
    ;

/* ── RelOp ── */
rel_op:
      '<'  { $$ = strdup("<");  }
    | '>'  { $$ = strdup(">");  }
    | '='  { $$ = strdup("=");  }
    | LE   { $$ = strdup("<="); }
    | GE   { $$ = strdup(">="); }
    | NE   { $$ = strdup("<>"); }
    ;

/* ── ArithExpr (Level 3 – Add/Sub) ──────────────────────────
 * ArithExpr -> ArithExpr AddOp Term | Term
 *
 * TAC:  t_new = <left> +/- <right>
 */
arith_expr:
      arith_expr add_op term
      {
          char *t = new_temp();
          printf("  %s = %s %s %s\n", t, $1, $2, $3);
          $$ = t;
      }
    | term
      { $$ = $1; }
    ;

/* ── AddOp ── */
add_op:
      '+'  { $$ = strdup("+"); }
    | '-'  { $$ = strdup("-"); }
    ;

/* ── Term (Level 4 – Mul/Div) ────────────────────────────────
 * Term -> Term MulOp Factor | Factor
 *
 * TAC:  t_new = <left> (op) <right>
 */
term:
      term mul_op factor
      {
          char *t = new_temp();
          printf("  %s = %s %s %s\n", t, $1, $2, $3);
          $$ = t;
      }
    | factor
      { $$ = $1; }
    ;

/* ── MulOp ── */
mul_op:
      '*'  { $$ = strdup("*"); }
    | '/'  { $$ = strdup("/"); }
    ;

/* ── Factor (Level 5 – Base Expressions) ────────────────────
 * Factor -> identifier | number | 'TRUE' | 'FALSE'
 *         | 'NOT' Factor | '(' Expr ')'
 *
 * TAC for NOT:  t_new = NOT <operand>
 * Parenthesised sub-expression just propagates its temp.
 */
factor:
      IDENTIFIER
      { $$ = $1; }
    | NUMBER
      { $$ = $1; }
    | TRUE
      { $$ = strdup("TRUE"); }
    | FALSE
      { $$ = strdup("FALSE"); }
    | NOT factor
      {
          char *t = new_temp();
          printf("  %s = NOT %s\n", t, $2);
          $$ = t;
      }
    | '(' expr ')'
      { $$ = $2; }
    ;

%%

/* ─────────────────────────────────────────────────────────────
 * SECTION 5 – SUPPORTING C FUNCTIONS
 * ───────────────────────────────────────────────────────────── */

void yyerror(const char *s)
{
    fprintf(stderr, "Syntax Error (near line %d)\n", yylineno);
    (void)s;
}

int main(int argc, char **argv)
{
    if (argc > 1) {
        extern FILE *yyin;
        yyin = fopen(argv[1], "r");
        if (!yyin) {
            fprintf(stderr, "Error: could not open '%s'\n", argv[1]);
            return 1;
        }
    }
    /* With no filename argument, yyin defaults to stdin — run as
     * `./compiler < program.mod` or pipe a program in. */

    printf("============================================\n");
    printf("  Modula-2 Compiler – Parser + TAC Output    \n");
    printf("============================================\n");
    printf("Three-Address Code:\n\n");

    int result = yyparse();

    if (result != 0)
        printf("Status: Parsing FAILED.\n");

    return result;
}
