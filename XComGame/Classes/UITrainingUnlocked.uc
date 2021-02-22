//---------------------------------------------------------------------------------------
//  FILE:    	UITrainingUnlocked
//  AUTHOR:  	David McDonough  --  6/24/2019
//  PURPOSE: 	Show a sequence of Training Programs available for use.
//				Based on UITrainingUnlocked
//           
//---------------------------------------------------------------------------------------
//  Copyright (c) 2019 Firaxis Games, Inc. All rights reserved.
//---------------------------------------------------------------------------------------
class UITrainingUnlocked extends UIScreen;

// Text
var localized string m_strTitle;
var localized string m_strMissingTrainingName;
var localized string m_strMissingTrainingDescription;

var name DisplayTag;
var name CameraTag;

var int CurrentTrainingIndex;
var int NumUnlockedTraining;

var UINavigationHelp NavHelp;
var UIDIOHUD m_HUD;

// Constructor
simulated function InitScreen(XComPlayerController InitController, UIMovie InitMovie, optional name InitName)
{
	super.InitScreen(InitController, InitMovie, InitName);

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
	NavHelp.AddContinueButton(NextTraining);
	NavHelp.Show();
}

simulated function OnReceiveFocus()
{
	super.OnReceiveFocus();
	m_HUD.UpdateResources(self);
	UpdateNavHelp();
	if (UIMovie_3D(Movie) != none)
	{
		class'UIUtilities'.static.DisplayUI3D(DisplayTag, CameraTag, 0);
	}
}

simulated function OnLoseFocus()
{
	super.OnLoseFocus();
	NavHelp.ClearButtonHelp();
	UIMovie_3D(Movie).HideDisplay(DisplayTag);
}

//---------------------------------------------------------------------------------------
simulated function InitTrainingUnlocked(array<X2DioTrainingProgramTemplate> UnlockedTrainingTemplates)
{
	local int i;
	local XGParamTag LocTag;
	local X2DioTrainingProgramTemplate TrainingTemplate;
	local string TrainingName, TrainingDescription, TempString;

	CurrentTrainingIndex = 0;
	NumUnlockedTraining = UnlockedTrainingTemplates.Length;

	LocTag = XGParamTag(`XEXPANDCONTEXT.FindTag("XGParam"));

	for (i = 0; i < UnlockedTrainingTemplates.Length; ++i)
	{
		TrainingTemplate = UnlockedTrainingTemplates[i];

		LocTag.StrValue0 = string(TrainingTemplate.DataName);

		if (TrainingTemplate.GetDisplayNameString() != "")
		{
			TrainingName = TrainingTemplate.GetDisplayNameString();
		}
		else
		{
			TrainingName = `XEXPAND.ExpandString(m_strMissingTrainingName);
		}

		TempString = TrainingTemplate.GetDescription();
		if (TempString != "")
		{
			TrainingDescription = TempString;

			// Append Effects string
			TempString = TrainingTemplate.GetEffectsString();
			TrainingDescription $= "<br><br>" $ class'UIUtilities_Text'.static.GetColoredText(TempString, eUIState_Good);
		}
		else
		{
			TrainingDescription = `XEXPAND.ExpandString(m_strMissingTrainingDescription);
		}

		AddTraining(m_strTitle, TrainingName, TrainingTemplate.Image, TrainingDescription);
	}

	// Causes research panels to reposition themselves and animate in.
	MC.FunctionVoid("realize");
}

//---------------------------------------------------------------------------------------
simulated function bool OnUnrealCommand(int cmd, int arg)
{
	// Only pay attention to presses or repeats; ignoring other input types
	// NOTE: Ensure repeats only occur with arrow keys
	if (!CheckInputIsReleaseOrDirectionRepeat(cmd, arg))
		return false;

	switch (cmd)
	{
		// OnAccept
		`if(`notdefined(FINAL_RELEASE))
	case class'UIUtilities_Input'.const.FXS_KEY_TAB :
			`endif
	case class'UIUtilities_Input'.const.FXS_BUTTON_A :
	case class'UIUtilities_Input'.const.FXS_KEY_ENTER :
	case class'UIUtilities_Input'.const.FXS_BUTTON_B :
	case class'UIUtilities_Input'.const.FXS_KEY_ESCAPE :
	case class'UIUtilities_Input'.const.FXS_R_MOUSE_DOWN :
			PlayMouseClickSound();
			NextTraining();
		return true;
	case class'UIUtilities_Input'.const.FXS_BUTTON_START :
		`HQPRES.UIPauseMenu(, true);
		return true;
	}

	return true;
}

//---------------------------------------------------------------------------------------
simulated function OnCommand(string cmd, string arg)
{
	if (cmd == "NoMoreResearch")
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
simulated function AddTraining(string Header, string Title, string Image, string Description)
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
simulated function NextTraining()
{
	MC.FunctionVoid("nextResearch");

	// This is a safety net that ensures the game will continue regardless of animation time
	CurrentTrainingIndex++;
	if (CurrentTrainingIndex > NumUnlockedTraining)
	{
		CloseScreen();
	}
}

//------------------------------------------------------
defaultproperties
{
	Package = "/ package/gfxResearchUnlocked/ResearchUnlocked"
}
