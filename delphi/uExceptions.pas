unit uExceptions;

interface

uses
  SysUtils, Classes;

type
  // IDR_FEATURE: exception class hierarchy
  EIdrTest = class(Exception);
  EIdrSub = class(EIdrTest);

function ExceptionSmoke: string;
procedure TouchExceptions;

implementation

function MightFail(X: Integer): Integer;
begin
  if X = 0 then
    raise EIdrSub.Create('X cannot be zero');
  Result := 100 div X;
end;

function ExceptionSmoke: string;
var
  X: Integer;
begin
  Result := '';
  for X := -1 to 1 do
  begin
    try
      Result := Result + IntToStr(MightFail(X)) + ';';
    except
      on E: EIdrTest do
        Result := Result + '[' + E.ClassName + ':' + E.Message + '];';
      on E: Exception do
        Result := Result + '[Other:' + E.Message + '];';
    end;
  end;

  // IDR_FEATURE: try/finally
  try
    // no-op
  finally
    Result := Result + 'finally;';
  end;
end;

procedure TouchExceptions;
begin
  ExceptionSmoke;
end;

end.
