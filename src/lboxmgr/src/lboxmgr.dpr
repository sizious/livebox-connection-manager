program lboxmgr;

{$APPTYPE CONSOLE}

{$R 'version.res' 'version.rc'}

uses
  SysUtils,
  lboxctrl in 'lboxctrl.pas',
  utils in 'utils.pas';

const
  APP_VERSION = '1.1';

type
  TLiveboxOperation = (loInvalid, loInfo, loConnect, loDisconnect, loRenew);
    
var
  Livebox: TInventelLiveboxHandler;
  PrgName, Temp: string;
  Operation: TLiveboxOperation;

procedure UnableToContactLivebox;
begin
  ConsolePrint(
    'ERREUR: Impossible de se connecter à la Livebox. Vérifiez les paramètres de' + sLineBreak +
    '        connexion (adresse IP, login et password). L''ordre de saisie est ' + sLineBreak +
    '        important. Tapez "' + PrgName + ' /?" dans la console pour obtenir de l''aide.'
  );
end;

procedure PrintLiveboxInfos;
var
  LineStatus, InternetStatus, FinalLine: string;

begin
  if Livebox.Properties.Retrieve then begin
    case Livebox.Properties.LineStatus of
      lsUnknow        : LineStatus := 'Inconnu!';
      lsSynchronizing : LineStatus := 'Synchronisation en cours...';
      lsSynchronized  : LineStatus := 'Synchronisé';
      lsNegotiating   : LineStatus := 'Négociation en cours...';
      lsConnected     : LineStatus := 'Connecté';
    end;

    if Livebox.Properties.InternetStatus then
      InternetStatus := 'Connecté'
    else
      InternetStatus := 'Déconnecté';

    FinalLine := (
      'Propriétés actuelles de la Livebox :' + sLineBreak + sLineBreak +
      'Statut de la ligne ADSL............: ' + LineStatus + sLineBreak +
      'État de la connexion Internet......: ' + InternetStatus + sLineBreak +
      'Adresse IP de la Livebox...........: ' + Livebox.Properties.IP + sLineBreak +
      'Connecté à Internet depuis.........: ' + Livebox.Properties.ConnectedTime
    );
    FinalLine := StringToOem(FinalLine);

    WriteLn(FinalLine);
  end else
    UnableToContactLivebox;
end;

procedure PrintHeader;
begin
  WriteLn(
    'Livebox Connection Manager - v', APP_VERSION, ' (Moteur v', LIB_VERSION, ')', sLineBreak,
    '(C)reated by [big_fury]SiZiOUS - http://sbibuilder.shorturl.com/', sLineBreak
  );
end;

procedure PrintUsage;
var
  Line: string;

begin
  Line := StringToOem(
    'Ce programme a pour but de contrôler la Livebox d''Orange en ligne de commande.' +  sLineBreak + 
    'Pour le moment, seule la Livebox d''Inventel est supportée.' + sLineBreak +
    sLineBreak + 
    'Utilisation:' +  sLineBreak + 
    '  ' + PrgName +  ' [/?] [ <ip> <usr> <pwd> [/info|/connect|/disconnect|/renew] [/u] ]' + sLineBreak +
    sLineBreak +
    'où:' +  sLineBreak + 
    sLineBreak +
    'Opérations: ' + sLineBreak +  
    '   /?            Affiche cette aide.' + sLineBreak +
    '   /info         Affiche les informations de connexion.' +  sLineBreak +
    '   /connect      Connecte la Livebox à Internet.' + sLineBreak +
    '   /disconnect   Déconnecte la Livebox d''Internet.' +  sLineBreak +
    '   /renew        Renouvelle l''adresse IP de la Livebox (pour non dégroupés)' + sLineBreak +
    sLineBreak +
    'Options:' + sLineBreak +
    '   /u            Mise à jour du DNS Dynamique (/connect et /renew uniquement)' + sLineBreak +
    sLineBreak +    
    'Pour toutes les opérations, l''<ip>, l''<usr> ainsi que le <pwd> de la ' + sLineBreak +
    'Livebox doivent être spécifiés *AVANT* l''opération proprement dite.'
  );
  WriteLn(Line);
end;

