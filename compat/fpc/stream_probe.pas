program stream_probe;
{$mode delphi}
{$H+}
{ Original clean-room code. Free Pascal RTL only. }
uses Classes, SysUtils, TypInfo;

type
  TProbeNode = class(TComponent)
  private
    FValue: Integer;
    FOnSignal: TNotifyEvent;
    FPeer: TProbeNode;
  published
    property Value: Integer read FValue write FValue;
    property OnSignal: TNotifyEvent read FOnSignal write FOnSignal;
    property Peer: TProbeNode read FPeer write FPeer;
  end;
  TProbeRoot = class(TComponent)
  private
    FLoadedCount: Integer;
  protected
    procedure Loaded; override;
    procedure GetChildren(Proc: TGetChildProc; Root: TComponent); override;
  public
    property LoadedCount: Integer read FLoadedCount;
  end;

procedure TProbeRoot.Loaded;
begin
  inherited Loaded;
  Inc(FLoadedCount);
end;
{ Only the declared children are eligible for streaming. The base TComponent
  implementation does NOT enumerate owned children by itself. }
procedure TProbeRoot.GetChildren(Proc: TGetChildProc; Root: TComponent);
var I: Integer;
begin
  if Root = Self then
    for I := 0 to ComponentCount - 1 do
      Proc(Components[I]);
end;
procedure Require(Condition: Boolean; const Detail: string);
begin
  if not Condition then begin
    WriteLn(StdErr, 'FAIL: ', Detail);
    Halt(2);
  end;
end;
procedure CheckOwner;
var R: TProbeRoot; N: TProbeNode;
begin
  R := TProbeRoot.Create(nil);
  try
    Require(R.ComponentCount = 0, 'initial owner count');
    N := TProbeNode.Create(R); N.Name := 'OwnedChild';
    Require(N.Owner = R, 'owner link');
    Require(R.FindComponent('OwnedChild') = N, 'name lookup');
    Require(R.ComponentCount = 1, 'count after create');
    N.Free;
    Require(R.ComponentCount = 0, 'count after free');
    Require(R.FindComponent('OwnedChild') = nil, 'name after free');
  finally R.Free; end;
  WriteLn('PASS owner-lifecycle');
end;
procedure CheckRtti;
var P: PPropInfo;
begin
  P := GetPropInfo(TProbeNode.ClassInfo, 'Value');
  Require(P <> nil, 'Value published');
  Require(P^.PropType^.Kind = tkInteger, 'Value kind');
  P := GetPropInfo(TProbeNode.ClassInfo, 'OnSignal');
  Require(P <> nil, 'event published');
  Require(P^.PropType^.Kind = tkMethod, 'event method kind');
  WriteLn('PASS published-rtti');
end;
procedure CheckStream;
var Orig, ReadR: TProbeRoot; N: TProbeNode;
    M: TMemoryStream; C: TComponent;
begin
  Orig := TProbeRoot.Create(nil); M := TMemoryStream.Create; ReadR := nil;
  try
    Orig.Name := 'ProbeRoot'; N := TProbeNode.Create(Orig);
    N.Name := 'Child'; N.Value := 41;
    M.WriteComponent(Orig);
    Require(M.Size > 0, 'nonempty stream');
    M.Position := 0; C := M.ReadComponent(nil);
    Require(C is TProbeRoot, 'decoded root class');
    ReadR := TProbeRoot(C);
    Require(ReadR.Name = 'ProbeRoot', 'decoded root name');
    C := ReadR.FindComponent('Child');
    Require(C is TProbeNode, 'decoded child class');
    N := TProbeNode(C);
    Require(N.Owner = ReadR, 'decoded owner');
    Require(N.Value = 41, 'decoded value');
    Require(ReadR.LoadedCount = 1, 'Loaded callback must occur once after streaming');
    WriteLn('PASS component-stream-roundtrip');
    WriteLn('TRACE loaded-count=', ReadR.LoadedCount);
  finally ReadR.Free; Orig.Free; M.Free; end;
end;
procedure CheckForwardReference;
var Orig, ReadR: TProbeRoot;
    Earlier, Later, ReadEarlier, ReadLater: TProbeNode;
    M: TMemoryStream; C: TComponent;
begin
  Orig := TProbeRoot.Create(nil); M := TMemoryStream.Create;
  ReadR := nil;
  try
    Orig.Name := 'ForwardRoot';
    Earlier := TProbeNode.Create(Orig);
    Earlier.Name := 'Earlier';
    Later := TProbeNode.Create(Orig);
    Later.Name := 'Later'; Later.Value := 73;
    Earlier.Peer := Later;
    Require(Orig.Components[0] = Earlier, 'earlier child is streamed first');
    M.WriteComponent(Orig);
    Require(M.Size > 0, 'forward-reference stream nonempty');
    M.Position := 0;
    C := M.ReadComponent(nil);
    Require(C is TProbeRoot, 'forward-reference root class');
    ReadR := TProbeRoot(C);
    C := ReadR.FindComponent('Earlier');
    Require(C is TProbeNode, 'forward-reference earlier decoded');
    ReadEarlier := TProbeNode(C);
    C := ReadR.FindComponent('Later');
    Require(C is TProbeNode, 'forward-reference later decoded');
    ReadLater := TProbeNode(C);
    Require(ReadLater.Value = 73, 'forward-reference target value');
    Require(ReadEarlier.Peer = ReadLater, 'forward-reference property fixed up');
    Require(ReadR.LoadedCount = 1, 'forward-reference root Loaded exactly once');
    WriteLn('PASS forward-reference-fixup');
  finally
    ReadR.Free; Orig.Free; M.Free;
  end;
end;
procedure CheckUnknownProperty;
var T: TStringStream; M: TMemoryStream;
    C: TComponent; Rejected: Boolean;
begin
  T := TStringStream.Create('object UnknownPropertyRoot: TProbeRoot' +
    LineEnding + '  NotPublishedHere = 7' + LineEnding +
    'end' + LineEnding);
  M := TMemoryStream.Create;
  try
    ObjectTextToBinary(T, M); M.Position := 0;
    Rejected := False; C := nil;
    try C := M.ReadComponent(nil);
    except on E: Exception do Rejected := True; end;
    C.Free;
    Require(Rejected, 'unknown published property must fail');
  finally M.Free; T.Free; end;
  WriteLn('PASS unknown-property-negative');
end;
procedure CheckUnknownClass;
var T: TStringStream; M: TMemoryStream;
    C: TComponent; Rejected: Boolean;
begin
  T := TStringStream.Create('object Ghost: TProbeMissingClass' +
    LineEnding + 'end' + LineEnding);
  M := TMemoryStream.Create;
  try
    ObjectTextToBinary(T, M); M.Position := 0;
    Rejected := False; C := nil;
    try C := M.ReadComponent(nil);
    except on E: Exception do Rejected := True; end;
    C.Free;
    Require(Rejected, 'unregistered class must fail');
  finally M.Free; T.Free; end;
  WriteLn('PASS unknown-class-negative');
end;
begin
  RegisterClass(TProbeRoot); RegisterClass(TProbeNode);
  CheckOwner; CheckRtti; CheckStream; CheckForwardReference; CheckUnknownProperty; CheckUnknownClass;
  WriteLn('PASS 6/6 FPC clean-room behavioral probes (NOT Delphi VCL parity)');
end.
