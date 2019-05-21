CPP=g++ -std=c++11
CC=gcc
LEX=flex
YACC=bison
LD=gcc

all:	pepeXD

pepeXD:	def.tab.o lex.yy.o
	$(CPP) lex.yy.o def.tab.o -o pepeXD -ll

lex.yy.o:	lex.yy.c
	$(CC) -c lex.yy.c

lex.yy.c: lab.l
	$(LEX) lab.l

def.tab.o:	def.tab.cc
	$(CPP) -c def.tab.cc 

def.tab.cc:	def.yy
	$(YACC) -d def.yy

clean:
	rm *.o pepeXD def.tab.cc lex.yy.c
