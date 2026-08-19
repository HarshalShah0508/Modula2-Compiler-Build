# Language Specification

Formal specification of the minimal Modula-2 subset implemented by this
project, as submitted in the Phase 1 report
([`Assignment(Phase-1)_Group_13.pdf`](Assignment(Phase-1)_Group_13.pdf)).

The grammar supports variable declarations, assignment, arithmetic /
relational / logical expressions, one conditional statement, and one loop
statement — with five levels of operator precedence.

## Context-Free Grammar

```
Program          -> 'MODULE' identifier ';' 'BEGIN' StatementSequence 'END' identifier '.'
StatementSequence -> Statement ';' StatementSequence | Statement ';' | ε
Statement        -> VarDecl | Assignment | Conditional | Loop

// Variable declaration
VarDecl          -> 'VAR' identifier ':' Type
Type             -> 'INTEGER' | 'BOOLEAN'

// Assignment
Assignment       -> identifier ':=' Expr

// Conditional
Conditional      -> 'IF' Expr 'THEN' StatementSequence 'ELSE' StatementSequence 'END'

// Loop
Loop             -> 'WHILE' Expr 'DO' StatementSequence 'END'

// Expressions, precedence level 1 (lowest) -> 5 (highest)
// Level 1: Logical
Expr             -> Expr 'OR' RelExpr | Expr 'AND' RelExpr | RelExpr
// Level 2: Relational
RelExpr          -> ArithExpr RelOp ArithExpr | ArithExpr
RelOp            -> '<' | '>' | '=' | '<=' | '>=' | '<>'
// Level 3: Addition / Subtraction
ArithExpr        -> ArithExpr AddOp Term | Term
AddOp            -> '+' | '-'
// Level 4: Multiplication / Division
Term             -> Term MulOp Factor | Factor
MulOp            -> '*' | '/'
// Level 5: Base expressions
Factor           -> identifier | number | 'TRUE' | 'FALSE' | 'NOT' Factor | '(' Expr ')'
```

Left recursion in `StatementSequence`, `Expr`, `RelExpr`, `ArithExpr`, and
`Term` is intentional — Bison (an LALR parser generator) handles left
recursion natively and more efficiently than right recursion.

## Lexical Specification

Every terminal in the CFG maps to a regular expression, implemented as a
Flex rule in both `phase1-lexical-analysis/lexer.l` and
`phase2-parser-and-tac/lexer.l`.

**Identifiers & numbers**

| Token | Regex |
|---|---|
| Identifier | `[a-zA-Z][a-zA-Z0-9]*` |
| Number | `[0-9]+` |

**Keywords** — matched literally: `MODULE`, `BEGIN`, `END`, `VAR`,
`INTEGER`, `BOOLEAN`, `IF`, `THEN`, `ELSE`, `WHILE`, `DO`, `AND`, `OR`,
`NOT`, `TRUE`, `FALSE`.

**Operators**

| Token | Regex |
|---|---|
| Assign | `:=` |
| Add / Sub / Mul / Div | `+`  `-`  `*`  `/` |
| Equal / Not Equal | `=`  `<>` |
| Less / Greater | `<`  `>` |
| Less-or-equal / Greater-or-equal | `<=`  `>=` |

**Punctuation**: `;` `:` `,` `(` `)` `.`

**Ignored**

| Token | Regex |
|---|---|
| Whitespace | `[ \t\n]+` |
| Block comment | `"(*" ([^*] \| \*+[^)*])* \*+ "*)"` — implemented with a Flex exclusive start state (`%x COMMENT`) rather than a single regex, since comments can span multiple lines |

## Why Modula-2

The assignment required each group to pick a distinct language, excluding
C, Python, and Java. Modula-2's `BEGIN`/`END`-delimited blocks and
`MODULE` structure keep the grammar close to a textbook Pascal-family
example while still being a real, historically significant systems
language (designed by Niklaus Wirth as Pascal's successor).
