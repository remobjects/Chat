namespace RemObjects.Chat.Server;

type
  ChatInfo = public class
  public
    property ID: not nullable Guid; required;
    property UserIDs: not nullable List<Guid>; required;

    method ToJson:
  end;

  PrivateChatInfo = public class(ChatInfo)
  public
  end;

  GroupChatInfo = public class(ChatInfo)
  public
    property Name: String;
    property PublicKey: array of Byte;
  end;

  MessageInfo = public class
  public
  end;

end.