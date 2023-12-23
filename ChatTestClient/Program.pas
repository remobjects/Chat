namespace ChatTestClient;

uses
  RemObjects.Elements.Serialization,
  RemObjects.Infrastructure,
  RemObjects.Infrastructure.Encryption,
  RemObjects.Chat,
  RemObjects.Chat.Client;

type
  Program = class
  public
    class method Main(args: array of String): Int32;
    begin
      // add your own code here
      writeLn('The magic happens here.');
      //var lKey := KeyPair.Generate(KeyType.RSA);
      ////var lKey := new KeyPair fromKeychain;
      //Log($"Key.GenerateKey {Convert.ToHexString(lKey.GetPublicKey)}");
      //Log($"Key.GenerateKey {Convert.ToHexString(lKey.GetPrivateKey)}");

      //var lChatUser := new ChatUser;
      //lChatUser.OwnKeyPair := KeyPair.Generate(KeyType.RSA);;
      var lChatUser := new ChatUser withFolder("/Users/mh/temp/Chat1");
      lChatUser.OwnKeyPair := KeyPair.Generate(KeyType.RSA);
      writeLn($"public:  {lChatUser.OwnKeyPair.GetPublicKey.ToHexString}");
      writeLn($"private: {lChatUser.OwnKeyPair.GetPrivateKey.ToHexString}");

      var lUserID := Guid.NewGuid;

      {$IF ECHOES}
      var lHub := new RemObjects.Chat.Server.Hub as not nullable;
      var lDummyQueue1 := new LocalQueue<Package>;
      lDummyQueue1.ClientEndpoint.Receive := (aPackage) -> begin
        Log($"aPackage {aPackage.Payload}");
      end;
      var lHubClient1 := new RemObjects.Chat.Server.HubClient(Hub := lHub, UserID := lUserID);
      lHubClient1.Queue := lDummyQueue1.ServerEndpoint;
      lHub.Clients[lHubClient1.UserID] := lHubClient1;
      {$ENDIF}


      var lChat := new PrivateChat;
      lChat.Person := new Person;
      lChat.Person.PublicKey := lChatUser.OwnKeyPair;//PublicKey.Generate(KeyType.RSA);
      lChatUser.AddChat(lChat);

      lChatUser.Save("/Users/mh/temp/Chat1");

      var lMessage := new ChatMessage;
      lMessage.Payload := JsonDocument.FromString('{"test": "test2"}');

      var lEncodedMessage := lChatUser.EncodeMessage(lMessage, lChat);
      //Log($"lEncodedMessage {lEncodedMessage}");
      lEncodedMessage.Save("/Users/mh/temp/message1.msg");

      var lPackage := new Package(&Type := PackageType.Message,
                                  SenderID := lUserID,
                                  ChatID := lChat.ID,
                                  MessageID := Guid.NewGuid,
                                  Payload := lEncodedMessage);
      lDummyQueue1.ClientEndpoint.Send(lPackage);

      var lLoadedMessage := new MessagePayload;
      lLoadedMessage.Load("/Users/mh/temp/message1.msg");
      //Log($"lLoadedMessage {lLoadedMessage}");
      /*var lMessage2 :=*/ lChatUser.DecodeMessage(lLoadedMessage, lChat)

      //var lCoder := new JsonCoder;
      //lCoder.Encode(lChatUser);
      //Log($"lCoder.ToString {lCoder.ToString}");
    end;

  end;

end.