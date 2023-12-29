namespace RemObjects.Chat.Connection;

uses
  RemObjects.InternetPack,
  RemObjects.Chat;

type
  IPChatConnection = public class(IDisposable)
  private
  protected
  public

    property UserID: Guid read private write;

    constructor(aServer: not nullable IIPChatServer; aDataConnection: not nullable Connection);
    begin
      Server := aServer;
      DataConnection := aDataConnection;
    end;

    constructor(aClient: not nullable IPChatClient; aDataConnection: not nullable Connection);
    begin
      Client := aClient;
      DataConnection := aDataConnection;
    end;

    method Dispose;
    begin
      DataConnection:Close;
      DataConnection:Dispose;
    end;

    property DataConnection: not nullable Connection;

    method Work;
    begin
      while DataConnection.ReadUInt16LE(out var lType) do begin
        Log($"lType {Convert.ToHexString(lType)}");
        case lType of
          $0000: ReadMessage;
          $1111: ReadSuccessResponse;
          $6666: ReadErrorResponse;
          $316, $4547: raise new ChatException($"This is not a HTTP Server.");
          else raise new ChatException($"Unexpected package kind {Convert.ToHexString(lType)}.");
        end;
        Log($"done work loop");
      end;
      Log($"done work");
    end;

    method ReadMessage;
    begin
      if DataConnection.ReadUInt32LE(out var lMessageID) then begin
        //if not PackageWasHandled[lMessageID] then begin
        try
          if DataConnection.ReadByte(out var lType) then begin
            if DataConnection.ReadUInt32LE(out var lSize) then begin
              if lSize > MaxPackageSize then
                raise new ChatException($"Package exceeds maximum size {Convert.ToHexString(lSize)} > {Convert.ToHexString(MaxPackageSize)}.");
              case lType of
                TYPE_AUTH: ReadAuthentication(lMessageID, lSize);
                TYPE_PACKAGE: ReadPackage(lMessageID, lSize);
                else raise new ChatException($"Unexpected package type {lType}.");
              end;
            end;
          end;
          if not DataConnection.ReadUInt16LE(out var lEtx) then
            raise new ChatException($"Comnection closed reading end pf package marker.");
          Log($"lEtx {Convert.ToHexString(lEtx)}");
          if lEtx ≠ $ffff then
            raise new ChatException($"Expected end of package marker, received {Convert.ToHexString(lEtx)}.");
          SendAck(lMessageID);
        except
          on E: Exception do begin
            Log($"E {E}");
            SendNak(lMessageID, E.Message);
            DataConnection.Close;
          end;
        end;
        //PackageWasHandled[lMessageID] := true;
      //end
      //else begin
        //if DataConnection.ReadUInt8(out var lType) then begin
          //if DataConnection.ReadUInt32LE(out var lSize) then begin
      //end;
      end;
    end;

    method ReadSuccessResponse;
    begin
      if DataConnection.ReadUInt32LE(out var lSize) and (lSize < MaxPackageSize) then begin

      end;
    end;

    method ReadErrorResponse;
    begin
      if DataConnection.ReadUInt32LE(out var lSize) and (lSize < MaxPackageSize) then begin

      end;
    end;

    //

    method ReadAuthentication(aMessageID: UInt64; aSize: UInt32);
    begin
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

    method ReadPackage(aMessageID: UInt64; aSize: UInt32);
    begin
      Log($"ReadPackage {aMessageID} {Convert.ToHexString(aSize)}");
      var lBytes := new Byte[aSize];
      var lOffset := 0;
      while lOffset < aSize do begin
        var lRead := DataConnection.Read(lBytes, lOffset, aSize-lOffset);
        if lRead = 0 then
          exit;
        inc(lOffset, lRead);
      end;
      var lPackage := new Package withByteArray(lBytes);
      Server.ReceivePackage(self, lPackage);
    end;

    method SendAuthentication(aUserID: Guid; aAuthenticationCode: Guid): future Boolean;
    begin
      Log($"SendAuthentication");
      DataConnection.WriteUInt16LE($0000);
      var lMessageID := NextID;
      DataConnection.WriteUInt32LE(lMessageID);
      DataConnection.WriteByte(TYPE_AUTH);
      DataConnection.WriteUInt32LE(Guid.Size*2);
      DataConnection.WriteGuid(aUserID);
      DataConnection.WriteGuid(aAuthenticationCode);
      DataConnection.WriteUInt16LE($ffff);
      //var lResponse := WaitForResponse(lMessageID);
    end;

    method SendPackage(aPackage: Package);
    begin
      Log($"SendPackage");
      DataConnection.WriteUInt16LE($0000);
      var lMessageID := NextID;
      DataConnection.WriteUInt32LE(lMessageID);
      DataConnection.WriteByte(TYPE_PACKAGE);
      var lBytes := aPackage.ToByteArray;
      DataConnection.WriteUInt32LE(length(lBytes));
      DataConnection.Write(lBytes);
      DataConnection.WriteUInt16LE($ffff);
    end;

    method SendAck(aMessageID: UInt32);
    begin
      Log($"SendAck");
      DataConnection.WriteUInt16LE($1111);
      DataConnection.WriteUInt32LE(aMessageID);
      DataConnection.WriteUInt16LE($2222);
    end;

    method SendNak(aMessageID: UInt32; aError: String);
    begin
      Log($"SendNak");
      DataConnection.WriteUInt16LE($6666);
      DataConnection.WriteUInt32LE(aMessageID);
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

    const MaxPackageSize = 512 000;

    const TYPE_AUTH = $01;
    const TYPE_PACKAGE = $02;

    const TYPE_ACK = $81;
    const TYPE_NAK = $82;

    property PackageWasHandled[aMessageID: Int32]: Boolean read false write begin end;

    property Client: nullable IPChatClient;
    property Server: nullable IIPChatServer;

  private

    var fNextMessageID: Integer;

    method NextID: Integer; inline;
    begin
      {$IF COOPER}
      locking self do begin
        result := fNextMessageID;
        inc(fNextMessageID);
      end;
      {$ELSE}
      interlockedInc(var fNextMessageID);
      {$ENDIF}
    end;

  end;

end.