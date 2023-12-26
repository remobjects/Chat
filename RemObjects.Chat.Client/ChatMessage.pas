namespace RemObjects.Chat.Client;

uses
  RemObjects.Chat;

type
  ChatMessage = public class
  public
    property SignatureValid: Boolean;
    property Payload: JsonDocument;

    property ChatID: Guid read Guid.TryParse(Payload["chatId"]);
    property SenderID: Guid read Guid.TryParse(Payload["senderId"]);

    property Chat: weak ChatInfo;
    property Sender: weak UserInfo;
  end;

end.