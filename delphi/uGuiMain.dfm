object frmMain: TfrmMain
  Left = 192
  Top = 124
  Width = 680
  Height = 440
  Caption = 'IDR Delphi7 testcase (GUI)'
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = False
  PixelsPerInch = 96
  TextHeight = 13
  object lblHint: TLabel
    Left = 16
    Top = 16
    Width = 610
    Height = 13
    Caption = 'IDR_FEATURE: DFM resource + event handlers + VCL symbols. You do not need to run this for analysis.'
  end
  object btnRun: TButton
    Left = 16
    Top = 40
    Width = 140
    Height = 25
    Caption = 'Run smoke (optional)'
    TabOrder = 0
    OnClick = btnRunClick
  end
  object Memo1: TMemo
    Left = 16
    Top = 80
    Width = 632
    Height = 320
    TabOrder = 1
    ScrollBars = ssVertical
  end
end
