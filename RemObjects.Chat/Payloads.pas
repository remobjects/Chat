namespace RemObjects.Chat;

type
  IPayload = public interface
    method ToByteArray: array of Byte;

    method Save(aFilename: String);
    method Load(aFilename: String);
    method Load(aBytes: array of Byte; aOffset: Integer := 0);

    method ToBase64: String;
    begin
      result := Convert.ToBase64String(ToByteArray);
    end;

  end;

  //
  //
  //

  JsonPayload = public class(IPayload)
  public

    constructor; empty;

    constructor (aJson: not nullable JsonDocument);
    begin
      Json := aJson;
    end;

    property Json: JsonDocument read private write := new JsonObject;

    method ToByteArray: array of Byte; //override;
    begin
      result := Encoding.UTF8.GetBytes(Json.ToJsonString(JsonFormat.Minimal));
    end;

    method Save(aFilename: String);
    begin
      File.WriteText(aFilename, Json.ToJsonString);
    end;

    method Load(aFilename: String);
    begin
      Json := JsonDocument.FromFile(aFilename);
    end;

    method Load(aBytes: array of Byte; aOffset: Integer := 0);
    begin
      Json := JsonDocument.FromString(Encoding.UTF8.GetString(aBytes, aOffset));
    end;

    [ToString]
    method ToString: String; override;
    begin
      result := Json.ToJsonString;
    end;

  end;

  //
  //
  //

  MessagePayload = public class(JsonPayload)
  public

    constructor; empty;

    //constructor unencryptedWithMessage(aMessage: MessageInfo);
    //begin
      //Message := Encoding.UTF8.GetBytes(aMessage.Payload.ToJsonString(JsonFormat.Minimal));
      //IsEncrypted := false;
    //end;

    property Message: array of Byte read begin
      result := if assigned(Json["message"]:StringValue) then Convert.Base64StringToByteArray(Json["message"]:StringValue);
    end
    write begin
      Json["message"] := Convert.ToBase64String(value);
    end;

    property Key: array of Byte read begin
      result := if assigned(Json["key"]:StringValue) then Convert.Base64StringToByteArray(Json["key"]:StringValue);
    end
    write begin
      Json["key"] := Convert.ToBase64String(value);
    end;

    property IV: array of Byte read begin
      result := if assigned(Json["iv"]:StringValue) then Convert.Base64StringToByteArray(Json["iv"]:StringValue);
    end
    write begin
      Json["iv"] := Convert.ToBase64String(value);
    end;

    property Signature: array of Byte read begin
      result := if assigned(Json["signature"]:StringValue) then Convert.Base64StringToByteArray(Json["signature"]:StringValue);
    end
    write begin
      Json["signature"] := Convert.ToBase64String(value);
    end;

    property Format: String read Json["format"]:StringValue write Json["signature"];

    property IsEncrypted: nullable Boolean read valueOrDefault(Json["encrypted"]:BooleanValue) write Json["encrypted"];

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