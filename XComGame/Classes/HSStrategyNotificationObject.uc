//
// Helios Singleton notification object that DioStrategyNotificationsHelper will send off in 
// an Event Listener before assigning default values
// There's no easy way to send a delegate in an event listener unless it's an object of some kind
class HSStrategyNotificationObject extends Object;

var TStrategyNotificationData NotificationData;

delegate OnItemSelectedCallback(optional int ItemObjectID = -1);