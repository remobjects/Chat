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
        case lType of
          $0000: ReadMessage;
          $1111: ReadSuccessResponse;
          $6666: ReadErrorResponse;
          $316, $4547: raise new ChatException($"This is not a HTTP Server.");
          else raise new ChatException($"Unexpected package kind {Convert.ToHexString(lType)}.");
        end;
      end
    end;

    method ReadMessage;
    begin
      if DataConnection.ReadUInt64LE(out var lMessageID) then begin
        //if not PackageWasHandled[lMessageID] then begin
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
          //PackageWasHandled[lMessageID] := true;
        //end
        //else begin
          //if DataConnection.ReadUInt8(out var lType) then begin
            //if DataConnection.ReadUInt32LE(out var lSize) then begin
        //end;
        SendAck(lMessageID);
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
      if Server.AuthenticateConnection(self, lUserID, lAuthentcationToken) then begin
        UserID := lUserID;
        SendAck(aMessageID);
      end
      else begin
        SendNak(aMessageID);
        DataConnection.Close;
      end;
    end;

    method ReadPackage(aMessageID: UInt64; aSize: UInt32);
    begin
      var lBytes := new Byte[aSize];
      var lOffset := 0;
      while lOffset < aSize do begin
        var lRead := DataConnection.Read(lBytes, lOffset, aSize-lOffset);
        if lRead = 0 then
          exit;
        inc(lOffset, lRead);
      end;
      var lPackage := new Package withByteArray(lBytes);
      if Server.ReceivePackage(self, lPackage) then begin
        //UserID := lUserID;
        SendAck(aMessageID);
      end
      else begin
        SendNak(aMessageID);
        //DataConnection.Close;
      end;
    end;

    method SendAuthentication(aUserID: Guid; aAuthenticationCode: Guid): future Boolean;
    begin
      DataConnection.WriteUInt16LE($0000);
      var lMessageID := interlockedInc(var fNextMessageID);
      DataConnection.WriteUInt32LE(lMessageID);
      DataConnection.WriteUInt16LE(TYPE_AUTH);
      DataConnection.WriteGuid(aUserID);
      DataConnection.WriteGuid(aAuthenticationCode);
      DataConnection.WriteUInt16LE($ffff);
      //var lResponse := WaitForResponse(lMessageID);
    end;

    method SendAck(aMessageID: UInt32);
    begin
      DataConnection.WriteUInt16LE($1111);
      DataConnection.WriteUInt32LE(aMessageID);
      DataConnection.WriteUInt16LE($2222);
    end;

    method SendNak(aMessageID: UInt32);
    begin
      DataConnection.WriteUInt16LE($6666);
      DataConnection.WriteUInt32LE(aMessageID);
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

  end;

end.