unit lboxctrl;

interface

uses
  Windows, SysUtils, Classes, IdHTTP;

const
  LIB_VERSION = '1.1';

type
  TConnectResult = (crSuccess, crFailConnect, crFailDNSUpdate);

  TLineStatus = (lsUnknow, lsSynchronizing, lsSynchronized, lsNegotiating, lsConnected);
  
  TConfigurationInfo = class(TObject)
  private
    fPassword: string;
    fUserName: string;
    fHost: string;
  public
    property Host: string read fHost write fHost;
    property UserName: string read fUserName write fUserName;
    property Password: string read fPassword write fPassword;
  end;

  TInventelLiveboxHandler = class;

  TPropertyInfo = (piLineStatus, piIP, piConnectedTime);

  TLiveboxInformation = class(TObject)
  private
    fOwner: TInventelLiveboxHandler;
    fConnectedTime: string;
    fInternetStatus: Boolean;
    fIP: string;
    fLineStatus: TLineStatus;
    function GetConnectedTime: string;
    function GetInternetStatus: Boolean;
    function GetIP: string;
    function GetLineStatus: TLineStatus;
  protected
    procedure Clear;
    function GetDataInfo(const RawHTMLOutput: string;
      const DataInfo: TPropertyInfo): string;
    function TranslateLineStatus(const RawStr: string): TLineStatus;
    function TranslatePropertyInfoToStr(Data: TPropertyInfo): string;
    property Handler: TInventelLiveboxHandler read fOwner;
  public
    function Retrieve: Boolean;
    property LineStatus: TLineStatus read GetLineStatus;
    property InternetStatus: Boolean read GetInternetStatus;
    property IP: string read GetIP;
    property ConnectedTime: string read GetConnectedTime;
  end;

  TRequestHandler = class(TObject)
  private
    fHTTPClient: TIdHTTP;
    fOwner: TInventelLiveboxHandler;
  protected
    function AccessGranted(const ReturnedPage: string): Boolean;
    function GetBaseURL: string;
    procedure InitConnection;
    property Client: TIdHTTP read fHTTPClient;
  public
    constructor Create(Owner: TInventelLiveboxHandler);
    destructor Destroy; override;
    function Read(URL: string): string;
    function Write(URL: string; SuccessStringTags: array of string): Boolean;
      overload;
    function Write(URL: string; SuccessStringTag: string): Boolean; overload;
    function Write(URL: string; SuccessStringTags: array of string;
      MaxRetry, SleepBetweenRetry: Integer): Boolean; overload;
    function Write(URL: string; SuccessStringTag: string;
      MaxRetry, SleepBetweenRetry: Integer): Boolean; overload;
    property Owner: TInventelLiveboxHandler read fOwner;
  end;

  TInventelLiveboxHandler = class(TObject)
  private
    fConfiguration: TConfigurationInfo;
    fProperties: TLiveboxInformation;
    fUpdateDynDNS: Boolean;
    fClient: TRequestHandler;
  protected

    function PerformUpdateDynDNS: Boolean;
    property Client: TRequestHandler read fClient;
  public
    constructor Create;
    destructor Destroy; override;
    function Connect: TConnectResult;
    function Disconnect: Boolean;
    function RenewIP: TConnectResult;
    property Configuration: TConfigurationInfo read fConfiguration;
    property UpdateDynDNS: Boolean read fUpdateDynDNS write fUpdateDynDNS;
    property Properties: TLiveboxInformation read fProperties;
  end;

implementation

uses
  Utils;

const
  WRITE_DEFAULT_MAX_TRIES = 10;
  WRITE_DEFAULT_SLEEP	    = 1000;
  SUCCESS_TAG = 'Vous devez attendre 1 minute avant que votre livebox soit ';
  
{ TInventelLiveboxHandler }

function TInventelLiveboxHandler.Connect: TConnectResult;
begin
  Result := crFailConnect;

  if Client.Write('internetok.cgi?enblInternet=1', SUCCESS_TAG) then
    Result := crSuccess;

  if (UpdateDynDNS) and (not PerformUpdateDynDNS) then
    Result := crFailDNSUpdate;

  Properties.Clear;
end;

constructor TInventelLiveboxHandler.Create;
begin
  fClient := TRequestHandler.Create(Self);
  fConfiguration := TConfigurationInfo.Create;
  fProperties := TLiveboxInformation.Create;
  fProperties.fOwner := Self;
  fUpdateDynDNS := False;
end;

destructor TInventelLiveboxHandler.Destroy;
begin
  Configuration.Free;
  Client.Free;
  Properties.Free;  
  inherited;
end;

