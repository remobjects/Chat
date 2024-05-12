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
      async try
        Work;
        Dispose;
      except
        on E: Exception do
          Log($"Exception on connection thread: {E}");
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

    //property OnConnect: block(aConnection: IPChatConnection);
    property OnDisconnect: block(aConnection: IPChatConnection);

    method Work;
    begin
      try
        while DataConnection.ReadUInt16LE(out var lType) do begin
          Log($"Incoming packet of type ${Convert.ToHexString(lType, 4)}.");
          case lType of
            $0000: ReadChunk;
            $1111: ReadAck;
            $6666: ReadNak;
            $316, $4547: raise new ChatException($"This is not a HTTP Server.");
            else raise new ChatException($"Unexpected package kind {Convert.ToHexString(lType)}.");
          end;
          //Log($"done work loop");
        end;
        Log(if IsServer then $"Client {UserID} disconnected" else $"Server closed the connection");
      finally
        Disconnected := true;
        if assigned(OnDisconnect) then
          OnDisconnect(self);
      except
        on E: Exception do begin
          Log($"Exception in ChatConnection.Work: {E}");
        end;
      end;
    end;

    //
    //
    //

    method ReadChunk;
    begin
      if DataConnection.ReadUInt32LE(out var lChunkID) then begin
        //if not PackageWasHandled[lChunkID] then begin
        try
          if DataConnection.ReadByte(out var lType) then begin
            if DataConnection.ReadUInt32LE(out var lSize) then begin
              if lSize > MaxPackageSize then
                raise new ChatException($"Package exceeds maximum size {Convert.ToHexString(lSize)} > {Convert.ToHexString(MaxPackageSize)}.");
              case lType of
                TYPE_AUTH: ReadAuthentication(lChunkID, lSize);
                TYPE_PACKAGE: ReadPackage(lChunkID, lSize);
                else raise new ChatException($"Unexpected package type {lType}.");
              end;
            end;
          end;
          if not DataConnection.ReadUInt16LE(out var lEtx) then
            raise new ChatException($"Comnection closed reading end pf package marker.");
          if lEtx ≠ $ffff then
            raise new ChatException($"Expected end of package marker, received {Convert.ToHexString(lEtx)}.");
          SendAck(lChunkID);
        except
          on E: Exception do begin
            Log($"E {E}");
            SendNak(lChunkID, E.Message);
            DataConnection.Close;
          end;
        end;
        //PackageWasHandled[lChunkID] := true;
      //end
      //else begin
        //if DataConnection.ReadUInt8(out var lType) then begin
          //if DataConnection.ReadUInt32LE(out var lSize) then begin
      //end;
      end;
    end;

    //

    method ReadAuthentication(aChunkID: UInt64; aSize: UInt32);
    begin
      Log($"ReadAuthentication #{aChunkID}");
      if not assigned(Server) then
        raise new ChatException($"Unexpected Package type {TYPE_AUTH} for client.");
      if aSize ≠ Guid.Size*2 then
        raise new ChatException($"Unexpected Package size for this request {Convert.ToHexString(aSize)} ≠ {Guid.Size*2}.");
      if not DataConnection.ReadGuid(out var lUserID) then
        raise new ChatException($"Unexpected Package size for this request.");
      if not DataConnection.ReadGuid(out var lAuthentcationToken) then
        raise new ChatException($"Unexpected Package size for this request.");

      if not Server.AuthenticateConnection(self, lUserID, lAuthentcationToken) then
        raise new Exception($"Authentication failed");
        //DataConnection.Close;
      UserID := lUserID;
    end;

    method ReadPackage(aChunkID: UInt64; aSize: UInt32);
    begin
      Log($"ReadPackage #{aChunkID} size {Convert.ToHexString(aSize)}");
      var lBytes := new Byte[aSize];
      var lOffset := 0;
      while lOffset < aSize do begin
        var lRead := DataConnection.Read(lBytes, lOffset, aSize-lOffset);
        if lRead = 0 then
          exit;
        inc(lOffset, lRead);
      end;
      var lPackage := new Package withByteArray(lBytes);
      ReceivePackage(lPackage);
    end;

    method ReadAck;
    begin
      if DataConnection.ReadUInt32LE(out var lChunkID) then
        if not DataConnection.ReadUInt16LE(out var lEtx) then
          if lEtx ≠ $2222 then
            raise new ChatException($"Expected end of package marker, received {Convert.ToHexString(lEtx)}.");
      //Log($"Got ACK");
      Ack(lChunkID);
    end;

    method ReadNak;
    begin
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
          Log($"Got NAK with error message: '{lError}'");
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

    method SendAuthentication(aUserID: Guid; aAuthenticationCode: Guid; aTimeout: TimeSpan := TimeSpan.FromSeconds(10)): Boolean; locked on self;
    begin
      //Log($"SendAuthentication");
      DataConnection.WriteUInt16LE($0000);
      var lChunkID := NextID;
      DataConnection.WriteUInt32LE(lChunkID);
      DataConnection.WriteByte(TYPE_AUTH);
      DataConnection.WriteUInt32LE(Guid.Size*2);
      DataConnection.WriteGuid(aUserID);
      DataConnection.WriteGuid(aAuthenticationCode);
      DataConnection.WriteUInt16LE($ffff);
      //Log($"SendAuthentication: waiting");
      result := WaitForResponse(lChunkID, aTimeout);
      //Log($"SendAuthentication: {result}");
    end;

    method SendPackage(aPackage: Package; aCallback: block(aSuccess: Boolean; aError: nullable String)); locked on self;
    begin
      if IsClient then Log($"SendPackage {aPackage.ID} to chat {aPackage.ChatID}");
      //Log(if IsServer then $"SendPackage {aPackage.Type} to user {UserID} via {DataConnection}" else $"SendPackage {aPackage.Type}");
      DataConnection.WriteUInt16LE($0000);
      var lChunkID := NextID;

      if assigned(aCallback) then async begin
        var lSuccess := WaitForResponse(lChunkID, TimeSpan.FromSeconds(PACKAGE_WAIT_TIMEOUT), out var lError);
        aCallback(lSuccess, lError);
      end;

      DataConnection.WriteUInt32LE(lChunkID);
      DataConnection.WriteByte(TYPE_PACKAGE);
      var lBytes := aPackage.ToByteArray;
      DataConnection.WriteUInt32LE(length(lBytes));
      DataConnection.Write(lBytes);
      DataConnection.WriteUInt16LE($ffff);
    end;

    method SendAck(aChunkID: UInt32); locked on self;
    begin
      Log($"SendAck");
      DataConnection.WriteUInt16LE($1111);
      DataConnection.WriteUInt32LE(aChunkID);
      DataConnection.WriteUInt16LE($2222);
    end;

    method SendNak(aChunkID: UInt32; aError: String); locked on self;
    begin
      Log($"SendNak");
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
      result := WaitForResponse(aChunkID, aTimeout, out var nil);
    end;

    method WaitForResponse(aChunkID: Integer; aTimeout: TimeSpan; out aErrorMessage: nullable String): Boolean;
    begin
      var lEvent := new &Event withState(false) Mode(EventMode.Manual);

      var lWait := () -> lEvent.Set;

      locking fWaiters do
        fWaiters[aChunkID] := lWait;

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

      if not lEvent.WaitFor(aTimeout) then
        aErrorMessage := $"(timeout after {aTimeout})";

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
      locking fReceivedResponses do begin
        fReceivedResponses[aChunkID] := (true, nil);
        locking fWaiters do begin
          var lWaiter := fWaiters[aChunkID];
          if assigned(lWaiter) then
            lWaiter;
        end;
      end;
    end;

    method Nak(aChunkID: Integer; aErrorMessage: String);
    begin
      locking fReceivedResponses do begin
        fReceivedResponses[aChunkID] := (false, aErrorMessage);
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