unit taTypes;

interface

uses
  System.Generics.Collections, System.SysUtils, Data.DB, System.Classes;

type
  TTimePeriod = record
    Start: TDateTime;
    Duration: Integer;
    Tags: string;
  strict private
    function GetFinish: TDateTime;
    procedure StringsTrim(AStrings: TStrings);
    procedure TagsFromStrings(AStrings: TStrings);
    procedure TagsToStrings(AStrings: TStringList);
  private
  public
    constructor Create(AStart: TDateTime; ADuration: Integer; const ATags: string);
    function HasTag(ATag: string): Boolean;
    function IncDuration(ASeconds: Integer; AMoveStart: Boolean): TTimePeriod;
    function IncludeTags(ASource: TTimePeriod): TTimePeriod;
    function RemoveTag(ATag: string): TTimePeriod;
    function TimeShift(ASeconds: Integer): TTimePeriod;
    property Finish: TDateTime read GetFinish;
  end;

  TTimePeriodList = class(TList<TTimePeriod>)
  strict private
  private
    function GetNearestIdx(AMoment: TDateTime; out AFoundBefore: Boolean): Integer;
  public
    procedure MergeSequences;
    procedure ApplyCorrections(ACorrections: TTimePeriodList);
    procedure Check;
    procedure ClearUntil(ALastStart: TDatetime);
    procedure FilterByTag(ATag: string; ARemoveTag: Boolean);
    procedure JustifyMidnight;
    procedure ShrinkOverlapped;
    procedure TimeShift(ASeconds: Integer);
  end;
implementation

uses
  System.DateUtils, taGlobals, System.Types;

constructor TTimePeriod.Create(AStart: TDateTime; ADuration: Integer; const
    ATags: string);
begin
  Start := AStart;
  Duration := ADuration;
  Tags := ATags;
end;

function TTimePeriod.GetFinish: TDateTime;
begin
  Result := IncSecond(Self.Start, Self.Duration);
end;

function TTimePeriod.HasTag(ATag: string): Boolean;
var
  LStrings: TStringList;
  LTag: string;
begin
  Result := False;
  LStrings := TStringList.Create();
  try
    TagsToStrings(LStrings);
    LStrings.CaseSensitive := False;
    Result := LStrings.IndexOf(ATag) >= 0;
    {for LTag in LStrings do
      if LTag.ToUpper=ATag.ToUpper then
        Exit(True);}
  finally
    FreeAndNil(LStrings);
  end;
end;

function TTimePeriod.IncDuration(ASeconds: Integer; AMoveStart: Boolean):
    TTimePeriod;
begin
  Inc(Self.Duration, ASeconds);
  if AMoveStart then
    Self.Start := IncSecond(Self.Start, -ASeconds);
  Result := Self;
end;

function TTimePeriod.IncludeTags(ASource: TTimePeriod): TTimePeriod;
var
  LSource: TStringList;
  LDest: TStringList;
  LTag: string;
begin
  LSource := TStringList.Create();
  LDest := TStringList.Create();
  try
    ASource.TagsToStrings(LSource);
    Self.TagsToStrings(LDest);
    for LTag in LSource do
      if LDest.IndexOf(LTag) < 0 then
        LDest.Add(LTag);
    Self.TagsFromStrings(LDest);
  finally
    FreeAndNil(LDest);
    FreeAndNil(LSource);
  end;
  Result := Self;
end;

function TTimePeriod.RemoveTag(ATag: string): TTimePeriod;
var
  LStrings: TStringList;
  LTag: string;
  I: Integer;
begin
  LStrings := TStringList.Create();
  try
    Self.TagsToStrings(LStrings);

    while True do
    begin
      I := LStrings.IndexOf(ATag);
      if I < 0 then
        Break;
      LStrings.Delete(I);
    end;

    {
    for I := LStrings.Count - 1 downto 0 do
      if LStrings.Strings[I].ToUpper=ATag.ToUpper then
        LStrings.Delete(I);}
    Self.TagsFromStrings(LStrings);
  finally
    FreeAndNil(LStrings);
  end;
  Result := Self;
end;

procedure TTimePeriod.StringsTrim(AStrings: TStrings);
var
  I: Integer;
