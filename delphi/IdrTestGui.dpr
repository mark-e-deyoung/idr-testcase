program IdrTestGui;

{$D+}{$L+}{$Y+}{$H+}
{$R IdrTestGui.res} // built by build.sh via brcc32

uses
  Forms,
  SysUtils, // Added for Exception handling
  uGuiMain in 'uGuiMain.pas' {frmMain},
  uIdrMarkers in 'uIdrMarkers.pas',
  uCommon in 'uCommon.pas',
  uTypes in 'uTypes.pas',
  uOO in 'uOO.pas',
  uInterfaces in 'uInterfaces.pas',
  uExceptions in 'uExceptions.pas';

begin
  try
    Application.Initialize;
    Application.Title := 'IDR Testcase';
    Application.CreateForm(TfrmMain, frmMain);
    Application.Run;
  except
    on E: Exception do
    begin
      // Safe logging to file
      try
        AssignFile(Output, 'startup_error.log');
        Rewrite(Output);
        Writeln(Output, 'Startup Error: ' + E.ClassName + ' - ' + E.Message);
        CloseFile(Output);
      except
      end;
      Halt(1);
    end;
  end;
end.