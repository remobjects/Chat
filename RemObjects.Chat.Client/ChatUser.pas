namespace RemObjects.Chat.Client;

uses
  RemObjects.Chat,
  //RemObjects.Elements.Serialization,
  RemObjects.Infrastructure,
  RemObjects.Infrastructure.Encryption;

type
  //[Codable(NamingStyle.camelCase)]
  ChatClient = public class(BaseClient)
  public

    constructor; empty;

    //constructor withFolder(aFolder: String);
    //begin
      //Load(aFolder);
    //end;

    //method Load(aFolder: not nullable String);
    //begin
      //OwnKeyPair := new KeyPair withFiles(Path.Combine(aFolder, "public_key.key"),
                                          //Path.Combine(aFolder, "private_key.key"),
                                          //KeyFormat.Bytes);
      //for each f in Folder.GetFiles(aFolder).Where(f -> f.LastPathComponent.EndsWith("_public.key")) do
        //fPersons.Add(new UserInfo(UserID := Guid.TryParse(f.LastPathComponent.Substring(0, length(f.LastPathComponent)-11)),
                                //PublicKey := new KeyPair withFiles(f, nil, KeyFormat.Bytes)));
    //end;

    //method Save(aFolder: not nullable String);
    //begin
      //Folder.Create(aFolder);
      //OwnKeyPair.SaveToFiles(Path.Combine(aFolder, "public_key.key"),
                             //Path.Combine(aFolder, "private_key.key"),
                             //KeyFormat.Bytes);
      //for each p in Persons do
        //p.PublicKey.SaveToFiles(Path.Combine(aFolder, p.UserID+"_public.key"), nil, KeyFormat.Bytes);
    //end;

    //

    property OwnKeyPair: KeyPair;

    method FindChat(aChatID: not nullable Guid): Chat;
    begin
      result := fChatsByID[aChatID];
      if not assigned(result) then begin

        var lChatInfo := ChatControllerProxy.FindChat(aChatID);
        if not assigned(lChatInfo) then
          raise new Exception($"Chat '{aChatID}' not found.");
        result := new Chat(self, lChatInfo);

      end;
    end;

    //
    // incoming packages
    //

    method OnReceivePackage(aPackage: Package); override; protected;
    begin
      try

        Log($"Client {UserID} received: {aPackage.MessageID}, {aPackage.Type}, {aPackage.Payload}");
        case aPackage.Type of
          PackageType.Message: begin
              //var lMessage := CreateMessage(aPackage);
              Log($"Client: New message received");//: {lMessage}");
              SendStatusResponse(aPackage, PackageType.Delivered, DateTime.UtcNow);
                var lChat := FindChat(aPackage.ChatID);
                var lEncryptedMessage := aPackage.Payload as MessagePayload;
              try
                var lMessage := DecodeMessage(aPackage.SenderID, lEncryptedMessage, lChat);
                Log($"Client: decrypted message: {lMessage.Payload}");
                SendStatusResponse(aPackage, PackageType.Decrypted, DateTime.UtcNow);
                lChat.AddMessage(lMessage);
              except
                SendStatusResponse(aPackage, PackageType.FailedToDecrypt, DateTime.UtcNow);
              end;
            end;
          PackageType.FailedToDecrypt: begin
              Log($"Client: New status received for {aPackage.MessageID}: {aPackage.Type}.");
              {$HINT TODO: re-encrypt with new key and resend}
            end;
          PackageType.Delivered,
          PackageType.Received,
          PackageType.Decrypted,
          PackageType.Displayed,
          PackageType.Read: begin
              //var lChat := FindChat(aPackage.ChatID); CHAT ID DIFFERS BETWEEN CLIENTS. BAD.
              //lChat.SetMessageStatus(aPackage.MessageID, aPackage.Type);
              Log($"Client: New status received for {aPackage.MessageID}: {aPackage.Type}");
            end;
        end;

      except
        on E: Exception do
          Log($"{E.Message}");
      end;
    end;

    method SendStatusResponse(aPackage: Package; aStatus: PackageType; aDate: DateTime);
    begin
      var lPackage := new Package(&Type := aStatus,
                                  SenderID := UserID,
                                  RecipientID := aPackage.SenderID,
                                  ChatID := aPackage.ChatID,
                                  MessageID := aPackage.MessageID,
                                  Payload := new StatusPayload(Status := aStatus,
                                                               Date := DateTime.UtcNow));
      SendPackage(lPackage);
    end;


    //
    //
    //


    //property ChatServer: ChatServer;

    property Chats: ImmutableList<Chat> read fChats;
    var fChats := new List<Chat>; private;
    var fChatsByID := new Dictionary<Guid,Chat>; private;

    property Persons: ImmutableList<UserInfo>;// read fPersons;
    var fPersons := new List<UserInfo>; private;

    method AddChat(aChat: Chat);
    begin
      fChats.Add(aChat);
      fChatsByID[aChat.ChatID] := aChat;
    end;

    //

    method SendMessage(aMessage: ChatMessage; aChat: Chat): MessagePayload;
    begin
      var lEncodedMessage := EncodeMessage(aMessage, aChat);
      //Log($"lEncodedMessage {lEncodedMessage}");
      lEncodedMessage.Save("/Users/mh/temp/message1.msg");

      var lPackage := new Package(&Type := PackageType.Message,
                                  SenderID := UserID,
                                  ChatID := aChat.ChatID,
                                  MessageID := Guid.NewGuid,
                                  Payload := lEncodedMessage);
      SendPackage(lPackage);
    end;

  private

    method EncodeMessage(aMessage: ChatMessage; aChat: Chat): MessagePayload;
    begin

      var lPayload := new MessagePayload;

      var lStringData := aMessage.Payload.ToJsonString(JsonFormat.Minimal);
      var lData := Encoding.UTF8.GetBytes(lStringData);

      lPayload.EncryptedMessage := aChat.PublicKey.EncryptWithPublicKey(lData);
      lPayload.Signature := OwnKeyPair.SignWithPrivateKey(lData);

      //Log($"-- encode --");
      //Log($"lStringData {lStringData}");
      //Log($"lData {lData.ToHexString}");
      //Log($"lEncryptedMessage {lPayload.EncryptedMessage.ToHexString}");
      //Log($"lSignature        {lPayload.Signature}");

      result := lPayload;

    end;

    //method DecodeMessage(aPackage: Package): ChatMessage;
    //begin
      //var lChat := FindChat(aPackage.ChatID);
      //result := DecodeMessage(aPackage.Payload as MessagePayload, lChat);
    //end;

    method DecodeMessage(aSenderID: Guid; aPayload: MessagePayload; aChat: Chat): ChatMessage;
    begin

      result := new ChatMessage;

      case aChat.Type of
        ChatType.Private: begin
            var lDecryptedMessage := OwnKeyPair.DecryptWithPrivateKey(aPayload.EncryptedMessage);
            var lString := Encoding.UTF8.GetString(lDecryptedMessage);

            result.Payload := JsonDocument.FromString(lString);
            result.Sender := FindSender(aSenderID);

            if assigned(result.Sender:PublicKey) then begin
              result.SignatureValid := result.Sender.PublicKey.ValidateSignatureWithPublicKey(lDecryptedMessage, aPayload.Signature);
              if not result.SignatureValid then begin
                if RefreshPublicKey(result.Sender) then
                  result.SignatureValid := result.Sender.PublicKey.ValidateSignatureWithPublicKey(lDecryptedMessage, aPayload.Signature);
              end;
            end;

          end;
        ChatType.Group: begin

            var lDecryptedMessage := aChat.SharedKeyPair.DecryptWithPrivateKey(aPayload.EncryptedMessage);
            var lString := Encoding.UTF8.GetString(lDecryptedMessage);

            result.Payload := JsonDocument.FromString(lString);
            result.Sender := FindSender(result.SenderID);

            if assigned(aSenderID) then begin
              result.Sender := FindSender(result.SenderID);
              if assigned(result.Sender:PublicKey) then begin
                result.SignatureValid := result.Sender.PublicKey.ValidateSignatureWithPublicKey(lDecryptedMessage, aPayload.Signature);
                if not result.SignatureValid then begin
                  if RefreshPublicKey(result.Sender) then
                    result.SignatureValid := result.Sender.PublicKey.ValidateSignatureWithPublicKey(lDecryptedMessage, aPayload.Signature);
                end;
              end;
            end;

          end;
        else raise new Exception($"Unexpected chat type {aChat.Type}.")

      end;

      result.Chat := ChatControllerProxy.FindChat(aChat.ChatID);
      if assigned(result.SenderID) and (result.SenderID ≠ aSenderID) then
        raise new Exception("Mismatched sender in payload");
      if assigned(result.ChatID) and (result.ChatID ≠ aChat.ChatID) then
        raise new Exception("Mismatched sender in payload");


      //Log($"-- decode --");
      //Log($"lSignature        {aPayload.Signature.ToHexString}");
      //Log($"lEncryptedMessage {aPayload.EncryptedMessage.ToHexString}");
      //Log($"result.Payload {result.Payload}");
      //Log($"result.SignatureValid {result.SignatureValid}");

    end;

    //
    //
    //

    method Connect;
    begin
      var lAuthenticationCode: Guid;// := fChatServer.GetChatAuthenticationCode;

      var lAuthenticationMessage := new Byte[2+sizeOf(Guid)*2];
      lAuthenticationMessage[0] := ord('A');
      &Array.Copy(UserID.ToByteArray, 0, lAuthenticationMessage, 1, sizeOf(Guid));
      lAuthenticationMessage[1+sizeOf(Guid)] := ord('-');
      &Array.Copy(lAuthenticationCode.ToByteArray, 0, lAuthenticationMessage, 2+sizeOf(Guid), sizeOf(Guid));

      // Connect
      // SendMessage(lAuthenticationMessage)
    end;

    method FindSender(aSenderID: Guid): nullable UserInfo;
    begin
      if assigned(aSenderID) then
        result := ChatControllerProxy.FindUser(aSenderID);
    end;

    method RefreshPublicKey(aPerson: UserInfo): Boolean;
    begin

    end;

  end;

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

    //
    //
    //


    method AddMessage(aMessage: ChatMessage);
    begin
      fMessages.Add(aMessage);
    end;

    method SetMessageStatus(aMessageID: not nullable Guid; aStatus: PackageType);
    begin
      //fMessages.Add(aMessage);
    end;

    var fMessages := new List<ChatMessage>; private;

  end;

  ChatType = public enum(&Private, &Group);

    //[Codable(NamingStyle.camelCase)]
  //PrivateChat = public class(Chat)
  //public

    //property UserInfo: UserInfo;

  //end;

  ////[Codable(NamingStyle.camelCase)]
  //GroupChat = public class(Chat)
  //public
    //property SharedKeyPair: KeyPair;
    //property Persons: List<UserInfo>;

    ////[Encode(false)]
    //property PersonsByID: Dictionary<Guid,UserInfo>;
    ////[Encode(false)]
    //property PersonsByShortID: Dictionary<Integer,UserInfo>;
  //end;

end.