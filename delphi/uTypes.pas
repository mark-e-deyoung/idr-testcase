unit uTypes;

interface

uses
  Windows, SysUtils, Classes, Variants;

type
  // IDR_FEATURE: enums/sets/subranges
  TColorCode = (ccRed, ccGreen, ccBlue, ccUnknown);
  TColorSet = set of TColorCode;
  TSmallIntRange = -10..10;

  // IDR_FEATURE: packed record + variant record (layout recovery)
  TPackedHeader = packed record
    Magic: Word;
    Version: Byte;
    Flags: Byte;
  end;

  TVariantPayload = record
    Tag: Byte;
    case Integer of
      0: (AsInt: Integer);
      1: (AsPtr: Pointer);
      2: (AsDouble: Double);
  end;

  // IDR_FEATURE: strings + dyn arrays inside a record
  TComplexRecord = record
    Name: AnsiString;
    Count: Integer;
    Values: array of Integer;
    Header: TPackedHeader;
    Payload: TVariantPayload;
  end;

function MakeComplex(const AName: AnsiString; N: Integer): TComplexRecord;
function FormatComplexTypesSummary: string;

procedure TouchTypes;

implementation

function MakeComplex(const AName: AnsiString; N: Integer): TComplexRecord;
var
  I: Integer;
begin
  Result.Name := AName;
  Result.Count := N;
  SetLength(Result.Values, N);
  for I := 0 to N - 1 do
    Result.Values[I] := (I * I) - (3 * I);

  Result.Header.Magic := $D711;
  Result.Header.Version := 7;
  Result.Header.Flags := $A5;

  Result.Payload.Tag := 2;
  Result.Payload.AsDouble := 3.1415926535;
end;

function ColorSetToStr(CS: TColorSet): string;
begin
  Result := '';
  if ccRed in CS then Result := Result + 'R';
  if ccGreen in CS then Result := Result + 'G';
  if ccBlue in CS then Result := Result + 'B';
  if Result = '' then Result := '-';
end;

function FormatComplexTypesSummary: string;
var
  R: TComplexRecord;
  CS: TColorSet;
  V: Variant;
  SR: TSmallIntRange;
begin
  // IDR_FEATURE: Variant array + record fields
  R := MakeComplex('demo', 5);
  CS := [ccRed, ccBlue];
  V := VarArrayOf([R.Count, R.Header.Magic, R.Payload.AsDouble, R.Name]);
  SR := 3;

  Result := Format('Rec{Name=%s;Count=%d;CS=%s;SR=%d;V0=%s}',
    [string(R.Name), R.Count, ColorSetToStr(CS), Integer(SR), VarToStr(V[0])]);
end;

procedure TouchTypes;
var
  R: TComplexRecord;
begin
  R := MakeComplex('touch', 3);
  if R.Header.Magic = 0 then
    Writeln('unreachable');
end;

end.
