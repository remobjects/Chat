﻿namespace ChatTestClient;

uses
  RemObjects.Elements.Serialization,
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
      // add your own code here
      writeLn('The magic happens here.');
      //var lKey := KeyPair.Generate(KeyType.RSA);
      ////var lKey := new KeyPair fromKeychain;
      //Log($"Key.GenerateKey {Convert.ToHexString(lKey.GetPublicKey)}");
      //Log($"Key.GenerateKey {Convert.ToHexString(lKey.GetPrivateKey)}");

      var lLocalDummyQueue := new LocalFolderTestQueue<Package> withFolder("/Users/mh/temp/FolderQueue1"); // local connection from Client 1 to Server

      var lDummyQueue1 := new LocalQueue<Package>; // local connection from Client 1 to Server
      var lDummyQueue2 := new LocalQueue<Package>; // local connection from Client 2 to Server

      //
      // Set up the Clients
      //

      var lUser1 := new UserInfo(ID := Guid.NewGuid, Name := "User 1", PublicKey := KeyPair.Generate(KeyType.RSA));
      var lUser2 := new UserInfo(ID := Guid.NewGuid, Name := "User 2", PublicKey := KeyPair.Generate(KeyType.RSA));

      var lClient1 := new ChatClient(User := lUser1, OwnKeyPair := lUser1.PublicKey);
      lClient1.Queue := lLocalDummyQueue;//lDummyQueue1.ClientEndpoint;
      lClient1.ChatControllerProxy := ChatController.Instance;

      var lClient2 := new ChatClient(User := lUser2, OwnKeyPair := lUser2.PublicKey);
      lClient2.Queue := lDummyQueue2.ClientEndpoint;
      lClient2.ChatControllerProxy := ChatController.Instance;



      //
      // Set up the Server
      //

      {$IF ECHOES}
      ChatManager.ActiveChatManager := new InMemoryChatManager;
      (ChatManager.ActiveChatManager as InMemoryChatManager).__AddUser(lUser1);
      (ChatManager.ActiveChatManager as InMemoryChatManager).__AddUser(lUser2);

      var lHub := new RemObjects.Chat.Server.Hub as not nullable;

      var lHubClient1 := new RemObjects.Chat.Server.HubClient(Hub := lHub, User := lUser1);
      lHubClient1.Queue := lDummyQueue1.ServerEndpoint;
      lHub.Clients[lHubClient1.UserID] := lHubClient1;

      var lHubClient2 := new RemObjects.Chat.Server.HubClient(Hub := lHub, User := lUser2);
      lHubClient2.Queue := lDummyQueue2.ServerEndpoint;
      lHub.Clients[lHubClient2.UserID] := lHubClient2;
      {$ENDIF}

      //
      // Set up the chat. Normally this would be a call to a server API, say via ROSDK
      //

      var lChat := ChatController.Instance.CreatePrivateChat(lClient1.UserID, lClient2.UserID);

      //
      // Set up the local chat, for both users. Nprmally this would happen after calling the above API
      //

      var lChat1 := new Chat(lClient1, lChat.ID, [lClient1.UserID, lClient2.UserID].ToList, ChatType.Private);

      var lMessage := new ChatMessage;
      lMessage.Payload := JsonDocument.FromString('{"senderId": "{3e6eaa7a-d8a2-4c00-868b-7f8c2a0f1e97}", "message": "hello WUnite!!"}');

      lClient1.SendMessage(lMessage, lChat1);
    end;

  end;

end.