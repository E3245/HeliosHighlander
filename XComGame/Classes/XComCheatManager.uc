/**
 * Copyright 1998-2008 Epic Games, Inc. All Rights Reserved.
 */
//=============================================================================
// CheatManager
// Object within playercontroller that manages "cheat" commands
//=============================================================================

class XComCheatManager extends CheatManager within XComPlayerControllerNativeBase
	dependson(XComWeatherControl)
	dependson(XComMCPTypes)
	dependson(XComEngine)
	dependson(XComGameState_LadderProgress)
	native(Core)
	config(Cheats);

//X-Com 2 debug modes
var bool bDebugVisualizers;
var bool bDebugVisualizersDetail;
var bool bDebugHistory;
var bool bDebugRuleset;
var bool bAIActivityHack;
var bool bDebugXp;
var bool bDebugSoldierRelationships;
var bool bDisableLootFountain;

var bool bShowActions;
var bool bLightDebugMode;
var bool bLightDebugRealtime;
var bool bUseGlamCam;
var bool bUseAIGlamCam;
var bool bShowCamCage;
var XComTacticalController  m_kPlayerControllerOwner;
var PlayerController GeneralPlayerController;
var XComPresentationLayer m_kPres;
var string m_strGlamCamName;
var bool m_bUseGlamBlend;
var bool m_bDebugVis;
var bool m_bDebugIK;
var bool m_bDebugAims;
var ETeam  m_DebugAimsTeam;
var bool bDebugHandIK;
var bool m_bStrategyAllFacilitiesAvailable;
var bool m_bStrategyAllFacilitiesFree;
var bool m_bStrategyAllFacilitiesInstaBuild;
var bool bDebuggingVisibilityToCursor;
var bool m_bAllowShields; 
var bool m_bAllowAbortBox; 
var bool m_bAllowTether; 

var bool bDebugFracDestruction;

var bool bSimulatingCombat; // SimCombat in progress

var bool bNarrativeDisabled;

var bool bDebugMouseTrace;

// Animation Debugging Variables START
var bool bDebugAnims;
var bool bDebugAnimsPawn;
var bool bDisplayAnims;
var Name m_DebugAnims_TargetName;

// Some Tactical cheats need to be stored at this level so that native code can read their state
// Tactical Cheats------------------------------------------------------------------------------
var bool bGhostMode; // Cheat- ghost mode.
var bool bDebugVisibility;
var bool bDebugFOW;
var bool bDisableSpawningPrereqs;
//----------------------------------------------------------------------------------------------

var bool bMusicDisabled;
var bool bAmbienceDisabled;
var bool bConcealmentTilesHidden;
var bool bLoadedMarketingPresets;

var bool bDebugCameras;
var bool bForceMissionVictory;

// DIO
//----------------------------------------------------------------------------------------------
var bool bDebugCameraObstacleHiding;
var bool bDebugSlomoGroups;
var bool bUsedPlayDialogueCheat;

// procedural encounter params
var int StartingAlertLevel;
var array<EnemyFactionSpawnInfo> FactionSpawnInfos;
var array<EnemyFactionForceLevelInfo> FactionForceLevelInfos;
//----------------------------------------------------------------------------------------------

/** Gets a copy of the friends data from the online subsystem */
var array<OnlineFriend> m_arrFriendsList;

var XGUnit m_kVisDebug;
var XComOnlineStatsRead m_kStatsRead;

var int X2DebugHistoryHighlight;
var string ErrorReportTitle;
var string ErrorReportText;
var bool m_bSendCrashInfo;

var config bool bShouldAutosaveBeforeEveryAction;

var bool bMonkeyRun;
var array<int> PriorityInput;

struct native CommandSet
{
	var string Name;
	var array<string> Commands;
};

var array<CommandSet> CommandSets;

simulated native function LoadCommandSets();

simulated native function WriteToFilteredLogFile(string WriteString, name ChannelName);

exec native function ConvertEncounters();

exec native function TestThreadedScripting(bool Infinite = false);
simulated event int ThreadingTestCallback(int depth = 0)
{
	local int returnDepth;

	if(depth < 20)
	{
		returnDepth = ThreadingTestCallback(depth + 1);
		`assert(returnDepth == (depth + 1));
	}

	`assert(depth < 21);

	return depth;
}

exec function RunCommandSet(string CommandSetName)
{
	local int Idx, CmdIdx;
	local Console PlayerConsole;
    local LocalPlayer LP;

	if (CommandSets.Length == 0)
		LoadCommandSets();

	for (Idx = 0; Idx < CommandSets.Length; ++Idx)
	{
		if (CommandSets[Idx].Name ~= CommandSetName)
		{
			LP = LocalPlayer( Outer.Player );
			if( ( LP != none )  && ( LP.ViewportClient.ViewportConsole != none ) )
			{
				PlayerConsole = LocalPlayer( Player ).ViewportClient.ViewportConsole;
			}

			for (CmdIdx = 0; CmdIdx < CommandSets[Idx].Commands.Length; ++CmdIdx)
			{
				if (PlayerConsole != none)
					PlayerConsole.OutputText(CommandSets[Idx].Commands[CmdIdx]);
				ConsoleCommand(CommandSets[Idx].Commands[CmdIdx], true);
			}
			break;
		}
	}
}

exec function DebugAnims(optional bool bEnable = true, optional bool bEnableDisplay = false, optional Name unitName = '')
{
	bDebugAnims = bEnable;              // Enables animation logging to internal memory buffer.
	bDisplayAnims = bEnableDisplay;      // Displays logged animations to screen.

	if (unitName == '' || unitName == 'all')
	{
		m_DebugAnims_TargetName = '';		
		bDebugAnimsPawn = true;
	}
	else
	{
		m_DebugAnims_TargetName = unitName;   // Debugs ONE unit only. Will write to screen && std-out.
	}
}

exec function DioDebugSlomogroups()
{
	bDebugSlomoGroups = !bDebugSlomoGroups;
}

exec function UpdateSavedGamesList()
{
	`ONLINEEVENTMGR.UpdateSaveGameList();
}

exec function X2DebugVisualizers(optional bool bDetailedInfo)
{
	bDebugRuleset = false;
	bDebugHistory = false;
	bDebugVisualizers = !bDebugVisualizers;

	if (bDebugVisualizers)
	{
		`SCREENSTACK.Push(spawn(class'UIDebugVisualizers'));
		bDebugVisualizersDetail = bDetailedInfo;
	}
	else
	{
		`SCREENSTACK.PopFirstInstanceOfClass(class'UIDebugVisualizers');
	}
}

exec function X2DebugRuleset()
{
	bDebugVisualizers = false;
	bDebugHistory = false;
	bDebugRuleset = !bDebugRuleset;
}

exec function X2DebugHistory()
{
	XComPlayerController(Outer).Pres.UIHistoryDebugScreen();
}

exec function X2DebugHistoryHighlightObjectID(int ObjectID)
{
	X2DebugHistoryHighlight = ObjectID;
}

exec function X2AuthorRegions()
{
	XComPlayerController(Outer).Pres.UIAuthorRegionsDebugScreen();
}

exec function X2DebugItems()
{
	XComPlayerController(Outer).Pres.UIItemDebugScreen();
}

exec function X2DebugVisibility()
{
	XComPlayerController(Outer).Pres.UIVisibilityDebugScreen();
}

exec function X2DebugMultiplayer()
{
	XComPlayerController(Outer).Pres.UIMultiplayerDebugScreen();
}

exec function X2DebugMap()
{
	XComPlayerController(Outer).Pres.UIDebugMap();
}

exec function X2DebugMarketing()
{
	if( !class'Engine'.static.IsRetailGame() || class'Engine'.static.IsConsoleAllowed())
	{
		//This mode can turn off the UI, so make sure the UI is visible before we go in
		if(!XComPlayerController(Outer).Pres.Get2DMovie().bIsVisible)
		{
			XComPlayerController(Outer).Pres.Get2DMovie().Show();
		}
		XComPlayerController(Outer).Pres.UIDebugMarketing();
	}
}

exec function X2PrintHistory()
{
	WriteToFilteredLogFile(`XCOMHISTORY.HistoryDebugString(), 'XCom_Strategy');
}

exec function X2PrintNetworkDebug(optional bool bIncludeDetailedInformation=false)
{
	local XComGameStateNetworkManager NetworkMgr;
	NetworkMgr = `XCOMNETMANAGER;
	NetworkMgr.PrintDebugInformation(bIncludeDetailedInformation);
}

exec function UIRedScreen()
{
	`RedScreen( "DebugRedScreen");
}

exec function UIChallengeModeEventNotify(optional bool bDataView=false)
{
	XComPlayerController(Outer).Pres.UIChallengeModeEventNotify(bDataView);
}

exec function UIReplayScreen()
{
	//bsg-jneal (8.1.17): no replays on console
	if(!`ISCONSOLE)
	{
		XComPlayerController(Outer).Pres.UIReplayScreen("");
	}
	//bsg-jneal (8.1.17): end
}

exec function UISpawnScreen(class<UIScreen> ScreenClass)
{
	XComPlayerController(Outer).Pres.ScreenStack.Push( Spawn(ScreenClass, XComPlayerController(Outer).Pres) );
}

exec function UIDrawGrid()
{
	XComPlayerController(Outer).Pres.UIDrawGridPixel(480, 270, false);
}

exec function UIDrawGridPixel(int horizontalSpacing, int verticalSpacing, bool bIn3D)
{
	XComPlayerController(Outer).Pres.UIDrawGridPixel(horizontalSpacing, verticalSpacing, bIn3D);
}

exec function UIDrawGridPercent(float horizontalSpacing, float verticalSpacing, bool bIn3D)
{
	XComPlayerController(Outer).Pres.UIDrawGridPercent(horizontalSpacing, verticalSpacing, bIn3D);
}

exec function UISetDistortion( float Value )
{
	XComPlayerController(Outer).Pres.SetUIDistortionStrength(Value);
}

exec function UIClearCustomizeAlerts()
{
	`XPROFILESETTINGS.Data.m_arrCharacterCustomizationCategoriesClearedAttention.Length = 0;
	`XPROFILESETTINGS.Data.m_arrCharacterCustomizationCategoriesInfo.Length = 0;
	`ONLINEEVENTMGR.SaveProfileSettings(true);

	`log("Customize alert categories cleared.");
}

exec function UIEnableTooltips()
{
	XComPlayerController(Outer).Pres.m_kTooltipMgr.bEnableTooltips = true;
}
exec function UIDisableTooltips()
{
	XComPlayerController(Outer).Pres.m_kTooltipMgr.bEnableTooltips = false;
}

exec function UIClearGrid()
{
	XComPlayerController(Outer).Pres.UIClearGrid();
}

exec function UIDebugControlOps()
{
	XComPlayerController(Outer).ConsoleCommand("UnSuppress DevGfxUI");
	XComPlayerController(Outer).Pres.UIDebugControlOps();
}

exec function UIPrintMCCache()
{
	XComPlayerController(Outer).ConsoleCommand("UnSuppress DevGfxUI");
	XComPlayerController(Outer).Pres.PrintMCCache();
}

exec function UIDebugControls(optional class<UIScreen> ScreenClass)
{
	local UIScreen SearchScreen;
	local UIPanel Control;
	local array<UIPanel> Controls;

	if(ScreenClass != none)
		Control = XComPlayerController(Outer).Pres.ScreenStack.GetScreen(ScreenClass);
	else
		Control = XComPlayerController(Outer).Pres.ScreenStack.GetCurrentScreen();

	if( Control == none ) //It's outside of the state stack, so let's try to find it in the rest of the universe, probably in the presentation layers.
	{
		foreach AllActors(class'UIScreen', SearchScreen)
		{
			if( SearchScreen.Class == ScreenClass )
			{
				Control = SearchScreen;
				break;
			}
		}
	}

	if(Control != none)
		Control.GetChildrenOfType(class'UIPanel', Controls);
	
	foreach Controls(Control)
	{
		if(Control != none)
			Control.DebugControl();
	}
}

exec function UIPrintMouseLocation()
{
	local Vector2D vMouseCoords;
	XComPlayerController(Outer).Pres.GetMouseCoords(vMouseCoords);
	`log("Mouse Location: X=" $ vMouseCoords.X $ ", Y=" $ vMouseCoords.Y);
}

exec function UIPrintPanelNavigationInfo(optional bool bCascade = false, optional bool bShowNavigatorInfo = false)
{
	XComPlayerController(Outer).Pres.ScreenStack.GetCurrentScreen().PrintPanelNavigationInfo(bCascade, bShowNavigatorInfo);
}

exec function UIPrintNav(optional string TargetPath )
{
	local UIScreen Screen;
	local UIPanel Control;
	local UIScreenStack Screenstack;

	Screenstack = XComPlayerController(Outer).Pres.ScreenStack;
	if( TargetPath != "" )
	{

		foreach Screenstack.Screens(Screen)
		{
			foreach Screen.ChildPanels(Control)
			{
				if( InStr(Caps(String(Control.MCPath)), Caps(TargetPath)) != -1 )
				{
					Control.PrintNavigator();
					return;
				}
			}
		}
	}
	else
	{
		ScreenStack.GetCurrentScreen().PrintNavigator();
	}
}

exec function UIPrintPanelNavFor(string Path, optional bool bCascade = false, optional bool bShowNavigatorInfo = false)
{
	local UIScreen Screen;
	local UIPanel Control;
	local UIScreenStack Screenstack;

	Screenstack = XComPlayerController(Outer).Pres.ScreenStack;

	foreach Screenstack.Screens(Screen)
	{
		if( InStr(Screen.MCPath, Path) == -1 )
			continue;

		foreach Screen.ChildPanels(Control)
		{
			if( InStr(String(Control.MCPath), Path) != -1 )
			{
				Control.PrintPanelNavigationInfo(bCascade, bShowNavigatorInfo);
				return;
			}
		}
	}
}


exec function UIMPShowDisconnectedOverlay()
{
	XComPlayerController(Outer).Pres.LoadGenericScreenFromName("XComGame.UIMultiplayerDisconnectPopup");
}

exec function UIClearCompProfileData()
{
	`XPROFILESETTINGS.Data.ViewedComps.length = 0; 
}

exec function UIClearTutorialPopups()
{
	`XPROFILESETTINGS.Data.ViewedTutorialSteps.length = 0;
}

exec function DisableNarrative()
{
	bNarrativeDisabled = true;	
	`log("NARRATIVE DISABLED");
}


exec function DoAutoTest()
{
	ConsoleCommand("open XComShell?AutoTests=1?MapIndex=-1");
}

exec function TestMe()
{
	local array<SequenceObject> Events;

	`log("Start Test1");
	class'Engine'.static.GetCurrentWorldInfo().GetGameSequence().FindSeqObjectsByName( "UGH", true, Events, true, true);
	`log("End Test2");

}

exec function ClearNarrativeHistory()
{
	local int i;

	for (i = 0; i < XComPlayerController(Outer).Pres.m_kNarrative.m_arrNarrativeCounters.Length; i++)
	{
		XComPlayerController(Outer).Pres.m_kNarrative.m_arrNarrativeCounters[i] = 0;
	}
}

exec function PreloadNarrative(XComNarrativeMoment Moment)
{
	local XGNarrative kNarr;
	
	if (XComPlayerController(Outer).Pres.m_kNarrative == none)
	{
		kNarr = spawn(class'XGNarrative');
		kNarr.InitNarrative();
		XComPlayerController(Outer).Pres.SetNarrativeMgr(kNarr);
	}

	XComPlayerController(Outer).Pres.UIPreloadNarrative(Moment);
}

exec function TestNarrativeClearing()
{
	//DoNarrative(XComNarrativeMoment'NarrativeMoment.SightSectoid');
	//DoNarrative(XComNarrativeMoment'NarrativeMoment.SightMuton');
	//DoNarrative(XComNarrativeMoment'NarrativeMoment.SightThinman');
}

exec function TestNarrativeClearing2()
{
	//DoNarrative(XComNarrativeMoment'NarrativeMoment.FirstUFOShotDown');
	//DoNarrative(XComNarrativeMoment'NarrativeMoment.SightFloater');
	//DoNarrative(XComNarrativeMoment'NarrativeMoment.FirstMissionControl');
}

exec function DoNarrative(XComNarrativeMoment Moment)
{
	local XGNarrative kNarr;
	
	if (XComPlayerController(Outer).Pres.m_kNarrative == none)
	{
		kNarr = spawn(class'XGNarrative');
		kNarr.InitNarrative();
		XComPlayerController(Outer).Pres.SetNarrativeMgr(kNarr);
	}

	XComPlayerController(Outer).Pres.UINarrative(Moment);
}

exec function ValidateNarratives()
{
	local XComNarrativeMoment Moment;
	local XGNarrative kNarr;
	local int iIndex;
	local int iIndex2;
	local SoundCue LoadedCue;
	local XComConversationNode ConversationNode;
	
	if (XComPlayerController(Outer).Pres.m_kNarrative == none)
	{
		kNarr = spawn(class'XGNarrative');
		kNarr.InitNarrative();
		XComPlayerController(Outer).Pres.SetNarrativeMgr(kNarr);
	}

	foreach XComPlayerController(Outer).Pres.m_kNarrative.m_arrNarrativeMoments(Moment)
	{
		
		if ( Moment.arrConversations.Length == 0 && Moment.nmRemoteEvent == 'None')
		{
			`log("ValidateNarratives::Invalid Narrative Moment, Conversations Array is empty and no remote event, Invalid combination (No Sound or Matinee) - " $Moment.Name);
		}

		for (iIndex = 0; iIndex < Moment.arrConversations.Length; iIndex++)
		{
			if (Moment.arrConversations[iIndex] != 'None')
			{
				LoadedCue = SoundCue(DynamicLoadObject( string(Moment.arrConversations[iIndex]), class'SoundCue', false ));	

				ConversationNode = XComPlayerController(Outer).Pres.m_kNarrativeUIMgr.GetConversationNode(LoadedCue);
			
				if (ConversationNode != none)
				{
					for (iIndex2 = 0; iIndex2 < ConversationNode.ChildNodes.Length; iIndex2++)
					{
						if (ConversationNode.ChildNodes[iIndex2] == none)
						{
							`log("ValidateNarratives::Invalid Narrative Moment, Conversation Node Child "$iIndex2$" is none : "$Moment.Name);
						}
					}
				}
				else
				{
					`log("ValidateNarratives::Invalid Narrative Moment, No Conversation Node - " $Moment.Name $" : " $Moment.arrConversations[iIndex]);
				}
			}
		}
	}

}

exec function UIUnlockScreen()
{
	`STRATPRES.UIUnlockCharacter();
}


exec function AchieveEasyGame()
{
	
}
exec function AchieveNormalGame()
{
	
}
exec function AchieveHardGame()
{
	
}
exec function AchieveClassicGame()
{
	
}

exec function ClearGamesCompleted()
{
	
}

exec function DumpMapCounts()
{

}

exec function ResetMapCounts()
{	
	`ONLINEEVENTMGR.SaveProfileSettings();
}


exec function MuffleVO()
{
	XComPlayerController(Outer).Pres.m_kNarrativeUIMgr.MuffleVOOnly();
}

exec function UnMuffleVO()
{
	XComPlayerController(Outer).Pres.m_kNarrativeUIMgr.UnMuffleVOOnly();
}

exec function DebugVis(bool bDebugVis)
{
	m_bDebugVis = bDebugVis;	
}

exec function DebugAims(int FilterToTeam = -1)
{
	local ETeam TeamSetting;	

	switch (FilterToTeam)
	{
	case -1:		
		TeamSetting = eTeam_All;
		break;
	case 0:		
		TeamSetting = eTeam_XCom;
		break;
	case 1:		
		TeamSetting = eTeam_Alien;
		break;
	case 2:	
		TeamSetting = eTeam_Neutral;
		break;
	}

	//Repeating the command without changing the team should toggle debug aims off. If it is off, always toggle
	if (TeamSetting == m_DebugAimsTeam || !m_bDebugAims)
	{
		m_bDebugAims = !m_bDebugAims;
	}

	`log( (m_bDebugAims ? "Enabling" : "Disabling") @ "DebugAims." );		
	if (m_bDebugAims)
	{		
		`log("Team Options are: (-1) ALL, (0) XCOM, (1) ALIEN, (2) NEUTRAL ... ");
		`log("Team Selection:" @ TeamSetting);
		m_DebugAimsTeam = TeamSetting;
	}
}

exec function DebugIK(bool bDebugIK)
{
	m_bDebugIK = bDebugIK;	
}

exec function DebugHandIK()
{
	bDebugHandIK = !bDebugHandIK;
}

exec function DebugFracDestruction()
{
	bDebugFracDestruction = true;
}

exec function  Help(optional string tok)
{  
	if (tok=="set")
	{
		OutputMsg("SET <ObjectName|ClassName]> <PropertyName> <Value>");
		HelpDESC("SETNOPEC <ObjectName|ClassName]> <PropertyName> <Value>", "set value without calling PostEditChange");
		HelpDESC("ex: set xcomfow bHidden true", "Will set the bHidden flag on ALL XComFOW actors in the level");
		HelpDESC("ex: set xcomfow_0 bHidden true", "Will set the bHidden flag on just xcomfow_0");
	}
	else
	if(tok=="obj")
	{   // for 'help obj'
		OutputMsg("OBJ PRINT [CLASS=ClassName] [PACKAGE=PackageName] [OUTER=OuterObjectName] [PropertyName==PropertyValue] [-MEMBERS]");
		OutputMsg("OBJ LIST [CLASS=ClassName] [PACKAGE=PackageName] [OUTER=OuterObjectName] [KEY=Key] [VALUE=Value]");
		OutputMsg("OBJ DUMP ObjectName");
		OutputMsg("OBJ GC");
		HelpDESC("ex: obj print bHidden==true", "This will print all objects that have their bHidden property set to true");
		HelpDESC("ex: obj print package=MyPackage", "This will print all objects that came from MyPackage");
		HelpDESC("ex: obj print outer=XComFOW bHidden==false", "Find all the children of XComFOW that are currently shown");
		HelpDESC("ex: obj print -MEMBERS outer=XComFOW", "Prints out all of the class members of XComFOW");
		HelpDESC("ex: obj list", "This will list all classes in the level");
		HelpDESC("ex: obj list class=interpactor", "This will list all objects of that class to the log");
		HelpDESC("ex: obj list class=interpactor key=bHidden value=true", "This will list all objects of that class that match the key/value pair");
		HelpDESC("ex: obj dump XComFOW_0", "This will list all member values for the XComFOW actor");
		HelpDESC("ex: obj gc", "This will garbage collect all unreferenced objects");
	}
	else
	if (tok=="stat")
	{
		HelpDESC( "stat (actors|slowactors)", "show stats of all actors");
		HelpDESC( "stat (anim|audio|engine|fps|game|hier|draw)", "show game stats");
		HelpDESC( "stat (memory|memorychurn|scenerendering)", "more show game stats");
		HelpDESC( "stat (sceneupdate|streaming|unit)", "more show game stats");
	}
	else
	if (tok=="show")
	{
		 HelpDESC( "show (bounds|bsp|camfrustums|collision|dynamicshadows)",	    "show/hide categories");
		 HelpDESC( "show (foliage|particles|postprocess)",	    "show/hide categories");
		 HelpDESC( "show (shadowfrustums|skelmeshes|staticmeshes)",	    "more show/hide categories");
		 HelpDESC( "show (terrain|unlittranslucency|volumes)",	    "more show/hide categories");
	}
	else
	if (tok=="viewmode")
	{
		HelpDESC( "viewmode (wireframe|unlit|lightcomplexity|lightingonly|shadercomplexity|texturedensity)",   "change view mode");
	}
	else
	if (tok=="list")
	{
 		HelpDESC( "listtextures",   "list all textures in the log ");
 		HelpDESC( "listwaves",   "list all resident sounds and their sizes,  in the log ");
	}
	else
	if (tok=="togglefow")
	{
		HelpDESC( "ToggleFOW [particles|canopy|lineofsight|regeneration|truesight]",   "toggles Fog of War visibility");
	}
	else
	if (tok=="ui")
	{
		HelpDESC( "EnableDebugMenu",	"Enable the double bumper debug menu access. MENU IS ON BY DEFAULT.");
		HelpDESC( "DisableDebugMenu",	"Disable the double bumper debug menu access. MENU IS ON BY DEFAULT.");
		HelpDESC( "UITooltipsHide",	    "Loop through all tooltips and hide them.");
		HelpDESC( "UITooltipsPrintDebug","Debug print tooltip mgr info.");
		HelpDESC( "UIForceClearAllUIToHUD", "Hit the UI with a Big Hammer. Use only in case of mega state fail, as this has potential bad state consequences.");		
		HelpDESC( "UIListScreens",      "Output all loaded UI screens to the log.");	
		HelpDESC( "UIPrintStateStack",  "Print the presentation layer's (UI) state stack.");
		HelpDESC( "UIStatus",           "Shows the status of the UI" );
		HelpDESC( "UIToggleMouseHitDebugging", "Toggle mouse hittesting to UI logging.");	
		HelpDESC( "UIToggleSafearea",	"Turn on/off the safe area rectangle. Optional bool param bForceToHUD.");
		HelpDESC( "UIEnableTooltips",	"Turn on the tooltip system.");
		HelpDESC( "UIDisableTooltips",	"Turn off the tooltip system.");
		HelpDESC( "ToggleAnchors",		"Turn on/off the anchor points and safearea-based anchor rectangle." );
		HelpDESC( "UIToggleGrid",       "Show ProtoUI grid overlay" );
		HelpDESC( "ToggleHardHide",		"Force UI to be hidden (or *attempt* to re-show after being hidden.)" );		
		HelpDESC( "UIToggleVisibility", "Turn on/off the GFx user interface." );
		HelpDESC( "UIToggleMouseCursor", "Turn on/off the mouse cursor while on PC." );
		HelpDESC( "UIToggleShields",    "Turn on/off drawing the 3D shields." );
		HelpDESC( "UIToggleAbortBox",   "Turn on/off drawing the 3D abort area on the map." );
		HelpDESC("UIToggleTether",		"Turn on/off drawing the glowing cursor tether and the pathing grid.");
		HelpDESC("UIDrawGrid",			"Draw a grid at 25% increments in UI pixel space in the 2D movie.");
		HelpDESC("UIDrawGridPixel",		"Specify a grid in UI pixel space to draw, in 2D or 3D.");
		HelpDESC("UIDrawGridPercent",	"Specify a grid using percent in UI pixel space to draw, in 2D or 3D.");
		HelpDESC("UISetDistortion", "Set the value for the UI distortion on the 3D material instance.");
		HelpDESC("UIClearCustomizeAlerts", "Clear the array of alert categories you've seen in the UICustomizesystem from your profile.");
	}
	else
	{
     `log( "===============Add more Help in XComCheatManager=" );
//     HelpDESC( "quit",              "exit the game");
	 HelpDESC( "show",	        "use 'help show' for more info");
	 HelpDESC( "stat",	        "use 'help stat' for more info");
	 HelpDESC( "set",	        "use 'help set' for more info");
	 HelpDESC( "obj list|print",   "use 'help obj' for more info");
     HelpDESC( "viewmode",      "use 'help viewmode' for more info");
	 HelpDESC( "pause",   "toggle pause");
	 HelpDESC( "disconnect",   "restart game");
     HelpDESC( "sloMo t",           "slow game down by t");
     HelpDESC( "teleportToCursor",           "move your current guy to the cursor");
     HelpDESC( "PDI <class>",       "Print debug info on Class");
	 HelpDESC( "nxvis collision",   "show physics collisions volume??");
//	 HelpDESC( "ToggleLoadingScreen","Toggle the canvas loading screen");
// 	 HelpDESC( "DebugFootsteps","Turn on debug CLIP CLOP sound when stepping on unknown materials");
	 HelpDESC( "screenshot",   "take a screenshot to xcomgame\screenshots");
	 HelpDESC( "showlog",   "toggle log window");
//	 HelpDESC( "gameversion",   "write game and engine version to log window");
	 HelpDESC( "freezeall",   "freeze rendering and streaming, visibility culling");
	 HelpDESC( "availabletexmem",   "display in the log how much texture mem is available");
 	 HelpDESC( "listtextures",   "list all textures in the log ");
 	 HelpDESC( "listsounds",   "list all resident sounds and their sizes,  in the log ");
	 HelpDESC( "showhotkismet",   "list top 10 kismet sequenceops to the log");
	 HelpDESC( "killall *class*",   "ex: killall class=trigger, kill all objects of that class");
	 HelpDESC( "set classname property value",   "ex: set actor bHidden 1");
	 HelpDESC( "ToggleFOW",   "toggles Fog of War visibility");
	 HelpDESC( "SpawnWeather", "spawn weather actor");
	 HelpDESC( "ToggleCascadeRestriction", "Toggle rendering selective cascade frustums" );
	 HelpDESC( "ParticleInfo", "lists all particle systems count");
	 HelpDESC( "ToggleLightDebug", "places debug shapes around all lights");
	 HelpDESC( "TogglePostProcess [optional index]", "toggles one/all post process effects");
	 HelpDESC( "SetMLAAMode index", "Sets MLAA Mode [0=Normal, 1=Force Off, 2=Vis. X Distance, 3=Vis. Y Distance, 4=Vis. Weight]");
	 HelpDESC( "ToggleRain", "toggles rain effect" );
	 HelpDESC( "TriggerFlash", "triggerlightingflashdebug" );
	 HelpDESC( "RainRateScale x", "toggles rain scale" );
//	 HelpDESC( "PlayBink movieName",   "plays a fullscreen movie once");
	 HelpDESC( "Changelist", "Outputs the build changelist to the console command window");
	 HelpDESC( "dptrans x y z, dprot x y z", "sets the translation/rotation of the decal projector (for debugging)");
	 HelpDESC( "dpfrustum w h", "sets the total width and total height of the projector's frustum (for debugging)");
	 HelpDESC( "geoscapept u v", "prints the country id at the uv coordinates" );
	 HelpDESC( "killsquad", "kills entire squad" );
	 HelpDESC( "WhatsOnMyFloors [floor=0 e.g. all floors] [actorclass=class'Actor']", "dump what actors are touching in the cursor's building");
	 HelpDESC( "WhatsAreMyFloors", "output all floor volumes in the current floor" );
	 HelpDESC( "SetGlamCam [on, off]", "turns glam cam on or off. call with no arguments to toggle" );
	 HelpDESC( "SetStrategyFacilitiesSuperSpree [on, off]", "allows player to build all the facilities from the start, free, and they are constructed immediately. call with no arguments to toggle");
	 HelpDESC( "SetStrategyFacilitiesUnlockAll [on, off]", "allows player to build all the facilities available. call with no arguments to toggle");
	 HelpDESC( "SetStrategyFacilitiesFree [on, off]", "allows player to build facilities for free. call with no arguments to toggle");
	 HelpDESC( "SetStrategyFacilitiesInstantBuild [on, off]", "facilities are finished instantly. call with no arguments to toggle");
	 HelpDESC( "SetNoWeaponsClass [on, off]", "Soldiers can try on weapons, armor, and items regardless of class. No promises for what happens in tactical mode");
	 HelpDESC( "SetNoWeaponsTech [on, off]", "Soldiers can try on weapons, armor, and items regardless of if the tech is researched. No promises for what happens in tactical mode");
	}
	OutputMsg("====================================================");
}

