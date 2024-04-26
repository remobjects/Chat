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
      fChatConnection.OnDisconnect := () -> DisconnectFromChat;
    end;

    method DisconnectFromChat;
    begin
      Log($"DisconnectFromChat");
      fChatConnection:DataConnection:Close;
      fChatConnection:Dispose;
      fChatConnection := nil;
    end;

  assembly

    method ReceivePackage(aConnection: not nullable IPChatConnection; aPackage: not nullable Package);
    begin
      Receive(aPackage);
    end;

  private

    method Send(aPackage: not nullable Package);
    begin
      Log($"Sending new package");
      locking fPackages do
        fPackages.Add(aPackage);
      //fPackagesByID[aPackage.ID] := aPackage;
      Log($"{fPackages.Count} packages pending, has connection? {assigned(fChatConnection)}");
      if assigned(fChatConnection) then begin
        fChatConnection.SendPackage(aPackage) begin
          if aSuccess then begin
            locking fPackages do
              fPackages.Remove(aPackage);
          end
          else begin
            Log($"ToDo: messages failed to send. what next?");
          end;
        end;
      end;
    end;

    property Receive: block(aPacket: not nullable Package);

    var fChatConnection: IPChatConnection;
    var fPackages := new List<Package>;
    //var fPackagesByID := new Dictionary<Guid,Package>;

  end;

end.