namespace RemObjects.Chat.Server;

uses
  RemObjects.Infrastructure,
  RemObjects.Chat;

type
  HubChat = public class
  public

    constructor(aHub: not nullable Hub; aChatInfo: not nullable ChatInfo);
    begin
      Hub := aHub;
      ChatID := aChatInfo.ID;
      UserIDs := aChatInfo.UserIDs;
    end;

    property Hub: weak not nullable Hub;
    property ChatID: not nullable Guid;

    property UserIDs: ImmutableList<Guid>;

    method CreateMessage(aPackage: not nullable Package): not nullable HubMessage;
    begin
      result := new HubMessage(OriginalPackage := aPackage,
                               Received := DateTime.UtcNow);
      Hub.SaveMessage(result);
      //raise new NotImplementedException("CreateMessage"); {$HINT for now}
    end;

    method DeliverMessage(aMessage: HubMessage) ToAllBut(aAllButUserID: nullable Guid);
    begin
      var lPackage := aMessage.OriginalPackage;
      for each u in UserIDs do
        if u ≠ aAllButUserID then
          Hub.FindClient(u).Queue.Send(lPackage);
    end;

    //
    // Incoming packages
    //

    method OnReceivePackage(aPackage: Package);
    begin
      case aPackage.Type of
        PackageType.Message: begin
            var lMessage := CreateMessage(aPackage);
            Log($"Server: New message received: {lMessage}");
            DeliverMessage(lMessage) ToAllBut(aPackage.SenderID);
            SendStatusResponse(lMessage, Guid.Empty, PackageType.Received, DateTime.UtcNow);
          end;
        PackageType.Received: raise new Exception("Should not happen on server");
        PackageType.Delivered,
        PackageType.Decrypted,
        PackageType.FailedToDecrypt,
        PackageType.Displayed,
        PackageType.Read: begin
            Log($"Server: New status received for {aPackage.MessageID}: {aPackage.Type}");
            NotifyStatus(aPackage);
          end;
      end;
    end;

    //

    method NotifyStatus(aPackage: Package);
    begin
      var lMessage := Hub.FindMessage(aPackage);
      case aPackage.Type of
        PackageType.Received: ;{no-op}
        PackageType.Delivered: lMessage.Delivered := aPackage.Sent;
        PackageType.Decrypted: lMessage.Decryted := aPackage.Sent;
        PackageType.FailedToDecrypt: ;
        PackageType.Displayed: lMessage.Displayed := aPackage.Sent;
        PackageType.Read: lMessage.Read := aPackage.Sent;
        else raise new Exception($"Unexpected package type {aPackage.Type}");
      end;
      SendStatusResponse(lMessage, aPackage.SenderID, aPackage.Type, aPackage.Sent);
    end;

    method SendStatusResponse(aMessage: HubMessage; aSenderID: not nullable Guid; aStatus: PackageType; aDate: DateTime);
    begin
      var lPackage := new Package(&Type := aStatus,
                                  SenderID := aSenderID,
                                  ChatID := ChatID,
                                  MessageID := aMessage.ID,
                                  Payload := new StatusPayload(Status := aStatus,
                                                               Date := DateTime.UtcNow));
      Hub.SendPackage(aMessage.SenderID, lPackage);
    end;


  end;

  //HubPrivateChat = public class(HubChat)
  //public

    ////constructor(aChatInfo: PrivateChatInfo);
    ////begin
      //////
    ////end;

  //end;

  //HubGroupChat = public class(HubChat)
  //public

    ////constructor(aChatInfo: GroupChatInfo);
    ////begin
      //////
    ////end;

  //end;

end.