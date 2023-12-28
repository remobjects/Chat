namespace RemObjects.Chat.Connection;

uses
  RemObjects.InternetPack,
  RemObjects.Chat;

type
  IIPChatServer = public interface(Server)
  public

    method AuthenticateConnection(aConnection: not nullable IPChatConnection; aUserID: not nullable Guid; aAuthenticationCode: not nullable Guid): Boolean; abstract;
    method ReceivePackage(aConnection: not nullable IPChatConnection; aPackage: not nullable Package): Boolean; abstract;

  end;

end.