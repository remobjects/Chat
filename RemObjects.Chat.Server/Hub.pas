namespace RemObjects.Chat.Server;

uses
  RemObjects.Infrastructure,
  RemObjects.Chat;

type
  Hub = public class
  public

    property Clients := new Dictionary<Guid,HubClient>;
    property Chats := new Dictionary<Guid,HubChat>;

    method FindUser(aChatID: Guid): nullable HubUser;
    begin

    end;

    method FindGroupChat(aChatID: Guid): nullable HubGroupChatInfo;
    begin

    end;

    method FindChat(aChatID: Guid): HubChat;
    begin
      result := Chats[aChatID];
      if not assigned(result) then begin

        var lUser := FindUser(aChatID);
        if assigned(lUser) then begin
          result := new HubPrivateChat(Hub := self, ChatID := lUser.ID, User := lUser);
          Chats[lUser.ID] := result;
          exit;
        end;

        var lGroupChat := FindGroupChat(aChatID);
        if assigned(lGroupChat) then begin
          result := new HubGroupChat(Hub := self, ChatID := lGroupChat.ID);
          Chats[lUser.ID] := result;
          exit;
        end;

        result := new HubChat(Hub := self, ChatID := aChatID); {$HINT for now}

      end;
    end;

    method FindClient(aUserID: Guid): HubClient;
    begin
      result := Clients[aUserID];
      if not assigned(result) then begin


        raise new Exception($"unknown user/client id {aUserID}.");

      end;
    end;

    //

    method SendPackage(aUserID: Guid; aPackage: Package);
    begin
      var lClient := FindClient(aUserID);
      lClient.SendPackage(aPackage);
    end;

  end;

  HubClient = public class
  public

    property Hub: not nullable Hub; required;
    property UserID: not nullable Guid; required;
    property Queue: ITwoWayQueueEndpoint<Package> read fQueue write SetQueue;

    method SendPackage(aPackage: Package);
    begin
      fQueue.Send(aPackage);
    end;

  private

    fQueue: ITwoWayQueueEndpoint<Package>;

    method SetQueue(aValue: ITwoWayQueueEndpoint<Package>);
    begin
      fQueue:Receive := nil;
      fQueue := aValue;
      fQueue:Receive := @OnReceivePackage;
    end;

    method OnReceivePackage(aPackage: Package);
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

  HubChat = public class
  public

    property Hub: weak not nullable Hub; required;
    property ChatID: not nullable Guid; required;

    method CreateMessage(aPackage: not nullable Package): not nullable HubMessage;
    begin
      result := new HubMessage(OriginalPackage := aPackage,
                               Received := DateTime.UtcNow);
      //raise new NotImplementedException("CreateMessage"); {$HINT for now}
    end;

    method FindMessage(aPackage: Package): not nullable HubMessage;
    begin
      raise new Exception($"Message {aPackage.MessageID} not found"); {$HINT for now}
    end;

    method DeliverMessgage(aMessage: HubMessage) ToAllBut(aUserID: Guid);
    begin
      //
    end;

    method NotifyStatus(aPackage: Package);
    begin
      var lMessage := FindMessage(aPackage);
      case aPackage.Type of

        PackageType.Received: lMessage.Delivered := aPackage.Sent;
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

    method OnReceivePackage(aPackage: Package);
    begin
      case aPackage.Type of
        PackageType.Message: begin
            var lMessage := CreateMessage(aPackage);
            Log($"New message received: {lMessage}");
            SendStatusResponse(lMessage, Guid.Empty, PackageType.Received, DateTime.UtcNow);
            DeliverMessgage(lMessage) ToAllBut(aPackage.SenderID);
          end;
        PackageType.Delivered:; {should not happen on server}
        PackageType.Received,
        PackageType.Decrypted,
        PackageType.FailedToDecrypt,
        PackageType.Displayed,
        PackageType.Read: begin
            NotifyStatus(aPackage);
          end;
      end;
    end;


  end;

  HubPrivateChat = public class(HubChat)
  public
    property User: HubUser;
  end;

  HubGroupChat = public class(HubChat)
    property Users: List<HubUser>;
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