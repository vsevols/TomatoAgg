unit taGlobals;

interface

const
  SECONDSINMINUTE = 60;
  SECONDSINHOUR = 60 * SECONDSINMINUTE;
  OUTPUTTIMEZONE_UTCDELTA_HRS = +3;
  TOMATODURATION = 30 * SECONDSINMINUTE;

function DataPath(ARelativePath: string): string;

procedure NotSupported(const AValue: Variant; const AName: string = '');

implementation

uses
  System.SysUtils;
function DataPath(ARelativePath: string): string;
begin
  Result := ExtractFilePath(ParamStr(0)) + 'Data\' + ARelativePath;
end;

procedure NotSupported(const AValue: Variant; const AName: string = '');
begin
  raise Exception.CreateFmt('Not supported: %s = %s', [AName, AValue.ToString]);
end;

end.
