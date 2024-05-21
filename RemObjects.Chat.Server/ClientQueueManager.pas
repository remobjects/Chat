namespace RemObjects.Chat.Server;

uses
  RemObjects.Infrastructure,
  RemObjects.Chat,
  RemObjects.Chat.Connection;

type
  ClientQueueManager = public abstract class
  public

    [ErrOnNilAccess("Queue Manager has not been initialized.")]
    class property ActiveClientQueueManager: ClientQueueManager;

    method InjectClientQueue(aQueue: IClientQueue);
    begin
      fClientQueues[aQueue.UserID] := aQueue;
    end;

    method FindClientQueue(aUserID: not nullable Guid): IClientQueue;
    begin
      result := fClientQueues[aUserID];
      if not assigned(result) then begin
        result := CreateQueueForUser(aUserID);
        fClientQueues[aUserID] := result;
        result.Receive := @Hub.Instance.FindClient(aUserID).OnReceivePackage;
        result.UserID := aUserID;
      end;
    end;

    [ToString]
    method ToString: String; override;
    begin
      result := $"<{GetType.Name}, {fClientQueues.Count} queues"+Environment.LineBreak+
                (for each k in fClientQueues.Keys.OrderBy(k -> k.ToString) yield
                  fClientQueues[k].ToString).JoinedString(Environment.LineBreak)+
                ">";
    end;

    constructor;
    begin
      Log($"Created {GetType.Name}");
      async loop try
        Thread.Sleep(10000);
        Log($"{ClientQueueManager.ActiveClientQueueManager}");
      except
        on E: Exception do
          Log($"E {E}");
      end;
    end;


  protected

    method CreateQueueForUser(aUserID: not nullable Guid): IClientQueue; abstract;

  private

    fClientQueues := new Dictionary<Guid,IClientQueue>;

  end;

  IClientQueue = public interface(ITwoWayQueueEndpoint<Package>)
  public
    property UserID: not nullable Guid;
  end;

  IIPClientQueue = public interface
    property Connection: nullable IPChatConnection;
  end;


  DefaultClientQueueManager<Q> = public class(ClientQueueManager)
  where Q is IClientQueue, Q has constructor;
  protected

    method CreateQueueForUser(aUserID: not nullable Guid): IClientQueue; override;
    begin
      result := new Q;
      result.UserID := aUserID;
    end;

  end;

  //ChatQueueManager<PS> = public class(ClientQueueManager)
  //where PS is PackageStore, PS has constructor;
  //protected

    //method CreateQueueForUser(aUserID: not nullable Guid): IClientQueue; override;
    //begin
      //var lPackageStore := new PS;
      //result := new ConnectedQueue(aUserID, lPackageStore);
    //end;

  //end;

  FolderBackedQueueManager = public class(ClientQueueManager)
  public

    constructor withFolder(aFolder: not nullable String);
    begin
      fFolder := aFolder;
    end;

  protected

    method CreateQueueForUser(aUserID: not nullable Guid): IClientQueue; override;
    begin
      var lPackageStore := new FolderBackedPackageStore withFolder(Path.Combine(fFolder, aUserID.ToString));
      result := new ConnectedQueue(aUserID, lPackageStore);
    end;

  private

    var fFolder: not nullable String;

  end;

  IInjectableClientQueue = public interface
  public
    method InjectIncomingPacket(aPackage: Package);
    property HasActiveConnection: Boolean read;
    property OutgoingPacketCount: Integer read;
    property OutgoingPackets[aIndex: Integer]: Package read;
    method AcknowledgeReceiptOfOutgoingPackets(aIDs: array of Guid);
  end;



end.