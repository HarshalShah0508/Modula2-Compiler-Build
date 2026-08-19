CC     = gcc
CFLAGS = -Wall -Wextra

.PHONY: all test clean

all: compiler

compiler: lex.yy.c parser.tab.c
	$(CC) $(CFLAGS) lex.yy.c parser.tab.c -o compiler

lex.yy.c: lexer.l parser.tab.h
	flex lexer.l

parser.tab.c parser.tab.h: parser.y
	bison -d parser.y

test: compiler
	@echo "== tests/valid.mod (expect: exit 0, 'Parse successful') =="
	@./compiler tests/valid.mod; \
	if [ $$? -ne 0 ]; then echo "FAIL: expected exit code 0"; exit 1; fi
	@echo
	@echo "== tests/invalid.mod (expect: exit 1, 'Syntax Error') =="
	@./compiler tests/invalid.mod; \
	if [ $$? -ne 1 ]; then echo "FAIL: expected exit code 1"; exit 1; fi

clean:
	rm -f lex.yy.c parser.tab.c parser.tab.h compiler
