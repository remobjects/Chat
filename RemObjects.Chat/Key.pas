namespace RemObjects.Infrastructure.Encryption;

{$IF ECHOES}
uses
  System.Security.Cryptography,
  RemObjects.Elements.Serialization;
{$ENDIF}

{$IF TOFFEE}
uses
  CoreFoundation,
  Foundation,
  Security,
  RemObjects.Elements.RTL;
{$ENDIF}


type
  KeyType = public enum(RSA, EC);
  KeyFormat = public enum(Bytes, PEM, Pkcs8);

  //[Codable]
  KeyPair = public class//(ICodable)
  public

    class method Generate(aType: KeyType): KeyPair;
    begin
      {$IF TOFFEE}
      var keyPairAttributes := new Foundation.NSMutableDictionary;
        case aType of
          KeyType.RSA: begin
            keyPairAttributes[bridge<String>(Security.kSecAttrKeyType)] := bridge<String>(Security.kSecAttrKeyTypeRSA);
            keyPairAttributes[bridge<String>(Security.kSecAttrKeySizeInBits)] := 2048;
            end;
          KeyType.EC: begin
            keyPairAttributes[bridge<String>(Security.kSecAttrKeyType)] := bridge<String>(Security.kSecAttrKeyTypeEC);
            keyPairAttributes[bridge<String>(Security.kSecAttrKeySizeInBits)] := 256;
            end;
        end;

      var lSecure := ((defined("IOS") and defined("DEVICE")) or defined("arm64") or HasSecureEnclave);
      if lSecure then begin
        var lError: CoreFoundation.CFErrorRef;
        var accessControlDict := new Foundation.NSMutableDictionary;
        accessControlDict[bridge<String>(Security.kSecAttrAccessControl)] := bridge<id>(Security.SecAccessControlCreateWithFlags(CoreFoundation.kCFAllocatorDefault,
                                                                                                                                 Security.kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
                                                                                                                                 Security.SecAccessControlCreateFlags.kSecAccessControlPrivateKeyUsage,
                                                                                                                                 @lError));
        if aType = KeyType.EC then
          keyPairAttributes[bridge<String>(Security.kSecAttrTokenID)] := bridge<String>(Security.kSecAttrTokenIDSecureEnclave);
        keyPairAttributes[bridge<String>(Security.kSecPrivateKeyAttrs)] := accessControlDict;
      end
      else begin
        var privateKeyAttributes := new Foundation.NSMutableDictionary;
        var publicKeyAttributes := new Foundation.NSMutableDictionary;
        privateKeyAttributes[bridge<String>(Security.kSecAttrIsPermanent)] := true;
        publicKeyAttributes[bridge<String>(Security.kSecAttrIsPermanent)] := true;
        keyPairAttributes[bridge<String>(Security.kSecPrivateKeyAttrs)] := privateKeyAttributes;
        keyPairAttributes[bridge<String>(Security.kSecPublicKeyAttrs)] := publicKeyAttributes;
      end;

      var lPublicKey: Security.SecKeyRef;
      var lPrivateKey: Security.SecKeyRef;
      var status := Security.SecKeyGeneratePair(bridge<CoreFoundation.CFDictionaryRef>(keyPairAttributes), @lPublicKey, @lPrivateKey);
      if status ≠ Security.errSecSuccess then
        raise new Exception($"Failed to generate key pair: {StringFromOSStatus(status)}");

      result := new KeyPair withPublicKey(lPublicKey) privateKey(lPrivateKey);

      if assigned(lPublicKey) then
        CoreFoundation.CFRelease(lPublicKey);
      if assigned(lPrivateKey) then
        CoreFoundation.CFRelease(lPrivateKey);

      {$ELSEIF ECHOES}
      using rsa := System.Security.Cryptography.RSA.Create(2048) do
        result := new KeyPair withPlatformKey(rsa);
      {$ENDIF}
    end;

    constructor withFiles(aPublicKeyFile: nullable String; aPrivateKeyFile: nullable String := nil; aFormat: KeyFormat);
    begin
      LoadFromFiles(aPublicKeyFile, aPrivateKeyFile, aFormat);
    end;

    constructor withPublicKey(aPublicKeyData: array of Byte) privateKey(aPrivateKeyData: nullable array of Byte := nil);
    begin
      LoadFromBytes(aPublicKeyData, aPrivateKeyData);
    end;

    {$IF TOFFEE}
    constructor withPublicKey(aPublicKey: Security.SecKeyRef) privateKey(aPrivateKey: Security.SecKeyRef);
    begin
      fPublicKey := aPublicKey;
      fPrivateKey := aPrivateKey;
      CoreFoundation.CFRetain(fPublicKey);
      CoreFoundation.CFRetain(fPrivateKey);
    end;

    constructor fromKeyChain;
    begin
      var lQuery := new Foundation.NSMutableDictionary;
      lQuery[bridge<id>(Security.kSecClass)] := bridge<id>(Security.kSecClassKey);
      lQuery[bridge<id>(Security.kSecAttrApplicationTag)] := "RemObjects Chat";
      lQuery[bridge<id>(Security.kSecReturnRef)] := true;

      var lResult: CoreFoundation.CFTypeRef;
      var lStatus := Security.SecItemCopyMatching(bridge<CoreFoundation.CFDictionaryRef>(lQuery), @lResult);
      if lStatus ≠ Security.errSecSuccess then
        raise new Exception($"Failed to load key: {StringFromOSStatus(STATUS)}");
    end;
    {$ENDIF}

    {$IF ECHOES}
    constructor withPlatformKey(aKey: System.Security.Cryptography.RSA);
    begin
      fKey := aKey;
    end;
    {$ENDIF}

    property HasPublicKey: Boolean read GetHasPublicKey;
    property HasPrivateKey: Boolean read GetHasPrivateKey;

    method GetPrivateKey: array of Byte;
    begin
      {$IF TOFFEE}
      var lData := GetPrivateKeyAsNSData;
      result := new Byte[lData.length];
      lData.getBytes(@result[0]) length(lData.length);
      {$ELSEIF ECHOES}
      result := fKey.ExportRSAPrivateKey;
      {$ENDIF}
    end;

    method GetPublicKey: array of Byte;
    begin
      {$IF TOFFEE}
      var lData := GetPublicKeyAsNSData;
      result := new Byte[lData.length];
      lData.getBytes(@result[0]) length(lData.length);
      {$ELSEIF ECHOES}
      result := fKey.ExportRSAPublicKey;
      {$ENDIF}
    end;

    {$IF TOFFEE}
    method GetPrivateKeyAsNSData: not nullable Foundation.NSData;
    begin
      var lError: CoreFoundation.CFErrorRef;
      Security.SecKeyCopyExternalRepresentation(fPrivateKey, @lError);
      var lResult := bridge<Foundation.NSData>(Security.SecKeyCopyExternalRepresentation(fPrivateKey, @lError));
      if not assigned(lResult) then
        raise new Exception($"Error getting private key bytes {Foundation.CFBridgingRelease(lError)}");
      result := lResult;
    end;

    method GetPublicKeyAsNSData: not nullable Foundation.NSData;
    begin
      var lError: CoreFoundation.CFErrorRef;
      Security.SecKeyCopyExternalRepresentation(fPublicKey, @lError);
      var lResult := bridge<Foundation.NSData>(Security.SecKeyCopyExternalRepresentation(fPublicKey, @lError));
      if not assigned(var lResult) then
        raise new Exception($"Error getting public key bytes {Foundation.CFBridgingRelease(lError)}");
      result := lResult;
    end;
    {$ENDIF}

    {$IF DARWIN}
    method SaveToKeyChain(aService: not nullable String; aAccount: not nullable String; aComment: nullable String := nil);
    begin
      var lKeychainItem := new Foundation.NSMutableDictionary;
      lKeychainItem[bridge<id>(Security.kSecClass)] := bridge<id>(Security.kSecClassKey);
      lKeychainItem[bridge<id>(Security.kSecAttrApplicationTag)] := "RemObjects Chat";
      lKeychainItem[bridge<id>(Security.kSecAttrService)] := aService;
      lKeychainItem[bridge<id>(Security.kSecAttrAccount)] := aAccount;
      lKeychainItem[bridge<id>(Security.kSecAttrComment)] := aComment;
      lKeychainItem[bridge<id>(Security.kSecValueData)] := GetPrivateKeyAsNSData;

      var status := Security.SecItemAdd(bridge<CoreFoundation.CFDictionaryRef>(lKeychainItem), nil);
      Log($"status {status}");
      if status ≠ Security.errSecSuccess then
        raise new Exception($"Failed to save key: {StringFromOSStatus(status)}");
    end;
    {$ENDIF}

    method SaveToFiles(aPublicKeyFile: String; aPrivateKeyFile: String; aFormat: KeyFormat);
    begin
      {$IF TOFFEE}
        case aFormat of
          KeyFormat.Bytes: begin
              if assigned(aPublicKeyFile) then
                File.WriteBytes(aPublicKeyFile, GetPublicKey);
              if assigned(aPrivateKeyFile) then
                File.WriteBytes(aPrivateKeyFile, GetPrivateKey);
            end;
          KeyFormat.PEM: begin
              raise new NotSupportedException("Saving as PEM is not supported on Cocoa.");
              //File.WriteText(aPublicKeyFile, GetPublicKeyPem);
              //File.WriteText(aPrivateKeyFile, GetPrivateKeyPem);
            end;
        end;
      {$ENDIF}

      {$IF ECHOES}
        case aFormat of
          KeyFormat.Bytes: begin
            if assigned(aPublicKeyFile) then
              File.WriteBytes(aPublicKeyFile, fKey.ExportRSAPublicKey);
            if assigned(aPrivateKeyFile) then
              File.WriteBytes(aPrivateKeyFile, fKey.ExportPkcs8PrivateKey);
            end;
          KeyFormat.PEM: begin
            if assigned(aPublicKeyFile) then
              File.WriteText(aPublicKeyFile, fKey.ExportRSAPublicKeyPem);
            if assigned(aPrivateKeyFile) then
              File.WriteText(aPrivateKeyFile, fKey.ExportPkcs8PrivateKeyPem);
            end;
        end;
        {$ENDIF}
    end;

    //
    //
    //

    method EncryptWithPublicKey(aData: array of Byte): array of Byte;
    begin
      {$IF TOFFEE}
      var lError: CoreFoundation.CFErrorDomain;
      var lAlgorithm := Security.kSecKeyAlgorithmRSAEncryptionPKCS1;

      // Ensure the public key supports the encryption algorithm
      if not Security.SecKeyIsAlgorithmSupported(fPublicKey, Security.SecKeyOperationType.kSecKeyOperationTypeEncrypt, lAlgorithm) then
        raise new Exception('Public key does not support the specified algorithm.');

      // Perform the encryption
      var lData := Foundation.NSData.dataWithBytes(@aData[0]) length(length(aData));
      var lEncryptedData := bridge<Foundation.NSData>(Security.SecKeyCreateEncryptedData(fPublicKey,
                                                                                         lAlgorithm,
                                                                                         bridge<CoreFoundation.CFDataRef>(lData),
                                                                                         @lError));
      if assigned(lError) then
        raise new Exception($"Failed to encrypt data: {bridge<Foundation.NSError>(lError)}");

      result := new Byte[lEncryptedData.length];
      lEncryptedData.getBytes(@result[0]) length(lEncryptedData.length);
      {$ENDIF}

      {$IF ECHOES}
      result := fKey.Encrypt(aData, System.Security.Cryptography.RSAEncryptionPadding.OaepSHA256);
      {$ENDIF}
    end;

    method DecryptWithPrivateKey(aData: array of Byte): array of Byte;
    begin
      {$IF TOFFEE}
      var lError: CoreFoundation.CFErrorDomain;
      var lAlgorithm := Security.kSecKeyAlgorithmRSAEncryptionPKCS1;

      // Ensure the public key supports the encryption algorithm
      //if not Security.SecKeyIsAlgorithmSupported(fPrivateKey, Security.SecKeyOperationType.kSecKeyOperationTypeEncrypt, lAlgorithm) then
        //raise new Exception('Public key does not support the specified algorithm.');

      // Perform the encryption
      var lData := Foundation.NSData.dataWithBytes(@aData[0]) length(length(aData));
      var lDecryptedData := bridge<Foundation.NSData>(Security.SecKeyCreateDecryptedData(fPrivateKey,
                                                                                         lAlgorithm,
                                                                                         bridge<CoreFoundation.CFDataRef>(lData),
                                                                                         @lError));
      if assigned(lError) then
        raise new Exception($"Failed to encrypt data: {bridge<Foundation.NSError>(lError)}");

      result := new Byte[lDecryptedData.length];
      lDecryptedData.getBytes(@result[0]) length(lDecryptedData.length);
      {$ENDIF}

      {$IF ECHOES}
      result := fKey.Decrypt(aData, System.Security.Cryptography.RSAEncryptionPadding.OaepSHA256);
      {$ENDIF}
    end;

    method SignWithPrivateKey(aData: array of Byte): array of Byte;
    begin
      {$IF TOFFEE}
      var lError: CoreFoundation.CFErrorRef;
      var lData := Foundation.NSData.dataWithBytes(@aData[0]) length(length(aData));
      var lSignature := bridge<Foundation.NSData>(Security.SecKeyCreateSignature(fPrivateKey,
                                                                                 Security.kSecKeyAlgorithmRSASignatureMessagePKCS1v15SHA256,
                                                                                 bridge<CoreFoundation.CFDataRef>(HashSHA256(lData)),
                                                                                 @lError));
      if assigned(lError) then
        raise new Exception($"Failed to sign data: {bridge<Foundation.NSError>(lError)}");

      result := new Byte[lSignature.length];
      lSignature.getBytes(@result[0]) length(lSignature.length);
      {$ENDIF}
      {$IF ECHOES}
      result := fKey.SignData(aData,
                              System.Security.Cryptography.HashAlgorithmName.SHA256,
                              System.Security.Cryptography.RSASignaturePadding.Pkcs1);
      {$ENDIF}
    end;

    method ValidateSignatureWithPublicKey(aData: array of Byte; aSignature: array of Byte): Boolean;
    begin
      {$IF TOFFEE}
      var lError: CoreFoundation.CFErrorRef;
      var lData := Foundation.NSData.dataWithBytes(@aData[0]) length(length(aData));
      var lSignature := Foundation.NSData.dataWithBytes(@aSignature[0]) length(length(aSignature));
      result := Security.SecKeyVerifySignature(fPublicKey,
                                               Security.kSecKeyAlgorithmRSASignatureMessagePKCS1v15SHA256,
                                               bridge<CoreFoundation.CFDataRef>(HashSHA256(lData)),
                                               bridge<CoreFoundation.CFDataRef>(lSignature),
                                               @lError);
      if assigned(lError) then
        raise new Exception($"Failed to verify signature: {bridge<Foundation.NSError>(lError)}");
      {$ENDIF}
      {$IF ECHOES}
      result := fKey.VerifyData(aData,
                                aSignature,
                                System.Security.Cryptography.HashAlgorithmName.SHA256,
                                System.Security.Cryptography.RSASignaturePadding.Pkcs1);
      {$ENDIF}
    end;

    //
    //
    //

    [ToString]
    method ToString: String; override;
    begin
      {$IF TOFFEE}
      {$ENDIF}

      {$IF ECHOES}
      //Log($"fKey.ExportRSAPublicKeyPem {fKey.ExportRSAPublicKeyPem}");
      //Log($"fkey.ExportRSAPrivateKeyPem {fKey.ExportRSAPrivateKeyPem}");
      {$ENDIF}
    end;

    //
    // Encoding
    //

    {$IF ECHOES}
    method Encode(aCoder: Coder);
    begin
      if HasPublicKey then
        aCoder.EncodeString("publicKey", Convert.ToBase64String(GetPrivateKey));
      if HasPrivateKey then
        aCoder.EncodeString("privateKey", Convert.ToBase64String(GetPublicKey));
    end;

    method Decode(aCoder: Coder);
    begin
      var lPublicKey := aCoder.DecodeString("publicKey");
      var lPublicKeyData := if assigned(lPublicKey) then Convert.Base64StringToByteArray(lPublicKey);
      var lPrivateKey := aCoder.DecodeString("privateKey");
      var lPrivateKeyData := if assigned(lPrivateKey) then Convert.Base64StringToByteArray(lPrivateKey);
      LoadFromBytes(lPublicKeyData, lPrivateKeyData);
    end;
    {$ENDIF}

    //
    // This is not using Serialization because it will be used client-side too, and Serialixation isn't ported to Cocoa yet :(.
    //

    method ToJson: JsonObject;
    begin
      result := new JsonObject;
      if HasPublicKey then
        result["publicKey"] := Convert.ToBase64String(GetPrivateKey);
      if HasPrivateKey then
        result["privateKey"] := Convert.ToBase64String(GetPublicKey);
    end;

    constructor withJson(aJson: JsonDocument);
    begin
      var lPublicKey := aJson["publicKey"]:StringValue;
      var lPublicKeyData := if assigned(lPublicKey) then Convert.Base64StringToByteArray(lPublicKey);
      var lPrivateKey := aJson["privateKey"]:StringValue;
      var lPrivateKeyData := if assigned(lPrivateKey) then Convert.Base64StringToByteArray(lPrivateKey);
      LoadFromBytes(lPublicKeyData, lPrivateKeyData);
    end;

  private

    {$IF TOFFEE}
    fPublicKey: Security.SecKeyRef;
    fPrivateKey: Security.SecKeyRef;
    {$ENDIF}

    {$IF ECHOES}
    fKey: System.Security.Cryptography.RSA;
    {$ENDIF}

    method LoadFromFiles(aPublicKeyFile: String; aPrivateKeyFile: String; aFormat: KeyFormat);
    begin
      case aFormat of
        KeyFormat.Bytes: LoadFromBytes(if aPublicKeyFile:FileExists then File.ReadBytes(aPublicKeyFile),
                                       if aPrivateKeyFile:FileExists then File.ReadBytes(aPrivateKeyFile));
        KeyFormat.PEM: begin
            {$IF TOFFEE}
            LoadFromBytes(if aPublicKeyFile:FileExists then PemToDer(File.ReadText(aPublicKeyFile)),
                          if aPrivateKeyFile:FileExists then PemToDer(File.ReadText(aPrivateKeyFile)));
            {$ENDIF}
            {$IF ECHOES}
            fKey := System.Security.Cryptography.RSA.Create;
            if assigned(aPublicKeyFile:FileExists) then
              fKey.ImportFromPem(System.String(File.ReadText(aPublicKeyFile)).AsSpan);
            if assigned(aPrivateKeyFile:FileExists) then
              fKey.ImportFromPem(System.String(File.ReadText(aPrivateKeyFile)).AsSpan);
            {$ENDIF}
          end;
      end;
    end;

    method LoadFromBytes(aPublicKeyData: array of Byte; aPrivateKeyData: array of Byte);
    begin
      {$IF TOFFEE}
      if assigned(aPublicKeyData) then
        LoadKeyFromData(aPublicKeyData, Security.kSecAttrKeyClassPublic);
      if assigned(aPrivateKeyData) then
        LoadKeyFromData(aPublicKeyData, Security.kSecAttrKeyClassPrivate);
      {$ENDIF}
      {$IF ECHOES}
      fKey := System.Security.Cryptography.RSA.Create;
      if assigned(aPublicKeyData) then
        fKey.ImportRSAPublicKey(aPublicKeyData, out var nil);
      if assigned(aPrivateKeyData) then
        fKey.ImportPkcs8PrivateKey(aPrivateKeyData, out var nil);
        {$ENDIF}
    end;

    {$IF TOFFEE}
    method LoadKeyFromData(aData: array of Byte; aKeyClass: CoreFoundation.CFStringRef);
    begin
      var lError: CoreFoundation.CFErrorRef;
      var lKeyDict := new Foundation.NSMutableDictionary;
      var lData := Foundation.NSData.dataWithBytes(@aData[0]) length(length(aData));
      lKeyDict[bridge<id>(Security.kSecAttrKeyType)] := bridge<id>(Security.kSecAttrKeyTypeRSA);
      lKeyDict[bridge<id>(Security.kSecAttrKeyClass)] := bridge<id>(aKeyClass);
      lKeyDict[bridge<id>(Security.kSecValueData)] := lData;
      fPublicKey := Security.SecKeyCreateWithData(bridge<CoreFoundation.CFDataRef>(lData),
                                                  bridge<CoreFoundation.CFDictionaryRef>(lKeyDict),
                                                  @lError);
      if assigned(lError) then
        raise new Exception($"Failed to load key: {bridge<Foundation.NSError>(lError)}");
    end;

    class method HashSHA256(aData: array of Byte): array of Byte;
    begin
      result := new Byte[CC_SHA256_DIGEST_LENGTH];
      CC_SHA256(@aData[0], CC_LONG(length(aData)), @result[0]);
    end;

    class method HashSHA256(aData: Foundation.NSData): Foundation.NSData;
    begin
      var lHash := new Byte[CC_SHA256_DIGEST_LENGTH];
      CC_SHA256(aData.bytes, CC_LONG(aData.length), @lHash[0]);
      exit Foundation.NSData.dataWithBytes(@lHash[0]) length(CC_SHA256_DIGEST_LENGTH);
    end;
    {$ENDIF}

    method PemToDer(aKeyData: String): array of Byte;
    begin
      aKeyData := aKeyData.trim
                          .SubstringFromFirstOccurrenceOf(#10)
                          .SubstringToLastOccurrenceOf(#10)
                          .Replace(#13, "")
                          .Replace(#10, "");
      result := Convert.Base64StringToByteArray(aKeyData);
    end;

    {$IF MACOS}
    class method HasSecureEnclave: Boolean;
    begin
      var lTask := new Foundation.NSTask;
      lTask.launchPath := "/usr/sbin/system_profiler";
      lTask.arguments := ["SPiBridgeDataType"];
      var lPipe := Foundation.NSPipe.pipe();
      lTask.setStandardOutput(lPipe);
      var lFile := lPipe.fileHandleForReading();
      var lError: Foundation.NSError;
      lTask.launchAndReturnError(var lError);
      if assigned(lError) then
        exit;
      lTask.waitUntilExit();
      var data := lFile.readDataToEndOfFileAndReturnError(var lError);
      if assigned(lError) then
        exit;
      var lOutput := new Foundation.NSString withData(data) encoding(Foundation.NSStringEncoding.NSUTF8StringEncoding);
      result := lOutput.containsString("T1") or lOutput.containsString("T2") or lOutput.containsString("Apple T2 Security Chip");

      //var platformExpert: io_service_t := IOServiceGetMatchingService(kIOMasterPortDefault, IOServiceMatching("IOPlatformExpertDevice"));
      //if platformExpert then begin
        //var modelRef: CFTypeRef := IORegistryEntryCreateCFProperty(platformExpert, CFSTR("model"), kCFAllocatorDefault, 0);
        //IOObjectRelease(platformExpert);
        //if modelRef then begin
          //var model: NSString := CFBridgingRelease(modelRef);
          //var hasEnclave: Boolean := model.containsString("iMacPro") or model.containsString("MacBookPro");
          //exit hasEnclave;
        //end;
      //end;
    end;
    {$ENDIF}

    {$IF DARWIN}
    class method StringFromOSStatus(status: OSStatus): String;
    begin
      result := bridge<String>(Security.SecCopyErrorMessageString(status, nil));
      if not assigned(result) then
        result := $"Unknown error: {status}";
    end;
    {$ENDIF}

    //
    //
    //

    method GetHasPublicKey: Boolean;
    begin
      {$IF TOFFEE}
      result := assigned(fPublicKey);
      {$ENDIF}
      {$IF ECHOES}
      try
        result := assigned(fKey:ExportParameters(true):Modulus) and assigned(fKey:ExportParameters(true):Exponent);
      except
      end;
      {$ENDIF}
    end;

    method GetHasPrivateKey: Boolean;
    begin
      {$IF TOFFEE}
      result := assigned(fPrivateKey);
      {$ENDIF}
      {$IF ECHOES}
      try
        result := assigned(fKey:ExportParameters(true):D);
      except
      end;
      {$ENDIF}
    end;

  end;

  PublicKey = public KeyPair;

  //class(KeyPair) // for now
  //public

    //constructor withPublicKeyFile(aPublicKeyFile: nullable String) format(aFormat: KeyFormat);
    //begin
      //inherited constructor withPublicKeyFile(aPublicKeyFile) privateKeyFile(nil) format(aFormat);
    //end;

    //constructor withPublicKey(aPublicKeyData: array of Byte);
    //begin
      //inherited constructor withPublicKey(aPublicKeyData) privateKey(nil);
    //end;

    //method SaveToFile(aPublicKeyFile: String; aFormat: KeyFormat);
    //begin
      //SaveToFiles(aPublicKeyFile, nil, aFormat);
    //end;

  //end;

end.