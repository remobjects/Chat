namespace RemObjects.Chat.Connection;

uses
  RemObjects.InternetPack,
  RemObjects.Infrastructure,
  RemObjects.Chat;

type
  IPChatClient = public class(Client, ITwoWayQueueEndpoint<Package>)
  public

    property UserID: Guid; required;

    method ConnectToChat(aAuthenticationCode: Guid);
    begin
      var lConnection := Connect;
      fChatConnection := new IPChatConnection(self, lConnection);
      fChatConnection.SendAuthentication(UserID, aAuthenticationCode);
    end;

    method DisconnectFromChat;
    begin
      fChatConnection.DataConnection.Close;
      fChatConnection:Dispose;
      fChatConnection := nil;
    end;

  private

    method Send(aPackage: not nullable Package);
    begin
      fPackages.Add(aPackage);
      fPackagesByID[aPackage.ID] := aPackage;
      if assigned(fChatConnection) then begin
        fChatConnection.SendPackage(aPackage);
      end;
    end;

    property Receive: block(aPacket: not nullable Package);

    var fChatConnection: IPChatConnection;
    var fPackages := new List<Package>;
    var fPackagesByID := new Dictionary<Guid,Package>;

  end;

end.