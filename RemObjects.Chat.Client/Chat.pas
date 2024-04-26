namespace RemObjects.Chat.Client;

uses
  RemObjects.Infrastructure.Encryption,
  RemObjects.Chat;

type
  ChatType = public enum(&Private, &Group);

  Chat = public class
  public

    [Warning("For internal use/testing only")]
    constructor(aClient: not nullable ChatClient; aChatID: not nullable Guid;  aUserIDs: ImmutableList<Guid>; aType: ChatType);
    begin
      Client := aClient;
      UserID := aClient.UserID;
      ChatID := aChatID;
      UserIDs := aUserIDs;
      &Type := aType;
    end;

    constructor(aClient: not nullable ChatClient; aChatInfo: not nullable ChatInfo);
    begin
      Client := aClient;
      UserID := aClient.UserID;
      ChatID := aChatInfo.ID;
      UserIDs := aChatInfo.UserIDs;

      case aChatInfo type of
        PrivateChatInfo: begin
            &Type := ChatType.Private;
          end;
        GroupChatInfo: begin
            &Type := ChatType.Group;
          end;
        else raise new Exception($"Unexpected chat type {&Type}.")
      end;
    end;

    property Client: weak not nullable ChatClient;
    property ChatID: not nullable Guid;
    property UserID: not nullable Guid;
    property &Type: ChatType;

    property UserIDs: ImmutableList<Guid>;
    //property Persons: List<UserInfo>;

    property PublicKey: KeyPair read begin
      result := case &Type of
        ChatType.Private: OtherUserPublicKey;
        ChatType.Group: SharedKeyPair;
        else raise new Exception($"Unexpected chat type {&Type}.")
      end;
    end;

    //PrivateChat
    property OtherUserPublicKey: PublicKey read OtherUser.PublicKey;
    property OtherUser: UserInfo read begin
      if &Type = ChatType.Private then begin
        result := Client.ChatControllerProxy.FindUser(UserIDs.First(u -> u ≠ UserID));
      end;
    end;

    // GroupChat
    property SharedKeyPair: KeyPair;

    property NewMessageReceived: NewMessageReceivedBlock;
    property MessageStatusChanged: MessageStatusChangedBlock;

    property Messages: ImmutableList<MessageInfo> read fMessages;

  assembly

    method AddMessage(aMessage: MessageInfo);
    begin
      fMessages.Add(aMessage);
      if assigned(NewMessageReceived) then
        NewMessageReceived(aMessage);
    end;

    method SetMessageStatus(aMessageID: not nullable Guid; aStatus: MessageStatus);
    begin
      if assigned(NewMessageReceived) then
        MessageStatusChanged(aMessageID, aStatus);
    end;

    var fMessages := new List<MessageInfo>; private;

  end;

  NewMessageReceivedBlock nested in Chat = public block(aMessage: MessageInfo);
  MessageStatusChangedBlock nested in Chat = public block(aMessageID: not nullable Guid; aStatus: MessageStatus);

end.