exec function WhereIs(string ActorName)
{
	local Actor Target, It;
	local PlayerController PC;

	foreach AllActors(class'Actor', It)
	{
		if (It.Name == name(ActorName))
		{
			Target = It;
			break;
		}
	}

	if (Target != none)
	{
		`log(Target.Name @ "is at" @ Target.Location @ "rot=" $ Target.Rotation);
		if (Target.bHidden)
		{
			`log(Target.Name @ "is hidden, unhiding...");
			Target.SetHidden(false);
		}

		PC = GetALocalPlayerController();
		if (PC != none)
		{
			PC.SetViewTarget(Target);
		}
	}
	else
	{
		`log("There is no actor named" @ ActorName);
	}
}

exec function RebuildBVs()
{
	local XComBuildingVolume kBuildingVolume;
	foreach AllActors(class'XComBuildingVolume', kBuildingVolume)
	{
		kBuildingVolume.CacheStreamedInActors();
	}
}

exec native function SetFOWFVBlurKernel (int iBlurKernelSize);
exec native function SetPPIgnoreIndex (int iIndex);
exec native function SetDisplayGamma (float fGamma);
exec native function SetGammaColorOverlay (float R, float G, float B);
exec native function SetGammaColorScale (float R, float G, float B);
exec native function ToggleDynamicColorSwitch();

exec native function DumpSkelPoseUpdaters();


//exec function SetFOWFVOpacity(float fOpacity)
//{
//	(MaterialInstanceConstant'XComEngineMaterials.PP_SSFOW_INST').SetScalarParameterValue('fFogIntensity', fOpacity);
//}

exec function SetFOWHaveSeen(float x)
{
	local XComLevelVolume LevelVolume;
	foreach AllActors(class'XComLevelVolume', LevelVolume)
	{
		LevelVolume.WorldData.FOWHaveSeen = x;
		LevelVolume.WorldData.UpdateDebugVisuals(false);
	}
}

exec function SetFOWNeverSeen(float x)
{
	local XComLevelVolume LevelVolume;
	foreach AllActors(class'XComLevelVolume', LevelVolume)
	{
		LevelVolume.WorldData.FOWNeverSeen = x;
		LevelVolume.WorldData.UpdateDebugVisuals(false);
	}
}

//exec function SetFOWColor(float r, float g, float b)
//{	
//	local LinearColor tmpColor;

//	tmpColor = MakeLinearColor(r,g,b,1);
//	(MaterialInstanceConstant'XComEngineMaterials.PP_SSFOW_INST').SetVectorParameterValue('Color', tmpColor);
//}

exec function SpawnWeather()
{
	XComTacticalController(WorldInfo.GetALocalPlayerController()).WeatherControl();
}

exec function ToggleCascadeRestriction()
{
}

exec function ParticleInfo()
{
	local Actor A;
	local ParticleSystemComponent PSC;
	local int count;

	foreach AllActors(class'Actor', A)
	{
		count = 0;
		foreach A.AllOwnedComponents(class'ParticleSystemComponent', PSC)
			count++;

		if(count > 0)
			OutputMsg(A @ count);
	}
}

exec function SetEncounterIDForVis(int ID)
{
	local XComBuildingVisManager VisMgr;
	foreach AllActors(class'XComBuildingVisManager', VisMgr)
	{
		VisMgr.ResetEncounter();
		if (!VisMgr.AddEncounter(ID))
		{
			OutputMsg("Invalid Encounter ID");
		}
	}
}

exec function ToggleLightDebug()
{
	local Actor A;
	local LightComponent L;

	bLightDebugMode = !bLightDebugMode;

	if(!bLightDebugRealtime)
	{		
		if(bLightDebugMode)
		{
			foreach AllActors(class'Actor', A)
			{
				foreach A.AllOwnedComponents(class'LightComponent', L)
				{
					OutputMsg(L @ "Owner:" @ A @ "Location:" @ L.GetOrigin().X @ L.GetOrigin().Y @ L.GetOrigin().Z @ "Enabled:" @ L.bEnabled);
					if(L.bEnabled)
						DrawDebugSphere(L.GetOrigin(), 25, 10, 255, 0, 0, true);
					else
						DrawDebugSphere(L.GetOrigin(), 25, 10, 0, 0, 255, true);
				}
			}
		}
		else
		{
			FlushPersistentDebugLines();
		}
	}
}

exec function TogglePostProcess(optional int iIndex)
{
	local LocalPlayer LP;
	local int i, j;
	local PostProcessChain PPChain;
	local PostProcessEffect PPEffect;

	if(iIndex == -1)
		ConsoleCommand("show postprocess");
	else
	{
		LP = LocalPlayer(Player);
		for(i=0;i<LP.PlayerPostProcessChains.Length;i++)
		{
			PPChain = LP.PlayerPostProcessChains[i];
			for(j=0;j<PPChain.Effects.Length;j++)
			{
				PPEffect = PPChain.Effects[j];
				if(PPEffect != none)
				{
					if(iIndex == 0)
						PPEffect.bShowInGame = !PPEffect.bShowInGame;
					iIndex--;
				}
			}
		}
	}
}

exec function GetPostProcessName(optional int iIndex)
{
	local LocalPlayer LP;
	local int i, j;
	local PostProcessChain PPChain;
	local PostProcessEffect PPEffect;
	
	if (iIndex == -1)
		return;
	else
	{
		LP = LocalPlayer(Player);
		for (i = 0; i < LP.PlayerPostProcessChains.Length; i++)
		{
			PPChain = LP.PlayerPostProcessChains[i];
			for (j = 0; j < PPChain.Effects.Length; j++)
			{
				PPEffect = PPChain.Effects[j];
				if (PPEffect != none)
				{
					if (iIndex == 0)
					{
						OutputMsg(string(PPEffect.EffectName));
					}
					iIndex--;
				}
			}
		}
	}
}

exec function SetMLAAMode(int ModeIndex )
{
	local LocalPlayer LP;
	local PostProcessChain PPChain;
	local MLAAEffect MLAAPPEffect;
	local int i;
	local int j;

	LP = LocalPlayer(Player);
	for(i=0;i<LP.PlayerPostProcessChains.Length;i++)
	{
		PPChain = LP.PlayerPostProcessChains[i];

		// Search for the MLAA Effect
		for(j=0;j<PPChain.Effects.Length;j++)
		{
			MLAAPPEffect = MLAAEffect(PPChain.Effects[j]);
			if(MLAAPPEffect != none)
			{
				MLAAPPEffect.CurrentMode = EMLAAMode(ModeIndex);
			}
		}
	}
}

exec function forceglamcam(string strGlamCamName)
{
	m_strGlamCamName = Caps(strGlamCamName);
}

exec function setglamblend(bool bUseGlamBlend)
{
	m_bUseGlamBlend = bUseGlamBlend;
}


exec function setcinematicmode(optional string strCommand)
{
	local XComTacticalController kTacticalController;
	local bool bCurMode,bNewMode;

	//kTacticalController = XComTacticalController(GetALocalPlayerController());
	kTacticalController = XComTacticalController(ViewTarget.Owner);
	bCurMode = kTacticalController.m_bInCinematicMode;

	if(strCommand == "on")
	{
		bNewMode = true;
		kTacticalController.SetCinematicMode(bNewMode, true, true, true, true, true);
	}
	else if(strCommand == "off")
	{
		bNewMode = false;
		kTacticalController.SetCinematicMode(bNewMode, true, true, true, true, true);
	}
	else
	{
		bNewMode = !bCurMode;
		kTacticalController.SetCinematicMode(bNewMode, true, true, true, true, true);
	}
	`log("Cinematic mode ="@bNewMode);
}

exec function setglamcam(optional string strCommand)
{
	if(strCommand == "on")
	{
		bUseGlamCam = true;
	}
	else if(strCommand == "off")
	{
		bUseGlamCam = false;
	}
	else
	{
		bUseGlamCam = !bUseGlamCam;
	}
}

exec function setaiglamcam(optional string strCommand)
{
	if(strCommand == "on")
	{
		bUseAIGlamCam = true;
	}
	else if(strCommand == "off")
	{
		bUseAIGlamCam = false;
	}
	else
	{
		bUseAIGlamCam = !bUseAIGlamCam;
	}
}

exec function superspree (optional string strCommand)
{ 
	setstrategyfacilitiessuperspree(strCommand);
}
exec function setstrategyfacilitiessuperspree (optional string strCommand)
{
	if (strCommand == "on") {
		m_bStrategyAllFacilitiesAvailable  = true;
		m_bStrategyAllFacilitiesFree       = true;
		m_bStrategyAllFacilitiesInstaBuild = true;
	} else if (strCommand == "off") {
		m_bStrategyAllFacilitiesAvailable  = false;
		m_bStrategyAllFacilitiesFree       = false;
		m_bStrategyAllFacilitiesInstaBuild = false;
	} else {
		m_bStrategyAllFacilitiesAvailable  = !m_bStrategyAllFacilitiesAvailable;
		m_bStrategyAllFacilitiesFree       = !m_bStrategyAllFacilitiesFree;
		m_bStrategyAllFacilitiesInstaBuild = !m_bStrategyAllFacilitiesInstaBuild;
	}
}

exec function setstrategyfacilitiesunlockall (optional string strCommand)
{
	if (strCommand == "on") {
		m_bStrategyAllFacilitiesAvailable  = true;
	} else if (strCommand == "off") {
		m_bStrategyAllFacilitiesAvailable  = false;
	} else {
		m_bStrategyAllFacilitiesAvailable  = !m_bStrategyAllFacilitiesAvailable;
	}
}

exec function setstrategyfacilitiesfree (optional string strCommand)
{
	if (strCommand == "on") {
		m_bStrategyAllFacilitiesFree       = true;
	} else if (strCommand == "off") {
		m_bStrategyAllFacilitiesFree       = false;
	} else {
		m_bStrategyAllFacilitiesFree       = !m_bStrategyAllFacilitiesFree;
	}
}

exec function setstrategyfacilitiesinstantbuild (optional string strCommand)
{
	if (strCommand == "on") {
		m_bStrategyAllFacilitiesInstaBuild = true;
	} else if (strCommand == "off") {
		m_bStrategyAllFacilitiesInstaBuild = false;
	} else {
		m_bStrategyAllFacilitiesInstaBuild = !m_bStrategyAllFacilitiesInstaBuild;
	}	
}

exec function SetPPVignette(string strCommand)
{
      local LocalPlayer LP;
      local int i;
      local PostProcessEffect PPEffect;

      LP = LocalPlayer(Player);
      for(i=0;i<LP.PlayerPostProcessChains.Length;i++)
      {
            PPEffect = LP.PlayerPostProcessChains[i].FindPostProcessEffect('Vignette');
            if(PPEffect != none)
            {
				if (strCommand == "True")
				{
					PPEffect.bShowInGame = true;
//					`log("SetPPVignette:"@strCommand);
				}
				else if (strCommand == "False")
				{
					PPEffect.bShowInGame = false;
//					`log("SetPPVignette:"@strCommand);
				}
            }
      }
}

function FunctionToGetRidOfCompilerWarning(bool bHide)
{
}

// Turn a floor on and off
exec function DebugBuilding(optional string cmd, optional int floor = 0)
{
	local XCom3DCursor Cursor;
	local XComBuildingVolume BuildingVolume;
	local bool bHide;

	bHide = true;
	FunctionToGetRidOfCompilerWarning(bHide);
		
	Cursor = XCom3DCursor(Pawn);

	if (Cursor == none)
		return;

	BuildingVolume = Cursor.IndoorInfo.CurrentBuildingVolume;

	if (BuildingVolume == none)
	{
		OutputMsg("cursor not in any buidling volumes, ignoring.");
		return;
	}

	if (cmd == "")
	{
		OutputMsg("usage: DebugFloor [resetall|showfloor|hidefloor|showallfloors|hideallfloors] [floor#]");
		return;
	}
}

// Show a list of objects that are on my floor
exec function WhatsOnMyFloors(optional int FloorWeCareAbout = 0, optional class<Actor> ActorClass = none)
{
	local XCom3DCursor Cursor;
	local int currentflooridx;
	local Floor CurrentFloor;
	local FloorActorInfo A;
	local XComFloorComponent FloorComponent;
	local int iNumFloorComponents;
	local string strNumFloorComponents;
		
	Cursor = XCom3DCursor(Pawn);

	if (ActorClass == none)
		ActorClass = class'Actor';
	
	if (Cursor == none)
		return;


	OutputMsg("Cursor is on floor #" @ Cursor.IndoorInfo.GetCurrentFloorNumber());

	for (currentflooridx=0; currentflooridx<Cursor.IndoorInfo.CurrentBuildingVolume.Floors.Length; ++currentflooridx)
	{
		CurrentFloor = Cursor.IndoorInfo.CurrentBuildingVolume.Floors[currentflooridx];

		// first floor is floor 1, floor zero doesn't exist.
		// pass in floor zero to dump all floors

		// skip this floor if we don't care about it
		if (FloorWeCareAbout != 0 && FloorWeCareAbout != currentflooridx+1)
			continue;

		OutputMsg("Floor# " @ currentflooridx+1 @ " object list:");

		foreach CurrentFloor.m_aCachedActors(A)
		{
			iNumFloorComponents = 0;

			foreach A.ResidentActor.ComponentList(class'XComFloorComponent', FloorComponent)
			{
				++iNumFloorComponents;
			}

			if (iNumFloorComponents == 0)
				strNumFloorComponents = "";
			else if (iNumFloorComponents == 1)
				strNumFloorComponents = "[floorcomponent present]";
			else
				strNumFloorComponents = "[ERROR: " @ iNumFloorComponents @ " present, should only be ONE!]";
			
			OutputMsg("+ " @ A.ResidentActor.Name @ A.ResidentActor.Tag @ strNumFloorComponents);
		}

		OutputMsg("");
	}
}

// Show a list of floors in the current building volume and their constituent floor volumes
exec function WhatAreMyFloors()
{
	local XCom3DCursor Cursor;
	local int currentfloor, j;
	local XComFloorVolume FloorVolume;
		
	Cursor = XCom3DCursor(Pawn);
	
	if (Cursor == none)
		return;

	OutputMsg("Cursor is on floor #" @ Cursor.IndoorInfo.GetCurrentFloorNumber());

	for (currentfloor=0; currentfloor<Cursor.IndoorInfo.CurrentBuildingVolume.Floors.Length; ++currentfloor)
	{
		for (j=0; j<Cursor.IndoorInfo.CurrentBuildingVolume.Floors[currentfloor].FloorVolumes.Length; ++j)
		{
			FloorVolume = Cursor.IndoorInfo.CurrentBuildingVolume.Floors[currentfloor].FloorVolumes[j];
			
			OutputMsg( "Floor: " @ currentfloor @ " Volume: " @ FloorVolume.Name );
		}
	}
}

function vector GetCursorLoc( bool bValidate = false)
{
	local Vector vLoc;
	vLoc = Pawn.Location;
	if (bValidate)
	{
		vLoc=XComTacticalGRI(WorldInfo.GRI).GetClosestValidLocation(vLoc, XComTacticalController(ViewTarget.Owner).GetActiveUnit());
		if (VSizeSq2D(vLoc)==0)
		{
			vLoc=Pawn.Location;
		}
	}
	return vLoc;
}

exec function RefreshStance()
{
	local XComTacticalController TacticalController;
	local XGUnit ActiveUnit;
	
	TacticalController = XComTacticalController(ViewTarget.Owner);// Pawn is the CURSOR in the Combat game
	if (TacticalController != none && XCom3DCursor(Pawn) != none)
	{
		ActiveUnit = TacticalController.GetActiveUnit();
		ActiveUnit.IdleStateMachine.CheckForStanceUpdate();
	}
}

function TeleportTo(Vector vLoc)
{	
	local XComTacticalController TacticalController;
	local XGUnit ActiveUnit;
	// Pawn is the CURSOR in the Combat game
	TacticalController = XComTacticalController(ViewTarget.Owner);

	if (TacticalController != none && XCom3DCursor(Pawn) != none)
	{	
		ActiveUnit = TacticalController.GetActiveUnit();
		TeleportUnit(ActiveUnit, vLoc);
	}
}

static function CheatTeleport_BuildVisualization(XComGameState VisualizeGameState)
{
	local XComGameState_Unit UnitState;
	local VisualizationActionMetadata BuildTrack;
	local X2Action_UpdateFOW FOWAction;

	foreach VisualizeGameState.IterateByClassType(class'XComGameState_Unit', UnitState)
	{
		BuildTrack.StateObject_NewState = UnitState;
		BuildTrack.StateObject_OldState = UnitState;
		class'X2Action_SyncVisualizer'.static.AddToVisualizationTree(BuildTrack, VisualizeGameState.GetContext());

		FOWAction = X2Action_UpdateFOW( class'X2Action_UpdateFOW'.static.AddToVisualizationTree( BuildTrack, VisualizeGameState.GetContext()) );
		FOWAction.ForceUpdate = true;

		break;
	}
}

function TeleportUnit( XGUnit ActiveUnit, Vector vLoc)
{
	local XComTacticalController TacticalController;
	local XComGameState TeleportGameState;
	local XComGameState_Unit UnitState;
	local TTile UnitTile;

	// Pawn is the CURSOR in the Combat game
	TacticalController = XComTacticalController(ViewTarget.Owner);
	
	if (TacticalController != none && XCom3DCursor(Pawn) != none)
	{	
		TeleportGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState( "Cheat: Teleport Unit" );
		XComGameStateContext_ChangeContainer( TeleportGameState.GetContext() ).BuildVisualizationFn = CheatTeleport_BuildVisualization;

		UnitState = XComGameState_Unit(TeleportGameState.ModifyStateObject(class'XComGameState_Unit', ActiveUnit.ObjectID));
		UnitState.bRequiresVisibilityUpdate = true;
		`XWORLD.GetFloorTileForPosition(vLoc, UnitTile, false);
		UnitState.SetVisibilityLocation(UnitTile);

		`TACTICALRULES.SubmitGameState(TeleportGameState);

		// MHU - Please don't remove this log statement, this is for QA debugging.
		`log (ActiveUnit.Name@"- TeleportTo used");

		// for some reason this will jack up the clients in MP. the unit will never teleport. probably because new actions get generated and set the position -tsmith 
		if(WorldInfo.NetMode == NM_Standalone)
		{
			// HACK, unselect and re-select to reset breadcrumbs
			// FIXED to work with new right thumbstick selection
			// (this is still a hack)
			TacticalController.Shoulder_Right_Press();
			TacticalController.Shoulder_Right_Release();
			TacticalController.Shoulder_Left_Press(); 
			TacticalController.Shoulder_Left_Release();

			TacticalController.Visualizer_SelectUnit(XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(ActiveUnit.ObjectID)));
		}
	}
}

exec function TeleportToCursor()
{	
	local XComTacticalController TacticalController;
		
	// Pawn is the CURSOR in the Combat game
	TacticalController = XComTacticalController(ViewTarget.Owner);
	
	if (TacticalController != none && XCom3DCursor(Pawn) != none)
	{		
		TeleportTo(GetCursorLoc());
	}
}
exec function TTC()
{
	TeleportToCursor();
}
exec function TATC()
{
	TeleportAllToCursor();
}

exec function TeleportAllToCursor()
{
	local XGUnit kUnit;
	local array<int> TeleportedIDs;
	local XComTacticalController TacticalController;
	local Vector vLoc;
		
	// Pawn is the CURSOR in Combat
	TacticalController = XComTacticalController(ViewTarget.Owner);

	kUnit = TacticalController.m_XGPlayer.m_kSquad.GetNextGoodMember(kUnit,,false);
	vLoc = GetCursorLoc();

	while (kUnit != None)
	{ 
		if (TeleportedIDs.Find(kUnit.ObjectID) != -1) // Just in case, break out of loop on repeats.
			break;
		vLoc.Y += 128;
		TeleportUnit(kUnit, vLoc);
		TeleportedIDs.AddItem(kUnit.ObjectID);
		kUnit = TacticalController.m_XGPlayer.m_kSquad.GetNextGoodMember(kUnit,,false);
	}
}

function HelpDESC( string func, string description)
{
	OutputMsg(""@func@"-"@description);
}

event OutputMsg( string msg )
{
    local Console PlayerConsole;
    local LocalPlayer LP;

	LP = LocalPlayer( Outer.Player );
	if( ( LP != none )  && ( LP.ViewportClient.ViewportConsole != none ) )
	{
		PlayerConsole = LocalPlayer( Player ).ViewportClient.ViewportConsole;
		PlayerConsole.OutputText(msg);
	}

    //Output to log just encase..
	`log(msg);
}

exec function ToggleVisDebug()
{
	`XWORLD.bDrawVisibilityChecks = !`XWORLD.bDrawVisibilityChecks;
}

// FIRAXIS Psyonix START
// cjcone@psyonix: consoel command to get useful information about
// actors of a certain class that are currently spawned.
// Usage in console: "PrintDebugInfo Weapon"
exec function PrintDebugInfo( class<Actor> ActorClass )
{
`if (`notdefined(FINAL_RELEASE))
	local int NumActors;
	local Actor CurrentActor;

	if ( ActorClass == none )
		ActorClass = class'Actor';

	`log( "===========================" );
	`log( "Printing debug info for actors of class:"@ActorClass );
	`log( "===========================" );

	foreach WorldInfo.AllActors( ActorClass, CurrentActor )
	{
		`log( "--------------" );
		CurrentActor.LogDebugInfo();
		NumActors++;
	}

	`log( "===========================" );
	`log( "Printed debug info for " $ NumActors $ " actors." );
