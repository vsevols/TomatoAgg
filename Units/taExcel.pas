unit taExcel;

interface

uses
  Excel2010, taTypes, System.DateUtils, System.SysUtils;

type
  TTaExcel = class(TObject)
  strict private
  private
    FBook: ExcelWorkbook;
    FExcel: TExcelApplication;
  protected
  public
    constructor Create;
    destructor Destroy; override;
    function EofRow(ASheet: ExcelWorksheet; ARow: Integer): Boolean;
    procedure GetCorrections(ACorrections: TTimePeriodList; var ALastStart:
        TDatetime);
    function GetSheet(AIndex: Integer): ExcelWorksheet;
    procedure GetTomatoes(ATomatoes: TTimePeriodList);
    procedure InitExcelBook(APath, ATemplatePath: string);
    function MonthToNumber(AName: string; const AFormat: TFormatSettings): Integer;
    procedure PrintPeriods(APeriods: TTimePeriodList);
    function TomatoDateToDateTime(AValue: string): TDateTime;
  end;

implementation

uses
  Winapi.Windows, System.Variants, System.Classes, taGlobals;


constructor TTaExcel.Create;
begin
  inherited Create;
  FExcel := TExcelApplication.Create(nil);
end;

destructor TTaExcel.Destroy;
begin
  FreeAndNil(FExcel);
  inherited Destroy;
end;

function TTaExcel.EofRow(ASheet: ExcelWorksheet; ARow: Integer): Boolean;
begin
  Result := VarToStrDef(ASheet.Cells.Item[ARow, 1], '').IsEmpty;
end;

procedure TTaExcel.GetCorrections(ACorrections: TTimePeriodList; var
    ALastStart: TDatetime);
const
  COLIDX_DATE = 'A';
  COLIDX_DURATION = 'B';
  COLIDX_TAGS = 'C';
var
  LIdx: Integer;
  LRow: Integer;
  LSheet: ExcelWorksheet;
begin
  ACorrections.Clear;
  LSheet := GetSheet(2);
  LRow := 1;
  try
    while not EofRow(LSheet, LRow) do
    begin
      LIdx := ACorrections.Add(
        TTimePeriod.Create(
          StrToDateTime(LSheet.Cells.Item[LRow, COLIDX_DATE]),
          StrToInt(LSheet.Cells.Item[LRow, COLIDX_DURATION]) * SECONDSINMINUTE,
          VarToStrDef(LSheet.Cells.Item[LRow, COLIDX_TAGS], '')
            )
          );

      ACorrections[LIdx] := ACorrections[LIdx].TimeShift(-ACorrections[LIdx].Duration);

      Inc(LRow);
    end;
  except on e:Exception do
    begin
      e.RaiseOuterException(
        Exception.CreateFmt('%s LRow = %d', [e.Message, LRow])
        );
    end;
  end;
  ACorrections.ClearUntil(ALastStart);

  if ACorrections.Count > 0 then
    ALastStart := ACorrections.Last.Start;
end;

function TTaExcel.GetSheet(AIndex: Integer): ExcelWorksheet;
begin
  Result := FBook.Worksheets.Item[AIndex] as ExcelWorksheet;
end;

procedure TTaExcel.GetTomatoes(ATomatoes: TTimePeriodList);
const
  COLIDX_DATE = 'A';
  COLIDX_TAGS = 'B';
var
  LRow: Integer;
  LSheet: ExcelWorksheet;
begin
  ATomatoes.Clear;
  LSheet := GetSheet(1);
  LRow := 1;
  try
    while not EofRow(LSheet, LRow) do
    begin
      ATomatoes.Add(
        TTimePeriod.Create(
          TomatoDateToDateTime(LSheet.Cells.Item[LRow, COLIDX_DATE]),
          TOMATODURATION,
          VarToStrDef(LSheet.Cells.Item[LRow, COLIDX_TAGS], '')
            )
          );
      Inc(LRow);
    end;
  except on e:Exception do
    begin
      e.RaiseOuterException(
        Exception.CreateFmt('%s LRow = %d', [e.Message, LRow])
        );
    end;
  end;

  ATomatoes.Reverse;
  ATomatoes.Check;
end;

procedure TTaExcel.InitExcelBook(APath, ATemplatePath: string);
begin
  FExcel.Visible[GetUserDefaultLCID] := True;
  //TODO: WorkbookCreateFromTemplate
  //FExcel.Workbooks.Add(ATemplatePath, GetUserDefaultLCID);
  //FExcel.Workbooks.Add('', GetUserDefaultLCID);

  FBook := FExcel.Workbooks.Open(APath, EmptyParam, EmptyParam, EmptyParam, EmptyParam,
    EmptyParam, EmptyParam, EmptyParam, EmptyParam, EmptyParam, EmptyParam,
    EmptyParam, EmptyParam, EmptyParam, EmptyParam, 0);
      {
  FBook := FExcel.Workbooks.Open(APath, varNull, nil, nil, nil,
    nil, nil, nil, nil, nil, nil,
    nil, nil, nil, nil, 0);
    }
end;

function TTaExcel.MonthToNumber(AName: string; const AFormat: TFormatSettings):
    Integer;
var
  I: Integer;
begin
  Result := -1;
  for I := Low(AFormat.LongMonthNames) to High(AFormat.LongMonthNames) do
    if AFormat.LongMonthNames[i] = AName then
      Exit(I);
end;

procedure TTaExcel.PrintPeriods(APeriods: TTimePeriodList);
const
  STimeFormat = 'h:mm:ss;@';
var
  I: Integer;
  LRow: Integer;
  LSheet: ExcelWorksheet;
begin
  LSheet := GetSheet(3);
  LSheet.Cells.ClearContents;
  //LSheet.Columns.Item[1, 2].NumberFormat := STimeFormat;
  //LSheet.Columns.Item[1, 2].NumberFormat := STimeFormat;

  for I := 0 to APeriods.Count - 1 do
  begin
    LRow := I + 1;
    LSheet.Cells.Item[LRow, 'A'] := DateOf(APeriods[I].Start);

    LSheet.Cells.Item[LRow, 'B'] := TimeOf(APeriods[I].Start);
    LSheet.Cells.Item[LRow, 'C'] := TimeOf(APeriods[I].Finish);

    LSheet.Cells.Item[LRow, 'E'] := APeriods[I].Tags;
  end;
end;

function TTaExcel.TomatoDateToDateTime(AValue: string): TDateTime;
const
  IDXDAY = 1;
var
  LFormat: TFormatSettings;
  LStrings: TStringList;
begin
  LFormat := LFormat.Create('en_US');

  LStrings := TStringList.Create();
  try
    LStrings.Delimiter := ' ';
    LStrings.DelimitedText := AValue;
    LStrings.Strings[IDXDAY] := StringReplace(LStrings.Strings[IDXDAY], ',','', []);
    AValue := Format('%d/%s/%s %s', [
      MonthToNumber(LStrings.Strings[0], LFormat),
      LStrings.Strings[IDXDAY],
      LStrings.Strings[2],
      LStrings.Strings[3]
      ]);
  finally
    FreeAndNil(LStrings);
  end;

//  DateTimeToString(AValue, 'mmmm dd, yyyy hh:nn', Now, LFormat);
  Result := StrToDateTime(AValue, LFormat);
end;

end.

