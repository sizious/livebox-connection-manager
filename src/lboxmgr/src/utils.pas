unit utils;

interface

uses
  Windows, SysUtils;

procedure ConsolePrint(const S: string); overload;
procedure ConsolePrint(const S: string; LineBreak: Boolean); overload;
function ExtractStr(LSubStr, RSubStr, S: string): string;
function IsInString(const SubStr, S: string): Boolean; overload;
function IsInString(SubStrs: array of string; const S: string): Boolean; overload;
function StringToOem(const S: string): string;

implementation

// Merci Michel (Phidels.com) pour ces fonctions

function Droite(substr: string; s: string): string;
begin
  if pos(substr,s)=0 then result:='' else
    result:=copy(s, pos(substr, s)+length(substr), length(s)-pos(substr, s)+length(substr));
end;

function Gauche(substr: string; s: string): string;
begin
  result:=copy(s, 1, pos(substr, s)-1);
end;

function ExtractStr(LSubStr, RSubStr, S: string): string;
begin
  Result := Gauche(RSubStr, Droite(LSubStr, S));
end;

// Merci HRS pour cette fonction
// http://hrs.developpez.com/contrib.html#console32

function StringToOem(const S: string): string;
var
  Buf: array[0..1023] of Char;

begin
  CharToOem(PChar(s), @Buf);
  Result := StrPas(@Buf);
end;

function IsInString(const SubStr, S: string): Boolean; overload;
begin
  Result := Pos(LowerCase(SubStr), LowerCase(S)) > 0;
end;

procedure ConsolePrint(const S: string; LineBreak: Boolean); overload;
begin
  if LineBreak then  
    WriteLn(StringToOem(S))
  else
    Write(StringToOem(S));
end;

procedure ConsolePrint(const S: string); overload;
begin
  ConsolePrint(S, True);
end;

function IsInString(SubStrs: array of string; const S: string): Boolean; overload;
var
  i: Integer;

begin
  i := Low(SubStrs);
  repeat
    Result := IsInString(SubStrs[i], S);
    Inc(i);
  until Result or (i > High(SubStrs));
end;

end.
