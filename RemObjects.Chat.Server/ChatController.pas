﻿namespace RemObjects.Chat.Server;

uses
  RemObjects.Infrastructure.Encryption,
  RemObjects.Chat;

type
  ChatController = public class(IChatControllerProxy)
  public

    class property Instance := new ChatController; readonly;

    method CreatePrivateChat(aUserID1: not nullable Guid; aUserID2: not nullable Guid): not nullable ChatInfo;
    begin
      if aUserID1 = aUserID2 then
        raise new Exception($"User IDs for private chat must not match.");
      var lChat := ChatManager.ActiveChatManager.FindPrivateChat(aUserID1, aUserID2);
      if not assigned(lChat) then begin
        lChat := new PrivateChatInfo(Guid.NewGuid, [aUserID1, aUserID2].ToList as not nullable);
        ChatManager.ActiveChatManager.AddChat(lChat);
      end;
      result := lChat as not nullable;
    end;

    method CreateGroupChat(aName: nullable String; aUsers: not nullable array of not nullable Guid; aKeyPair: nullable KeyPair := nil): not nullable ChatInfo;
    begin
      result := new GroupChatInfo(Guid.NewGuid, aUsers.ToList as not nullable, aName, aKeyPair);
      ChatManager.ActiveChatManager.AddChat(result);
    end;

    method FindChat(aChatID: not nullable Guid): nullable ChatInfo;
    begin
      result := ChatManager.ActiveChatManager.FindChat(aChatID);
    end;

    method AddUserToGroupChat(aChatID: not nullable Guid; aUser: not nullable Guid);
    begin
      ChatManager.ActiveChatManager.AddUserToGroupChat(aChatID, aUser);
    end;

    method RemoveUserFromGroupChat(aChatID: not nullable Guid; aUser: not nullable Guid);
    begin
      ChatManager.ActiveChatManager.RemoveUserFromGroupChat(aChatID, aUser);
    end;

    method DeleteChat(aChatID: not nullable Guid);
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