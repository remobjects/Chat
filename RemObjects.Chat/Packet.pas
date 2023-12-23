namespace RemObjects.Chat;

type
  IPacket = public interface
  public
  end;

  Packet = public class(IPacket)
  public
    property &Type: PacketType;
    property ID: Int32;
    property Payload: array of Byte;
  end;

  PacketType = public enum(Packet, Ack, Nak);

end.