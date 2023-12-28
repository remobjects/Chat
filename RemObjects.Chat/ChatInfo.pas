namespace RemObjects.Chat;

uses
  RemObjects.Infrastructure.Encryption;

type
  ChatInfo = public abstract class
  public
    property ID: not nullable Guid;
    property UserIDs: not nullable List<Guid>;

    constructor(aID: not nullable Guid);
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

    class method FromJson(aJson: JsonDocument): ChatInfo;
    begin
      if length(aJson["name"]:StringValue) > 0 then
        result := new GroupChatInfo withJson(aJson)
      else
        result := new PrivateChatInfo withJson(aJson)
    end;

    constructor withJson(aJson: JsonDocument); unit;
    begin
      if not assigned(aJson["id"]) then
        raise new Exception("ChatIngo json is missing field 'id'.");
      ID := Guid.TryParse(aJson["id"]) as not nullable;
      UserIDs := new List<Guid>;
      for each g in JsonArray(aJson["userIDs"]) do
        UserIDs.Add(Guid.TryParse(g));
    end;

    method ToJson: JsonObject; virtual;
    begin
      result := new JsonObject;
      result["id"] := ID.ToString;
      result["userIDs"] := new JsonArray;
      for each u in UserIDs do
        JsonArray(result["userIDs"]).Add(u.ToString)
    end;

    method ToJsonString(aFormat: JsonFormat := JsonFormat.HumanReadable): not nullable String;
    begin
      result := ToJson.ToJsonString(JsonFormat.Minimal);
    end;

  end;

  PrivateChatInfo = public class(ChatInfo)
  public
  end;

  GroupChatInfo = public class(ChatInfo)
  public
    property Name: String;
    property KeyPair: KeyPair;

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

    constructor(aID: not nullable Guid; aUserIDs: not nullable List<Guid>; aName: not nullable String; aKeyPair: KeyPair);
    begin
      constructor(aID, aUserIDs, aName);
      KeyPair := aKeyPair;
    end;

    constructor withJson(aJson: JsonDocument); unit;
    begin
      inherited constructor withJson(aJson);
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
    property PublicKey: PublicKey;

    constructor(aID: not nullable Guid; aName: not nullable String);
    begin
      ID := aID;
      Name := aName;
    end;

    //
    // This is not using Serialization because it will be used client-side too, and Serialixation isn't ported to Cocoa yet :(.
    //

    class method FromJson(aJson: JsonDocument): UserInfo;
    begin
      result := new UserInfo withJson(aJson);
    end;

    constructor withJson(aJson: JsonDocument); unit;
    begin
      if not assigned(aJson["id"]) then
        raise new Exception("ChatInfo json is missing field 'id'.");
      ID := Guid.TryParse(aJson["id"]) as not nullable;
      Name := aJson["name"]:StringValue as not nullable;
      Handle := aJson["handle"]:StringValue as not nullable;
      Status := aJson["status"]:StringValue as not nullable;
      LastSeen := DateTime.TryParseISO8601(aJson["lastSeen"]:StringValue);
      if assigned(aJson["publicKey"]) then
        PublicKey := new PublicKey withJson(aJson["publicKey"]);
    end;

    method ToJson: JsonObject; virtual;
    begin
      result := new JsonObject;
      result["id"] := ID.ToString;
      result["name"] := Name;
      result["handle"] := Handle;
      result["status"] := Status;
      result["lastSeen"] := LastSeen:ToISO8601String;
      result["publicKey"] := PublicKey.ToJson;
    end;

    method ToJsonString(aFormat: JsonFormat := JsonFormat.HumanReadable): not nullable String;
    begin
      result := ToJson.ToJsonString(JsonFormat.Minimal);
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

    property Chat: weak ChatInfo;
    property Sender: weak UserInfo;
  end;

end.