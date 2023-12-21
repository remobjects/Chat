namespace RemObjects.Chat.Client;

uses
  //RemObjects.Elements.Serialization,
  RemObjects.Infrastructure.Encryption;

type
  //[Codable(NamingStyle.camelCase)]
  ChatUser = public class
  public

    constructor; empty;

    constructor withFolder(aFolder: String);
    begin
      Load(aFolder);
    end;

    method Load(aFolder: not nullable String);
    begin
      OwnKeyPair := new KeyPair withFiles(Path.Combine(aFolder, "public_key.key"),
                                          Path.Combine(aFolder, "private_key.key"),
                                          KeyFormat.Bytes);
      for each f in Folder.GetFiles(aFolder).Where(f -> f.LastPathComponent.EndsWith("_public.key")) do
        fPersons.Add(new Person(ID := Guid.TryParse(f.LastPathComponent.Substring(0, length(f.LastPathComponent)-11)),
                                PublicKey := new KeyPair withFiles(f, nil, KeyFormat.Bytes)));
    end;

    method Save(aFolder: not nullable String);
    begin
      Folder.Create(aFolder);
      OwnKeyPair.SaveToFiles(Path.Combine(aFolder, "public_key.key"),
                             Path.Combine(aFolder, "private_key.key"),
                             KeyFormat.Bytes);
      for each p in Persons do
        p.PublicKey.SaveToFiles(Path.Combine(aFolder, p.ID+"_public.key"), nil, KeyFormat.Bytes);
    end;

    //

    property UserID: Guid;
    property ChatServer: ChatServer;
    property OwnKeyPair: KeyPair;

    property Chats: ImmutableList<Chat> read fChats;
    var fChats := new List<Chat>; private;
    var fChatsByID := new Dictionary<Guid,Chat>; private;

    property Persons: ImmutableList<Person>;// read fPersons;
    var fPersons := new List<Person>; private;

    method AddChat(aChat: Chat);
    begin
      fChats.Add(aChat);
      fChatsByID[aChat.ID] := aChat;
    end;

    //

    method EncodeMessage(aMessage: ChatMessage; aChat: Chat): array of Byte;
    begin
      Log($"-- encode --");
      var lStringData := aMessage.Payload.ToJsonString(JsonFormat.Minimal);
      Log($"lStringData {lStringData}");
      var lData := Encoding.UTF8.GetBytes(lStringData);
      Log($"lData {lData.ToHexString}");
      var lSignature := OwnKeyPair.SignWithPrivateKey(lData);
      Log($"lSignature        {lSignature.ToHexString}");
      if aChat is var lPrivateChat: PrivateChat then begin
        var lEncryptedMessage := lPrivateChat.Person.PublicKey.EncryptWithPublicKey(lData);
        Log($"lEncryptedMessage {lEncryptedMessage.ToHexString}");


        result := new Byte[2+length(lSignature)+length(lEncryptedMessage)];
        result[0] := ord('S');
        result[length(lSignature)+1] := ord('-');
        &Array.Copy(lSignature, 0, result, 1, length(lSignature));
        &Array.Copy(lEncryptedMessage, 0, result, length(lSignature)+2, length(lEncryptedMessage));
        Log($"result          {result.ToHexString}");

      end;

    end;

    method DecodeMessage(aData: array of Byte): ChatMessage;
    begin
    end;

    method DecodeMessage(aData: array of Byte; aChat: Chat): ChatMessage;
    begin
      Log($"-- decode --");
      result := new ChatMessage;

      case aData[0] of
        ord('S'): begin

            if aData[1+256] ≠ ord('-') then
              raise new Exception("Unexpected message format (#2).");

            var lSignature := new Byte[256];
            &Array.Copy(aData, 1, lSignature, 0, 256);
            var lEncryptedMessage := new Byte[length(aData)-2-256];
            &Array.Copy(aData, 2+256, lEncryptedMessage, 0, length(lEncryptedMessage));
            Log($"lSignature        {lSignature.ToHexString}");
            Log($"lEncryptedMessage {lEncryptedMessage.ToHexString}");

            result := new ChatMessage;

            if aChat is var lPrivateChat: PrivateChat then begin

              var lDecryptedMessage := OwnKeyPair.DecryptWithPrivateKey(lEncryptedMessage);
              var lString := Encoding.UTF8.GetString(lDecryptedMessage);
              result.Payload := JsonDocument.FromString(lString);

              result.Sender := lPrivateChat.Person;
              result.SignatureValid := result.Sender.PublicKey.ValidateSignatureWithPublicKey(lDecryptedMessage, lSignature);
              if not result.SignatureValid then begin
                if RefreshPublicKey(result.Sender) then
                  result.SignatureValid := result.Sender.PublicKey.ValidateSignatureWithPublicKey(lDecryptedMessage, lSignature);
              end;

            end
            else if aChat is var lGroupChat: GroupChat then begin

              var lDecryptedMessage := lGroupChat.SharedKeyPair.DecryptWithPrivateKey(lEncryptedMessage);
              var lString := Encoding.UTF8.GetString(lDecryptedMessage);
              result.Payload := JsonDocument.FromString(lString);

              var lSenderID := result.SenderID;
              if assigned(lSenderID) then begin
                result.Sender := FindSender(lSenderID);
                if assigned(result.Sender:PublicKey) then begin
                  result.SignatureValid := lPrivateChat.Person.PublicKey.ValidateSignatureWithPublicKey(lDecryptedMessage, lSignature);
                  if not result.SignatureValid then begin
                    if RefreshPublicKey(result.Sender) then
                      result.SignatureValid := result.Sender.PublicKey.ValidateSignatureWithPublicKey(lDecryptedMessage, lSignature);
                  end;
                end;
              end;

            end;

            aChat.AddMessagew(result);

          end;
        else begin
          raise new Exception("Unexpected message format (#1).");
        end;

        //var lSignature := OwnKeyPair.SignWithPrivateKey(lDecryptedMessage);
        //Log($"lSignature {lSignature.ToHexString}");

      end;

      //
      //
      //

      method Connect;
      begin
        var lAuthenticationCode: Guid;// := fChatServer.GetChatAuthenticationCode;

        var lAuthenticationMessage := new Byte[2+sizeOf(Guid)*2];
        lAuthenticationMessage[0] := ord('A');
        &Array.Copy(UserID.ToByteArray, 0, lAuthenticationMessage, 1, sizeOf(Guid));
        lAuthenticationMessage[1+sizeOf(Guid)] := ord('-');
        &Array.Copy(lAuthenticationCode.ToByteArray, 0, lAuthenticationMessage, 2+sizeOf(Guid), sizeOf(Guid));

        // Connect
        // SendMessage(lAuthenticationMessage)
      end;

    end;

    method FindSender(aSenderID: Guid): nullable Person;
    begin
    end;

    method RefreshPublicKey(aPerson: Person): Boolean;
    begin

    end;


  end;

  //[Codable(NamingStyle.camelCase)]
  Chat = public abstract class
  public

    property ID: Guid;

    method AddMessagew(aMessage: ChatMessage);
    begin
      fMessages.Add(aMessage);
    end;

    var fMessages := new List<ChatMessage>; private;

  end;

  //[Codable(NamingStyle.camelCase)]
  PrivateChat = public class(Chat)
  public

    property Person: Person;

  end;

  //[Codable(NamingStyle.camelCase)]
  GroupChat = public class(Chat)
  public
    property SharedKeyPair: KeyPair;
    property Persons: List<Person>;

    //[Encode(false)]
    property PersonsByID: Dictionary<Guid,Person>;
    //[Encode(false)]
    property PersonsByShortID: Dictionary<Integer,Person>;
  end;

  ChatMessage = public class
  public
    property SignatureValid: Boolean;
    property Payload: JsonDocument;

    property SenderID: Guid read Guid.TryParse(Payload["senderId"]);
    property Sender: Person;
  end;

  //[Codable(NamingStyle.camelCase)]
  Person = public class
  public
    property ID: Guid;
    property ShortID: nullable Integer;
    property Name: nullable String;
    property Handle: nullable String;
    property Status: nullable String;
    property LastSeen: nullable DateTime;
    property PublicKey: PublicKey;

  end;

end.