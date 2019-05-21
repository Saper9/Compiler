%{
#include <string>
#include <stdio.h>
#include <stack>
#include <vector>
#include <map>
#include <iostream>
#include <fstream>
#include <sstream>
#define INFILE_ERROR 1
#define OUTFILE_ERROR 2
FILE* file;
FILE* trees;
FILE* assembler;
extern "C" int yylex();
extern "C" int yyerror(const char*msg,...);
using namespace std;
#define TINT 0
#define TFLOAT 1
struct Strc{
	int token;
	string val;
}strc;
//informacje o symbolu
struct symbol_info{
 int type; //int,float,string , czyli LD,LC czy STRING
 int size; //rozmiar
 string id; //nazwa zmiennej aka. id
 string value; //wartosc
};
//pojemniki
stack<Strc> stk; //stos
vector<string> code; //asm
map<string,struct symbol_info>symbole;
int ARRINT = 10;
int ARRFLOAT = 11;
void callsyscall();
void printintg(string name);
void printfloat(string name);
void printString(string name);
void inputinteger(string name);
void inputfloat(string name);
int getype(Strc el);
string addtorejestr(Strc arg, int rejestr);
string gettypes(Strc arg1, Strc arg2);
void makeCode(Strc arg1, Strc arg2,char sign, string resultName);
void treeMaker(char sign);
string convert (int id);
void porownaniewarunku(string var);
static int licznik = 0;
//do zagniezdzen ifow
static int ifcounter = 0; 
static int strCounter = 0; //do stringow
static int helper = 0; //do tablic
string getfloat(Strc arg, int NumberRejestru);
stack<string> etykiety; //stos etykiet do zagniezdzen
%}
%union 
{char *text;
int	ival;
float dval;};

%token LEQ 	GEQ EQ
%token FOR INT FLOAT WHILE ELSEIF
%token PRINTFL,PRINTSTR,PRINTI
%token INPUTIN,INPUTFIN
%token <text> ID // id np. a
%token <ival> LC //liczba calkowita
%token <dval> LD // liczba przecinkowa
%token <text> STRING
%token EQ NE LT GT GE LE //porownanie EQ-rowne, NE-nierowne LT-less than GT-greater than GE/LE = greater/less equal
%token IF ELSE //jezeli
%%
multilinia
	: multilinia linia {;}
	| linia	{;}
	;
linia
	: przypisanie ';' { fprintf(file, "\n");}
	| deklaracja ';' {;}
	| wyswietlanie ';' {;} //elo 
	| pobieranie ';' {;}
	| ifcalosc ';' {;}
	| whilepetla ';' {;}
	;
whilepetla
	: whileetykieta '('warunek ')' '{' multilinia '}'{
		string etk=etykiety.top();
		etykiety.pop();
		string etk2=etykiety.top();
		etykiety.pop();
		code.push_back("b "+etk2);
		code.push_back(etk+ ":");
	}
	;
whileetykieta
	: WHILE {
		string nowaetyketa="ETYKIETA"+to_string(ifcounter);
		ifcounter++;
		etykiety.push(nowaetyketa);
		code.push_back("b "+nowaetyketa);
		code.push_back(nowaetyketa + ":");
	}
	;
ifcalosc
	: ifpoczatek '{' multilinia '}' {
		
		  string etk = etykiety.top();
      code.push_back(etk + ":");
      etykiety.pop();
      ifcounter++;
	} 
	| ifpoczatek '{' multilinia '}' elsemoje '{'multilinia '}' {
			
			string etk = etykiety.top();
      code.push_back(etk + ":");
      etykiety.pop();
      ifcounter++;
	}
	;
elsemoje
	: ELSE{
			string etk = etykiety.top();
			
    	stringstream sstream;
    	sstream<<ifcounter;
    
      //string newetk = "etk" + to_string(ifcounter);
			string newetk = "etk" +sstream.str();
      code.push_back("b " + newetk);
      code.push_back(etk+":");
      etykiety.pop();
      etk = "etk" + to_string(ifcounter);
      etykiety.push(etk);
      ifcounter++;
	}
	;
ifpoczatek
	: IF '('warunek')' {;}
	;
warunek
	: wyr EQ wyr {porownaniewarunku("EQ");}
	| wyr NE wyr {porownaniewarunku("NE");}
	| wyr LT wyr {porownaniewarunku("LT");}
	| wyr GT wyr {porownaniewarunku("GT");}
	| wyr GE wyr {porownaniewarunku("GE");}
	| wyr LE wyr {porownaniewarunku("LE");}
	;
