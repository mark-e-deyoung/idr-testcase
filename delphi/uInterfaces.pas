unit uInterfaces;

interface

uses
  Windows, SysUtils, Classes;

const
  // IDR_FEATURE: interface GUIDs (explicit constants for Delphi 7)
  IID_IGreeter: TGUID = '{7D35B9AA-7B42-4E2E-9B58-1A9DB7E6D3A1}';
  IID_ICounter: TGUID = '{B3F8D2F4-1A07-4F1B-9F4A-6FBBE1D33C2B}';

type
  // IDR_FEATURE: interfaces w/ GUIDs
  IGreeter = interface(IUnknown)
    ['{7D35B9AA-7B42-4E2E-9B58-1A9DB7E6D3A1}']
    function Hello(const Name: WideString): WideString;
    function Add(A, B: Integer): Integer;
  end;

  ICounter = interface(IUnknown)
    ['{B3F8D2F4-1A07-4F1B-9F4A-6FBBE1D33C2B}']
    procedure Inc; // intentionally named 'Inc' (tests name collisions vs System.Inc)
    function Value: Integer;
  end;

  // TInterfacedObject => refcounting path for IDR
  TGreeter = class(TInterfacedObject, IGreeter, ICounter)
  private
    FCount: Integer;
  public
    function Hello(const Name: WideString): WideString;
    function Add(A, B: Integer): Integer;

    procedure Inc;
    function Value: Integer;
  end;

function InterfaceSmoke: string;
procedure TouchInterfaces;

implementation

function TGreeter.Add(A, B: Integer): Integer;
begin
  Result := A + B;
end;

function TGreeter.Hello(const Name: WideString): WideString;
begin
  Result := 'Hello, ' + Name;
end;

procedure TGreeter.Inc;
begin
  // IDR_FEATURE: name collision / qualification (method Inc vs System.Inc)
  System.Inc(FCount);
end;

function TGreeter.Value: Integer;
begin
  Result := FCount;
end;

function InterfaceSmoke: string;
var
  G: IGreeter;
  C: ICounter;
begin
  // IDR_FEATURE: interface construction + vtable dispatch
  G := TGreeter.Create;
  Result := string(G.Hello('IDR')) + ';' + IntToStr(G.Add(1, 2)) + ';';

  // IDR_FEATURE: QueryInterface (Delphi 7-safe; avoids Supports overload differences)
  if G.QueryInterface(IID_ICounter, C) = S_OK then
  begin
    C.Inc;
    C.Inc;
    Result := Result + IntToStr(C.Value) + ';';
  end
  else
    Result := Result + 'no-counter;';
end;

procedure TouchInterfaces;
begin
  InterfaceSmoke;
end;

end.
