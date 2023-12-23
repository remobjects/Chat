namespace RemObjects.Chat;

uses
  RemObjects.Infrastructure;

type
  BaseClient = public abstract class
  public

    property UserID: not nullable Guid; required;
    property Queue: ITwoWayQueueEndpoint<Package> read fQueue write SetQueue;

    method SendPackage(aPackage: Package);
    begin
      Queue.Send(aPackage);
    end;

  protected

    method OnReceivePackage(aPackage: Package); abstract;

  private

    fQueue: ITwoWayQueueEndpoint<Package>;

    method SetQueue(aValue: ITwoWayQueueEndpoint<Package>);
    begin
      fQueue:Receive := nil;
      fQueue := aValue;
      fQueue:Receive := @OnReceivePackage;
    end;

  end;

end.