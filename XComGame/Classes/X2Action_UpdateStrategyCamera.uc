class X2Action_UpdateStrategyCamera extends X2Action;

var name AreaTag;

var private XComEventObject_EnterHeadquartersArea EnterAreaMessage;

simulated state Executing
{
Begin:
	// HELIOS BEGIN	
	`PRESBASE.RefreshCamera(AreaTag);
	// HELIOS END
	/*EnterAreaMessage = new class'XComEventObject_EnterHeadquartersArea';
	EnterAreaMessage.AreaTag = AreaTag; 
	`XEVENTMGR.TriggerEvent('UIEvent_EnterBaseArea_Immediate', EnterAreaMessage);*/

	CompleteAction();
}

DefaultProperties
{
}
