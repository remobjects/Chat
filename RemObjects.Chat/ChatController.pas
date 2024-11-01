namespace RemObjects.Chat;

type
  IChatControllerProxy = public interface
    method FindChat(aChatID: not nullable Guid): nullable ChatInfo;
    method FindUser(aUserID: not nullable Guid): nullable UserInfo;
  end;

  IChatControllerAttachmentProxy = public interface
    method UploadAttachment(aChatID: not nullable Guid; aAttachment: array of Byte): not nullable Guid;
    method DownloadAttachment(aChatID: not nullable Guid; aAttachmentID: not nullable Guid): nullable array of Byte;
  end;

end.