unit Controller;

interface

uses
  taTypes, taCsv, System.Classes;

type
  TTomatoAggController = class(TObject)
  strict private
    FCsv: TTaCsv;
    //FExcel: TTaExcel;
    FFilterTag: string;
    FLastCorrectionDateTime: TDatetime;
    FLastTomatoDateTime: TDatetime;
    procedure SerializeBegin(AStrings: TStringList; APath: string);
    procedure SerializeEnd(AStrings: TStringList; APath: string; ASave: Boolean);
    procedure SerializeSettingsValue(AStrings: TStringList; AIdx: Integer; ASave:
        Boolean; var AValue: TDatetime); overload;
    procedure SerializeSettingsValue(AStrings: TStringList; AIdx: Integer; ASave:
        Boolean; var AValue: string); overload;
  public
    constructor Create;
    destructor Destroy; override;
    function GetLastPeriodsStr: string;
    procedure Process(ACsvInput: Boolean);
    procedure SerializeSettings(APath: string; ASave: Boolean);
  published
  end;

implementation

uses
  System.SysUtils, taGlobals;

constructor TTomatoAggController.Create;
begin
  inherited Create;
  FCsv := TTaCsv.Create();
end;

destructor TTomatoAggController.Destroy;
begin
  FreeAndNil(FCsv);
  inherited Destroy;
end;

function TTomatoAggController.GetLastPeriodsStr: string;
const
  SYyMmddHhNn = 'yy-mmdd hh:nn';
begin
  Result := Format('%s / %s',
    [FormatDateTime(SYyMmddHhNn, FLastTomatoDateTime),
      FormatDateTime(SYyMmddHhNn, FLastCorrectionDateTime)]);
end;

procedure TTomatoAggController.Process(ACsvInput: Boolean);
var
  LTomatoes: TTimePeriodList;
  LCorrections: TTimePeriodList;
  LCsvCorrections: TTaCsv;
  LCsvOutput: TTaCsv;
begin
  LTomatoes := TTimePeriodList.Create;
  LCorrections := TTimePeriodList.Create;
  try
    //FExcel.InitExcelBook(DataPath('Data.xlsx'), DataPath('Template.xlsx'));
    if not ACsvInput then
    begin
      //FExcel.GetTomatoes(LTomatoes);
      NotSupported(ACsvInput, 'ACsvInput');
    end
      else
      begin
        FCsv.Open(DataPath('tomato.es.csv'), False);
        FCsv.GetTomatoes(LTomatoes, FLastTomatoDateTime);
      end;

    LCsvCorrections := TTaCsv.Create;
    LCsvCorrections.Delimiter := STab;
    LCsvCorrections.Open(DataPath('Corrections.csv'), False);
    try
      LCsvCorrections.GetCorrections(LCorrections, FLastCorrectionDateTime);
    finally
      FreeAndNil(LCsvCorrections);
    end;

    LTomatoes.FilterByTag(FFilterTag, True);
    LTomatoes.ApplyCorrections(LCorrections);
    LTomatoes.MergeSequences;
    LTomatoes.TimeShift(OUTPUTTIMEZONE_UTCDELTA_HRS * SECONDSINHOUR);
    LTomatoes.JustifyMidnight;
    LTomatoes.Check;
    //FExcel.PrintPeriods(LTomatoes);
    LCsvOutput := TTaCsv.Create;
    try
      LCsvOutput.Open(DataPath('output.csv'), True); 
      LCsvOutput.PrintPeriods(LTomatoes);
    finally
      FreeAndNil(LCsvOutput);
    end;
  finally
    FreeAndNil(LCorrections);
    FreeAndNil(LTomatoes);
  end;
end;

procedure TTomatoAggController.SerializeBegin(AStrings: TStringList; APath:
    string);
begin
  if FileExists(APath) then
    AStrings.LoadFromFile(APath);
end;

procedure TTomatoAggController.SerializeEnd(AStrings: TStringList; APath:
    string; ASave: Boolean);
begin
  if ASave then
    AStrings.SaveToFile(APath);
end;

procedure TTomatoAggController.SerializeSettings(APath: string; ASave: Boolean);
var
  LStrings: TStringList;
begin
  LStrings := TStringList.Create;
  try
    SerializeBegin(LStrings, APath);
    SerializeSettingsValue(LStrings, 0, ASave, FLastTomatoDateTime);
    SerializeSettingsValue(LStrings, 1, ASave, FLastCorrectionDateTime);
    SerializeSettingsValue(LStrings, 2, ASave, FFilterTag);
    SerializeEnd(LStrings, APath, ASave);
  finally
    FreeAndNil(LStrings);
  end;
end;

procedure TTomatoAggController.SerializeSettingsValue(AStrings: TStringList;
    AIdx: Integer; ASave: Boolean; var AValue: TDatetime);
var
  LString: string;
begin
  LString := FloatToStr(AValue);
  SerializeSettingsValue(AStrings, AIdx, ASave, LString);
  if not ASave then
    AValue := StrToFloatDef(LString, 0);
end;

procedure TTomatoAggController.SerializeSettingsValue(AStrings: TStringList;
    AIdx: Integer; ASave: Boolean; var AValue: string);
begin
  if ASave then
  begin
    while AIdx > AStrings.Count - 1 do
      AStrings.Add('');
    AStrings[AIdx] := AValue;
  end
  else
    begin
      AValue := '';
      if AIdx < AStrings.Count then
        AValue := AStrings[AIdx];
    end;
end;

end.
