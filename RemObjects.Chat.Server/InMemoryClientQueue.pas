namespace RemObjects.Chat.Server;

uses
  RemObjects.Infrastructure,
  RemObjects.Chat,
  RemObjects.Chat.Connection;

type
  InMemoryClientQueue = public class(ConnectedQueue, IClientQueue, IIPClientQueue, IInjectableClientQueue)
  public


    method SavePacket(aPackage: Package); override;
    begin
      Log($"Queued {aPackage}");
      locking fOutgoingPackages do
        fOutgoingPackages.Add(aPackage);
    end;

    method SendPackets; override; locked on self;
    begin
      if assigned(Connection) and not Connection:Disconnected then begin

        try
          var lPackages := locking fOutgoingPackages do fOutgoingPackages.UniqueMutableCopy;
          Log($"> Sending {lPackages.Count} packages");
          //Log($"{fOutgoingPackages.Count} packages to send");
          for each p in lPackages do begin
            Connection.SendPackage(p) begin
              if aSuccess then begin
                locking fOutgoingPackages do
                  fOutgoingPackages.Remove(p);
                Log($"Package {p.ID} successfullty delivered to client");
              end
              else begin
                Log($"Package {p.ID} failed to deliver to client: '{aError}'");
              end;
            end;
          end;
          Log($"< Done sending {lPackages.Count} packages");

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

    property OutgoingPacketCount: Integer read fOutgoingPackages.Count;
    property OutgoingPackets[aIndex: Integer]: Package read fOutgoingPackages[aIndex];

    method InjectIncomingPacket(aPackage: Package);
    begin
      locking self do
        fIncomingPackages.Add(aPackage);
      ReceivePackages;
    end;

    method AcknowledgeReceiptOfOutgoingPackets(aIDs: array of Guid); //locked on self;
    begin
      var lCount := 0;
      locking fOutgoingPackages do begin
        for i := 0 to fOutgoingPackages.Count-1 do begin
          if aIDs.Contains(fOutgoingPackages[i].ID) then begin
            inc(lCount);
            fOutgoingPackages.RemoveAt(i);
            if lCount = length(aIDs) then
              exit;
          end;
        end;
      end;
    end;

    [ToString]
    method ToString: String; override;
    begin
      result := $"<{GetType.Name} for {UserID}, {fOutgoingPackages.Count} pending packages, {HasActiveConnection}";
    end;

  private

    fIncomingPackages := new List<Package>;
    fOutgoingPackages := new List<Package>;

  end;

end.