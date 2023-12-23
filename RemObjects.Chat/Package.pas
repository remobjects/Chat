namespace RemObjects.Chat;

type
  Package = public class
  public

    property &Type: PackageType; required;
    property SenderID: not nullable Guid; required;
    property RecipientID: nullable Guid;
    property ChatID: not nullable Guid; required;
    property MessageID: not nullable Guid; required;
    property Sent: not nullable DateTime := DateTime.UtcNow;
    property Payload: IPayload;

  end;

  PackageType = public enum(Message, Received, Delivered, Decrypted, FailedToDecrypt, Displayed, &Read);

end.