`endif
}

// wrapper for PrintDebugInfo
exec function PDI( class<Actor> ActorClass )
{
	`log( "PDI!" );
	PrintDebugInfo( ActorClass );
}

exec function ToggleUnitOutline()
{
	`XWORLD.bEnableUnitOutline = !`XWORLD.bEnableUnitOutline;
}

exec function ToggleFOW(optional string strCommand)
{

	local LocalPlayer LP;
	local int i, j;
	local PostProcessChain PPChain;
	local XComFOWEffect FOWEffect;
	local bool bPoint;
	local bool bFilter;
	local bool bHiding;

	if( !class'Engine'.static.IsRetailGame() || class'Engine'.static.IsConsoleAllowed())
	{
		bPoint = false;
		bFilter = false;
		bHiding = false;

		if( strCommand == "hiding" )
		{
			bHiding = true;
		}
		else if( strCommand == "point" )
		{
			bPoint = true;
		}
		else if( strCommand == "filter" )
		{
			bFilter = true;
		}
		else
		{
			`XWORLD.bDebugEnableFOW = !`XWORLD.bDebugEnableFOW;
		}

		LP = LocalPlayer(Player);
		for(i=0;i<LP.PlayerPostProcessChains.Length;i++)
		{
			PPChain = LP.PlayerPostProcessChains[i];
			for(j=0;j<PPChain.Effects.Length;j++)
			{
				FOWEffect = XComFOWEffect(PPChain.Effects[j]);
				if(FOWEffect != none)
				{
					if( bHiding )
					{
						FOWEffect.bHiding = !FOWEffect.bHiding;
					}
					else if( bPoint )
					{
						FOWEffect.bForcePointSampling = !FOWEffect.bForcePointSampling;
					}
					else if( bFilter )
					{
						FOWEffect.bForceNoFiltering = !FOWEffect.bForceNoFiltering;
					}
					else
					{
						FOWEffect.Opacity = `XWORLD.FOWOpacity * ( `XWORLD.bDebugEnableFOW ? 1.0 : 0.0 );
					}
				}
			}
		}
	}
}

exec function SetFOW(bool value)
{

	local LocalPlayer LP;
	local int i, j;
	local PostProcessChain PPChain;
	local XComFOWEffect FOWEffect;
	local float FOWOpacity;

	`XWORLD.bDebugEnableFOW = value;
	FOWOpacity =  `XWORLD.FOWOpacity * (`XWORLD.bDebugEnableFOW ? 1.0 : 0.0);

	LP = LocalPlayer(Player);
	for(i=0;i<LP.PlayerPostProcessChains.Length;i++)
	{
		PPChain = LP.PlayerPostProcessChains[i];
		for(j=0;j<PPChain.Effects.Length;j++)
		{
			FOWEffect = XComFOWEffect(PPChain.Effects[j]);
			if(FOWEffect != none)
			{
				FOWEffect.Opacity = FOWOpacity;

			}
		}
	}
}


exec function TriggerFlash()
{
	local XComWeatherControl WeatherController;
	WeatherController = XComTacticalController(WorldInfo.GetALocalPlayerController()).WeatherControl();

	if( WeatherController != none )
		WeatherController.TriggerFlash();
}

exec function ToggleRain()
{
	local XComWeatherControl WeatherController;
	WeatherController = XComTacticalController(WorldInfo.GetALocalPlayerController()).WeatherControl();

	if( WeatherController != none )
		WeatherController.ToggleRain();
}

exec function RainRateScale (float fScale)
{
	local XComWeatherControl WeatherController;
	WeatherController = XComTacticalController(WorldInfo.GetALocalPlayerController()).WeatherControl();

	if( WeatherController != none )
		WeatherController.SetRainScale( fScale );
}


exec function SetStormIntensity(int iLvl)
{
	local StormIntensity_t Level;
	local XComWeatherControl WeatherController;

	`Log( "Set Storm Intensity : " @ iLvl );

	switch(iLvl)
	{
		case 0:
			Level = NoStorm;
			break;
		case 1:
			Level = DistantGatheringStorm;
			break;
		case 2:
			Level = LightRain;
			break;
		case 3:
			Level = LightStorm;
			break;
		case 4:
			Level = ModerateStorm;
			break;
		case 5:
			Level = SevereStorm;
			break;
		case 6:
		case 7:
			Level = Hurricane;
			break;
		default:
			return;
	}
	
	WeatherController = XComTacticalController(WorldInfo.GetALocalPlayerController()).WeatherControl();

	if( WeatherController != none )
		WeatherController.SetStormIntensity(Level, 0, 0, 0);
}

exec function TimeOfDaySet()
{
	OutputMsg("Time of day currently set:" @ WorldInfo.m_eTimeOfDay);
}

exec function ToggleWet( bool bWet )
{
	class'XComWeatherControl'.static.SetAllAsWet(bWet);
}

// example of native console command (see XComHelpers.cpp for impl) - Moose
native exec function GlobalMemUsage();
native exec function string GetChangelists();

native exec function SingleStep(float fDeltaTime);  // 0 to end singleStep mode
native exec function SingleStepAdvance();

exec function Changelist()
{
    local Console PlayerConsole;
    local LocalPlayer LP;
	local string strChangeLists;

	strChangeLists = GetChangelists();

	LP = LocalPlayer( Outer.Player );
	if( ( LP != none )  && ( LP.ViewportClient.ViewportConsole != none ) )
	{
		PlayerConsole = LocalPlayer( Player ).ViewportClient.ViewportConsole;
		PlayerConsole.OutputText(strChangeLists);
	}

	ClientMessage(strChangeLists);
}

exec function PlayBink(string movieName)
{
	`XENGINE.PlayMovie(false, movieName);
	`XENGINE.WaitForMovie();
	`XENGINE.StopCurrentMovie();
}

exec function WinHQAssault()
{
	RunCommandSet("WinHQAssault");
}

exec function EnablePostProcessEffect(name EffectName, bool bEnable)
{
	`PRES.EnablePostProcessEffect(EffectName, bEnable);
}

exec function SimCombat(optional int AchievementToSimulate = -1)
{
	local X2TacticalGameRuleset TacticalRules;
	local XGBattle_SP Battle;
	local XGPlayer HumanPlayer;
	local XComGameStateHistory History;
	local XComGameState_Unit UnitState;
	local XComGameState NewGameState;
	local XComGameState_BattleData NewBattleData;

	TacticalRules = `TACTICALRULES;
	History = `XCOMHISTORY;
	if( TacticalRules != none )
	{
		bSimulatingCombat = true;
		Battle = XGBattle_SP(`BATTLE);
		HumanPlayer = Battle.GetHumanPlayer();
		NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("SimCombat - auto evac living soldiers");

		if (AchievementToSimulate != -1)
		{
			`XACHIEVEMENT_TRACKER.SimulateAchievementCondition(AchievementToSimulate);
		}

		foreach History.IterateByClassType(class'XComGameState_Unit', UnitState)
		{
			if (UnitState.ControllingPlayer.ObjectID == HumanPlayer.ObjectID && UnitState.IsAlive() && !UnitState.bRemovedFromPlay)
			{
				UnitState.EvacuateUnit(NewGameState);
			}
		}

		//Record that sim combat was used
		NewBattleData = XComGameState_BattleData(History.GetSingleGameStateObjectForClass(class'XComGameState_BattleData'));
		NewBattleData = XComGameState_BattleData(NewGameState.ModifyStateObject(NewBattleData.Class, NewBattleData.ObjectID));
		NewBattleData.bSimCombatUsed = true;

		if (`TUTORIAL != none)
		{
			`TUTORIAL.HandleSubmittedGameStateContext(NewGameState.GetContext());
		}
				
		TacticalRules.SubmitGameState(NewGameState);
				
		bSimulatingCombat = false;
	}
}

exec function TestWinGameAchievement(int AchievementToSimulate)
{
	// DIO DEPRECATED [3/11/2019 dmcdonough]
}

exec function EnableTutorial(bool bDisabled = false)
{
	local XComGameState NewGameState;
	local XComGameState_CampaignSettings CampaignSettings;
	local XComGameStateHistory History;

	History = `XCOMHISTORY;

	CampaignSettings = XComGameState_CampaignSettings(History.GetSingleGameStateObjectForClass(class'XComGameState_CampaignSettings'));

	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Cheat - EnableTutorial");
	CampaignSettings = XComGameState_CampaignSettings(NewGameState.ModifyStateObject(class'XComGameState_CampaignSettings', CampaignSettings.ObjectID));
	CampaignSettings.SetTutorialEnabled(!bDisabled);

	`GAMERULES.SubmitGameState(NewGameState);
}

//------------------------------------------------------------------------------------------------
function XGUnit GetUnitByName( Name unitName )
{
	local XGUnit kUnit;
	foreach WorldInfo.AllActors(class'XGUnit', kUnit)
	{
		if (unitName == kUnit.Name)
			return kUnit;
	}
	return none;
}
//------------------------------------------------------------------------------------------------
exec function ToggleDebugVisibilityToCursor( optional Name unitName='')
{
	local XComTacticalController TacticalController;
	local Vector vLoc;
	local XGUnit kUnit;
	kUnit = GetUnitByName(unitName);

	if( !bDebuggingVisibilityToCursor || (kUnit != None && kUnit != m_kVisDebug))
	{
		bDebuggingVisibilityToCursor = TRUE;

		`XWORLD.bUseSingleThreadedSolver = TRUE;
		`XWORLD.bDrawVisibilityChecks = TRUE;

		m_kVisDebug = kUnit;

		TacticalController = XComTacticalController(ViewTarget.Owner);
		if (m_kVisDebug == none)
			m_kVisDebug = TacticalController.GetActiveUnit();
		
		vLoc = GetCursorLoc();

		if( m_kVisDebug != none )
		{
			`XWORLD.DebugUpdateVisibilityMapForViewer(m_kVisDebug.GetPawn(), vLoc);
		}
		`Log("Visibility debugging to "@kUnit@"enabled.");
	}
	else
	{
		`XWORLD.bUseSingleThreadedSolver = FALSE;
		`XWORLD.bDrawVisibilityChecks = FALSE;
		bDebuggingVisibilityToCursor = FALSE;
		m_kVisDebug = None;
		`Log("Visibility debugging off.");
	}
}

exec function UIListScreens()
{
	XComPlayerController(Outer).Pres.Get2DMovie().PrintCurrentScreens();
}

exec function ToggleDebugMouseTrace()
{
	bDebugMouseTrace = !bDebugMouseTrace;
}

exec function UIToggleVisibility()
{
	if(XComPlayerController(Outer).Pres.Get2DMovie().bIsVisible)
	{
		XComPlayerController(Outer).Pres.Get2DMovie().Hide();
		XComPlayerController(Outer).Pres.Get3DMovie().Hide();
	}
	else
	{
		XComPlayerController(Outer).Pres.Get2DMovie().Show();
		XComPlayerController(Outer).Pres.Get3DMovie().Show();
	}
}

exec function ToggleHardHide(optional bool bHide = true)
{
	local bool ShowUI;
	local XComPathingPawn PathingPawn;
	local XGUnit Unit;

	XComPlayerController(Outer).Pres.Get2DMovie().ToggleHardHide(bHide);
	XComPlayerController(Outer).Pres.Get3DMovie().ToggleHardHide(bHide);

	ShowUI = !XComPlayerController(Outer).Pres.ScreenStack.DebugHardHide;
	class'Engine'.static.GetEngine().GameViewport.DebugSetUISystemEnabled(ShowUI, ShowUI);

	// need to force the pathing pawns to update so they can act on the new
	// debug setting.
	foreach XComPlayerController(Outer).AllActors(class'XComPathingPawn', PathingPawn)
	{
		PathingPawn.SetHidden(bHide);
	}

	foreach XComPlayerController(Outer).AllActors(class'XGUnit', Unit)
	{
		Unit.RefreshUnitDisc();
	}
}

exec function TogglePuckLight()
{
	local XComPathingPawn PathingPawn;

	foreach XComPlayerController(Outer).AllActors(class'XComPathingPawn', PathingPawn)
	{
		PathingPawn.TogglePuckLight();
	}
}

exec function ToggleAnchors()
{
	XComPlayerController(Outer).Pres.Get2DMovie().ToggleAnchors();
}

exec function UIToggleSafearea(bool bForceToHUD = false )
{
	XComPlayerController(Outer).Pres.UIToggleSafearea(bForceToHUD);
}

exec function UIToggleMouseHitDebugging()
{
	XComPlayerController(Outer).ConsoleCommand("UnSuppress DevGfxUI");
	XComPlayerController(Outer).ConsoleCommand("UnSuppress uiflash");
	XComPlayerController(Outer).Pres.Get2DMovie().AS_ToggleMouseHitDebugging();
	XComPlayerController(Outer).Pres.Get3DMovie().AS_ToggleMouseHitDebugging();
}

exec function UIStatus()
{
	XComPlayerController(Outer).Pres.UIStatus();
}

exec function UIToggleMouseCursor()
{
	if( XComPlayerController(Outer).Pres.Get2DMovie() != none )
		XComPlayerController(Outer).Pres.Get2DMovie().ToggleMouseActive();
}

exec function UIToggleShields()
{
	m_bAllowShields = !m_bAllowShields;
}
exec function UIToggleAbortBox()
{
	local StaticMeshActor kActor;

	m_bAllowAbortBox = !m_bAllowAbortBox;  
	
	foreach class'Engine'.static.GetCurrentWorldInfo().AllActors(class'StaticMeshActor', kActor)
	{
		if(kActor.StaticMeshComponent != none && kActor.StaticMeshComponent.StaticMesh.Name != 'Drop_Zone')
		{
			kActor.SetHidden(!m_bAllowAbortBox);
		}
	}
}
exec function UIToggleTether()
{
	local XComWorldData WorldData;

	m_bAllowTether = !m_bAllowTether; 

	WorldData = class'XComWorldData'.static.GetWorldData();
	if( WorldData != none && WorldData.Volume != none )
	{
		class'XComWorldData'.static.GetWorldData().Volume.BorderComponent.SetUIHidden(!m_bAllowTether);
		class'XComWorldData'.static.GetWorldData().Volume.BorderComponentDashing.SetUIHidden(!m_bAllowTether);
	}
}
exec function UIPrintStateStack()
{
	if( XComPlayerController(Outer).Pres.Get2DMovie() != none )
	{
		XComPlayerController(Outer).ConsoleCommand("UnSuppress UICore");
		`log("UI state stack:");
		XComPlayerController(Outer).Pres.Get2DMovie().PrintScreenStack();
		`log("END state stack output.");

		// HELIOS BEGIN
		// Turn off 'uicore' to prevent further log spam
		XComPlayerController(Outer).ConsoleCommand("Suppress UICore");		
		// HELIOS END
	}
}

exec function UIForceClearAllUIToHUD()
{
	`log("------------------------------------");
	`log("UIForceOutToStrategyHUD: Be warned: this is a Big Hammer and may have unintended consequences. Only use if you're stuck in a bad UI state, and need to try to get out to save your game.");
	
	UIPrintStateStack();

	`log("Trying to clear now...");

	XComPlayerController(Outer).Pres.ClearUIToHUD();

	`log("Clear complete. Remaining stacks:");
	UIPrintStateStack();
	`log("------------------------------------");
}

exec function UITooltipsHide()
{
	XComPlayerController(Outer).Pres.m_kTooltipMgr.HideAllTooltips();
}

exec function UITooltipsPrintDebug()
{
	XComPlayerController(Outer).Pres.m_kTooltipMgr.PrintDebugInfo();
}

exec function SetGrenadePrevisTimeStep(float fTimeStep)
{
	local XComPrecomputedPath kPPath;

	foreach WorldInfo.AllActors(class'XComPrecomputedPath', kPPath)
	{
		kPPath.SetEmitterTimeStep(fTimeStep);
	}
}

exec function UITestScreen()
{
	`log("Testing screen...");
	XComPlayerController(Outer).Pres.UITestScreen();
}

exec function DebugCC()
{
	local XComHumanPawn Soldier;

	GetALocalPlayerController().RemoveAllDebugStrings();
	foreach AllActors(class'XComHumanPawn', Soldier)
	{
		Soldier.bDebug = !Soldier.bDebug;
	}
}

exec function DebugPrintMPData()
{
	if(XComGameReplicationInfo(WorldInfo.GRI).m_kMPData != none)
	{
		`log(GetFuncName() @ XComGameReplicationInfo(WorldInfo.GRI).m_kMPData, true, 'XCom_Net');
		XComGameReplicationInfo(WorldInfo.GRI).m_kMPData.DebugPrintData();
	}
}

exec function DebugPrintLastMatchInfo()
{
	`log("***********************************");
	`log("         Last Match Info           ");
	`log(class'XComOnlineEventMgr'.static.TMPLastMatchInfo_ToString(`ONLINEEVENTMGR.m_kMPLastMatchInfo));
	`log("***********************************");
}

exec function DebugPrintLocalPRI()
{
	`log("***********************************");
	`log("         Local PRI                 ");
	`log(XComPlayerReplicationInfo(XComPlayerController(Outer).PlayerReplicationInfo).ToString());
	`log("***********************************");
}

// EventIDFilter - Use an empty string ("") to search for all events.
// DelegateObjectClassType - Use an empty string ("") to search for all delegates, use "EMPTY" to only search for delegates with no class type, otherwise search as specified.
// SourceObjectFilter/PreFilterObject - Any non-negative number will search only for listeners with the specified GameStateId.
// Example: "Search for Everything"
//     DebugPrintEventManager "" "" -1 -1
// Example: "Search for MP Hanging Listeners"
//     DebugPrintEventManager "" "EMPTY" 0 0
exec function DebugPrintEventManager(string EventIDFilter, string DelegateObjectClassType, optional int SourceObjectFilter=-1, optional int PreFilterObject=-1, optional bool bShowPendingEvents)
{
	local X2EventManager EventManager;
	local name EventIDFilterName;
	EventManager = `XEVENTMGR;
	`log(`location @ `ShowVar(EventIDFilter) @ `ShowVar(DelegateObjectClassType) @ `ShowVar(SourceObjectFilter) @ `ShowVar(PreFilterObject) @ `ShowVar(bShowPendingEvents));
	if( !(EventIDFilter ~= "EMPTY") && EventIDFilter != "" )
	{
		EventIDFilterName = name(EventIDFilter);
	}
	`log(EventManager.EventManagerDebugString(EventIDFilterName, DelegateObjectClassType, SourceObjectFilter, PreFilterObject, bShowPendingEvents));
}

///////////////////////////////////
// BEGIN Online Subsystem
///////////////////////////////////

