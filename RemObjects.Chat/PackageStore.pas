namespace RemObjects.Chat;

type
  PackageStore = public abstract class
  public

    method SavePackage(aPackage: not nullable Package); abstract;
    method RemovePackage(aPackage: nullable Package); abstract;

    method RemovePackage(aChunkID: Integer); virtual;
    begin
      var lPackage := locking fPackagesByChunk do fPackagesByChunk[aChunkID];
      if assigned(lPackage) then begin
        RemovePackage(lPackage);
        locking fPackagesByChunk do
          fPackagesByChunk[aChunkID] := nil;
      end;
    end;

    property Count: Integer read; abstract;
    property Snapshot: sequence of Package read; abstract;

    property PackagesByChunk[aChunkID: Integer]: Package read GetPackagesByChunk write SetPackagesByChunk; virtual;

  protected

    method ClearChunkIDs; locked on fPackagesByChunk;
    begin
      {$HINT is this safe? or could we have race with a new chunk being added? review later}
      Log($"Clearing all old Chunk IDs ({locking fPackagesByChunk do fPackagesByChunk.Count})");
      locking fPackagesByChunk do
        fPackagesByChunk.RemoveAll;
    end;

  private

    var fPackagesByChunk := new Dictionary<Integer, Package>;

    method GetPackagesByChunk(aChunkID: Integer): Package;
    begin
      locking fPackagesByChunk do
        result := fPackagesByChunk[aChunkID]
    end;

    method SetPackagesByChunk(aChunkID: Integer; aPackage: Package);
    begin
      locking fPackagesByChunk do
        fPackagesByChunk[aChunkID] := aPackage;
    end;

  end;

end.