namespace RemObjects.Chat.Client;

uses
  RemObjects.Chat;

type
  ChatControllerProxy = public abstract class(IChatControllerProxy)
  public

    method FindChat(aChatID: not nullable RemObjects.Elements.RTL.Guid): nullable ChatInfo; abstract;
    method FindUser(aUserID: not nullable RemObjects.Elements.RTL.Guid): nullable UserInfo; abstract;

  end;


end.