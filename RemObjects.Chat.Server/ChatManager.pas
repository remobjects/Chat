namespace RemObjects.Chat.Server;

uses
  RemObjects.Infrastructure,
  RemObjects.Chat;

type
  ChatManager = public abstract class
  public

    [ErrOnNilAccess("Chat Manager has not been initialized.")]
    class property ActiveChatManager: ChatManager;

    method FindChat(aChatID: not nullable Guid): nullable ChatInfo; abstract;
    method FindPrivateChat(aUser1: not nullable Guid; aUser2: not nullable Guid): nullable PrivateChatInfo; abstract;

    method AddChat(aChat: ChatInfo); abstract;
    method RemoveChat(aChatID: not nullable Guid); abstract;

    method AddUserToGroupChat(aChatID: not nullable Guid; aUser: not nullable Guid); abstract;
    method RemoveUserFromGroupChat(aChatID: not nullable Guid; aUser: not nullable Guid); abstract;

    method FindUser(aUserID: not nullable Guid): UserInfo; abstract;

    method MessageReceived(aChat: HubChat; aSenderID: Guid; aMessage: HubMessage); abstract;

    property ChatAuthentications := new Cache<Guid,Guid>(OneTimeAccess := true);

    method SendLocalMessage(aSenderID: not nullable Guid; aPayloadJson: JsonNode) ToChat(aChatID: not nullable Guid);
    begin
      var lMessage := new RemObjects.Chat.MessageInfo;
      lMessage.SenderID := aSenderID;
      lMessage.ChatID := aChatID;
      lMessage.ID := Guid.NewGuid;
      lMessage.Payload := aPayloadJson;
      SendLocalMessage(lMessage);
    end;

    method SendLocalMessage(aMessage: not nullable MessageInfo);
    begin
      //var lChat := if assigned(aChatInfo) then FindChat(aChatInfo) else FindChat(aMessage.ChatID);
      //var lEncryptedMessage := EncryptMessage(aMessage, lChat);
      var lEncryptedMessage := new MessagePayload unencryptedWithMessage(aMessage);

      var lPackage := new Package(&Type := PackageType.Message,
                                  ID := Guid.NewGuid,
                                  SenderID := aMessage.SenderID,
                                  ChatID := aMessage.ChatID,
                                  MessageID := aMessage.ID,
                                  Sent := coalesce(aMessage.Sent, DateTime.UtcNow),
                                  Payload := lEncryptedMessage);
      SendLocalPackage(lPackage);
    end;

    method SendLocalPackage(aPackage: Package);
    begin
      var lChat := Hub.Instance.FindChat(aPackage.ChatID, true);
      if assigned(lChat) then begin

        var lMessage := lChat.CreateMessage(aPackage);
        Logging.Delivery($"Server: New message generated locally: {lMessage}, {aPackage.Sent}");
        lChat.DeliverMessage(lMessage);
        ChatManager.ActiveChatManager.MessageReceived(lChat, aPackage.SenderID, lMessage);

      end;
    end;

  end;

  InMemoryChatManager = public class(ChatManager)
  public

    method FindChat(aChatID: not nullable Guid): nullable ChatInfo; override;
    begin
      result := fChats[aChatID];
    end;

    method FindPrivateChat(aUser1: not nullable Guid; aUser2: not nullable Guid): nullable PrivateChatInfo; override;
    begin
      for each v in fChats.Values do
        if (v is PrivateChatInfo) and (v.UserIDs.Count = 2) then
          if ((v.UserIDs[0] = aUser1) and (v.UserIDs[1] = aUser2)) or
             ((v.UserIDs[0] = aUser2) and (v.UserIDs[1] = aUser1)) then
            exit v as PrivateChatInfo;
    end;

    method AddChat(aChat: ChatInfo); override;
    begin
      fChats[aChat.ID] := aChat;
    end;

    method RemoveChat(aChatID: not nullable Guid); override;
    begin
      fChats[aChatID] := nil;
    end;

    method AddUserToGroupChat(aChatID: not nullable Guid; aUserID: not nullable Guid); override;
    begin
      var lChat := fChats[aChatID];
      if not assigned(lChat) then
        raise new Exception($"Chat '{aChatID}' not found.");
      if lChat is not GroupChatInfo then
        raise new Exception($"Chat '{aChatID}' is not a group chat.");
      if lChat.UserIDs.Contains(aUserID) then
        raise new Exception($"user {aUserID} is already a member of chat '{aChatID}'.");
      lChat.UserIDs.Add(aUserID);
    end;

    method RemoveUserFromGroupChat(aChatID: not nullable Guid; aUserID: not nullable Guid); override;
    begin
      var lChat := fChats[aChatID];
      if not assigned(lChat) then
        raise new Exception($"Chat '{aChatID}' not found.");
      if lChat is not GroupChatInfo then
        raise new Exception($"Chat '{aChatID}' is not a group chat.");
      if not lChat.UserIDs.Contains(aUserID) then
        raise new Exception($"user {aUserID} is not a member of chat '{aChatID}'.");
      lChat.UserIDs.Remove(aUserID);
      if lChat.UserIDs.Count = 0 then
        RemoveChat(aChatID);
    end;

    method FindUser(aUserID: not nullable Guid): UserInfo; override;
    begin
      result := fUsers[aUserID];
    end;

    method MessageReceived(aChat: HubChat; aSenderID: Guid; aMessage: HubMessage); override;
    begin
      Logging.Delivery($"Message Received: {aMessage}");
    end;

    method __AddUser(aUser: UserInfo);
    begin
      fUsers[aUser.ID] := aUser;
    end;

  private

    var fChats := new Dictionary<Guid,ChatInfo>;
    var fUsers := new Dictionary<Guid,UserInfo>;

  end;

end.