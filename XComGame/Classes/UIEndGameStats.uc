//---------------------------------------------------------------------------------------
//  *********   FIRAXIS SOURCE CODE   ******************
//  FILE:    UIEndGameStats
//  AUTHOR:  Sam Batista
//  PURPOSE: This file controls the summary of players achievements
//---------------------------------------------------------------------------------------
//  Copyright (c) 2016 Firaxis Games, Inc. All rights reserved.
//--------------------------------------------------------------------------------------- 

class UIEndGameStats extends UIScreen;

struct TEndGameStat
{
	var string Label;
	var string YouValue;
	var string WorldValue;
};

const BANNER_WIN1 = 0; // good win
const BANNER_WIN2 = 1; // worn win
const BANNER_WIN3 = 2; // torn win
const BANNER_WIN_IRONMAN = 3;
const BANNER_LOSE = 4;
const NUM_PAGES = 1;

var bool bGameWon;
var int CurrentPage;
var array<UIEndGameStatsPage> StatPages;

var UIDIOHUD m_HUD;
var UINavigationHelp NavHelp;

//------------------------------------------------------
// LOCALIZED STRINGS
var localized string GameSummary;
var localized string Victory;
var localized string Defeat;
var localized string Difficulty;
var localized string Ironman;
var localized string Date;
var localized string Doom;
var localized string Page;
var localized string Stats;
var localized string You;
var localized string World;

// FIRST PAGE STATS
var localized string MissionsWon;
var localized string MissionsLost;
var localized string AliensKilled;
var localized string SoldiersLost;
var localized string AverageShotTakenPct;
var localized string FlawlessMissions;
var localized string AverageTurnsLeftOnMissionTimers;

// XPACK SECOND PAGE STATS
var localized string KillsByFactionHeroes;
var localized string AbilityPointsEarned;
var localized string CompletedCovertActions;
var localized string NumLevel3SoldierBonds;
var localized string NumBreakthroughsResearched;

// SECOND PAGE STATS
var localized string SoldiersWhoSawAction;
var localized string DaysToFirstColonel;
var localized string TotalDaysWounded;
var localized string PromotionsEarned;
var localized string NumberColonels;
var localized string PsiSoldiersTrained;
var localized string NumberMaguses;
var localized string HackRewardsEarned;
var localized string RobotsHacked;

// THIRD PAGE STATS
var localized string NumberScientists;
var localized string NumberEngineers;
var localized string DaysToMagneticWeapons;
var localized string DaysToBeamWeapons;
var localized string DaysToPlatedArmor;
var localized string DaysToPowerArmor;
var localized string DaysToAlienEncryption;

// FOURTH PAGE STATS
var localized string RadioRelaysBuilt;
var localized string SuppliesFromDepots;
var localized string SuppliedFromBlackMarket;
var localized string IntelCollected;
var localized string IntelPaidToBlackMarket;
var localized string AlienFacilitiesSabotaged;

// PROGRESS DIALOG
var localized string FetchDataDialogTitle;
var localized string FetchDataDialogBody;

// DIO stats
var localized string NumberMaxRankedAgents;
var localized string TotalNumUnitScarsAcquired;
var localized string DaysToVictory;
var localized string NumberCapturedUnits;


//------------------------------------------------------
// MEMBER DATA
var XComGameState_Analytics Analytics;
var AnalyticsManager AnalyticsManager;

