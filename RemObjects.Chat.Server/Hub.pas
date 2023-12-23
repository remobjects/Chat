namespace RemObjects.Chat.Server;

uses
  RemObjects.Infrastructure,
  RemObjects.Chat;

type
  Hub = public class
  public

    property Clients := new Dictionary<Guid,HubClient>;
    property Chats := new Dictionary<Guid,HubChat>;
    property Messages := new Dictionary<Guid,HubMessage>;

    method FindUser(aChatID: Guid): nullable HubUser;
    begin

    end;

    method FindGroupChat(aChatID: Guid): nullable HubGroupChatInfo;
    begin

    end;

    method FindChat(aChatID: not nullable Guid): HubChat;
    begin
      result := Chats[aChatID];
      if not assigned(result) then begin

        var lUser := FindUser(aChatID);
        if assigned(lUser) then begin
          result := new HubPrivateChat(Hub := self, ChatID := lUser.ID, UserID := lUser.ID);
          Chats[lUser.ID] := result;
          exit;
        end;

        var lGroupChat := FindGroupChat(aChatID);
        if assigned(lGroupChat) then begin
          result := new HubGroupChat(Hub := self, ChatID := lGroupChat.ID);
          Chats[lUser.ID] := result;
          exit;
        end;

        result := new HubPrivateChat(Hub := self, ChatID := aChatID, UserID := aChatID); {$HINT for now}

      end;
    end;

    method FindClient(aUserID: Guid): HubClient;
    begin
      result := Clients[aUserID];
      if not assigned(result) then begin


        raise new Exception($"unknown user/client id {aUserID}.");

      end;
    end;

    method FindMessage(aPackage: not nullable Package): not nullable HubMessage;
    begin
      result := Messages[aPackage.MessageID];
      if not assigned(result) then
        raise new Exception("Message '{aPackage.MessageID}' not found");
    end;

    method SaveMessage(aMessage: not nullable HubMessage);
    begin
      Messages[aMessage.ID] := aMessage;
    end;

    //

    method SendPackage(aUserID: Guid; aPackage: Package);
    begin
      var lClient := FindClient(aUserID);
      lClient.SendPackage(aPackage);
    end;

  end;

  HubClient = public class(BaseClient)
  public

    property Hub: not nullable Hub; required;

  protected

    method OnReceivePackage(aPackage: Package); override;
    begin
      try
        aPackage.SenderID := UserID;
        var lChat := Hub.FindChat(aPackage.ChatID);
        if not assigned(lChat) then
          raise new Exception($"Received {aPackage.Type} package for unknown chat {aPackage.ChatID}");
        lChat.OnReceivePackage(aPackage);
      except
        on E: Exception do
          Log($"{E.Message}");
      end;
    end;

  end;

  HubChat = public abstract class
  public

    property Hub: weak not nullable Hub; required;
    property ChatID: not nullable Guid; required;

    property AllUserIDs: sequence of Guid read; abstract;

    method CreateMessage(aPackage: not nullable Package): not nullable HubMessage;
    begin
      result := new HubMessage(OriginalPackage := aPackage,
                               Received := DateTime.UtcNow);
      Hub.SaveMessage(result);
      //raise new NotImplementedException("CreateMessage"); {$HINT for now}
    end;

    method DeliverMessage(aMessage: HubMessage) ToAllBut(aAllButUserID: nullable Guid);
    begin
      var lPackage := aMessage.OriginalPackage;
      for each u in AllUserIDs do
        if u ≠ aAllButUserID then
          Hub.FindClient(u).Queue.Send(lPackage);
    end;

    //
    // Incoming packages
    //

    method OnReceivePackage(aPackage: Package);
    begin
      case aPackage.Type of
        PackageType.Message: begin
            var lMessage := CreateMessage(aPackage);
            Log($"Server: New message received: {lMessage}");
            DeliverMessage(lMessage) ToAllBut(aPackage.SenderID);
            SendStatusResponse(lMessage, Guid.Empty, PackageType.Received, DateTime.UtcNow);
          end;
        PackageType.Received: raise new Exception("Should not happen on server");
        PackageType.Delivered,
        PackageType.Decrypted,
        PackageType.FailedToDecrypt,
        PackageType.Displayed,
        PackageType.Read: begin
            Log($"Server: New status received for {aPackage.MessageID}: {aPackage.Type}");
            NotifyStatus(aPackage);
          end;
      end;
    end;

    //

    method NotifyStatus(aPackage: Package);
    begin
      var lMessage := Hub.FindMessage(aPackage);
      case aPackage.Type of
        PackageType.Received: ;{no-op}
        PackageType.Delivered: lMessage.Delivered := aPackage.Sent;
        PackageType.Decrypted: lMessage.Decryted := aPackage.Sent;
        PackageType.FailedToDecrypt: ;
        PackageType.Displayed: lMessage.Displayed := aPackage.Sent;
        PackageType.Read: lMessage.Read := aPackage.Sent;
        else raise new Exception($"Unexpected package type {aPackage.Type}");
      end;
      SendStatusResponse(lMessage, aPackage.SenderID, aPackage.Type, aPackage.Sent);
    end;

    method SendStatusResponse(aMessage: HubMessage; aSenderID: not nullable Guid; aStatus: PackageType; aDate: DateTime);
    begin
      var lPackage := new Package(&Type := aStatus,
                                  SenderID := aSenderID,
                                  ChatID := ChatID,
                                  MessageID := aMessage.ID,
                                  Payload := new StatusPayload(Status := aStatus,
                                                               Date := DateTime.UtcNow));
      Hub.SendPackage(aMessage.SenderID, lPackage);
    end;


  end;

  HubPrivateChat = public class(HubChat)
  public
    property UserID: nullable Guid; required;
    property AllUserIDs: sequence of Guid read [UserID]; override;
  end;

  HubGroupChat = public class(HubChat)
  public
    property UserIDs: List<Guid>;
    property AllUserIDs: sequence of Guid read UserIDs; override;
  end;

  HubMessage = public class
  public

    property OriginalPackage: not nullable Package; required;
    property Received: not nullable DateTime; required;
    property Delivered: nullable DateTime;
    property Decryted: nullable DateTime;
    property Displayed: nullable DateTime;
    property &Read: nullable DateTime;

    property ID: not nullable Guid read OriginalPackage.MessageID;
    property SenderID: not nullable Guid read OriginalPackage.SenderID;
    property ChatID: not nullable Guid read OriginalPackage.ChatID;

    [ToString]
    method ToString: String; override;
    begin
      result := $"Message from {SenderID} to {ChatID}. {length((OriginalPackage.Payload as MessagePayload).EncryptedMessage)} bytes."
    end;

  end;

  HubUser = public class
  public
    property ID: not nullable Guid; required;
  end;

  HubGroupChatInfo = public class
  public
    property ID: not nullable Guid; required;
  end;

end.