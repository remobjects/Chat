namespace RemObjects.Chat.Client;

uses
  RemObjects.Chat,
  RemObjects.Chat.Connection,
  RemObjects.Infrastructure,
  RemObjects.Infrastructure.Encryption;

type
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
    //
    //

    method Connect(aHostName: String; aPort: Integer; aAuthenticationCode: Guid);
    begin
      if not assigned(fIPClient) then begin
        fIPClient := new IPChatClient(HostName := aHostName, Port := aPort, UserID := UserID);
        Queue := fIPClient;
      end;
      fIPClient.ConnectToChat(aAuthenticationCode);
    end;

    method Disconnect;
    begin
      fIPClient.DisconnectFromChat;
    end;

    var fIPClient: IPChatClient; private;


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
              try
                var lMessage := DecodeMessage(aPackage, lChat);
                Log($"Client: decrypted message: {lMessage.Payload}");
                SendStatusResponse(aPackage, PackageType.Decrypted, DateTime.UtcNow);
                lChat.AddMessage(lMessage);
              except
                on E: Exception do begin
                  Log($"E {E}");
                  SendStatusResponse(aPackage, PackageType.FailedToDecrypt, DateTime.UtcNow);
                end;
              end;
            end;
          PackageType.FailedToDecrypt: begin
              Log($"Client: New status received for {aPackage.MessageID}: {aPackage.Type}.");
              ResendMessage(aPackage.MessageID);
            end;
          PackageType.Decrypted: begin
              Log($"Client: New status received for {aPackage.MessageID}: {aPackage.Type}");
              DiscardMessage(aPackage.MessageID);
            end;
          PackageType.Delivered,
          PackageType.Received,
          PackageType.Displayed,
          PackageType.Read: begin
              var lChat := FindChat(aPackage.ChatID);
              lChat.SetMessageStatus(aPackage.MessageID, aPackage.Type);
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

    //property Persons: ImmutableList<UserInfo>;// read fPersons;
    //var fPersons := new List<UserInfo>; private;

    method AddChat(aChat: Chat);
    begin
      fChats.Add(aChat);
      fChatsByID[aChat.ChatID] := aChat;
    end;

    //

    method SendMessage(aMessage: MessageInfo);
    begin
      aMessage.SenderID := UserID;
      aMessage.ID := Guid.NewGuid;
      aMessage.SendCount := aMessage.SendCount+1;

      var lChat := FindChat(aMessage.ChatID);
      var lEncryptedMessage := EncryptMessage(aMessage, lChat);

      var lPackage := new Package(&Type := PackageType.Message,
                                  ID := Guid.NewGuid,
                                  SenderID := UserID,
                                  ChatID := lChat.ChatID,
                                  MessageID := aMessage.ID,
                                  Payload := lEncryptedMessage);
      SendPackage(lPackage);
      fMessages[aMessage.ID] := aMessage;
    end;

    method ResendMessage(aMessageID: Guid);
    begin
      var lMessage := fMessages[aMessageID];
      if assigned(lMessage) then begin
        var lChat := FindChat(lMessage.ChatID);
        if assigned(lChat.OtherUser) then begin
          RefreshPublicKey(lChat.OtherUser);
          Log($"refreshed");
        end;
        //if lMessage.SendCount < MaximujmDeliveryAttempts then begin
          //SendMessage(lMessage);
        //end
        //else begin
          lChat.SetMessageStatus(lMessage.ID, PackageType.FailedToDecrypt);
        //end;
      end;
    end;

    method DiscardMessage(aMessageID: Guid);
    begin
      fMessages[aMessageID] := nil;
    end;

    property MaximujmDeliveryAttempts: Integer := 5;

  private

    var fMessages := new Dictionary<Guid,MessageInfo>;

    method EncryptMessage(aMessage: MessageInfo; aChat: Chat): MessagePayload;
    begin
      var lStringData := aMessage.Payload.ToJsonString(JsonFormat.Minimal);
      var lData := Encoding.UTF8.GetBytes(lStringData);

      result := new MessagePayload;
      result.EncryptedMessage := aChat.PublicKey.EncryptWithPublicKey(lData);
      result.Signature := OwnKeyPair.SignWithPrivateKey(lData);

      //Log($"-- encode --");
      //Log($"StringData       {Convert.ToHexString(length(lStringData), 8)} {lStringData}");
      //Log($"lata             {Convert.ToHexString(length(lData), 8)} {lData.ToHexString}");
      //Log($"EncryptedMessage {Convert.ToHexString(length(result.EncryptedMessage), 8)} {result.EncryptedMessage.ToHexString}");
      //Log($"Signature        {Convert.ToHexString(length(result.Signature), 8)} {result.Signature.ToHexString}");
      //Log($"PublicKey        {Convert.ToHexString(length(aChat.PublicKey.GetPublicKey), 8)} {aChat.PublicKey.GetPublicKey.ToHexString(" ", 16)}");
    end;

    //method DecodeMessage(aPackage: Package): MessageInfo;
    //begin
      //var lChat := FindChat(aPackage.ChatID);
      //result := DecodeMessage(aPackage.Payload as MessagePayload, lChat);
    //end;

    method DecodeMessage(aPackage: Package; aChat: Chat): MessageInfo;
    begin
      result := new MessageInfo;
      result.ID := aPackage.MessageID;
      result.ChatID := aPackage.ChatID;
      result.SenderID := aPackage.SenderID;

      result.Sender := FindSender(aPackage.SenderID);
      result.Chat := ChatControllerProxy.FindChat(aChat.ChatID);

      if aPackage.Payload is not MessagePayload then
        raise new Exception($"Unexpecyted payload type '{typeOf(aPackage.Payload)}' for message");
      var lPayload := aPackage.Payload as MessagePayload;

      //Log($"-- decode --");
      //Log($"Signature        {Convert.ToHexString(length(lPayload.Signature), 8)} {lPayload.Signature.ToHexString}");
      //Log($"EncryptedMessage {Convert.ToHexString(length(lPayload.EncryptedMessage), 8)} {lPayload.EncryptedMessage.ToHexString}");

      case aChat.Type of
        ChatType.Private: begin
            //Log($"OwnPrivateKey    {Convert.ToHexString(length(OwnKeyPair:GetPrivateKey), 8)} {OwnKeyPair:GetPrivateKey.ToHexString(" ", 16)}");
            var lDecryptedMessage := OwnKeyPair.DecryptWithPrivateKey(lPayload.EncryptedMessage);
            var lString := Encoding.UTF8.GetString(lDecryptedMessage);

            result.Payload := JsonDocument.FromString(lString);

            Log($"PublicKey        {Convert.ToHexString(length(result.Sender:PublicKey:GetPublicKey), 8)} {result.Sender:PublicKey:GetPublicKey.ToHexString}");
            if result.Sender:PublicKey:HasPublicKey then begin
              result.SignatureValid := result.Sender.PublicKey.ValidateSignatureWithPublicKey(lDecryptedMessage, lPayload.Signature);
              if not result.SignatureValid then begin
                if RefreshPublicKey(result.Sender) then
                  result.SignatureValid := result.Sender.PublicKey.ValidateSignatureWithPublicKey(lDecryptedMessage, lPayload.Signature);
              end;
            end;

          end;
        ChatType.Group: begin

            var lDecryptedMessage := aChat.SharedKeyPair.DecryptWithPrivateKey(lPayload.EncryptedMessage);
            var lString := Encoding.UTF8.GetString(lDecryptedMessage);

            result.Payload := JsonDocument.FromString(lString);

            if assigned(result.Sender:PublicKey) then begin
              result.SignatureValid := result.Sender.PublicKey.ValidateSignatureWithPublicKey(lDecryptedMessage, lPayload.Signature);
              if not result.SignatureValid then begin
                if RefreshPublicKey(result.Sender) then
                  result.SignatureValid := result.Sender.PublicKey.ValidateSignatureWithPublicKey(lDecryptedMessage, lPayload.Signature);
              end;
            end;

          end;
        else raise new Exception($"Unexpected chat type {aChat.Type}.")

      end;



      //Log($"-- decode --");
      //Log($"lSignature        {aPayload.Signature.ToHexString}");
      //Log($"lEncryptedMessage {aPayload.EncryptedMessage.ToHexString}");
      //Log($"result.Payload {result.Payload}");
      //Log($"result.SignatureValid {result.SignatureValid}");

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
        result := ChatControllerProxy.FindUser(aSenderID);
    end;

    method RefreshPublicKey(aPerson: UserInfo): Boolean;
    begin
      var lNewUserInfo := ChatControllerProxy.FindUser(aPerson.ID);
      result := aPerson.PublicKeyData ≠ lNewUserInfo.PublicKeyData;
      if result then begin
        Log($"new key");
        aPerson.PublicKeyData := lNewUserInfo.PublicKeyData;
      end
      else begin
        Log($"no new key");
      end;

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