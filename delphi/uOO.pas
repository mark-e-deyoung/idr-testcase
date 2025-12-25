unit uOO;

interface

uses
  Windows, Messages, SysUtils, Classes;

type
  // IDR_FEATURE: published RTTI (class RTTI generation)
  {$M+}
  TBase = class(TComponent)
  private
    FName: string;
    FOnProgress: TNotifyEvent;
  protected
    procedure DoProgress;
  public
    constructor Create(AOwner: TComponent); override;
    function VirtualCalc(X: Integer): Integer; virtual;
    function DynamicCalc(X: Integer): Integer; dynamic;

    // IDR_FEATURE: message method / dispatch table
    procedure WmUser(var Msg: TMessage); message WM_USER + 101;

    property NameField: string read FName write FName;
  published
    // IDR_FEATURE: published event type
    property OnProgress: TNotifyEvent read FOnProgress write FOnProgress;
  end;

  TDerived = class(TBase)
  private
    FValue: Integer;
  public
    // IDR_FEATURE: override virtual
    function VirtualCalc(X: Integer): Integer; override;
    // IDR_FEATURE: dynamic method in derived class (note: will warn about hiding)
    function DynamicCalc(X: Integer): Integer; dynamic;

    property Value: Integer read FValue write FValue;
  published
    // IDR_FEATURE: published property (RTTI)
    property PublishedValue: Integer read FValue write FValue;
  end;
  {$M-}

  // IDR_FEATURE: threads
  TWorkerThread = class(TThread)
  private
    FSum: Integer;
  protected
    procedure Execute; override;
  public
    property Sum: Integer read FSum;
  end;

function BuildOOReport: string;
procedure TouchOO;

implementation

constructor TBase.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FName := ClassName;
end;

procedure TBase.DoProgress;
begin
  if Assigned(FOnProgress) then
    FOnProgress(Self);
end;

function TBase.VirtualCalc(X: Integer): Integer;
begin
  Result := X * 2 + 1;
end;

function TBase.DynamicCalc(X: Integer): Integer;
begin
  Result := X * 3 + 2;
end;

procedure TBase.WmUser(var Msg: TMessage);
begin
  Msg.Result := VirtualCalc(Msg.WParam) + DynamicCalc(Msg.LParam);
end;

function TDerived.VirtualCalc(X: Integer): Integer;
begin
  Result := inherited VirtualCalc(X) + 10;
end;

function TDerived.DynamicCalc(X: Integer): Integer;
begin
  Result := inherited DynamicCalc(X) + 20;
end;

procedure TWorkerThread.Execute;
var
  I: Integer;
begin
  FSum := 0;
  for I := 1 to 100 do
    Inc(FSum, I);
end;

function BuildOOReport: string;
var
  B: TBase;
  D: TDerived;
  M: TMessage;
  T: TWorkerThread;
begin
  B := TBase.Create(nil);
  D := TDerived.Create(nil);
  try
    D.Value := 7;

    // IDR_FEATURE: virtual + dynamic dispatch (VMT + dispatch table)
    Result := Format('%s:%d,%d; %s:%d,%d;',
      [B.ClassName, B.VirtualCalc(1), B.DynamicCalc(1),
       D.ClassName, D.VirtualCalc(1), D.DynamicCalc(1)]);

    // IDR_FEATURE: message dispatch
    M.Msg := WM_USER + 101;
    M.WParam := 2;
    M.LParam := 3;
    M.Result := 0;
    B.Dispatch(M);
    Result := Result + 'msg=' + IntToStr(M.Result) + ';';

    // IDR_FEATURE: thread symbol + Execute loop
    T := TWorkerThread.Create(True);
    try
      T.Resume;   // Delphi 7-era API
      T.WaitFor;
      Result := Result + 'sum=' + IntToStr(T.Sum) + ';';
    finally
      T.Free;
    end;
  finally
    D.Free;
    B.Free;
  end;
end;

procedure TouchOO;
begin
  BuildOOReport;
end;

initialization
  // IDR_FEATURE: initialization section
finalization
  // IDR_FEATURE: finalization section
end.
