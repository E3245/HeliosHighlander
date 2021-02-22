//---------------------------------------------------------------------------------------
//  *********   FIRAXIS SOURCE CODE   ******************
//  FILE:    UIResearchUnlocked
//  AUTHOR:  Sam Batista
//	Refactored for Dio Research [5/28/2019 dmcdonough]
//
//  PURPOSE: Shows a list of techs now available for research.
//---------------------------------------------------------------------------------------
//  Copyright (c) 2016 Firaxis Games, Inc. All rights reserved.
//--------------------------------------------------------------------------------------- 

class UIResearchUnlocked extends UIScreen;

// Text
var localized string m_strTitle;
var localized string m_strMissingResearchName;
var localized string m_strMissingResearchDescription;

var name DisplayTag;
var name CameraTag;

var int CurrentResearchIndex;
var int NumUnlockedResearch;

var UINavigationHelp NavHelp;
var UIDIOHUD m_HUD;

// Constructor
simulated function InitScreen(XComPlayerController InitController, UIMovie InitMovie, optional name InitName)
{
	super.InitScreen( InitController, InitMovie, InitName );
	
	class'UIUtilities'.static.DisplayUI3D(DisplayTag, CameraTag, `HQINTERPTIME, true);

	// HELIOS BEGIN
	// Replace the hard reference with a reference to the main HUD	
	m_HUD = UIDIOHUD(`SCREENSTACK.GetScreen(`PRESBASE.UIHUD_Strategy));
	// HELIOS END	
	m_HUD.UpdateResources(self);

	NavHelp = InitController.Pres.GetNavHelp();
	if (NavHelp == none) // Tactical
	{
		NavHelp = Spawn(class'UINavigationHelp', self).InitNavHelp();
	}
	UpdateNavHelp();
}

simulated function UpdateNavHelp()
{
	NavHelp.AddContinueButton(NextResearch);
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

//---------------------------------------------------------------------------------------
simulated function InitResearchUnlocked(array<X2DioResearchTemplate> UnlockedResearchTemplates)
{
	local int i;
	local XGParamTag LocTag;
	local X2DioResearchTemplate ResearchTemplate;
	local string ResearchName, ResearchDescription, TempString;

	CurrentResearchIndex = 0;
	NumUnlockedResearch = UnlockedResearchTemplates.Length;

	LocTag = XGParamTag(`XEXPANDCONTEXT.FindTag("XGParam"));
	
	for(i = 0; i < UnlockedResearchTemplates.Length; ++i)
	{
		ResearchTemplate = UnlockedResearchTemplates[i];
		//ResearchState = XComGameState_Research(History.GetGameStateForObjectID(UnlockedResearchs[i].ObjectID));

		LocTag.StrValue0 = string(ResearchTemplate.DataName);

		if (ResearchTemplate.DisplayName != "")
		{
			ResearchName = ResearchTemplate.DisplayName;
		}
		else
		{
			ResearchName = `XEXPAND.ExpandString(m_strMissingResearchName);
		}

		TempString = ResearchTemplate.GetSummaryString();
		if (TempString != "")
		{
			ResearchDescription = TempString;
		}
		else
		{
			ResearchDescription = `XEXPAND.ExpandString(m_strMissingResearchDescription);
		}
		
		AddResearch(m_strTitle, ResearchName, ResearchTemplate.Image, ResearchDescription);
	}

	// Causes research panels to reposition themselves and animate in.
	MC.FunctionVoid("realize");
}

//---------------------------------------------------------------------------------------
simulated function bool OnUnrealCommand(int cmd, int arg)
{
	// Only pay attention to presses or repeats; ignoring other input types
	// NOTE: Ensure repeats only occur with arrow keys
	if ( !CheckInputIsReleaseOrDirectionRepeat(cmd, arg) )
		return false;

	switch( cmd )
	{
		// OnAccept
`if(`notdefined(FINAL_RELEASE))
		case class'UIUtilities_Input'.const.FXS_KEY_TAB:
`endif
		case class'UIUtilities_Input'.const.FXS_BUTTON_A:
		case class'UIUtilities_Input'.const.FXS_KEY_ENTER:
		case class'UIUtilities_Input'.const.FXS_BUTTON_B:
		case class'UIUtilities_Input'.const.FXS_KEY_ESCAPE:
		case class'UIUtilities_Input'.const.FXS_R_MOUSE_DOWN:
			NextResearch();
			return true;
		case class'UIUtilities_Input'.const.FXS_BUTTON_START:
			`HQPRES.UIPauseMenu( ,true );
			return true;
	}

	return true;
}

//---------------------------------------------------------------------------------------
simulated function OnCommand(string cmd, string arg)
{
	if(cmd == "NoMoreResearch")
	{
		CloseScreen();
	}
}

//---------------------------------------------------------------------------------------
//simulated function CloseScreen()
//{
//	local XComGameStateHistory History;
//	local XComGameState_HeadquartersXCom XComHQ;
//
//	Super.CloseScreen();
//
//	History = `XCOMHISTORY;
//	XComHQ = XComGameState_HeadquartersXCom(History.GetSingleGameStateObjectForClass(class'XComGameState_HeadquartersXCom'));
//
//	if(!XComGameState_MissionSite(History.GetGameStateForObjectID(XComHQ.MissionRef.ObjectID)).GetMissionSource().bSkipRewardsRecap && 
//	   XComHQ.IsObjectiveCompleted('T0_M8_ReturnToAvengerPt2'))
//	{
//		`HQPRES.UIRewardsRecap();
//	}
//	else
//	{
//		`HQPRES.ExitPostMissionSequence();
//	}
//}

//---------------------------------------------------------------------------------------
simulated function AddResearch(string Header, string Title, string Image, string Description)
{
	MC.BeginFunctionOp("addResearch");
	MC.QueueString(Header);
	MC.QueueString(Title);
	MC.QueueString(Image);
	MC.QueueString(Description);
	//MC.QueueBoolean(ShadowProject);
	MC.EndOp();
}

//---------------------------------------------------------------------------------------
simulated function NextResearch()
{
	MC.FunctionVoid("nextResearch");

	// This is a safety net that ensures the game will continue regardless of animation time
	CurrentResearchIndex++;
	if(CurrentResearchIndex > NumUnlockedResearch)
	{
		CloseScreen();
	}	
}

//------------------------------------------------------
defaultproperties
{
	Package = "/ package/gfxResearchUnlocked/ResearchUnlocked";
	DisplayTag="UIBlueprint_ResearchUnlocked"
	CameraTag="UIBlueprint_ResearchUnlocked"
}
