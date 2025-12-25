program IdrTestGui;

{$D+}{$L+}{$Y+}{$H+}
{$R IdrTestGui.res} // built by build.sh via brcc32

uses
  Forms,
  uGuiMain in 'uGuiMain.pas' {frmMain},
  uIdrMarkers in 'uIdrMarkers.pas',
  uCommon in 'uCommon.pas',
  uTypes in 'uTypes.pas',
  uOO in 'uOO.pas',
  uInterfaces in 'uInterfaces.pas',
  uExceptions in 'uExceptions.pas';

begin
  Application.Initialize;
  Application.Title := 'IDR Testcase';
  Application.CreateForm(TfrmMain, frmMain);
  Application.Run;
end.
