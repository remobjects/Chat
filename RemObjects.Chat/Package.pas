namespace RemObjects.Chat;

type
  Package = public class(IPersistent)
  public

    constructor; empty;

    constructor withByteArray(aBytes: array of Byte);
    begin
      LoadFromByteArray(aBytes);
    end;

    property &Type: PackageType; //required;
    property ID: /*not nullable*/ Guid; //required;
    property SenderID: /*not nullable*/ Guid; //required;
    property RecipientID: nullable Guid;
    property ChatID: /*not nullable*/ Guid; //required;
    property MessageID: /*not nullable*/ Guid; //required;
    property Sent: /*not nullable*/ DateTime := DateTime.UtcNow;
    property Payload: Payload;
    property Expiration: nullable DateTime;

    { IPersistent }

    method ToByteArray: array of Byte;
    begin
      var lBinary := new Binary;
      var lWriter := new BinaryWriter withBinary(lBinary);
      lWriter.WriteUInt8($02); // Version
      lWriter.WriteUInt8(&Type as Byte);
      lWriter.WriteGuid(ID);
      lWriter.WriteGuid(coalesce(SenderID, Guid.Empty));
      lWriter.WriteGuid(coalesce(RecipientID, Guid.Empty));
      lWriter.WriteGuid(ChatID);
      lWriter.WriteGuid(MessageID);
      lWriter.WriteDouble(Sent.ToOADate);
      lWriter.WriteUInt8(if assigned(Expiration) then 1 else 0);
      if assigned(Expiration) then
        lWriter.WriteDouble(Expiration.ToOADate);
      lWriter.WriteByteArray(Payload.Data);
      result := lBinary.ToArray;
    end;

    method LoadFromByteArray(aBytes: array of Byte);
    begin
      if length(aBytes) < 2 + Guid.Size*4 + sizeOf(Double) + 1 then
        raise new Exception("Data is too small to be a Pckage.");
      var lReader := new BinaryReader withBytes(aBytes);

      var lVersion := lReader.ReadUInt8;
      if lVersion not in [$01, $02] then
        raise new Exception("Unexpected Package format version.");

      &Type := lReader.ReadUInt8 as PackageType;
      ID := lReader.ReadGuid;
      SenderID := lReader.ReadGuid;
      RecipientID := lReader.ReadGuid;
      ChatID := lReader.ReadGuid;
      MessageID := lReader.ReadGuid;
      Sent := DateTime.FromOADate(lReader.ReadDouble);

      if SenderID = Guid.Empty then
        SenderID := nil;
      if RecipientID = Guid.Empty then
        RecipientID := nil;

      case lVersion of
        $01: begin
            var lFormat := lReader.ReadUInt8;
            Payload := case lFormat of
              ord('j'): new JsonPayload();
              ord('m'): new MessagePayload();
              ord('s'): new StatusPayload();
              else raise new Exception("Unexpected Package format.");
            end;
            Payload.Load(aBytes, lReader.Offset);
          end;
        $02: begin
            Expiration := if lReader.ReadUInt8 = 1 then DateTime.FromOADate(lReader.ReadDouble);
            Payload := case &Type of
              PackageType.Message: new MessagePayload();
              PackageType.Status: new StatusPayload();
              else new JsonPayload();
            end;
            Payload.Load(aBytes, lReader.Offset);
          end;
      end;

    end;

    [ToString]
    method ToString: String; override;
    begin
      result := $"<Package type {&Type} {if assigned(SenderID) then "from "+SenderID} to {ChatID}/{RecipientID}: {Payload}>";
    end;

  end;

  IPersistent = public interface
    method ToByteArray: array of Byte;
    method LoadFromByteArray(aBytes: array of Byte);
  end;

  PackageType = public enum(Message, Status);
  MessageStatus = public enum(Unknown, Received, Delivered, Decrypted, FailedToSend, FailedToDecrypt, FailedPermanently, Displayed, &Read);

end.