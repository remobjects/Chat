namespace RemObjects.Chat;

uses
  RemObjects.Infrastructure.Encryption;

type
  ChatInfo = public class
  public
    property ID: not nullable Guid; required;
    property UserIDs: not nullable List<Guid>; required;

    //
    // This isn nkt using Serialization because it will be sued client-side too.
    //

    method ToJson: JsonDocument; virtual;
    begin
      result := new JsonObject;
      result["id"] := ID.ToString;
      result["UserIDs"] := new JsonArray;
      for each u in UserIDs do
        JsonArray(result["UserIDs"]).Add(u.ToString)
    end;

    method ToJsonString: String;
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
    property PublicKey: array of Byte;

    method ToJson: JsonDocument; override;
    begin
      result := inherited;
      result["name"] := Name;
      result["publicKey"] := Convert.ToBase64String(PublicKey);
    end;

  end;

  UserInfo = public class
  public
    property ID: not nullable Guid; required;
    property ShortID: nullable Integer;
    property Name: not nullable nullable String; required;
    property Handle: nullable String;
    property Status: nullable String;
    property LastSeen: nullable DateTime;
    property PublicKey: PublicKey; required;
  end;


  MessageInfo = public class
  public
  end;

end.