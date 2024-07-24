namespace RemObjects.Chat.Server;

uses
  RemObjects.Infrastructure,
  RemObjects.Chat,
  RemObjects.Chat.Connection;

type
  ConnectedQueue = public class(PersistentQueue<Package>, IClientQueue, IIPClientQueue)
  public

    constructor(aUserID: not nullable Guid; aPackageStore: not nullable PackageStore);
    begin
      UserID := aUserID;
      fPackageStore := aPackageStore;
    end;


    property UserID: not nullable Guid read private write;
    property Connection: nullable IPChatConnection read fConnection write SetConnection;
    //property PackageStore: PackageStore read fPackageStore write fPackageStore;

    property HasActiveConnection: Boolean read assigned(Connection);

    [ToString]
    method ToString: String; override;
    begin
      result := $"<{GetType.Name} for {UserID}, {fPackageStore.Count} pending packages, {HasActiveConnection}";
    end;

    //
    //
    //

    method SavePacket(aPackage: Package); override;
    begin
      Logging.Delivery($"Queued {aPackage}");
      fPackageStore.SavePackage(aPackage);
      //locking fOutgoingPackages do
        //fOutgoingPackages.Add(aPackage);
    end;

    method SendPackets; override; locked on self;
    begin
      if assigned(Connection) and not Connection:Disconnected then begin

        try
          var lPackages := locking PackageStore do fPackageStore.Snapshot;
          Logging.Delivery($"> Sending {lPackages.Count} packages");
          //Logging.Delivery($"{fOutgoingPackages.Count} packages to send");
          for each p in lPackages do begin
            Connection.SendPackage(p) begin
              Logging.Delivery($"Saving initial Chunk ID {aChunkID} for package {p.ID}");
              fPackageStore.PackagesByChunk[aChunkID] := p;
              //if aSuccess then begin
                //locking fOutgoingPackages do
                  //fOutgoingPackages.Remove(p);
                //Logging.Delivery($"Package {p.ID} successfullty delivered to client");
              //end
              //else begin
                //Logging.Delivery($"Package {p.ID} failed to deliver to client: '{aError}'");
              //end;
            end;
          end;
          Logging.Delivery($"< Done sending {lPackages.Count} packages");

        except
          on E: System.ObjectDisposedException do begin
            Log($"Live client connection for user '{UserID}' was closed/lost.");
            Connection := nil;
          end;
          on E: Exception do begin
            Logging.Error($"Exception sending packets: {E}");
          end;

        end;

      end
      else begin
        Logging.Delivery($"Currently there is no live client connection for user '{UserID}'.");
      end;
    end;

  private

    var fConnection: nullable IPChatConnection;
    var fPackageStore: PackageStore;

    method SetConnection(aConnection: nullable IPChatConnection);
    begin
      if aConnection ≠ fConnection then begin
        Log(if assigned(aConnection) then $"Queue got live connection for user {UserID}." else $"Queue lost live connection for user {UserID}.");

        fConnection:OnAck := nil;
        fConnection:OnNak := nil;

        fConnection := aConnection;

        fConnection:OnAck := (aChunkID) -> begin
          Logging.Delivery($"+ Successfully sent package with Chunk ID {aChunkID}");
          fPackageStore.RemovePackage(aChunkID);
        end;
        fConnection:OnNak := (aChunkID, aError) -> begin
          Logging.Delivery($"- Failed to sent package with Chunk ID {aChunkID}");
          fPackageStore.PackagesByChunk[aChunkID] := nil; // remove chunk but keep the package
        end;

        if assigned(fConnection) then
          SendPackets;
      end;
    end;

  end;

end.