exec function OSSReadFriends()
{
	local LocalPlayer kLP;
	local OnlineSubsystem kOnlineSub;
	local OnlinePlayerInterface kPlayerInterface;

	kLP = LocalPlayer(Player);
	if(kLP != none)
	{
		kOnlineSub = class'GameEngine'.static.GetOnlineSubsystem();
		if(kOnlineSub != none)
		{
			kPlayerInterface = kOnlineSub.PlayerInterface;
			if(kPlayerInterface != none)
			{
				// Register that we are interested in any sign in change for this player
				//PlayerInterface.AddLoginChangeDelegate(OnLoginChange,Player.ControllerId);
				// Set our callback function per player
				kPlayerInterface.AddReadFriendsCompleteDelegate(kLP.ControllerId, OSSOnFriendsReadComplete);
				// Start the async task
				if (kPlayerInterface.ReadFriendsList(kLP.ControllerId) == false)
				{
					`warn("Can't retrieve friends for player ("$kLP.ControllerId$")");
					kPlayerInterface.ClearReadFriendsCompleteDelegate(kLP.ControllerId, OSSOnFriendsReadComplete);
				}
			}
			else
			{
				`warn("OnlineSubsystem does not support the player interface. Can't retrieve friends for player ("$kLP.ControllerId$")");
			}
		}
		else
		{
			`warn("No OnlineSubsystem present. Can't retrieve friends for player ("$kLP.ControllerId$")");
		}
	}

}

/**
 * Handles the notification that the async read of the friends data is done
 *
 * @param bWasSuccessful whether the call completed ok or not
*/
function OSSOnFriendsReadComplete(bool bWasSuccessful)
{
	local LocalPlayer kLP;
	local OnlineSubsystem kOnlineSub;
	local OnlinePlayerInterface kPlayerInterface;
	local OnlineFriend kFriend;

	kLP = LocalPlayer(Player);
	if(kLP != none)
	{
		if (bWasSuccessful == true)
		{
			// Figure out if we have an online subsystem registered
			kOnlineSub = class'GameEngine'.static.GetOnlineSubsystem();
			if (kOnlineSub != None)
			{
				// Grab the player interface to verify the subsystem supports it
				kPlayerInterface = kOnlineSub.PlayerInterface;
				if (kPlayerInterface != None)
				{
					`log("Friends currently online:", true, 'XCom_Online');
					kPlayerInterface.GetFriendsList(kLP.ControllerId, m_arrFriendsList);
					foreach m_arrFriendsList(kFriend)
					{
						if(kFriend.bIsOnline)
						{
							`log("      " $ kFriend.NickName, true, 'XCom_Online');
						}
					}
				}
			}
		}
		else
		{
			`Log("Failed to read friends list", true, 'XCom_Online');
		}

		WorldInfo.Game.OnlineSub.PlayerInterface.ClearReadFriendsCompleteDelegate(kLP.ControllerId, OSSOnFriendsReadComplete);
	}
}


exec function OSSCreatePrivateVersusGame()
{
    local OnlineSubsystem kOSS;
    local OnlineGameSettings kSettings;

	// if we currently have a game we must destroy it because we can't modify certain flags on the current session, we must create a brand new session -tsmith 
	if(class'GameEngine'.static.GetOnlineSubsystem().GameInterface.GetGameSettings('Game') == none)
	{
		kOSS = class'GameEngine'.static.GetOnlineSubsystem();
		kSettings = new class 'OnlineGameSettings';
	
	
		kSettings.bUsesStats = false;
		// NOTE: this just advertise the match to the online service. it does not make the match private/public.
		// see https://udn.epicgames.com/lists/showpost.php?list=unprog3&id=33321&lessthan=&show=20 -tsmith 
		kSettings.bShouldAdvertise = true;
		kSettings.bUsesArbitration = false;
		kSettings.NumPublicConnections = 0;
		// this is what actually makes the game private/invite only -tsmith 
		kSettings.NumPrivateConnections = 2;
		kSettings.bAllowJoinInProgress = false; 
	
		kOSS.GameInterface.AddCreateOnlineGameCompleteDelegate(OSSOnCreatePrivateVersusGameComplete);
		if(!kOSS.GameInterface.CreateOnlineGame( `ONLINEEVENTMGR.LocalUserIndex, 'Game', kSettings ))
		{
			`warn(GetFuncName() $ ": Failed to start async task CreateOnlineGame", true, 'XCom_Online');
			kOSS.GameInterface.ClearCreateOnlineGameCompleteDelegate(OSSOnCreatePrivateVersusGameComplete);
		}
	}
	else
	{
		`log(GetFuncName() $ ": Session 'Game' already exists, destroying and will create new one", true, 'XCom_Online'); 
		class'GameEngine'.static.GetOnlineSubsystem().GameInterface.AddDestroyOnlineGameCompleteDelegate(OnDestroyOnlineGameCompleteCreatePrivateVersusGame);
		//<workshop> CONSOLE_OSS JPS 2015/10/30
		//WAS:
		//if(!class'GameEngine'.static.GetOnlineSubsystem().GameInterface.DestroyOnlineGame('Game'))
		if(!class'GameEngine'.static.GetOnlineSubsystem().GameInterface.DestroyOnlineGame(LocalPlayer(m_kPlayerControllerOwner.Player).ControllerId, 'Game'))
		//</workshop>
		{
			`warn(GetFuncName() $ ": Failed to start async task DestroyOnlineGame");
			class'GameEngine'.static.GetOnlineSubsystem().GameInterface.ClearDestroyOnlineGameCompleteDelegate(OnDestroyOnlineGameCompleteCreatePrivateVersusGame);
		}
	}
}

/** Callback for when the game is finish being created. */
function OSSOnCreatePrivateVersusGameComplete(name SessionName,bool bWasSuccessful)
{
	local OnlineGameSettings kGameSettings;

	class'GameEngine'.static.GetOnlineSubsystem().GameInterface.ClearCreateOnlineGameCompleteDelegate(OSSOnCreatePrivateVersusGameComplete);
	if(bWasSuccessful)
	{
		`log("Successfully created online game: Session=" $ SessionName $ ", Server=" @ WorldInfo.GRI.ServerName, true, 'XCom_Online');
		kGameSettings = class'GameEngine'.static.GetOnlineSubsystem().GameInterface.GetGameSettings(SessionName);
		class'OnlineSubsystem'.static.DumpGameSettings(kGameSettings);
	}
	else
	{
		`log("Failed to create online game: Session=" $ SessionName, true, 'XCom_Online');
	}
}

function OnDestroyOnlineGameCompleteCreatePrivateVersusGame(name SessionName,bool bWasSuccessful)
{
	class'GameEngine'.static.GetOnlineSubsystem().GameInterface.ClearDestroyOnlineGameCompleteDelegate(OnDestroyOnlineGameCompleteCreatePrivateVersusGame);
	OSSCreatePrivateVersusGame();
}

exec function OSSCreateLANVersusGame()
{
	local OnlineGameSettings kSettings;

	// if we currently have a game we must destroy it because we can't modify certain flags on the current session, we must create a brand new session -tsmith 
	if(class'GameEngine'.static.GetOnlineSubsystem().GameInterface.GetGameSettings('Game') == none)
	{
		kSettings = new class 'OnlineGameSettings';
	
		kSettings.bUsesStats = false;
		// NOTE: this just advertise the match to the online service. it does not make the match private/public.
		// see https://udn.epicgames.com/lists/showpost.php?list=unprog3&id=33321&lessthan=&show=20 -tsmith 
		kSettings.bShouldAdvertise = true;
		kSettings.bUsesArbitration = false;
		kSettings.NumPublicConnections = 2;
		// this is what actually makes the game private/invite only -tsmith 
		kSettings.NumPrivateConnections = 2;
		kSettings.bAllowJoinInProgress = false; 
		kSettings.bIsLanMatch = true;
	
		class'GameEngine'.static.GetOnlineSubsystem().GameInterface.AddCreateOnlineGameCompleteDelegate(OSSOnCreateLANVersusGameComplete);
		if(!class'GameEngine'.static.GetOnlineSubsystem().GameInterface.CreateOnlineGame( `ONLINEEVENTMGR.LocalUserIndex, 'Game', kSettings ))
		{
			`warn(GetFuncName() $ ": Failed to start async task CreateOnlineGame", true, 'XCom_Online');
			class'GameEngine'.static.GetOnlineSubsystem().GameInterface.ClearCreateOnlineGameCompleteDelegate(OSSOnCreateLANVersusGameComplete);
		}
	
	}
	else
	{
		`log(GetFuncName() $ ": Session 'Game' already exists, destroying and will create new one", true, 'XCom_Online'); 
		class'GameEngine'.static.GetOnlineSubsystem().GameInterface.AddDestroyOnlineGameCompleteDelegate(OnDestroyOnlineGameCompleteCreateLANGame);
		//<workshop> CONSOLE_OSS JPS 2015/10/30
		//WAS:
		//if(!class'GameEngine'.static.GetOnlineSubsystem().GameInterface.DestroyOnlineGame('Game'))
		if(!class'GameEngine'.static.GetOnlineSubsystem().GameInterface.DestroyOnlineGame(LocalPlayer(m_kPlayerControllerOwner.Player).ControllerId, 'Game'))
		//</workshop>
		{
			`warn(GetFuncName() $ ": Failed to start async task DestroyOnlineGame");
			class'GameEngine'.static.GetOnlineSubsystem().GameInterface.ClearDestroyOnlineGameCompleteDelegate(OnDestroyOnlineGameCompleteCreateLANGame);
		}
	}

}

function OSSOnCreateLANVersusGameComplete(name SessionName,bool bWasSuccessful)
{
	local OnlineGameSettings kGameSettings;

	if(bWasSuccessful)
	{
		`log(GetFuncName() $ ": Successfully created online game: Session=" $ SessionName $ ", Server=" @ WorldInfo.GRI.ServerName, true, 'XCom_Online');
		kGameSettings = class'GameEngine'.static.GetOnlineSubsystem().GameInterface.GetGameSettings(SessionName);
		class'OnlineSubsystem'.static.DumpGameSettings(kGameSettings);
	}
	else
	{
		`log(GetFuncName() $ ": Failed to create online game: Session=" $ SessionName, true, 'XCom_Online');
	}

	class'GameEngine'.static.GetOnlineSubsystem().GameInterface.ClearCreateOnlineGameCompleteDelegate(OSSOnCreateLANVersusGameComplete);
}

function OnDestroyOnlineGameCompleteCreateLANGame(name SessionName,bool bWasSuccessful)
{
	class'GameEngine'.static.GetOnlineSubsystem().GameInterface.ClearDestroyOnlineGameCompleteDelegate(OnDestroyOnlineGameCompleteCreateLANGame);
	OSSCreateLANVersusGame();
}
	

exec function OSSInviteFriendToGame(string strFriendName)
{
	local LocalPlayer kLP;
	local OnlineSubsystem kOnlineSub;
	local OnlinePlayerInterface kPlayerInterface;
	local OnlineFriend kFriend;
	local bool bFoundOnlineFriend;

	// TODO: make sure we have created a game -tsmith 
	if(m_arrFriendsList.Length != 0)
	{
		foreach m_arrFriendsList(kFriend)
		{
			if(kFriend.NickName == strFriendName)
			{
				`log(GetFuncName() $ ": Found friend '" $ strFriendName $ "'" @ `ShowVar(kFriend.bIsOnline) @ `ShowVar(kFriend.bIsPlayingThisGame), true, 'XCom_Online');
				if(kFriend.bIsOnline && kFriend.bIsPlayingThisGame)
				{
					bFoundOnlineFriend = true;
					break;
				}
			}
		}

		if(bFoundOnlineFriend)
		{
			kLP = LocalPlayer(Player);
			if(kLP != none)
			{
				kOnlineSub = class'GameEngine'.static.GetOnlineSubsystem();
				if(kOnlineSub != none)
				{
					kPlayerInterface = kOnlineSub.PlayerInterface;
					if(kPlayerInterface != none)
					{
						`log(GetFuncName() $ ": Calling SendGameInviteToFriend" @ `ShowVar(kLP.ControllerId) @ `ShowVar(kFriend.NickName) /*@ `ShowVar(kFriend.UniqueId.Uid)*/, true, 'XCom_Online');
						if(kPlayerInterface.SendGameInviteToFriend(kLP.ControllerId, kFriend.UniqueId, "Yo sucka! Come play with me!"))
						{
							`log(GetFuncName() $ ": Game invite successfully sent", true, 'XCom_Online');
						}
						else
						{
							`log(GetFuncName() $ ": Game invite FAILED!", true, 'XCom_Online');
						}
					}
				}
			}
		}
		else
		{
			`log(GetFuncName() $ ": Friend '" $ strFriendName $ "' not found", true, 'XCom_Online');
		}
	}
	else
	{
		`log(GetFuncName() $ ": Friends list not populated yet, call OSSReadFriends first", true, 'XCom_Online');
	}
	
}

exec function OSSJoinInviteGame(string strFriendName)
{
	local LocalPlayer kLP;
	local OnlineSubsystem kOnlineSub;
	local OnlinePlayerInterface kPlayerInterface;
	local OnlineFriend kFriend;
	local UniqueNetId kZeroID;
	local bool bFoundOnlineFriend;

	// TODO: teardown any game we have created -tsmith 
	if(m_arrFriendsList.Length != 0)
	{
		foreach m_arrFriendsList(kFriend)
		{
			if(kFriend.NickName == strFriendName)
			{
				`log(GetFuncName() $ ": Found friend '" $ strFriendName $ "'" @ `ShowVar(kFriend.bIsOnline) @ `ShowVar(kFriend.bIsPlayingThisGame) @ `ShowVar(kFriend.bHasInvitedYou), true, 'XCom_Online');
				if(kFriend.UniqueId != kZeroID && kFriend.bIsOnline && kFriend.bIsPlayingThisGame && kFriend.bHasInvitedYou)
				{
					bFoundOnlineFriend = true;
					break;
				}
			}
		}

		if(bFoundOnlineFriend)
		{
			kLP = LocalPlayer(Player);
			if(kLP != none)
			{
				kOnlineSub = class'GameEngine'.static.GetOnlineSubsystem();
				if(kOnlineSub != none)
				{
					kPlayerInterface = kOnlineSub.PlayerInterface;
					if(kPlayerInterface != none)
					{
						`log(GetFuncName() $ ": Calling JoinFriendGame" @ `ShowVar(kLP.ControllerId) @ `ShowVar(kFriend.NickName), true, 'XCom_Online');
						// TODO: set delegates -tsmith 
						if(kPlayerInterface.JoinFriendGame(kLP.ControllerId, kFriend.UniqueId))
						{
							`log(GetFuncName() $ ": JoinFriendGame async call started", true, 'XCom_Online');
						}
						else
						{
							`log(GetFuncName() $ ": JoinFriendGame async call FAILED!", true, 'XCom_Online');
						}
					}
				}
			}
		}
		else
		{
			`log(GetFuncName() $ ": Friend '" $ strFriendName $ "' not found", true, 'XCom_Online');
		}
	}
	else
	{
		`log(GetFuncName() $ ": Friends list not populated yet, call OSSReadFriends first", true, 'XCom_Online');
	}
	
}

delegate OSSFindDelegate();

exec function OSSFind()
{
	`log(self $ "::" $ GetFuncName(), true, 'XCom_Online');

	if(OSSFindDelegate != none)
	{
		OSSFindDelegate();
	}
}

delegate OSSJoinDelegate(int iGameIndex);

exec function OSSJoin(int iGameIndex)
{
	`log(self $ "::" $ GetFuncName(), true, 'XCom_Online');
	
	if(OSSJoinDelegate != none)
	{
		OSSJoinDelegate(iGameIndex);
	}
}

delegate OSSInfoDelegate();

exec function OSSInfo()
{
	`log(self $ "::" $ GetFuncName(), true, 'XCom_Online');

	if(OSSInfoDelegate != none)
	{
		OSSInfoDelegate();
	}
}

exec function OSSGetGameSettings(string strSessionName)
{
	local OnlineGameSettings kGameSettings;

	kGameSettings = class'GameEngine'.static.GetOnlineSubsystem().GameInterface.GetGameSettings(name(strSessionName));
	if(kGameSettings != none)
	{
		`log(GetFuncName() $ ": Dumping online game settings", true, 'XCom_Online');
		class'OnlineSubsystem'.static.DumpGameSettings(kGameSettings);
	}
	else
	{
		`log(GetFuncName() $ ": No online game settings found for session named '" $ strSessionName $ "'", true, 'XCom_Online');
	}

}

exec function OSSUpdateGameSettingsToPrivate()
{
	local OnlineGameSettings kGameSettings;

	kGameSettings = class'GameEngine'.static.GetOnlineSubsystem().GameInterface.GetGameSettings('Game');
	if(kGameSettings != none)
	{
		`log(GetFuncName() $ ": Updating online game settings", true, 'XCom_Online');

		kGameSettings.NumPrivateConnections = 2;
		kGameSettings.NumPublicConnections = 0;
		class'GameEngine'.static.GetOnlineSubsystem().GameInterface.AddUpdateOnlineGameCompleteDelegate(OnUpdateOnlineSettingsToPrivateComplete);
		// NOTE: this function is not implemented in the PCGameInterface so it will always fail -tsmith 
		//<workshop> CONSOLE_OSS JPS 2015/10/30
		//WAS:
		//if(!class'GameEngine'.static.GetOnlineSubsystem().GameInterface.UpdateOnlineGame('Game', kGameSettings, true))
		if(!class'GameEngine'.static.GetOnlineSubsystem().GameInterface.UpdateOnlineGame(LocalPlayer(m_kPlayerControllerOwner.Player).ControllerId, 'Game', kGameSettings, true))
		//</workshop>
		{
			`log(GetFuncName() $ ": Failed to start async task UpdateOnlineGame", true, 'XCom_Online');
			class'GameEngine'.static.GetOnlineSubsystem().GameInterface.ClearUpdateOnlineGameCompleteDelegate(OnUpdateOnlineSettingsToPrivateComplete);
		}
	}
}

exec function OSSPrintLoginStatus()
{
	local OnlinePlayerInterface PlayerInterface;
	local XComOnlineEventMgr OnlineEventMananger;
	local ELoginStatus LoginStatus;
	local string strLoginStatus;


	strLoginStatus = "No Online Subsystem Found";
	if(OnlineSub != none)
	{
		PlayerInterface = OnlineSub.PlayerInterface;
		if(PlayerInterface != none)
		{
			LoginStatus = ELoginStatus(PlayerInterface.GetLoginStatus(LocalPlayer(Outer.Player).ControllerId));
			strLoginStatus = "" $ LoginStatus;
			strLoginStatus $= ", IsLocalLogin=" $PlayerInterface.IsLocalLogin(LocalPlayer(Outer.Player).ControllerId);
			OnlineEventMananger = `ONLINEEVENTMGR;
			if(OnlineEventMananger != none)
			{
				LoginStatus = OnlineEventMananger.LoginStatus;
				strLoginStatus $= ", OnlineEventMgr.LoginStatus=" $ LoginStatus;
			}
			//<workshop> OSS TODO ytt Jan-6-2016
			//DEL:
			//if(OnlineSubsystemSteamworks(OnlineSub) != none)
			//{
			//	LoginStatus = OnlineSubsystemSteamworks(OnlineSub).LoggedInStatus;
			//	strLoginStatus $= ", Steamworks cached LoggedInStatus=" $ LoginStatus;
			//}
			//</workshop>
		}
	}

	`log("LoginStatus=" $ strLoginStatus,, 'XCom_Online');
}

/**
 * Delegate fired when a update request has completed
 *
 * @param SessionName the name of the session this callback is for
 * @param bWasSuccessful true if the async action completed without error, false if there was an error
 */
function OnUpdateOnlineSettingsToPrivateComplete(name SessionName, bool bWasSuccessful)
{
	local OnlineGameSettings kGameSettings;

	kGameSettings = class'GameEngine'.static.GetOnlineSubsystem().GameInterface.GetGameSettings(SessionName);
	if(bWasSuccessful)
	{
		`log(GetFuncName() $ ": Updating online game settings SUCCESS", true, 'XCom_Online');
	}
	else
	{
		`log(GetFuncName() $ ": Updating online game settings FAIL", true, 'XCom_Online');
	}

	class'OnlineSubsystem'.static.DumpGameSettings(kGameSettings);
	class'GameEngine'.static.GetOnlineSubsystem().GameInterface.ClearUpdateOnlineGameCompleteDelegate(OnUpdateOnlineSettingsToPrivateComplete);
}

exec function OSSUpdateGameSettingsToPublic()
{
	local OnlineGameSettings kGameSettings;

	kGameSettings = class'GameEngine'.static.GetOnlineSubsystem().GameInterface.GetGameSettings('Game');
	//<workshop> CONSOLE_MP JPS 2016/03/07
	//INS:
	if (kGameSettings == none)
	{
		kGameSettings = class'GameEngine'.static.GetOnlineSubsystem().GameInterface.GetGameSettings('Lobby');
	}
	//</workshop>
	if(kGameSettings != none)
	{
		`log(GetFuncName() $ ": Updating online game settings", true, 'XCom_Online');

		kGameSettings.NumPrivateConnections = 0;
		kGameSettings.NumPublicConnections = 2;
		class'GameEngine'.static.GetOnlineSubsystem().GameInterface.AddUpdateOnlineGameCompleteDelegate(OnUpdateOnlineSettingsToPublicComplete);
		// NOTE: this function is not implemented in the PCGameInterface so it will always fail -tsmith 
		//<workshop> CONSOLE_OSS JPS 2015/10/30
		//WAS:
		//if(!class'GameEngine'.static.GetOnlineSubsystem().GameInterface.UpdateOnlineGame('Game', kGameSettings, true))
		if(!class'GameEngine'.static.GetOnlineSubsystem().GameInterface.UpdateOnlineGame(LocalPlayer(m_kPlayerControllerOwner.Player).ControllerId, 'Game', kGameSettings, true))
		//</workshop>
		{
			`log(GetFuncName() $ ": Failed to start async task UpdateOnlineGame", true, 'XCom_Online');
			class'GameEngine'.static.GetOnlineSubsystem().GameInterface.ClearUpdateOnlineGameCompleteDelegate(OnUpdateOnlineSettingsToPublicComplete);
		}
	}
}

/**
 * Delegate fired when a update request has completed
 *
 * @param SessionName the name of the session this callback is for
 * @param bWasSuccessful true if the async action completed without error, false if there was an error
 */
function OnUpdateOnlineSettingsToPublicComplete(name SessionName, bool bWasSuccessful)
{
	local OnlineGameSettings kGameSettings;

	kGameSettings = class'GameEngine'.static.GetOnlineSubsystem().GameInterface.GetGameSettings(SessionName);
	if(bWasSuccessful)
	{
		`log(GetFuncName() $ ": Updating online game settings SUCCESS", true, 'XCom_Online');
	}
	else
	{
		`log(GetFuncName() $ ": Updating online game settings FAIL", true, 'XCom_Online');
	}

	class'OnlineSubsystem'.static.DumpGameSettings(kGameSettings);
	class'GameEngine'.static.GetOnlineSubsystem().GameInterface.ClearUpdateOnlineGameCompleteDelegate(OnUpdateOnlineSettingsToPublicComplete);
}

exec function StatsTestWrite(int iTestInt, int iTestRating)
{
	local XComOnlineStatsWriteTest kStatsWrite;

	`log(self $ "::" $ GetFuncName() @ `ShowVar(iTestInt) @ `ShowVar(iTestRating), true, 'XCom_Online');

	kStatsWrite = new class'XComOnlineStatsWriteTest';
	kStatsWrite.InitOnlineStatsWriteTest(iTestInt, iTestRating);
	OnlineSub.StatsInterface.WriteOnlineStats(PlayerReplicationInfo.SessionName, PlayerReplicationInfo.UniqueId, kStatsWrite);
	OnlineSub.StatsInterface.FlushOnlineStats(PlayerReplicationInfo.SessionName);
}

exec function StatsTestRead()
{
//<workshop> OSS FIX THIS
	//local array<UniqueNetId> arrUniqueNetIds;

	//`log(self $ "::" $ GetFuncName(), true, 'XCom_Online');

	//if(m_kStatsRead == none)
	//{
	//	m_kStatsRead = new class'XComOnlineStatsReadTest';
	//	arrUniqueNetIds.AddItem(PlayerReplicationInfo.UniqueId);
	//	OnlineSub.StatsInterface.AddReadOnlineStatsCompleteDelegate(StatsTestOnReadComplete);
	//	if(!OnlineSub.StatsInterface.ReadOnlineStats(arrUniqueNetIds, m_kStatsRead))
	//	{
	//		`warn(self $ "::" $ GetFuncName() @ "Failed to start async task ReadOnlineStats");
	//		OnlineSub.StatsInterface.ClearReadOnlineStatsCompleteDelegate(StatsTestOnReadComplete);
	//	}
	//}
}

private function StatsTestOnReadComplete(bool bWasSuccessful)
{
	`log(self $ "::" $ GetFuncName() @ `ShowVar(bWasSuccessful), true, 'XCom_Online');
	if(bWasSuccessful)
	{
		`log(self $ "::" $ GetFuncName() @ m_kStatsRead.ToString_ForPlayer(PlayerReplicationInfo.PlayerName, PlayerReplicationInfo.UniqueId), true, 'XCom_Online');
	}

	OnlineSub.StatsInterface.ClearReadOnlineStatsCompleteDelegate(StatsTestOnReadComplete);
	OnlineSub.StatsInterface.FreeStats(m_kStatsRead);
	m_kStatsRead = none;
}

`if(`notdefined(FINAL_RELEASE))
exec function TestUnlockAchievement(int AchievementType)
{
	`ONLINEEVENTMGR.UnlockAchievement(EAchievementType(AchievementType));
}

exec function StatsResetStats(bool bResetAchievements)
{
	`log(self $ "::" $ GetFuncName() @ `ShowVar(bResetAchievements) @ "Success=" $ OnlineSub.StatsInterface.ResetStats(bResetAchievements), true, 'XCom_Online');
}

exec function StatsClearDeathmatchRanked()
{
	local XComOnlineStatsWriteDeathmatchClearAllStats kStatsWrite;

	`log(self $ "::" $ GetFuncName() @ `ShowVar(PlayerReplicationInfo.SessionName) @ "PlayerUniqueNetId=" $ class'OnlineSubsystem'.static.UniqueNetIdToString(PlayerReplicationInfo.UniqueId), true, 'XCom_Online');
	kStatsWrite = new class'XComOnlineStatsWriteDeathmatchClearAllStats';
	OnlineSub.StatsInterface.WriteOnlineStats(PlayerReplicationInfo.SessionName, PlayerReplicationInfo.UniqueId, kStatsWrite);
	OnlineSub.StatsInterface.FlushOnlineStats(PlayerReplicationInfo.SessionName);
}

exec function StatsFlush()
{
	`log(`location, true, 'XCom_Online');
	OnlineSub.StatsInterface.FlushOnlineStats(PlayerReplicationInfo.SessionName);
}

exec function StatsWriteDeathmatchRanked(int SkillRating, int MatchesWon, optional int MatchesLost=0, optional int Disconnects=0, optional int MatchStarted=0)
{
	local XComOnlineStatsWriteDeathmatchRanked kStatsWrite;

	`log(`location @ `ShowVar(SkillRating) @ `ShowVar(MatchesWon) @ `ShowVar(MatchesLost) @ `ShowVar(Disconnects) @ `ShowVar(MatchStarted), true, 'XCom_Online');

	kStatsWrite = new class'XComOnlineStatsWriteDeathmatchRanked';
	kStatsWrite.UpdateStats(MatchStarted, SkillRating, MatchesWon, MatchesLost, Disconnects);
	OnlineSub.StatsInterface.WriteOnlineStats(PlayerReplicationInfo.SessionName, PlayerReplicationInfo.UniqueId, kStatsWrite);
	OnlineSub.StatsInterface.FlushOnlineStats(PlayerReplicationInfo.SessionName);
}

exec function StatsReadDeathmatchRanked()
{
//<workshop> OSS FIX THIS
	//local array<UniqueNetId> arrUniqueNetIds;

	//`log(`location, true, 'XCom_Online');

	//if(m_kStatsRead == none)
	//{
	//	m_kStatsRead = new class'XComOnlineStatsReadDeathmatchRanked';
	//	arrUniqueNetIds.AddItem(PlayerReplicationInfo.UniqueId);
	//	`log(`location @ class'OnlineSubsystem'.static.UniqueNetIdToString(PlayerReplicationInfo.UniqueId),,'XCom_Online');
	//
	//	OnlineSub.StatsInterface.AddReadOnlineStatsCompleteDelegate(StatsOnReadDeathmatchRankedComplete);
	//	if(!OnlineSub.StatsInterface.ReadOnlineStats(arrUniqueNetIds, m_kStatsRead))
	//	{
	//		`warn(`location @ "Failed to start async task ReadOnlineStats");
	//		OnlineSub.StatsInterface.ClearReadOnlineStatsCompleteDelegate(StatsOnReadDeathmatchRankedComplete);
	//	}
	//}
}

private function StatsOnReadDeathmatchRankedComplete(bool bWasSuccessful)
{
	`log(`location @ `ShowVar(bWasSuccessful), true, 'XCom_Online');
	if(bWasSuccessful)
	{
		`log(`location @ m_kStatsRead.ToString_ForPlayer(PlayerReplicationInfo.PlayerName, PlayerReplicationInfo.UniqueId), true, 'XCom_Online');
	}

	OnlineSub.StatsInterface.ClearReadOnlineStatsCompleteDelegate(StatsOnReadDeathmatchRankedComplete);
	OnlineSub.StatsInterface.FreeStats(m_kStatsRead);
	m_kStatsRead = none;
}
`endif

///////////////////////////////////
// END Online Subsystem
///////////////////////////////////

exec function X2ToggleSpawningPrereqs()
{
	bDisableSpawningPrereqs = !bDisableSpawningPrereqs;
}

// Marketing mode
native function bool IsInMarketingMode();
native function SetMarketingMode(bool bEnable);
exec native function SetOverallTextureStreamingBias(float Bias=1.0f);

exec native function FlushLogs();

exec function marketing()
{
	`log("MARKETING MODE ENGAGE");
	SetMarketingMode(true);
	SetOverallTextureStreamingBias(2.0);
	DisableNarrative();
}

exec function marketingAltr()
{
	`log("MARKETING-Alt MODE ENGAGE");
	SetMarketingMode(true);
	SetOverallTextureStreamingBias(2.0);
}

exec function PingMCP()
{
	`log(self $ "::" $ GetFuncName(), true, 'XCom_Net');
	if( `XENGINE.MCPManager != none )
	{
		if(`XENGINE.MCPManager.PingMCP(OnPingMCPComplete))
		{
			`log("      started async task PingMCP", true, 'XCom_Net');
		}
		else
		{
			`warn("      failed to start async task PingMCP");
		}
	}
	else
	{
		`warn("      MCP manager does not exist");
	}
}

function OnPingMCPComplete(bool bWasSuccessful, EOnlineEventType EventType)
{
	`log(self $ "::" $ GetFuncName() @ `ShowVar(bWasSuccessful) @ `ShowVar(EventType), true, 'XCom_Net');
	`XENGINE.MCPManager.OnEventCompleted = none;
}

native exec function SetSeedOverride( int iSeed );

// Terribly Inefficient! ONLY FOR TESTING!
private function GetSkeletalMeshCompenents(out array<SkeletalMeshComponent> SkelMeshComponents)
{
	local Actor HQActor;
	local SkeletalMeshComponent SkelMeshComp;

	foreach AllActors(class'Actor', HQActor)
	{
		foreach HQActor.AllOwnedComponents(class'SkeletalMeshComponent', SkelMeshComp)
		{
			SkelMeshComponents.AddItem(SkelMeshComp);
		}
	}
}

exec function DisableEmitterTicks()
{
	local Emitter EmitterActor;
	foreach AllActors(class'Emitter', EmitterActor)
	{
		EmitterActor.SetTickIsDisabled(true);
	}
}

//==============================================================================
//		ANIM LOD TESTING CODE 
//==============================================================================

exec function SetAnimLODRate(int FrameRate)
{
	local SkeletalMeshComponent SkelMeshComp;
	local array<SkeletalMeshComponent> SkelMeshComponents;

	`log("Setting Animation LOD Frame Rate to " $ FrameRate);

	GetSkeletalMeshCompenents(SkelMeshComponents);
	foreach SkelMeshComponents(SkelMeshComp)
	{
		SkelMeshComp.AnimationLODFrameRate = FrameRate;
	}
}

exec function SetAnimLODDist(float DistFactor)
{
	local SkeletalMeshComponent SkelMeshComp;
	local array<SkeletalMeshComponent> SkelMeshComponents;

	`log("Setting Animation LOD Distance Factor to " $ DistFactor);

	GetSkeletalMeshCompenents(SkelMeshComponents);
	foreach SkelMeshComponents(SkelMeshComp)
	{
		SkelMeshComp.AnimationLODDistanceFactor = DistFactor;
	}
}

exec function TickAnimNodesWhenNotRendered(bool bValue)
{
	local SkeletalMeshComponent SkelMeshComp;
	local array<SkeletalMeshComponent> SkelMeshComponents;

	`log("Setting bTickAnimNodesWhenNotRendered to " $ bValue);

	GetSkeletalMeshCompenents(SkelMeshComponents);
	foreach SkelMeshComponents(SkelMeshComp)
	{
		SkelMeshComp.bTickAnimNodesWhenNotRendered = bValue;
	}
}

exec function UpdateSkelWhenNotRendered(bool bValue)
{
	local SkeletalMeshComponent SkelMeshComp;
	local array<SkeletalMeshComponent> SkelMeshComponents;

	`log("Setting bUpdateSkelWhenNotRendered to " $ bValue);

	GetSkeletalMeshCompenents(SkelMeshComponents);
	foreach SkelMeshComponents(SkelMeshComp)
	{
		SkelMeshComp.bUpdateSkelWhenNotRendered = bValue;
	}
}

exec function SkelMeshesIgnoreControllersWhenNotRendered(bool bValue)
{
	local SkeletalMeshComponent SkelMeshComp;
	local array<SkeletalMeshComponent> SkelMeshComponents;

	`log("Setting bIgnoreControllersWhenNotRendered to " $ bValue);

	GetSkeletalMeshCompenents(SkelMeshComponents);
	foreach SkelMeshComponents(SkelMeshComp)
	{
		SkelMeshComp.bIgnoreControllersWhenNotRendered = bValue;
	}
}

exec function AllowSetAnimPositionWhenNotRendered(bool bValue) 
{
	local SkeletalMeshComponent SkelMeshComp;
	local array<SkeletalMeshComponent> SkelMeshComponents;

	`log("Setting bAllowSetAnimPositionWhenNotRendered to " $ bValue);

	GetSkeletalMeshCompenents(SkelMeshComponents);
	foreach SkelMeshComponents(SkelMeshComp)
	{
		SkelMeshComp.bAllowSetAnimPositionWhenNotRendered = bValue;
	}
}
//==============================================================================

exec function GetProcLevelSeed()
{
	`log("Proc Level Seed:"@(`BATTLE.iLevelSeed));
}

exec function SetProcLevelSeed(int iSeed)
{
	`log("Setting Proc Level Seed:"@iSeed);
	class'Engine'.static.GetEngine().SetRandomSeeds(iSeed);
}

exec function OutputParcelInfo(optional bool DarkLines = false)
{
	`PARCELMGR.OutputParcelInfo(DarkLines);

	GetProcLevelSeed();

	FlushLogs();
}

exec function ForceMission(int iIndex)
{
	`log("Forcing Mission:"@iIndex);
	if (iIndex == -1)
	{
		`TACTICALMISSIONMGR.ForceMission.sType = "";
	}
	else
	{
		`TACTICALMISSIONMGR.ForceMission = `TACTICALMISSIONMGR.arrMissions[iIndex];
	}
}

function OnGameArchetypeLoaded(Object LoadedArchetype)
{
	`log(GetFuncName() @ LoadedArchetype,,'XCom_Content');
}

exec function LoadGameArchetype(string ArchetypeName, bool bAsync=true)
{
	`CONTENT.RequestGameArchetype(ArchetypeName, self, OnGameArchetypeLoaded, bAsync);
}

exec function X2DebugVisibilitySelected()
{	
	local XGUnit SelectedUnit;
	local int Index;

	local vector CursorLocation;
	local float Distance;
	local float BestDistance;
	local int CursorObjectID;
	local XComGameState_Unit ItUnit;
	
	local X2GameRulesetVisibilityManager VisibilityMgr;
	local GameRulesCache_VisibilityInfo OutVisibilityInfo;

	CursorLocation = GetCursorLoc();
	BestDistance = 10000000.0f;
	foreach `XCOMHISTORY.IterateByClassType(class'XComGameState_Unit', ItUnit)
	{
		Distance = VSize(XGUnit(ItUnit.GetVisualizer()).Location - CursorLocation);
		if( Distance < BestDistance )
		{
			CursorObjectID = ItUnit.ObjectID;
			BestDistance = Distance;
		}
	}

	SelectedUnit = XComTacticalController(ViewTarget.Owner).GetActiveUnit();

	VisibilityMgr = `TACTICALRULES.VisibilityMgr;

	if( SelectedUnit.ObjectID > 0 && CursorObjectID > 0 )
	{
		VisibilityMgr.GetVisibilityInfo(SelectedUnit.ObjectID, CursorObjectID, OutVisibilityInfo);
		`log("Visibility info from"@SelectedUnit.ObjectID@"to"@CursorObjectID);
		`log("bClearLOS             :"@OutVisibilityInfo.bClearLOS);
		`log("bVisibleBasic         :"@OutVisibilityInfo.bVisibleBasic);
		`log("bVisibleFromDefault   :"@OutVisibilityInfo.bVisibleFromDefault);
		`log("bVisibleGameplay      :"@OutVisibilityInfo.bVisibleGameplay);
		for( Index = 0; Index < OutVisibilityInfo.GameplayVisibleTags.Length; ++Index )
		{
			`log("GameplayVisibleTags["@Index@"] :"@string(OutVisibilityInfo.GameplayVisibleTags[Index]));
		}
		`log("CoverDirection        :"@OutVisibilityInfo.CoverDirection);
		`log("PeekSide              :"@OutVisibilityInfo.PeekSide);
		`log("PeekToTargetDist      :"@OutVisibilityInfo.PeekToTargetDist);
		`log("TargetCover           :"@OutVisibilityInfo.TargetCover);
	}	
}

exec function LootSim(name LootTableName, int Repeat=1)
{
	local int i, j;
	local array<name> Loots;
	local X2LootTableManager LootTableManager;

	LootTableManager = class'X2LootTableManager'.static.GetLootTableManager();

	`log("LootSim for" @ LootTableName @ "...");
	for (i = 0; i < Repeat; ++i)
	{
		`log("LootSim #" $ i);
		Loots.Length = 0;
		LootTableManager.RollForLootTable(LootTableName, Loots);
		if (Loots.Length == 0)
		{
			`log("  (no loot)");
		}
		else
		{
			for (j = 0; j < Loots.Length; ++j)
			{
				`log("  " $ Loots[j]);
			}
		}
	}
}

exec function LootList()
{
	local XComGameState_InteractiveObject InterObj;
	local XComGameState_Unit Unit;
	local XComGameStateHistory History;

	History = `XCOMHISTORY;
	`log("=====Units=====");
	foreach History.IterateByClassType(class'XComGameState_Unit', Unit)
	{
		`log(Unit.ToString());
		`log("  Results for" @ Unit.ObjectID);
		`log("  " $ class'X2LootTableManager'.static.LootResultsToString((Unit.PendingLoot)));
	}
	`log("====Interactive Objects====");
	foreach History.IterateByClassType(class'XComGameState_InteractiveObject', InterObj)
	{
		`log("Object" @ InterObj.ObjectID);
		if (!InterObj.HasAvailableLoot())
		{
			`log("  Has no loot.");
		}
		else
		{
			`log("  " $ class'X2LootTableManager'.static.LootResultsToString(InterObj.PendingLoot));
		}
	}
	`log("end of loot list");
}

exec function DumpMPShellLoadoutDetails(optional int LoadoutId=-1)
{
	local XComGameState_Unit SoldierState;
	local XComGameState kLoadoutState;
	local array<XComGameState> arrSquadLoadouts;
	local X2MPCharacterTemplateManager MPCharacterTemplateManager;

	MPCharacterTemplateManager = class'X2MPCharacterTemplateManager'.static.GetMPCharacterTemplateManager();
	m_kPres = `PRES;

	if( LoadoutId < 0 )
	{
		arrSquadLoadouts = XComShellPresentationLayer(XComPlayerController(Outer).Pres).m_kMPShellManager.m_arrSquadLoadouts;

	}
	else
	{
		kLoadoutState = XComShellPresentationLayer(XComPlayerController(Outer).Pres).m_kMPShellManager.GetLoadoutFromId(LoadoutId);
		arrSquadLoadouts.AddItem(kLoadoutState);
	}

	foreach arrSquadLoadouts(kLoadoutState)
	{
		OutputMsg(" ");
		OutputMsg("Context:" @ kLoadoutState.GetContext().SummaryString());
		OutputMsg("-------------------------------------------------------------------------");
		foreach kLoadoutState.IterateByClassType(class'XComGameState_Unit', SoldierState, eReturnType_Reference)
		{
			//DisplaySoldierClassDetails(SoldierState);
			OutputMsg("Fullname:" @ SoldierState.GetFullName());
			OutputMsg("Template:" @ SoldierState.GetMyTemplateName() @ "  Mapping:" @ MPCharacterTemplateManager.FindCharacterTemplateMapOldToNew(SoldierState.GetMyTemplateName()));
			OutputMsg("Soldier:" @ SoldierState.GetSoldierClassTemplateName() @ "  Mapping:" @ MPCharacterTemplateManager.FindCharacterTemplateMapOldToNew(SoldierState.GetSoldierClassTemplateName()));
			OutputMsg("MP Char:" @ SoldierState.GetMPCharacterTemplateName() @ "  Mapping:" @ MPCharacterTemplateManager.FindCharacterTemplateMapOldToNew(SoldierState.GetMPCharacterTemplateName()));
			OutputMsg("Personality:" @ SoldierState.GetPersonalityTemplate().DataName);
			OutputMsg("Stats:" @ `ShowVar(SoldierState.GetCurrentStat(eStat_HP),HP) @ "  " @ `ShowVar(SoldierState.GetCurrentStat(eStat_Offense),Offense)
				@ "  " @ `ShowVar(SoldierState.GetCurrentStat(eStat_Defense),Defense) @ "  " @ `ShowVar(SoldierState.GetCurrentStat(eStat_Will),Will)
				@ "  " @ `ShowVar(SoldierState.GetCurrentStat(eStat_UtilityItems),UtilityItems));
			OutputMsg("-------------------------------------------------------------------------");
		}
		OutputMsg("=========================================================================");
	}
}

exec function DumpCharacterTemplateNames()
{
	local X2CharacterTemplateManager CharacterMgr;
	local X2DataTemplate Template;

	CharacterMgr = class'X2CharacterTemplateManager'.static.GetCharacterTemplateManager();
	foreach CharacterMgr.IterateTemplates(Template, none)
	{
		`Log(Template.DataName);
	}
}

exec function DumpMPCharacterTemplateName()
{
	local X2MPCharacterTemplateManager MPCharacterMgr;
	local X2DataTemplate Template;
	local X2MPCharacterTemplate MPTemplate;

	MPCharacterMgr = class'X2MPCharacterTemplateManager'.static.GetMPCharacterTemplateManager();
	foreach MPCharacterMgr.IterateTemplates(Template, none)
	{
		MPTemplate = X2MPCharacterTemplate(Template);
		`Log(`ShowVar(Template.DataName) @ `ShowVar(MPTemplate.CharacterTemplateName) @ `ShowVar(MPTemplate.SoldierClassTemplateName) @ `ShowVar(MPTemplate.DisplayName) @ `ShowVar(MPTemplate.DisplayDescription));
	}
}

function DisplaySoldierClassDetails(XComGameState_Unit SoldierState)
{
	local int iRankIndex;
	local array<SoldierClassAbilityType> AbilityNames;
	local X2AbilityTemplateManager AbilityTemplateMan;
	local X2AbilityTemplate AbilityTemplate;
	local X2CharacterTemplate CharacterTemplate;
	local name AbilityName;

	OutputMsg("=========================================================================");
	OutputMsg(`ShowVar(SoldierState.ObjectID, 'ObjectID') @ `ShowVar(SoldierState.GetName(eNameType_Full), 'Soldier Name') @ `ShowVar(SoldierState.GetMyTemplate().DataName, 'Data Name') @ `ShowVar(SoldierState.GetMyTemplate().Name, 'Template Name'));
	if (SoldierState.IsSoldier())
	{
		OutputMsg(`ShowVar(SoldierState.GetSoldierClassTemplate().DataName, 'Soldier Template Data Name') @ `ShowVar(SoldierState.GetSoldierClassTemplate().Name, 'Soldier Template Name') @ `ShowVar(SoldierState.GetName(eNameType_RankFull), 'Soldier Name'));
		AbilityNames = SoldierState.GetEarnedSoldierAbilities();
		OutputMsg(" ");
		OutputMsg("==== Earned Soldier Abilities ===");
		for (iRankIndex = 0; iRankIndex < AbilityNames.Length; ++iRankIndex)
		{
			OutputMsg("     Ability(" $ iRankIndex $ "):" @ `ShowVar(AbilityNames[iRankIndex].AbilityName, 'AbilityName'));
		}
	}

	OutputMsg(" ");
	OutputMsg("==== Abilities ===");
	AbilityTemplateMan = class'X2AbilityTemplateManager'.static.GetAbilityTemplateManager();
	CharacterTemplate = SoldierState.GetMyTemplate();
	foreach CharacterTemplate.Abilities(AbilityName)
	{
		AbilityTemplate = AbilityTemplateMan.FindAbilityTemplate(AbilityName);
		OutputMsg("     Ability(" $ AbilityName $ "):" @ `ShowVar(AbilityTemplate, 'AbilityTemplate'));
	}

	OutputMsg(" ");
	OutputMsg("==== Character Stats ===");
	OutputMsg(SoldierState.CharacterStats_ToString());
	OutputMsg("=========================================================================");
	OutputMsg(" ");
	OutputMsg(" ");
}

exec function DisplaySoldierRelationships(optional int ObjectID=-1)
{
	local XComGameStateHistory History;	
	local XComGameState_Unit SoldierState;
	
	History = `XCOMHISTORY;
	if (ObjectID < 0)
	{
		foreach History.IterateByClassType(class'XComGameState_Unit', SoldierState, eReturnType_Reference)
		{
			if (!SoldierState.IsSoldier())
			{
				continue;
			}
			SoldierRelationshipsPrintToLog(SoldierState);
		}
	}
	else
	{
		SoldierState = XComGameState_Unit(History.GetGameStateForObjectID(ObjectID, eReturnType_Reference));
		if (SoldierState.IsSoldier())
		{
			SoldierRelationshipsPrintToLog(SoldierState);
		}   
	}
}

function SoldierRelationshipsPrintToLog(XComGameState_Unit SoldierState)
{
	local XComGameState_Unit SoldierInRelationship;
	local int iRankIndex;
	local array<SquadmateScore> arrSoldierRelationships;

	OutputMsg("====" $ SoldierState.GetFirstName() $ " " $ SoldierState.GetLastName() $ "====");
	arrSoldierRelationships = SoldierState.GetSoldierRelationships();
	if (arrSoldierRelationships.Length == 0 && SoldierState.IsSoldier())
	{
		OutputMsg("No relationships currently\n");
	}
	
	for (iRankIndex = 0; iRankIndex < arrSoldierRelationships.Length; ++iRankIndex)
	{
		SoldierInRelationship = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(arrSoldierRelationships[iRankIndex].SquadmateObjectRef.ObjectID));
		OutputMsg("Relationship #"$(iRankIndex + 1)$" with: " $ SoldierInRelationship.GetFirstName() $ " " $ SoldierInRelationship.GetLastName());
		OutputMsg("Relationship score: " $ arrSoldierRelationships[iRankIndex].Score);
		OutputMsg("Relationship level: " $ arrSoldierRelationships[iRankIndex].eRelationship $ "\n");
	}
}

exec function DisplaySoldierClass(optional int ObjectID=-1)
{
	local XComGameStateHistory History;	
	local XComGameState_Unit SoldierState;

	History = `XCOMHISTORY;
	if (ObjectID < 0)
	{
		foreach History.IterateByClassType(class'XComGameState_Unit', SoldierState, eReturnType_Reference)
		{
			DisplaySoldierClassDetails(SoldierState);
		}
	}
	else
	{
		SoldierState = XComGameState_Unit(History.GetGameStateForObjectID(ObjectID, eReturnType_Reference));
		DisplaySoldierClassDetails(SoldierState);
	}
}

exec function GetObjectFromHistory(int ObjectID = -1)
{
	local XComGameStateHistory History;
	local XComGameState_BaseObject GSObject;

	History = `XCOMHISTORY;
	GSObject = History.GetGameStateForObjectID(ObjectID);

	`log(GSObject.ToString());
}

exec function SelectSoldierProgressionAbility(int ObjectID, int iSoldierRank, int iBranch)
{
	local XComGameStateHistory History;	
	local XComGameState NewGameState;
	local XComGameState_Unit SoldierState;

	History = `XCOMHISTORY;
	SoldierState = XComGameState_Unit(History.GetGameStateForObjectID(ObjectID, eReturnType_Reference));
	if (SoldierState != none)
	{
		NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Cheat" @ GetFuncName());
		SoldierState = XComGameState_Unit(NewGameState.ModifyStateObject(SoldierState.Class, SoldierState.ObjectID));
		SoldierState.BuySoldierProgressionAbility(NewGameState, iSoldierRank, iBranch);
		`GAMERULES.SubmitGameState(NewGameState);
	}
}

exec function TestCalcDamage(int iWeaponDamage, int iSourceDmgFlatBonus, int iSourceDmgPercentBonus, int iTargetDmgFlatReduction, int iTargetDmgPercentReduction)
{
	local int TotalDamage, WeaponDamage;
	local int SourceDamageBonus, SourceDmgFlatBonus, SourceDmgPercentBonus;
	local int TargetDamageReduction, TargetDmgFlatReduction, TargetDmgPercentReduction;
/*
	local XComGameState_Unit kTargetUnit;
	local X2WeaponTemplate kWeaponTemplate;

	bCalculatedDamage = true;
	kWeaponTemplate = X2WeaponTemplate(kSourceWeapon.GetMyTemplate());
	if (kWeaponTemplate != none)
	{
		WeaponDamage = kWeaponTemplate.iDamage;
	}
	SourceDmgFlatBonus = kSourceUnit.GetCurrentStat(eStat_DmgFlatBonus);
	SourceDmgPercentBonus = kSourceUnit.GetCurrentStat(eStat_DmgPercentBonus);

	kTargetUnit = XComGameState_Unit(kTarget);
	if (kTargetUnit != none)
	{
		TargetDmgFlatReduction = kTargetUnit.GetCurrentStat(eStat_DmgFlatReduction);
		TargetDmgPercentReduction = kTargetUnit.GetCurrentStat(eStat_DmgPercentReduction);
	}
*/
	WeaponDamage = iWeaponDamage;
	SourceDmgFlatBonus = iSourceDmgFlatBonus;
	SourceDmgPercentBonus = iSourceDmgPercentBonus;
	TargetDmgFlatReduction = iTargetDmgFlatReduction;
	TargetDmgPercentReduction = iTargetDmgPercentReduction;


	// Process the bonuses and reductions
	if (WeaponDamage > 0)
	{
		// Damage Dealing
		SourceDamageBonus += SourceDmgFlatBonus;
		SourceDamageBonus += FCeil(WeaponDamage * (SourceDmgPercentBonus / 100.0f));

		TargetDamageReduction += TargetDmgFlatReduction;
		TargetDamageReduction += FCeil(WeaponDamage * (TargetDmgPercentReduction / 100.0f));
	}
	else
	{
		// Healing ...
		SourceDamageBonus -= SourceDmgFlatBonus;
		SourceDamageBonus += FFloor(WeaponDamage * (SourceDmgPercentBonus / 100.0f));

		TargetDamageReduction -= TargetDmgFlatReduction;
		TargetDamageReduction += FFloor(WeaponDamage * (TargetDmgPercentReduction / 100.0f));
	}

	TotalDamage = WeaponDamage + SourceDamageBonus - TargetDamageReduction;

	if ((WeaponDamage > 0 && TotalDamage < 0) || (WeaponDamage < 0 && TotalDamage > 0))
	{
		// Do not allow the damage reduction to invert the damage amount (i.e. heal instead of hurt, or vice-versa).
		TotalDamage = 0;
	}
}

//exec function Give

exec function ChallengeModeSetTimer(int Minutes, int Seconds, optional bool bStopTime=false)
{
	local XComGameState_TimerData Timer;

	Timer = XComGameState_TimerData(`XCOMHISTORY.GetSingleGameStateObjectForClass(class'XComGameState_TimerData', true));
	`log( `location @ "Current Time: " $ Timer.GetCurrentTime());
	Timer.SetRealTimeTimer((Minutes * 60) + Seconds);
	Timer.bStopTime = bStopTime;
	`log( `location @ "Updated Time: " $ Timer.GetCurrentTime());
}

exec function ValidateHistory()
{
	local XComGameStateHistory History;
	local XComGameState_BattleData BattleDataState;

	History = class'XComGameStateHistory'.static.GetValidationGameStateHistory();
	History.ReadHistoryFromFile("SaveData_Dev/", "MPTacticalGameStartState");

	History = class'XComGameStateHistory'.static.GetGameStateHistory();
	History.ReadHistoryFromFile("SaveData_Dev/", "MPTacticalGameStartState_start");

	//Events will not be triggered during validation
	`XEVENTMGR.ResetToDefaults(false);

	BattleDataState = XComGameState_BattleData(History.GetSingleGameStateObjectForClass(class'XComGameState_BattleData'));
	`ONLINEEVENTMGR.bInitiateValidationAfterLoad = true;
	`ONLINEEVENTMGR.bIsChallengeModeGame = true;
	ConsoleCommand(BattleDataState.m_strMapCommand $ "Validation");
}

exec function ChallengeStartAutoSeedGeneration(int StartingSeedNum=1)
{
	local UITacticalQuickLaunch QuickLaunchUI;
	local XComOnlineEventMgr EventMgr;
	EventMgr = `ONLINEEVENTMGR;
	EventMgr.ChallengeModeSeedGenNum = StartingSeedNum;

	QuickLaunchUI = UITacticalQuickLaunch(XComPlayerController(Outer).Pres.ScreenStack.GetScreen(class'UITacticalQuickLaunch'));
	if (QuickLaunchUI != none)
	{
		QuickLaunchUI.StartChallengeBattle();
	}
}

exec native function CreateLadder( int LadderIndex, optional int LadderSize = class'XComGameState_LadderProgress'.default.DefaultSize );

exec function CreateLadderStart( int LadderIndex, int MissionIndex, optional int LadderSize = class'XComGameState_LadderProgress'.default.DefaultSize )
{
	local XComGameStateHistory History;
	local XComGameState StartState;
	local XComGameState_ObjectivesList StartObjectives, TrueObjectives;
	local XComGameState_Unit UnitStart, UnitLatest;
	local XComGameState_BattleData BattleDataState;
	local XComGameState_LadderProgress LadderData;
	local XComGameState_CampaignSettings CampaignSettings;

	History = class'XComGameStateHistory'.static.GetGameStateHistory( );

	StartState = History.GetGameStateFromHistory( History.FindStartStateIndex( ) );

	// copy over the objective strings from the latest non-start state to power the challenge squad select UI
	foreach History.IterateByClassType( class'XComGameState_ObjectivesList', TrueObjectives )
	{
		break;
	}
	StartObjectives = XComGameState_ObjectivesList( StartState.GetGameStateForObjectID( TrueObjectives.ObjectID ) );
	StartObjectives.ObjectiveDisplayInfos = TrueObjectives.ObjectiveDisplayInfos;

	// copy over all the unit positions from the latest to the start state so that Design can move them around after having launched through TQL
	foreach StartState.IterateByClassType( class'XComGameState_Unit', UnitStart )
	{
		UnitLatest = XComGameState_Unit( History.GetGameStateForObjectID( UnitStart.ObjectID ) );
		UnitStart.SetVisibilityLocation( UnitLatest.TileLocation );
		UnitStart.bNarrativeLadder = true;
	}

	History.ObliterateGameStatesFromHistory( History.GetNumGameStates( ) - History.FindStartStateIndex( ) - 1 );

	BattleDataState = XComGameState_BattleData( History.GetSingleGameStateObjectForClass( class'XComGameState_BattleData' ) );
	BattleDataState.m_strMapCommand = "open" @ BattleDataState.MapData.PlotMapName $ "?game=XComGame.XComTacticalGame";

	LadderData = XComGameState_LadderProgress( History.GetSingleGameStateObjectForClass( class'XComGameState_LadderProgress', true ) );
	if (LadderData == none)
	{
		LadderData = XComGameState_LadderProgress( StartState.CreateNewStateObject( class'XComGameState_LadderProgress' ) );
	}
	LadderData.bNewLadder = false;
	LadderData.LadderIndex = LadderIndex;
	LadderData.LadderRung = MissionIndex;
	LadderData.LadderSize = LadderSize;
	LadderData.LadderSquadIndex = -1;
	LadderData.LadderSquadName = class'UITacticalQuickLaunch'.static.GetLastUsedSquad( );
	LadderData.PopulateFromNarrativeConfig( );

	if (class'XComGameState_LadderProgress'.default.NarrativeLadderNames.Length + 1 > LadderIndex)
	{
		LadderData.LadderName = class'XComGameState_LadderProgress'.default.NarrativeLadderNames[ LadderIndex ];
	}
	else
	{
		LadderData.LadderName = "Missing Ladder " $ LadderIndex $ " Name";
	}


	CampaignSettings = XComGameState_CampaignSettings( History.GetSingleGameStateObjectForClass( class'XComGameState_CampaignSettings' ) );
	CampaignSettings.SetSuppressFirstTimeNarrativeEnabled( true );
	CampaignSettings.SetTutorialEnabled( false );
	CampaignSettings.SetIronmanEnabled( true );

	`TACTICALMISSIONMGR.RefreshHackRewards( BattleDataState );

	if (!History.WriteHistoryToFile( "Ladders/", "Mission_" $ LadderIndex $ "_" $ MissionIndex $ "_" $ CampaignSettings.DifficultySetting ))
	{
		OutputMsg( "Failed to write Ladder Save Mission_" $ LadderIndex $ "_" $ MissionIndex $ "_" $ CampaignSettings.DifficultySetting );
	}
}

native static function string GetCampaignStartTime( );

exec function LoadLadderStart( int LadderIndex, int MissionIndex, int Difficulty = 1 )
{
	local XComGameStateHistory History;
	local XComGameState_BattleData BattleDataState;
	local XComGameState_CampaignSettings CurrentCampaign;

	History = class'XComGameStateHistory'.static.GetGameStateHistory();
	History.ReadHistoryFromFile( "Ladders/", "Mission_" $ LadderIndex $ "_" $ MissionIndex $ "_" $ Difficulty );

	CurrentCampaign = XComGameState_CampaignSettings(History.GetSingleGameStateObjectForClass(class'XComGameState_CampaignSettings'));
	CurrentCampaign.SetStartTime( GetCampaignStartTime( ) );
	CurrentCampaign.SetGameIndexFromProfile( );

	BattleDataState = XComGameState_BattleData( History.GetSingleGameStateObjectForClass( class'XComGameState_BattleData' ) );
	ConsoleCommand( BattleDataState.m_strMapCommand );
}

exec function StartLadder( int LadderIndex, int Difficulty = 1 )
{
	LoadLadderStart( LadderIndex, 1, Difficulty );
}

exec function ResetLadderProgress( )
{
	local XComOnlineProfileSettings Profile;

	Profile = `XPROFILESETTINGS;
	Profile.Data.m_Ladders = 9;

	`ONLINEEVENTMGR.SaveProfileSettings();
}

// Usage: Open UITacticalQuickLaunch, select appropriate settings, "Start Challenge Mode", wait for load into map, then finally, with the start dialog open, run this command.
exec function CreateChallengeStart(string LeaderBoardSuffix)
{
	local XComGameStateHistory History;
	local XComGameState_BattleData BattleDataState;
	local XComGameState_ChallengeData ChallengeData;
	local XComGameState StartState;
	local XComGameState_ObjectivesList StartObjectives, TrueObjectives;
	local XComGameState_MissionSite MissionSite;
	local XComGameState_Unit UnitStart, UnitLatest;
	local XComGameState_TimerData Timer;

	History = class'XComGameStateHistory'.static.GetGameStateHistory( );

	StartState = History.GetGameStateFromHistory( History.FindStartStateIndex( ) );
	MissionSite = XComGameState_MissionSite( History.GetSingleGameStateObjectForClass( class'XComGameState_MissionSite' ) );

	// copy over the objective strings from the latest non-start state to power the challenge squad select UI
	foreach History.IterateByClassType( class'XComGameState_ObjectivesList', TrueObjectives )
	{
		break;
	}
	StartObjectives = XComGameState_ObjectivesList( StartState.GetGameStateForObjectID( TrueObjectives.ObjectID ) );
	StartObjectives.ObjectiveDisplayInfos = TrueObjectives.ObjectiveDisplayInfos;

	// copy over all the unit positions from the latest to the start state so that Design can move them around after having launched through TQL
	foreach StartState.IterateByClassType( class'XComGameState_Unit', UnitStart )
	{
		UnitLatest = XComGameState_Unit( History.GetGameStateForObjectID( UnitStart.ObjectID ) );
		UnitStart.SetVisibilityLocation( UnitLatest.TileLocation );
	}

	History.ObliterateGameStatesFromHistory( History.GetNumGameStates( ) - History.FindStartStateIndex( ) - 1 );

	BattleDataState = XComGameState_BattleData( History.GetSingleGameStateObjectForClass( class'XComGameState_BattleData' ) );
	BattleDataState.m_strLocation = MissionSite.GetLocationDescription( );
	BattleDataState.m_strMapCommand = "open" @ BattleDataState.MapData.PlotMapName $ "?game=XComGame.XComTacticalGame";

	ChallengeData = XComGameState_ChallengeData( History.GetSingleGameStateObjectForClass( class'XComGameState_ChallengeData', true ) );
	if (ChallengeData == none)
	{
		ChallengeData = XComGameState_ChallengeData( StartState.CreateNewStateObject( class'XComGameState_ChallengeData' ) );

		ChallengeData.SquadSizeSelectorName = 'TQL';
		ChallengeData.ClassSelectorName = 'TQL';
		ChallengeData.AlienSelectorName = 'TQL';
		ChallengeData.RankSelectorName = 'TQL';
		ChallengeData.ArmorSelectorName = 'TQL';
		ChallengeData.PrimaryWeaponSelectorName = 'TQL';
		ChallengeData.SecondaryWeaponSelectorName = 'TQL';
		ChallengeData.UtilityItemSelectorName = 'TQL';
		ChallengeData.AlertForceLevelSelectorName = 'TQL';
		ChallengeData.EnemyForcesSelectorName = 'TQL';

		// we can probably assume if we didn't have the challenge data, we don't have the ChallengeMode timer state either
		Timer = XComGameState_TimerData( StartState.CreateNewStateObject( class'XComGameState_TimerData' ) );
		Timer.bIsChallengeModeTimer = true;
		Timer.SetTimerData( EGSTT_AppRelativeTime, EGSTDT_Down, EGSTRT_None );
		Timer.SetRealTimeTimer( 30 * 60 );
		Timer.bStopTime = true;
	}

	ChallengeData.LeaderBoardName = BattleDataState.m_strOpName @ LeaderBoardSuffix;

	History.WriteHistoryToFile( "Challenges/", "ChallengeStartState_" $ LeaderBoardSuffix );
}

exec function LoadChallengeStart(string LeaderBoardSuffix)
{
	local XComGameStateHistory History;
	local XComGameState_BattleData BattleDataState;
	local XComChallengeModeManager ChallengeModeManager;


	History = class'XComGameStateHistory'.static.GetGameStateHistory();
	History.ReadHistoryFromFile("Challenges/", "ChallengeStartState_" $ LeaderBoardSuffix);

	ChallengeModeManager = XComEngine(Class'GameEngine'.static.GetEngine()).ChallengeModeManager;
	ChallengeModeManager.BootstrapDebugChallenge( );

	BattleDataState = XComGameState_BattleData(History.GetSingleGameStateObjectForClass(class'XComGameState_BattleData'));
	`ONLINEEVENTMGR.bIsChallengeModeGame = true;
	ConsoleCommand(BattleDataState.m_strMapCommand);
}

exec function LoadChallengeReplay(string LeaderBoardSuffix)
{
	local XComGameStateHistory History;
	local XComGameState_BattleData BattleDataState;

	History = class'XComGameStateHistory'.static.GetGameStateHistory();
	History.ReadHistoryFromFile("Challenges/", "ChallengeStartState_" $ LeaderBoardSuffix);

	BattleDataState = XComGameState_BattleData(History.GetSingleGameStateObjectForClass(class'XComGameState_BattleData'));
	`ONLINEEVENTMGR.bInitiateReplayAfterLoad = true;
	`ONLINEEVENTMGR.bIsChallengeModeGame = true;
	ConsoleCommand(BattleDataState.m_strMapCommand);
}

// copied from X2TacticalGameRuleset
private static function Object GetEventFilterObject(AbilityEventFilter eventFilter, XComGameState_Unit FilterUnit, XComGameState_Player FilterPlayerState)
{
	local Object FilterObj;

	switch(eventFilter)
	{
		case eFilter_None:
			FilterObj = none;
			break;
		case eFilter_Unit:
			FilterObj = FilterUnit;
			break;
		case eFilter_Player:
			FilterObj = FilterPlayerState;
			break;
	}

	return FilterObj;
}

exec function ResaveChallengeStart(string LeaderBoardSuffix)
{
	local XComGameStateHistory History;
	local XComGameState StartState;
	local StateObjectReference StateRef;
	local XComGameState_Player PlayerState;
	local XComGameState_Unit Unit;
	local array<AbilitySetupData> AbilityInitData;
	local AbilitySetupData AbilityData;
	local XComGameState_Ability AbilityState;
	local X2CharacterTemplate CharTemplate;
	local int i, ChallengeDifficultyLevel;
	local float TemplateBaseStat, CharBaseStat;
	local X2CharacterTemplateManager CharTemplateManager;
	local array<X2DataTemplate> AllTemplates;
	local AbilityEventListener kListener;
	local X2AbilityTrigger Trigger;
	local Object FilterObj, SourceObj;
	local X2EventManager EventManager;
	local X2AbilityTrigger_EventListener AbilityTriggerEventListener;

	EventManager = `XEVENTMGR;

	ChallengeDifficultyLevel = 2;

	History = class'XComGameStateHistory'.static.GetGameStateHistory();
	CharTemplateManager = class'X2CharacterTemplateManager'.static.GetCharacterTemplateManager();

	History.ReadHistoryFromFile("Challenges/", "ChallengeStartState_" $ LeaderBoardSuffix);

	StartState = History.GetStartState( );

	foreach History.IterateByClassType( class'XComGameState_Unit', Unit )
	{
		StateRef.ObjectID = Unit.GetAssociatedPlayerID();
		PlayerState = XComGameState_Player( History.GetGameStateForObjectID( StateRef.ObjectID ) );

		AbilityInitData = Unit.GatherUnitAbilitiesForInit( StartState, PlayerState, false );

		foreach AbilityInitData( AbilityData )
		{
			StateRef = Unit.FindAbility( AbilityData.TemplateName );
			AbilityState = XComGameState_Ability( History.GetGameStateForObjectID( StateRef.ObjectID ) );

			if (AbilityState == none)
			{
				OutputMsg( Unit.GetMyTemplateName() @ "missing ability" @ AbilityData.TemplateName );
				class'X2TacticalGameRuleset'.static.InitAbilityForUnit( AbilityData.Template, Unit, StartState, AbilityData.SourceWeaponRef, AbilityData.SourceAmmoRef );
			}
			else
			{
				SourceObj = AbilityState;

				foreach AbilityData.Template.AbilityEventListeners(kListener)
				{
					FilterObj = GetEventFilterObject(kListener.Filter, Unit, PlayerState);

					if (!EventManager.IsRegistered( SourceObj, kListener.EventID, kListener.Deferral, kListener.EventFn ))
					{
						OutputMsg( Unit.GetMyTemplateName() @ AbilityData.TemplateName  @ "missing event listener" );
						EventManager.RegisterForEvent(SourceObj, kListener.EventID, kListener.EventFn, kListener.Deferral, /*priority*/, FilterObj);
					}
				}

				foreach AbilityData.Template.AbilityTriggers(Trigger)
				{
					if (Trigger.IsA('X2AbilityTrigger_EventListener'))
					{
						AbilityTriggerEventListener = X2AbilityTrigger_EventListener(Trigger);

						FilterObj = GetEventFilterObject(AbilityTriggerEventListener.ListenerData.Filter, Unit, PlayerState);
						if (AbilityTriggerEventListener.FixupRegisterListener(AbilityState, FilterObj))
						{
							OutputMsg( Unit.GetMyTemplateName() @ AbilityData.TemplateName  @ "missing event listener" );
						}
					}
				}
			}
		}

		if (Unit.GetMyTemplate().bShouldCreateDifficultyVariants)
		{
			// After reading the history, the cache of pre-computed templates will be out of sync with the difficulty of the
			// history that we've loaded.  Since Challenge Mode is exactly Commander-level, get that template directly
			// instead of rebuilding the entire cache of Character Templates.
			CharTemplateManager.FindDataTemplateAllDifficulties( Unit.GetMyTemplateName(), AllTemplates );
			CharTemplate = X2CharacterTemplate( AllTemplates[ ChallengeDifficultyLevel ] );
		}
		else
		{
			// No difficulty variation so the returned template is the correct one.
			CharTemplate = Unit.GetMyTemplate( );
		}

		for (i = 0; i < eStat_MAX; ++i)
		{
			TemplateBaseStat = CharTemplate.GetCharacterBaseStat( ECharStatType(i) );
			CharBaseStat = Unit.GetBaseStat( ECharStatType(i) );

			if (CharBaseStat != TemplateBaseStat)
			{
				OutputMsg( Unit.GetMyTemplateName() @ "base stat mismatch" @ `ShowEnum(ECharStatType, i) );
				Unit.SetBaseMaxStat( ECharStatType(i), TemplateBaseStat );
			}
		}
	}

	History.WriteHistoryToFile( "Challenges/", "ChallengeStartState_" $ LeaderBoardSuffix );

	OutputMsg( "Resave of Challenge" @ LeaderBoardSuffix @ "complete." );
}

exec function MPWriteTacticalGameStartState()
{
	local XComGameStateHistory History;
	//local XComOnlineProfileSettings Settings;
	//Settings = `XPROFILESETTINGS;
	//class'XComGameState'.static.WriteToByteArray(TacticalStartState, Settings.Data.MPTacticalGameStartState);
	History = class'XComGameStateHistory'.static.GetGameStateHistory();
	History.WriteHistoryToFile("SaveData_Dev/", "MPTacticalGameStartState");
}

exec function MPReadTacticalGameStartState()
{
	local XComGameStateHistory History;

	History = class'XComGameStateHistory'.static.GetGameStateHistory();
	History.ReadHistoryFromFile("SaveData_Dev/", "MPTacticalGameStartState");
}

exec function MPLoadTacticalMap()
{
	local XComGameState_BattleData BattleDataState;
	local XComGameStateHistory History;

	History = class'XComGameStateHistory'.static.GetGameStateHistory();
	BattleDataState = XComGameState_BattleData(History.GetSingleGameStateObjectForClass(class'XComGameState_BattleData'));

	ConsoleCommand(BattleDataState.m_strMapCommand);
}

exec function MPForceConnectionAttempt()
{
	local XComGameStateNetworkManager NetworkMgr;
	NetworkMgr = `XCOMNETMANAGER;
	NetworkMgr.ForceConnectionAttempt();
}

exec function MPCreateServer(optional int Port=7777, optional bool bSteam=false)
{
	local string Error;
	local URL ServerURL;
	local XComGameStateNetworkManager NetworkMgr;
	ServerURL.Port = Port;
	if (bSteam)
	{
		ServerURL.Op.AddItem("steamsockets");
	}
	NetworkMgr = `XCOMNETMANAGER;
	NetworkMgr.CreateServer(ServerURL, Error);
}

exec function MPCreateClient(string ServerURL, optional int Port=7777)
{
	local string Error;
	local URL ClientURL;
	local XComGameStateNetworkManager NetworkMgr;
	ClientURL.Host = ServerURL;
	ClientURL.Port = Port;
	NetworkMgr = `XCOMNETMANAGER;
	NetworkMgr.CreateClient(ClientURL, Error);
}

exec function MPSimInvite()
{
	local XComOnlineEventMgr OnlineMgr;
	OnlineMgr = `ONLINEEVENTMGR;
	// Simulate "accepting" an invite
	OnlineMgr.HasAcceptedInvites();
}


/***
 *
 * Current flow for creating a Steam Lobby -> P2P Server / Client
 *
 *   Server:
 *       - MPAddLobbyDelegates
 *       - MPCreateLobby
 *       Wait for Client to "Join Lobby"
 *
 *   Client:
 *       - MPAddLobbyDelegates
 *       - MPJoinLobby [Hex Value of Server's Lobby, will look like: 186000036E2D597 for the LobbyID: 109775241837991319]
 *       Wait for Server to "Make the Game Server"
 *
 *   Server:
 *       - MPCreateLobbyServer
 *       - MPSetLobbyServer [Hex Lobby ID (186000036E2D597)]  [Hex Server ID (14014455AC47402 from the ID: 90094280655533058)]
 *       This should make both the server and client ready for any "SendP2PData" calls
 *
 *   MPSendP2PData 1100001009ED61F     (innominatesnap: 76561197970675231)
 *   MPSendP2PData 110000105C0DEF0     (talley.timothy: 76561198056791792)
 *
 */

exec function MPAddLobbyDelegates()
{
//<workshop> TODO OSS
	//local OnlineGameInterfaceXCom GameInterface;

	//GameInterface = OnlineGameInterfaceXCom(OnlineSub.GameInterface);
	//GameInterface.AddJoinLobbyCompleteDelegate(OnJoinLobbyComplete);
	//GameInterface.AddLobbySettingsUpdateDelegate(OnLobbySettingsUpdate);
	//GameInterface.AddLobbyMemberSettingsUpdateDelegate(OnLobbyMemberSettingsUpdate);
	//GameInterface.AddLobbyMemberStatusUpdateDelegate(OnLobbyMemberStatusUpdate);
	//GameInterface.AddLobbyReceiveMessageDelegate(OnLobbyReceiveMessage);
	//GameInterface.AddLobbyReceiveBinaryDataDelegate(OnLobbyReceiveBinaryData);
	//GameInterface.AddLobbyJoinGameDelegate(OnLobbyJoinGame);
}

exec function MPClearLobbyDelegates()
{
//<workshop> TODO OSS
	//local OnlineGameInterfaceXCom GameInterface;

	//GameInterface = OnlineGameInterfaceXCom(OnlineSub.GameInterface);
	//GameInterface.ClearJoinLobbyCompleteDelegate(OnJoinLobbyComplete);
	//GameInterface.ClearLobbySettingsUpdateDelegate(OnLobbySettingsUpdate);
	//GameInterface.ClearLobbyMemberSettingsUpdateDelegate(OnLobbyMemberSettingsUpdate);
	//GameInterface.ClearLobbyMemberStatusUpdateDelegate(OnLobbyMemberStatusUpdate);
	//GameInterface.ClearLobbyReceiveMessageDelegate(OnLobbyReceiveMessage);
	//GameInterface.ClearLobbyReceiveBinaryDataDelegate(OnLobbyReceiveBinaryData);
	//GameInterface.ClearLobbyJoinGameDelegate(OnLobbyJoinGame);
}

//function OnJoinLobbyComplete(bool bWasSuccessful, const out array<OnlineGameInterfaceXCom_ActiveLobbyInfo> LobbyList, int LobbyIndex, UniqueNetId LobbyUID, string Error)
//{
//	local string LobbyUIDString;
//	LobbyUIDString = OnlineSub.UniqueNetIdToHexString( LobbyUID );
//	`log(`location @ `ShowVar(bWasSuccessful) @ `ShowVar(LobbyIndex) @ `ShowVar(LobbyUIDString) @ `ShowVar(Error),,'XCom_Online');
//}
//
//function OnLobbySettingsUpdate(const out array<OnlineGameInterfaceXCom_ActiveLobbyInfo> LobbyList, int LobbyIndex)
//{
//	`log(`location @ `ShowVar(LobbyIndex),,'XCom_Online');
//}
//
//function OnLobbyMemberSettingsUpdate(const out array<OnlineGameInterfaceXCom_ActiveLobbyInfo> LobbyList, int LobbyIndex, int MemberIndex)
//{
//	`log(`location @ `ShowVar(LobbyIndex) @ `ShowVar(MemberIndex),,'XCom_Online');
//}
//
//function OnLobbyMemberStatusUpdate(const out array<OnlineGameInterfaceXCom_ActiveLobbyInfo> LobbyList, int LobbyIndex, int MemberIndex, int InstigatorIndex, string Status)
//{
//	`log(`location @ `ShowVar(LobbyIndex) @ `ShowVar(MemberIndex) @ `ShowVar(InstigatorIndex) @ `ShowVar(Status),,'XCom_Online');
//	if( LobbyList.Length >= 2 )
//	{
//		MPCreateLobbyServer();
//	}
//}
//
//function OnLobbyReceiveMessage(const out array<OnlineGameInterfaceXCom_ActiveLobbyInfo> LobbyList, int LobbyIndex, int MemberIndex, string Type, string Message)
//{
//	`log(`location @ `ShowVar(LobbyIndex) @ `ShowVar(MemberIndex) @ `ShowVar(Type) @ `ShowVar(Message),,'XCom_Online');
//}
//
//function OnLobbyReceiveBinaryData(const out array<OnlineGameInterfaceXCom_ActiveLobbyInfo> LobbyList, int LobbyIndex, int MemberIndex, const out array<byte> Data)
//{
//	`log(`location @ `ShowVar(LobbyIndex) @ `ShowVar(MemberIndex) @ `ShowVar(Data.Length),,'XCom_Online');
//}
//
//function OnLobbyJoinGame(const out array<OnlineGameInterfaceXCom_ActiveLobbyInfo> LobbyList, int LobbyIndex, UniqueNetId ServerId, string ServerIP)
//{
//	local string ServerIdString;
//	ServerIdString = OnlineSub.UniqueNetIdToHexString( ServerId );
//	`log(`location @ `ShowVar(LobbyIndex) @ `ShowVar(ServerIdString) @ `ShowVar(ServerIP),,'XCom_Online');
//}
//
//function OnLobbyKicked(const out array<OnlineGameInterfaceXCom_ActiveLobbyInfo> LobbyList, int LobbyIndex, int AdminIndex)
//{
//	`log(`location @ `ShowVar(LobbyIndex) @ `ShowVar(AdminIndex),,'XCom_Online');
//}
//
//exec function MPCreateLobby()
//{
//	local OnlineGameInterfaceXCom GameInterface;
//	GameInterface = OnlineGameInterfaceXCom(OnlineSub.GameInterface);
//	if ( GameInterface.CreateLobby(2, XLV_Public) )
//	{
//		`log("Created Lobby...");
//	}
//}
//
//exec function MPJoinLobby(string UniqueNetIdHexString)
//{
//	local OnlineGameInterfaceXCom GameInterface;
//	local UniqueNetId LobbyId;
//
//	OnlineSub.StringToUniqueNetId( UniqueNetIdHexString, LobbyId );
//	GameInterface = OnlineGameInterfaceXCom(OnlineSub.GameInterface);
//	if ( GameInterface.JoinLobby(LobbyId) )
//	{
//		`log("Joined Lobby: " $ LobbyId.Uid.A $ LobbyId.Uid.B);
//	}
//}
//
//exec function MPLeaveLobby(string UniqueNetIdHexString)
//{
//	local OnlineGameInterfaceXCom GameInterface;
//	local UniqueNetId LobbyId;
//
//	OnlineSub.StringToUniqueNetId( UniqueNetIdHexString, LobbyId );
//	GameInterface = OnlineGameInterfaceXCom(OnlineSub.GameInterface);
//	if ( GameInterface.LeaveLobby(LobbyId) )
//	{
//		`log("Leave Lobby: " $ LobbyId.Uid.A $ LobbyId.Uid.B);
//	}
//}
//
//exec function MPCreateLobbyServer()
//{
//	local OnlineGameInterfaceXCom GameInterface;
//
//	GameInterface = OnlineGameInterfaceXCom(OnlineSub.GameInterface);
//	GameInterface.PublishSteamServer();
//}
//
//exec function MPJoinLobbyServer()
//{
//}
//
//exec function MPSendP2PData(string UniqueNetIdHexString, optional bool bForceClient=false)
//{
//	local OnlineGameInterfaceXCom GameInterface;
//	local UniqueNetId SteamId;
//	local array<byte> Data;
//	local int i;
//
//	OnlineSub.StringToUniqueNetId( UniqueNetIdHexString, SteamId );
//	GameInterface = OnlineGameInterfaceXCom(OnlineSub.GameInterface);
//	Data.Add(10);
//	for (i=0; i < Data.Length; ++i)
//	{
//		Data[i] = i;
//	}
//	GameInterface.SendP2PData(SteamId, Data, bForceClient);
//	`log(`location @ `ShowVar(OnlineSub.UniqueNetIdToHexString(SteamId)));
//}
//
//exec function MPReadP2PData()
//{
//	local OnlineGameInterfaceXCom GameInterface;
//	local UniqueNetId SteamId;
//	local string DebugOutput;
//	local array<byte> Data;
//	local int i;
//
//	GameInterface = OnlineGameInterfaceXCom(OnlineSub.GameInterface);
//	GameInterface.ReadP2PData(Data, SteamId);
//	for (i = 0; i < Data.Length; ++i)
//	{
//		DebugOutput $= i;
//	}
//	`log(`location @ `ShowVar(OnlineSub.UniqueNetIdToHexString(SteamId)) @ `ShowVar(DebugOutput));
//}
//
//exec function MPAcceptP2PSessionWithUser(string UniqueNetIdHexString)
//{
//	local OnlineGameInterfaceXCom GameInterface;
//	local UniqueNetId SteamId;
//
//	OnlineSub.StringToUniqueNetId( UniqueNetIdHexString, SteamId );
//	GameInterface = OnlineGameInterfaceXCom(OnlineSub.GameInterface);
//	GameInterface.AcceptP2PSessionWithUser(SteamId);
//	`log(`location @ `ShowVar(OnlineSub.UniqueNetIdToHexString(SteamId)));
//}
//
//exec function MPCloseP2PSessionWithUser(string UniqueNetIdHexString)
//{
//	local OnlineGameInterfaceXCom GameInterface;
//	local UniqueNetId SteamId;
//
//	OnlineSub.StringToUniqueNetId( UniqueNetIdHexString, SteamId );
//	GameInterface = OnlineGameInterfaceXCom(OnlineSub.GameInterface);
//	GameInterface.CloseP2PSessionWithUser(SteamId);
//	`log(`location @ `ShowVar(OnlineSub.UniqueNetIdToHexString(SteamId)));
//}
//
//exec function MPAllowP2PPacketRelay(bool bAllow)
//{
//	local OnlineGameInterfaceXCom GameInterface;
//
//	GameInterface = OnlineGameInterfaceXCom(OnlineSub.GameInterface);
//	GameInterface.AllowP2PPacketRelay(bAllow);
//	`log(`location @ `ShowVar(bAllow));
//}
//
//exec function MPGetP2PSessionState(string UniqueNetIdHexString)
//{
//	local OnlineGameInterfaceXCom GameInterface;
//	local UniqueNetId SteamId;
//
//	OnlineSub.StringToUniqueNetId( UniqueNetIdHexString, SteamId );
//	GameInterface = OnlineGameInterfaceXCom(OnlineSub.GameInterface);
//	GameInterface.GetP2PSessionState(SteamId);
//	`log(`location @ `ShowVar(OnlineSub.UniqueNetIdToHexString(SteamId)));
//}
//
//exec function MPSetLobbyServer(string LobbyIdHexString, string ServerIdHexString, optional string ServerIP)
//{
//	local OnlineGameInterfaceXCom GameInterface;
//	local UniqueNetId LobbyId, ServerId;
//
//	OnlineSub.StringToUniqueNetId( LobbyIdHexString, LobbyId );
//	OnlineSub.StringToUniqueNetId( ServerIdHexString, ServerId );
//	GameInterface = OnlineGameInterfaceXCom(OnlineSub.GameInterface);
//	GameInterface.SetLobbyServer(LobbyId, ServerId, ServerIP);
//}
//
//exec function MPDisconnect()
//{
//	local XComGameStateNetworkManager NetworkMgr;
//	NetworkMgr = `XCOMNETMANAGER;
//	NetworkMgr.Disconnect();
//}
//
//exec function MPResetConnectionData()
//{
//	local XComGameStateNetworkManager NetworkMgr;
//	NetworkMgr = `XCOMNETMANAGER;
//	NetworkMgr.ResetConnectionData();
//}
//
//exec function MPSendHistory()
//{
//	local XComGameStateNetworkManager NetworkMgr;
//	NetworkMgr = `XCOMNETMANAGER;
//	NetworkMgr.SendHistory(`XCOMHISTORY, `XEVENTMGR);
//}
//
//exec function MPCheckConnections()
//{
//	local int Idx;
//	local XComGameStateNetworkManager NetworkMgr;
//	NetworkMgr = `XCOMNETMANAGER;
//	for(Idx = 0; Idx < NetworkMgr.Connections.Length; ++Idx)
//	{
//		`log( "XComGameStateNetworkManager: " @ NetworkMgr.GetConnectionInfoDebugString(Idx),, 'XCom_Net');
//	}
//}
//
//exec function MPSetPlayerSync(optional bool bReady=true)
//{
//	local XComGameState_Player GameStatePlayer, NewPlayerState;
//	//local XComGameStateNetworkManager NetworkMgr;
//	local XComGameStateHistory History;
//	local XComGameState NewGameState;
//	local bool bSubmitGameState;
//
//	History = class'XComGameStateHistory'.static.GetGameStateHistory();
//	//NetworkMgr = `XCOMNETMANAGER;
//	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Set Player Sync");
//	foreach History.IterateByClassType(class'XComGameState_Player', GameStatePlayer)
//	{
//		//if (GameStatePlayer.GetGameStatePlayerName() == GetALocalPlayerController().PlayerReplicationInfo.PlayerName)
//		//{
//			`log(`location @ "Found Player '"$GameStatePlayer.GetGameStatePlayerName()$"': Setting the Sync flag to "$bReady,,'XComOnline');
//			NewPlayerState = XComGameState_Player(NewGameState.CreateStateObject(class'XComGameState_Player', GameStatePlayer.ObjectID));
//			NewPlayerState.bPlayerReady = bReady;
//			NewGameState.AddStateObject(NewPlayerState);
//			//NetworkMgr.SendMergeGameState(NewGameState);
//			bSubmitGameState = true;
//			//break;
//		//}
//	}
//	if (bSubmitGameState)
//	{
//		`TACTICALRULES.SubmitGameState(NewGameState);
//	}
//}
//
//exec function MPValidateConnections()
//{
//	local int NumHistoryFrames;
//	local int LastHistoryFrameIndex;
//	local int ConnectionIdx;
//	local XComGameStateHistory History;
//	local XComGameStateNetworkManager NetworkMgr;
//
//	NetworkMgr = `XCOMNETMANAGER;
//	History = `XCOMHISTORY;
//	NumHistoryFrames = History.GetNumGameStates();
//	LastHistoryFrameIndex = NumHistoryFrames - 1;
//	for( ConnectionIdx = 0; ConnectionIdx < NetworkMgr.Connections.Length; ++ConnectionIdx )
//	{
//		NetworkMgr.Connections[ConnectionIdx].bValidated = true;
//		NetworkMgr.Connections[ConnectionIdx].CurrentSendHistoryIndex = LastHistoryFrameIndex;
//		NetworkMgr.Connections[ConnectionIdx].CurrentRecvHistoryIndex = LastHistoryFrameIndex;
//	}
//}
//
//exec function MPSetPauseGameStateSending(bool bPauseGameStateSending)
//{
//	local XComGameStateNetworkManager NetworkMgr;
//	NetworkMgr = `XCOMNETMANAGER;
//	NetworkMgr.SetPauseGameStateSending(bPauseGameStateSending);
//}
//
//exec function MPToggleGSNetworkDebugging()
//{
//	local XComGameStateNetworkManager NetworkMgr;
//	local bool bPause;
//	NetworkMgr = `XCOMNETMANAGER;
//	bPause = !NetworkMgr.bPauseGameStateSending;
//	NetworkMgr.SetPauseGameStateSending(bPause);
//	OutputMsg("Setting Network Game State Sending to:" @ `ShowVar(bPause));
//}

exec function DumpTeamData()
{
	local actor A;
	local int ActorCount;
	foreach AllActors(class'Actor', A)
	{
		++ActorCount;
		if (A.m_eTeam != eTeam_None)
		{
			OutputMsg("("$ActorCount$")"@A.Name@"-"@`ShowEnum(ETeam,A.m_eTeam,Team));
		}
	}
}

exec function DebugXp()
{
	bDebugXp = !bDebugXp;
	`log("Experience debugging is now" @ (bDebugXp ? "on." : "off."));
}

exec function ToggleLootFountain()
{
	bDisableLootFountain = !bDisableLootFountain;
	`log("Loot Fountaining is now" @ (bDisableLootFountain ? "DISABLED." : "ENABLED."));
}

exec function ToggleSoldierRelationshipXp()
{
	bDebugSoldierRelationships = !bDebugSoldierRelationships;
	`log("Soldier Relationship debugging is now" @ (bDebugSoldierRelationships ? "on." : "off."));
}

exec function ErrorReport()
{	
	local TInputDialogData kData;
	local PlayerController PC;

	if( !class'Engine'.static.IsRetailGame() || class'Engine'.static.IsConsoleAllowed())
	{
		if (XComPlayerController(Outer).Pres.ScreenStack.GetScreen(class'UIRedScreen') == none)
		{
			PC = GetALocalPlayerController();
			if (PC != none)
			{
				if (PC.PlayerInput != none)
				{
					PC.PlayerInput.ResetInput();
				}
			}
		
			kData.strTitle = "Error Report";
			kData.iMaxChars = 500;
			kData.strInputBoxText = "Enter a title above, describe the issue within this text field, and press 'Confirm' to create an error report.";
			kData.fnCallbackAccepted_report = OnErrorReportInputBoxClosed;
			kData.DialogType = eDialogType_Report;

			XComPlayerController(Outer).Pres.UIInputDialog(kData);
		}
		else
		{
			GenerateErrorReport("Redscreen", "");
		}
	}
}

function OnErrorReportInputBoxClosed(string title, string text, bool bSendCrashInfo)
{
	//Title goes into the file path, so sanitize it
	ErrorReportTitle = class'UIUtilities'.static.SanitizeFilenameFromUserInput(title);
	ErrorReportText = text;	
	m_bSendCrashInfo = bSendCrashInfo;


	//Slight delay before submitting the report so we have time to let the dialog close down ( so it isn't in our screen shot )
	XComPlayerController(Outer).Pres.SetTimer(0.1f, false, nameof(DelayGenerateReport), self);
}

function DelayGenerateReport()
{
	GenerateErrorReport(ErrorReportTitle, ErrorReportText, m_bSendCrashInfo);
}

function native GenerateErrorReport(string ErrorTitle, string ErrorInformationText, bool bSendCrashInfo = false);

function OnCaptureFinished(TextureRenderTarget2D RenderTarget)
{
	`log("Operate with the finished render target" @RenderTarget.GetSurfaceWidth());
}

// Test function for requesting a render from a SceneCapture2DActor
exec function TestCharacterCapture()
{
	local TextureRenderTarget2D RenderTarget;
	local SceneCapture2DActor CaptureActor;
	
	RenderTarget = class'TextureRenderTarget2D'.static.Create(128,128);
	
	foreach WorldInfo.AllActors(class'SceneCapture2DActor', CaptureActor)
	{
		CaptureActor.CaptureByTag('CharacterCapture', RenderTarget, OnCaptureFinished);
	}
}

exec function AIReinitBehaviors()
{
	`BEHAVIORTREEMGR.InitBehaviors();
}

exec function X2ForceBiome(string InForceBiome)
{
	`PARCELMGR.ForceBiome = InForceBiome;
}

exec function X2ForceLighting(string InForceLighting)
{
	`PARCELMGR.ForceLighting = InForceLighting;
}

exec function UnsuppressMP()
{
	ConsoleCommand("unsuppress DevOnline");
	ConsoleCommand("unsuppress DevNet");
	ConsoleCommand("unsuppress XCom_Online");
	ConsoleCommand("unsuppress XCom_Net");
	ConsoleCommand("unsuppress XCom_NetDebug");
	ConsoleCommand("unsuppress Rand");
}

exec function X2DebugDeckNames()
{
	class'X2CardManager'.static.GetCardManager().DebugDeckNames();
}

exec function X2DebugDeck(string DeckName)
{
	class'X2CardManager'.static.GetCardManager().DebugDeck(name(DeckName));
}

exec function TestMissionNarrative(string MissionType, optional name QuestItemTemplateName = '')
{
	local X2MissionNarrativeTemplateManager Manager;
	local XComPlayerController PlayerController;
	local X2MissionNarrativeTemplate NarrativeTemplate;
	local Console ViewportConsole;
	local string Text;

	Manager = class'X2MissionNarrativeTemplateManager'.static.GetMissionNarrativeTemplateManager();

	PlayerController = XComPlayerController(`XWORLDINFO.GetALocalPlayerController());
	if(PlayerController == none) return;

	ViewportConsole = LocalPlayer(PlayerController.Player).ViewportClient.ViewportConsole;

	NarrativeTemplate = Manager.FindMissionNarrativeTemplate(MissionType, QuestItemTemplateName);
	if(NarrativeTemplate == none)
	{
		ViewportConsole.OutputText("Could not find a matching narrative template");
	}

	foreach NarrativeTemplate.ObjectiveTextPools(Text)
	{
		ViewportConsole.OutputText(Text);
	}
}

exec function ChallengeModeSwitchProvider(bool bUseMCP)
{
	local XComChallengeModeManager Manager;
	Manager = `CHALLENGEMODE_MGR;
	// mmg_adrian.williams DNA - Replacing Firaxis Live with DNA
	`log(`location @ "WARNING: This function may not work as intended due to the removal of Firaxis Live.", , 'DNADeprecated');
	Manager.SetSystemInterface(`XENGINE.MCPManager); //(bUseMCP) ? `XENGINE.MCPManager : `FXSLIVE );
	OutputMsg("ChallengeModeSwitchProvider:" @ `ShowVar(bUseMCP) @ `ShowVar(Manager.GetSystemInterface(), SystemInterface));
}

exec function X2MPRequestValidationReport(optional int ConnectionIdx=-1)
{
	local XComGameStateNetworkManager NetworkMgr;
	NetworkMgr = `XCOMNETMANAGER;
	if (NetworkMgr.Connections.Length > 0 && ConnectionIdx < NetworkMgr.Connections.Length)
	{
		NetworkMgr.AddReceiveMirrorHistoryDelegate(OnReceiveMirrorHistory);
		NetworkMgr.RequestMirrorHistory((ConnectionIdx >= 0) ? ConnectionIdx : 0);
	}
}

function OnReceiveMirrorHistory(XComGameStateHistory History, X2EventManager EventManager)
{
	local XComGameStateNetworkManager NetworkMgr;
	NetworkMgr = `XCOMNETMANAGER;
	NetworkMgr.ClearReceiveMirrorHistoryDelegate(OnReceiveMirrorHistory);
	NetworkMgr.GenerateValidationReport(History, EventManager);
}

exec function X2MPGenerateValidationReport(optional int ConnectionIdx=-1)
{
	local XComGameStateNetworkManager NetworkMgr;
	NetworkMgr = `XCOMNETMANAGER;
	if (NetworkMgr.Connections.Length > 0 && ConnectionIdx < NetworkMgr.Connections.Length)
	{
		NetworkMgr.GenerateValidationReport(NetworkMgr.Connections[(ConnectionIdx >= 0) ? ConnectionIdx : 0].HistoryMirror, NetworkMgr.Connections[(ConnectionIdx >= 0) ? ConnectionIdx : 0].EventManagerMirror);
	}
}

exec function X2MPOfflineReport(string NameOfSaveFileOne, string NameOfSaveFileTwo)
{
	local XComGameStateNetworkManager NetworkMgr;
	NetworkMgr = `XCOMNETMANAGER;
	NetworkMgr.GenerateOfflineValidationReport(NameOfSaveFileOne, NameOfSaveFileTwo);
	OutputMsg("Done.");
}

exec function X2MPOfflineReportForDir(string DirectoryName)
{
	local XComGameStateNetworkManager NetworkMgr;
	NetworkMgr = `XCOMNETMANAGER;
	NetworkMgr.GenerateOfflineValidationReportForDirectory(DirectoryName);
	OutputMsg("Done.");
}

exec function X2MPRebuildLocalStateObjectCache()
{
	local X2TacticalMPGameRuleset Ruleset;
	Ruleset = X2TacticalMPGameRuleset(`TACTICALRULES);
	Ruleset.RebuildLocalStateObjectCache();
}

exec function UpdateRegionMesh(string RegionName, vector NewLocation, float NewScale)
{
	local UIStrategyMapItem_Region A;
	local XComGameState_WorldRegion LandingSite;
	local Name SiteName;

	foreach WorldInfo.AllActors(class'UIStrategyMapItem_Region', A)
	{
		LandingSite = XComGameState_WorldRegion(`XCOMHISTORY.GetGameStateForObjectID(A.GeoscapeEntityRef.ObjectID));
		SiteName = LandingSite.GetMyTemplateName();

		if( A != none && SiteName == name(RegionName) )
		{
			A.UpdateRegion(NewLocation.X, NewLocation.Y, NewScale);
		}
	}
}

exec function TemporarilyDisableRedscreens()
{
	`XENGINE.TemporarilyDisableRedscreens();
}

/** Dump all analytics stats **/
exec function DumpAnalyticsStats()
{
	local XComGameStateHistory	History;
	local XComGameState_Analytics Analytics;

	History = `XCOMHISTORY;
		Analytics = XComGameState_Analytics(History.GetSingleGameStateObjectForClass(class'XComGameState_Analytics', true));

	if (Analytics != None)
	{
		Analytics.DumpValues();
	}
}

exec function DebugTriggerEvent(Name EventID)
{
	local XComGameState NewGameState;

	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Cheat" @ GetFuncName() @ EventID);
	`XEVENTMGR.TriggerEvent(EventID, , , NewGameState);
	`GAMERULES.SubmitGameState(NewGameState);
}

exec function SetDifficulty(EDifficultyLevel NewDifficulty)
{
	local XComGameStateHistory History;
	local XComGameState NewGameState;
	local XComGameState_CampaignSettings CampaignSettingsStateObject;

	if( NewDifficulty < 4 )
	{
		History = `XCOMHISTORY;
			CampaignSettingsStateObject = XComGameState_CampaignSettings(History.GetSingleGameStateObjectForClass(class'XComGameState_CampaignSettings'));

		NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Changing User-Selected Difficulty to " $ NewDifficulty);

		CampaignSettingsStateObject = XComGameState_CampaignSettings(NewGameState.ModifyStateObject(class'XComGameState_CampaignSettings', CampaignSettingsStateObject.ObjectID));
		CampaignSettingsStateObject.SetDifficulty(NewDifficulty);

		`GAMERULES.SubmitGameState(NewGameState);
	}
}

exec function SetCustomDifficulty(float TacticalDifficulty, float StrategyDifficulty, float GameLength)
{
	local XComGameStateHistory History;
	local XComGameState NewGameState;
	local XComGameState_CampaignSettings CampaignSettingsStateObject;

	History = `XCOMHISTORY;
		CampaignSettingsStateObject = XComGameState_CampaignSettings(History.GetSingleGameStateObjectForClass(class'XComGameState_CampaignSettings'));

	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Changing User-Selected Difficulty to Custom");

	CampaignSettingsStateObject = XComGameState_CampaignSettings(NewGameState.ModifyStateObject(class'XComGameState_CampaignSettings', CampaignSettingsStateObject.ObjectID));
	CampaignSettingsStateObject.SetDifficulty(
		4,
		TacticalDifficulty,
		StrategyDifficulty,
		GameLength);

	`GAMERULES.SubmitGameState(NewGameState);
}


exec function AddTacticalGameplayTag(Name GameplayTag)
{
	local UITacticalQuickLaunch QuickLaunchUI;
	local XComGameStateHistory History;
	local XComGameState NewGameState;
	local XComGameState_HeadquartersDio DioHQ;

	History = `XCOMHISTORY;
	DioHQ = `DioHQ;

	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Adding Tactical Gameplay Tag " $ GameplayTag);
	DioHQ = XComGameState_HeadquartersDio(History.GetSingleGameStateObjectForClass(class'XComGameState_HeadquartersDio'));
	DioHQ = XComGameState_HeadquartersDio(NewGameState.ModifyStateObject(class'XComGameState_HeadquartersDio', DioHQ == None ? -1 : DioHQ.ObjectID));
	DioHQ.TacticalGameplayTags.AddItem(GameplayTag);
	`GAMERULES.SubmitGameState(NewGameState);

	QuickLaunchUI = UITacticalQuickLaunch(XComPlayerController(Outer).Pres.ScreenStack.GetScreen(class'UITacticalQuickLaunch'));

	QuickLaunchUI.TacticalGameplayTags.AddItem(GameplayTag);
}

exec function RemoveTacticalGameplayTag(Name GameplayTag)
{
	local UITacticalQuickLaunch QuickLaunchUI;
	local XComGameStateHistory History;
	local XComGameState NewGameState;
	local XComGameState_HeadquartersDio DioHQ;

	History = `XCOMHISTORY;
	DioHQ = `DioHQ;

	DioHQ = XComGameState_HeadquartersDio(History.GetSingleGameStateObjectForClass(class'XComGameState_HeadquartersDio'));
	if(DioHQ.TacticalGameplayTags.Find(GameplayTag) != INDEX_NONE )
	{

		NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Removing Tactical Gameplay Tag " $ GameplayTag);
		DioHQ = XComGameState_HeadquartersDio(NewGameState.ModifyStateObject(class'XComGameState_HeadquartersDio', DioHQ == None ? -1 : DioHQ.ObjectID));
		DioHQ.TacticalGameplayTags.RemoveItem(GameplayTag);
		`GAMERULES.SubmitGameState(NewGameState);
		QuickLaunchUI = UITacticalQuickLaunch(XComPlayerController(Outer).Pres.ScreenStack.GetScreen(class'UITacticalQuickLaunch'));
		QuickLaunchUI.TacticalGameplayTags.RemoveItem(GameplayTag);
	}
}

exec function PrintTacticalGameplayTags()
{
	local XComGameState_HeadquartersDio DioHQ;
	local name TacticalTag;
	local string TagList;

	DioHQ = `DioHQ;;
	TagList = "\n-------------------------------------\nACTIVE TACTICAL TAGS:";

	foreach DioHQ.TacticalGameplayTags(TacticalTag)
	{
		TagList $= "\n" $ TacticalTag;
	}

	TagList $= "\n-------------------------------------\n";
	`log(TagList);
}

exec function RemoveAllTacticalGameplayTags()
{
	local XComGameStateHistory History;
	local XComGameState NewGameState;
	local XComGameState_HeadquartersXCom XComHQ;

	History = `XCOMHISTORY;

	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("CHEAT: RemoveAllTacticalGameplayTags");
	XComHQ = XComGameState_HeadquartersXCom(History.GetSingleGameStateObjectForClass(class'XComGameState_HeadquartersXCom'));
	XComHQ = XComGameState_HeadquartersXCom(NewGameState.ModifyStateObject(class'XComGameState_HeadquartersXCom', XComHQ.ObjectID));
	XComHQ.TacticalGameplayTags.Length = 0;
	`GAMERULES.SubmitGameState(NewGameState);
}

exec native function SaveTemplateConfig();

exec function StartObjective(name ObjectiveName, bool bForceStart)
{
	local XComGameStateHistory History;
	local XComGameState_Objective ObjectiveState;
	local XComGameState NewGameState;

	History = `XCOMHISTORY;
		NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("CHEAT: Force Complete Objective");

	foreach History.IterateByClassType(class'XComGameState_Objective', ObjectiveState)
	{
		if (ObjectiveState.GetMyTemplateName() == ObjectiveName)
		{
			ObjectiveState = XComGameState_Objective(NewGameState.ModifyStateObject(class'XComGameState_Objective', ObjectiveState.ObjectID));
			ObjectiveState.StartObjective(NewGameState, bForceStart);
			ObjectiveState.RevealObjective(NewGameState);
		}
	}

	if (NewGameState.GetNumGameStateObjects() > 0)
	{
		`XCOMGAME.GameRuleset.SubmitGameState(NewGameState);
	}
	else
	{
		History.CleanupPendingGameState(NewGameState);
	}
}

exec function ForceCompleteObjective(name ObjectiveName)
{
	local XComGameStateHistory History;
	local XComGameState_Objective ObjectiveState;
	local XComGameState NewGameState;

	History = `XCOMHISTORY;
		NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("CHEAT: Force Complete Objective");

	foreach History.IterateByClassType(class'XComGameState_Objective', ObjectiveState)
	{
		if (ObjectiveState.GetMyTemplateName() == ObjectiveName)
		{
			ObjectiveState = XComGameState_Objective(NewGameState.ModifyStateObject(class'XComGameState_Objective', ObjectiveState.ObjectID));
			ObjectiveState.CompleteObjective(NewGameState);
		}
	}

	if (NewGameState.GetNumGameStateObjects() > 0)
	{
		`XCOMGAME.GameRuleset.SubmitGameState(NewGameState);
	}
	else
	{
		History.CleanupPendingGameState(NewGameState);
	}
}

exec function X2TestLoadManagerContent()
{
	class'X2ItemTemplateManager'.static.GetItemTemplateManager().LoadAllContent();
	class'X2CharacterTemplateManager'.static.GetCharacterTemplateManager().LoadAllContent();
	class'X2BodyPartTemplateManager'.static.GetBodyPartTemplateManager().LoadAllContent();
}

exec function X2ClearVisualizationHangs()
{
	`XCOMVISUALIZATIONMGR.DebugClearHangs();
}

exec function X2ResetMy2KConversionAttempts(optional bool bResetSession=false)
{
	local XComOnlineProfileSettings Settings;
	Settings = `XPROFILESETTINGS;
	`log(`location @ `ShowVar(Settings.SessionAttemptedMy2KConversion) @ `ShowVar(Settings.Data.NumberOfMy2KConversionAttempts));
	if( bResetSession )
	{
		Settings.SessionAttemptedMy2KConversion = false;
	}
	Settings.Data.NumberOfMy2KConversionAttempts = 0;
	`ONLINEEVENTMGR.SaveProfileSettings();
}

exec function X2DumpAnalytics( optional bool bGlobals = true, optional bool bTactical = true )
{
	local XComGameState_Analytics AnalyticsObject;
	local XComGameStateHistory History;

	History = `XCOMHISTORY;

	AnalyticsObject = XComGameState_Analytics( History.GetSingleGameStateObjectForClass( class'XComGameState_Analytics', true ) );
	if (AnalyticsObject == none)
	{
		OutputMsg( "No Analytics found in History." );
		return;
	}

	if (bGlobals)
	{
		AnalyticsObject.DumpValues( );
	}

	if (bTactical)
	{
		AnalyticsObject.DumpTacticalValues( );
	}

	OutputMsg( "Done." );
}

exec function FiraxisLiveToggleAutoLogin()
{
	// mmg_adrian.williams DNA - Replacing Firaxis Live with DNA
	//local X2FiraxisLiveClient LiveClient;
	//LiveClient = `FXSLIVE;
	//LiveClient.bCHEATDisableAutoLogin = !LiveClient.bCHEATDisableAutoLogin;
	//`log(`location @ `ShowVar(LiveClient.bCHEATDisableAutoLogin, bCHEATDisableAutoLogin));
}

exec function ToggleAutosavePerAction()
{
	bShouldAutosaveBeforeEveryAction = !bShouldAutosaveBeforeEveryAction;
	`log("bShouldAutosaveBeforeEveryAction = "$bShouldAutosaveBeforeEveryAction);
}

exec function DisableLost()
{
	RemoveTacticalGameplayTag('SITREP_TheLost');
}

exec function EnableLost()
{
	AddTacticalGameplayTag('SITREP_TheLost');
}

exec function BondSoldiers(string UnitNameA, string UnitNameB, optional bool bSetBond = true)
{
	local XComGameStateHistory History;
	local XComGameState_HeadquartersXCom XComHQ;
	local XComGameState NewGameState;
	local XComGameState_Unit UnitState, BondmateA, BondmateB;
	local SoldierBond Bond;
	local int DesiredCohesion;
	local string CheckUnitName;

	History = `XCOMHISTORY;
	XComHQ = XComGameState_HeadquartersXCom(History.GetSingleGameStateObjectForClass(class'XComGameState_HeadquartersXCom'));
	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("CHEAT: BondSoldiers");

	foreach History.IterateByClassType(class'XComGameState_Unit', UnitState)
	{
		if(UnitState.GetTeam() == eTeam_XCom || XComHQ.Crew.Find('ObjectID', UnitState.ObjectID) != INDEX_NONE)
		{
			CheckUnitName = UnitState.GetFullName();
			if(CheckUnitName ~= UnitNameA)
			{ 
				BondmateA = XComGameState_Unit(NewGameState.ModifyStateObject(class'XComGameState_Unit', UnitState.ObjectID));
			}
			else if(CheckUnitName ~= UnitNameB)
			{
				BondmateB = XComGameState_Unit(NewGameState.ModifyStateObject(class'XComGameState_Unit', UnitState.ObjectID));
			}
		}
	}

	BondmateA.GetBondData(BondmateB.GetReference(), Bond);
	if(BondmateA != none && BondmateB != none && (Bond.BondLevel + 1) < class'X2StrategyGameRulesetDataStructures'.default.CohesionThresholds.Length)
	{
		DesiredCohesion = class'X2StrategyGameRulesetDataStructures'.default.CohesionThresholds[Bond.BondLevel + 1];

		if(DesiredCohesion > Bond.Cohesion)
		{
			class'X2StrategyGameRulesetDataStructures'.static.ModifySoldierCohesion(BondmateA, BondmateB, (DesiredCohesion - Bond.Cohesion), true);
		}

		if(bSetBond)
		{
			class'X2StrategyGameRulesetDataStructures'.static.SetBondLevel(BondmateA, BondmateB, (Bond.BondLevel + 1));
		}

		`XCOMGAME.GameRuleset.SubmitGameState(NewGameState);
	}
	else
	{
		History.CleanupPendingGameState(NewGameState);
	}
}

exec function ActivatePolicyCard( string PolicyName )
{
	local XComGameStateHistory History;
	local X2StrategyElementTemplateManager TemplateManager;
	local X2StrategyCardTemplate PolicyTemplate;
	local XComGameState NewGameState;
	local XComGameState_StrategyCard PolicyState;
	local XComGameState_HeadquartersResistance ResHQ;

	History = `XCOMHISTORY;

	TemplateManager = class'X2StrategyElementTemplateManager'.static.GetStrategyElementTemplateManager();
	PolicyTemplate = X2StrategyCardTemplate( TemplateManager.FindStrategyElementTemplate( name(PolicyName) ) );

	if (PolicyTemplate == none)
		return;

	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("CHEAT: ActivatePolicyCard");

	PolicyState = PolicyTemplate.CreateInstanceFromTemplate( NewGameState );
	PolicyState.bDrawn = true;

	ResHQ = XComGameState_HeadquartersResistance( History.GetSingleGameStateObjectForClass( class'XComGameState_HeadquartersResistance' ) );
	ResHQ = XComGameState_HeadquartersResistance( NewGameState.ModifyStateObject( class'XComGameState_HeadquartersResistance', ResHQ.ObjectID ) );

	ResHQ.WildCardSlots.AddItem( PolicyState.GetReference() );

	PolicyState.ActivateCard( NewGameState );

	`XCOMGAME.GameRuleset.SubmitGameState(NewGameState);
}

exec function Ryantest()
{
	ConsoleCommand("suppress all");
	ConsoleCommand("unsuppress xcom_anim");
	ConsoleCommand("SetXComAnimUnitName xgunit_0");
	ConsoleCommand("x2debugvisualizers");	
}

exec function ToggleMonkey()
{
	bMonkeyRun = !bMonkeyRun;
	`Log(`ShowVar(bMonkeyRun));
	if( bMonkeyRun && !IsTimerActive(nameof(MonkeyTimer) ))
	{
		if( GeneralPlayerController == None )
		{
			GeneralPlayerController = WorldInfo.GetALocalPlayerController();
		}
		if( GeneralPlayerController.bTickIsDisabled )
		{
			GeneralPlayerController.SetTickIsDisabled(false);
		}
		if( PriorityInput.Length == 0 )
		{
			InitPriorityInput();
		}
		GeneralPlayerController.SetTimer(1.0f, false, nameof(MonkeyTimer), self);
	}
}

function InitPriorityInput()
{
	PriorityInput.Length = 0;
	PriorityInput.AddItem(class'UIUtilities_Input'.const.FXS_KEY_ENTER);
	PriorityInput.AddItem(class'UIUtilities_Input'.const.FXS_KEY_ENTER);
	PriorityInput.AddItem(class'UIUtilities_Input'.const.FXS_KEY_ENTER);
	PriorityInput.AddItem(class'UIUtilities_Input'.const.FXS_KEY_ESCAPE);
	PriorityInput.AddItem(class'UIUtilities_Input'.const.FXS_KEY_ESCAPE);
	PriorityInput.AddItem(class'UIUtilities_Input'.const.FXS_ARROW_UP);
	PriorityInput.AddItem(class'UIUtilities_Input'.const.FXS_ARROW_RIGHT);
	PriorityInput.AddItem(class'UIUtilities_Input'.const.FXS_ARROW_DOWN);
	PriorityInput.AddItem(class'UIUtilities_Input'.const.FXS_ARROW_LEFT);
}

exec function SayText(string Text, bool bMaleVoice)
{
	`PRESBASE.Speak(Text, bMaleVoice);
}

function MonkeyTimer()
{
	local int RandInput, Range;
	if( bMonkeyRun )
	{
		RandInput = class'UIUtilities_Input'.const.FXS_KEYBOARD_RANGE_BEGIN;
		if( Rand(100) < 33 )
		{
			Range = class'UIUtilities_Input'.const.FXS_KEYBOARD_RANGE_END - class'UIUtilities_Input'.const.FXS_KEYBOARD_RANGE_BEGIN;
			RandInput = class'UIUtilities_Input'.const.FXS_KEYBOARD_RANGE_BEGIN + Rand(Range);
		}
		if( (RandInput == class'UIUtilities_Input'.const.FXS_KEYBOARD_RANGE_BEGIN)
			|| (RandInput > class'UIUtilities_Input'.const.FXS_KEY_RIGHT_ALT && RandInput < class'UIUtilities_Input'.const.FXS_KEY_HOME )
		    || (RandInput > class'UIUtilities_Input'.const.FXS_KEY_PAGEDN && RandInput < class'UIUtilities_Input'.const.FXS_KEY_F1)
		    || (RandInput > class'UIUtilities_Input'.const.FXS_KEY_NUMPAD_0 && RandInput <= class'UIUtilities_Input'.const.FXS_KEYBOARD_RANGE_END))
		{
			RandInput = PriorityInput[Rand(PriorityInput.Length)];
		}
		XComInputBase(GeneralPlayerController.PlayerInput).InputEvent(RandInput);
		XComInputBase(GeneralPlayerController.PlayerInput).InputEvent(RandInput, class'UIUtilities_Input'.const.FXS_ACTION_RELEASE);

		GeneralPlayerController.SetTimer(0.1f, false, nameof(MonkeyTimer), self);
	}
}

exec function GiveTraitToUnit(Name TraitTemplateName, string UnitName)
{
	local XComGameState_Unit UnitState;
	local XComGameState NewGameState;
	local XComGameStateHistory History;
	local XComGameState_HeadquartersXCom XComHQ;
	local string CheckUnitName;

	History = `XCOMHISTORY;
	XComHQ = XComGameState_HeadquartersXCom(History.GetSingleGameStateObjectForClass(class'XComGameState_HeadquartersXCom'));

	foreach History.IterateByClassType(class'XComGameState_Unit', UnitState)
	{
		if( UnitState.GetTeam() == eTeam_XCom || XComHQ.Crew.Find('ObjectID', UnitState.ObjectID) != INDEX_NONE )
		{
			CheckUnitName = UnitState.GetFullName();
			if( CheckUnitName ~= UnitName )
			{
				NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Adding trait " $ TraitTemplateName $ " to unit: " $ UnitName);
				UnitState = XComGameState_Unit(NewGameState.ModifyStateObject(class'XComGameState_Unit', UnitState.ObjectID));
				UnitState.AcquireTrait(NewGameState, TraitTemplateName, true);

				`XCOMGAME.GameRuleset.SubmitGameState(NewGameState);
				return;
			}
		}
	}
}

exec function AddSoldierKillsToKillCount()
{
	local XComGameState NewGameState;
	local XComGameStateHistory History;
	local XComGameState_Unit UnitState;
	local int OldKillCount;

	History = `XCOMHISTORY;
	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("CHEAT: AddSoldierKillsToKillCount");

	foreach History.IterateByClassType(class'XComGameState_Unit', UnitState)
	{
		if (UnitState.IsSoldier() && UnitState.IsAlive())
		{
			OldKillCount = UnitState.GetKills().Length;

			// Only allow the kill count to be modified once
			if (OldKillCount > UnitState.KillCount)
			{
				UnitState = XComGameState_Unit(NewGameState.ModifyStateObject(class'XComGameState_Unit', UnitState.ObjectID));
				UnitState.KillCount += UnitState.GetKills().Length;
				UnitState.KillAssistsCount = UnitState.GetKillAssists().Length;
			}
		}
	}

	`XCOMGAME.GameRuleset.SubmitGameState(NewGameState);
}

exec function PhotoboothSetBGColorOverride(bool bOverride)
{
	`PHOTOBOOTH.SetBackgroundColorOverride(bOverride);
}

exec function PhotoboothSetBGColor(bool bSetColor1, float R, float G, float B)
{
	local LinearColor NewColor;

	NewColor.R = R; NewColor.G = G; NewColor.B = B;

	if (bSetColor1)
	{
		`PHOTOBOOTH.SetGradientColor1(NewColor);
	}
	else
	{
		`PHOTOBOOTH.SetGradientColor2(NewColor);
	}
}

exec function ResetMissionSiteEncounterData( )
{
	local XComGameStateHistory History;
	local XComGameState_MissionSite MissionSite, NewMissionSite;
	local XComGameState NewGameState;

	History = `XCOMHISTORY;

	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Cheat: Resetting Mission Site Encounter Data");

	foreach History.IterateByClassType( class'XComGameState_MissionSite', MissionSite )
	{
		NewMissionSite = XComGameState_MissionSite( NewGameState.ModifyStateObject( MissionSite.Class, MissionSite.ObjectID ) );

		NewMissionSite.SelectedMissionData.SelectedMissionScheduleName = '';
		NewMissionSite.SelectedMissionData.SelectedEncounters.Length = 0;
	}

	`XCOMGAME.GameRuleset.SubmitGameState(NewGameState);
}

exec function SetSoundtrack(int SoundtrackNum)
{
	switch (SoundtrackNum)
	{
	case 0: `SOUNDMGR.SetState('SoundtrackGame', 'XComUFO'); break;
	case 1: `SOUNDMGR.SetState('SoundtrackGame', 'XCom1'); break;
	case 2: `SOUNDMGR.SetState('SoundtrackGame', 'XCom2'); break;
	}
}

