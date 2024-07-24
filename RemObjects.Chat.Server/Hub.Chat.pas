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
      DeliveryNotifications := aChatInfo.DeliveryNotifications
    end;

    property Hub: weak not nullable Hub;
    property ChatID: not nullable Guid;
    property DeliveryNotifications: Boolean;

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
            Logging.Error($"Could not deliver message to {u}:  {E}");
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
            Logging.Delivery($"Server: New message received: {lMessage}, {aPackage.Sent}");
            DeliverMessage(lMessage) ToAllBut(aPackage.SenderID);
            ChatManager.ActiveChatManager.MessageReceived(self, aPackage.SenderID, lMessage);
            Logging.Delivery($"aPackage.RecipientID {aPackage.RecipientID}, aMessage.SenderID {lMessage.SenderID}");
            SendStatusResponse(aPackage.SenderID, aPackage, MessageStatus.Received, DateTime.UtcNow);
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
                  Logging.Delivery($"Server: New status received for {aPackage.MessageID}: {lStatus}");
                  if DeliveryNotifications then
                    SendStatusResponse(aPackage.RecipientID, aPackage, lStatus, aPackage.Sent);
                end;
              else raise new Exception($"Unexpected Message Status {lStatus}")
            end;
          end;
        else raise new Exception($"Unexpected Package Type {aPackage.Type}");
      end;
    end;

    //

    method SendStatusResponse(aRecipientID: Guid; aPackage: Package; aStatus: MessageStatus; aDate: DateTime);
    begin
      var lPackage := new Package(&Type := PackageType.Status,
                                  ID := Guid.NewGuid,
                                  SenderID := aPackage.SenderID,
                                  ChatID := ChatID,
                                  MessageID := aPackage.MessageID,
                                  Sent := DateTime.UtcNow,
                                  Payload := new StatusPayload(Status := aStatus,
                                                               Date := DateTime.UtcNow));
      Hub.SendPackage(aRecipientID, lPackage);
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