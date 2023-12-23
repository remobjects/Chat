namespace RemObjects.Infrastructure;

type
  LocalQueue<P> = public class
  public

    constructor;
    begin
      ID := Guid.NewGuid
    end;

    property ID: Guid;

    property ClientEndpoint: ITwoWayQueueEndpoint<P> := new ClientEndpointimpl(self); readonly;
    property ServerEndpoint: ITwoWayQueueEndpoint<P> := new ServerEndpointImpl(self); readonly;

    [ToString]
    method ToString: String; override;
    begin
      result := $"LocalQueue {ID}";
    end;

    type
      ClientEndpointImpl = class(ITwoWayQueueEndpoint<P>)

        constructor (aLocalQueue: LocalQueue<P>);
        begin
          fLocalQueue := aLocalQueue;
        end;

        fLocalQueue: LocalQueue<P>;

        method Send(aPacket: not nullable P);
        begin
          if not assigned(fLocalQueue.ServerEndpoint.Receive) then
            raise new Exception("ServerEndpoint.Receive is not assigned.");
          fLocalQueue.ServerEndpoint.Receive(aPacket);
        end;

        property Receive: block(aPacket: not nullable P);

      end;

      ServerEndpointImpl = class(ITwoWayQueueEndpoint<P>)

        constructor (aLocalQueue: LocalQueue<P>);
        begin
          fLocalQueue := aLocalQueue;
        end;

        fLocalQueue: LocalQueue<P>;

        method Send(aPacket: not nullable P);
        begin
          if not assigned(fLocalQueue.ClientEndpoint.Receive) then
            raise new Exception("ClientEndpoint.Receive is not assigned.");
          fLocalQueue.ClientEndpoint.Receive(aPacket);
        end;

        property Receive: block(aPacket: not nullable P);

      end;

  end;

end.