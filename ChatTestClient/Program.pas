namespace ChatTestClient;

uses
  RemObjects.Elements.Serialization,
  RemObjects.Infrastructure.Encryption,
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
      writeLn($"public:  {lChatUser.OwnKeyPair.GetPublicKey.ToHexString}");
      writeLn($"private: {lChatUser.OwnKeyPair.GetPrivateKey.ToHexString}");

      var lChat := new PrivateChat;
      lChat.Person := new Person;
      lChat.Person.PublicKey := PublicKey.Generate(KeyType.RSA);
      lChatUser.AddChat(lChat);

      lChatUser.Save("/Users/mh/temp/Chat1");

      var lMessage := new ChatMessage;
      lMessage.Payload := JsonDocument.FromString('{"test": "test2"}');

      var lEncodedMessage := lChatUser.EncodeMessage(lMessage, lChat);
      File.WriteBytes("/Users/mh/temp/message1.msg", lEncodedMessage);

      var lLoadedMessage := File.ReadBytes("/Users/mh/temp/message1.msg");
      /*var lMessage2 :=*/ lChatUser.DecodeMessage(lLoadedMessage, lChat)

      //var lCoder := new JsonCoder;
      //lCoder.Encode(lChatUser);
      //Log($"lCoder.ToString {lCoder.ToString}");
    end;

  end;

end.