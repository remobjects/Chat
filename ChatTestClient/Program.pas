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

      var lDummyQueue1 := new LocalQueue<Package>;
      //lDummyQueue1.ClientEndpoint.Receive := (aPackage) -> begin
        //Log($"Client1 received: {aPackage.MessageID}, {aPackage.Type}, {aPackage.Payload}");
      //end;

      var lDummyQueue2 := new LocalQueue<Package>;
      //lDummyQueue2.ClientEndpoint.Receive := (aPackage) -> begin
        //Log($"Client2: received: {aPackage.MessageID}, {aPackage.Type}, {aPackage.Payload}");
      //end;

      var lClient1 := new Client(UserID := Guid.NewGuid);
      lClient1.OwnKeyPair := KeyPair.Generate(KeyType.RSA);
      lClient1.Queue := lDummyQueue1.ClientEndpoint;
      //writeLn($"public:  {lClient1.OwnKeyPair.GetPublicKey.ToHexString}");
      //writeLn($"private: {lClient1.OwnKeyPair.GetPrivateKey.ToHexString}");

      var lClient2 := new Client(UserID := Guid.NewGuid);
      lClient2.UserID := Guid.NewGuid;
      lClient2.OwnKeyPair := KeyPair.Generate(KeyType.RSA);
      lClient2.Queue := lDummyQueue2.ClientEndpoint;
      //writeLn($"public:  {lClient2.OwnKeyPair.GetPublicKey.ToHexString}");
      //writeLn($"private: {lClient2.OwnKeyPair.GetPrivateKey.ToHexString}");

      {$IF ECHOES}
      var lHub := new RemObjects.Chat.Server.Hub as not nullable;

      var lHubClient1 := new RemObjects.Chat.Server.HubClient(Hub := lHub, UserID := lClient1.UserID);
      lHubClient1.Queue := lDummyQueue1.ServerEndpoint;
      lHub.Clients[lHubClient1.UserID] := lHubClient1;

      var lHubClient2 := new RemObjects.Chat.Server.HubClient(Hub := lHub, UserID := lClient2.UserID);
      lHubClient2.Queue := lDummyQueue2.ServerEndpoint;
      lHub.Clients[lHubClient2.UserID] := lHubClient2;
      {$ENDIF}


      var lChat1 := new PrivateChat;
      lChat1.ID := lClient2.UserID;
      lChat1.Person := new Person;
      lChat1.Person.PublicKey := lClient2.OwnKeyPair;//PublicKey.Generate(KeyType.RSA);

      var lChat2 := new PrivateChat;
      lChat2.ID := lClient1.UserID;
      lChat2.Person := new Person;
      lChat2.Person.PublicKey := lClient1.OwnKeyPair;//PublicKey.Generate(KeyType.RSA);

      lClient1.AddChat(lChat2);
      lClient2.AddChat(lChat1);

      lClient1.Save("/Users/mh/temp/Client1");
      lClient2.Save("/Users/mh/temp/Client2");

      var lMessage := new ChatMessage;
      lMessage.Payload := JsonDocument.FromString('{"message": "hello WUnite!!"}');

      lClient1.SendMessage(lMessage, lChat1);

      //var lEncodedMessage := lClient1.EncodeMessage(lMessage, lChat);
      ////Log($"lEncodedMessage {lEncodedMessage}");
      //lEncodedMessage.Save("/Users/mh/temp/message1.msg");

      //var lPackage := new Package(&Type := PackageType.Message,
                                  //SenderID := lClient1.UserID,
                                  //ChatID := lChat.ID,
                                  //MessageID := Guid.NewGuid,
                                  //Payload := lEncodedMessage);
      //lDummyQueue1.ClientEndpoint.Send(lPackage);

      //var lLoadedMessage := new MessagePayload;
      //lLoadedMessage.Load("/Users/mh/temp/message1.msg");
      //Log($"lLoadedMessage {lLoadedMessage}");
      // /*var lMessage2 :=*/ lChatUser.DecodeMessage(lLoadedMessage, lChat)

      //var lCoder := new JsonCoder;
      //lCoder.Encode(lChatUser);
      //Log($"lCoder.ToString {lCoder.ToString}");
    end;

  end;

end.