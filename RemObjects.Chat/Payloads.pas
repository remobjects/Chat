namespace RemObjects.Chat;

uses
  RemObjects.Infrastructure.Encryption;

type
  Payload = public abstract class

    constructor; empty;

    constructor withBytes(aBytes: array of Byte);
    begin
      Bytes := aBytes;
    end;

    property Data: array of Byte read write; abstract;
    property Bytes: array of Byte read Data write Data; virtual;

    method Save(aFilename: String);
    begin
      File.WriteBytes(aFilename, Data);
    end;

    method Load(aFilename: String);
    begin
      Bytes := File.ReadBytes(aFilename);
    end;

    method Load(aBytes: array of Byte);
    begin
      Bytes := aBytes;
    end;

    method Load(aBytes: array of Byte; aOffset: Integer; aLength: Integer := -1);
    begin
      if aLength > 0 then begin
        var lData := new Byte[aLength];
        &Array.Copy(aBytes, aOffset, lData, 0, length(lData));
        Bytes := lData;
      end
      else if aOffset > 0 then begin
        var lData := new Byte[length(aBytes)-aOffset];
        &Array.Copy(aBytes, aOffset, lData, 0, length(lData));
        Bytes := lData;
      end
      else begin
        Bytes := aBytes;
      end;
    end;

    method ToBase64: String;
    begin
      result := Convert.ToBase64String(Data);
    end;

  end;

  //
  //
  //

  EncryptablePayload = public abstract class(Payload)
  public

    method SetUnencryptedData(aData: array of Byte);
    begin
      Data := aData;
      Format := "plain";
      IsEncrypted := false;
    end;

    method SetEncryptedDataWithPublicKey(aData: array of Byte; aKeyPair: nullable KeyPair);
    begin
      if assigned(aKeyPair) and (aKeyPair.HasPublicKey) then begin
        if length(aData) < aKeyPair.Size then begin
          Data := aKeyPair.EncryptWithPublicKey(aData);
          Format := "rsa";
        end
        else begin
          var lKey := SymmetricKey.Generate(KeyType.AES);
          Log($"Generated Key {Convert.ToHexString(lKey.GetKey)}");
          Key := aKeyPair.EncryptWithPublicKey(lKey.GetKey);

          //https://git.remobjects.com/remobjects/elements/-/issues/27041
          //var lEncrypted := lKey.Encrypt(aData);
          //Data := lEncrypted[0];
          //IV := aKeyPair.EncryptWithPublicKey(lEncrypted[1]);
          Data := lKey.Encrypt(aData, out var lIV);
          Log($"Generated IV {Convert.ToHexString(lIV)}");
          IV := aKeyPair.EncryptWithPublicKey(lIV);

          Log($"original  {Convert.ToHexString(aData)}");
          Log($"data      {Convert.ToHexString(Data)}");

          Format := "aes+rsa";
        end;
        Signature := if aKeyPair.HasPrivateKey then
          aKeyPair.SignWithPrivateKey(aData);
        IsEncrypted := true;
      end
      else begin
        SetUnencryptedData(aData);
      end;
    end;

    method GetDecryptedDataWithPrivateKey(aKeyPair: KeyPair): array of Byte;
    begin
      if IsEncrypted then begin

        if not assigned(aKeyPair) or not aKeyPair.HasPrivateKey then
          raise new Exception("Payload is encrypted, but no private key is set.");

        case Format of
          "rsa", nil: begin
            result := aKeyPair.DecryptWithPrivateKey(Data);
            end;
          "aes+rsa": begin
            var lIV := aKeyPair.DecryptWithPrivateKey(IV);
            Log($"Read IV {Convert.ToHexString(lIV)}");
            var lKey := aKeyPair.DecryptWithPrivateKey(Key);
            Log($"Read Key {Convert.ToHexString(lKey)}");
            result := new SymmetricKey withKey(lKey).Decrypt(Data, lIV);
            Log($"data      {Convert.ToHexString(Data)}");
            Log($"decrypted {Convert.ToHexString(result)}");
          end;
        end;

      end
      else begin
        result := Data;
      end;
    end;

    method ValidateSignatureWithPublicKey(aKeyPair: KeyPair): Boolean;
    begin
      if assigned(Signature) then
        aKeyPair.ValidateSignatureWithPublicKey(Data, Signature);
    end;

  protected

    property IsEncrypted: Boolean read write; abstract;
    property Signature: array of Byte read write; abstract;
    property Format: String read write; abstract;
    property Key: array of Byte read write; abstract;
    property IV: array of Byte read write; abstract;

  end;

  JsonPayload = public class(EncryptablePayload)
  public

    constructor;
    begin
      Json := JsonDocument.CreateObject;
    end;

    constructor withBytes(aData: array of Byte);
    begin
      Json := JsonDocument.CreateObject;
    end;

    constructor withJson(aJson: nullable JsonObject);
    begin
      Json := coalesce(aJson, JsonDocument.CreateObject);
    end;

    property Json: JsonNode;

    property Data: array of Byte read begin
      result := if assigned(Json[DataNodeName]:StringValue) then Convert.Base64StringToByteArray(Json[DataNodeName]:StringValue);
    end
    write begin
      Json[DataNodeName] := Convert.ToBase64String(value);
    end; override;

  protected

    property DataNodeName: String read "data"; virtual;

    property Format: String read Json["format"]:StringValue write Json["format"]; override;
    property IsEncrypted: Boolean read valueOrDefault(Json["encrypted"]:BooleanValue) write Json["encrypted"]; override;

    property Key: array of Byte read begin
      result := if assigned(Json["key"]:StringValue) then Convert.Base64StringToByteArray(Json["key"]:StringValue);
    end
    write begin
      Json["key"] := Convert.ToBase64String(value);
    end; override;

    property IV: array of Byte read begin
      result := if assigned(Json["iv"]:StringValue) then Convert.Base64StringToByteArray(Json["iv"]:StringValue);
    end
    write begin
      Json["iv"] := Convert.ToBase64String(value);
    end; override;

    property Signature: array of Byte read begin
      result := if assigned(Json["signature"]:StringValue) then Convert.Base64StringToByteArray(Json["signature"]:StringValue);
    end
    write begin
      Json["signature"] := Convert.ToBase64String(value);
    end; override;

    [ToString]
    method ToString: String; override;
    begin
      result := $"<JsonPayLoad {Json.ToJsonString(JsonFormat.HumanReadable)}>"
    end;

  end;

  JsonPayloadWithAttachment = public class(JsonPayload)
  public

    constructor; empty;
    constructor withJson(aJson: nullable JsonObject); empty;

    constructor withBytes(aData: array of Byte);
    begin
      Bytes := aData;
    end;

    constructor withJson(aJson: nullable JsonObject; aBinary: nullable array of Byte);
    begin
      Data := aBinary;
      Json := coalesce(aJson, JsonDocument.CreateObject);
    end;

    property Data: array of Byte/* read fData write fData*/; override;

    property Bytes: array of Byte read begin
      var lJson := Encoding.UTF8.GetBytes(Json.ToJsonString(JsonFormat.Minimal));
      var lData := new Byte[1+length(lJson)+1+length(Data)];
      &Array.Copy(lJson, 0, lData, 1, length(lJson));
      &Array.Copy(Data, 0, lData, length(lJson)+2, length(lData));
      lData[0] := #2;
      lData[length(lJson)+1] := #0;
      result := lData;
    end
    write begin
      if value[0] ≠ #2 then
        raise new Exception("Invalid payload format");
      var i := 0;
      for i := 0 to length(value)-1 do
        if value[i] = 0 then
          break;
      if (i > 0) and (i < length(value)-1) then begin
        Json := JsonDocument.FromString(Encoding.UTF8.GetString(value, 1, i-1)) as JsonObject;
        Data := new Byte[length(value)-i];
        &Array.Copy(value, i+1, Data, 0, length(Data));
      end;
    end; override;

    [ToString]
    method ToString: String; override;
    begin
      result := $"<JsonPayload {Json.ToJsonString(JsonFormat.HumanReadable)} with {length(Data)} attachment>"
    end;

  protected

  end;

end.