wyswietlanie
	: PRINTI '(' ID ')'{ printintg($3);}
	| PRINTFL '(' ID ')'{ printfloat($3);}
	| PRINTSTR '(' STRING ')' {
		  auto it = symbole.find($3);
      symbol_info sInfo;
      sInfo.type = STRING;
      sInfo.size = 1;
      sInfo.id = "_string" + to_string(strCounter);
      sInfo.value = $3;
      if(it != symbole.end()){
        printString(it->second.id);
      }
      else{
        symbole.insert(std::pair<string,symbol_info>($3, sInfo));
        printString(sInfo.id);
        strCounter++;
  	}
	}
	|PRINTI '(' ID tab_wyr ')' { 
      string tmpname = "tempintprint";
      auto it = symbole.find(tmpname);
      symbol_info symboltmp;
      symboltmp.id = tmpname;
      symboltmp.type = LC;
      symboltmp.size = 1;
      symboltmp.value = "0";
      symbole.insert(std::pair<string,symbol_info>(tmpname,symboltmp));
      Strc arg1 = stk.top();
      stk.pop();
			string asm1;
			if(arg1.token == ID){asm1="lw $t"  + to_string(0) + "," + arg1.val;} 
    	else if (arg1.token == LC) {asm1= "li $t" + to_string(0) + "," + arg1.val;}
			stringstream sstream;
			sstream<<$3;
			string newetk = sstream.str();
      code.push_back("la $t4, "+newetk);
      if(arg1.token == ID) code.push_back("lw $t5, "+ arg1.val);
      else code.push_back("li $t5, "+ arg1.val);
      code.push_back("mul $t5,$t5,4");
      code.push_back("add $t4, $t4, $t5");
      code.push_back("lw $t0, ($t4)");
      code.push_back("sw $t0, " + tmpname);
      printintg(tmpname);
  }
	|PRINTFL '(' ID tab_wyr ')' {
      string tmpname = "tempfloatprint";
      auto it = symbole.find(tmpname);
      symbol_info symboltmp;
      symboltmp.id = tmpname;
      symboltmp.type = LD;
      symboltmp.size = 1;
      symboltmp.value = "0";
      symbole.insert(std::pair<string,symbol_info>(tmpname, symboltmp));
      Strc arg1 = stk.top();
      stk.pop();
      string asm1 ;
			if(arg1.token == ID){asm1="lw $t"  + to_string(0) + "," + arg1.val;} 
    	else if (arg1.token == LC) {asm1= "li $t" + to_string(0) + "," + arg1.val;}
			stringstream sstream;
			sstream<<$3;
			string newetk = sstream.str();
      code.push_back("la $t4, "+ newetk);
      if(arg1.token == ID) code.push_back("lw $t5, "+ arg1.val);
      else code.push_back("li $t5, "+ arg1.val);
      code.push_back("mul $t5,$t5,4");
      code.push_back("add $t4, $t4, $t5");
      code.push_back("l.s $f0, ($t4)");
      code.push_back("s.s $f0, " + tmpname);
      printfloat(tmpname);
  }
	;
deklaracja
	:INT ID{
		
		auto iterator=symbole.find($2);
		if(iterator != symbole.end()) {cout << "taki int juz istnieje\n"; exit(-1);}
		symbol_info symbol;
		symbol.type=LC;
		symbol.size=1;
		symbol.id=$2;
		symbol.value="0";
		symbole.insert(std::pair<string,symbol_info>($2, symbol));

	}
	|FLOAT ID{
		auto iterator=symbole.find($2);
		
		if(iterator != symbole.end()) {cout << "taki float juz istnieje\n"; exit(-1);}
		symbol_info symbol;
		symbol.type=LD;
		symbol.size=1;
		symbol.id=$2;
		symbol.value="0.0";
		symbole.insert(pair<string,symbol_info>($2, symbol));
	}
	  |INT ID '[' LC ']' {
      symbol_info sInfo;
      sInfo.type = ARRINT;
      sInfo.size = $4;
      sInfo.id = $2;
      sInfo.value = "0:"+to_string($4);	//" bo inaczej koloruje wszystko
      symbole.insert(std::pair<string,symbol_info>($2,sInfo));
  ;}
  |FLOAT ID '[' LC ']' {
      symbol_info sInfo;
      sInfo.type = ARRFLOAT;
      sInfo.size = $4;
      sInfo.id = $2;
      sInfo.value = "0:"+to_string($4); //"


      symbole.insert(std::pair<string,symbol_info>($2, sInfo));
  ;}
	;

