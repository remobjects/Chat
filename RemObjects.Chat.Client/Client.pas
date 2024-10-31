namespace RemObjects.Chat.Client;

uses
  RemObjects.Chat,
  RemObjects.Chat.Connection,
  RemObjects.Infrastructure,
  RemObjects.Infrastructure.Encryption;

type
  ChatClient = public class(BaseClient)
  public

    constructor(aUser: UserInfo; aPackageStore: not nullable PackageStore);
    begin
      inherited(aUser);
      fIPClient := new IPChatClient(UserID := UserID);
      fIPClient.OnConnect := () -> begin
        if assigned(OnConnect) then
          OnConnect();
      end;
      fIPClient.OnDisconnect := () -> begin
        Log($"## ChatClient OnDisconnect callback");
        if assigned(OnDisconnect) then
          OnDisconnect();
      end;
      fIPClient.PackageStore := aPackageStore;
      Queue := fIPClient;
    end;

    //

    property OwnKeyPair: KeyPair;

    method FindChat(aChatID: not nullable Guid): Chat; locked on self;
    begin
      result := fChatsByID[aChatID];
      if not assigned(result) then begin

        var lChatInfo := ChatControllerProxy.FindChat(aChatID);
        if not assigned(lChatInfo) then
          raise new Exception($"Chat '{aChatID}' not found.");
        result := new Chat(self, lChatInfo);
        fChatsByID[aChatID] := result;

      end;
    end;

    method FindChat(aChatInfo: not nullable ChatInfo): Chat; locked on self;
    begin
      result := fChatsByID[aChatInfo.ID];
      if not assigned(result) then begin
        result := new Chat(self, aChatInfo);
        fChatsByID[aChatInfo.ID] := result;
      end;
    end;

    method FindUser(aUserID: not nullable Guid; aForce: Boolean = false): UserInfo; locked on self;
    begin
      result := if not aForce then fUsersByID[aUserID];
      if not assigned(result) then begin

        result := ChatControllerProxy.FindUser(aUserID);
        if not assigned(result) then
          raise new Exception($"User '{aUserID}' not found.");
        fUsersByID[aUserID] := result;

      end;
    end;

    //
    //
    //

    method Connect(aHostName: not nullable String; aPort: Integer; aAuthenticationCode: not nullable Guid);
    begin
      fIPClient.ConnectToChat(aHostName, aPort, aAuthenticationCode);
    end;

    method Disconnect;
    begin
      fIPClient:DisconnectFromChat;
    end;

    var fIPClient: IPChatClient; private;
    property PackageStore: PackageStore read fIPClient.PackageStore;

    property NewMessageReceived: block(aChat: Chat; aMessage: MessageInfo);
    property MessageStatusChanged: block(aChat: Chat; aMessageID: Guid; aStatus: MessageStatus);
    property OnError: block(aString: String);

    property OnConnect: block;
    property OnDisconnect: block;

    //
    // incoming packages
    //

    method OnReceivePackage(aPackage: Package); override; protected;
    begin
      try

        Logging.Connection($"Client {UserID} received: {aPackage.MessageID}, {aPackage.Type}, {aPackage.Payload}");
        case aPackage.Type of
          PackageType.Message: begin
              //var lMessage := CreateMessage(aPackage);
              Logging.Connection($"Client: New message received");//: {lMessage}");
              SendStatusResponse(aPackage, MessageStatus.Delivered, DateTime.UtcNow);
              var lChat := FindChat(aPackage.ChatID);
              try
                var lMessage := DecodeMessage(aPackage, lChat);
                Logging.Connection($"Client: decrypted message: {lMessage.Payload}");
                SendStatusResponse(aPackage, MessageStatus.Decrypted, DateTime.UtcNow);
                lChat.AddMessage(lMessage);
                if assigned(NewMessageReceived) then
                  NewMessageReceived(lChat, lMessage);
              except
                on E: Exception do begin
                  Logging.Error($"E {E}");
                  if assigned(OnError) then
                    OnError(E.ToString);
                  SendStatusResponse(aPackage, MessageStatus.FailedToDecrypt, DateTime.UtcNow);
                end;
              end;
            end;
          PackageType.Status: begin
              var lStatus := (aPackage.Payload as StatusPayload).Status;
              Logging.Connection($"PackageType.Status {lStatus}");

              case lStatus of
                MessageStatus.FailedToDecrypt: begin
                    ResendMessage(aPackage.MessageID);
                  end;
                MessageStatus.Decrypted: begin
                    DiscardMessage(aPackage.MessageID);
                  end;
                MessageStatus.Received: begin
                    var lChat := FindChat(aPackage.ChatID);
                    if not lChat.DeliveryNotifications then {$HINT use a separate flag for that, later.}
                      fMessages[aPackage.MessageID] := nil;
                  end;
                //MessageStatus.Delivered,
                //MessageStatus.Displayed,
                //MessageStatus.Read,
              end;

              Logging.Connection($"Client: New status received for {aPackage.MessageID}: {aPackage.Type}");
              var lChat := FindChat(aPackage.ChatID);
              SetMessageStatus(aPackage.MessageID, lChat, lStatus);
            end;
          else raise new Exception($"Unexpected Package Type {aPackage.Type}");
        end;

      except
        on E: Exception do
          Logging.Error($"{E.Message}");
      end;
    end;

    method SetMessageStatus(aMessageID: not nullable Guid; aChat: not nullable Chat; aStatus: MessageStatus);
    begin
      aChat.SetMessageStatus(aMessageID, aStatus);
      if assigned(MessageStatusChanged) then
        MessageStatusChanged(aChat, aMessageID, aStatus);
    end;

    method SendStatusResponse(aPackage: Package; aStatus: MessageStatus; aDate: DateTime);
    begin
      var lPackage := new Package(&Type := PackageType.Status,
                                  ID := Guid.NewGuid,
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
    var fUsersByID := new Dictionary<Guid,UserInfo>; private;

    //property Persons: ImmutableList<UserInfo>;// read fPersons;
    //var fPersons := new List<UserInfo>; private;

    method AddChat(aChat: Chat);
    begin
      fChats.Add(aChat);
      fChatsByID[aChat.ChatID] := aChat;
    end;

    //

    method SendMessage(aMessage: not nullable MessageInfo; aChatInfo: nullable ChatInfo := nil; aUserInfo: nullable UserInfo := nil);
    begin
      aMessage.SenderID := UserID;
      aMessage.ID := coalesce(aMessage.ID, Guid.NewGuid);
      aMessage.SendCount := aMessage.SendCount+1;

      if assigned(aUserInfo) then
        fUsersByID[aUserInfo.ID] := aUserInfo;

      var lChat := if assigned(aChatInfo) then FindChat(aChatInfo) else FindChat(aMessage.ChatID);
      var lEncryptedMessage := EncryptMessage(aMessage, lChat);

      var lPackage := new Package(&Type := PackageType.Message,
                                  ID := Guid.NewGuid,
                                  SenderID := UserID,
                                  ChatID := lChat.ChatID,
                                  MessageID := aMessage.ID,
                                  Sent := coalesce(aMessage.Sent, DateTime.UtcNow),
                                  Payload := lEncryptedMessage);
      SendPackage(lPackage);
      fMessages[aMessage.ID] := aMessage;
    end;

    method ResendMessage(aMessageID: Guid);
    begin
      Logging.Connection($"ResendMessage {aMessageID}");
      var lMessage := fMessages[aMessageID];
      if assigned(lMessage) then begin
        var lChat := FindChat(lMessage.ChatID);
        var lUser := FindUser(lChat.UserIDs.First(u -> u ≠ UserID));

        if RefreshPublicKey(lUser) then begin
          Logging.Keys($"Key was refreshed");

          if lMessage.SendCount < MaximumDeliveryAttempts then begin
            SendMessage(lMessage);
          end
          else begin
            SetMessageStatus(lMessage.ID, lChat, MessageStatus.FailedPermanently);
          end;

        end;
      end;
    end;

    method DiscardMessage(aMessageID: Guid);
    begin
      fMessages[aMessageID] := nil;
    end;

    property MaximumDeliveryAttempts: Integer := 5;

  private

    var fMessages := new Dictionary<Guid,MessageInfo>;

    method EncryptMessage(aMessage: MessageInfo; aChat: Chat): MessagePayload;
    begin
      var lStringData := aMessage.Payload.ToJsonString(JsonFormat.Minimal);
      var lData := Encoding.UTF8.GetBytes(lStringData);

      result := new MessagePayload;
      //if aChat.PublicKey:HasPublicKey then
        //Logging.Keys($"EncryptMessage PublicKey: {Convert.ToHexString(length(aChat.PublicKey:GetPublicKey), 8)} {aChat.PublicKey:GetPublicKey.ToHexString}")
      //else
        //Logging.Keys($"EncryptMessage PublicKey: none");

      var lKeyPair := case aChat.Type of
        ChatType.Private: FindUser(aChat.UserIDs.First(u -> u ≠ UserID)).PublicKey;
        ChatType.Group: aChat.SharedKeyPair;
        else raise new Exception($"Unexpected chat type {aChat.Type}.")
      end;

      if lKeyPair:HasPublicKey then begin
        if length(lData) < lKeyPair.Size then begin
          result.Message := lKeyPair.EncryptWithPublicKey(lData);
          result.Format := "rsa";
        end
        else begin
          var lKey := SymmetricKey.Generate(KeyType.AES);
          result.Key := lKeyPair.EncryptWithPublicKey(lKey.GetKey);
          var lEncrypted := lKey.Encrypt(lData);
          result.Message := lEncrypted[0];
          result.IV := lKeyPair.EncryptWithPublicKey(lEncrypted[1]);
          result.Format := "aes+rsa";
        end;
        result.IsEncrypted := lKeyPair:HasPublicKey;
      end
      else begin
        result.Message := lData;
        result.Format := "plain";
        result.IsEncrypted := lKeyPair:HasPublicKey;
      end;

      if not OwnKeyPair:HasPrivateKey then
        raise new Exception("User does not have a private key set up.");

      result.Signature := OwnKeyPair.SignWithPrivateKey(lData);

      //Logging.Keys($"-- encode --");
      //Logging.Keys($"StringData       {Convert.ToHexString(length(lStringData), 8)} {lStringData}");
      //Logging.Keys($"lata             {Convert.ToHexString(length(lData), 8)} {lData.ToHexString}");
      //Logging.Keys($"EncryptedMessage {Convert.ToHexString(length(result.EncryptedMessage), 8)} {result.EncryptedMessage.ToHexString}");
      //Logging.Keys($"Signature        {Convert.ToHexString(length(result.Signature), 8)} {result.Signature.ToHexString}");
      //Logging.Keys($"PublicKey        {Convert.ToHexString(length(aChat.PublicKey.GetPublicKey), 8)} {aChat.PublicKey.GetPublicKey.ToHexString(" ", 16)}");
    end;

    //method DecodeMessage(aPackage: Package): MessageInfo;
    //begin
      //var lChat := FindChat(aPackage.ChatID);
      //result := DecodeMessage(aPackage.Payload as MessagePayload, lChat);
    //end;

    method DecodeMessage(aPackage: Package; aChat: Chat): MessageInfo;
    begin

      if aPackage.Payload is not MessagePayload then
        raise new Exception($"Unexpected payload type '{typeOf(aPackage.Payload)}' for message");
      var lPayload := aPackage.Payload as MessagePayload;

      result := DecodePayload(lPayload, aChat);

      {$HINT not happy with how this is split}
      result.ID := aPackage.MessageID;
      result.ChatID := aPackage.ChatID;
      result.SenderID := aPackage.SenderID;
      result.Chat := ChatControllerProxy.FindChat(aChat.ChatID);
      result.Sent := aPackage.Sent;
      result.Received := DateTime.UtcNow;

      result.Sender := FindSender(aPackage.SenderID);
    end;

    method DecodePayload(aPayload: MessagePayload; aChat: Chat): MessageInfo; public;
    begin
      result := new MessageInfo;

      //Logging.Keys($"-- decode --");
      //Logging.Keys($"Signature        {Convert.ToHexString(length(lPayload.Signature), 8)} {lPayload.Signature.ToHexString}");
      //Logging.Keys($"EncryptedMessage {Convert.ToHexString(length(lPayload.EncryptedMessage), 8)} {lPayload.EncryptedMessage.ToHexString}");


      Log($"aPayload.IsEncrypted {aPayload.IsEncrypted}");
      Log($"aChat {aChat}");
      Log($"aChat.SharedKeyPair {aChat.SharedKeyPair}");
      if assigned(aChat.SharedKeyPair) then
        Log($"aChat.SharedKeyPair.HasPrivateKey {aChat.SharedKeyPair.HasPrivateKey}");
      Log($"aChat.Type {aChat.Type}");

      case aChat.Type of
        ChatType.Private: begin

          Log($"Private chat");
          if aPayload.IsEncrypted and not assigned(OwnKeyPair) or not OwnKeyPair.HasPrivateKey then
            raise new Exception("Payload is encrypted, but user has no own private key.");

          //Logging.Keys($"OwnPrivateKey    {Convert.ToHexString(length(OwnKeyPair:GetPrivateKey), 8)} {OwnKeyPair:GetPrivateKey.ToHexString(" ", 16)}");

          //if OwnKeyPair:HasPublicKey then
            //Logging.Keys($"DecodePayload PrivateKey: {Convert.ToHexString(length(OwnKeyPair:GetPublicKey), 8)} {OwnKeyPair:GetPublicKey.ToHexString}")
          //else
            //Logging.Keys($"DecodePayload PrivateKey: none");

            //Logging.Keys($"aPayload.IsEncrypted {aPayload.IsEncrypted}");
            //Logging.Keys($"aPayload.EncryptedMessage {Convert.ToHexString(aPayload.EncryptedMessage)}");
            //Logging.Keys($"aPayload.EncryptedMessage {Convert.ToAsciiString(aPayload.EncryptedMessage)}");

            var lDecryptedMessage := if aPayload.IsEncrypted then OwnKeyPair.DecryptWithPrivateKey(aPayload.EncryptedMessage) else aPayload.EncryptedMessage;
            var lString := Encoding.UTF8.GetString(lDecryptedMessage);

            result.Payload := JsonDocument.FromString(lString);

            //Logging.Keys($"DecodePayload PublicKey: {Convert.ToHexString(length(result.Sender:PublicKey:GetPublicKey), 8)} {result.Sender:PublicKey:GetPublicKey.ToHexString}");
            if result.Sender:PublicKey:HasPublicKey then begin
              result.SignatureValid := result.Sender.PublicKey.ValidateSignatureWithPublicKey(lDecryptedMessage, aPayload.Signature);
              Logging.Keys($"result.SignatureValid {result.SignatureValid}");
              if not result.SignatureValid then begin
                if RefreshPublicKey(result.Sender) then
                  result.SignatureValid := result.Sender.PublicKey.ValidateSignatureWithPublicKey(lDecryptedMessage, aPayload.Signature);
                Logging.Keys($"result.SignatureValid {result.SignatureValid}, now");
              end;
            end;

          end;
        ChatType.Group: begin

            Log($"Group chat");

            if aPayload.IsEncrypted and (not assigned(aChat.SharedKeyPair) or not aChat.SharedKeyPair.HasPrivateKey) then
              raise new Exception("Payload is encrypted, but group chat has no private key.");

            var lDecryptedMessage := if aPayload.IsEncrypted then aChat.SharedKeyPair.DecryptWithPrivateKey(aPayload.EncryptedMessage) else aPayload.EncryptedMessage;
            var lString := Encoding.UTF8.GetString(lDecryptedMessage);

            result.Payload := JsonDocument.FromString(lString);

            if assigned(result.Sender:PublicKey) then begin
              result.SignatureValid := result.Sender.PublicKey.ValidateSignatureWithPublicKey(lDecryptedMessage, aPayload.Signature);
              if not result.SignatureValid then begin
                if RefreshPublicKey(result.Sender) then
                  result.SignatureValid := result.Sender.PublicKey.ValidateSignatureWithPublicKey(lDecryptedMessage, aPayload.Signature);
              end;
            end;

          end;
        else raise new Exception($"Unexpected chat type {aChat.Type}.")

      end;



      //Logging.Keys($"-- decode --");
      //Logging.Keys($"lSignature        {aPayload.Signature.ToHexString}");
      //Logging.Keys($"lEncryptedMessage {aPayload.EncryptedMessage.ToHexString}");
      //Logging.Keys($"result.Payload {result.Payload}");
      //Logging.Keys($"result.SignatureValid {result.SignatureValid}");

    end;

    //
    //
    //

    //method Connect;
    //begin
      //var lAuthenticationCode: Guid;// := fChatServer.GetChatAuthenticationCode;

      //var lAuthenticationMessage := new Byte[2+Guid.Size*2];
      //lAuthenticationMessage[0] := ord('A');
      //&Array.Copy(UserID.ToByteArray, 0, lAuthenticationMessage, 1, Guid.Size);
      //lAuthenticationMessage[1+Guid.Size] := ord('-');
      //&Array.Copy(lAuthenticationCode.ToByteArray, 0, lAuthenticationMessage, 2+Guid.Size, Guid.Size);

      //// Connect
      //// SendMessage(lAuthenticationMessage)
    //end;

    method FindSender(aSenderID: Guid): nullable UserInfo;
    begin
      if assigned(aSenderID) then
        result := FindUser(aSenderID);
    end;

    method RefreshPublicKey(aPerson: UserInfo): Boolean;
    begin
      var lNewUserInfo := FindUser(aPerson.ID, true);
      result := aPerson.PublicKeyData ≠ lNewUserInfo.PublicKeyData;
      if result then begin
        Logging.Keys($"got a new key");
        aPerson.PublicKeyData := lNewUserInfo.PublicKeyData;
      end
      else begin
        Logging.Keys($"no new key");
      end;
      Logging.Keys($"old key {Convert.ToHexString(aPerson.PublicKeyData)}");
      Logging.Keys($"new key {Convert.ToHexString(lNewUserInfo.PublicKeyData)}");
    end;

  end;



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