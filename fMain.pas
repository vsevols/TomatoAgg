unit fMain;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs,
  FMX.Controls.Presentation, FMX.StdCtrls, Controller, FMX.Edit,
  Winapi.ShellAPI, Winapi.Windows;

type
  TfmMain = class(TForm)
    Label1: TLabel;
    btProcess: TButton;
    btProcessCsv: TButton;
    btSaveHead: TButton;
    Label4: TLabel;
    edLastPeriod: TEdit;
    btHelp: TButton;
    btDownloadCsv: TButton;
    procedure btDownloadCsvClick(Sender: TObject);
    procedure btHelpClick(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure btProcessClick(Sender: TObject);
    procedure btProcessCsvClick(Sender: TObject);
    procedure btSaveHeadClick(Sender: TObject);
  strict private
    procedure UpdateGui;
  private
    FController: TTomatoAggController;
    procedure ShellExecute(sPath: string; sParams: string = ''; nCmdShow: Cardinal
        = SW_NORMAL);
    { Private declarations }
  protected
  public
    { Public declarations }
  published
  end;

var
  fmMain: TfmMain;

implementation

uses
  taGlobals;

const
  SSettingsDat = 'Settings.dat';


{$R *.fmx}

procedure TfmMain.btDownloadCsvClick(Sender: TObject);
begin
  ShellExecute('http://www.tomato.es/tomatoes.csv');
end;

procedure TfmMain.btHelpClick(Sender: TObject);
begin
  ShellExecute(DataPath('Help.txt'));
end;

procedure TfmMain.ShellExecute(sPath: string; sParams: string = ''; nCmdShow:
    Cardinal = SW_NORMAL);
begin
  Winapi.ShellApi.ShellExecute(0, nil, pChar(sPath), pChar(sParams), nil, nCmdShow);
end;

procedure TfmMain.FormDestroy(Sender: TObject);
begin
  FreeAndNil(FController);
end;

procedure TfmMain.FormCreate(Sender: TObject);
begin
  FController := TTomatoAggController.Create();
  //Button1Click(nil);
  FController.SerializeSettings(DataPath(SSettingsDat), False);

  Label1.Visible := False;
  btProcess.Visible := False;
  UpdateGui;
end;

procedure TfmMain.btProcessClick(Sender: TObject);
begin
  FController.Process(False);
end;

procedure TfmMain.btProcessCsvClick(Sender: TObject);
begin
  FController.Process(True);
  UpdateGui;
end;

procedure TfmMain.btSaveHeadClick(Sender: TObject);
begin
  FController.SerializeSettings(DataPath(SSettingsDat), True);
end;

procedure TfmMain.UpdateGui;
begin
  edLastPeriod.Text := FController.GetLastPeriodsStr;
end;

end.