pobieranie
	: INPUTIN '('ID')' {inputinteger($3);} //readi
	| INPUTFIN '('ID')' {inputfloat($3);} //readf
	;
przypisanie
	:ID '=' wyr {
			Strc result;
			result.val=$1;
			
			result.token=ID;  
			stk.push(result);
			treeMaker('=');
		}
		|ID '[' wyr ']' '=' wyr {
      auto it = symbole.find($1);
      if(it->second.type == ARRINT){ 
					stringstream sstream;
					sstream<<$1;
					string newetk = sstream.str();
          code.push_back("la $t4, " + newetk);
          Strc variable1 = stk.top();
					string asm1;
					string asm2;
          stk.pop();
					if(variable1.token == ID){asm1="lw $t"  + to_string(0) + "," + variable1.val;} 
    			else if (variable1.token == LC) {asm1= "li $t" + to_string(0) + "," + variable1.val;}

          code.push_back(asm1);

          Strc variable2 = stk.top();
          stk.pop();
					if(variable2.token == ID){asm2="lw $t"  + to_string(5) + "," + variable2.val;} 
    			else if (variable2.token == LC) {asm2= "li $t" + to_string(5) + "," + variable2.val;}
          code.push_back(asm2);
          code.push_back("mul $t5, $t5, 4");
          code.push_back("add $t4, $t4, $t5");
          code.push_back("sw $t0, ($t4)");
      }
      else{ 
					stringstream sstream;
					sstream<<$1;
					string newetk = sstream.str();
          code.push_back("la $t4, " + newetk);
					string asm2;
          Strc variable1 = stk.top();
          stk.pop();
          string asm1 = getfloat(variable1,0);
          code.push_back(asm1);

          Strc variable2=stk.top();
          stk.pop();
					if(variable2.token == ID){asm2="lw $t"  + to_string(5) + "," + variable2.val;} 
    			else if (variable2.token == LC) {asm2= "li $t" + to_string(5) + "," + variable2.val;}
          code.push_back(asm2);
          code.push_back("mul $t5, $t5, 4");
          code.push_back("add $t4, $t4, $t5");
          code.push_back("s.s $f0, ($t4)");
            }
  ;}
;
wyr
	:wyr '+' skladnik	{fprintf(file,"+ ");treeMaker('+');}
	|wyr '-' skladnik	{fprintf(file,"- ");treeMaker('-');}
	|skladnik		{;}
	;
tab_wyr
  :'[' wyr ']' {}
;
skladnik
	:skladnik '*' czynnik	{fprintf(file,"* ");treeMaker('*');}
	|skladnik '/' czynnik	{fprintf(file,"/ ");treeMaker('/');}
	|czynnik		{;}
	;
czynnik
	:ID			{strc.val=$1;strc.token=ID;stk.push(strc);} 
	|LC			{strc.val=to_string($1);strc.token=LC;stk.push(strc);}
	|LD			{strc.val=to_string($1);strc.token=LD;stk.push(strc);}
	|'(' wyr ')'		{;}
	|STRING {};
	|ID tab_wyr {
      auto it = symbole.find($1);
      if(it->second.type == ARRINT){
          Strc var1 = stk.top();
          stk.pop();
					stringstream sstream;
					sstream<<$1;
					string newetk = sstream.str();
          code.push_back("la $t4,"+newetk);
          if(var1.token == ID)
              code.push_back("lw $t5, "+var1.val);
          else
              code.push_back("li $t5, "+var1.val);

          code.push_back("mul $t5, $t5, 4");
          code.push_back("add $t4, $t4, $t5");
          code.push_back("lw $t0, ($t4)");
          helper++;
          string temporaryName="_tmp" + to_string(helper);
          symbol_info sInfo;
          sInfo.id = temporaryName;
          sInfo.type = LC;
          sInfo.size = 1;
          sInfo.value = "0";
          symbole.insert(std::pair<string,symbol_info>(temporaryName, sInfo));
					Strc tempstrc;
					tempstrc.val=temporaryName;
					tempstrc.token=ID;
					stk.push(tempstrc);
          code.push_back("sw $t0, " + temporaryName);
      }
      else {
          Strc var1 = stk.top();
          stk.pop();

    			stringstream sstream;
					sstream<<$1;
					string newetk = sstream.str();

          code.push_back("la $t4," + newetk);
          if(var1.token == ID) code.push_back("lw $t5, "+ var1.val);
          else code.push_back("li $t5, " + var1.val);

          code.push_back("mul $t5, $t5, 4");
          code.push_back("add $t4, $t4, $t5");
          code.push_back("l.s $f0, ($t4)");
          licznik++;
          string temporaryName = "_tmp_float"+to_string(licznik);
          symbol_info sInfo;
          sInfo.id = temporaryName;
          sInfo.type = LC;
          sInfo.size = 1;
          sInfo.value = "0";
          symbole.insert(std::pair<string,symbol_info>(temporaryName, sInfo));
					Strc tempstrc;
					tempstrc.val=temporaryName;
					tempstrc.token=ID;
					stk.push(tempstrc);
          code.push_back("s.s $f0, " + temporaryName);
       }
  ;}
	;
