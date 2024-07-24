namespace RemObjects.Chat;

uses
  RemObjects.Infrastructure.Encryption;

type
  ChatType = public enum(&Private, &Group);

  ChatInfo = public abstract class
  public
    property ID: not nullable Guid;
    property UserIDs: nullable List<Guid>;

    property &Type: ChatType read; abstract;
    property DeliveryNotifications: Boolean read &Type = ChatType.Private; virtual;

    constructor(aID: not nullable Guid); unit;
    begin
      ID := aID;
      UserIDs := new List<Guid>;
    end;

    constructor(aID: not nullable Guid; aUserIDs: not nullable List<Guid>);
    begin
      ID := aID;
      UserIDs := aUserIDs;
    end;

    //
    // This is not using Serialization because it will be used client-side too, and Serialixation isn't ported to Cocoa yet :(.
    //

    class method FromJson(aJson: JsonDocument): InstanceType;
    begin
      Log($"FromJson {aJson}, {length(aJson["name"]:StringValue) > 0}, '{aJson["name"]}'");
      if length(aJson["name"]:StringValue) > 0 then
        result := new GroupChatInfo withJson(aJson)
      else
        result := new PrivateChatInfo withJson(aJson)
    end;

    class method FromString(aJsonString: String): InstanceType;
    begin
      result := FromJson(JsonDocument.FromString(aJsonString));
    end;

    constructor withJson(aJson: JsonDocument); unit;
    begin
      Log($"base withJson");
      if not assigned(aJson["id"]) then
        raise new Exception("ChatInfo json is missing field 'id'.");
      ID := Guid.TryParse(aJson["id"]) as not nullable;
      if assigned(aJson["userIDs"]) then begin
        UserIDs := new List<Guid> withCapacity(aJson["userIDs"]:Count);
        for each g in JsonArray(aJson["userIDs"]) do
          UserIDs.Add(Guid.TryParse(g));
      end;
    end;

    method ToJson: JsonObject; virtual;
    begin
      result := new JsonObject;
      result["id"] := ID.ToString;
      if assigned(UserIDs) then begin
        result["userIDs"] := new JsonArray;
        for each u in UserIDs do
          JsonArray(result["userIDs"]).Add(u.ToString)
      end;
    end;

    method ToJsonString(aFormat: JsonFormat := JsonFormat.HumanReadable): not nullable String;
    begin
      result := ToJson.ToJsonString(JsonFormat.Minimal);
    end;

    [ToString]
    method ToString: String; override;
    begin
      result := ToJsonString(JsonFormat.HumanReadable);
    end;

  end;

  PrivateChatInfo = public class(ChatInfo)
  public
    property &Type: ChatType read ChatType.Private; override;

  end;

  GroupChatInfo = public class(ChatInfo)
  public
    property Name: String;
    property KeyPair: KeyPair;
    property &Type: ChatType read ChatType.Group; override;

    constructor(aID: not nullable Guid; aName: not nullable String);
    begin
      inherited constructor(aID);
      Name := aName;
    end;

    constructor(aID: not nullable Guid; aUserIDs: not nullable List<Guid>; aName: not nullable String);
    begin
      inherited constructor(aID, aUserIDs);
      Name := aName;
    end;

    constructor(aID: not nullable Guid; aUserIDs: nullable List<Guid>; aName: not nullable String; aKeyPair: KeyPair);
    begin
      constructor(aID, aUserIDs, aName);
      KeyPair := aKeyPair;
    end;

    constructor withJson(aJson: JsonDocument); unit;
    begin
      inherited constructor withJson(aJson);
      Log($"GroupChatInfo withJson");
      Name := aJson["name"]:StringValue;
      KeyPair := if assigned(aJson["keys"]) then new KeyPair withJson(aJson["keys"]);
    end;

    method ToJson: JsonObject; override;
    begin
      result := inherited;
      result["name"] := Name;
      result["keys"] := KeyPair:ToJson;
    end;

  end;

  UserInfo = public class
  public
    property ID: not nullable Guid;
    property Name: not nullable nullable String;
    property Handle: nullable String;
    property Status: nullable String;
    property LastSeen: nullable DateTime;

    property PublicKeyData: array of Byte;
    property PublicKey: PublicKey := if length(PublicKeyData) > 0 then new KeyPair withPublicKey(PublicKeyData); lazy; readonly;

    constructor(aID: not nullable Guid; aName: not nullable String);
    begin
      ID := aID;
      Name := aName;
    end;

    //
    // This is not using Serialization because it will be used client-side too, and Serialixation isn't ported to Cocoa yet :(.
    //

    class method FromJson(aJson: JsonDocument): InstanceType;
    begin
      result := new UserInfo withJson(aJson);
    end;

    class method FromString(aJsonString: String): InstanceType;
    begin
      result := FromJson(JsonDocument.FromString(aJsonString));
    end;

    constructor withJson(aJson: JsonDocument); unit;
    begin
      if not assigned(aJson["id"]) then
        raise new Exception("ChatInfo json is missing field 'id'.");
      ID := Guid.TryParse(aJson["id"]) as not nullable;
      Name := aJson["name"]:StringValue as not nullable;
      Handle := aJson["handle"]:StringValue;
      Status := aJson["status"]:StringValue;
      LastSeen := DateTime.TryParseISO8601(aJson["lastSeen"]:StringValue);
      if length(aJson["publicKey"]:StringValue) > 0 then
        PublicKeyData := Convert.Base64StringToByteArray(aJson["publicKey"]:StringValue);
    end;

    method ToJson: JsonObject; virtual;
    begin
      result := new JsonObject;
      result["id"] := ID.ToString;
      result["name"] := Name;
      result["handle"] := Handle;
      result["status"] := Status;
      result["lastSeen"] := LastSeen:ToISO8601String;
      if length(PublicKeyData) > 0 then
        result["publicKey"] := Convert.ToBase64String(PublicKeyData);
    end;

    method ToJsonString(aFormat: JsonFormat := JsonFormat.HumanReadable): not nullable String;
    begin
      result := ToJson.ToJsonString(JsonFormat.Minimal);
    end;

    [ToString]
    method ToString: String; override;
    begin
      result := ToJsonString(JsonFormat.HumanReadable);
    end;

  end;


  MessageInfo = public class
  public
    property Payload: JsonDocument;
    property SignatureValid: Boolean;

    property ID: Guid;// read Guid.TryParse(Payload["id"]) write begin Payload["id"] := value:ToString; end;
    property ChatID: Guid;// read Guid.TryParse(Payload["chatId"]) write begin Payload["chatId"] := value:ToString; end;
    property SenderID: Guid;// read Guid.TryParse(Payload["senderId"]) write begin Payload["senderId"] := value:ToString; end;

    property SendCount: Integer;// read Guid.TryParse(Payload["senderId"]) write begin Payload["senderId"] := value:ToString; end;

    property Sent: DateTime;
    property Received: DateTime;

    property Chat: weak ChatInfo;
    property Sender: weak UserInfo;
  end;

end.