//==============================================================================
//		INITIALIZATION & INPUT:
//==============================================================================
simulated function InitScreen(XComPlayerController InitController, UIMovie InitMovie, optional name InitName)
{
	local int i;

	super.InitScreen(InitController, InitMovie, InitName);
	// HELIOS BEGIN
	// Replace the hard reference with a reference to the main HUD	
	m_HUD = UIDIOHUD(`SCREENSTACK.GetScreen(`PRESBASE.UIHUD_Strategy));
	// HELIOS END	
	m_HUD.UpdateResources(self);
	m_HUD.NavHelp.ClearButtonHelp();
	NavHelp = m_HUD.NavHelp;

	MC.BeginFunctionOp("setBannerData");
	MC.QueueString(class'UIUtilities_Image'.const.VictoryScreenNarrativeImage);
	MC.QueueString(Victory); //strTitle
	MC.QueueString(Difficulty); //strDifficultyLabel
	MC.QueueString(Caps(class'UIShellDifficulty'.default.m_arrDifficultyTypeStrings[`CAMPAIGNDIFFICULTYSETTING])); //strDifficultyValue
	MC.QueueString(`GAME.m_bIronman ? Ironman : ""); //strIronman
	MC.QueueString(Date); //strDateLabel
	MC.QueueString(class'X2StrategyGameRulesetDataStructures'.static.GetDateString(class'UIUtilities_Strategy'.static.GetGameTime().CurrentTime, true)); //strDateValue
	MC.EndOp();

	for (i = 0; i < NUM_PAGES; ++i)
	{
		//MC.FunctionVoid("addStatPage");
		StatPages.AddItem(UIEndGameStatsPage(Spawn(class'UIEndGameStatsPage', self).InitPanel()));
	}

	AnalyticsManager = `XANALYTICS;
		Analytics = XComGameState_Analytics(`XCOMHISTORY.GetSingleGameStateObjectForClass(class'XComGameState_Analytics'));

	if (AnalyticsManager.WaitingOnWorldStats())
	{
		ShowFetchingDataProgressDialog();
		return;
	}

	UpdateStats();
	UpdateNavHelp();
	MC.FunctionVoid("animateIn");
}

simulated function OnInit()
{
	super.OnInit();
	OnReceiveFocus();
}

simulated function ShowFetchingDataProgressDialog()
{
	local TProgressDialogData ProgressDialogData;
	ProgressDialogData.strTitle = FetchDataDialogTitle;
	ProgressDialogData.strDescription = FetchDataDialogBody;
	ProgressDialogData.fnCallback = CancelFetchingData;
	Movie.Pres.UIProgressDialog(ProgressDialogData);
}

simulated function CancelFetchingData()
{
	AnalyticsManager.CancelWorldStats();
	DisplayStats();
}

simulated function DisplayStats()
{
	UpdateNavHelp();
	UpdateStats();
	Show();
	MC.FunctionVoid("animateIn");
}

simulated function UpdateStats()
{
	StatPages[0].UpdateStats(GetFirstPageStats());
}

