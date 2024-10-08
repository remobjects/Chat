﻿namespace RemObjects.Chat.Connection;

uses
  RemObjects.InternetPack,
  RemObjects.Infrastructure,
  RemObjects.Chat;

type
  IPChatClient = public class(Client, ITwoWayQueueEndpoint<Package>)
  public

    property UserID: Guid; required;

    method ConnectToChat(aHostName: not nullable String; aPort: Integer; aAuthenticationCode: Guid);
    begin
      Logging.Connection($"> ConnectToChat");
      //HostName := aHostName;
      //Port := aPort;
      var lConnection := ConnectNew(aHostName, aPort);
      fChatConnection := new IPChatConnection(self, lConnection);
      //if fChatConnection.SendAuthentication(UserID, aAuthenticationCode) then begin
      try
        fChatConnection.SendAuthentication(UserID, aAuthenticationCode);
        fChatConnection.OnDisconnect := () -> DisconnectFromChat;
        fChatConnection.OnAck := (aChunkID) -> begin
          Logging.Connection($"+ Successfully sent package with Chunk ID {aChunkID}");
          PackageStore.RemovePackage(aChunkID);
        end;
        fChatConnection:OnNak := (aChunkID, aError) -> begin
          Logging.Connection($"- Failed to sent package with Chunk ID {aChunkID}");
          PackageStore.PackagesByChunk[aChunkID] := nil; // remove chunk but keep the package
        end;
        Logging.Connection($"+ ConnectedToChat");
        ConnectedToChat;
      except
        on E: Exception do begin
          Logging.Error($"Exception while connecting to chat: {E}");
          Logging.Connection($"- DisconnectFromChat");
          DisconnectFromChat;
          raise;
        end;
      end;
    end;

    var fIsConnected: Boolean; private;

    method ConnectedToChat;
    begin
      Logging.Connection($"ConnectedToChat");
      fIsConnected := true;
      if assigned(OnConnect) then
        OnConnect();
      SendStoredPackages;
    end;

    method DisconnectFromChat;
    begin
      Logging.Connection($"DisconnectFromChat");
      var lWasConnected := fIsConnected;
      fIsConnected := false;
      fChatConnection:OnAck := nil;
      fChatConnection:OnNak := nil;
      fChatConnection:OnDisconnect := nil;
      fChatConnection:DataConnection:Close;
      fChatConnection:Dispose;
      fChatConnection := nil;
      if lWasConnected and assigned(OnDisconnect) then
        OnDisconnect();
    end;

    property OnConnect: block;
    property OnDisconnect: block;

    property PackageStore: PackageStore;

  assembly

    method ReceivePackage(aConnection: not nullable IPChatConnection; aPackage: not nullable Package);
    begin
      Logging.Connection($"ReceivePackage");
      Receive(aPackage);
    end;

  private

    method Send(aPackage: not nullable Package); locked on self;
    begin
      Logging.Connection($"Sending new package");
      PackageStore.SavePackage(aPackage);
      Logging.Connection($"{coalesce(PackageStore.Count, "unknown number of")} total package(s) pending, has connection? {assigned(fChatConnection)}");
      if assigned(fChatConnection) then begin
        fChatConnection.SendPackage(aPackage) begin
          Logging.Connection($"Saving initial Chunk ID {aChunkID} for package {aPackage.ID}");
          PackageStore.PackagesByChunk[aChunkID] := aPackage;
        end;
      end;
    end;

    method SendStoredPackages; locked on self;
    begin
      Logging.Connection($"SendStoredPackages");
      if not assigned(fChatConnection) then
        exit;

      var lPackages := PackageStore.Snapshot;
      Logging.Connection($"lPackages.Count {lPackages.Count}");
      if lPackages.Count = 0 then
        exit;

      Logging.Connection($"Sending {lPackages.Count} older package(s)");
      for each p in lPackages do begin
        if not assigned(fChatConnection) then
          break;

        fChatConnection.SendPackage(p) begin
          Logging.Connection($"Saving new Chunk ID {aChunkID} for package {p.ID}");
          PackageStore.PackagesByChunk[aChunkID] := p; {$HINT might add dupe chunk ids, but no biggie}
        end;

      end;
    end;

    property Receive: block(aPacket: not nullable Package);

    var fChatConnection: IPChatConnection;

  end;

end.