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

  IInjectableClientQueue = public interface
  public
    method InjectIncomingPacket(aPackage: Package);
    property HasActiveConnection: Boolean read;
    property OutgoingPacketCount: Integer read;
    property OutgoingPackets[aIndex: Integer]: Package read;
    method AcknowledgeReceiptOfOutgoingPackets(aIDs: array of Guid);
  end;

  ConnectedQueue = public abstract class(PersistentQueue<Package>)
  public

    property UserID: not nullable Guid; required;
    property Connection: nullable IPChatConnection read begin
      result := fConnection;
    end write begin
      if fConnection ≠ value then begin
        Log(if assigned(value) then $"Queue got live connection for user {UserID}." else $"Queue lost live connection for user {UserID}.");
        fConnection := value;
        if assigned(value) then
          SendPackets;
      end;
    end;

    property HasActiveConnection: Boolean read assigned(Connection);

  private
    var fConnection: nullable IPChatConnection;

  end;



end.