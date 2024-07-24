namespace RemObjects.Chat.Connection;

uses
  RemObjects.InternetPack,
  RemObjects.Chat,
  RemObjects.Chat.Server;

type
  IPChatServer = public class(Server, IIPChatServer)
  public

    property KeepAlive: Boolean := true;

    event ChatRequest: ChatRequestEventHandler; public;

    constructor; public;
    begin
      self.DefaultPort := 8080;
    end;

    method GetWorkerClass: &RemObjects.Elements.RTL.Reflection.Type; public; override;
    begin
      exit typeOf(ChatWorker);
    end;

  public

    { IIPChatServer }

    method AuthenticateConnection(aConnection: not nullable IPChatConnection; aUserID: not nullable Guid; aAuthenticationCode: not nullable Guid): Boolean;
    begin
      Logging.Connection($"AuthenticateConnection");

      var lID := ChatManager.ActiveChatManager.ChatAuthentications[aAuthenticationCode];

      if lID = aUserID then begin
        fConnections[aUserID] := aConnection;
        result := true;
          //Log($"AuthenticateConnection callback");
          //if ClientQueueManager.ActiveClientQueueManager.FindClientQueue(aUserID) is var lQueue: IIPClientQueue then begin
            //aConnection.OnDisconnect := () -> begin lQueue.Connection := nil; end;
            //lQueue.Connection := aConnection;
          //end;
        //end);
      end
      else begin
        Log($"Chat: AuthenticateConnection failed:");
        Log($"aUserID {aUserID}");
        Log($"lID     {lID}");
        Log($"lID = aUserID {lID = aUserID}");
      end;

    end;

    method PostAuthenticateConnection(aConnection: not nullable IPChatConnection);
    begin
      Logging.Connection($"PostAuthenticateConnection");
      if ClientQueueManager.ActiveClientQueueManager.FindClientQueue(aConnection.UserID) is var lQueue: IIPClientQueue then begin
        aConnection.OnDisconnect := () -> begin lQueue.Connection := nil; end;
        lQueue.Connection := aConnection;
      end;
    end;

    method ReceivePackage(aConnection: not nullable IPChatConnection; aPackage: not nullable Package);
    begin
      Logging.Connection($"ReceivePackage {aPackage}");
      var lQueue := ClientQueueManager.ActiveClientQueueManager.FindClientQueue(aConnection.UserID);
      if not assigned(lQueue) then
        raise new Exception($"No client queue found for user '{aConnection.UserID}'.");
      if not assigned(lQueue.Receive) then
        raise new Exception($"Client queue for user '{aConnection.UserID}' is not set up to receive data.");
      lQueue.Receive(aPackage);
    end;

    var fConnections := new Dictionary<Guid,IPChatConnection>;

  protected

    //method TriggerIncomingRequest(e: ChatRequestEventArgs); virtual;
    //begin
      //if assigned(self.ChatRequest) then begin
        //self.ChatRequest(self, e);
      //end;
    //end;

    //method HandleChatRequest(connection: Connection; request: ChatServerRequest; response: ChatServerResponse); virtual;
    //begin
      //self.TriggerChatRequest(new ChatRequestEventArgs(connection, request, response));
    //end;

  end;

  ChatWorker nested in IPChatServer = private sealed class(Worker)
  protected

    method DoWork; protected; override;
    begin
      var lConnection := new IPChatConnection(Owner, DataConnection);
      try
        lConnection.Work;
      except
        on E: Exception do
          Log($"E {E}");
      finally
        self.DataConnection.Close();
      end;
    end;

  private

    property Owner: IPChatServer read inherited Owner as IPChatServer; reintroduce;

  end;

  ChatRequestEventArgs = public class(ConnectionEventArgs)
  public

    property Request: ChatServerRequest read unit write;
    property Response: ChatServerResponse read unit write;
    property Handled: Boolean; public;

    constructor(aConnection: Connection; aRequest: ChatServerRequest; aResponse: ChatServerResponse); public;
    begin
      inherited constructor(aConnection);
      self.Request := aRequest;
      self.Response := aResponse;
      //self.Handled := false;
    end;

  end;

  ChatRequestEventHandler = public block(sender: Object; e: ChatRequestEventArgs);

  ChatServerRequest = public class

  end;

  ChatServerResponse = public class

  end;

end.