namespace RemObjects.Chat;

uses
  RemObjects.Infrastructure;

type
  BaseClient = public abstract class
  public

    property User: not nullable UserInfo;
    property UserID: not nullable Guid read User.ID;

    property Queue: ITwoWayQueueEndpoint<Package> read fQueue write SetQueue;
    property ChatControllerProxy: IChatControllerProxy;

    method SendPackage(aPackage: Package);
    begin
      Queue.Send(aPackage);
    end;

    constructor(aUser: not nullable UserInfo);
    begin
      User := aUser;
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