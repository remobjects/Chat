namespace RemObjects.Chat;

type
  IChatMessage = public interface
  public
    property PayloadType: Byte read;
    property Payload: array of Byte read;

    property SenderID: Guid read;
    property ChatID: Guid read;
  end;

  JsonChatMessage = public class(IChatMessage)
  public

    property SignatureValid: Boolean;
    property JsonPayload: JsonDocument;

    property ChatID: Guid read Guid.TryParse(JsonPayload["senderId"]);
    property SenderID: Guid read Guid.TryParse(JsonPayload["senderId"]);

    { IChatMessage }

    property PayloadType: Byte read ord('J');
    property Payload: array of Byte read Encoding.UTF8.GetBytes(JsonPayload.ToJsonString(JsonFormat.Minimal));

  end;

end.