exec function X2DebugCameraObstacles()
{
	bDebugCameraObstacleHiding = !bDebugCameraObstacleHiding;
}

exec function X2DebugCameras()
{
	bDebugCameras = !bDebugCameras;
}

exec function DioScreenshot(string ScreenshotName)
{
	class'Engine'.static.GetEngine().CaptureScreenshotPNG(ScreenshotName);
}

// dforrest (6.13.17): debug support for deleting all save games
exec function DeleteAllSaves()
{
	`ONLINEEVENTMGR.DeleteAllSaves();
}
// dforrest (6.13.17): end

exec function PlayDialogue(name Concept, optional int SpeakerObjectID = -1, optional bool bEnableCheatMode = false)
{
	local XComGameState_Unit UnitState;
	local X2EventManager EventManager;
	local XComGameStateHistory History;

	History = `XCOMHISTORY;
	EventManager = `XEVENTMGR;

	UnitState = (SpeakerObjectID == -1) ? none : XComGameState_Unit (History.GetGameStateForObjectID(SpeakerObjectID));

	bUsedPlayDialogueCheat = bEnableCheatMode;

	EventManager.TriggerEvent(Concept, none, UnitState);
}

exec function PlayChatterLineByAkEvent(name AkEvent, optional bool bTriggerFollowUp = false)
{
	local XComGameState_DialogueManager DialogueManager;
	local XComGameStateHistory History;

	bUsedPlayDialogueCheat = true;

	History = `XCOMHISTORY;
	DialogueManager = XComGameState_DialogueManager(History.GetSingleGameStateObjectForClass(class'XComGameState_DialogueManager'));
	DialogueManager.CheatPlayLineByAkEvent(AkEvent, bTriggerFollowUp);
}