begin
  for I := 0 to AStrings.Count - 1 do
  begin
    AStrings.Strings[I] := Trim(AStrings.Strings[I]);
    AStrings.Strings[I] := StringReplace(AStrings.Strings[I], ''#$00a0, '', []);
  end;
end;

procedure TTimePeriod.TagsFromStrings(AStrings: TStrings);
begin
  AStrings.Delimiter := ',';
  Tags := AStrings.DelimitedText;
end;

procedure TTimePeriod.TagsToStrings(AStrings: TStringList);
begin
  AStrings.Delimiter := ',';
  AStrings.StrictDelimiter := True;
  AStrings.DelimitedText := Tags;
  AStrings.CaseSensitive := False;
  StringsTrim(AStrings);
end;

function TTimePeriod.TimeShift(ASeconds: Integer): TTimePeriod;
begin
  Self.Start := IncSecond(Self.Start, ASeconds);
  Result := Self;
end;

procedure TTimePeriodList.ApplyCorrections(ACorrections: TTimePeriodList);
var
  LTomatoIsBefore: Boolean;
  LNearest: TTimePeriod;
  LNearestIdx: Integer;
  LPeriod: TTimePeriod;
begin
  if ACorrections.Count = 0 then
    Exit;

  if Count = 0 then
  begin
    Add(ACorrections[0]);
    ACorrections.Delete(0);
  end;

  for LPeriod in ACorrections do
  begin
    LNearestIdx := GetNearestIdx(LPeriod.Start, LTomatoIsBefore);
    LNearest := Self[LNearestIdx];

    LNearest := LNearest.IncDuration(LPeriod.Duration, not LTomatoIsBefore);

    LNearest := LNearest.IncludeTags(LPeriod);
    Self[LNearestIdx] := LNearest;
  end;


end;

procedure TTimePeriodList.Check;
var
  APrevFinish: TDateTime;
  I: Integer;
  LPeriod: TTimePeriod;
begin
  I := 0;
  APrevFinish := 0;
  for LPeriod in Self do
  begin
    if APrevFinish > LPeriod.Start then
      raise Exception.CreateFmt(
        'TTimePeriodList.Check APrevFinish > LPeriod.Start Idx:%d %s > %s', [I,
          FormatDateTime('yy-mmdd hh:nn', APrevFinish),
          FormatDateTime('yy-mmdd hh:nn', LPeriod.Start)
          ]);
    if LPeriod.Duration < 0 then
      raise Exception.CreateFmt(
        'TTimePeriodList.Check LPeriod.Duration < 0 Idx:%d %s > %s', [I,
          FormatDateTime('yy-mmdd hh:nn', LPeriod.Start),
          FormatDateTime('yy-mmdd hh:nn', LPeriod.Finish)
          ]);

    APrevFinish := LPeriod.Finish;
    Inc(I);
  end;
end;

procedure TTimePeriodList.ClearUntil(ALastStart: TDatetime);
var
  I: Integer;
begin
  for I := Count-1 downto 0 do
  begin
    //if Self[I].Start <= ALastStart then //acts not correct when seconds are equal
    if CompareDateTime(Self[I].Start, ALastStart) <= EqualsValue then
      Delete(I);
  end;
end;

procedure TTimePeriodList.FilterByTag(ATag: string; ARemoveTag: Boolean);
var
  I: Integer;
begin
  for I := Count-1 downto 0 do
    if not Self[I].HasTag(ATag) then
      Delete(I)
      else if ARemoveTag then
      begin
        Self[I] := Self[I].RemoveTag(ATag);
      end;
end;

function TTimePeriodList.GetNearestIdx(AMoment: TDateTime; out AFoundBefore:
    Boolean): Integer;
var
  I: Integer;
  LSpan: Double;
begin
  LSpan := MaxDateTime;
  Result := -1;

  for I := 0 to Count - 1 do
    if Abs(AMoment - Self[i].Start) < LSpan then
    begin
      Result := I;
      AFoundBefore := AMoment > Self[i].Start;
      LSpan := Abs(AMoment - Self[i].Start);
    end;
end;

procedure TTimePeriodList.JustifyMidnight;
var
  I: Integer;
  LNewPeriod: TTimePeriod;
  LPeriod: TTimePeriod;
begin
  for LPeriod in Self do
    if DateOf(LPeriod.Start) <> DateOf(LPeriod.Finish) then
    begin
      LNewPeriod := TTimePeriod.Create(DateOf(LPeriod.Finish),
        SecondsBetween(DateOf(LPeriod.Finish), LPeriod.Finish) + SECONDSINMINUTE,
        LPeriod.Tags);
      //DONE: Здесь и в остальных местах Exchange! Структуры ведь не сохраняются (?)
      I := IndexOf(LPeriod); //DONE: IndexOf - корректно ли?
      Self[I] := Self[I].IncDuration(-LNewPeriod.Duration, False);
      Self.Insert(I + 1, LNewPeriod);
    end;

  ShrinkOverlapped;
end;

procedure TTimePeriodList.MergeSequences;
const
  MERGEMAXSPAN = SECONDSINMINUTE * 60 * 2;
var
  I: Integer;
begin
  for I := Count - 2 downto 0 do
    if (Self[I].Tags = Self[I + 1].Tags)
      and (SecondsBetween(Self[I].Start, Self[I + 1].Start) < MERGEMAXSPAN) then
    begin
      Self[I] := Self[I].IncDuration(Self[I + 1].Duration, False);
      Delete(I + 1);
    end;
end;

procedure TTimePeriodList.ShrinkOverlapped;
var
  dbgTmp: TDateTime;
  I: Integer;
begin               dbgTmp := StrToDateTime('04.01.2019 19:00'); //TODO -cDelete: dbg
  for I := 1 to Count - 1 do
  begin
    if Self[I - 1].Finish > Self[I].Start then
    begin
      Self[I] := Self[I].TimeShift(SecondsBetween(Self[I].Start, Self[I - 1].Finish));
    end;
  end;
end;

procedure TTimePeriodList.TimeShift(ASeconds: Integer);
var
  I: Integer;
  LItem: TTimePeriod;
begin
  for I := 0 to Count - 1 do
  begin
    Self[I] := Self[I].TimeShift(ASeconds);
  end;
end;

end.
