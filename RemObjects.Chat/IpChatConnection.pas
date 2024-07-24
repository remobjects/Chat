namespace RemObjects.Chat.Connection;

uses
  RemObjects.InternetPack,
  RemObjects.Chat;

type
  IPChatConnection = public class(IDisposable)
  private
  protected
  public

    property UserID: nullable Guid read private write;

    constructor(aServer: not nullable IIPChatServer; aDataConnection: not nullable Connection);
    begin
      Server := aServer;
      DataConnection := aDataConnection;
    end;

    constructor(aClient: not nullable IPChatClient; aDataConnection: not nullable Connection);
    begin
      Client := aClient;
      UserID := aClient.UserID;
      DataConnection := aDataConnection;
      Logging.Connection($"new IPChatConnection");
      async try
        Work;
        Dispose;
      except
        on E: Exception do
          Logging.Connection($"Exception on connection thread: {E}");
      end;
    end;

    method Dispose;
    begin
      DataConnection:Close;
      DataConnection:Dispose;
    end;

    property IsServer: Boolean read assigned(Server);
    property IsClient: Boolean read assigned(Client);
    property DataConnection: not nullable Connection;

    property Disconnected: Boolean read private write;

    property OnAck: block(aChunkID: Integer);
    property OnNak: block(aChunkID: Integer; aError: String);

    //property OnConnect: block(aConnection: IPChatConnection);
    property OnDisconnect: block(aConnection: IPChatConnection);

    method Work;
    begin
      //Logging.Connection($"> IPChatConnection.Work starts");
      try
        while DataConnection.ReadUInt16LE(out var lType) do begin
          Logging.Connection($"Incoming packet of type ${Convert.ToHexString(lType, 4)}.");
          case lType of
            $0000: ReadChunk;
            $1111: ReadAck;
            $6666: ReadNak;
            $316, $4547: raise new ChatException($"This is not a HTTP Server.");
            else raise new ChatException($"Unexpected packet kind {Convert.ToHexString(lType)}.");
          end;
          //Logging.Connection($"> IPChatConnection.Work loop");
        end;
        Log(if IsServer then $"Client {UserID} disconnected" else $"Server closed the connection");
      finally
        Disconnected := true;
        if assigned(OnDisconnect) then
          OnDisconnect(self);
      except
        on E: Exception do begin
          Logging.Error($"Exception in ChatConnection.Work: {E}");
        end;
      end;
      //Logging.Connection($"< IPChatConnection.Work done");
    end;

    //
    //
    //

    method ReadChunk;
    begin
      Logging.Connection($"ReadChunk");
      try
        if not DataConnection.ReadUInt32LE(out var lChunkID) then
          raise new Exception("Connection closed while reading chunk id");
        Logging.Connection($"lChunkID {lChunkID}");
        try
          if not DataConnection.ReadByte(out var lType) then
            raise new Exception("Connection closed while reading chunk type");
          //Logging.Connection($"lType {lType}");

          if not DataConnection.ReadUInt32LE(out var lSize) then
            raise new Exception("Connection closed while reading chunk size");
          if lSize > MaxPackageSize then
            raise new ChatException($"Package exceeds maximum size {Convert.ToHexString(lSize)} > {Convert.ToHexString(MaxPackageSize)}.");
          //Logging.Connection($"lSize {lSize}");

          case lType of
            TYPE_AUTH: ReadAuthentication(lChunkID, lSize);
            TYPE_PACKAGE: ReadPackage(lChunkID, lSize);
            else raise new ChatException($"Unexpected package type {lType}.");
          end;

          if not DataConnection.ReadUInt16LE(out var lEtx) then
            raise new ChatException($"Connection closed while reading end of package marker.");
          //Logging.Connection($"lEtx {Convert.ToHexString(lEtx)}");
          if lEtx ≠ $ffff then
            raise new ChatException($"Expected end of package marker, received {Convert.ToHexString(lEtx)}.");

          SendAck(lChunkID);

          case lType of
            TYPE_AUTH: Server.PostAuthenticateConnection(self);
          end;

        except
          on E: Exception do begin
            Logging.Error($"Exception reading chunk {lChunkID} {E}");
            SendNak(lChunkID, E.Message);
            DataConnection.Close;
          end;
        end;
      except
        on E: Exception do begin
          Logging.Error($"Exception reading chunk {E}");
          DataConnection.Close;
        end;
      end;
    end;

    //

    method ReadAuthentication(aChunkID: UInt64; aSize: UInt32);
    begin
      Logging.Connection($"ReadAuthentication #{aChunkID}");
      if not assigned(Server) then
        raise new ChatException($"Unexpected Package type {TYPE_AUTH} for client.");
      if (aSize ≠ Guid.Size*2) and (aSize ≠ Guid.Size*2+sizeOf(UInt16)*2) then
        raise new ChatException($"Unexpected Package size for this request {Convert.ToHexString(aSize)} ≠ {Guid.Size*2}.");

      if not DataConnection.ReadGuid(out var lUserID) then
        raise new ChatException($"Unexpected Package size for this request.");
      if not DataConnection.ReadGuid(out var lAuthentcationToken) then
        raise new ChatException($"Unexpected Package size for this request.");

      if (aSize = Guid.Size*2) then begin
        ClientVersion := 1;
        ClientMinVersion := 1;
      end
      else if aSize = Guid.Size*2+sizeOf(UInt16)*2 then begin
        if not DataConnection.ReadUInt16LE(out ClientVersion) then
          raise new ChatException($"Unexpected Package size for this request.");
        if not DataConnection.ReadUInt16LE(out var ClientinVersion) then
          raise new ChatException($"Unexpected Package size for this request.");
      end;

      Log($"ReadAuthentication {lUserID}, token {lAuthentcationToken}");
      if not Server.AuthenticateConnection(self, lUserID, lAuthentcationToken) then
        raise new Exception($"Authentication failed");
      //Logging.Connection($"Authenticated as {lUserID}");
      UserID := lUserID;
    end;

    method ReadPackage(aChunkID: UInt64; aSize: UInt32);
    begin
      Logging.Connection($"ReadPackage #{aChunkID} size {Convert.ToHexString(aSize)}");
      var lBytes := new Byte[aSize];
      var lOffset := 0;
      while lOffset < aSize do begin
        var lRead := DataConnection.Read(lBytes, lOffset, aSize-lOffset);
        if lRead = 0 then
          exit;
        inc(lOffset, lRead);
      end;
      //Logging.Connection($"RECEIVED: {Convert.ToHexString(lBytes, " ", 16)}");
      var lPackage := new Package withByteArray(lBytes);
      ReceivePackage(lPackage);
    end;

    method ReadAck;
    begin
      Logging.Connection($"ReadAck");
      if DataConnection.ReadUInt32LE(out var lChunkID) then
        if not DataConnection.ReadUInt16LE(out var lEtx) then
          if lEtx ≠ $2222 then
            raise new ChatException($"Expected end of package marker, received {Convert.ToHexString(lEtx)}.");
      //Logging.Connection($"Got ACK");
      Ack(lChunkID);
    end;

    method ReadNak;
    begin
      Logging.Connection($"ReadNak");
      if DataConnection.ReadUInt32LE(out var lChunkID) then begin
        if DataConnection.ReadUInt32LE(out var lSize) and (lSize < MaxErrorChunkSize) then begin
          var lBytes := new Byte[lSize];
          var lOffset := 0;
          while lSize > 0 do begin
            var lRead := DataConnection.Read(lBytes, lOffset, lSize);
            dec(lSize, lRead);
            inc(lOffset, lRead);
          end;
          var lError := Encoding.UTF8.GetString(lBytes);
          Logging.Connection($"Got NAK with error message: '{lError}'");
          Nak(lChunkID, lError);
          if not DataConnection.ReadUInt16LE(out var lEtx) then
            if lEtx ≠ $2222 then
              raise new ChatException($"Expected end of package marker, received {Convert.ToHexString(lEtx)}.");
        end;
      end;
    end;

    //
    // Send
    //

    method SendAuthentication(aUserID: Guid; aAuthenticationCode: Guid; aTimeout: TimeSpan := TimeSpan.FromSeconds(10)); locked on self;
    begin
      Logging.Connection($"SendAuthentication {aUserID}");
      DataConnection.WriteUInt16LE($0000);
      var lChunkID := NextID;
      DataConnection.WriteUInt32LE(lChunkID);
      DataConnection.WriteByte(TYPE_AUTH);
      DataConnection.WriteUInt32LE(Guid.Size*2);
      DataConnection.WriteGuid(aUserID);
      DataConnection.WriteGuid(aAuthenticationCode);
      DataConnection.WriteUInt16LE($ffff);
      //Logging.Connection($"SendAuthentication: waiting");
      if not WaitForResponse(lChunkID, aTimeout, out var aError) then
        raise new Exception(aError);
      //Logging.Connection($"SendAuthentication Done");
    end;

    method SendPackage(aPackage: Package; aSaveCallback: block(aChunkID: Integer)); locked on self;
    begin
      Logging.Connection($"SendPackage");
      if IsClient then Logging.Connection($"SendPackage {aPackage.ID} to chat {aPackage.ChatID}");
      //Logging.Connection(if IsServer then $"SendPackage {aPackage.Type} to user {UserID} via {DataConnection}" else $"SendPackage {aPackage.Type}");
      DataConnection.WriteUInt16LE($0000);
      var lChunkID := NextID;

      if assigned(aSaveCallback) then async
        aSaveCallback(lChunkID);

      DataConnection.WriteUInt32LE(lChunkID);
      DataConnection.WriteByte(TYPE_PACKAGE);
      var lBytes := aPackage.ToByteArray;
      //Logging.Connection($"SENDING: {Convert.ToHexString(lBytes, " ", 16)}");
      DataConnection.WriteUInt32LE(length(lBytes));
      DataConnection.Write(lBytes);
      DataConnection.WriteUInt16LE($ffff);
      //Logging.Connection($"SendPackage done");
    end;

    method SendAck(aChunkID: UInt32); locked on self;
    begin
      Logging.Connection($"SendAck");
      DataConnection.WriteUInt16LE($1111);
      DataConnection.WriteUInt32LE(aChunkID);
      DataConnection.WriteUInt16LE($2222);
      //Logging.Connection($"SendAck done");
    end;

    method SendNak(aChunkID: UInt32; aError: String); locked on self;
    begin
      Logging.Connection($"SendNak");
      DataConnection.WriteUInt16LE($6666);
      DataConnection.WriteUInt32LE(aChunkID);
      if length(aError) > 0 then begin
        var lBytes := Encoding.UTF8.GetBytes(aError);
        DataConnection.WriteUInt32LE(length(lBytes));
        DataConnection.Write(lBytes);
      end
      else begin
        DataConnection.WriteUInt32LE(0);
      end;
      DataConnection.WriteUInt16LE($2222);
      //Logging.Connection($"SendNak done");
    end;

    //
    //
    //

    const MaxPackageSize = 512 000;
    const MaxErrorChunkSize = 512;

    const PACKAGE_WAIT_TIMEOUT = 10; // seconds

    const TYPE_AUTH = $01;
    const TYPE_PACKAGE = $02;

    const TYPE_ACK = $81;
    const TYPE_NAK = $82;

    property PackageWasHandled[aChunkID: Int32]: Boolean read false write begin end;

    property Client: nullable IPChatClient;
    property Server: nullable IIPChatServer;

    property ClientVersion: UInt16 read private write;
    property ClientMinVersion: UInt16 read private write;


  private

    var fNextChunkID: Integer;

    method NextID: Integer; inline;
    begin
      {$IF COOPER}
      locking self do begin
        result := fNextChunkID;
        inc(fNextChunkID);
      end;
      {$ELSE}
      result := interlockedInc(var fNextChunkID);
      {$ENDIF}
    end;

    method WaitForResponse(aChunkID: Integer; aTimeout: TimeSpan): Boolean; inline;
    begin
      //Logging.Connection($"WaitForResponse({aTimeout.Seconds}s)");
      result := WaitForResponse(aChunkID, aTimeout, out var nil);
      //Logging.Connection($"got response {result}");
    end;

    method WaitForResponse(aChunkID: Integer; aTimeout: TimeSpan; out aErrorMessage: nullable String): Boolean;
    begin
      var lEvent := new &Event withState(false) Mode(EventMode.Manual);

      var lWait := () -> lEvent.Set;

      locking fWaiters do
        fWaiters[aChunkID] := lWait;

      //Logging.Connection($"WaitForResponse({aChunkID})");

      locking fReceivedResponses do begin
        if assigned(fReceivedResponses[aChunkID]) then begin
          result := fReceivedResponses[aChunkID]:[0];
          if not result then
            aErrorMessage := fReceivedResponses[aChunkID]:[1];
          fReceivedResponses[aChunkID] := nil;
          locking fWaiters do begin
            fWaiters[aChunkID] := nil;
            lEvent.Dispose;
          end;
          exit;
        end;
      end;

      //Logging.Connection($"WaitForResponse2");

      if not lEvent.WaitFor(aTimeout) then begin
        Logging.Connection($"WaitForResponse timeout ({aTimeout}s)");
        aErrorMessage := $"(timeout after {aTimeout}s)";
      end;

      locking fReceivedResponses do begin
        result := fReceivedResponses[aChunkID]:[0];
        if not result then
          aErrorMessage := coalesce(fReceivedResponses[aChunkID]:[1], aErrorMessage);
        fReceivedResponses[aChunkID] := nil;
      end;

      locking fWaiters do begin
        fWaiters[aChunkID] := nil;
        lEvent.Dispose;
      end;
    end;

    method AsyncWaitForResponse(aChunkID: Integer; aTimeout: TimeSpan; aCallback: not nullable block(aSuccess: Boolean; aErrorMesage: String));
    begin
      async begin
        var lSuccess := WaitForResponse(aChunkID, aTimeout, out var lErrorMessage);
        aCallback(lSuccess, lErrorMessage);
      end;
    end;

    property fWaiters := new Dictionary<Integer, block>;
    property fReceivedResponses := new Dictionary<Integer, tuple of (Boolean, String)>;

    method Ack(aChunkID: Integer);
    begin
      Logging.Connection($"Ack({aChunkID})");
      locking fReceivedResponses do begin
        fReceivedResponses[aChunkID] := (true, nil);
        if assigned(OnAck) then
          OnAck(aChunkID);
        locking fWaiters do begin
          var lWaiter := fWaiters[aChunkID];
          if assigned(lWaiter) then
            lWaiter;
        end;
      end;
    end;

    method Nak(aChunkID: Integer; aErrorMessage: String);
    begin
      Logging.Connection($"Nak({aChunkID})");
      locking fReceivedResponses do begin
        fReceivedResponses[aChunkID] := (false, aErrorMessage);
        if assigned(OnNak) then
          OnNak(aChunkID, aErrorMessage);
        locking fWaiters do begin
          var lWaiter := fWaiters[aChunkID];
          if assigned(lWaiter) then
            lWaiter;
        end;
      end;
    end;

    method ReceivePackage(aPackage: not nullable Package);
    begin
      Server:ReceivePackage(self, aPackage);
      Client:ReceivePackage(self, aPackage);
    end;


  end;

end.