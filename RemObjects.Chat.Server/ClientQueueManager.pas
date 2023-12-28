namespace RemObjects.Chat.Server;

uses
  RemObjects.Infrastructure,
  RemObjects.Chat;

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
        result.UserID := aUserID;
        fClientQueues[aUserID] := result;
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

  InMemoryClientQueue = public class(PersistentQueue<Package>, IClientQueue, IInjectableClientQueue)
  public

    property UserID: not nullable Guid; required;
    property Connection: nullable Object;

    method SavePacket(aPackage: Package); override;
    begin
      Log($"Queued {aPackage}");
      fOutgoingPackages.Add(aPackage);
    end;

    method SendPackets; override; locked on self;
    begin
      if assigned(Connection) then begin
        var lLastSent := fOutgoingPackages.Count-1;
        for i := 0 to fOutgoingPackages.Count-1 do
          DoSendPacket(fOutgoingPackages[i]);
        fOutgoingPackages.RemoveRange(0, lLastSent);
      end
      else begin
        Log($"Currently there is no live client connection for user '{UserID}'.");
      end;
    end;

    method DoSendPacket(aPackage: Package); override;
    begin
      Log($"Pretend-sending {aPackage}");
    end;

    method ReceivePackages;
    begin
      if assigned(Receive) then begin
        var lLastReceived := fIncomingPackages.Count-1;
        for i := 0 to fIncomingPackages.Count-1 do begin
          Receive(fIncomingPackages[i]);
        end;
        locking self do
          fIncomingPackages.RemoveRange(0, lLastReceived);
      end;
    end;

    //
    //
    //

    property HasActiveConnection: Boolean read assigned(Connection);
    property OutgoingPacketCount: Integer read fOutgoingPackages.Count;
    property OutgoingPackets[aIndex: Integer]: Package read fOutgoingPackages[aIndex];

    method InjectIncomingPacket(aPackage: Package);
    begin
      locking self do
        fIncomingPackages.Add(aPackage);
      ReceivePackages;
    end;

    method AcknowledgeReceiptOfOutgoingPackets(aIDs: array of Guid); locked on self;
    begin
      var lCount := 0;
      for i := 0 to fOutgoingPackages.Count-1 do begin
        if aIDs.Contains(fOutgoingPackages[i].ID) then begin
          inc(lCount);
          fOutgoingPackages.RemoveAt(i);
          if lCount = length(aIDs) then
            exit;
        end;
      end;
    end;

  private

    fIncomingPackages := new List<Package>;
    fOutgoingPackages := new List<Package>;

  end;

end.