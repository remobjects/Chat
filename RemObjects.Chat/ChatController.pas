namespace RemObjects.Chat;

type
  IChatControllerProxy = public interface
    method FindChat(aChatID: not nullable Guid): nullable ChatInfo;
    method FindUser(aUserID: not nullable Guid): nullable UserInfo;
  end;

end.