%%
int main(int argc, char *argv[])
{

	file=fopen("RPN.txt","w");
	trees=fopen("treesw.txt","w");
	assembler=fopen("asm.txt","w");
	yyparse();

	fprintf(assembler,".data\n");
	for(auto symmain:symbole)
	{
		fprintf(assembler,"\t%s\t:",symmain.second.id.c_str());
		fprintf(assembler,"\t%s",convert(symmain.second.type).c_str());
		fprintf(assembler,"\t%s\n",symmain.second.value.c_str());
	}
	fprintf(assembler,"%s",".text\n");
	for(auto kod:code){
		fprintf(assembler,"%s\n", kod.c_str());
		}
	fclose(file);
	fclose(trees);
	fclose(assembler);
	return 0;
}


string getfloat(Strc arg, int NumberRejestru){ 
    if(arg.token == ID)
        return "l.s $f" + to_string(NumberRejestru) + "," + arg.val; //jak jest przypisany do zmiennej
    symbol_info symbolinfo;
    symbolinfo.id = "_tmp_float" + to_string(licznik); //ladujemy do jakiegos tmp floata, i to tmp do rejestru
    licznik++;
    symbolinfo.type = LD;
    symbolinfo.size = 1;
    symbolinfo.value = arg.val;
    symbole.insert(std::pair<string,symbol_info>(symbolinfo.id, symbolinfo));
    return "l.s $f" + to_string(NumberRejestru) + "," + symbolinfo.id;
}
string convert (int id){
	fprintf(file," id = %d",id);
  if(id == LC || id == ARRINT)
    return ".word";
  else if(id == LD || id == ARRFLOAT)
    return ".float";
  else if (id == STRING)
    return ".asciiz";

  return ".unknown";
}

