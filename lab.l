%{
#include <stdlib.h>
#include <string.h>
#include "def.tab.hh"
#define INFILE_ERROR 1
#define OUTFILE_ERROR 2
extern int yylineno;
int yyerror(const char *,...);
%}
%%
\=\=					{ return EQ;}
\!\=					{ return NE;}
\<						{ return LT;}
\>						{ return GT;}
\>\=					{return GE;}
\<\=					{return LE;}

"for"	{return FOR;}
"whiledo"	{return WHILE;}
"iffy"	{return IF;}
"elseiffy"	{return ELSEIF;}
"else"	{return ELSE;}
"int" { return INT;}
"float" {return FLOAT;}
"string" {return STRING;}
";" {return ';';}
"printfl" {return PRINTFL;}
"printfi" {return PRINTI;}
"printfstr" {return PRINTSTR;}
"readint" {return INPUTIN;}
"readfloat" {return INPUTFIN;}

\-	{printf("minus");return '-';}
\+	{printf("znak +");return '+';}
\*	{printf("znak *");return '*';}
\/						{ return '/';}
\=	{printf("przypisane");return '=';} 
\(	{return '(';}
\)	{return ')';}
\{						{ return '{';}
\}						{ return '}';}
\[						{ return '[';}
\]						{ return ']';}
\"[^\"]*\" {yylval.text = strdup(yytext);
			return STRING;}
[_a-zA-Z][_a-zA-Z0-9]*	{yylval.text = strdup(yytext);return ID;}
[1-9][0-9]*|0 {
				
				yylval.ival = atoi(yytext);
				return LC;
			}	
([1-9][0-9]*|0)"."[0-9]* {yylval.dval = atof(yytext);return LD;}
\ |\t			{;}
\n			{yylineno++ ;}
.	{printf("jakis error\n");}
%%
int yyerror(const char *msg,...)
{
	//printf("%d: %s", yylineno, msg);
	printf("blad w linii : %d: %s", yylineno, msg);
	exit(1);
}
