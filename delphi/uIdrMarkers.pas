unit uIdrMarkers;

interface

uses
  SysUtils;

type
  TMarkerSink = procedure(const S: string) of object;
procedure SetMarkerSink(Sink: TMarkerSink);
procedure Mark(const Feature, Detail: string);
function MarkLine(const Feature, Detail: string): string;

implementation

var
  GSink: TMarkerSink = nil;

procedure SetMarkerSink(Sink: TMarkerSink);
begin
  GSink := Sink;
end;

function MarkLine(const Feature, Detail: string): string;
begin
  // Standardized prefix for log parsing / diffing.
  Result := Format('[IDR_FEATURE:%s] %s', [Feature, Detail]);
end;

procedure Mark(const Feature, Detail: string);
var
  L: string;
begin
  L := MarkLine(Feature, Detail);
  if Assigned(GSink) then
    GSink(L)
  else
    Writeln(L);
end;

end.
