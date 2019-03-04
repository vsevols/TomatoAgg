program TomatoAgg;

uses
  System.StartUpCopy,
  FMX.Forms,
  fMain in 'fMain.pas' {fmMain},
  Controller in 'Units\Controller.pas',
  taExcel in 'Units\taExcel.pas',
  taGlobals in 'Units\taGlobals.pas',
  taTypes in 'Units\taTypes.pas',
  taCsv in 'Units\taCsv.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TfmMain, fmMain);
  Application.Run;
end.
