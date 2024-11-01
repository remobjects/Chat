namespace RemObjects.Chat;

uses
  RemObjects.Infrastructure.Encryption;

type
  MessagePayload = public class(JsonPayload)
  public

    constructor; empty;

    constructor unencryptedWithMessage(aMessage: MessageInfo);
    begin
      SetUnencryptedData(Encoding.UTF8.GetBytes(aMessage.Payload.ToJsonString(JsonFormat.Minimal)));
    end;

  protected

    property DataNodeName: String read "message"; override;
  end;


  StatusPayload = public class(JsonPayload)
  public

    property Status: MessageStatus read begin
      result := case Json["status"]:StringValue of
        "received": MessageStatus.Received;
        "delivered": MessageStatus.Delivered;
        "decrypted": MessageStatus.Decrypted;
        "failedToDecrypt": MessageStatus.FailedToDecrypt;
        "displayed": MessageStatus.Displayed;
        "read": MessageStatus.Read;
      end;
    end
    write begin
      Json["status"] := case value of
        MessageStatus.Received: "received";
        MessageStatus.Delivered: "delivered";
        MessageStatus.Decrypted: "decrypted";
        MessageStatus.FailedToDecrypt: "failedToDecrypt";
        MessageStatus.Displayed: "displayed";
        MessageStatus.Read: "read";
      end;
    end;

    property Date: DateTime read begin
      DateTime.TryParseISO8601(Json["date"]);
    end
    write begin
      Json["date"] := value.ToISO8601String;
    end;

  end;

end.