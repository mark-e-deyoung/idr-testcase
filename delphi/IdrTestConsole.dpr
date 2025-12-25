program IdrTestConsole;

{$APPTYPE CONSOLE}
{$D+}{$L+}{$Y+}{$H+}
{$R IdrTestConsole.res} // built by build.sh via brcc32

uses
  SysUtils,
  Windows,
  Classes,
  uIdrMarkers in 'uIdrMarkers.pas',
  uCommon in 'uCommon.pas',
  uTypes in 'uTypes.pas',
  uOO in 'uOO.pas',
  uInterfaces in 'uInterfaces.pas',
  uExceptions in 'uExceptions.pas';

procedure Banner;
begin
  Writeln('IDR Delphi 7 testcase (console)');
  Writeln('This program prints feature markers; do not rely on values beyond smoke testing.');
end;

begin
  try
    Banner;

    Mark('resources', 'linked .res (stringtable) included via {$R IdrTestConsole.res}');
    Mark('units', 'touch all units so symbols appear');

    uCommon.TouchAll;
    uTypes.TouchTypes;
    uOO.TouchOO;
    uInterfaces.TouchInterfaces;
    uExceptions.TouchExceptions;

    Mark('strings', 'uCommon.Hash32 + string conversions');
    Writeln(uCommon.Hash32('hello'));

    Mark('types', 'uTypes.FormatComplexTypesSummary (records, sets, variants)');
    Writeln(uTypes.FormatComplexTypesSummary);

    Mark('oop', 'uOO.BuildOOReport (VMT, virtual/dynamic, message dispatch, thread)');
    Writeln(uOO.BuildOOReport);

    Mark('interfaces', 'uInterfaces.InterfaceSmoke (GUIDs, QueryInterface, refcount)');
    Writeln(uInterfaces.InterfaceSmoke);

    Mark('exceptions', 'uExceptions.ExceptionSmoke (try/except/finally, custom exceptions)');
    Writeln(uExceptions.ExceptionSmoke);

    Mark('done', 'console testcase completed');
  except
    on E: Exception do
    begin
      Writeln('[IDR_FEATURE:unhandled] ', E.ClassName, ': ', E.Message);
      Halt(1);
    end;
  end;
end.
