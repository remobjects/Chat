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
      for each u in UserIDs do begin
        if u ≠ aAllButUserID then try
          Hub.FindClient(u).Send(lPackage);
        except
          on E: Exception do
            Log($"Could not deliver message to {u}:  {E}");
        end;
      end;
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
            ChatManager.ActiveChatManager.MessageReceived(self, aPackage.SenderID, lMessage);
            SendStatusResponse(lMessage, nil, MessageStatus.Received, DateTime.UtcNow);
          end;
        PackageType.Status: begin
            var lStatus := (aPackage.Payload as StatusPayload).Status;
            case lStatus of
              MessageStatus.Received: raise new Exception("Should not happen on server");
              MessageStatus.Delivered,
              MessageStatus.Decrypted,
              MessageStatus.FailedToDecrypt,
              MessageStatus.Displayed,
              MessageStatus.Read: begin
                  Log($"Server: New status received for {aPackage.MessageID}: {aPackage.Type}");
                  NotifyStatus(aPackage);
                end;
              else raise new Exception($"Unexpected Message Status {lStatus}")
            end;
          end;
        else raise new Exception($"Unexpected Package Type {aPackage.Type}");
      end;
    end;

    //

    method NotifyStatus(aPackage: Package);
    begin
      var lMessage := Hub.FindMessage(aPackage);
      case aPackage.Type of
        PackageType.Status: begin
            var lStatus := (aPackage.Payload as StatusPayload).Status;
            case lStatus of
              MessageStatus.Received: ;{no-op}
              MessageStatus.Delivered: lMessage.Delivered := aPackage.Sent;
              MessageStatus.Decrypted: lMessage.Decryted := aPackage.Sent;
              MessageStatus.FailedToDecrypt: ;
              MessageStatus.Displayed: lMessage.Displayed := aPackage.Sent;
              MessageStatus.Read: lMessage.Read := aPackage.Sent;
              else raise new Exception($"Unexpected message status {lStatus}");
            end;
            SendStatusResponse(lMessage, aPackage.SenderID, lStatus, aPackage.Sent);
          end;
      end;
    end;

    method SendStatusResponse(aMessage: HubMessage; aSenderID: nullable Guid; aStatus: MessageStatus; aDate: DateTime);
    begin
      var lPackage := new Package(&Type := PackageType.Status,
                                  ID := Guid.NewGuid,
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