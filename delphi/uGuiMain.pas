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
  private
    procedure Log(const S: string);
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

procedure TfrmMain.btnRunClick(Sender: TObject);
begin
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
end;

end.
