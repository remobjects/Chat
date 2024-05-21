namespace RemObjects.Chat;

type
  EchoQueue = public class(IClientQueue)
  public

    method Send(aPacket: not nullable Package);
    begin
      if assigned(Receive) then begin

      end;
        Receive(nen);
    end;

    property Receive: method (aPacket: not nullable Package);

    property UserID: not nullable RemObjects.Elements.RTL.Guid;

    constructor(aUserID: Guid);
    begin
      UserID := aUserID;
    end;

  end;

end.