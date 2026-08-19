# Modula-2 Compiler Frontend

[![CI](https://github.com/HarshalShah0508/Modula2-Compiler-Frontend/actions/workflows/ci.yml/badge.svg)](https://github.com/HarshalShah0508/Modula2-Compiler-Frontend/actions/workflows/ci.yml)
[![Flex](https://img.shields.io/badge/Lexer-Flex-blue?style=flat-square)](https://github.com/westes/flex)
[![Bison](https://img.shields.io/badge/Parser-GNU%20Bison-blue?style=flat-square)](https://www.gnu.org/software/bison/)
[![C](https://img.shields.io/badge/C-POSIX-00599C?style=flat-square&logo=c&logoColor=white)](https://en.wikipedia.org/wiki/C_(programming_language))

A hand-built compiler frontend — lexer, parser, and three-address-code
generator — for a minimal subset of **Modula-2**, Niklaus Wirth's
Pascal successor. Built with Flex and GNU Bison as a two-phase Compiler
Construction (CS F363) assignment: Phase 1 designs the language and
implements the lexer; Phase 2 adds an LALR parser and TAC generation on
top of it.

Feed it a `.mod` program and it lexes, parses, and — if the program is
syntactically valid — emits three-address code with real labels and jumps
for `IF`/`ELSE` and `WHILE`, ready to hand to a later codegen phase.

## Example

Input (`phase2-parser-and-tac/tests/valid.mod`):

```modula2
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
```

Output:

```
Three-Address Code:

  x = 10
  t1 = 5 * 2
  t2 = x + t1
  x = t2
  t3 = x > 12
  flag = t3
  if flag goto L1
  goto L2
L1:
  t4 = x - 1
  x = t4
  goto L3
L2:
  t5 = x + 1
  x = t5
L3:
L4:
  t6 = x > 0
  if t6 goto L5
  goto L6
L5:
  t7 = x - 1
  x = t7
  goto L4
L6:

--------------------------------------
TAC generation complete.
Parse successful - valid Modula-2 program.
```

Note the constant-folding-free, textbook TAC: every sub-expression gets
its own temporary (`t1`, `t2`, …), and control flow lowers to explicit
labels and conditional/unconditional jumps — exactly the intermediate
form a later optimization or codegen pass would expect.

## Language

A minimal Modula-2 subset: `MODULE`-delimited programs, `VAR` declarations
(`INTEGER`/`BOOLEAN`), assignment, one `IF`/`THEN`/`ELSE` conditional, one
`WHILE` loop, and arithmetic/relational/logical expressions across five
precedence levels. Full CFG and lexical spec (regex per terminal):
[`docs/cfg-and-lexical-spec.md`](docs/cfg-and-lexical-spec.md).

## Project Structure

```
Modula2-Compiler-Frontend/
├── phase1-lexical-analysis/     Phase 1: standalone lexer
│   ├── lexer.l                   Prints a token table (line, type, lexeme)
│   ├── Makefile                  make / make test / make clean
│   └── tests/
│       ├── valid.mod
│       └── lexical_error.mod     Characters outside the language's alphabet
│
├── phase2-parser-and-tac/       Phase 2: parser + TAC generator
│   ├── lexer.l                   Same tokens, feeds Bison instead of printing
│   ├── parser.y                  LALR grammar + TAC-emitting semantic actions
│   ├── Makefile
│   └── tests/
│       ├── valid.mod
│       └── invalid.mod           Syntactically invalid (missing ';', bad END, etc.)
│
├── docs/
│   ├── cfg-and-lexical-spec.md
│   ├── Assignment(Phase-1)_Group_13.pdf   Submitted Phase 1 report
│   ├── CC_Assignment(Phase-2)_Group_13.pdf Submitted Phase 2 report
│   └── assignment-brief.pdf                Original assignment spec (course staff)
│
└── .github/workflows/ci.yml     Builds + tests both phases on every push
```

`phase1-lexical-analysis` and `phase2-parser-and-tac` are independent,
buildable units — each has its own lexer and its own `Makefile` — because
that mirrors how the assignment was actually graded: two separate
deliverables, not one program that grew a second executable bolted on.

## Quick Start

Requires `flex`, `bison`, and `gcc` (or any C99 compiler).

```bash
git clone https://github.com/HarshalShah0508/Modula2-Compiler-Frontend.git
cd Modula2-Compiler-Frontend

# Phase 1 — lexer only
cd phase1-lexical-analysis
make
./lexer tests/valid.mod

# Phase 2 — parser + TAC generation
cd ../phase2-parser-and-tac
make
./compiler tests/valid.mod
```

Each phase's `make test` builds and runs both the valid and invalid test
programs, asserting the exit code matches what's expected (`0` for a
clean parse, `1` for a caught error) — the same check CI runs on every
push.

```bash
cd phase1-lexical-analysis && make test
cd ../phase2-parser-and-tac && make test
```

## How TAC generation works

Every expression rule (`expr`, `rel_expr`, `arith_expr`, `term`, `factor`)
returns a string — either a `t<n>` temporary it just allocated, or an
operand it received unchanged from a lower-precedence rule — via Bison's
`$$`. A binary operator rule allocates one fresh temporary, prints
`tN = left op right`, and returns `tN`; a rule that just passes an operand
through (e.g. `factor: IDENTIFIER`) returns it directly with no code
emitted, so no unnecessary copies pile up in straight-line expressions.

`IF` and `WHILE` need labels emitted *between* grammar symbols — before
the parser has seen the whole rule — so both use **mid-rule actions**
(`{ ... }` inserted directly in the middle of a production). For example,
`conditional` fires three actions at three different points while
matching one `IF ... THEN ... ELSE ... END`:

1. Right after `expr` — emit the conditional jump (`if cond goto L_true`,
   `goto L_false`, `L_true:`), and pack `L_false`/`L_end` into the mid-rule
   action's own synthesized value for the next action to read
2. Right after the `THEN` branch's statements — close the true branch
   (`goto L_end`), open the false branch (`L_false:`)
3. At the very end — emit `L_end:`

`loop` follows the same pattern for `WHILE`. See the comments directly
above each rule in [`parser.y`](phase2-parser-and-tac/parser.y) for the
exact `$1`/`$2`/… symbol numbering, since mid-rule actions shift every
subsequent symbol's position by one.

## Testing

Beyond the required "one valid, one invalid" program per phase, this repo
adds a genuine **lexical**-error test
(`phase1-lexical-analysis/tests/lexical_error.mod`) distinct from the
**syntax**-error test used in Phase 2 — the original assignment draft only
had a syntactically-invalid program, which doesn't actually exercise the
lexer's catch-all "unrecognized character" rule at all.

| Test | Phase | Checks |
|---|---|---|
| `valid.mod` | 1 | Every real token is recognized correctly, 0 lexical errors |
| `lexical_error.mod` | 1 | `@`, `#`, `$` are correctly rejected as unrecognized characters, with line numbers |
| `valid.mod` | 2 | Parses successfully; TAC output is well-formed (checked manually against the example above) |
| `invalid.mod` | 2 | Missing `;`, `:=` written as `=`, and a missing `END` are all caught, parse exits non-zero |

## Contributors

Group 13, Compiler Construction (CS F363), BITS Pilani Hyderabad Campus —
under Prof. J Jabez Christopher.

- Harshal Shah — 2023A7PS0055H
- Arav Thakkar — 2023A7PS1091H
- Mokshil Shah — 2023A7PS0139H
- Marmik Sapovadia — 2023A7PS0057H
- Akshat Kumar — 2023A7PS0117H

## Limitations

- No type checking — `VAR x : INTEGER; x := TRUE;` parses and generates
  TAC without complaint, since the CFG doesn't encode types beyond the
  declaration keyword
- No symbol table — a `WHILE` referencing an undeclared identifier is
  syntactically fine and will happily generate TAC for it
- Single-pass: TAC is emitted directly during parsing (no AST is built),
  so there's no intermediate representation to run further optimization
  passes over without restructuring the parser
