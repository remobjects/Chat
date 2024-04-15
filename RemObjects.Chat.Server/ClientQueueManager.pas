﻿namespace RemObjects.Chat.Server;

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

  private
    var fConnection: nullable IPChatConnection;

  end;

  InMemoryClientQueue = public class(ConnectedQueue, IClientQueue, IIPClientQueue, IInjectableClientQueue)
  public


    method SavePacket(aPackage: Package); override;
    begin
      Log($"Queued {aPackage}");
      fOutgoingPackages.Add(aPackage);
    end;

    method SendPackets; override; locked on self;
    begin
      if assigned(Connection) and not Connection:Disconnected then begin

        try
          Log($"Sending {fOutgoingPackages.Count} packages");
          var lLastSent := fOutgoingPackages.Count-1;
          //Log($"{fOutgoingPackages.Count} packages to send");
          for i := 0 to fOutgoingPackages.Count-1 do
            Connection.SendPackage(fOutgoingPackages[i]);
          fOutgoingPackages.RemoveRange(0, lLastSent+1); {$HINT don't remove until we know it's delivered?}
          //Log($"{fOutgoingPackages.Count} packages left to send");

        except
          on E: System.ObjectDisposedException do begin
            Log($"Live client connection for user '{UserID}' was closed/lost.");
            Connection := nil;
          end;
          on E: Exception do begin
            Log($"Exception sending packets: {E}");
          end;

        end;

      end
      else begin
        Log($"Currently there is no live client connection for user '{UserID}'.");
      end;
    end;

    method DoSendPacket(aPackage: Package); override;
    begin
      //if assigned(Connection) then
        //Connection.SendPackage(aPackage);
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