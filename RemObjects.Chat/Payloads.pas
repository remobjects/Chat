namespace RemObjects.Chat;

type
  IPayload = public interface
    method ToByteArray: array of Byte;
    method Save(aFilename: String);
    method Load(aFilename: String);
    method Load(aBytes: array of Byte; aOffset: Integer := 0);
  end;

  //
  //
  //

  JsonPayload = public class(IPayload)
  public

    constructor; empty;

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
      Json := JsonDocument.TryFromString(Encoding.UTF8.GetString(aBytes, aOffset));
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

    property EncryptedMessage: array of Byte read begin
      result := if assigned(Json["message"]:StringValue) then Convert.Base64StringToByteArray(Json["message"]:StringValue);
    end
    write begin
      Json["message"] := Convert.ToBase64String(value);
    end;

    property Signature: array of Byte read begin
      result := if assigned(Json["signature"]:StringValue) then Convert.Base64StringToByteArray(Json["signature"]:StringValue);
    end
    write begin
      Json["signature"] := Convert.ToBase64String(value);
    end;

  end;


  StatusPayload = public class(JsonPayload)
  public

    property Status: PackageType read begin
      result := case Json["status"]:StringValue of
        "received": PackageType.Received;
        "delivered": PackageType.Delivered;
        "decrypted": PackageType.Decrypted;
        "failedToDecrypt": PackageType.FailedToDecrypt;
        "displayed": PackageType.Displayed;
        "read": PackageType.Read;
      end;
    end
    write begin
      Json["status"] := case value of
        PackageType.Received: "received";
        PackageType.Delivered: "delivered";
        PackageType.Decrypted: "decrypted";
        PackageType.FailedToDecrypt: "failedToDecrypt";
        PackageType.Displayed: "displayed";
        PackageType.Read: "read";
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