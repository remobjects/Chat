namespace RemObjects.Chat.Connection;

uses
  RemObjects.InternetPack;

type
  IPChatClient = public class(Client)
  public

    method ConnectToChat(aHostName: String; aPort: Integer; aAuthenticatinCode: Guid);
    begin
      var lConnection := Connect(aHostName, aPort);
      fChatConnection := new IPChatConnection(self, lConnection);
      fChatConnection.SendAuthentication(aAuthenticatinCode);
    end;

    method DisconnectFromChat;
    begin
      fChatConnection.DataConnection.Close;
      fChatConnection:Dispose;
      fChatConnection := nil;
    end;

  private

    var fChatConnection: IPChatConnection;

  end;

end.