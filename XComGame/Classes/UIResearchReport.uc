//---------------------------------------------------------------------------------------
//  FILE:    	UIResearchReport
//  AUTHOR:  	David McDonough  --  5/21/2019
//  PURPOSE: 	Refactored from X2 Tech system: display the full results of a recently
//				completed Dio Research project.
//           
//---------------------------------------------------------------------------------------
//  Copyright (c) 2019 Firaxis Games, Inc. All rights reserved.
//---------------------------------------------------------------------------------------

class UIResearchReport extends UIScreen;

var public localized string m_strCodename;
var public localized string m_strTopSecret;
var public localized string m_strResearchReport;

var name DisplayTag;
var name CameraTag;

var public bool bInstantInterp;

var UINavigationHelp NavHelp;
var UILargeButton ContinueButton;
var UIDIOHUD m_HUD;

simulated function InitScreen(XComPlayerController InitController, UIMovie InitMovie, optional name InitName)
{
	local float InterpTime;

	super.InitScreen(InitController, InitMovie, InitName);

	// HELIOS BEGIN
	// Replace the hard reference with a reference to the main HUD	
	m_HUD = UIDIOHUD(`SCREENSTACK.GetScreen(`PRESBASE.UIHUD_Strategy));
	// HELIOS END	
	m_HUD.UpdateResources(self);

	InterpTime = `HQINTERPTIME;

	if(bInstantInterp)
	{
		InterpTime = 0.0f;
	}

	if( UIMovie_3D(Movie) != none )
		class'UIUtilities'.static.DisplayUI3D(DisplayTag, CameraTag, InterpTime);

	NavHelp = InitController.Pres.GetNavHelp();
	if (NavHelp == none) // Tactical
	{
		NavHelp = Spawn(class'UINavigationHelp', self).InitNavHelp();
	}
	UpdateNavHelp();
}

simulated function UpdateNavHelp()
{
	NavHelp.AddContinueButton(CloseScreen);
	NavHelp.Show();
}

simulated function OnReceiveFocus()
{
	super.OnReceiveFocus();
	m_HUD.UpdateResources(self);
	UpdateNavHelp();
	if( UIMovie_3D(Movie) != none )
		class'UIUtilities'.static.DisplayUI3D(DisplayTag, CameraTag, 0);
}

simulated function OnLoseFocus()
{
	super.OnLoseFocus();
	NavHelp.ClearButtonHelp();
	UIMovie_3D(Movie).HideDisplay(DisplayTag);
}

simulated function CloseScreen()
{
	NavHelp.ClearButtonHelp();
	super.CloseScreen();
}

simulated function InitResearchReport(StateObjectReference ResearchRef)
{
	local int i;
	local string Unlocks;
	local array<String> arrStrings;
	local XComGameStateHistory History;
	local XComGameState_DioResearch Research;
	local X2DioResearchTemplate ResearchTemplate;

	class'UIUtilities_Sound'.static.PlayOpenSound();

	History = `XCOMHISTORY;
	Research = XComGameState_DioResearch(History.GetGameStateForObjectID(ResearchRef.ObjectID));
	ResearchTemplate = Research.GetMyTemplate();

	arrStrings = Research.GetMyTemplate().GetRewardStrings();
	for (i = 0; i < arrStrings.Length; i++)
	{
		Unlocks $= arrStrings[i];
		if (i < arrStrings.Length - 1)
			Unlocks $= "\n";
	}

	AS_UpdateResearchReport(
		m_strResearchReport, 
		`MAKECAPS(ResearchTemplate.DisplayName),
		m_strCodename @ ResearchTemplate.CodeName,
		`DIO_UI.static.FormatTurn(Research.TurnCompleted),
		ResearchTemplate.Image,
		Unlocks,
		ResearchTemplate.GetSummaryString(),
		m_strTopSecret);
}

simulated function AS_UpdateResearchReport(string header, string project, string code, string date, string image, string unlocks, string description, string greeble)
{
	MC.BeginFunctionOp("UpdateResearchReport");
	MC.QueueString(header);
	MC.QueueString(project);
	MC.QueueString(code);
	MC.QueueString(date);
	MC.QueueString(image);
	MC.QueueString(unlocks);
	MC.QueueString(description);
	MC.QueueString(greeble);
	MC.EndOp();
}

//============================================================================== 

simulated function bool OnUnrealCommand(int cmd, int arg)
{
	local bool bHandled;

	if ( !CheckInputIsReleaseOrDirectionRepeat(cmd, arg) )
		return false;

	bHandled = true;

	switch( cmd )
	{
	case class'UIUtilities_Input'.const.FXS_BUTTON_B :
	case class'UIUtilities_Input'.const.FXS_KEY_ESCAPE :
	case class'UIUtilities_Input'.const.FXS_R_MOUSE_DOWN :
	case class'UIUtilities_Input'.const.FXS_BUTTON_A :
	case class'UIUtilities_Input'.const.FXS_BUTTON_X :
	case class'UIUtilities_Input'.const.FXS_KEY_ENTER :
	case class'UIUtilities_Input'.const.FXS_KEY_SPACEBAR :
		CloseScreen();
		break;
		default:
			bHandled = false;
			break;
	}

	return bHandled || super.OnUnrealCommand(cmd, arg);
}


simulated function OnRemoved()
{
	super.OnRemoved();
}

//==============================================================================

defaultproperties
{
	DisplayTag      = "UIBlueprint_Powercore";
	CameraTag       = "UIBlueprint_Powercore";

	Package = "/ package/gfxResearchReport/ResearchReport";
	InputState = eInputState_Evaluate;
	bAnimateOnInit = true;
}
