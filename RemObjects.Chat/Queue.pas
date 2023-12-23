namespace RemObjects.Infrastructure;

type
  ITwoWayQueueEndpoint<P> = public interface
    method Send(aPacket: not nullable P);
    property Receive: block(aPacket: not nullable P);
  end;

end.