exec function DebugChatter()
{
	if (`SCREENSTACK.HasInstanceOf(class'UIDebugChatter'))
	{
		`SCREENSTACK.PopFirstInstanceOfClass(class'UIDebugChatter', true);
	}
	else
	{
		`SCREENSTACK.Push(Spawn(class'UIDebugChatter'));
	}
}

exec function DioForceVisTreeUpdate()
{
	//Trigger a report to the vis tree debugging tool
	`XCOMVISUALIZATIONMGR.bReportNodeStates = true;
}

exec function SkipCurrentVO()
{
	local XComGameState_DialogueManager DialogueManager;
	local XComGameStateHistory History;

	History = `XCOMHISTORY;
	DialogueManager = XComGameState_DialogueManager(History.GetSingleGameStateObjectForClass(class'XComGameState_DialogueManager'));
	DialogueManager.SkipCurrentVOLine();
}

exec function StopCurrentConversation()
{
	local XComGameState_DialogueManager DialogueManager;
	local XComGameStateHistory History;

	History = `XCOMHISTORY;
	DialogueManager = XComGameState_DialogueManager(History.GetSingleGameStateObjectForClass(class'XComGameState_DialogueManager'));
	DialogueManager.StopCurrentConversation();
}

exec function StartWwiseProfiler()
{
	`SOUNDMGR.StartWwiseProfiler();
}

exec function StopWwiseProfiler()
{
	`SOUNDMGR.StopWwiseProfiler();
}

exec function DebugProceduralEncounters(int RoomCount = 3, name DarkEventTag = '', name FactionID = 'Progeny')
{
	local EnemyFactionForceLevelInfo FactionForceLevelInfo;
	local EnemyFactionSpawnInfo FactionSpawnInfo;
	local array<EnemyFactionSpawnInfo> LocalFactionSpawnInfos;
	local array<EnemyFactionForceLevelInfo> LocalFactionForceLevelInfos;
	local XComGameState_EncounterData EncounterData;
	local array<ConfigurableEncounter> ConfigedRoomEncoutners, ConfigedReinforcementEncounters;
	local int AlertLevel;
	local array<int> RoomIDs;
	local XComGameState NewGameState;
	local int i, j;
	local int MaxForceLevel, MaxAlertLevel;
	local XComGameState_HeadquartersDio DioHQ;

	MaxForceLevel = 6;
	MaxAlertLevel = 9;

	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Debug Procedural Encounters");
	EncounterData = XComGameState_EncounterData(NewGameState.CreateNewStateObject(class'XComGameState_EncounterData'));
	DioHQ = XComGameState_HeadquartersDio(NewGameState.CreateNewStateObject(class'XComGameState_HeadquartersDio'));

	for (i = 0; i < RoomCount; i++)
	{
		RoomIDs.AddItem(i);
	}

	if (FactionForceLevelInfos.Length < 1)
	{
		FactionForceLevelInfo.FactionID = FactionID;
		FactionForceLevelInfo.ForceLevel = 1;
		LocalFactionForceLevelInfos.AddItem(FactionForceLevelInfo);

		FactionSpawnInfo.FactionID = FactionID;
		FactionSpawnInfo.Weight = 100;
		LocalFactionSpawnInfos.AddItem(FactionSpawnInfo);
	}
	else
	{
		LocalFactionForceLevelInfos = FactionForceLevelInfos;
		LocalFactionSpawnInfos = FactionSpawnInfos;
	}
	
	AlertLevel = max(1, StartingAlertLevel);

	if (DarkEventTag != '')
	{
		DioHQ.TacticalGameplayTags.AddItem(DarkEventTag);
	}

	for (i = 0; i < MaxAlertLevel; i++)
	{
		for (j = 0; j < 3; j++)
		{
			`SPAWNMGR.BuildEncounters(AlertLevel, LocalFactionForceLevelInfos, RoomIDs, DioHQ, LocalFactionSpawnInfos, EncounterData, ConfigedRoomEncoutners, ConfigedReinforcementEncounters);

			EncounterData.OutputDebugLog();
		}

		`log("--------------------------------------------------------------------------");

		// increase spawn params
		if (LocalFactionForceLevelInfos[0].ForceLevel < MaxForceLevel)
		{
			for (i = 0; i < LocalFactionForceLevelInfos.length; i++)
			{
				LocalFactionForceLevelInfos[i].ForceLevel++;
			}
		}
	
		AlertLevel++;
	}


	// no need to submit
	`XCOMHISTORY.CleanupPendingGameState(NewGameState);
}

exec function SetFactionSpawnData(name FactionID, int ForceLevel, int SpawnWeight)
{
	local EnemyFactionForceLevelInfo FactionForceLevelInfo;
	local EnemyFactionSpawnInfo FactionSpawnInfo;

	FactionForceLevelInfo.FactionID = FactionID;
	FactionForceLevelInfo.ForceLevel = ForceLevel;

	FactionSpawnInfo.FactionID = FactionID;
	FactionSpawnInfo.Weight = SpawnWeight;

	FactionForceLevelInfos.AddItem(FactionForceLevelInfo);
	FactionSpawnInfos.AddItem(FactionSpawnInfo);
	
	DumpFactionSpawnData();
}

exec function SetFactionSpawnAlertLevel(int AlertLevel = 1)
{
	StartingAlertLevel = AlertLevel;

	DumpFactionSpawnData();
}

exec function DumpFactionSpawnData()
{
	local int i;
	local EnemyFactionForceLevelInfo FactionForceLevelInfo;
	local EnemyFactionSpawnInfo FactionSpawnInfo;

	OutputMsg("Current Spawn Data: Alert Level:" @ StartingAlertLevel);
	for (i = 0; i < FactionForceLevelInfos.Length; i++)
	{
		FactionForceLevelInfo = FactionForceLevelInfos[i];
		FactionSpawnInfo = FactionSpawnInfos[i];

		OutputMsg(FactionForceLevelInfo.FactionID @ ":" @ "Force Level:" @ FactionForceLevelInfo.ForceLevel @ "Spawn Ratio:" @ FactionSpawnInfo.Weight);
	}
}

exec function ClearFactionSpawnData(optional bool bResetAlertLevel = false)
{
	FactionForceLevelInfos.length = 0;
	FactionSpawnInfos.length = 0;

	if (bResetAlertLevel)
	{
		StartingAlertLevel = 1;
	}
}

exec function DioPreloadMap(string mapname)
{
	`MAPS.PreloadMap(mapname);
}


exec function ToggleLogChannel(name Channel,  bool Enable = true)
{
	class'Helpers'.static.ToggleLogChannel(Channel, !Enable);
}

exec function EvaluateDialogTag(name TagName)
{
	local X2DialogueElementTemplateManager DialogTemplateManager;
	local X2DialogueTagTemplate DialogTemplate;
	local RuleTemplateData NoneValue;
	local XComGameState_DialogueManager DialogManager;
	local XComGameStateHistory History;

	History = `XCOMHISTORY;
	DialogManager = XComGameState_DialogueManager(History.GetSingleGameStateObjectForClass(class'XComGameState_DialogueManager'));
	DialogTemplateManager = class'X2DialogueElementTemplateManager'.static.GetDialogueElementTemplateManager();
	DialogTemplate = DialogTemplateManager.FindDialogueTagTemplate(TagName);
	DialogTemplate.IsConditionMet(NoneValue, none, none, none, DialogManager);
}

native exec function ReloadDialogData();

defaultproperties
{
	bUseGlamCam = true;
	bShowCamCage = false;
	m_strGlamCamName = "NONE";
	m_bUseGlamBlend = true;
	bUseAIGlamCam = true;
	m_bStrategyAllFacilitiesAvailable = false;
	m_bStrategyAllFacilitiesFree = false;
	m_bStrategyAllFacilitiesInstaBuild = false;
	bDebuggingVisibilityToCursor = false;
	bDebugFOW = false;
	m_bAllowShields = true;
	m_bAllowAbortBox = true;
	m_bAllowTether = true;

	bDebugVisualizers = false;
	bDebugHistory = false;
	bDebugRuleset = false;
	bDebugXp = false;
	bDebugSoldierRelationships = false;
	bLightDebugRealtime = true;
	m_DebugAimsTeam = eTeam_All;

	StartingAlertLevel = 1;
}
