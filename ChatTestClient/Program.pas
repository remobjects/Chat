namespace ChatTestClient;

uses
  //RemObjects.Elements.Serialization,
  RemObjects.Infrastructure,
  RemObjects.Infrastructure.Encryption,
  RemObjects.Chat,
  RemObjects.Chat.Client;

{$IF ECHOES}
uses
  RemObjects.Chat.Server;
{$ENDIF}

type
  Program = class
  public
    class method Main(args: array of String): Int32;
    begin

      var m := JsonDocument.CreateObject;
      m["test"] := "blub";
      var d := File.ReadBytes("/Users/mh/Downloads/Bestelling controleren - Veilig afrekenen.pdf");
      var k := KeyPair.Generate(KeyType.RSA);

      //var a := new JsonPayloadWithAttachment withJson(m, d);

      //Log($"a.Data  {Convert.ToAsciiString(a.Data)}");
      //Log($"a.Data  {Convert.ToHexString(a.Data)}");
      //Log($"a.Bytes {Convert.ToAsciiString(a.Bytes)}");
      //Log($"a.Bytes {Convert.ToHexString(a.Bytes)}");

      //var b := new JsonPayloadWithAttachment withBytes(a.Bytes);

      //Log($"b.Data  {Convert.ToAsciiString(b.Data)}");
      //Log($"b.Data  {Convert.ToHexString(b.Data)}");
      //Log($"b.Bytes {Convert.ToAsciiString(b.Bytes)}");
      //Log($"b.Bytes {Convert.ToHexString(b.Bytes)}");
      ////Log($"b.Json {b.Json}");
      ////Log($"Convert.ToAsciiString(b.Binary) {Convert.ToAsciiString(b.Binary)}");
      ////Log($"Convert.ToHexString(b.Binary)   {Convert.ToHexString(b.Binary)}");


      //var c := new JsonPayloadWithAttachment;
      //Log($"Convert.ToAsciiString(b.Payload) {Convert.ToAsciiString(b.Bytes)}");
      //c.SetEncryptedDataWithPublicKey(b.Bytes, k);
      //Log($"c.Json {c.Json}");
      //Log($"c.Data    {Convert.ToAsciiString(c.Data)}");
      //Log($"c.Data    {Convert.ToHexString(c.Data)}");
      //Log($"c.Bytes   {Convert.ToAsciiString(c.Bytes)}");
      //Log($"c.Bytes   {Convert.ToHexString(c.Bytes)}");

      //var f := c.GetDecryptedDataWithPrivateKey(k);
      //Log($"Convert.ToAsciiString(f) {Convert.ToAsciiString(f)}");
      //Log($"Convert.ToHexString(f)   {Convert.ToHexString(f)}");

      var p := new MessagePayload;
      p.SetEncryptedDataWithPublicKey(Encoding.UTF8.GetBytes(m.ToJsonString), k);
      Log($"p {p}");
      Log($"p.Bytes {Convert.ToAsciiString(p.Bytes)}");

      var f := p.GetDecryptedDataWithPrivateKey(k);
      Log($"Convert.ToAsciiString(f) {Convert.ToAsciiString(f)}");
      Log($"Convert.ToHexString(f)   {Convert.ToHexString(f)}");
      var j := JsonDocument.FromString(Encoding.UTF8.GetString(f));
      Log($"j {j}");



      exit;

      {$IF ECHOES}

      //var lLocalDummyQueue := new LocalFolderTestQueue<Package> withFolder("/Users/mh/temp/FolderQueue1"); // local connection from Client 1 to Server
      var lDummyQueue1 := new LocalQueue<Package>; // local connection from Client 1 to Server
      var lDummyQueue2 := new LocalQueue<Package>; // local connection from Client 2 to Server

      //
      // Set up the Clients
      //

      var lUser1 := new UserInfo(Guid.NewGuid, "User 1", PublicKey := KeyPair.Generate(KeyType.RSA));
      var lUser2 := new UserInfo(Guid.NewGuid, "User 2", PublicKey := KeyPair.Generate(KeyType.RSA));

      var lClient1 := new ChatClient(User := lUser1, OwnKeyPair := lUser1.PublicKey);
      lClient1.Queue := /*lLocalDummyQueue;//*/lDummyQueue1.ClientEndpoint;
      lClient1.ChatControllerProxy := ChatController.Instance;

      var lClient2 := new ChatClient(User := lUser2, OwnKeyPair := lUser2.PublicKey);
      lClient2.Queue := lDummyQueue2.ClientEndpoint;
      lClient2.ChatControllerProxy := ChatController.Instance;



      //
      // Set up the Server
      //

      ChatManager.ActiveChatManager := new InMemoryChatManager;
      (ChatManager.ActiveChatManager as InMemoryChatManager).__AddUser(lUser1);
      (ChatManager.ActiveChatManager as InMemoryChatManager).__AddUser(lUser2);

      ClientQueueManager.ActiveClientQueueManager := new DefaultClientQueueManager<InMemoryClientQueue>;

      var lHubClient1 := new RemObjects.Chat.Server.HubClient(Hub := Hub.Instance, User := lUser1);
      lHubClient1.Queue := lDummyQueue1.ServerEndpoint;
      Hub.Instance.Clients[lHubClient1.UserID] := lHubClient1;

      //var lHubClient2 := new RemObjects.Chat.Server.HubClient(Hub := Hub.Instance, User := lUser2);
      //lHubClient2.Queue := lDummyQueue2.ServerEndpoint;
      //Hub.Instance.Clients[lHubClient2.UserID] := lHubClient2;

      //
      // Set up the chat. Normally this would be a call to a server API, say via ROSDK
      //

      var lChat := ChatController.Instance.CreatePrivateChat(lClient1.UserID, lClient2.UserID);

      //
      // Set up the local chat, for both users. Nprmally this would happen after calling the above API
      //

      var lChat1 := new Chat(lClient1, lChat.ID, [lClient1.UserID, lClient2.UserID].ToList, ChatType.Private);

      var lMessage := new MessageInfo;
      //lMessage.Payload := JsonDocument.FromString('{"senderId": "{3e6eaa7a-d8a2-4c00-868b-7f8c2a0f1e97}", "message": "hello WUnite!!"}');
      lMessage.Payload := JsonDocument.FromString('{"message": "hello WUnite!!"}');
      lMessage.ChatID := lChat1.ChatID;

      lClient1.SendMessage(lMessage);

      {$ENDIF}
    end;

  end;

end.