namespace RemObjects.Chat;

type
  InMemoryPackageStore = public class(PackageStore)
  public

    method SavePackage(aPackage: not nullable Package); override;
    begin
      Log($"Removing new message {aPackage.ID}");
      locking fPackages do begin
        fPackages.Add(aPackage);
        //fPackagesByID[aPackage.ID] := aPackage;
      end;
    end;

    method RemovePackage(aPackage: nullable Package); override;
    begin
      if not assigned(aPackage) then
        exit;

      Log($"Removing sent message {aPackage.ID}");
      locking fPackages do begin
        fPackages.Remove(aPackage);
        //fPackagesByID[aPackage.ID] := aPackage;
        if fPackages.Count = 0 then
          ClearChunkIDs;
      end;
    end;

    property Count: Integer read fPackages.Count; override;
    property Snapshot: sequence of Package read locking fPackages do fPackages.UniqueCopy; override;

  private

    var fPackages := new List<Package>;
    //var fPackagesByID := new Dictionary<Guid,Package>;

  end;

end.