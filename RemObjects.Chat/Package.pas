namespace RemObjects.Chat;

type
  Package = public class(IPersistent)
  public

    property &Type: PackageType; required;
    property SenderID: not nullable Guid; required;
    property RecipientID: nullable Guid;
    property ChatID: not nullable Guid; required;
    property MessageID: not nullable Guid; required;
    property Sent: not nullable DateTime := DateTime.UtcNow;
    property Payload: IPayload;

    { IPersistent }

    method ToByteArray: array of Byte;
    begin
      var lBinary := new Binary;
      var lWriter := new BinaryWriter withBinary(lBinary);
      lWriter.WriteUInt8($01);
      lWriter.WriteUInt8(&Type as Byte);
      lWriter.WriteGuid(SenderID);
      lWriter.WriteGuid(coalesce(RecipientID, Guid.Empty));
      lWriter.WriteGuid(ChatID);
      lWriter.WriteGuid(MessageID);
      lWriter.WriteDouble(Sent.ToOADate);
      case Payload type of
        MessagePayload: lWriter.WriteUInt8(ord('m'));
        StatusPayload: lWriter.WriteUInt8(ord('s'));
        JsonPayload: lWriter.WriteUInt8(ord('j'));
        else raise new Exception("Unexpected Package format.");
      end;
      lWriter.WriteByteArray(Payload.ToByteArray);
      result := lBinary.ToArray;
    end;

    method FromByteArray(aBytes: array of Byte);
    begin
      if length(aBytes) < 2 + Guid.Size*4 + sizeOf(Double) + 1 then
        raise new Exception("Data is too small to be a Pckage.");
      var lReader := new BinaryReader withBytes(aBytes);
      if lReader.ReadUInt8 ≠ $01 then
        raise new Exception("Unexpected Package format version.");
      &Type := lReader.ReadUInt8 as PackageType;
      SenderID := lReader.ReadGuid;
      RecipientID := lReader.ReadGuid;
      if RecipientID = Guid.Empty then
        RecipientID := nil;
      ChatID := lReader.ReadGuid;
      MessageID := lReader.ReadGuid;
      Sent := DateTime.FromOADate(lReader.ReadDouble);
      var lFormat := lReader.ReadUInt8;
      Payload := case lFormat of
        ord('j'): new JsonPayload();
        ord('m'): new MessagePayload();
        ord('s'): new StatusPayload();
        else raise new Exception("Unexpected Package format.");
      end;
      Payload.Load(aBytes, lReader.Offset);

    end;
  end;

  IPersistent = public interface
    method ToByteArray: array of Byte;
    method FromByteArray(aBytes: array of Byte);
  end;

  PackageType = public enum(Message, Received, Delivered, Decrypted, FailedToDecrypt, Displayed, &Read);

end.