CC     = gcc
CFLAGS = -Wall -Wextra

.PHONY: all test clean

all: lexer

lexer: lex.yy.c
	$(CC) $(CFLAGS) lex.yy.c -o lexer

lex.yy.c: lexer.l
	flex lexer.l

test: lexer
	@echo "== tests/valid.mod (expect: exit 0, 0 lexical errors) =="
	./lexer tests/valid.mod
	@echo
	@echo "== tests/lexical_error.mod (expect: exit 1, 3 lexical errors) =="
	@./lexer tests/lexical_error.mod; \
	if [ $$? -ne 1 ]; then echo "FAIL: expected exit code 1"; exit 1; fi

clean:
	rm -f lex.yy.c lexer
