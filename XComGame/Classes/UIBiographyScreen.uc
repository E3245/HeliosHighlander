//---------------------------------------------------------------------------------------
//  *********   FIRAXIS SOURCE CODE   ******************
//  FILE:    UIBiographyScreen.uc
//  AUTHOR:  Brit Steiner - 2/14/2020
//  PURPOSE: This file corresponds to the armory biography window.
//---------------------------------------------------------------------------------------
//  Copyright (c) 2020 Firaxis Games, Inc. All rights reserved.
//--------------------------------------------------------------------------------------- 

class UIBiographyScreen extends UIScreen;

var UINavigationHelp NavHelp;

//----------------------------------------------------------------------------
// MEMBERS

simulated function UIPanel InitPanel(optional name InitName, optional name InitLibId)
{
	super.InitPanel(InitName, InitLibId);
	RegisterForEvents();
	UpdateData();
	return self; 
}

function RegisterForEvents()
{
	local X2EventManager EventManager;
	local Object SelfObject;

	SelfObject = self;

	EventManager = `XEVENTMGR;
	EventManager.RegisterForEvent(SelfObject, 'UIEvent_CycleSoldier', CycleSoldier, ELD_Immediate);

	AddOnRemovedDelegate(UnRegisterForEvents);
}

function UnRegisterForEvents(UIPanel Panel)
{
	local X2EventManager EventManager;
	local Object SelfObject;

	EventManager = `XEVENTMGR;
	SelfObject = self;

	EventManager.UnRegisterFromEvent(SelfObject, 'UIEvent_CycleSoldier');
}
//---------------------------------------------------------------------------------------

function EventListenerReturn CycleSoldier(Object EventData, Object EventSource, XComGameState GameState, Name Event, Object CallbackData)
{
	UpdateData();
	return ELR_NoInterrupt;
}

function UpdateData()
{
	local X2SoldierClassTemplate UnitTemplate;
	local XComGameState_Unit Unit; 
	local UIArmory_MainMenu ArmoryScreen; 
	local UIDIOStrategyPicker_CharacterUnlocks CharScreen; 

	//Let's try to find a unit! 
	// HELIOS BEGIN
	ArmoryScreen = UIArmory_MainMenu(Movie.Pres.ScreenStack.GetScreen(`PRESBASE.Armory_MainMenu));
	// HELIOS END
	if(ArmoryScreen != none)
	{
		Unit = ArmoryScreen.GetUnit();
		UnitTemplate = Unit.GetSoldierClassTemplate();
	}
	else
	{
		CharScreen = UIDIOStrategyPicker_CharacterUnlocks(Movie.Pres.ScreenStack.GetScreen(class'UIDIOStrategyPicker_CharacterUnlocks'));
		if(CharScreen != none)
		{
			UnitTemplate = CharScreen.ViewingInfoOnCharTemplate;
		}
	}

	if(UnitTemplate == none)
	{
		CloseScreen();
		return; 
	}

	MC.BeginFunctionOp("UpdateInfo");
	MC.QueueString(`MAKECAPS(UnitTemplate.FirstName));
	MC.QueueString(FormatText(UnitTemplate.ClassLongBio));
	MC.EndOp();

	UpdateNavHelp();
}


static function string FormatText(string txt, optional bool bIncludeSubheaderLineBreaks = true)
{
	local string fontFace, fontFaceBold, startTags;

	if( txt == "" )
		return txt;

	fontFace = class'UIUtilities_Text'.const.BODY_FONT_TYPE;
	fontFaceBold = fontFace $ "Bold";

	// We're adding an extra line break, and wrapping the bolded text in yellow as well. 
	startTags = bIncludeSubheaderLineBreaks ? "\n" : "";
	startTags $= "<font face='" $ fontFaceBold $ "' color='#" $ class'UIUtilities_Colors'.const.WARNING_ORANGE_BRIGHT_HTML_COLOR $"'>";

	txt = Repl(txt, "<b>", startTags, false);
	txt = Repl(txt, "</b> ", "</font>\n", false);
	
	//Now parse regular for any other styling.
	return class'UIUtilities_Text'.static.ConvertStylingToFontFace(txt);
}

simulated function bool OnUnrealCommand(int cmd, int arg)
{
	if( !CheckInputIsReleaseOrDirectionRepeat(cmd, arg) )
		return false;

	switch( cmd )
	{
	case class'UIUtilities_Input'.const.FXS_BUTTON_A:
	case class'UIUtilities_Input'.const.FXS_KEY_ENTER:
	case class'UIUtilities_Input'.const.FXS_KEY_SPACEBAR:
	case class'UIUtilities_Input'.const.FXS_BUTTON_B :
	case class'UIUtilities_Input'.const.FXS_KEY_ESCAPE:
	case class'UIUtilities_Input'.const.FXS_R_MOUSE_DOWN :
		CloseScreen();
		return true;
	}

	return super.OnUnrealCommand(cmd, arg);
}

simulated function OnReceiveFocus()
{
	super.OnReceiveFocus();
	UpdateNavHelp();
}

simulated function CloseScreen()
{
	local XComStrategySoundManager SoundMgr;

	SoundMgr = `XSTRATEGYSOUNDMGR;
	if (SoundMgr != none)
	{
		SoundMgr.BiographyScreenClosed();
	}
	PlayMouseClickSound();
	super.CloseScreen();
}

simulated function UpdateNavHelp()
{
	if( NavHelp == None )
	{
		// HELIOS BEGIN
		// Replace the hard reference with a reference to the main HUD		
		NavHelp = UIDIOHUD(`SCREENSTACK.GetScreen(`PRESBASE.UIHUD_Strategy)).NavHelp;
		// HELIOS END
	}
	NavHelp.ClearButtonHelp();
	NavHelp.AddBackButton(CloseScreen);
}

//==============================================================================

defaultproperties
{
	Package = "/ package/gfxBiographyScreen/BiographyScreen";
	MCName = "theScreen";

	InputState = eInputState_Evaluate; 
}