void porownaniewarunku(string var){
	//cout<<"poczatek warunku"<<endl;
	Strc variable2 = stk.top();
	//cout<<"variable2: "<<variable2.token<<" "<<variable2.val<<endl;
  stk.pop();
  Strc variable1=stk.top();
	//cout<<"variable1: "<<variable1.token<<" "<<variable1.val<<endl;
  stk.pop();
	//cout<<"LD token wynosi: "<<LD<<endl;
  if(variable1.token == LD || variable2.token == LD) {cout << "floaty nie sa do warunku";exit(-1);}
  string asm1, asm2, etykieta;
	if(variable1.token == ID){asm1="lw $t"  + to_string(0) + "," + variable1.val;}
  else if (variable1.token == LC) {asm1= "li $t" + to_string(0) + "," + variable1.val;}

	if(variable2.token == ID){asm2="lw $t"  + to_string(1) + "," + variable2.val;}
  else if (variable2.token == LC) {asm2= "li $t" + to_string(1) + "," + variable2.val;}

  etykieta = "ETYKIETA" + to_string(ifcounter);
  etykiety.push(etykieta);
  code.push_back(asm1);
  code.push_back(asm2);

	string tmp;
	if(var=="EQ") tmp="bne";
	if(var=="NE") tmp="beq";
	if(var=="LT") tmp="bge";
	if(var=="GT") tmp="ble";
	if(var=="LE") tmp="bgt";
	if(var=="GE") tmp="blt";
  code.push_back(tmp+" $t0,$t1, " + etykieta); //do funkcji
  ifcounter++;
}
//do dzialan
string gettypes(Strc arg1, Strc arg2){
	if(arg1.token==LC && arg2.token==LC) //dwa inty
	{
		return "inty";
	}
	else if(arg1.token==LD && arg2.token==LD) //dwa float
	{
		return "doubly";
	}
	else{

		//dwa rozne typy
		return "nie mozna dodawac roznych typow";
		//
		int arg1type;
		int arg2type;
		if(arg1.token==LC) arg1type=0;
		else arg1type=1;

		if(arg2.token==LC) arg2type=0;
		else arg2type=1;

		if(arg1type==0 && arg2type==1) return "intfloat";
		else return "floatint";
	}

}
//wpycham do dobrego rejestru
string addtorejestr(Strc arg, int rejestr){
	if(arg.token==ID ) 
	{
		auto it=symbole.find(arg.val);
		if(it->second.type==LC){
			//cout<<"addtorejestr it->second.type : "<<it->second.type<<endl;
			return "lw $t" + to_string(rejestr)+ ",";
		}
		//sprawdzic w tablicy symboli typ argumentu
		if(it->second.type==LD)return "l.s $f"+to_string(rejestr)+ ",";
	}
	else if(arg.token==LC) 
	{
		return "li $t"+to_string(rejestr)+ ",";

	}
	else if(arg.token==LD){
		return "l.s $f"+to_string(rejestr)+ ",";


	}
}
//usyskuje typ
	int getype(Strc arg){
  if(arg.token == LC || arg.token == LD) //albo int albo float
    return arg.token;
  else if(arg.token == ID){
    auto it = symbole.find(arg.val);
    if(it != symbole.end()) //jak to nie jest koniec mapy
      return it->second.type;
  }
}

void callsyscall(){
  string asm1;
  asm1 = "syscall";
  code.push_back(asm1);
}

//wyswietlanie
void printintg(string name){
	string asm1, asm2;
  asm1 = "li $v0, 1";
  asm2 = "lw $a0, " + name;
  code.push_back(asm1);
  code.push_back(asm2);
  callsyscall();
}
void printfloat(string name){
	string asm1, asm2;
  asm1 = "li $v0, 2";
  asm2 = "lwc1 $f12, " + name;
  code.push_back(asm1);
  code.push_back(asm2);
  callsyscall();
}
void printString(string name){
  string asm1, asm2;
  asm1 = "li $v0, 4"; //
  asm2 = "la $a0, " + name;
  code.push_back(asm1);
  code.push_back(asm2);
  callsyscall();
}

//wczytywanie
void inputinteger(string name){
  string asm1, asm2;
  asm1 = "li $v0, 5"; //4 string 5 to int 6 float
  asm2 = "sw $v0, " + name;
  code.push_back(asm1);
  callsyscall();
  code.push_back(asm2);
}

void inputfloat(string name){
  string asm1, asm2;
  asm1 = "li $v0, 6";
  asm2 = "s.s $f0, " + name;
  code.push_back(asm1);
  callsyscall();
  code.push_back(asm2);
}

void intputer(string name, int number)
{
	string asm1, asm2;
	if(number==0) //0 to int, 1 to float
	{
		asm1 = "li $v0, 5"; //4 string 5 to int 6 float
  	asm2 = "sw $v0, " + name;
	} else
	{
		asm1 = "li $v0, 6";
  	asm2 = "s.s $f0, " + name;
	}
	code.push_back(asm1);
  callsyscall();
  code.push_back(asm2);
}

string makeOP(char sign, int type){
	//dzialania matematyczne
	string line3;
	if(type==0) //int
	{
	if(sign=='+'){
		
		line3 ="add $t0 , $t0 , $t1";
		}
	if(sign=='-'){
		line3 ="sub $t0 , $t0 , $t1";
		}
	if(sign=='*'){
		line3 = "mul $t0 , $t0 , $t1";
		}
	if(sign=='/'){
		line3 ="div $t0 , $t0 , $t1";
		}
		return line3;
	}
	else{ //float
	if(sign=='+'){
		
		line3 ="add.s $f0 , $f0 , $f1";
		}
	if(sign=='-'){
		line3 ="sub.s $f0 , $f0 , $f1";
		}
	if(sign=='*'){
		line3 = "mul.s $f0 , $f0 , $f1";
		}
	if(sign=='/'){
		line3 ="div.s $f0 , $f0 , $f1";
		}
		return line3;
	}
}

