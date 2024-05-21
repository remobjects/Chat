namespace RemObjects.Chat;

type
  FolderBackedPackageStore = public class(PackageStore)
  public

    constructor withFolder(aFolder: not nullable String);
    begin
      fFolder := aFolder;
      Load;
      Log($"Reloaded {Count} package(s)");
    end;

    method SavePackage(aPackage: not nullable Package); override;
    begin
      Log($"Adding new message {aPackage.ID}");
      locking fPackages do begin
        fPackages.Add(aPackage);
        File.WriteBytes(Path.Combine(fFolder, aPackage.ID.ToString+".package"), aPackage.ToByteArray);
      end;
    end;

    method RemovePackage(aPackage: nullable Package); override;
    begin
      if not assigned(aPackage) then
        exit;

      Log($"Removing sent message {aPackage.ID}");
      locking fPackages do begin
        fPackages.Remove(aPackage);
        File.Delete(Path.Combine(fFolder, aPackage.ID.ToString+".package"));
        if fPackages.Count = 0 then
          ClearChunkIDs;
      end;
    end;

    property Count: Integer read fPackages.Count; override;
    property Snapshot: sequence of Package read locking fPackages do fPackages.UniqueCopy; override;

  private

    var fFolder: not nullable String;
    var fPackages := new List<Package>;

    method Load; locked on fPackages;
    begin
      if not fFolder.FolderExists then
        Folder.Create(fFolder);
      for each f in Folder.GetFiles(fFolder).Where(f -> f.PathExtension = ".package") do try
        var lPackage := new Package withByteArray(File.ReadBytes(f));
        fPackages.Add(lPackage);
      except
        on E: Exception do begin
          Log($"Exceprtiom loading package file {f}: {E.Message}");
          File.Delete(f);
        end;
      end;
    end;

    method Clear; locked on fPackages;
    begin
      fPackages.RemoveAll;
      if fFolder.FolderExists then
        Folder.Delete(fFolder);
      Folder.Create(fFolder);
    end;

  end;

end.