unit uCommon;

interface

uses
  Windows, SysUtils, Classes;

type
  // IDR_FEATURE: strings / encodings
  TAnsi32 = AnsiString;
  TWide = WideString;
  TShort = ShortString;

function Hash32(const S: TAnsi32): Cardinal;
function RotL32(Value: Cardinal; Bits: Byte): Cardinal;

procedure TouchAll;

implementation

function RotL32(Value: Cardinal; Bits: Byte): Cardinal;
begin
  Result := (Value shl Bits) or (Value shr (32 - Bits));
end;

function Hash32(const S: TAnsi32): Cardinal;
var
  I: Integer;
  H: Cardinal;
begin
  // Simple, deterministic, non-cryptographic hash.
  H := $811C9DC5; // FNV-ish
  for I := 1 to Length(S) do
  begin
    H := H xor Ord(S[I]);
    H := H * 16777619;
    H := RotL32(H, 5);
  end;
  Result := H;
end;

procedure TouchAll;
var
  ws: TWide;
  a: TAnsi32;
  ss: TShort;
  p: PChar;
  pw: PWideChar;
begin
  // IDR_FEATURE: string conversions / PChar / PWideChar
  a := 'ansi';
  ws := TWide('wide');
  ss := 'short';
  p := PChar(a);
  pw := PWideChar(ws);

  // Reference variables so compiler emits relevant helper calls.
  if (Length(a) + Length(ws) + Length(ss) + Ord(p[0]) + Ord(pw[0])) = 0 then
    RaiseLastOSError;
end;

end.
