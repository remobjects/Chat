namespace RemObjects.Chat.Server;

uses
  RemObjects.Infrastructure,
  RemObjects.Chat;

type
  Hub = public class
  public

    class property Instance := new Hub; lazy; readonly;

    property Clients := new Dictionary<Guid,HubClient>;
    property Chats := new Dictionary<Guid,HubChat>;
    property Messages := new Dictionary<Guid,HubMessage>;

    method FindUser(aChatID: Guid): nullable HubUser;
    begin

    end;

    method FindChat(aChatID: not nullable Guid): HubChat;
    begin
      result := Chats[aChatID];
      if not assigned(result) then begin
        var lChatInfo := ChatController.Instance.FindChat(aChatID);
        if not assigned(lChatInfo) then
          raise new Exception($"Chat '{aChatID}' not found.");
        result := new HubChat(self, lChatInfo);
      end;
    end;

    method FindClient(aUserID: Guid): HubClient;
    begin
      result := Clients[aUserID];
      if not assigned(result) then begin

        var lUserInfo := ChatController.Instance.FindUser(aUserID);
        if not assigned(lUserInfo) then
          raise new Exception($"User '{aUserID}' not found.");

        var lQueue := ClientQueueManager.ActiveClientQueueManager.FindClientQueue(aUserID);

        result := new HubClient(Hub := self, User := lUserInfo, Queue := lQueue);
      end;
    end;

    method FindMessage(aPackage: not nullable Package): not nullable HubMessage;
    begin
      result := Messages[aPackage.MessageID];
      if not assigned(result) then
        raise new Exception($"Message '{aPackage.MessageID}' not found.");
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

    method Send(aPackage: not nullable Package);
    begin
      if not assigned(Queue) then
        raise new Exception($"Client {UserID} has no queue.");
      Queue.Send(aPackage);
    end;

    method OnReceivePackage(aPackage: Package); override;
    begin
      try
        Log($"OnReceivePackage(User.ID)");
        aPackage.SenderID := User.ID;
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

end.