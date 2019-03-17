unit taCsv;

interface

uses
  taTypes, System.Classes, Data.DB;

const
  SComma = ',';
  STab = ''#9;

type
  TTaCsv = class(TObject)
  strict private
    FLine: TStringList;
    FLineIdx: Integer;
    FReader: TStreamReader;
    FWriter: TStreamWriter;
    procedure Close;
    procedure CommitLine;
    function Eof: Boolean;
    function FieldValue(AColumnIdx: Integer): string;
    function ParseDateTime(const AValue: string): TDateTime;
    function ReplaceDelimiter(const AString: string; const ANew, AOld: Char):
        string;
    procedure SetFieldValue(AColumnIdx: Integer; AValue: string); overload;
    procedure SetFieldValue(AColumnIdx: Integer; AValue: TDateTime); overload;
  private
    FDelimiter: Char;
  public
    constructor Create;
    destructor Destroy; override;
    procedure GetCorrections(ACorrections: TTimePeriodList; var ALastStart:
        TDatetime);
    procedure GetTomatoes(ATomatoes: TTimePeriodList; var ALastStart: TDatetime);
    function Next: Boolean;
    procedure Open(const APath: string; AWrite: Boolean; AAppend: Boolean = False);
    procedure PrintPeriods(APeriods: TTimePeriodList);
    function TomatoDateToDateTime(AValue: string): TDateTime;
    property Delimiter: Char read FDelimiter write FDelimiter;
  end;

implementation

uses
  taGlobals, System.Variants, System.SysUtils, System.DateUtils,
  System.RegularExpressions;

const
  SFmt_ddmmyyyyhhnn = '%s.%s.%s %s:%s';

constructor TTaCsv.Create;
begin
  inherited Create;
  FLine := TStringList.Create();
  FDelimiter := SComma;
end;

destructor TTaCsv.Destroy;
begin
  FreeAndNil(FLine);
  Close;
  inherited;
end;

procedure TTaCsv.Close;
begin
  if Assigned(FReader) then
    FreeAndNil(FReader);
  if Assigned(FWriter) then
    FreeAndNil(FWriter);
end;

procedure TTaCsv.CommitLine;
begin
  FWriter.Write(FLine.CommaText);
  FWriter.WriteLine;
end;

function TTaCsv.Eof: Boolean;
begin
  Result := FReader.EndOfStream;
end;

function TTaCsv.FieldValue(AColumnIdx: Integer): string;
begin
  Result := '';
  if AColumnIdx >= FLine.Count then
    Exit;
  Result := FLine.Strings[AColumnIdx];
end;

procedure TTaCsv.GetCorrections(ACorrections: TTimePeriodList; var ALastStart:
    TDatetime);
const
  COLIDX_DATE = 0;
  COLIDX_MINUTES = 1;
  COLIDX_TAGS = 2;
begin
  ACorrections.Clear;
  try
    while not Eof do
    begin
      ACorrections.Add(
        TTimePeriod.Create(
          ParseDateTime(FieldValue(COLIDX_DATE)),
          StrToInt(FieldValue(COLIDX_MINUTES)) * SECONDSINMINUTE,
          FieldValue(COLIDX_TAGS)
            )
          );
      Next;
    end;
  except on e:Exception do
    begin
      e.RaiseOuterException(
        Exception.CreateFmt('%s LRow = %d', [e.Message, FLineIdx])
        );
    end;
  end;

  ACorrections.ClearUntil(ALastStart);

  if ACorrections.Count > 0 then
    ALastStart := ACorrections.Last.Start;
end;

procedure TTaCsv.GetTomatoes(ATomatoes: TTimePeriodList; var ALastStart:
    TDatetime);
const
  COLIDX_END_DATE = 0;
  COLIDX_TAGS = 1;
begin
  ATomatoes.Clear;
  try
    while not Eof do
    begin
      ATomatoes.Add(
        TTimePeriod.Create(
          IncSecond(TomatoDateToDateTime(FieldValue(COLIDX_END_DATE)), -TOMATODURATION),
          TOMATODURATION,
          VarToStrDef(FieldValue(COLIDX_TAGS), '')
            )
          );
      Next;
    end;
  except on e:Exception do
    begin
      e.RaiseOuterException(
        Exception.CreateFmt('%s LRow = %d', [e.Message, FLineIdx])
        );
    end;
  end;

  ATomatoes.Reverse;

  ATomatoes.ClearUntil(ALastStart);

  //if ATomatoes.Count = 0 then
    //Exception.Create('ATomatoes.Count = 0');
  if ATomatoes.Count > 0 then
    ALastStart := ATomatoes.Last.Start;

  ATomatoes.ShrinkOverlapped;
  ATomatoes.Check;
