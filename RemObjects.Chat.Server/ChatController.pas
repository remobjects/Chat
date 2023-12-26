namespace RemObjects.Chat.Server;

uses
  RemObjects.Chat;

type
  ChatController = public class(IChatControllerProxy)
  public

    class property Instance := new ChatController; readonly;

    method CreatePrivateChat(aUserID1: not nullable Guid; aUserID2: not nullable Guid): not nullable ChatInfo;
    begin
      if aUserID1 = aUserID2 then
        raise new Exception($"User IDs for provatwe chat cannot match.");
      var lChat := ChatManager.ActiveChatManager.FindPrivateChat(aUserID1, aUserID2);
      if not assigned(lChat) then begin
        lChat := new PrivateChatInfo(ID := Guid.NewGuid, UserIDs := [aUserID1, aUserID2].ToList as not nullable);
        ChatManager.ActiveChatManager.AddChat(lChat);
      end;
      result := lChat as not nullable;
    end;

    method CreateGroupChat(aName: nullable String; aUsers: not nullable array of not nullable Guid; aPublicKey: array of Byte): not nullable ChatInfo;
    begin
      result := new GroupChatInfo(ID := Guid.NewGuid, Name := aName, UserIDs := aUsers.ToList as not nullable, PublicKey := aPublicKey);
      ChatManager.ActiveChatManager.AddChat(result);
    end;

    method FindChat(aChatID: not nullable Guid): nullable ChatInfo;
    begin
      result := ChatManager.ActiveChatManager.FindChat(aChatID);
    end;

    method AddUserToGroupChat(aChatID: Guid; aUser: not nullable Guid);
    begin
      ChatManager.ActiveChatManager.AddUserToGroupChat(aChatID, aUser);
    end;

    method RemoveUserFromGroupChat(aChatID: Guid; aUser: not nullable Guid);
    begin
      ChatManager.ActiveChatManager.RemoveUserFromGroupChat(aChatID, aUser);
    end;

    method DeleteChat(aChatID: Guid);
    begin
      ChatManager.ActiveChatManager.RemoveChat(aChatID);
    end;

    method FindUser(aUserID: not nullable Guid): nullable UserInfo;
    begin
      result := ChatManager.ActiveChatManager.FindUser(aUserID);
    end;

  private

    constructor; empty;

  end;

end.