//tutaj tworzenie kodu asm
void makeCode(Strc arg1, Strc arg2,char sign, string resultName){
	//zaladowanie do rejestru
	string line1,line2;
	int type1 = getype(arg1);
  int type2 = getype(arg2);
	//string line1=addtorejestr(arg1,0)+arg1.val; //typ 1 zmiennej np li $t0 , 27
	//string line2=addtorejestr(arg2,1)+arg2.val;  //typ2 zmiennej
	string line3; 
	//pobranie typow zmiennych

	if( (type1==LC && type2==LD) ||(type1==LD && type2==LC)){
		printf("nie mozna przypisac zmiennych roznych typow");
		exit(-1);
	}
	//line1=genasmload(arg1,0);//if sign = '=' to generujemy tylko line1 i line4
	if(type1 == LD && type2 == LD){
        line1 = getfloat(arg1,0);
        line2 = getfloat(arg2,1);
    }
    else if(type1 == LC && type2 == LC){

				
				if(arg1.token == ID){line1="lw $t"  + to_string(0) + "," + arg1.val;}
    		else if (arg1.token == LC) {line1= "li $t" + to_string(0) + "," + arg1.val;}

				if(arg2.token == ID){line2="lw $t"  + to_string(1) + "," + arg2.val;}
    		else if (arg2.token == LC) {line2= "li $t" + to_string(1) + "," + arg2.val;}
        
    }


		if(type1==LC && type2==LC)line3=makeOP(sign,0);
		else line3=makeOP(sign,1); //jak jeden i drugi typ to float
			
		string line4;
		if(type1 == LC && type2 == LC) line4 = "sw $t0," + resultName;
    else line4 = "s.s $f0," + resultName; //float
		//string line4="sw $t0, " + resultName ;
		code.push_back(line1);
		code.push_back(line2);
		code.push_back(line3);
		code.push_back(line4);
	}

	//ROBIENIE DRZEWA , TO JEST WAZNEEEEE
void treeMaker(char sign){
		static int counter=0;
		Strc arg2=stk.top();
		stk.pop();
		Strc arg1=stk.top();
		stk.pop();
		int type1 = getype(arg1);
		int type2 = getype(arg2);
		//cout<<"arg1: "<<arg1.token<<" "<<arg1.val<<endl;
		//cout<<"arg2: "<<arg2.token<<" "<<arg2.val<<endl;
		if(sign=='='){ //przypisanie
				string asm1;
				string asm2;

				int type1 = getype(arg1);
				int type2 = getype(arg2);

				if(type1 == LD && type2 == LD ){
					//to do
				asm1 = getfloat(arg1,0);
				//cout<<"asm1 w treeMaker dla float "<<asm1<<endl;
				code.push_back(asm1);
			}
			else if(type1 == LC && type2 == LC ){
					
					if(arg1.token == ID){asm1="lw $t"  + to_string(0) + "," + arg1.val;} //
    			else if (arg1.token == LC) {asm1= "li $t" + to_string(0) + "," + arg1.val;}
					//cout<<"asm1 w treeMaker "<<asm1<<endl;
					code.push_back(asm1);
			}
			else if(type2 == LC && type1 == LD){
					//cout << "Blad przypisania";
					exit(-1);
			}
			//asm2 drugi elementt
			
    	if(type1 == LC && type2 == LC)
      asm2 = "sw $t0," + arg2.val;
    	else
      asm2 = "s.s $f0," + arg2.val; //jak float

			code.push_back(asm2);
			return;

		}
		//todo- operacje matematyczne
		else{ //nie ma =, czyli jest operacja arytmetyczna
		
			
			counter=counter+1;
			string resultname=" res"+to_string(counter);
			Strc result;

			result.val=resultname;
			result.token=ID;
			stk.push(result);

			symbol_info symbol;
			 //potem dorobic, ze co jak jest inny np. l
			if(type1==LC)symbol.type=LC;
			else symbol.type=LD;
			symbol.size=1;
			symbol.id=resultname;
			if(type1==LC) symbol.value="0";
			else symbol.value="0.0";
			symbole.insert(std::pair<string,symbol_info>(resultname, symbol));

			

			makeCode(arg1,arg2,sign,resultname);
		}
	
	}