begin
  PrgName := ChangeFileExt(ExtractFileName(ParamStr(0)), '');
  PrintHeader;

  // Affiche l'aide. C'est soit '/?'
  if ParamCount = 0 then begin
    PrintUsage;
    Halt(1);
  end;

  if (ParamCount = 1) then begin
    if ParamStr(1) <> '/?' then begin
      ConsolePrint(
      'ERREUR: L''option "' + ParamStr(1) + '" n''a pas été reconnue.' + sLineBreak +
      '        Tapez "' + PrgName + ' /?" dans la console pour obtenir de l''aide.');
    end else
      PrintUsage;
    Halt(1);
  end;

  if (ParamCount < 3) then begin
    ConsolePrint(
      'ERREUR: Il manque une information de connexion à la Livebox.' + sLineBreak +
      '        Tapez "' + PrgName + ' /?" dans la console pour obtenir de l''aide.'
    );
    Halt(2);
  end;

  if (ParamCount > 5) then begin
    ConsolePrint(
      'AVERTISSEMENT: Les paramètres situés après la dernière commande seront ignorés.' + sLineBreak
    );
  end;

  try
    Livebox := TInventelLiveboxHandler.Create;

    try
      Livebox.Configuration.Host := ParamStr(1);
      Livebox.Configuration.UserName := ParamStr(2);
      Livebox.Configuration.Password := ParamStr(3);

      Temp := '';

      // Pour l'opération à effectuer
      if ParamCount > 3 then
        Temp := UpperCase(ParamStr(4));

      if (Temp = '/INFO') or (Temp = '') then
        Operation := loInfo
      else if Temp = '/CONNECT' then
        Operation := loConnect
      else if Temp = '/DISCONNECT' then
        Operation := loDisconnect
      else if Temp = '/RENEW' then
        Operation := loRenew
      else
        Operation := loInvalid;

      // Pour la mise à jour du DNS
      if ParamCount > 4 then
        if (UpperCase(ParamStr(5)) = '/U') then begin
          if (Operation = loConnect) or (Operation = loRenew) then begin
            ConsolePrint('Mise à jour du DNS activée.');
            Livebox.UpdateDynDNS := True;            
          end else
            ConsolePrint('AVERTISSEMENT: Le paramètre "' + ParamStr(5) + '" n''est pas utile. Ignoré.');
        end else
          ConsolePrint('AVERTISSEMENT: Le paramètre "' + ParamStr(5) + '" n''est pas reconnu. Ignoré.');

      // Effectuer l'opération
      case Operation of
        loInfo        : PrintLiveboxInfos;

        loConnect     : begin
                          ConsolePrint('Transmission de la demande de connexion à Internet...');
                          case Livebox.Connect of
                            crSuccess:
                              ConsolePrint('La demande de connexion a été transmise avec succès à la Livebox.');
                            crFailConnect:
                              UnableToContactLivebox;
                            crFailDNSUpdate:
                              ConsolePrint('La demande de connexion a été transmise, mais impossible de mettre à' + sLineBreak +
                                'jour le DNS Dynamique.');
                          end;
                        end;

        loDisconnect  : begin
                          ConsolePrint('Transmission de la demande de déconnexion d''Internet...');
                          if Livebox.Disconnect then
                            ConsolePrint('La demande de déconnexion a été transmise avec succès à la Livebox.')
                          else
                            UnableToContactLivebox;
                        end;

        loRenew       : begin
                          ConsolePrint('Transmission de la demande de renouvellement de l''adresse IP...');
                          case  Livebox.RenewIP of
                            crSuccess:
                              ConsolePrint('La demande de renouvellement d''adresse IP a été transmise avec succès à la '
                                + sLineBreak + 'Livebox.');
                            crFailConnect:
                              UnableToContactLivebox;
                            crFailDNSUpdate:
                              ConsolePrint('La demande de reconnexion a été transmise, mais impossible de mettre à' + sLineBreak +
                                'jour le DNS Dynamique.');
                          end;

                        end;

        loInvalid     : ConsolePrint(
                          'ERREUR: La commande "' + ParamStr(4) + '" est inconnue.' + sLineBreak +
                          '        Tapez "' + PrgName + ' /?" dans la console pour obtenir de l''aide.'
                        );
      end;
    finally
      Livebox.Free;
    end;

  except
    on E:Exception do
      Writeln('ERREUR GENERALE: ', E.Classname, ': ', E.Message);
  end;
end.
