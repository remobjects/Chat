namespace RemObjects.Chat;

type
  Logging = public static class
  public

    [Conditional("DEBUG_CONNECTIONS")]
    method Connection(aMessage: String);
    begin
      Log("Chat: "+aMessage);
    end;

    [Conditional("DEBUG_PACKAGES")]
    method Packages(aMessage: String);
    begin
      Log("Chat: "+aMessage);
    end;

    [Conditional("DEBUG_DELIVERY")]
    method Delivery(aMessage: String);
    begin
      Log("Chat: "+aMessage);
    end;

    [Conditional("DEBUG_PACKAGE_STORE")]
    method PackageStore(aMessage: String);
    begin
      Log("Chat: "+aMessage);
    end;

    [Conditional("DEBUG_KEYS")]
    method Keys(aMessage: String);
    begin
      Log("Chat: "+aMessage);
    end;

    method Error(aMessage: String);
    begin
      Log("Chat: "+aMessage);
    end;

  end;

end.