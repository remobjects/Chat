namespace RemObjects.Chat;

uses
  RemObjects.Infrastructure;

type
  PersistentQueue<P> = public class(ITwoWayQueueEndpoint<P>)
  where P is IPersistent;
  public

    method Send(aPacket: not nullable P); final;
    begin
      SavePacket(aPacket);
      SendPackets;
    end;

    property Receive: block(aPacket: not nullable P);

  protected

    method SavePacket(aPacket: P); abstract;
    //begin
      //PacketQueue.Enqueue(aPacket);
    //end;

    method SendPackets;
    begin
      //while PacketQueue.Count > 0 do begin
        //var p := PacketQueue.Peek;
        //DoSendPacket(p);
        //PacketQueue.Dequeue;
      //end;
    end;

    method DoSendPacket(aPacket: P); abstract;

  end;

  LocalFolderQueue<P> = public abstract class(PersistentQueue<P>)
  protected

    constructor withFolder(aFolder: not nullable String);
    begin
      fFolder := aFolder;
      Folder.Create(aFolder);
    end;

    method SavePacket(aPacket: P); override;
    begin
      var lName := Path.Combine(fFolder, Guid.NewGuid+".package");
      File.WriteBytes(lName, aPacket.ToByteArray);
    end;

  private

    var fFolder: String;

  end;

  LocalFolderTestQueue<P> = public class(LocalFolderQueue<P>)
  protected

    method DoSendPacket(aPacket: P); override;
    begin
      Log($"Pretend-sending {aPacket}");
    end;

  end;

end.