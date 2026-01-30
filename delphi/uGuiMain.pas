unit uGuiMain;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls;

type
  TfrmMain = class(TForm)
    btnRun: TButton;
    Memo1: TMemo;
    lblHint: TLabel;
    procedure btnRunClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
  private
    procedure Log(const S: string);
    procedure RunSmoke;
  public
  end;

var
  frmMain: TfrmMain;

implementation

{$R *.dfm}

uses
  uIdrMarkers,
  uCommon, uTypes, uOO, uInterfaces, uExceptions;

procedure TfrmMain.Log(const S: string);
begin
  Memo1.Lines.Add(S);
end;

procedure TfrmMain.RunSmoke;
var
  F: TextFile;
begin
  try
    // IDR_FEATURE: resources/dfm (DFM + event handler hookup)
    SetMarkerSink(Log);

    Mark('resources/dfm', 'DFM resource loaded, OnClick handler executes');
    Mark('units', 'TouchAll');
    uCommon.TouchAll;

    Mark('strings', 'Hash32("gui")');
    Log(IntToStr(uCommon.Hash32('gui')));

    Mark('types', 'FormatComplexTypesSummary');
    Log(uTypes.FormatComplexTypesSummary);

    Mark('oop', 'BuildOOReport');
    Log(uOO.BuildOOReport);

    Mark('interfaces', 'InterfaceSmoke');
    Log(uInterfaces.InterfaceSmoke);

    Mark('exceptions', 'ExceptionSmoke');
    Log(uExceptions.ExceptionSmoke);

    Mark('done', 'GUI smoke done');

    // Interaction automated: create a file
    AssignFile(F, ExtractFilePath(ParamStr(0)) + 'idr_test_artifact.txt');
    Rewrite(F);
    Writeln(F, 'Automated interaction successful.');
    CloseFile(F);
  except
    // Suppress all exceptions during automation to avoid modal dialogs hanging the test
  end;
end;

procedure TfrmMain.btnRunClick(Sender: TObject);
begin
  RunSmoke;
end;

procedure TfrmMain.FormCreate(Sender: TObject);
begin
  if FindCmdLineSwitch('automate', ['/', '-'], True) then
  begin
    RunSmoke;
    Halt(0);
  end;
end;

end.
