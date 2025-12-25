library IdrTestDll;

{$D+}{$L+}{$Y+}{$H+}
{$R IdrTestDll.res} // built by build.sh via brcc32

uses
  Windows,
  SysUtils,
  Classes,
  uIdrMarkers in 'uIdrMarkers.pas',
  uCommon in 'uCommon.pas',
  uTypes in 'uTypes.pas',
  uOO in 'uOO.pas',
  uInterfaces in 'uInterfaces.pas',
  uExceptions in 'uExceptions.pas';

function IdrTestcase_Version: PAnsiChar; stdcall;
begin
  Result := 'idr-testcase/1.1 (Delphi7)';
end;

// IDR_FEATURE: exports/stdcall (named exports + stdcall)
function IdrTestcase_RunAll(out ResultCode: Integer): Integer; stdcall;
begin
  try
    uCommon.TouchAll;
    uTypes.TouchTypes;
    uOO.TouchOO;
    uInterfaces.TouchInterfaces;
    uExceptions.TouchExceptions;
    ResultCode := 0;
    Result := 1;
  except
    on E: Exception do
    begin
      ResultCode := -1;
      Result := 0;
    end;
  end;
end;

exports
  IdrTestcase_Version name 'IdrTestcase_Version',
  IdrTestcase_RunAll name 'IdrTestcase_RunAll';

begin
end.
