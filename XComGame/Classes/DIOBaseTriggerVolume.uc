/**
 * Copyright 1998-2013 Epic Games, Inc. All Rights Reserved.
 */
class DIOBaseTriggerVolume extends TriggerVolume
	implements(IMouseInteractionInterface)
	native
	placeable;

// HELIOS BEGIN
// Have an Event Listener tri
function bool OnMouseEvent(int cmd,
	int Actionmask,
	optional Vector MouseWorldOrigin,
	optional Vector MouseWorldDirection,
	optional Vector HitLocation)
{
	local bool Handled;

	if (cmd == class'UIUtilities_Input'.const.FXS_L_MOUSE_DOWN)
	{
		if (`SCREENSTACK.OnDIOVolumeInput(self))
			Handled = true;

		// Default Case if not handled from above
		if (!Handled)
		{
			class'UIUtilities_Strategy'.static.OnBaseVolumeClicked(self);
			Handled = true;
		}
	}

	return Handled;
}
// HELIOS END

defaultproperties
{
	bColored=true
	BrushColor=(R=100,G=255,B=100,A=255)

	bCollideActors=true
	bProjTarget=true
	SupportedEvents.Empty
	SupportedEvents(0)=class'SeqEvent_Touch'
	bTickIsDisabled=true
}
