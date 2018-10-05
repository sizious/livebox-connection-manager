program checkcon;

{$APPTYPE CONSOLE}

{$R 'version.res' 'version.rc'}

uses
  Windows,
  SysUtils,
  IdObjs,
  IdBaseComponent,
  IdComponent,
  IdRawBase,
  IdRawClient,
  IdIcmpClient;

const
  APP_VERSION = '1.0';
  
type
  TCheckConnectionHandler = class
  public
    Client: TIdIcmpClient;
    PingStatusResult: Boolean;
    procedure OnReplyHandler(ASender: TIdNativeComponent; const AReplyStatus: TReplyStatus);
    function Ping(const AHost: string; const ATimes: Integer): Boolean;
  end;

var
  CheckConnectionHandler: TCheckConnectionHandler;
  Host: string;
  TimesTest: Integer;
   
procedure TCheckConnectionHandler.OnReplyHandler(ASender: TIdNativeComponent;
  const AReplyStatus: TReplyStatus);
begin
  PingStatusResult := PingStatusResult and (AReplyStatus.ReplyStatusType = rsEcho);
end;

function TCheckConnectionHandler.Ping(const AHost: string; const ATimes: Integer): Boolean;
 var
  i: Integer;

begin
  Result := True;
  if ATimes <= 0 then Exit;

  PingStatusResult := True;
  
  Client := TIdIcmpClient.Create(nil);
  with Client do
    try
      OnReply := OnReplyHandler;
      Host := AHost;
      ReceiveTimeout := 999; //TimeOut du ping

      // Pinguer le client
      for i := 0 to Pred(ATimes) do begin
        try
          Ping;
          Sleep(1000);
        except
          PingStatusResult := False;
          Break;
        end;
      end;

    finally
      Result := PingStatusResult;
      Free;
    end;
end;

begin
  CheckConnectionHandler := TCheckConnectionHandler.Create;
  try
    try
      WriteLn('Connection Checker - v', APP_VERSION, ' - (C)reated by [big_fury]SiZiOUS');
      WriteLn('http://sbibuilder.shorturl.com/' + sLineBreak);

      WriteLn('Checking Internet connection status...');      
      try
        Host := 'www.google.fr';
        if ParamCount > 0 then
          Host := ParamStr(1);

        TimesTest := 4;
        if ParamCount > 1 then
          TimesTest := StrToIntDef(ParamStr(2), 4);
      except
        WriteLn('Invalid parameters.');
        WriteLn('Syntax: checkcon [host] [max_test]');
        ExitCode := 255;
        Exit;
      end;

      if CheckConnectionHandler.Ping(Host, TimesTest) then begin
        ExitCode := 0;
        WriteLn('Internet Connection available.');
      end else begin
        ExitCode := 1;
        WriteLn('Internet Connection is NOT available.');
      end;
    except
      on E:Exception do
        WriteLn('FATAL: ', E.ClassName, ': ', E.Message);
    end;
  finally
    CheckConnectionHandler.Free;
  end;
end.