end;

function TTaCsv.Next: Boolean;
var
  LStr: string;
begin
  Result := not Eof;
  if Result then
  begin
    LStr := FReader.ReadLine;
    if FDelimiter <> SComma then
      LStr := ReplaceDelimiter(LStr, SComma, FDelimiter);

    FLine.StrictDelimiter := True;
    FLine.CommaText := LStr;
    Inc(FLineIdx);
    //ProcessLine;
  end;
end;

procedure TTaCsv.Open(const APath: string; AWrite: Boolean; AAppend: Boolean =
    False);
begin
  Close;
  if not AWrite then
  begin
    FReader := TStreamReader.Create(APath, TEncoding.UTF8, True);
    FLineIdx := -1;
    Next;
  end
  else
    FWriter := TStreamWriter.Create(APath, AAppend, TEncoding.UTF8);
end;

function TTaCsv.ParseDateTime(const AValue: string): TDateTime;
const
  SRegEx_hhnnddmmyyyy = '(\d*):(\d*) (\d*)\.(\d*)\.(\d*)';
var
  LMatch: TMatch;
  LReg: TRegEx;
begin
  LReg.Create(SRegEx_hhnnddmmyyyy);
  LMatch := LReg.Match(AValue);
  if not LMatch.Success then
    NotSupported(AValue, 'AValue');

  Result := StrToDateTime(
    Format(SFmt_ddmmyyyyhhnn,
      [
      LMatch.Groups.Item[3].Value,
      LMatch.Groups.Item[4].Value,
      LMatch.Groups.Item[5].Value,
      LMatch.Groups.Item[1].Value,
      LMatch.Groups.Item[2].Value
        ])
        );
end;

procedure TTaCsv.PrintPeriods(APeriods: TTimePeriodList);

var
  I: Integer;
begin
  for I := 0 to APeriods.Count - 1 do
  begin
    SetFieldValue(0, DateOf(APeriods[I].Start));
    SetFieldValue(1, TimeOf(APeriods[I].Start));
    SetFieldValue(2, TimeOf(APeriods[I].Finish));
    SetFieldValue(4, APeriods[I].Tags);

    CommitLine;
  end;
end;

function TTaCsv.ReplaceDelimiter(const AString: string; const ANew, AOld:
    Char): string;
const
  SQuote = '"';
var
  LPos: Integer;
  LPrev: Integer;
  LStrings: TStringList;
  I: Integer;
begin
  Result := '';

  LStrings := TStringList.Create();
  try
    LPrev := 0;
    for LPos := 1 to Length(AString) do
      if AString[LPos] = AOld then
      begin
        LStrings.Add(Copy(AString, LPrev+1, LPos-LPrev-1));
        LPrev := LPos;
      end;

    LStrings.Add(Copy(AString, LPrev+1, LPos-LPrev-1));

    for I := 0 to LStrings.Count - 1 do
    begin
      if I > 0 then
        Result := Result + ANew;

      Result := Result + SQuote + LStrings[I] + SQuote;
    end;
  finally
    FreeAndNil(LStrings);
  end;
end;

procedure TTaCsv.SetFieldValue(AColumnIdx: Integer; AValue: string);
begin
  while AColumnIdx >= FLine.Count do
    FLine.Add('');
  FLine.Strings[AColumnIdx] := AValue;
end;

procedure TTaCsv.SetFieldValue(AColumnIdx: Integer; AValue: TDateTime);
begin
  if DateOf(AValue) > 0 then
    SetFieldValue(AColumnIdx, DateTimeToStr(AValue))
    else
      SetFieldValue(AColumnIdx, TimeToStr(AValue))
end;

function TTaCsv.TomatoDateToDateTime(AValue: string): TDateTime;
const
  STimePrefix: Char = 'T';
begin
  AValue[Pos(' ', AValue)] := STimePrefix;
  AValue := Copy(AValue, 1, Pos(' ', AValue)-1) + '.000'
    + Copy(AValue, Pos(' ', AValue)+1, MaxInt);
  AValue := Copy(AValue, 1, Length(AValue) - 2) + ':'
    + Copy(AValue, Length(AValue) - 1, MaxInt);

  Result := ISO8601ToDate(AValue, True);
end;

end.