simulated function float GetWinLevel()
{
	if (`GAME.m_bIronman)
		return BANNER_WIN_IRONMAN;

	// TODO: @mnauta

	return BANNER_WIN1;
}

simulated function UpdateNavHelp()
{
	NavHelp.ClearButtonHelp();
	if (CurrentPage > 0)
	{
		NavHelp.AddBackButton(OnBack);
	}
	NavHelp.AddContinueButton(OnContinue);
}

simulated function OnContinue()
{
	CurrentPage++;
	UpdateNavHelp();
	if (CurrentPage >= NUM_PAGES)
		CloseScreen();
	else
		MC.FunctionVoid("nextStat");
}

simulated function OnBack()
{
	if (CurrentPage > 0)
	{
		CurrentPage--;
		UpdateNavHelp();
		MC.FunctionVoid("prevStat");
	}
}

simulated function array<TEndGameStat> GetFirstPageStats()
{
	local TEndGameStat Stat;
	local array<TEndGameStat> StatList;
	local float NumTimedMissions, RemainingTimers;
	local float NumShots, NumSuccessfulShots;

	Stat.Label = MissionsWon;
	Stat.YouValue = Analytics.GetValueAsString("BATTLES_WON");
	//Stat.WorldValue = AnalyticsManager.GetAvgWorldStatValueAsString("BATTLES_WON");
	StatList.AddItem(Stat);

	Stat.Label = FlawlessMissions;
	Stat.YouValue = Analytics.GetValueAsString("FLAWLESS_MISSIONS");
	//Stat.WorldValue = AnalyticsManager.GetAvgWorldStatValueAsString("FLAWLESS_MISSIONS");
	StatList.AddItem(Stat);

	Stat.Label = AliensKilled;
	Stat.YouValue = Analytics.GetValueAsString("ACC_UNIT_KILLS");
	//Stat.WorldValue = AnalyticsManager.GetAvgWorldStatValueAsString("ACC_UNIT_KILLS");
	StatList.Additem(Stat);

	Stat.Label = NumberCapturedUnits;
	Stat.YouValue = Analytics.GetValueAsString("TOTAL_UNITCAPTURED");
	StatList.Additem(Stat);

	Stat.Label = TotalNumUnitScarsAcquired;
	Stat.YouValue = Analytics.GetValueAsString("TOTAL_UNITSCARS");
	StatList.Additem(Stat);

	Stat.Label = NumberMaxRankedAgents;
	Stat.YouValue = Analytics.GetValueAsString("NUM_MAXRANKED_AGENTS");
	StatList.Additem(Stat);

	Stat.Label = DaysToVictory;
	Stat.YouValue = Analytics.GetValueAsString("XCOM_VICTORY");
	StatList.Additem(Stat);



	Stat.Label = AverageShotTakenPct;
	NumShots = Analytics.GetFloatValue("ACC_UNIT_SHOTS_TAKEN");
	NumSuccessfulShots = Analytics.GetFloatValue("ACC_UNIT_SUCCESS_SHOTS");
	if (NumShots > 0)
	{
		Stat.YouValue = class'UIUtilities'.static.FormatPercentage(NumSuccessfulShots / NumShots * 100, 0);
	}
	else
	{
		Stat.YouValue = "--";
	}
	/*NumShots = AnalyticsManager.GetWorldStatFloatValue( "ACC_UNIT_SHOTS_TAKEN" );
	NumSuccessfulShots = AnalyticsManager.GetWorldStatFloatValue( "ACC_UNIT_SUCCESS_SHOTS" );
	if(NumShots > 0)
	{
		Stat.WorldValue = class'UIUtilities'.static.FormatPercentage(NumSuccessfulShots / NumShots * 100, 0);
	}
	else
	{
		Stat.WorldValue = "--";
	}*/
	StatList.Additem(Stat);

	Stat.Label = AverageTurnsLeftOnMissionTimers;
	NumTimedMissions = Analytics.GetFloatValue("NUM_TIMED_MISSIONS");
	RemainingTimers = Analytics.GetFloatValue("REMAINING_TIMED_MISSION_TURNS");
	if (NumTimedMissions > 0)
	{
		Stat.YouValue = class'UIUtilities'.static.FormatFloat(RemainingTimers / NumTimedMissions, 2);
	}
	else
	{
		Stat.YouValue = "--";
	}
	/*NumTimedMissions = AnalyticsManager.GetWorldStatFloatValue( "NUM_TIMED_MISSIONS" );
	RemainingTimers = AnalyticsManager.GetWorldStatFloatValue( "REMAINING_TIMED_MISSION_TURNS" );
	if (NumTimedMissions > 0)
	{
		Stat.WorldValue = class'UIUtilities'.static.FormatFloat( RemainingTimers / NumTimedMissions, 2 );
	}
	else
	{
		Stat.WorldValue = "--";
	}*/

	Stat.Label = SoldiersWhoSawAction;
	Stat.YouValue = Analytics.GetValueAsString("SAW_ACTION");
	//Stat.WorldValue = AnalyticsManager.GetAvgWorldStatValueAsString("SAW_ACTION");
	StatList.Additem(Stat);

	Stat.Label = RobotsHacked;
	Stat.YouValue = Analytics.GetValueAsString("SUCCESSFUL_HAYWIRES");
	//Stat.WorldValue = AnalyticsManager.GetAvgWorldStatValueAsString("SUCCESSFUL_HAYWIRES");
	StatList.Additem(Stat);

	return StatList;
}


simulated function bool OnUnrealCommand(int cmd, int arg)
{
	// Only pay attention to presses or repeats; ignoring other input types
	// NOTE: Ensure repeats only occur with arrow keys
	if (!CheckInputIsReleaseOrDirectionRepeat(cmd, arg))
		return false;

	switch (cmd)
	{
	case class'UIUtilities_Input'.const.FXS_BUTTON_A :
	case class'UIUtilities_Input'.const.FXS_KEY_ENTER :
	case class'UIUtilities_Input'.const.FXS_KEY_SPACEBAR :
		OnContinue();
		break;
	default:
		break;
	}

	return true;
}

//----------------------------------------------------------

simulated function Show()
{
	super.Show();
	NavHelp.Show();
}

simulated function Hide()
{
	super.Hide();
	NavHelp.Hide();
}

simulated function OnReceiveFocus()
{
	super.OnReceiveFocus();
	m_HUD.UpdateResources(self);
	UpdateNavHelp();
	DisplayStats();
}

simulated function OnRemoved()
{
	`STRATEGYRULES.GotoState('CampaignEnd');
}

//==============================================================================
//		DEFAULTS:
//==============================================================================
DefaultProperties
{
	Package = "/ package/gfxEndGameStats/EndGameStats";
	bAnimateOnInit = false; // we handle animation differently
	bConsumeMouseEvents = true;
	InputState = eInputState_Consume;
}