function TInventelLiveboxHandler.Disconnect: Boolean;
begin
  Result := Client.Write('internetok.cgi?enblInternet=0', SUCCESS_TAG);
  Properties.Clear;
end;

function TInventelLiveboxHandler.RenewIP: TConnectResult;
var
  OK: Boolean;

begin
  Result := crFailConnect;
  OK := Disconnect;
  if not OK then Exit;
  Sleep(10000);
  Result := Connect;
end;                          

function TInventelLiveboxHandler.PerformUpdateDynDNS: Boolean;
const
  SERVICE_TAG = 'dyndnsService.value';
  DOMAIN_TAG = 'dyndnsDomain.value';
  EMAIL_TAG = 'dyndnsEmail.value';
  USERNAME_TAG = 'dyndnsUsername.value';
  PASSWORD_TAG = 'dyndnsPassword.value';
  DYNDNS_PARAMS_APPLIED = 'Configuration r&eacute;ussie';

  DYNDNS_UPDATE_RESULT: array[0..1] of string = (
    'Update good and successful, IP updated.',
    'update is not necessary'
  );

var
  PageRequestInfo,
  DynUpdateURL: string;
  
  function GetParamValue(Tag: string): string;
  begin
    Result := ExtractStr(Tag + ' = ''', '''', PageRequestInfo);
  end;
  
  function GenerateUpdateURL: string;
  var
    Service, Domain, Email,
    UserName, Password: string;
    
  begin
    Service := GetParamValue(SERVICE_TAG);
    Domain := GetParamValue(DOMAIN_TAG);
    Email := GetParamValue(EMAIL_TAG);
    UserName := GetParamValue(USERNAME_TAG);
    Password := GetParamValue(PASSWORD_TAG);

    Result := 'dyndnsok.cgi?dyndnsService=' + Service +
      '&dyndnsDomain=' + Domain + '&dyndnsEmail=' + Email +
      '&dyndnsUsername=' + UserName + '&dyndnsPassword=' + Password;
  end;

begin
  PageRequestInfo := Client.Read('dyndns.html');

  // Génération de l'URL
  DynUpdateURL := GenerateUpdateURL;

  // Mis à jour du DNS de la Livebox.
  Properties.Retrieve;
  Result := Client.Write(DynUpdateURL, DYNDNS_PARAMS_APPLIED);

  // On a mis à jour le DNS de la Livebox, on vérifie le status du serveur
  if Result then
    Result := Client.Write('dyndns.html', DYNDNS_UPDATE_RESULT);
end;

{ TLiveboxInformation }

function TLiveboxInformation.Retrieve: Boolean;
const
  INTERNET_STATUS_TAG = 'if (''1'' == ''1'')';
  
var
  Output: string;
  
begin
  Result := False;
  Output := Handler.Client.Read('srv_internet.html');
  if Output = '' then Exit;

  // Retrieving infos
  fLineStatus := TranslateLineStatus(GetDataInfo(Output, piLineStatus));
  fIP := GetDataInfo(Output, piIP);
  fConnectedTime := Trim(GetDataInfo(Output, piConnectedTime));
  fInternetStatus := IsInString(INTERNET_STATUS_TAG, Output);
  Result := True;
end;

procedure TLiveboxInformation.Clear;
begin
  fLineStatus := lsUnknow;
  fConnectedTime := '';
  fInternetStatus := False;
  fIP := '';
end;

function TLiveboxInformation.GetConnectedTime: string;
begin
  if fConnectedTime = '' then Retrieve;
  Result := fConnectedTime;
end;

// Permet de récupérer la valeur voulue (DataInfo) depuis la sortie HTML (RawHTMLOutput)
function TLiveboxInformation.GetDataInfo(const RawHTMLOutput: string;
  const DataInfo: TPropertyInfo): string;
const
  LEFT_TAG = 'writit( color + "';
  RIGHT_TAG = '</font>", "'; // + DataInfo
  
var
  SearchedData: string;
  SL: TStringList;
  i: Integer;
  Done: Boolean;

begin
  Result := '';

  // on analyse le résultat
  SL := TStringList.Create;
  try
    SL.Text := RawHTMLOutput; // chaque ligne est maintenant un poste de la StringList
    Done := False;
    i := 0;

    // Balise de droite qui va servir à localiser la donnée cherchée
    SearchedData := RIGHT_TAG + TranslatePropertyInfoToStr(DataInfo);

    // Chercher la ligne concernée dans la page
    while not Done do begin
      // WriteLn(SL[i]);
      
      if (IsInString(LEFT_TAG, SL[i])) and (IsInString(SearchedData, SL[i])) then begin // si on a trouvé la ligne cherchée...
        Result := ExtractStr(LEFT_TAG, SearchedData, SL[i]); // On extrait notre donnée
        Done := True;
      end;
      Inc(i);
      Done := (not Done) and (i = SL.Count);
    end;

  finally
    SL.Free;
  end;
end;

function TLiveboxInformation.GetInternetStatus: Boolean;
begin
  if fIP = '' then Retrieve;
  Result := fInternetStatus;
end;

function TLiveboxInformation.GetIP: string;
begin
  if fIP = '' then Retrieve;
  Result := fIP;
end;

function TLiveboxInformation.GetLineStatus: TLineStatus;
begin
  if fLineStatus = lsUnknow then Retrieve;
  Result := fLineStatus;
end;

function TLiveboxInformation.TranslateLineStatus(
  const RawStr: string): TLineStatus;
begin
  Result := lsUnknow;
  if RawStr = 'Synchronisation en cours...' then Result := lsSynchronizing;
  if RawStr = 'Synchronis&eacute;' then Result := lsSynchronized;
  if RawStr = 'N&eacute;gociation en cours...' then Result := lsNegotiating;
  if RawStr = 'Connect&eacute;' then Result := lsConnected;
end;

function TLiveboxInformation.TranslatePropertyInfoToStr(
  Data: TPropertyInfo): string;
begin
  Result := '';
  case Data of
    piLineStatus      : Result := 'adsl_status';
    piIP              : Result := 'addr';
    piConnectedTime   : Result := 'time';
  end;
end;

{ TRequestHandler }

function TRequestHandler.AccessGranted(const ReturnedPage: string): Boolean;
const
  INVALID_PASSWORD = 'Authorization required.';

begin
  Result := not IsInString(INVALID_PASSWORD, ReturnedPage);
end;

constructor TRequestHandler.Create(Owner: TInventelLiveboxHandler);
begin
  Self.fOwner := Owner;
  fHTTPClient := TIdHTTP.Create(nil);
end;

destructor TRequestHandler.Destroy;
begin
  fHTTPClient.Free;
  inherited;
end;

function TRequestHandler.GetBaseURL: string;
begin
  Result := 'http://' + Owner.Configuration.Host + '/';
end;

procedure TRequestHandler.InitConnection;
begin
  Client.Request.Username := Owner.Configuration.UserName;
  Client.Request.Password := Owner.Configuration.Password;
  Client.Request.BasicAuthentication := True;
end;

function TRequestHandler.Read(URL: string): string;
begin
  try
    InitConnection;

    Result := Client.Get(GetBaseURL + URL);

{$IFDEF DEBUG}
    WriteLn(
      '<!-- BEGIN READ: "', URL, '" -->', sLineBreak,
      Result,
      '<!-- END READ: "', URL, '" -->', sLineBreak
    );
{$ENDIF}

    if not AccessGranted(Result) then
      Result := '';
  except
    Result := '';
  end;
end;

function TRequestHandler.Write(URL, SuccessStringTag: string): Boolean;
var
  OneStringArray: array[0..0] of string;
  
begin
  OneStringArray[0] := SuccessStringTag;
  Result := Write(URL, OneStringArray);
end;

function TRequestHandler.Write(URL, SuccessStringTag: string; MaxRetry,
  SleepBetweenRetry: Integer): Boolean;
var
  OneStringArray: array[0..0] of string;

begin
  OneStringArray[0] := SuccessStringTag;
  Result := Write(URL, OneStringArray, MaxRetry, SleepBetweenRetry);
end;

function TRequestHandler.Write(URL: string; SuccessStringTags: array of string): Boolean;
begin
  Result := Write(URL, SuccessStringTags, WRITE_DEFAULT_MAX_TRIES, WRITE_DEFAULT_SLEEP);
end;

function TRequestHandler.Write(URL: string; SuccessStringTags: array of string;
  MaxRetry, SleepBetweenRetry: Integer): Boolean;
var
  RetryCount: Integer;
  Output: string;

begin
  try
    InitConnection;

    RetryCount := 1;
    repeat
      Output := Client.Get(GetBaseURL + URL);

{$IFDEF DEBUG}
      WriteLn(
        '<!-- BEGIN WRITE [#', RetryCount, ']: "', URL, '" -->', sLineBreak,
        Output,
        '<!-- END WRITE [#', RetryCount, ']: "', URL, '" -->', sLineBreak
      );
{$ENDIF}

      Sleep(SleepBetweenRetry);

      // Checking result
      Result := AccessGranted(Output) and IsInString(SuccessStringTags, Output);

      Inc(RetryCount);
    until Result or (RetryCount > MaxRetry);

  except
    Result := False;
  end;
end;

end.
