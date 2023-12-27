namespace RemObjects.Chat.Connection;

uses
  System.Net.Sockets,
  RemObjects.InternetPack;

type
  IPChatServer = public class(Server)
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