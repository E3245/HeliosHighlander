//---------------------------------------------------------------------------------------
//  FILE:    XComOnlineEventMgr.uc
//  AUTHOR:  Ryan McFall  --  08/17/2011
//  PURPOSE: This object is designed to contain the various callbacks and delegates that
//           respond to online systems changes such as login/logout, storage device selection,
//           controller changes, and others
//           
//---------------------------------------------------------------------------------------
//  Copyright (c) 2016 Firaxis Games, Inc. All rights reserved.
//---------------------------------------------------------------------------------------
class XComOnlineEventMgr extends OnlineEventMgr
	dependson(UIDialogueBox)
	dependson(UIProgressDialogue)
	dependson(XComErrorMessageMgr)
	native;

enum EOnlineStatusType
{
	OnlineStatus_PlayingTheGame,
	OnlineStatus_Strategy,
	OnlineStatus_TacticalProgeny,
	OnlineStatus_TacticalSacredCoil,
	OnlineStatus_TacticalGrayPhoenix
};

//
// enum of all achievements/trophies
//
// Note: DO NOT INSERT OR REMOVE ENUMS! Rename entries or append new at the end.
//
enum EAchievementType
{
	eAchievement_HeroesOfCity31,					// Win the campaign
	eAchievement_ImpossibleDream,					// Win the campaign on Impossible difficulty
	eAchievement_PhoenixDown,						// Complete the Gray Phoenix Investigation
	eAchievement_SacredFoiled,						// Complete the Sacred Coil Investigation
	eAchievement_ChildsPlay,						// Complete the Progeny Investigation
	eAchievement_ReinforcedSteel,					// Replace an Agent mid-mission with an Android
	eAchievement_ANewLook,							// Launch a mission with no human agents in the squad
	eAchievement_CityOnFire,						// Complete the tutorial
	eAchievement_AndClear,							// Clear an entire encounter during the Breach turn
	eAchievement_UseTheLargeCuffs,					// Capture a Praetorian
	eAchievement_CagedSword,						// Capture a Ronin
	eAchievement_BottledLightning,					// Capture a Sorcerer
	eAchievement_ChimeraUnleashed,					// Use every Agent in at least one mission.
	eAchievement_FieldCommander,						// Unlock a Region Bonus
	eAchievement_SuperiorFirepower,					// Equip an Epic Weapon
	eAchievement_HammerAndTongs,					// Complete 20 Assembly projects
	eAchievement_MachineLearning,					// Fully upgrade an Android
	eAchievement_FriendlyNeighborhoodXCOM,			// Build Field Teams in all districts
	eAchievement_AllHandsOnDeck,					// 8 Agents in squad
	eAchievement_ThankYouForYourBusiness,			// Buy 20 unique items from Scavenger Market
	eAchievement_Overqualified,						// Train every specialty
	eAchievement_BookSmart,							// Complete an Agent's class training
	eAchievement_EveryTimeline,						// Complete every version of each Investigation
	eAchievement_NoStoneLeftUnturned,				// Complete every Spec Op
	eAchievement_IWillLetMyselfIn ,					// Use every type of Breach point
	eAchievement_ExtraHours,						// After activating Overtime, get a kill/capture with Godmother on the current turn and the extra Overtime turn.
	eAchievement_MakestheDreamWork,					// Complete a mission objective with an Agent gifted an action by Terminal�s Cooperation.
	eAchievement_Impregnable,						// Have Kinetic Armor on all 4 squad members at once.
	eAchievement_MindNuke,							// Use Verge to do 10 or more damage (across multiple ene mies) with one Mindflay.
	eAchievement_ChainReaction,						// Use Claymore to detonate a Shrapnel grenade with another explosive.
	eAchievement_DucksInARow,						// Use Blueblood to hit 3 or more enemies with one Phase Lance shot.
	eAchievement_KillSwitch,						// Use Patchwork to hack an enemy Android and trigger its Self-Destruct.
	eAchievement_DaisyChain,						// Use Relocate on the same unit with both Shelter and Shelter�s ghost from Fracture on the same turn.
	eAchievement_Brawler,							// Use Zephyr to hit 3 or more enemies with one use of Crowd Control.
	eAchievement_WatchyourStep,						// Use Torque to Tongue Pull an enemy into poison.
	eAchievement_AngerManagement,					// Kill an enemy with Axiom while Berserk.
	eAchievement_ArmyOfOne,							// Complete a mission with only one Agent left standing
	eAchievement_PacifistRoute,						// Complete a mission without killing a single enemy
	eAchievement_UpCloseAndPersonal,				// Complete an encounter by only dealing damage with melee attacks.
	eAchievement_NeedALift							// Move the same VIP with Shelter�s Relocate and Torque�s Tongue Pull on a mission.
};

const LowestCompatibleCheckpointVersion = 23;
const CheckpointVersion = 23;
const StorageRemovalWarningDelayTime = 1.0; // needed to prevent us from showing this on the very first frame if we pulled the storage device during load

//bsg-cballinger (3.20.17): BEGIN, Laz and Ozzy DLC names
const Laz_Name = "Lazarus";
const DLC_4_Name = "DLC_4";
//bsg-cballinger (3.20.17): END
struct native TMPLastMatchInfo_Player
{
	var UniqueNetId     m_kUniqueID;
	var bool            m_bMatchStarted;
	var int             m_iWins;
	var int             m_iLosses;
	var int             m_iDisconnects;
	var int             m_iSkillRating;
	var int             m_iRank;

	structdefaultproperties
	{
		m_bMatchStarted = false;
		m_iWins = -1;
		m_iLosses = -1;
		m_iDisconnects = -1;
		m_iSkillRating = -1;
		m_iRank = -1;
	}
};

struct native TMPLastMatchInfo
{
	var bool                        m_bIsRanked;
	var bool                        m_bAutomatch;
	var int                         m_iMapPlotType;
	var int                         m_iMapBiomeType;
	var EMPNetworkType              m_eNetworkType;
	var EMPGameType                 m_eGameType;
	var int                         m_iTurnTimeSeconds;
	var int                         m_iMaxSquadCost;
	var TMPLastMatchInfo_Player     m_kLocalPlayerInfo;
	var TMPLastMatchInfo_Player     m_kRemotePlayerInfo;
};

var XComErrorMessageMgr ErrorMessageMgr; //bsg-cballinger (10.13.16): Added so we can centralize error message tracking/displaying

var TMPLastMatchInfo                m_kMPLastMatchInfo;

var Engine LocalEngine;
var XComMCP MCP;
var XComCopyProtection CopyProtection;
var XComOnlineStatsReadDeathmatchRanked m_kStatsRead;
var XComPlayerController m_kStatsReadPlayerController;
var privatewrite bool m_bStatsReadInProgress;
var privatewrite bool m_bStatsReadSuccessful;

var privatewrite int     StorageDeviceIndex;
var privatewrite string  StorageDeviceName;
var privatewrite bool    bHasStorageDevice;
var privatewrite bool    bStorageSelectPending;
var privatewrite bool    bLoginUIPending;
//var privatewrite bool    bSaveDeviceWarningPending;
var privatewrite float   fSaveDeviceWarningPendingTimer; // to wait a few frames before showing the message, makes sure we don't show it the very first frame before things look decent
var privatewrite bool    bInShellLoginSequence;
var privatewrite bool    bExternalUIOpen;
var privatewrite bool    bUpdateSaveListInProgress;
var bool                 bWarnedOfOnlineStatus;
var bool                 bWarnedOfOfflineStatus;
var bool                 bAcceptedInviteDuringGameplay;

// Login Requirements
var privatewrite bool    bRequireLogin;
var privatewrite bool    bAllowInactiveProfiles;

var privatewrite bool          bOnlineSubIsSteamworks;
var privatewrite bool          bOnlineSubIsPSN;
var privatewrite bool          bOnlineSubIsLive;
//<workshop> CONSOLE_OSS wchen 10/28/2015
//INS:
var privatewrite bool		   bOnlineSubIsDingo;
var privatewrite bool		   bOnlineSubIsNP;
//</workshop>
var privatewrite ELoginStatus  LoginStatus;	
var privatewrite bool          bHasLogin;
var privatewrite bool          bHasProfileSettings;
var privatewrite bool          bShowingLoginUI;
//var privatewrite bool          bShowingLossOfDataWarning;
//var privatewrite bool          bShowingLoginRequiredWarning;
//var privatewrite bool          bShowingLossOfSaveDeviceWarning;
var privatewrite bool          bShowSaveIndicatorForProfileSaves;
var privatewrite bool          bCancelingShellLoginDialog;
var privatewrite bool          bMCPEnabledByConfig;
var privatewrite bool          bSaveDataOwnerErrHasShown;
var privatewrite bool          bSaveDataOwnerErrPending;
var privatewrite bool          bDelayDisconnects;
var privatewrite bool          bDisconnectPending;
var privatewrite bool          bConfigIsUpToDate;

var privatewrite EOnlineStatusType OnlineStatus;

var privatewrite bool			bProfileDirty; //Marks profile as needing to be saved. Used for deferred saving, preventing multiple requests from issuing multiple tasks in a single frame.
var privatewrite bool			bForceShowSaveIcon; //Saved option for deferred profile saving, indiciating if SaveIcon needs to be shown.

var bool bSaveExplanationScreenHasShown;
var private int                m_iCurrentGame;

var bool bPerformingStandardLoad;       //True when loading a normal saved game - ie. from player storage
var int  LoadGameContentCacheIndex;     //Index in the content cache to use during a standard load
var bool bPerformingTransferLoad;       //True when loading a strategy game from 'StrategySaveData', ie when going from a tactical game to the strategy
var init array<byte> TransportSaveData; //Stores the transport save blob for going between strategy & tactical
var init array<byte> StrategySaveData;  //Stores the strategy save blob while we are in a tactical game
var int StrategySaveDataCheckpointVersion; //Saves the version of the checkpoint system used to create the strategy save date blob
var init array<byte> SaveLoadBuffer;    //Scratch for loading / saving

var bool PendingSaveGameDataDeletes; //bsg-jneal (7.12.17): adding check if a save game delete is running to prevent a race condition where the delete might not complete until after the subsequent save had finished
var privatewrite transient array<string> PendingDeleteSaveFilenames;

//This flag is set to true when loading a saved game via the replay option, and cleared when that load is cancelled, or the load succeeds and the replay system is activated
var bool bInitiateReplayAfterLoad;
var bool bInitiateValidationAfterLoad;	//Start the validator after loading the map.
var bool bIsChallengeModeGame;			//True if this game is started from Challenge Mode.
var int  ChallengeModeSeedGenNum;		//Greater than 0 is auto-generating Challenge Start State #
var bool bGenerateMapForSkirmish;

// Campaign Settings to pass to Strategy Start after the tutorial
var string CampaignStartTime;
var int CampaignDifficultySetting;
var int CampaignLowestDifficultySetting;
var float CampaignTacticalDifficulty;
var float CampaignStrategyDifficulty;
var float CampaignGameLength;
var bool CampaignbIronmanEnabled;
var bool CampaignbTutorialEnabled;
var bool CampaignbXPackNarrativeEnabled;
var bool CampaignbIntegratedDLCEnabled;
var bool CampaignbSuppressFirstTimeNarrative;
var array<name> CampaignSecondWaveOptions;
var array<name> CampaignRequiredDLC;
var array<name> CampaignOptionalNarrativeDLC;

var bool bTutorial;  // Actively running the tutorial in Demo Direct mode using the replay system
var bool bDemoMode;	// Demo mode uses the Tutorial Code path but doesn't not draw helper markers
var bool bAutoTestLoad;

//A stable of checkpoints used for nefarious purposes.
var Checkpoint CurrentTacticalCheckpoint; //Holds a currently loading tactical checkpoint, for the purposes of bringing in kismet at a point later 
										  //than when the actors are serialized in. USED FOR LOADING

var bool CheckpointIsSerializing;
var bool CheckpointIsWritingToDisk;
var bool ProfileIsSerializing;
var Checkpoint StrategyCheckpoint;        //These hold a checkpoint that is currently being saved - the saving process happens asynchronously, so
var Checkpoint TacticalCheckpoint;	      //the online event mgr holds a reference until the save is done
var Checkpoint TransportCheckpoint;
var XComGameState SummonSuperSoldierGameState;
var XComGameState_Unit ConvertedSoldierState;

var private bool bAchivementsEnabled;
var bool bAchievementsDisabledXComHero;     // Achievements have been disabled because we are using an easter egg XCom Hero

var private bool bShuttleToMPPlayTogetherLoadout; // bsg-fchen (7/25/16): Updating supports for play together
var bool bCanPlayTogether; //bsg-fchen (8/22/16): Update Play Together to handle single player cases
var bool bDoNotProcessNetworkIssues; //bsg-fchen (5.31.17): Adding a flag to prevent network handling to be processed while in the Rise of the Resistance bink movie
var bool bIsReturningToStartScreen;
var bool bLoginUIRequestedByPlayer;
var bool bGameInviteProfileNeedsConfirmation;

//bsg-jneal (6.24.17): no state for new game non-tutorial, adding bool to keep track
var bool m_bInMessageBlockingScreenTransition; 
var bool m_bNeedsNewDLCInstalledMessage;
//bsg-jneal (6.24.17): end

//bsg-jrucker (8/16/16): Cached game invite accepted results
var private OnlineGameSearchResult mInviteResult;
var private bool mbInviteWasSuccessful;
var private EOnlineServerConnectionStatus mInviteStatus;
var private bool mbCurrentlyHandlingInvite;
//bsg-jrucker (8/16/16): End.

var private int DLCWatchVarHandle;

var localized string	m_strLadderFormatString;
var localized string    m_strIronmanFormatString;
var localized string    m_sCampaignInfoFormatString;
var localized string	m_strTacticalAutosaveFormatString;
var localized string	m_strTacticalSessionStartFormatString;
var localized string	m_strTacticalEncounterStartFormatString;
var localized string	m_strStrategyAutosaveFormatString;
var localized string	m_strStrategyTurnStartFormatString;
var localized string	m_strQuicksaveTacticalFormatString;
var localized string	m_strQuicksaveStrategyFormatString;
var localized string	m_strStrategySaveGameInfo;
var localized string    m_strIronmanLabel;
var localized string    m_strAutosaveLabel;
var localized string    m_strQuicksaveLabel;
var localized string    m_strGameLabel;
var localized string    m_strSaving;
var localized string    m_sLoadingProfile;
var localized string    m_sLoadingProfileDialogText; //bsg-jedwards (5.22.17) : Moved file into appropriate header
var localized string    m_sLossOfDataTitle;
var localized string    m_sLossOfDataWarning;
var localized string    m_sLossOfDataWarning360;
var localized string    m_sNoStorageDeviceSelectedWarning;
var localized string    m_sLoginWarning;
var localized string    m_sLoginWarningPC;
var localized string    m_sLossOfSaveDeviceWarning;
var localized string    m_strReturnToStartScreenLabel;
var localized string    m_sInactiveProfileMessage;
var localized string    m_sLoginRequiredMessage;
var localized string    m_sCorrupt;
var localized string	m_sXComHeroSummonTitle;
var localized string	m_sXComHeroSummonText;
//<workshop> SCI 2016/4/5
var localized string m_sXComHeroSummonTextOrbis;
//</workshop>
var localized string    m_sSaveDataOwnerErrPS3;
var localized string    m_sSaveDataHeroErrPS3;
var localized string    m_sSaveDataHeroErr360PC;
var localized string    m_sSlingshotDLCFriendlyName;
var localized string    m_sEliteSoldierPackDLCFriendlyName;
var localized string    m_sEmptySaveString;
var localized string	m_sCampaignString;

// My2K status messages
var localized string My2k_Offline;
var localized string My2k_Link;
var localized string My2k_Unlink;

//<workshop> CONSOLE_DLC RJM 2016/04/14
//INS:
var localized string m_sDLCInstalledDingo;
var localized string m_sDLCInstalledOrbis;
//</workshop>

// bsg-nlong (9.1.16) 6917: Adding two new strings for the newly installed DLC dialog if the player is on the main menu
var localized string m_sNewDLCInstalledDingo;
var localized string m_sNewDLCInstalledOrbis;
// bsg-nlong (9.1.16) 6917: end

// <workshop> LOCALIZED DLC NAMES 2016-05-19
// INS:
var localized string m_sDLC0Name;
var localized string m_sDLC1Name;
var localized string m_sDLC2Name;
var localized string m_sDLC3Name;
var localized string m_sDLC4Name; //bsg-cballinger (3.20.17): add Ozzy DLC name
// </workshop>

//<workshop> CORRUPT_CHARACTER_POOL RJM 2016/04/18
//INS:
var localized string m_sCorruptedCharacterPool;
//</workshop>
//<workshop> DISPLAYING_AUTOSAVE_MESSAGE kmartinez 2016-04-19
//INS:
var localized string m_sWarningAutoSave;
//</workshop>

// bsg-nlong (9.29.16) 4427: localized string and string length for swea replacements
// Be sure to updatae FilterTextReplacementLength in DefaultProperties
var localized string FilterTextReplacements[11];
var int FilterTextReplacementLength;
// bsg-nlong (9.29.16) 4427: end

//<workshop> SAVE_INDICATOR_PLACEMENT kmartinez 2016-04-19
//INS:
var float m_saveIndicatorDisplayTimeOnDialogBox;
var float m_saveIndicatorDisplayTimeNormaly;
var float m_saveIndicatorXPct_OnDialogBox;
var float m_saveIndicatorYPct_OnDialogBox;
var float m_saveIndicatorXPct_InStrategyMode;
var float m_saveIndicatorYPct_InStrategyMode;
var float m_saveIndicatorXPct_InTacticalMode;
var float m_saveIndicatorYPct_InTacticalMode;
//</workshop>

// Used by the UI to allow players to provide a custom save description
var private string m_sCustomSaveDescription;

var			string m_sReplayUserID;
var			string m_sLastReplayMapCommand;

// Rich Presence Strings
var localized string m_aRichPresenceStrings[EOnlineStatusType]<BoundEnum=EOnlineStatusType>;

var privatewrite ELoginStatus m_eNewLoginStatusForDestroyOnlineGame_OnLoginStatusChange;
var privatewrite UniqueNetId  m_kNewIdForDestroyOnlineGame_OnLoginStatusChange;

var private array< delegate<ShellLoginComplete> > m_BeginShellLoginDelegates;
var private array< delegate<SaveProfileSettingsComplete> > m_SaveProfileSettingsCompleteDelegates;
var private array< delegate<UpdateSaveListStarted> >  m_UpdateSaveListStartedDelegates;
var private array< delegate<UpdateSaveListComplete> > m_UpdateSaveListCompleteDelegates;
//<workshop> CONSOLE JPS 2015/11/20
// The delegate type OnlinePlayerInterface.OnLoginStatusChange is abstract and not usable here.
//WAS:
//var private array< delegate<OnlinePlayerInterface.OnLoginStatusChange> > m_LoginStatusChangeDelegates;
var private array< delegate<OnLoginStatusChange> > m_LoginStatusChangeDelegates;
//</workshop>
var private array< delegate<OnConnectionProblem> > m_ConnectionProblemDelegates;
var private array< delegate<OnSaveDeviceLost> > m_SaveDeviceLostDelegates;

var private array< delegate<OnPlayTogetherStarted> > m_PlayTogetherStartedDelegates; //bsg-jneal (7.17.16): Play Together hack for ORBIS

// Challenge Mode Data
var array<INT>          m_ChallengeModeEventMap;

// cached array of DLCs
var bool m_bCheckedForInfos;
var array<X2DownloadableContentInfo> m_cachedDLCInfos;

//<workshop> RICH_PRESENCE_ENABLE kmartinez 2016-2-24
//INS:
var private bool HasInitializedRichPresenceText;
//</workshop>

// bsg-dforrest (9.13.16): track async save time elapsed
var private transient double AsyncSaveDupStartTime;
// bsg-dforrest (9.13.16): end

// mmg_aaron.lee (06/12/19) BEGIN - added to track current save status
var private bool CurrSaveStatus;
var private bool PrevSaveStatus;
// mmg_aaron.lee (06/12/19) END

// Helper function for dealing with pre localized dates
native static function bool ParseTimeStamp(String TimeStamp, out int Year, out int Month, out int Day, out int Hour, out int Minute);

//External delegates
//==================================================================================================================

//Delegates for external users - ie. the UI wants to know when something finishes
delegate SaveProfileSettingsComplete(bool bWasSuccessful);
delegate UpdateSaveListStarted();
delegate UpdateSaveListComplete(bool bWasSuccessful);
delegate ReadSaveGameComplete(bool bWasSuccessful);
delegate WriteSaveGameComplete(bool bWasSuccessful);
delegate ShellLoginComplete(bool bWasSuccessful); // Called when the shell login sequence has completed
delegate OnConnectionProblem();
delegate OnSaveDeviceLost();
//<workshop> CONSOLE JPS 2015/11/20
//INS:
delegate OnLoginStatusChange(ELoginStatus NewStatus,UniqueNetId NewId);
//</workshop>

delegate OnPlayTogetherStarted(); //bsg-jneal (7.17.16): Play Together hack for ORBIS

//Initialization
//==================================================================================================================

event Init()
{
	super.Init();

	LocalEngine = class'Engine'.static.GetEngine();

	bOnlineSubIsLive       = OnlineSub.Class.Name == 'OnlineSubsystemLive';
	bOnlineSubIsSteamworks = OnlineSub.Class.Name == 'OnlineSubsystemSteamworks';
	bOnlineSubIsPSN        = OnlineSub.Class.Name == 'OnlineSubsystemPSN';
//<workshop> CONSOLE_OSS wchen 10/28/2015
//INS:
	bOnlineSubIsDingo	   = OnlineSub.Class.Name == 'OnlineSubsystemDingo';
	bOnlineSubIsNP         = OnlineSub.Class.Name == 'OnlineSubsystemNP';
//</workshop>

	// mmg_aaron.lee (06/12/19) BEGIN - init saveStatus
	CurrSaveStatus = false;
	PrevSaveStatus = false;
	// mmg_aaron.lee (06/12/19) END

	//Handle the editor / PIE case
	if(OnlineSub == none)
	{
		bOnlineSubIsSteamworks = true;
	}

	//bsg-cballinger (10.13.16): Added so we can centralize error message tracking/displaying, initialize here
	if(ErrorMessageMgr == none)
	{
		ErrorMessageMgr = new class'XComErrorMessageMgr';
	}

	// Profile saves on Xbox 360 take less than 500 ms so we don't need a save indicator per TCR 047.
	// Showing the indicator when we don't need to actually causes more bugs because of timing requirements.
	// On other platforms we show the save indicator because it is a better user experience.
	bShowSaveIndicatorForProfileSaves = false;//!class'WorldInfo'.static.IsConsoleBuild(CONSOLE_Xbox360);

	// Login Requirements

	// We require the user to be logged into a gamer profile on Xbox 360
	bRequireLogin = `ISCONSOLE;

	// There has been a lot of debate about whether or not logins should be
	// allowed on inactive controllers. We ultimately decided they should
	// be but if the decision changes all we need to do is change this bool.
	bAllowInactiveProfiles = true;

	// On PC subscribe to read profile settings early so we can check our input settings before the shell login sequence
	if( !`ISCONSOLE )
	{
		// Set the initial state of the controller
		super.SetActiveController(0);

		OnlineSub.PlayerInterface.AddReadProfileSettingsCompleteDelegate(LocalUserIndex, ReadProfileSettingsCompleteDelegate);
		OnlineSub.PlayerInterface.AddReadPlayerStorageCompleteDelegate(LocalUserIndex, ReadPlayerStorageCompleteDelegate);
	}
	//<workshop> CONSOLE_DLC RJM 2016/04/14
	//INS:
	//OnlineSub.ContentInterface.AddContentChangeDelegate(OnContentChange); bsg-nlong: Adding this delegate got moved to UIShell OnInit. Could cause issues in multiplayer?

// bsg-nlong (9.29.16) 4427: Set the array of strings currently used as substitutes for swears to a localized array in this class
// using the this class to hold the localized array as OnlineSubsystemDingo is not currently set up to handle localized strings
	initReplacementStrings();

}

function initReplacementStrings()
{
	local int i;

	for(i = 0; i < FilterTextReplacementLength; ++i )
	{
		OnlineSub.FilterTextReplacements.AddItem(FilterTextReplacements[i]);
	}
}
// bsg-nlong (9.29.16) 4427: end

function EvalName(XComGameState_Unit TestUnit)
{
	local name SuperSoldierID;
	local int SoldierIndex;

	if(`GAME != none && TestUnit.IsSoldier() && TestUnit.GetMyTemplateName() == 'Soldier')
	{
		if(TestUnit.GetFirstName() == "Sid" && TestUnit.GetLastName() == "Meier")
		{
			SuperSoldierID = 'Sid';
		}
		else if(TestUnit.GetNickName(true) == "Beaglerush")
		{
			SuperSoldierID = 'Beagle';
		}
		else if(TestUnit.GetFirstName() == "Peter" && TestUnit.GetLastName() == "Van Doorn")
		{
			SuperSoldierID = 'Peter';
		}

		if(SuperSoldierID != '')
		{
			for(SoldierIndex = 0; SoldierIndex < class'UITacticalQuickLaunch_MapData'.default.Soldiers.Length; ++SoldierIndex)
			{
				if(class'UITacticalQuickLaunch_MapData'.default.Soldiers[SoldierIndex].SoldierID == SuperSoldierID)
				{
					PromptSummonSuperSoldier(class'UITacticalQuickLaunch_MapData'.default.Soldiers[SoldierIndex], TestUnit);
					break;
				}
			}
		}
	}
}

//bsg-cballinger (11.7.16): BEGIN, Added, so platform-specific functions can be set to use system dialogs for some messages instead of in-game dialogs
event SetSystemMessageDelegates(delegate<XComErrorMessageMgr.SystemMessageTick> tick, delegate<XComErrorMessageMgr.HandledAsSystemMessage> handler)
{
	ErrorMessageMgr.SystemMessageTick = tick;
	ErrorMessageMgr.HandledAsSystemMessage = handler;
}
//bsg-cballinger (11.7.16): END

//Transform a regular soldier into a super soldier
function PromptSummonSuperSoldier(ConfigurableSoldier SoldierConfig, XComGameState_Unit ExistingSoldier)
{
	local StateObjectReference SuperSoldierRef;

	SummonSuperSoldierGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Make Super Soldier");
	ConvertedSoldierState = XComGameState_Unit(SummonSuperSoldierGameState.ModifyStateObject(ExistingSoldier.Class, ExistingSoldier.ObjectID));
	ConvertedSoldierState.bIsSuperSoldier = true;
	
	//Change the existing soldier in the the selected super soldier
	//****************************************************************
	ConvertedSoldierState.SetSoldierClassTemplate(SoldierConfig.SoldierClassTemplate);
	SuperSoldier_UpdateUnit(SoldierConfig, ConvertedSoldierState, SummonSuperSoldierGameState);
	if(ConvertedSoldierState.GetMyTemplate().RequiredLoadout != '')
	{
		ConvertedSoldierState.ApplyInventoryLoadout(SummonSuperSoldierGameState, ConvertedSoldierState.GetMyTemplate().RequiredLoadout);
	}
	SuperSoldier_AddFullInventory(SoldierConfig, SummonSuperSoldierGameState, ConvertedSoldierState);
	//****************************************************************

	//Submit the change
	`XCOMGAME.GameRuleset.SubmitGameState(SummonSuperSoldierGameState);

	SuperSoldierRef = ConvertedSoldierState.GetReference();
	
	`HQPRES.GetPhotoboothAutoGen().AddHeadShotRequest(SuperSoldierRef, 512, 512, ShowSuperSoldierAlert);
	`HQPRES.GetPhotoboothAutoGen().RequestPhotos();
}

private simulated function ShowSuperSoldierAlert(StateObjectReference UnitRef)
{
	local Texture2D StaffPicture;
	local XComGameState_CampaignSettings SettingsState;

	SettingsState = XComGameState_CampaignSettings(`XCOMHISTORY.GetSingleGameStateObjectForClass(class'XComGameState_CampaignSettings'));
	StaffPicture = `XENGINE.m_kPhotoManager.GetHeadshotTexture(SettingsState.GameIndex, UnitRef.ObjectID, 512, 512);

	`HQPRES.SuperSoldierAlert(UnitRef, SuperSoldierAlertCB, class'UIUtilities_Image'.static.ValidateImagePath(PathName(StaffPicture)));
}

simulated function SuperSoldier_AddFullInventory(ConfigurableSoldier SoldierConfig, XComGameState GameState, XComGameState_Unit Unit)
{
	// Add inventory
	Unit.bIgnoreItemEquipRestrictions = true;
	Unit.MakeItemsAvailable(GameState, false); // Drop all of their existing items
	Unit.EmptyInventoryItems(); // Then delete whatever was still in their inventory
	SuperSoldier_AddItemToUnit(GameState, Unit, SoldierConfig.PrimaryWeaponTemplate);
	SuperSoldier_AddItemToUnit(GameState, Unit, SoldierConfig.SecondaryWeaponTemplate);
	SuperSoldier_AddItemToUnit(GameState, Unit, SoldierConfig.ArmorTemplate);
	SuperSoldier_AddItemToUnit(GameState, Unit, SoldierConfig.HeavyWeaponTemplate);
	SuperSoldier_AddItemToUnit(GameState, Unit, SoldierConfig.BreachItemTemplate);
	SuperSoldier_AddItemToUnit(GameState, Unit, SoldierConfig.UtilityItem1Template);
	SuperSoldier_AddItemToUnit(GameState, Unit, SoldierConfig.UtilityItem2Template);
	Unit.bIgnoreItemEquipRestrictions = false;
}

simulated function SuperSoldier_AddItemToUnit(XComGameState NewGameState, XComGameState_Unit Unit, name EquipmentTemplateName)
{
	local XComGameState_Item ItemInstance;
	local X2EquipmentTemplate EquipmentTemplate;
	local X2ItemTemplateManager ItemTemplateManager;

	ItemTemplateManager = class'X2ItemTemplateManager'.static.GetItemTemplateManager();
	EquipmentTemplate = X2EquipmentTemplate(ItemTemplateManager.FindItemTemplate(EquipmentTemplateName));

	if(EquipmentTemplate != none)
	{
		ItemInstance = EquipmentTemplate.CreateInstanceFromTemplate(NewGameState);
		Unit.AddItemToInventory(ItemInstance, EquipmentTemplate.InventorySlot, NewGameState);
	}
}

simulated function SuperSoldier_UpdateUnit(ConfigurableSoldier SoldierConfig, XComGameState_Unit Unit, XComGameState UseGameState)
{
	local TSoldier Soldier;
	local int Index;
	local SCATProgression Progression;
	local array<SCATProgression> SoldierProgression;
	local array<SoldierClassAbilityType> AbilityTree;
	local X2SoldierClassTemplate UnitSoldierClassTemplate;
	local X2CharacterTemplate CivilianTemplate;//Get super soldier bios from the civilian character template
	local string RedScreenMsg;

	CivilianTemplate = class'X2CharacterTemplateManager'.static.GetCharacterTemplateManager().FindCharacterTemplate('Civilian');

	Soldier.kAppearance = Unit.kAppearance;
	if(SoldierConfig.SoldierID == 'Sid')
	{
		Soldier.kAppearance.nmPawn = 'XCom_Soldier_M';
		Soldier.kAppearance.iGender = 1;
		Soldier.kAppearance.nmHead = 'Supersoldier1_M';
		Soldier.kAppearance.nmHelmet = 'Helmet_0_NoHelmet_M';
		Soldier.kAppearance.nmHaircut = 'SidMeier_Hair';
		Soldier.kAppearance.nmBeard = 'MaleBeard_Blank';
		Soldier.kAppearance.nmEye = 'DefaultEyes';
		Soldier.kAppearance.nmTeeth = 'DefaultTeeth';
		Soldier.kAppearance.nmFacePropLower = 'Prop_FaceLower_Blank';
		Soldier.kAppearance.nmFacePropUpper = 'Prop_FaceUpper_Blank';
		Soldier.kAppearance.nmPatterns = 'Hex';
		Soldier.kAppearance.nmVoice = 'MaleVoice4_English_US';
		Soldier.kAppearance.nmTorso_Underlay = 'CnvUnderlay_Std_Torsos_A_M';
		Soldier.kAppearance.nmArms_Underlay = 'CnvUnderlay_Std_Arms_A_M';
		Soldier.kAppearance.nmLegs_Underlay = 'CnvUnderlay_Std_Legs_A_M';
		Unit.SetCharacterName(Unit.GetFirstName(), Unit.GetLastName(), "Godfather");
		Unit.SetCountry('Country_USA');
		Unit.SetBackground(CivilianTemplate.strCharacterBackgroundMale[0]);
		
	}
	else if(SoldierConfig.SoldierID == 'Beagle')
	{
		Soldier.kAppearance.nmPawn = 'XCom_Soldier_M';
		Soldier.kAppearance.iGender = 1;
		Soldier.kAppearance.nmHead = 'Supersoldier2_M';
		Soldier.kAppearance.nmHelmet = 'Helmet_0_NoHelmet_M';
		Soldier.kAppearance.nmHaircut = 'Beaglerush_Hair';
		Soldier.kAppearance.nmBeard = 'Beard_Beaglerush';
		Soldier.kAppearance.nmEye = 'DefaultEyes';
		Soldier.kAppearance.nmTeeth = 'DefaultTeeth';
		Soldier.kAppearance.iHairColor = 10;
		Soldier.kAppearance.nmFacePropLower = 'Prop_FaceLower_Blank';
		Soldier.kAppearance.nmFacePropUpper = 'Prop_FaceUpper_Blank';
		Soldier.kAppearance.nmPatterns = 'Camo_Digital';
		Soldier.kAppearance.nmVoice = 'MaleVoice1_English_UK';
		Soldier.kAppearance.nmTorso_Underlay = 'CnvUnderlay_Std_Torsos_A_M';
		Soldier.kAppearance.nmArms_Underlay = 'CnvUnderlay_Std_Arms_A_M';
		Soldier.kAppearance.nmLegs_Underlay = 'CnvUnderlay_Std_Legs_A_M';
		Unit.SetCharacterName("John", "Teasdale", Unit.SafeGetCharacterNickName());
		Unit.SetCountry('Country_Australia');
		Unit.SetBackground(CivilianTemplate.strCharacterBackgroundMale[1]);
	}
	else if(SoldierConfig.SoldierID == 'Peter')
	{
		Soldier.kAppearance.nmPawn = 'XCom_Soldier_M';
		Soldier.kAppearance.iGender = 1;
		Soldier.kAppearance.nmHead = 'Supersoldier3_M';
		Soldier.kAppearance.nmArms = 'PwrLgt_Std_D_M';
		Soldier.kAppearance.nmHelmet = 'Helmet_0_NoHelmet_M';
		Soldier.kAppearance.nmHaircut = 'VanDoorn_Hair';
		Soldier.kAppearance.nmBeard = 'ShortFullBeard';
		Soldier.kAppearance.nmEye = 'DefaultEyes';
		Soldier.kAppearance.nmTeeth = 'DefaultTeeth';
		Soldier.kAppearance.nmFacePropLower = 'Prop_FaceLower_Blank';
		Soldier.kAppearance.nmFacePropUpper = 'Prop_FaceUpper_Blank';
		Soldier.kAppearance.nmPatterns = 'Tigerstripe';
		Soldier.kAppearance.iTattooTint = 5;
		Soldier.kAppearance.iHairColor = 1;		
		Soldier.kAppearance.nmTattoo_LeftArm = 'Tattoo_Arms_05';
		Soldier.kAppearance.nmTattoo_RightArm = 'Tattoo_Arms_09';
		Soldier.kAppearance.nmVoice = 'MaleVoice9_English_US';
		Soldier.kAppearance.nmTorso_Underlay = 'CnvUnderlay_Std_Torsos_A_M';
		Soldier.kAppearance.nmArms_Underlay = 'CnvUnderlay_Std_Arms_A_M';
		Soldier.kAppearance.nmLegs_Underlay = 'CnvUnderlay_Std_Legs_A_M';
		Unit.SetCountry('Country_USA');		
		Unit.SetBackground(CivilianTemplate.strCharacterBackgroundMale[2]);
	}

	Unit.SetTAppearance(Soldier.kAppearance);
	Unit.SetSoldierClassTemplate(SoldierConfig.SoldierClassTemplate);
	Unit.ResetSoldierRank();
	for(Index = 0; Index < SoldierConfig.SoldierRank; ++Index)
	{
		Unit.RankUpSoldier(UseGameState, SoldierConfig.SoldierClassTemplate);
	}
	Unit.bNeedsNewClassPopup = false;
	UnitSoldierClassTemplate = Unit.GetSoldierClassTemplate();

	for(Progression.iRank = 0; Progression.iRank < UnitSoldierClassTemplate.GetMaxConfiguredRank(); ++Progression.iRank)
	{
		AbilityTree = Unit.GetRankAbilities(Progression.iRank);
		for(Progression.iBranch = 0; Progression.iBranch < AbilityTree.Length; ++Progression.iBranch)
		{
			if(SoldierConfig.EarnedClassAbilities.Find(AbilityTree[Progression.iBranch].AbilityName) != INDEX_NONE)
			{
				SoldierProgression.AddItem(Progression);
			}
		}
	}

	if(SoldierConfig.EarnedClassAbilities.Length != SoldierProgression.Length)
	{
		RedScreenMsg = "Soldier '" $ SoldierConfig.SoldierID $ "' has invalid ability definition: \n-> Configured Abilities:";
		for(Index = 0; Index < SoldierConfig.EarnedClassAbilities.Length; ++Index)
		{
			RedScreenMsg = RedScreenMsg $ "\n\t" $ SoldierConfig.EarnedClassAbilities[Index];
		}
		RedScreenMsg = RedScreenMsg $ "\n-> Selected Abilities:";
		for(Index = 0; Index < SoldierProgression.Length; ++Index)
		{
			AbilityTree = Unit.GetRankAbilities(SoldierProgression[Index].iRank);
			RedScreenMsg = RedScreenMsg $ "\n\t" $ AbilityTree[SoldierProgression[Index].iBranch].AbilityName;
		}
		`RedScreen(RedScreenMsg);
	}

	Unit.SetSoldierProgression(SoldierProgression);
	Unit.SetBaseMaxStat(eStat_UtilityItems, 2);
	Unit.SetCurrentStat(eStat_UtilityItems, 2);
}

simulated function SuperSoldierAlertCB(Name eAction, out DynamicPropertySet AlertData, optional bool bInstant = false)
{
	local XComGameStateHistory History;

	History = `XCOMHISTORY;
	switch(eAction)
	{
		case 'eUIAction_Accept':
			class'UICustomize'.static.CycleToSoldier(ConvertedSoldierState.GetReference());
			EnableAchievements(false, true);

			// If the soldier was staffed in a training slot, unstaff them and stop the project
			if (ConvertedSoldierState.StaffingSlot.ObjectID != 0)
			{
				ConvertedSoldierState.GetStaffSlot().EmptySlotStopProject();
			}
			break;
		case 'eUIAction_Cancel':
			History.ObliterateGameStatesFromHistory(1); //Undo if the user doesn't want this
			break;
	}
}


//Internal delegates
//==================================================================================================================

/** Called when a user signs in or out */
private simulated function LoginChangeDelegate(byte LocalUserNum)
{	
	local ELoginStatus InactiveUserLoginStatus;

	`log("LoginChange: " @`ShowVar(LocalUserNum) @ `ShowVar(OnlineSub.PlayerInterface.GetLoginStatus(LocalUserNum), LoginStatus) @ `ShowVar((OnlineSub.PlayerInterface.GetLoginStatus(LocalUserNum) != LS_NotLoggedIn), bHasLogin) , true, 'XCom_Online');

	if( LocalUserIndex == LocalUserNum )
	{
		RefreshLoginStatus();

		if( bInShellLoginSequence )
		{
			if( ErrorMessageMgr.ShowingLossOfDataWarning() || ErrorMessageMgr.ShowingLoginRequiredWarning())
			{
				// User logged in while the loss of data warning 
				// or Login Required dialog was up.  Cancel the
				// dialog and jump back to the user login
				// phase of the shell login sequence.
				CancelActiveShellLoginDialog();
				ShellLoginUserLoginComplete();
			}
			else if( bHasProfileSettings )
			{
				// User loggin changed at an unexpected time before
				// the shell login sequence could complete
				`log("Shell Login Failed: User login changed before completion.",,'XCom_Online');
				AbortShellLogin();
			}
			else
			{
				// User logged in at the expected time
				// in the shell login sequence.
				ShellLoginUserLoginComplete();
			}
		}
		else if( bHasProfileSettings )
		{
			`log("Login Changed",,'XCom_Online');

			// The user changed during gameplay.
			// Kick them back to the start screen.
			//<workshop> ACCOUNT_PICKER RJM 2016/03/17
			//WAS:
			//ReturnToStartScreen(QuitReason_SignOut);
			if(bLoginUIRequestedByPlayer)
			{
				//Don't go back to the start screen if this change 
				//is a result of the account picker on the main menu.
				BeginShellLogin(LocalUserNum);
			}
			else
			{
// mmg-ken.jordan (12-13-2019) BEGIN - TTP 5787 - Fix for signing out during APC leaving video, caused red-screen and assert when starting new game
				`log("Acting on user sign-out");

				if (`TACTICALRULES != None && `TACTICALRULES.GetStateName() == 'CreateTacticalGame')
				{
					`log("BUGFIX: In `TACTICALRULES.CreateTacticalGame state, so cleaning up History");
					`XCOMHISTORY.RemoveHistoryLock();	// this will not wrap below 0
					`XCOMHISTORY.ResetHistory();
				}
// mmg-ken.jordan (12-13-2019) END
				ReturnToStartScreen(QuitReason_SignOut);
			}
			bLoginUIRequestedByPlayer = false;
			//</workshop>
		}

		//bsg-cballinger (9.13.16): BEGIN, if the current user (LocalUserIndex) has a status change (e.g. logout/switch), leave all currently active sessions or the old sessions will not be cleaned up properly and prevent the player from joining new sessions 
		if(OnlineSub.GameInterface != none)
		{
			OnlineSub.GameInterface.LeaveAllOnlineSessions(true);
		}
		//bsg-cballinger (9.13.16): END
	}
	else
	{
		InactiveUserLoginStatus = OnlineSub.PlayerInterface.GetLoginStatus(LocalUserNum);
		if( InactiveUserLoginStatus != LS_NotLoggedIn )
		{
			if( bInShellLoginSequence && bShowingLoginUI )
			{
				// If an inactive profile chooses a login during the shell login sequence
				// then restart the login with that controller as active.
				`log("Shell Login: Restarting Shell Login Sequence. Inactive controller logged in.",,'XCom_Online');

				bInShellLoginSequence = false;
				BeginShellLogin(LocalUserNum);
			}
			else if( !bAllowInactiveProfiles && bHasProfileSettings )
			{
				// If inactive profiles are not allow then make sure that none are signed in
				ReturnToStartScreen(QuitReason_InactiveUser);
			}
		}
	}

	bShowingLoginUI = false;
}

function bool SaveInProgress()
{
	return ProfileIsSerializing || CheckpointIsSerializing;
}

/** Called if a user is prompted to log in but cancels */
private function LoginCancelledDelegate()
{
	`log("Login Cancelled",,'XCom_Online');

	bShowingLoginUI = false;

	RefreshLoginStatus();

	//<workshop> ACCOUNT_PICKER RJM 2016/03/17
	//INS:
	bLoginUIRequestedByPlayer = false;
	//</workshop>

	if( bInShellLoginSequence )
	{
		ShellLoginUserLoginComplete();
	}
}

//<workshop> ACCOUNT_PICKER RJM 2016/03/17
//INS:
private function LoginFailedDelegate(byte LocalUserNum,EOnlineServerConnectionStatus ErrorCode)
{
	bLoginUIRequestedByPlayer = false;
}
//</workshop>

/**
 * Delegate called when a player's status changes but doesn't change profiles
 *
 * @param NewStatus the new login status for the user
 * @param NewId the new id to associate with the user
 */
private simulated function LoginStatusChange(ELoginStatus NewStatus, UniqueNetId NewId)
{
	local OnlineGameSettings kGameSettings;
	`log(`location @ `ShowVar(NewStatus) @ `ShowVar(LocalUserIndex) @ "UniqueId=" $ class'OnlineSubsystem'.static.UniqueNetIdToString(NewId), true, 'XCom_Online');
	//<workshop> CONSOLE_MP JPS 2016/03/07
	//WAS:
	//if(OnlineSub != none && OnlineSub.GameInterface != none && OnlineSub.GameInterface.GetGameSettings('Game') != none)
	if(OnlineSub != none && OnlineSub.GameInterface != none &&
		(OnlineSub.GameInterface.GetGameSettings('Game') != none || OnlineSub.GameInterface.GetGameSettings('Lobby') != None))
	//</workshop>
	{
		// Is this a LAN Game Settings, and is it a host?  At which point we should ignore the destruction. -ttalley
		// BUG 21959: [ONLINE] - The host will be unable to successfully host or join a System Link/LAN match after the client disconnects their ethernet cable from a previous System Link/LAN match.
		kGameSettings = OnlineSub.GameInterface.GetGameSettings('Game');
		//<workshop> CONSOLE_MP JPS 2016/03/07
		//INS:
		if (kGameSettings == none)
		{
			kGameSettings = OnlineSub.GameInterface.GetGameSettings('Lobby');
		}
		//</workshop>
		if ( (kGameSettings == none) || ((kGameSettings != none) && (! kGameSettings.bIsLanMatch)) )
		{
			`log(`location @ "An online game settings exists, destroying before continuing...", true, 'XCom_Online');
			OnlineSub.GameInterface.AddDestroyOnlineGameCompleteDelegate(OnDestroyOnlineGameComplete_LoginStatusChange);
			//<workshop> CONSOLE_OSS JPS 2015/10/30
			//WAS:
			//if(OnlineSub.GameInterface.DestroyOnlineGame('Game'))
			if(OnlineSub.GameInterface.DestroyOnlineGame(LocalUserIndex, kGameSettings.SessionTemplateName ~= "Lobby" ? 'Lobby' : 'Game'))
			//</workshop>
			{
				m_eNewLoginStatusForDestroyOnlineGame_OnLoginStatusChange = NewStatus;
				m_kNewIdForDestroyOnlineGame_OnLoginStatusChange = NewId;
				`log(`location @ "Successfully created async task DestroyOnlineGame, waiting...", true, 'XCom_Online');
				return;
			}
			else
			{
				OnlineSub.GameInterface.ClearDestroyOnlineGameCompleteDelegate(OnDestroyOnlineGameComplete_LoginStatusChange);
				`warn(`location @ "Failed to create async task DestroyOnlineGame!");
			}
		}
		else
		{
			`warn(`location @ "Problem with the Login Status, there is a LAN match running, so we are not destroying the game session!", true, 'XCom_Online');
		}
	}

	RefreshLoginStatus();

	if( bOnlineSubIsPSN && bInShellLoginSequence && bShowingLoginUI ) 
	{//The PS3 is trying to complete a shell login and the player is also trying to log into the PSN.  
		//We got a LoginStatusChange because we're logged into the PSN and can proceed.
		//This situation occurs when a player accepted a cross game invite while logged out of the PSN.  
		//NOTE: We need this special case because we don't use LoginChangeDelegates on the PS3 because 
		//it doesn't care about local user profiles.  (Instead, everything is associated with the user's PSN account)

		ShellLoginUserLoginComplete(); 
		bShowingLoginUI = false; 
	} 

	if( MCP != none )
	{
		// Only enable the MCP if we have an online profile and the config allows it.
		MCP.bEnableMcpService = bMCPEnabledByConfig && LoginStatus == LS_LoggedIn;
	}

	if( bHasLogin )
	{
		RequestLoginFeatures();
	}

	// Route the event to our listeners. While it may seem odd to route this event through
	// the OnlineEventMgr it removes the complexity of having to worry about tracking the
	// active user in systems other than the OnlineEventMgr.
	CallLoginStatusChangeDelegates(NewStatus, NewId);
}

private simulated function OnDestroyOnlineGameComplete_LoginStatusChange(name SessionName, bool bWasSuccessful)
{
	`log(self $ "::" $ GetFuncName() @ `ShowVar(SessionName) @ `ShowVar(bWasSuccessful), true, 'XCom_Online');
	//bsg-jrucker (8/14/16): Need to call EndMultiplayer on Orbis here to handle the user logging out of PSN while in a MP match.
	if( `ISORBIS )
	{
		OnlineSub.GameInterface.EndMultiplayer(LocalUserIndex);
	}
	//bsg-jrucker (8/14/16): End.
	OnlineSub.GameInterface.ClearDestroyOnlineGameCompleteDelegate(OnDestroyOnlineGameComplete_LoginStatusChange);
	LoginStatusChange(m_eNewLoginStatusForDestroyOnlineGame_OnLoginStatusChange, m_kNewIdForDestroyOnlineGame_OnLoginStatusChange);
}

simulated function RefreshLoginStatus()
{
	local OnlinePlayerInterface PlayerInterface;

	PlayerInterface = OnlineSub.PlayerInterface;
	if( PlayerInterface != none )
	{
		LoginStatus = PlayerInterface.GetLoginStatus(LocalUserIndex);
		bHasLogin = LoginStatus != LS_NotLoggedIn && !PlayerInterface.IsGuestLogin(LocalUserIndex);
	}
}

// <workshop> PRESS A TO PLAY BUG - adsmith 2016-02-24
// ADD:
event bool IsPlayerLoggedIn()
{
	//PROFILE_SWITCH RJM 2016/03/23
	//handling sign out profile A, sign in profile B
	if (LoginStatus > LS_NotLoggedIn && bHasProfileSettings)
		return true;
	return false;
}
// </workshop>


//bsg-jrucker (3/9/17): Function to determine of the player needs to be shown an engagement screen at the main menu.  Reliant on user status.
function bool GetNeedsEngagementScreen()
{
	if (!OnlineSub.GetNeedsEngagementFromFirstBoot())
	{
		//bsg-hlee (06.23.17): Removing this because we can not use GetNeedsEngagementScreen without this turning it true.
		//OnlineSub.SetNeedsEngagement(true);
		RefreshLoginStatus();
		//bsg-fchen (6.28.17): Orbis does not need to update login
		if (!`ISORBIS)
		{
			LoginChangeDelegate(0);
		}
		if (LoginStatus > LS_NotLoggedIn)
		{
			return false;
		}
	}

	return true;
}
//bsg-jrucker (3/9/17): End.

/** Called if a user logs out */
private function LogoutCompletedDelegate(bool bWasSuccessful)
{
	bHasLogin = false;
	bHasProfileSettings = false;
}

/** Called when a user has picked a storage device */
private function DeviceSelectionDoneDelegate(bool bWasSuccessful)
{
	local OnlinePlayerInterfaceEx PlayerInterfaceEx;
	PlayerInterfaceEx = OnlineSub.PlayerInterfaceEx;

	if( bInShellLoginSequence && bOnlineSubIsLive && !bHasLogin )
	{
		`log("Storage Device Selector Failed: Login lost while storage selector was up!",,'XCom_Online');
		return;
	}

	StorageDeviceIndex = PlayerInterfaceEx.GetDeviceSelectionResults(LocalUserIndex, StorageDeviceName);
	if( bWasSuccessful && (!bOnlineSubIsLive || PlayerInterfaceEx.IsDeviceValid(StorageDeviceIndex)) )
	{
		`log("Storage Device Selected" @ `ShowVar(LocalUserIndex) @ `ShowVar(StorageDeviceName) @ `ShowVar(StorageDeviceIndex),,'XCom_Online');

		bHasStorageDevice = true;

		UpdateSaveGameList();

		// Now that we've picked storage, try to find our profile settings		
		ReadProfileSettings();
	}
	else
	{
		`log("Storage Device Selection Failed" @ `ShowVar(LocalUserIndex) @ `ShowVar(StorageDeviceName),,'XCom_Online');

		StorageDeviceIndex = -1;
		StorageDeviceName = "";
		bHasStorageDevice = false;

		UpdateSaveGameList();

		if( bInShellLoginSequence )
		{
			CreateNewProfile();
		}
		else
		{
			LossOfDataWarning(m_sNoStorageDeviceSelectedWarning);
		}
	}
}

/** Called when a storage device has been added or removed. */
private simulated function StorageDeviceChangeDelegate()
{
	local OnlinePlayerInterfaceEx PlayerInterfaceEx;

	PlayerInterfaceEx = OnlineSub.PlayerInterfaceEx;
	if( bHasStorageDevice && PlayerInterfaceEx != none && !PlayerInterfaceEx.IsDeviceValid(StorageDeviceIndex) )
	{
		`log("Save Device Lost.",,'XCom_Online');
		CallSaveDeviceLostDelegates();
		LossOfSaveDevice();
	}
}

private simulated function ExternalUIChangedDelegate(bool bOpen)
{
	local XComEngine GameEngine;

	bExternalUIOpen = bOpen;

	GameEngine = XComEngine(LocalEngine);
	if( GameEngine != none && GameEngine.IsAnyMoviePlaying() )
	{
		if( bExternalUIOpen )
			GameEngine.PauseMovie();
		else
			GameEngine.UnpauseMovie();
	}

	if( bStorageSelectPending )
	{
		bStorageSelectPending = false;
		SelectStorageDevice();
	}

	if( bLoginUIPending )
	{
		bLoginUIPending = false;
		ShellLoginShowLoginUI();
	}
}

/** Called when a ReadAchievements operation has completed */
private function ReadAchievementsCompleteDelegate(int TitleId)
{
	local array<AchievementDetails> ArrTrophies;

	OnlineSub.PlayerInterface.ClearReadAchievementsCompleteDelegate(LocalUserIndex, ReadAchievementsCompleteDelegate);
	OnlineSub.PlayerInterface.GetAchievements(LocalUserIndex, ArrTrophies);
}

/** Called when a ReadPlayerStorage operation has completed */
private function ReadProfileSettingsCompleteDelegate(byte LocalUserNum,EStorageResult eResult)
{
	local XComOnlineProfileSettings ProfileSettings;
	local XComPresentationLayerBase Presentation;

	if( eResult == eSR_Success )
	{	
		`log("Profile Read Successful",,'XCom_Online');

		ReadProfileSettingsFromBuffer();

		ProfileSettings = `XPROFILESETTINGS;

		// mmg_mike.anstine TODO! JHawley - Input - No one should be calling SetMouseState() directly - engine call is only one that matters
		// If the mouse is not active but no gamepad controllers are availabe then switch back to mouse input
		if (!`ISCONSOLE && !ProfileSettings.Data.IsMouseActive() && !GamepadConnected_PC()) 
		{
			ProfileSettings.Data.SetMouseState(true);
		}

		// need to set on the player controller because in MP the server needs to know whether a mouse or controller pawn is spawned -tsmith 
		XComPlayerController(class'UIInteraction'.static.GetLocalPlayer(0).Actor).SetIsMouseActive(ProfileSettings.Data.IsMouseActive());
		XComPlayerController(class'UIInteraction'.static.GetLocalPlayer(0).Actor).SetIsMouseActive(ProfileSettings.Data.IsControllerActive()); //bsg-jhilton (10.12.2016) - Added basic controller check and cleaned up cursor/camera
		
		if( bInShellLoginSequence )
		{
			bHasProfileSettings = true;
			EndShellLogin();
		}

		ProfileSettings.PostLoadData();

		ProfileSettings.ApplyOptionsSettings();
	}
	else
	{
		`log("Profile Read Failed",,'XCom_Online');

		if(eResult == eSR_Corrupt)
		{
			// TCR 49/30 on 360: We must confirm the destruction of the corrupt profile data before actually
			// nuking it with the flaming justice of 1000 fiery suns
			//<workshop> LOGIN_PROGRESS RJM 2016/05/03
			//INS:
			//bShowingLossOfDataWarning = true;
			//</workshop>

			Presentation = XComPlayerController(class'UIInteraction'.static.GetLocalPlayer(0).Actor).Pres; // GetLocalPlayer takes player index not controller index. Do not user LocalUserIndex.
			Presentation.UICloseProgressDialog();
			ErrorMessageMgr.EnqueueError(SystemMessage_CorruptedSave);
		}
		else if( bInShellLoginSequence )
		{
			// Automatically create a new profile if a profile could not be read
			CreateNewProfile();
			`XPROFILESETTINGS.PostLoadData(); // mmg_aaron.lee (06/10/19) - fix for setting default value for consoles.
			`XPROFILESETTINGS.ApplyOptionsSettings();
		}
	}
}

private function ReadPlayerStorageCompleteDelegate(byte LocalUserNum, EStorageResult eResult)
{
	ReadProfileSettingsCompleteDelegate(LocalUserNum, eResult);
}

/** Called when a WritePlayerStorage operation has completed */
private function WriteProfileSettingsCompleteDelegate(byte LocalUserNum, bool bWasSuccessful)
{	
	local delegate<SaveProfileSettingsComplete> dSaveProfileSettingsComplete;

	//<workshop> DISPLAYING_AUTOSAVE_MESSAGE kmartinez 2016-04-19
	//DEL:
	// We are no longer going to hide the auto save icon ourselves, and it shall display and hide itself based on it's own timer.
	//// Don't show the save indicator for failed saves
	//if( !bWasSuccessful )
	//{
	//	HideSaveIndicator();
	//}
	//</workshop>

	ProfileIsSerializing = false;

	foreach m_SaveProfileSettingsCompleteDelegates(dSaveProfileSettingsComplete)
	{
		dSaveProfileSettingsComplete(bWasSuccessful);
	}
}

private function WritePlayerStorageCompleteDelegate(byte LocalUserNum, bool bWasSuccessful)
{
	WriteProfileSettingsCompleteDelegate(LocalUserNum, bWasSuccessful);
}

private function OnUpdateSaveListComplete(bool bWasSuccessful)
{
	RefreshSaveIDs();
	bUpdateSaveListInProgress = false;
	CallUpdateSaveListCompleteDelegates(bWasSuccessful);
}

//<workshop> CONSOLE JPS 2015/11/17
//WAS:
///** Update save IDs to match content list. */
//native private function RefreshSaveIDs();
//
///** Ensure that the save IDs are correct */
//native private function CheckSaveIDs(out array<OnlineSaveGame> SaveGames);
//
//native private function OnReadSaveGameDataComplete(bool bWasSuccessful,byte LocalUserNum,int DeviceId,string FriendlyName,string FileName,string SaveFileName);

// NOTE: The original RefreshSaveIDs code appears to manipulate the underlying values of save games which won't
// actually work here. So this code may be broken.
/** Update save IDs to match content list. */
private function RefreshSaveIDs()
{
	local int MaxGameNum;
	local int NumSaveGames;
	local XComOnlineProfileSettings ProfileSettings;
	local array<OnlineSaveGame> SaveGames;
	local int SaveGameIndex;

	if (OnlineSub == None || OnlineSub.ContentInterface == None)
	{
		`log(`location @ "Cannot refresh save IDs. Online subsystem is not available.",,'DevOnline');
		return;
	}

	OnlineSub.ContentInterface.GetSaveGames(LocalUserIndex, SaveGames);

	NumSaveGames = SaveGames.Length;
	for (SaveGameIndex = 0; SaveGameIndex < NumSaveGames; SaveGameIndex++)
	{
		if (SaveGames[SaveGameIndex].SaveGames.Length > 0)
		{
			SaveGames[SaveGameIndex].SaveGames[0].SaveGameHeader.SaveID = SaveGameIndex;
			MaxGameNum = Max(SaveGames[SaveGameIndex].SaveGames[0].SaveGameHeader.GameNum, MaxGameNum);
		}
	}	

	//Update the game num based on the saves that are present
	if (LocalEngine != None)
	{
		ProfileSettings = XComOnlineProfileSettings(LocalEngine.GetProfileSettings());
		if (ProfileSettings != None)
		{
			ProfileSettings.Data.m_iGames = Max(ProfileSettings.Data.m_iGames, MaxGameNum);
		}
	}
}

/** Ensure that the save IDs are correct */
private function CheckSaveIDs(out array<OnlineSaveGame> SaveGames)
{
	local int NumSaveGames;
	local int i;

	NumSaveGames = SaveGames.Length;
	for (i = 0; i < NumSaveGames; i++)
	{
		if (SaveGames[i].SaveGames.Length > 0)
		{
			SaveGames[i].SaveGames[0].SaveGameHeader.SaveID = SaveNameToID(SaveGames[i].Filename);
		}
	}
}
//</workshop>

// dforrest (6.13.17): debug support for deleting all save games
function DeleteAllSaves()
{
	local int MaxGameNum;
	local int NumSaveGames;
	local array<OnlineSaveGame> SaveGames;
	local int SaveGameIndex, i;

	if (OnlineSub == None || OnlineSub.ContentInterface == None)
	{
		`log(`location @ "Cannot refresh save IDs. Online subsystem is not available.",,'DevOnline');
		return;
	}

	OnlineSub.ContentInterface.GetSaveGames(LocalUserIndex, SaveGames);

	NumSaveGames = SaveGames.Length;
	for (SaveGameIndex = 0; SaveGameIndex < NumSaveGames; SaveGameIndex++)
	{
		if (SaveGames[SaveGameIndex].SaveGames.Length > 0)
		{
			SaveGames[SaveGameIndex].SaveGames[0].SaveGameHeader.SaveID = SaveGameIndex;
			MaxGameNum = Max(SaveGames[SaveGameIndex].SaveGames[0].SaveGameHeader.GameNum, MaxGameNum);
		}
	}	

	NumSaveGames = SaveGames.Length;
	for (i = SaveGames.Length - 1; i >= 0; i--)
	{
		DeleteSaveGame(i);
	}

	RefreshSaveIDs();
}
// dforrest (6.13.17): end

private function OnWriteSaveGameDataComplete(bool bWasSuccessful, byte LocalUserNum, int DeviceId, string FriendlyName, string FileName, string SaveFileName)
{
	//<workshop> DISPLAYING_AUTOSAVE_MESSAGE kmartinez 2016-04-19
	//DEL:
	// We are no longer going to hide the auto save icon ourselves, and it shall display and hide itself based on it's own timer.
	//// Don't show the save indicator for failed saves
	//if( !bWasSuccessful )
	//{
	//	HideSaveIndicator();
	//}
	//</workshop>

	if( WriteSaveGameComplete != none )
	{
		WriteSaveGameComplete(bWasSuccessful);
		WriteSaveGameComplete = none;
	}

	OnSaveCompleteInternal( bWasSuccessful, LocalUserNum, DeviceId, FriendlyName, FileName, SaveFileName );
}

function UpdateCurrentGame(int iGame)
{
	m_iCurrentGame = iGame;
}

function int GetCurrentGame()
{
	return m_iCurrentGame;
}

/**
 * Messages the user about a Save Data owner error on PS3.
 * Only shows the message if it has not already shown.
 */
event ShowPostLoadMessages()
{
	local XComPresentationLayerBase Presentation;
	local TDialogueBoxData DialogData;
	local bool bShowDialog;

	//<workshop> AVOID_DIALOG_ON_LOAD_SCREEN RJM 2016/06/27
	//INS:
	local Actor TimerActor;

	TimerActor = class'WorldInfo'.static.GetWorldInfo().Spawn(class'DynamicPointInSpace');	
	TimerActor.Tag = 'PostLoadMessage';

	if(`XENGINE.IsLoadingMoviePlaying())
	{
		//This prevents the dialog from briefly rendering on top of the loading screen.
		TimerActor.SetTimer(1.0, false, nameof(ShowPostLoadMessages), self);
		return;
	}
	//</workshop>

	//bsg-jhilton (05.09.2017) - TTP 6908 - Readded super soldier achievement/trophy warning
	if( !bAchivementsEnabled )
	{
		Presentation = XComPlayerController(class'UIInteraction'.static.GetLocalPlayer(0).Actor).Pres; // GetLocalPlayer takes player index not controller index. Do not user LocalUserIndex.
		if( Presentation != none && Presentation.IsPresentationLayerReady() )
		{
			DialogData.eType = eDialog_Warning;
			if (bAchievementsDisabledXComHero)
			{
				bShowDialog = true;
				if (class'WorldInfo'.static.IsConsoleBuild(CONSOLE_Orbis))
				{
					DialogData.strText = m_sSaveDataHeroErrPS3;
				}
				else
				{
					DialogData.strText = m_sSaveDataHeroErr360PC;
				}
			}

			if( bShowDialog )
			{
				DialogData.strAccept = class'XComPresentationLayerBase'.default.m_strOK;
				Presentation.UIRaiseDialog(DialogData);
			}

			bSaveDataOwnerErrHasShown = true;
			bSaveDataOwnerErrPending = false;
		}
		else
		{
			bSaveDataOwnerErrPending = true;
		}
	}
	//bsg-jhilton (05.09.2017) - TTP 6908 - End
}

//External interface
//==================================================================================================================

private function SetupDefaultProfileSettings()
{
	//Initialize the profile settings, these will be overwritten if we are able to load saved settings
	LocalEngine.CreateProfileSettings();	
	XComOnlineProfileSettings(LocalEngine.GetProfileSettings()).SetToDefaults();	
}

function AddBeginShellLoginDelegate( delegate<ShellLoginComplete> ShellLoginCompleteCallback )
{
	`log(`location @ `ShowVar(ShellLoginCompleteCallback), true, 'XCom_Online');
	if (m_BeginShellLoginDelegates.Find(ShellLoginCompleteCallback) == INDEX_None)
	{
		m_BeginShellLoginDelegates[m_BeginShellLoginDelegates.Length] = ShellLoginCompleteCallback;
	}
}

function ClearBeginShellLoginDelegate( delegate<ShellLoginComplete> ShellLoginCompleteCallback )
{
	local int i;

	`log(`location @ `ShowVar(ShellLoginCompleteCallback), true, 'XCom_Online');
	i = m_BeginShellLoginDelegates.Find(ShellLoginCompleteCallback);
	if (i != INDEX_None)
	{
		m_BeginShellLoginDelegates.Remove(i, 1);
	}
}

/** Begins the shell login sequence. Logs in as local user associated with Controller ID. */
function BeginShellLogin(int ControllerId)
{
	local delegate<ShellLoginComplete> dShellLoginComplete;

	//<workshop> GAMEPAD_MANAGEMENT RJM 2016/03/24
	//INS:
	if(OnlineSub.PlayerInterfaceEx.SwapControllerToIndex0(ControllerId) || ControllerId < 0)
	{
		`log("Swapping controller 0 with controller" @ ControllerId,,'XCom_Online');
		ControllerId = 0;
	}
	//</workshop>

	if( bInShellLoginSequence )
	{
		`warn("Shell Login could not start: already started!",,'XCom_Online');
		foreach m_BeginShellLoginDelegates(dShellLoginComplete)
		{
			dShellLoginComplete(false);
		}
		return;
	}
	
	`log("Shell Login Started",,'XCom_Online');

	ClearShuttleToScreen();
	bDelayDisconnects = false;
			
	bInShellLoginSequence = true;

	ClearScreenUI();

	// bsg-fchen (4.5.17): Display the progress popup before anything else
	ShellLoginProgressMsg(m_sLoadingProfile);

	if( bHasProfileSettings )
		ResetLogin();	

	`CHARACTERPOOLMGR.ClearCharacterPool(); //bsg-jrebar (6/6/17): Clear at new login

	// mmg_mike.anstine (02/28/19) - Needed on console because the start screen sets controller and player index to -1 to force login
	if(`ISCONSOLE || `ISCONTROLLERACTIVE)
	{
		// Associate the correct controller
		SetActiveController(ControllerId);
	}

	//<workshop> CLEAR_OLD_SAVES RJM 2016/04/08
	// Handling the case where the player profile changes.
	//INS:
	OnlineSub.ContentInterface.ClearContentList(LocalUserIndex, OCT_SaveGame);
	//</workshop>

	// Initialize rich presence system
	InitRichPresence();

	// If inactive profiles are not allow then make sure that none are signed in
	if( !bAllowInactiveProfiles && CheckForInactiveProfiles() )
	{
		ShellLoginHandleInactiveProfiles();
		return;
	}

	if (CopyProtection == none)
	{
		`log("Creating protection object",,'XCom_Online');
		CopyProtection = new(self) class'XComCopyProtection';
	}
	
	InitializeDelegates();

	//////////////////////////////////////////////////////////////////
	//

	SetupDefaultProfileSettings();

	// Get MCP
	if( XComEngine(LocalEngine) != none && MCP == none )
	{
		MCP = XComEngine(LocalEngine).MCPManager;
		bMCPEnabledByConfig = MCP.bEnableMcpService;
	}


	RefreshLoginStatus();

	if( bOnlineSubIsLive && !bHasLogin )
	{	
		ShellLoginShowLoginUI(true);
	}
	else if( bOnlineSubIsPSN && LoginStatus != LS_LoggedIn && OnlineSub.GameInterface.GameBootIsFromInvite() )
	{
		ShellLoginShowLoginUI(true);
	}
	//<workshop> CONSOLE JPS 2015/11/20
	//INS:
	//PS4_PROFILE RJM 2016/03/22
	//PS4 does not show a login screen as there is always an initial user profile active.
	//Allow the user to select the correct invited profile if triggering a boot invite. InviteUserIndex > 0 indicates that the wrong profile is selected.
	else if ( bOnlineSubIsDingo && (LoginStatus != LS_LoggedIn || (m_bCurrentlyTriggeringBootInvite && InviteUserIndex > 0)) )
	{
		// mmg_aaron.lee (03/25/19) BEGIN - if it's running autotest on a durango build, skip the login process.
		if (`ONLINESUBSYSTEM.GetSkipUserLogin()) 
		{
			bHasLogin = true;
			ShellLoginUserLoginComplete();
		}
		else
		{
			ShellLoginShowLoginUI(true);
		}
		// mmg_aaron.lee (03/25/19) END
	}
	//</workshop>
	else
	{
		ShellLoginUserLoginComplete();
	}
}

protected function SetActiveController(int ControllerId)
{
	local LocalPlayer ActivePlayer;
	local PlayerController ActivePlayerController;

	// Set the active user
	if( !bOnlineSubIsSteamworks )
		super.SetActiveController(ControllerId);

	if (LocalEngine != none)
	{
		// Set the active controller
		if( LocalEngine.GamePlayers.Length > 0 && LocalEngine.GamePlayers[0] != none )
		{
			`log("USING CONTROLLER " $ ControllerId,,'XCom_Online');

			ActivePlayer = LocalEngine.GamePlayers[0];
			ActivePlayer.SetControllerId(ControllerId);

			ActivePlayerController = ActivePlayer.Actor;
			if( ActivePlayerController != none && ActivePlayerController.bIsControllerConnected == m_bControllerUnplugged )
			{
				`log("Updating controller connection status",,'XCom_Online');
				ActivePlayerController.OnControllerChanged(ControllerId, !m_bControllerUnplugged);
			}
		}
		else
		{
			`log("Failed to set active controller! No players detected!");
		}
	}
}

//<workshop> HIDE_DIALOG_AFTER_CONTROLLER_DISCONNECT RJM 2016/05/24
//INS:
protected function OnControllerStatusChanged(int ControllerId, bool bIsConnected)
{
	super.OnControllerStatusChanged(ControllerId, bIsConnected);
	if( LocalUserIndex == ControllerId )
	{
		if(bIsConnected)
		{
			//System UI dialogs become unresponsive after a controller disconnect. Hide them here.
			ClearScreenUI();

			//BET 2016-03-06 - The above call has been observed removing UIMouseGuard screens inappropriately, in the pause menu for example.
			//It does not appear to cause any issues currently, though - input is still consumed correctly.
		}
	}
}
//</workshop>

private function ClearScreenUI()
{
	if(ErrorMessageMgr != none)
		ErrorMessageMgr.ClearAllErrorMsgs();
		//bsg-cballinger (11.18.16): BSG_REMOVED, use ErrorMessageMgr instead
/*
	local XComPresentationLayerBase Presentation;
	local UIMovie_2D InterfaceMgr;

	Presentation = XComPlayerController(class'UIInteraction'.static.GetLocalPlayer(0).Actor).Pres; // GetLocalPlayer takes player index not controller index. Do not user LocalUserIndex.
	InterfaceMgr = (Presentation != none)? Presentation.Get2DMovie() : none;
	if( InterfaceMgr != none && InterfaceMgr.DialogBox != none )
	{
		ClearSystemMessages(); // Remove any system messages
		//bsg-jneal (7.25.16): Removing this call to clear dialogs as it is unnecessarily closing open dialogs throughout the title when a controller gets disconnected, should not need this anymore
		//InterfaceMgr.DialogBox.ClearDialogs(); // Remove any existing dialogs.
		//bsg-jneal (7.25.16): end
	}
*/
}

private function InitializeDelegates()
{
	local OnlinePlayerInterface PlayerInterface;
	local OnlinePlayerInterfaceEx PlayerInterfaceEx;
	local OnlineContentInterface ContentInterface;
	local OnlineSystemInterface SystemInterface;
	local OnlineStatsInterface StatsInterface;

	//Initialize all our delegates
	//////////////////////////////////////////////////////////////////
	PlayerInterface = OnlineSub.PlayerInterface;
	if( PlayerInterface != none )
	{
		//Login
		PlayerInterface.AddLoginChangeDelegate(LoginChangeDelegate);
		PlayerInterface.AddLoginCancelledDelegate(LoginCancelledDelegate);
		PlayerInterface.AddLogoutCompletedDelegate(LocalUserIndex, LogoutCompletedDelegate);
		PlayerInterface.AddLoginStatusChangeDelegate(LoginStatusChange, LocalUserIndex);
		//<workshop> ACCOUNT_PICKER RJM 2016/03/17
		//INS:
		PlayerInterface.AddLoginFailedDelegate(LocalUserIndex, LoginFailedDelegate);
		//</workshop>

		//Player Profile
		PlayerInterface.AddWriteProfileSettingsCompleteDelegate(LocalUserIndex, WriteProfileSettingsCompleteDelegate);
		PlayerInterface.AddReadProfileSettingsCompleteDelegate(LocalUserIndex, ReadProfileSettingsCompleteDelegate);
		PlayerInterface.AddWritePlayerStorageCompleteDelegate(LocalUserIndex, WritePlayerStorageCompleteDelegate);
		PlayerInterface.AddReadPlayerStorageCompleteDelegate(LocalUserIndex, ReadPlayerStorageCompleteDelegate);
	}

	PlayerInterfaceEx = OnlineSub.PlayerInterfaceEx;
	if( PlayerInterfaceEx != none )
	{
		//Device Selection
		PlayerInterfaceEx.AddDeviceSelectionDoneDelegate(LocalUserIndex, DeviceSelectionDoneDelegate);
	}

	SystemInterface = OnlineSub.SystemInterface;
	if( SystemInterface != none )
	{
		//External UI
		SystemInterface.AddExternalUIChangeDelegate(ExternalUIChangedDelegate);

		// Storage added or removed
		SystemInterface.AddStorageDeviceChangeDelegate(StorageDeviceChangeDelegate);
		SystemInterface.SetSystemMessageDelegates(); //bsg-cballinger(11.22.16): Set platform-specific handlers for system dialog messages
	}

	//Player content (saves)
	ContentInterface = OnlineSub.ContentInterface;
	if( ContentInterface != none )
	{
		//<workshop> OSS_CHANGES JPS 2015/11/17
		//WAS:
		//ContentInterface.AddReadSaveGameDataComplete(LocalUserIndex, OnReadSaveGameDataComplete);
		//ContentInterface.AddReadContentComplete(LocalUserIndex, OCT_SaveGame, OnUpdateSaveListComplete);
		//ContentInterface.AddWriteSaveGameDataComplete(LocalUserIndex, OnWriteSaveGameDataComplete);
		//ContentInterface.AddDeleteSaveGameDataComplete(LocalUserIndex, OnDeleteSaveGameDataComplete);
		ContentInterface.AddReadSaveGameDataCompleteDelegate(LocalUserIndex, OnReadSaveGameDataComplete);
		ContentInterface.AddReadContentComplete(LocalUserIndex, OCT_SaveGame, OnUpdateSaveListComplete);
		ContentInterface.AddWriteSaveGameDataCompleteDelegate(LocalUserIndex, OnWriteSaveGameDataComplete);
		ContentInterface.AddDeleteSaveGameDataCompleteDelegate(LocalUserIndex, OnDeleteSaveGameDataComplete);
		ContentInterface.AddReadCharacterPoolCompleteDelegate(LocalUserIndex, OnReadCharacterPoolComplete);
		//</workshop>
	}

	// stats -tsmith 
	StatsInterface = OnlineSub.StatsInterface;
	if(StatsInterface != none)
	{
		StatsInterface.SetStatsViewPropertyToColumnIdMapping(class'XComOnlineStatsUtils'.default.StatsViewPropertyToColumnIdMap);
		StatsInterface.SetViewToLeaderboardNameMapping(class'XComOnlineStatsUtils'.default.ViewIdToLeaderboardNameMap);
	}
}

// mmg_adrian.williams (10/28/19) - Show this when DNA UI is open, but DNA is not ready.
function UIProgressDialogue DNAWaitingProgressMsg(string sTitle, string sText)
{
	local XComPresentationLayerBase Presentation;
	local TProgressDialogData kDialogData;
	Presentation = XComPlayerController(class'UIInteraction'.static.GetLocalPlayer(0).Actor).Pres; // GetLocalPlayer takes player index not controller index. Do not user LocalUserIndex.
	if (Presentation != none)
	{
		if (Presentation.GetModalMovie().bIsInited)
		{
			kDialogData.strTitle = sTitle;
			kDialogData.strDescription = sText; //bsg-jedwards (5.22.17) : Displays description text for loading 
			kDialogData.bDNAUI = true;
			return Presentation.UIProgressDialog(kDialogData);
		}
	}
}

function UIProgressDialogue ShellLoginProgressMsgDNA(string sTitle, string sText)
{
	local XComPresentationLayerBase Presentation;
	local TProgressDialogData kDialogData;
	local UIProgressDialogue ReturnScreen;
	Presentation = XComPlayerController(class'UIInteraction'.static.GetLocalPlayer(0).Actor).Pres; // GetLocalPlayer takes player index not controller index. Do not user LocalUserIndex.
	if (Presentation != none)
	{
		if (Presentation.GetModalMovie().bIsInited)
		{	
			kDialogData.strTitle = sTitle;
			kDialogData.strDescription = sText; //bsg-jedwards (5.22.17) : Displays description text for loading 
			ReturnScreen = Presentation.UIProgressDialog(kDialogData);
			return ReturnScreen;
		}
	}
}

/** Called during shell login to update the progress message. */
private function ShellLoginProgressMsg(string sProgressMsg)
{
	local XComPresentationLayerBase Presentation;
	local TProgressDialogData kDialogData;

	Presentation = XComPlayerController(class'UIInteraction'.static.GetLocalPlayer(0).Actor).Pres; // GetLocalPlayer takes player index not controller index. Do not user LocalUserIndex.
	if( Presentation != none )
	{
		// Remove previous dialog box
		ShellLoginHideProgressDialog();

		kDialogData.strTitle = sProgressMsg;
		kDialogData.strDescription = m_sLoadingProfileDialogText; //bsg-jedwards (5.22.17) : Displays description text for loading 

		Presentation.UIProgressDialog(kDialogData);
	}
}

/** Use during the shell login sequence to hide the shell login progress dialog */
private function ShellLoginHideProgressDialog()
{
	local XComPresentationLayerBase Presentation;

	Presentation = XComPlayerController(class'UIInteraction'.static.GetLocalPlayer(0).Actor).Pres; // GetLocalPlayer takes player index not controller index. Do not user LocalUserIndex.
	if( Presentation != none && bInShellLoginSequence )
	{
		// Close the progress dialog as well as any other UI state that has
		// managed to introduce itself above the progress dialog.
		Presentation.ScreenStack.PopIncludingClass( class'UIProgressDialogue', false );
	}
}

/** Called when the user login is complete during the shell login sequence. */
private function ShellLoginUserLoginComplete()
{
	if( bHasLogin )
	{
		`log("Shell Login: User Logged In",,'XCom_Online');

		InitMCP();
		SelectStorageDevice();

		RefreshOnlineStatus(); // Updates rich presence

		CopyProtection.StartCheck(LocalUserIndex);
		RequestLoginFeatures();
	}
	else
	{
		`log("Shell Login: User NOT Logged In",,'XCom_Online');

		if( bRequireLogin )
		{
			//</workshop> REQUIRE_LOGIN RJM 2016/03/24
			//WAS:
			//if( bOnlineSubIsLive )
			if( bOnlineSubIsLive || bOnlineSubIsDingo )
			//</workshop>
			{
				RequestLogin();
				return;
			}
			else
			{
				`log("Login required but not present. However, Online Sub does not have login UI.",,'XCom_Online');
			}
		}

		// Non-Live systems can perform check without begin logged-in
		if( !bOnlineSubIsLive )
			CopyProtection.StartCheck(LocalUserIndex);

		if( bOnlineSubIsSteamworks )
		{
			SelectStorageDevice(); //PC users always have storage
		}
		else
		{
			// A failed login automatically goes to creating a new profile
			CreateNewProfile();
		}
	}

	//bsg-jrucker (9/30/16): Moved this here, it shouldn't happen until after we're done with the entire login process.
	`CHARACTERPOOLMGR.LoadCharacterPool();
	//bsg-jrucker (9/30/16): End.
}

private function RequestLogin()
{
	local XComPresentationLayerBase Presentation;

	`log("Requesting user login.",,'XCom_Online');

	Presentation = XComPlayerController(class'UIInteraction'.static.GetLocalPlayer(0).Actor).Pres; // GetLocalPlayer takes player index not controller index. Do not user LocalUserIndex.
	if( Presentation != none )
	{
		//bShowingLoginRequiredWarning = true;

		// Close the progress dialog
		ShellLoginHideProgressDialog();

		ErrorMessageMgr.EnqueueError(SystemMessage_LoginRequired);
	}
	//BSG_REMOVED: This is an error case, if we reach this case we probably don't want to handle it by acting as if the user acknowledged the error. Should be handled by the error mgr now anyway
	//              Moving function call to the Error Mgr, which is the only place that should be using it, as a button callback
	/*
	else
	{
		RequestLoginDialogCallback('eUIAction_Accept');
	}
	*/
}

private function RequestLoginDialogCallback(Name Action)
{
	//bShowingLoginRequiredWarning = false;
	ErrorMessageMgr.HandleDialogActionErrorMsg(Action);

	ShellLoginProgressMsg(m_sLoadingProfile); // Restore progress dialog

	if( Action == 'eUIAction_Accept' )
	{
		ShellLoginShowLoginUI();
	}
}

/** 
 *  Called during the shell login sequence when there are
 *  inactive profiles that need to be logged out.
 */
private function ShellLoginHandleInactiveProfiles()
{
	local XComPresentationLayerBase Presentation;

	`log("Shell Login: Raising inactive profile dialog",,'XCom_Online');

	Presentation = XComPlayerController(class'UIInteraction'.static.GetLocalPlayer(0).Actor).Pres; // GetLocalPlayer takes player index not controller index. Do not user LocalUserIndex.
	if( Presentation != none )
	{
		ErrorMessageMgr.EnqueueError(SystemMessage_InactiveProfile);
	}
	//BSG_REMOVED: This is an error case, if we reach this case we probably don't want to handle it by acting as if the user acknowledged the error. Should be handled by the error mgr now anyway
	//              Moving function call to the Error Mgr, which is the only place that should be using it, as a button callback
	/*
	else
	{
		InactiveProfilesDialogCallback('eUIAction_Cancel');
	}
	*/
}

private function InactiveProfilesDialogCallback(Name Action)
{
	ErrorMessageMgr.HandleDialogActionErrorMsg(Action);
	if( !CheckForInactiveProfiles() )
	{
		// No more inactive profiles. Restart Shell Login.
		`log("Shell Login: Restarting Shell Login Sequence",,'XCom_Online');

		bInShellLoginSequence = false;
		BeginShellLogin(LocalUserIndex);
	}
	else
	{
		`log("Shell Login Failed: Inactive Profiles Present",,'XCom_Online');

		AbortShellLogin();
	}
}

/** Called when the shell login has failed */
private function AbortShellLogin()
{
	local delegate<ShellLoginComplete> dShellLoginComplete;

	`log("Shell Login: Aborting");

	ResetLogin();

	// Close the progress dialog
	ShellLoginHideProgressDialog();

	bInShellLoginSequence = false;

	foreach m_BeginShellLoginDelegates(dShellLoginComplete)
	{
		dShellLoginComplete(false);
	}
}

/** Called when the shell login process is complete */
private function EndShellLogin()
{
	local XComPresentationLayerBase Presentation;
	`ONLINEEVENTMGR.ResetAchievementState(); //Firaxis RAM - shell login resets our internal state regarding achievements being disabled by easter eggs

	// Refresh configs only when logging in from the start screen
	Presentation = XComPlayerController(class'UIInteraction'.static.GetLocalPlayer(0).Actor).Pres; // GetLocalPlayer takes player index not controller index. Do not user LocalUserIndex.
	if( bOnlineSubIsSteamworks || (Presentation != none && Presentation.IsInState('State_StartScreen', true)) )
	{
		DownloadConfigFiles();
	}

	ShellLoginDLCRefreshComplete();
}

/** Called when DLC has finished refreshing while the shell login is waiting for it to complete. */
private function ShellLoginDLCRefreshComplete()
{
	// mmg_adrian.williams DNA - Replacing Firaxis Live with DNA
	//local EOnlineServerConnectionStatus ConnectionStatus;
	local delegate<ShellLoginComplete> dShellLoginComplete;

	if( bInShellLoginSequence )
	{
		//`log("Shell Login: DLC Refresh Complete",,'XCom_Online');
		`log("Shell Login Complete",,'XCom_Online');

		// Close the progress dialog
		ShellLoginHideProgressDialog();

		ShowPostLoadMessages();

		bInShellLoginSequence = false;
		
		foreach m_BeginShellLoginDelegates(dShellLoginComplete)
		{
			dShellLoginComplete(true);
		}
	}
}

private function DownloadConfigFiles()
{
	if (OnlineSub != none && OnlineSub.Patcher != none && OnlineSub.Patcher.TitleFileInterface != none && 
		(LoginStatus == LS_LoggedIn || bOnlineSubIsSteamworks))
	{
		`log("XComOnlineEventMgr: Requesting config files from server",,'XCom_Online');
		OnlineSub.Patcher.AddReadFileDelegate(OnReadTitleFileComplete);
		OnlineSub.Patcher.DownloadFiles();
	}
	else
	{
		`log("XComOnlineEventMgr: User is offline or patcher is not configured, no configs will be downloaded",,'XCom_Online');
		// Because we either aren't online or are not configured to download files, we just pretend
		// that everything is current -- jboswell
		bConfigIsUpToDate = true;
	}
}

simulated function OnReadTitleFileComplete(bool bWasSuccessful,string FileName)
{
	`log("XComOnlineEventMgr: Config file downloaded:" @ FileName @ bWasSuccessful,,'XCom_Online');
	// We don't care if it was successful, we are not going to hold the player up from playing
	// if we don't get a new config file. We only want to protect against the updated config arriving at
	// a bad time -- jboswell
	bConfigIsUpToDate = true;
}

simulated native function bool HasEliteSoldierPack();
simulated native function bool HasSlingshotPack();
simulated native function bool HasDLCEntitlement(int ContentID);
simulated native function bool HasTLEEntitlement();

simulated function ReadProfileSettings()
{
	local OnlinePlayerInterfaceEx PlayerInterfaceEx;	
	local XComOnlineProfileSettings ProfileSettings;

	PlayerInterfaceEx = OnlineSub.PlayerInterfaceEx;	

	ProfileSettings = XComOnlineProfileSettings(LocalEngine.GetProfileSettings());
	if( ProfileSettings == none )
	{
		SetupDefaultProfileSettings();

		// If creating/recreating the prifle, re-init critical card decks [2/21/2020 dmcdonough]
		class'DioStrategyAI'.static.InitCardDecks();
	}

	StorageDeviceIndex = PlayerInterfaceEx.GetDeviceSelectionResults(LocalUserIndex, StorageDeviceName);
	OnlineSub.PlayerInterface.ReadPlayerStorage(LocalUserIndex, ProfileSettings, StorageDeviceIndex);
}

//bsg-cballinger (1.11.16): BEGIN, Override function from OnlineEventMgr for proper error handling. Doing this here instead of OnlineEventMgr since we cant move the ErrorMgr to the engine level
event QueueSystemMessage(ESystemMessageType eMessageType, optional bool bIgnoreMsgAdd=false)
{
	ErrorMessageMgr.EnqueueError(eMessageType);
}

//bsg-cballinger (1.11.16): END


simulated function QueueQuitReasonMessage(EQuitReason Reason, optional bool bIgnoreMsgAdd=false)
{
	local ESystemMessageType systemMessage;
	
	systemMessage = GetSystemMessageForQuitReason(Reason);
	`log(`location $ ":" @ `ShowVar(Reason, QuitReason) @ "," @ `ShowVar(systemMessage, SystemMessage),,'XCom_Online');

	// We really don't care about QuitReasons that don't have an associated SystemMessage (just triggers disconnect, no error msg).
	if(systemMessage != SystemMessage_None)
		QueueSystemMessage(GetSystemMessageForQuitReason(Reason), bIgnoreMsgAdd);
}

simulated function ESystemMessageType GetSystemMessageForQuitReason(EQuitReason Reason)
{
	switch( Reason )
	{
	case QuitReason_SignOut:                return SystemMessage_QuitReasonLogout;
	case QuitReason_LostDlcDevice:          return SystemMessage_QuitReasonDlcDevice;
	case QuitReason_InactiveUser:           return SystemMessage_QuitReasonInactiveUser;
	case QuitReason_LostConnection:         return SystemMessage_QuitReasonLostConnection;
	case QuitReason_LostLinkConnection:     return SystemMessage_QuitReasonLinkLost;
	case QuitReason_OpponentDisconnected:   return SystemMessage_QuitReasonOpponentDisconnected;
	//<workshop> NETWORK_DISCONNECT RJM 2016/04/04
	//INS:
	case QuitReason_LostConnectionConsole:	return SystemMessage_QuitReasonLinkLostConsole;
	//</workshop>
	//<BSG> TTP_5089_5073_ADDED_PATCH_REQ_AND_AGE_RESTRICTION_MSGS JHilton 06.21.2016
	//INS:
	case QuitReason_UpdateRequired:	        return SystemMessage_UpdateRequired;
	case QuitReason_TooYoung:	            return SystemMessage_TooYoung;
	//</BSG>
	case QuitReason_MismatchContent:        return SystemMessage_MismatchContent; //bsg-fchen (8/9/16): Added DLC check to invited games
	default:
		return SystemMessage_None;
	};
}

//<workshop> CONSOLE_DLC RJM 2016/04/14
//INS:
function CheckForNewDLC()
{
	local DownloadableContentManager DLCManager;

	DLCManager = class'GameEngine'.static.GetDLCManager();
	if(DLCManager.bWantsToRefreshDLC)
	{
		DLCManager.RefreshDLC();
	}
}
//</workshop>

simulated function ReturnToStartScreen(EQuitReason Reason)
{
	`log("Returning to Start Screen" @ `ShowVar(Reason) @ `ShowEnum(ShuttleToScreenType, ShuttleToScreen, ShuttleToScreen),,'XCom_Online');

	if (Reason == QuitReason_LostConnection )
	{
		// If we received a lost connect because of a user sign out
		// then use this as the real reason for the quit.
		RefreshLoginStatus();
		if( !bHasLogin )
			Reason = QuitReason_SignOut;
	}

	QueueQuitReasonMessage(Reason, true /* bIgnoreMsgAdd */);

	if (GetShuttleToStartMenu())
	{
		`log("Ignoring duplicate return to Start Screen.",,'XCom_Online');
		ScriptTrace();
		return;
	}
	ScriptTrace();

	bInShellLoginSequence = false;
	bPerformingStandardLoad = false;
	bPerformingTransferLoad = false;
	bShowingLoginUI = false;
	bWarnedOfOnlineStatus = false;

	`ONLINEEVENTMGR.ClearAcceptedInvites(); //mmg-manstine(08.29.16): Make sure invites are cleared; fixes issues returning after accepting invite

	ResetLogin();

	`XENGINE.StopCurrentMovie();
	
	//bsg-hlee (06.21.17): Don't need this anymore since the case of transiiton between screens to main menu or start screen will be taken care of in
	//TravelToNextSceen. Reverting to prev code.
	if(!`ISCONSOLE) //Kick the user to the main menu when they log out
	{	
		SetShuttleToStartMenu();
	}

	//bsg-hlee (06.21.17): End

	if (!bDelayDisconnects)
		DisconnectAll();
	else
		bDisconnectPending = true;
}

simulated function InviteFailed(ESystemMessageType eSystemMessage, bool bTravelToMPMenus=false)
{
	`log(`location @ `ShowVar(m_bCurrentlyTriggeringBootInvite) @ `ShowVar(eSystemMessage) @ `ShowVar(bTravelToMPMenus) @ "\n" @ GetScriptTrace(),,'XCom_Online');
	// <workshop> WKB FIX_INVITE_ON_BOOT 5-12-2016
	// WAS: SetBootInviteChecked(true);
	Class'OnlineSubsystem'.static.SetPendingInvite(false);
	// </workshop>
	ClearCurrentlyTriggeringBootInvite();

	// <workshop> WKB FIX_INVITE_ON_BOOT 5-12-2016
	// INS:
	if (OnlineSub != none && OnlineSub.GameInterface != none)
	{
		OnlineSub.GameInterface.CancelGameInvite(LocalUserIndex);
	}
	// </workshop>

	if (bTravelToMPMenus)
	{
		ShowSystemMessageOnMPMenus(eSystemMessage);
	}
	else
	{
		QueueSystemMessage(eSystemMessage);
		ReturnToStartScreen(QuitReason_None);
	}
}

simulated function DelayDisconnects(bool bDelay)
{
	bDelayDisconnects = bDelay;
	if (!bDelayDisconnects && bDisconnectPending)
	{
		DisconnectAll();
	}
}

simulated function DisconnectAll()
{
	local XComGameStateNetworkManager NetworkMgr;
	
	//bsg-fchen (8/18/16): Added check not to double disconnect
	bDisconnectPending = true;
	NetworkMgr  = `XCOMNETMANAGER;
	NetworkMgr.Disconnect();
	EngineLevelDisconnect();
	bDisconnectPending = false;
	//bsg-fchen (8/18/16): End
}

//<workshop> CONSOLE_DLC RJM 2016/05/17
//INS:
event NotifyDisconnect()
{
	bIsReturningToStartScreen = true;
	CheckForNewDLC();
}
//</workshop>

function ReturnToMPMainMenuBase()
{
	ReturnToMPMainMenu();
}

function bool IsAtMPMainMenu()
{
	local XComPresentationLayerBase Presentation;
	Presentation = XComPlayerController(class'UIInteraction'.static.GetLocalPlayer(0).Actor).Pres;
	if(Presentation != none)
	{
		//This state comes from XComShellPresentationLayer.uc
		if(Presentation.IsInState('State_MPShell', true))
		{
			return true;
		}
	}

	return false;
}

/**
 *  This sets up the flow to return to the MP Main Menu.  Once the UI is initialized, 
 *  it will check here to find out if it should transfer to the Multiplayer menu.
 */
function ReturnToMPMainMenu(optional EQuitReason Reason=QuitReason_None)
{
	`log("Returning to MP Main Menu" @ `ShowVar(Reason) @ `ShowEnum(ShuttleToScreenType, ShuttleToScreen, ShuttleToScreen) @ "\n" $ GetScriptTrace(),,'XCom_Online');

	if (Reason == QuitReason_None && HasAcceptedInvites())
	{
		`log("Triggering Accepted Invites instead of returning to the MP Main Menu.",,'XCom_Online');
		// Trigger the invite
		TriggerAcceptedInvite();
		return;
	}

	QueueQuitReasonMessage(Reason, true /* bIgnoreMsgAdd */);

	if (GetShuttleToMPMainMenu())
	{
		`log("Ignoring duplicate return to MP Main Menu.",,'XCom_Online');
		return;
	}

	SetShuttleToMPMainMenu();
	DisconnectAll();
}

function bool GetCurrentlyHandlingInvite() { return mbCurrentlyHandlingInvite; }
// bsg-fchen (7/25/16): Updating supports for play together
function bool GetShuttleToMPPlayTogetherLoadout() { return bShuttleToMPPlayTogetherLoadout; }
function SetShuttleToMPPlayTogetherLoadout(bool ShouldShuttle)
{
	bShuttleToMPPlayTogetherLoadout = ShouldShuttle;
}
// bsg-fchen (7/25/16): End

private function ClearLoginSettings()
{
	LoginStatus = LS_NotLoggedIn;
	bHasLogin = false;
	bHasStorageDevice = false;
	bHasProfileSettings = false;
	StorageDeviceIndex = -1;
	StorageDeviceName = "";
	bSaveExplanationScreenHasShown = false;
}

simulated function ResetLogin()
{
	local OnlinePlayerInterface    PlayerInterface;
	local OnlinePlayerInterfaceEx  PlayerInterfaceEx;
	local OnlineContentInterface   ContentInterface;

	// Disable the MCP
	if( MCP != none )
	{
		MCP.bEnableMcpService = false;
	}

	// Clear user specific delegates
	if( OnlineSub != none )
	{
		PlayerInterface = OnlineSub.PlayerInterface;
		if( PlayerInterface != none )
		{
			//Login
			OnlineSub.PlayerInterface.ResetLogin();
			PlayerInterface.ClearLogoutCompletedDelegate(LocalUserIndex, LogoutCompletedDelegate);
			PlayerInterface.ClearLoginStatusChangeDelegate(LoginStatusChange, LocalUserIndex);

			//Player Profile
			PlayerInterface.ClearWriteProfileSettingsCompleteDelegate(LocalUserIndex, WriteProfileSettingsCompleteDelegate);
			PlayerInterface.ClearReadProfileSettingsCompleteDelegate(LocalUserIndex, ReadProfileSettingsCompleteDelegate);
			PlayerInterface.ClearWritePlayerStorageCompleteDelegate(LocalUserIndex, WritePlayerStorageCompleteDelegate);
			PlayerInterface.ClearReadPlayerStorageCompleteDelegate(LocalUserIndex, ReadPlayerStorageCompleteDelegate);
		}

		PlayerInterfaceEx = OnlineSub.PlayerInterfaceEx;
		if( PlayerInterfaceEx != none )
		{
			//Device Selection
			PlayerInterfaceEx.ClearDeviceSelectionDoneDelegate(LocalUserIndex, DeviceSelectionDoneDelegate);
		}
		
		ContentInterface = OnlineSub.ContentInterface;
		if( ContentInterface != none )
		{
			//Player content (saves)
			ContentInterface.ClearReadSaveGameDataCompleteDelegate(LocalUserIndex, OnReadSaveGameDataComplete);
			ContentInterface.ClearReadContentComplete(LocalUserIndex, OCT_SaveGame, OnUpdateSaveListComplete);
			//<workshop> OSS_CHANGES JPS 2015/11/19
			//WAS:
			//ContentInterface.ClearWriteSaveGameDataComplete(LocalUserIndex, OnWriteSaveGameDataComplete);
			//ContentInterface.ClearDeleteSaveGameDataComplete(LocalUserIndex, OnDeleteSaveGameDataComplete);
			`log("Unregistering OnWriteSaveGameDataComplete");
			ContentInterface.ClearWriteSaveGameDataCompleteDelegate(LocalUserIndex, OnWriteSaveGameDataComplete);
			ContentInterface.ClearDeleteSaveGameDataCompleteDelegate(LocalUserIndex, OnDeleteSaveGameDataComplete);
			//</workshop>
		}
	}

	// Clear any login settings
	ClearLoginSettings();
}

function InitMCP()
{
	local bool bLoggedIntoOnlineProfile;

	if( MCP != none )
	{
		bLoggedIntoOnlineProfile = LoginStatus == LS_LoggedIn;

		// Enable the MCP if we have an online profile and the config allows it.
		MCP.bEnableMcpService = bMCPEnabledByConfig && bLoggedIntoOnlineProfile;

		// Init even when disabled. This makes sure init listeners are called. MCP will still obey the enabled flag.
		//<workshop> JPS 2015/11/19
		// firaxis_depot shows this as having an argument. Where did it go in this branch?
		//WAS:
		//MCP.Init(bLoggedIntoOnlineProfile);
		MCP.Init();
		//</workshop>
	}
}

//function RefreshDLC()
//{
//	local DownloadableContentManager DLCManager;

//	DLCManager = class'GameEngine'.static.GetDLCManager();
//	if( DLCManager != none )
//	{
//		`log("Manually Refreshing DLC",,'XCom_Online');
//		DLCManager.RefreshDLC();
//	}
//	else
//	{
//		`log("Failed to manually refresh DLC. DLC Manager not found.",,'XCom_Online');
//	}
//}

function bool ShellLoginShowLoginUI(optional bool bCallLoginComplete=false)
{
	local bool bOpenedUI;
	bOpenedUI = false;

	if( bExternalUIOpen )
	{
		// We can't open the login UI while another external UI is up.
		// The login will be open when the current UI is closed.
		`log("Login UI Pending",,'XCom_Online');
		bLoginUIPending = true;
	}
	else
	{
		`log("Showing login UI",,'XCom_Online');
		bLoginUIPending = false;
		if (bCallLoginComplete)
		{
			OnlineSub.PlayerInterface.AddLoginUICompleteDelegate(OnShellLoginShowLoginUIComplete);
		}
		bOpenedUI = OnlineSub.PlayerInterface.ShowLoginUI(LocalUserIndex, false); //<workshop> ADD : LocalUserIndex
		bShowingLoginUI = bOpenedUI;
	}
	return bOpenedUI;
}

private function OnShellLoginShowLoginUIComplete(bool bWasSuccessful)
{
	OnlineSub.PlayerInterface.ClearLoginUICompleteDelegate(OnShellLoginShowLoginUIComplete);
	//<workshop> CONSOLE JPS 2015/11/20
	//WAS:
	//if (!bWasSuccessful)
	`log(`location @ "bWasSuccessful="$bWasSuccessful);

	//ORBIS_LOGIN RJM 2016/01/26
	RefreshLoginStatus();

	if (bWasSuccessful)
	//</workshop>
	{
		ShellLoginUserLoginComplete();
	}
}


simulated function SelectStorageDevice()
{
	//<workshop> CONSOLE JPS 2015/11/20
	//WAS:
	//if( bOnlineSubIsSteamworks || bOnlineSubIsPSN ) //Steamworks and PSN have default access to hard drives
	// All modern console and PC have direct hard drive access. So this can be simplified by checking Xbox360 only.
	if (!bOnlineSubIsLive)
	//</workshop>
	{
		DeviceSelectionDoneDelegate(true);
	}
	else if( bExternalUIOpen )
	{
		// We can't open the storage selection UI while another external UI is up.
		// The storage selection UI will be open when the current UI is closed.
		`log("Select Storage Device Pending",,'XCom_Online');
		bStorageSelectPending = true;
	}
	else
	{
		// Refresh Login Status
		// Under certain wacky circumstances the delegates will be called in such an order
		// that the login status is out of date here. We need to verify our login status
		// before showing the device selector. We shouldn't show it if we aren't logged in.
		RefreshLoginStatus();

		if( bHasLogin )
		{
			`log("Showing Storage Device Selector" @ `ShowVar(LocalUserIndex) @ `ShowVar(`XENGINE.GetMaxSaveSizeInBytes(), MaxSize) @ `ShowVar(bStorageSelectPending) @ `ShowVar(bInShellLoginSequence),,'XCom_Online');
			bStorageSelectPending = false;
			OnlineSub.PlayerInterfaceEx.ShowDeviceSelectionUI(
				LocalUserIndex, `XENGINE.GetMaxSaveSizeInBytes(), false, !bInShellLoginSequence);
		}
		else
		{
			`log("Storage Device Selector Failed: Login Lost",,'XCom_Online');
			bStorageSelectPending = false;
		}
	}
}

function SaveProfileSettingsImmediate()
{
	local delegate<SaveProfileSettingsComplete> dSaveProfileSettingsComplete;
	local bool bWritingProfileSettings;
	local bool bIsDataBlobUpdated;
	local bool bWroteSettingsToBuffer;
	local OnlinePlayerInterfaceEx PlayerInterfaceEx;
	local XComOnlineProfileSettings ProfileSettings;
	PlayerInterfaceEx = OnlineSub.PlayerInterfaceEx;

	ProfileSettings = XComOnlineProfileSettings(LocalEngine.GetProfileSettings());
	if (bHasProfileSettings && ProfileSettings != none && ProfileSettings.Data != none && !ProfileIsSerializing)	
	{
		`log("Saving profile to disk", , 'XCom_Online');

		ProfileSettings.PreSaveData();


		// mmg_aaron.lee (11/04/19) BEGIN - check if data blob is updated. if not, don't do a profile setting save and early return. 
		bIsDataBlobUpdated = IsDataBlobChanged();
		if (!bIsDataBlobUpdated)
		{
			bProfileDirty = false;
			
			// mmg_aaron.lee (11/18/19) BEGIN - Skip profilesettings save. Let the delegates complete. 
			foreach m_SaveProfileSettingsCompleteDelegates(dSaveProfileSettingsComplete)
			{
				dSaveProfileSettingsComplete(true);
			}
			// mmg_aaron.lee (11/18/19) END

			return;
		}
		// mmg_aaron.lee (11/04/19) END
		bWroteSettingsToBuffer = WriteProfileSettingsToBuffer();

		if (bWroteSettingsToBuffer)
		{
			ProfileIsSerializing = true;

			StorageDeviceIndex = PlayerInterfaceEx.GetDeviceSelectionResults(LocalUserIndex, StorageDeviceName);
			bWritingProfileSettings = OnlineSub.PlayerInterface.WritePlayerStorage(LocalUserIndex, ProfileSettings, StorageDeviceIndex);

			if (bWritingProfileSettings && (bShowSaveIndicatorForProfileSaves || bForceShowSaveIcon))
				ShowSaveIndicator(true);

			bProfileDirty = false;
		}
		else
		{
			`log("Cannot save profile settings: WriteProfileSettingsToBuffer failed!", , 'XCom_Online');
			foreach m_SaveProfileSettingsCompleteDelegates(dSaveProfileSettingsComplete)
			{
				dSaveProfileSettingsComplete(false);
			}
		}
	}
	else
	{
		`log("Cannot save profile settings: No profile available!", , 'XCom_Online');
		foreach m_SaveProfileSettingsCompleteDelegates(dSaveProfileSettingsComplete)
		{
			dSaveProfileSettingsComplete(false);
		}

		bProfileDirty = false;
	}

	bForceShowSaveIcon = false;
}

native function SaveProfileSettings(optional bool bForceShowSaveIndicator = false);

function DebugSaveProfileSettingsCompleteDelegate()
{
	local delegate<SaveProfileSettingsComplete> dSaveProfileSettingsComplete;
	`log(`location, true, 'XCom_Online');
	foreach m_SaveProfileSettingsCompleteDelegates(dSaveProfileSettingsComplete)
	{
		`log(`location @ "      DebugSaveProfileSettingsCompleteDelegate: " $ dSaveProfileSettingsComplete, true, 'XCom_Online');
	}
}

function AddSaveProfileSettingsCompleteDelegate( delegate<SaveProfileSettingsComplete> dSaveProfileSettingsCompleteDelegate )
{
	`log(`location @ `ShowVar(dSaveProfileSettingsCompleteDelegate), true, 'XCom_Online');
	if (m_SaveProfileSettingsCompleteDelegates.Find(dSaveProfileSettingsCompleteDelegate) == INDEX_None)
	{
		m_SaveProfileSettingsCompleteDelegates[m_SaveProfileSettingsCompleteDelegates.Length] = dSaveProfileSettingsCompleteDelegate;
	}
}

function ClearSaveProfileSettingsCompleteDelegate(delegate<SaveProfileSettingsComplete> dSaveProfileSettingsCompleteDelegate)
{
	local int i;

	`log(`location @ `ShowVar(dSaveProfileSettingsCompleteDelegate), true, 'XCom_Online');
	i = m_SaveProfileSettingsCompleteDelegates.Find(dSaveProfileSettingsCompleteDelegate);
	if (i != INDEX_None)
	{
		m_SaveProfileSettingsCompleteDelegates.Remove(i, 1);
	}
}

function CreateNewProfile()
{
	`log("Creating New Profile",,'XCom_Online');

	SetupDefaultProfileSettings();
	
	// mmg_mike.anstine TODO! JHawley - No one should be calling SetMouseState() directly - engine call is only one that matters
	// mmg_aaron.lee (06/10/19) BEGIN - Setting default value for consoles when there's no existed profile settings.
	if (`ISCONSOLE)
	{
		XComOnlineProfileSettings(LocalEngine.GetProfileSettings()).Data.SetMouseState(false);
	}
	// mmg_aaron.lee (06/10/19) END

	bHasProfileSettings = true;

	if( !bHasLogin )
	{
		`log("NOT Saving New Profile",,'XCom_Online');

		if( `ISCONSOLE )
			LossOfDataWarning(m_sLoginWarning);
		else
			LossOfDataWarning(m_sLoginWarningPC);
	}
	else
	{
		`log("Saving New Profile",,'XCom_Online');
		AddSaveProfileSettingsCompleteDelegate( NewProfileSaveComplete );
		SaveProfileSettings();
	}
}

private function NewProfileSaveComplete(bool bWasSuccessful)
{
	ClearSaveProfileSettingsCompleteDelegate( NewProfileSaveComplete );
	if( bWasSuccessful )
	{
		`log("New Profile Saved",,'XCom_Online');

		if( bInShellLoginSequence )
		{
			EndShellLogin();
		}
	}
	else
	{
		`log("New Profile Save Failed",,'XCom_Online');
		
		if( class'WorldInfo'.static.IsConsoleBuild(CONSOLE_Xbox360) )
		{
			LossOfDataWarning(m_sLossOfDataWarning360);
		}
		else
		{
			LossOfDataWarning(m_sLossOfDataWarning);
		}
	}
}

simulated private function LossOfDataWarning(string sWarningText)
{
	local XComPresentationLayerBase Presentation;
	local UIMovie_2D InterfaceMgr; 

	//bShowingLossOfDataWarning = true;

	Presentation = XComPlayerController(class'UIInteraction'.static.GetLocalPlayer(0).Actor).Pres; // GetLocalPlayer takes player index not controller index. Do not user LocalUserIndex.
	InterfaceMgr = (Presentation != none)? Presentation.Get2DMovie() : none;
	if( InterfaceMgr != none && InterfaceMgr.DialogBox != none )
	{
		if( sWarningText == m_sNoStorageDeviceSelectedWarning )
		{
			ErrorMessageMgr.EnqueueError(SystemMessage_NoStorageDevice);
		}
		else if(sWarningText == m_sLossOfDataWarning || sWarningText == m_sLossOfDataWarning360)
		{
			ErrorMessageMgr.EnqueueError(SystemMessage_LossOfData);
		}
		else if(sWarningText == m_sLoginWarning || sWarningText == m_sLoginWarningPC)
		{
			ErrorMessageMgr.EnqueueError(SystemMessage_LossOfData_NoProfile);
		}

		// Close the progress dialog if in the shell login sequence
		if( bInShellLoginSequence )
		{
			ShellLoginHideProgressDialog();
		}
		else
		{
			ClearScreenUI();
		}
	}
	//BSG_REMOVED: This is an error case, if we reach this case we probably don't want to handle it by acting as if the user acknowledged the error. Should be handled by the error mgr now anyway
	//              Moving function call to the Error Mgr, which is the only place that should be using it, as a button callback
	/*
	else
	{
		LossOfDataAccepted('eUIAction_Accept');
	}
	*/
}

private simulated function LossOfDataAccepted(Name eAction)
{
	//bShowingLossOfDataWarning = false;
	ErrorMessageMgr.HandleDialogActionErrorMsg(eAction);

	if( bCancelingShellLoginDialog )
	{
		ShellLoginProgressMsg(m_sLoadingProfile); // Going back to an earlier stage in the shell login
	}
	else if( bInShellLoginSequence )
	{
		EndShellLogin();
	}
}

private simulated function NoStorageDeviceCallback(Name eAction)
{
	//bShowingLossOfDataWarning = false;
	ErrorMessageMgr.HandleDialogActionErrorMsg(eAction);

	if( bCancelingShellLoginDialog )
	{
		ShellLoginProgressMsg(m_sLoadingProfile); // Going back to an earlier stage in the shell login
	}
	else if( eAction == 'eUIAction_Accept' )
	{
		SelectStorageDevice();
	}
	else if( bInShellLoginSequence )
	{
		EndShellLogin();
	}
}



/** Called when a dialog in the shell login sequence needs to be aborted */
private function CancelActiveShellLoginDialog()
{
	if( bInShellLoginSequence && (ErrorMessageMgr.ShowingLossOfDataWarning() || ErrorMessageMgr.ShowingLoginRequiredWarning()) )
	{
			bCancelingShellLoginDialog = true;
			//begin, remove any error messages that are invalidated after logging into a new profile
			ErrorMessageMgr.ClearErrorMsgType(SystemMessage_CorruptedSave);
			ErrorMessageMgr.ClearErrorMsgType(SystemMessage_NoStorageDevice);
			ErrorMessageMgr.ClearErrorMsgType(SystemMessage_LossOfData);
			ErrorMessageMgr.ClearErrorMsgType(SystemMessage_LossOfData_NoProfile);
			ErrorMessageMgr.ClearErrorMsgType(SystemMessage_LoginRequired);
			//end
			bCancelingShellLoginDialog = false;
		}
}

private simulated function LossOfSaveDevice()
{
	local XComPlayerController ActiveController;
	local XComPresentationLayerBase Presentation;
	local Camera PlayerCamera;

	bHasStorageDevice = false;
	StorageDeviceIndex = -1;
	StorageDeviceName = "";

	ActiveController = XComPlayerController(class'UIInteraction'.static.GetLocalPlayer(0).Actor); // GetLocalPlayer takes player index not controller index. Do not user LocalUserIndex.
	Presentation = ActiveController.Pres; // GetLocalPlayer takes player index not controller index. Do not user LocalUserIndex.
	PlayerCamera =ActiveController.PlayerCamera; 
	if( Presentation != none 
	   && Presentation.IsPresentationLayerReady()
		&& Presentation.Get2DMovie().DialogBox != none 
		&& !Presentation.Get2DMovie().DialogBox.ShowingDialog() 
		&& !Presentation.IsInState('State_ProgressDialog') 
		&& !ActiveController.bCinematicMode 
		&& !Presentation.ScreenStack.IsInputBlocked
		&& (PlayerCamera == none || !PlayerCamera.bEnableFading || PlayerCamera.FadeAmount == 0.0 ))
	{
		if( Presentation.GetStateName() == 'State_StartScreen' && !bHasProfileSettings )
		{
			`log("Ignoring loss of save device because we're on the start screen.",,'XCom_Online');
		}
		else
		{
			`log("Showing loss of save device warning.",,'XCom_Online');

			if( class'XComEngine'.static.IsLoadingMoviePlaying() )
			{
				Presentation.UIStopMovie();
			}

			// Force show the UI for this
			//bShowingLossOfSaveDeviceWarning = true;
			Presentation.Get2DMovie().PushForceShowUI();
			ActiveController.SetPause(true, CanUnpauseLossOfSaveDeviceWarning);

			ErrorMessageMgr.EnqueueError(SystemMessage_LossOfSaveDevice);
		}
	}
	//BSG_REMOVED: Redisplaying messages is now handled by error manager
	/*
	else
	{
		`log("Loss of save device warning waiting for presentation layer.",,'XCom_Online');
		bSaveDeviceWarningPending = true;
	}
	*/
}

private simulated function LossOfSaveDeviceAccepted(Name eAction)
{
	local XComPlayerController ActiveController;
	local XComPresentationLayerBase Presentation;

	ActiveController = XComPlayerController(class'UIInteraction'.static.GetLocalPlayer(0).Actor); // GetLocalPlayer takes player index not controller index. Do not user LocalUserIndex.
	Presentation = ActiveController.Pres; // GetLocalPlayer takes player index not controller index. Do not user LocalUserIndex.

	ErrorMessageMgr.HandleDialogActionErrorMsg(eAction);

	//bShowingLossOfSaveDeviceWarning = false;

	if( Presentation != none && Presentation.Get2DMovie() != none )
		Presentation.Get2DMovie().PopForceShowUI();

	ActiveController.SetPause(false, CanUnpauseLossOfSaveDeviceWarning);

	if( eAction == 'eUIAction_Accept' )
	{
		SelectStorageDevice();
	}
	else
	{
		ReturnToStartScreen(QuitReason_UserQuit);
	}
}

private function bool CanUnpauseLossOfSaveDeviceWarning()
{
	return !ErrorMessageMgr.ShowingLossOfSaveDeviceWarning();
}

event Tick(float DeltaTime)
{
	// mmg_aaron.lee (06/12/19) BEGIN - check for saveStatus change
	local XComPlayerController xPlayerController;
	local UIScreenStack ScreenStack;
	// mmg_aaron.lee (06/12/19) END

	//BSG_REMOVED: Redisplaying messages is now handled by error manager
	/*
	if( bSaveDeviceWarningPending && IsPresentationLayerReady() )
	{
		fSaveDeviceWarningPendingTimer = fmax(0, fSaveDeviceWarningPendingTimer - DeltaTime);
		if(fSaveDeviceWarningPendingTimer == 0)
		{
			bSaveDeviceWarningPending = false;
			LossOfSaveDevice();
		}
	}
	
	else if( ErrorMessageMgr.ShowingLossOfSaveDeviceWarning() && !IsPresentationLayerReady() )
	{
		// We lost our presentation layer after showing the loss of save device warning.
		// We'll have to bring it back when we get a new presentation layer.
		LossOfSaveDeviceAccepted('eUIAction_Cancel');
		bSaveDeviceWarningPending = true;
		fSaveDeviceWarningPendingTimer = StorageRemovalWarningDelayTime;
	}
	*/
	
	if( bSaveDataOwnerErrPending )
	{
		ShowPostLoadMessages();
	}

	if (bProfileDirty)
	{
		SaveProfileSettingsImmediate();
	}

	//<workshop> CONSOLE_DLC RJM 2016/05/17
	//INS:
	//CheckDLCDialog(); // BSG TODO: reenable for patch //bsg-cballinger (12.8.16): Don't re-enable, Error Message Mgr handles reopening dialogs now
	//</workshop>

	//<workshop> GAMEPAD_MANAGEMENT RJM 2016/05/13
	//INS:
	CheckLocalPlayer();
	//</workshop>

	//bsg-cballinger (11.7.16): added
	//Centralizes the call to Display, so that Display only needs to be called in this one spot
	//HOWEVER, this approach only works if EVERY error dialog box has a callback handler that at least removes the ErrorMsg from the ErrorMgr
	//Otherwise, the message never gets removed without risking losing the message before the user has acknowledged the message.
	ErrorMessageMgr.Tick(DeltaTime);

	// mmg_mike.anstine TODO JHawley - Is this still necessary?
	// mmg_aaron.lee (06/12/19) BEGIN - check for saveStatus change
	xPlayerController = XComPlayerController(class'UIInteraction'.static.GetLocalPlayer(0).Actor);
	ScreenStack = xPlayerController.Pres.ScreenStack;
	// HELIOS BEGIN	
	// Part of agnostic presentation layer
	if (ScreenStack.HasInstanceOf(`PRESBASE.UIHUD_Strategy))
	{
		CurrSaveStatus = IsConsoleSaveInProgress();
		if (CurrSaveStatus != PrevSaveStatus)
		{
			PrevSaveStatus = CurrSaveStatus;
			UIDIOHUD(ScreenStack.GetFirstInstanceOf(`PRESBASE.UIHUD_Strategy)).RefreshTurnButton();
		}
	}
	// HELIOS END		
	// mmg_aaron.lee (06/12/19) END
}

//BSG_REMOVED: ErrorMessageMgr should handle reopening
/*
//<workshop> CONSOLE_DLC RJM 2016/05/17
//INS:
private function CheckDLCDialog()
{
	local XComPlayerController PlayerController;
	local XComPresentationLayerBase Presentation;

	PlayerController = XComPlayerController(class'UIInteraction'.static.GetLocalPlayer(0).Actor);
	if(PlayerController != none)
	{
		Presentation = PlayerController.Pres;
		if(Presentation != none)
		{
			
			//Make sure the player confirms or denies the new DLC dialog.
			//Show the message again if the dialog was closed by the system.
			//if(bDLCUserConfirmationRequired)
			//{
			//Don't show the dialog when a load or movie is occurring.
			if(!`XENGINE.IsLoadingMoviePlaying() && !`XENGINE.IsAnyMoviePlaying() && PlayerController.bProcessedTravelDestinationLoaded)
			{
				if(!Presentation.UIIsShowingDialog())
				{
					ShowNewDLCMessage();
				}
			}
			else
			{
				if(Presentation.UIIsShowingDialog())
				{
					//Hide all dialogs that are displaying during a movie
					ClearScreenUI();
				}
			}
			//}
		}
	}
}
//</workshop>
*/

//<workshop> GAMEPAD_MANAGEMENT RJM 2016/05/13
//INS:
private function CheckLocalPlayer()
{
	local LocalPlayer LP;

	LP = class'UIInteraction'.static.GetLocalPlayer(0);
	if(LP != none && LP.bNeedsAnyController && LP.ControllerId != -1)
	{
		if(OnlineSub.PlayerInterfaceEx.SwapControllerToIndex0(LP.DesiredControllerId))
		{
			//Act as if this controller has just connected.
			XComPlayerController(LP.Actor).OnControllerChanged(0, true);
			`ONLINEEVENTMGR.OnControllerStatusChanged(0, true);
		}
		LP.bNeedsAnyController = false;
	}
}
//</workshop>

private function bool IsPresentationLayerReady()
{
	local XComPresentationLayerBase Presentation;
	Presentation = XComPlayerController(class'UIInteraction'.static.GetLocalPlayer(0).Actor).Pres; // GetLocalPlayer takes player index not controller index. Do not user LocalUserIndex.

	return Presentation != none && Presentation.IsPresentationLayerReady() && Presentation.Get2DMovie().DialogBox != none;
}

function bool WaitingForPlayerProfileRead()
{
	return false;
}

function bool AreAchievementsEnabled()
{
	return bAchivementsEnabled;
}

//bsg-jhilton (07.22.2016) - TTP 6768 - Properly disable achievements if the player has a super soldier
function CheckForSuperSoldier()
{
	//dakota.lemaster: 8.9.2019 we no longer use XComHQ in dio, so super soldiers aren't a thing
	//local XComGameState_Unit Unit;
	//local XComGameState_HeadquartersXCom HQState;
	//local int i;
	//local bool bAnySuperSoldiers;
	//
	//HQState = class'UIUtilities_Strategy'.static.GetXComHQ();	
	//bAnySuperSoldiers = false;
	//
	//if(`XCOMHISTORY != none && HQState != none)
	//{
	//	//Check each member of the crew
	//	for(i = 0; i < HQState.Crew.Length; i++)
	//	{
	//		Unit = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(HQState.Crew[i].ObjectID));
	//		if(Unit != none)
	//		{
	//			//Check if the the soldier is alive and super
	//			if(Unit.IsAlive() && Unit.GetMyTemplate().bIsSoldier && Unit.bIsSuperSoldier)
	//			{
	//				//Found a super soldier
	//				bAnySuperSoldiers = true;
	//				break;				
	//			}
	//		}
	//	}
	//
	//	if(bAnySuperSoldiers)
	//	{
	//		//Disable achievements
	//		EnableAchievements(false, true);
	//	}
	//	else
	//	{
	//		//Allow achievements
	//		EnableAchievements(true, false);
	//	}
	//}
}
//bsg-jhilton (07.22.2016) - End

function EnableAchievements(bool enable, optional bool bXComHero)
{
	bAchivementsEnabled = enable;
	bAchievementsDisabledXComHero = bXComHero;
}

function UnlockAchievement(EAchievementType Type)
{
	`log("UnlockAchievement: " $ AreAchievementsEnabled() $ ": " $ Type, , 'XCom_Online');

	//bsg-jhilton (07.22.2016) - TTP 6768 - Properly disable achievements if the player has a super soldier
	//Just to be safe check this here as well
	CheckForSuperSoldier();
	//bsg-jhilton (07.22.2016) - End

	if (AreAchievementsEnabled())
	{		
		OnlineSub.PlayerInterface.UnlockAchievement(LocalUserIndex, Type);
	}

	// mmg_adrian.williams (10/25/19) - No longer sending off game progress telemetry in this way.
	//CheckGameProgress(Type);
}

function int AchievementToProgressIndex(EAchievementType Type)
{
	// mmg_mike.anstine HACK - Make this work for telemetry
	return int(Type) + 1;
	switch (Type)
	{
		default: return 0;
	}
}

function int CountBits(int v)
{
	local int c;

	v = v - ((v >> 1) & 0x55555555);                    // reuse input as temporary
	v = (v & 0x33333333) + ((v >> 2) & 0x33333333);     // temp
	c = ((v + (v >> 4) & 0xF0F0F0F) * 0x1010101) >> 24; // count

	return c;
}

// mmg_adrian.williams (10/25/19) - No longer sending off game progress telemetry in this way.
//function CheckGameProgress(EAchievementType Type)
//{
//	local int progressIndex;
//	local XComGameStateHistory History;
//
//	progressIndex = AchievementToProgressIndex(Type);
//
//	if( progressIndex != 0 )
//	{
//		History = `XCOMHISTORY;
//		class'AnalyticsManager'.static.SendGameProgressTelemetry(History, string(GetEnum(enum'EAchievementType', EAchievementType(Type))));
//	}
//}

/** Sets a new Online Status and uses it to set the rich presence strings */
reliable client function SetOnlineStatus(EOnlineStatusType NewOnlineStatus)
{
	if( OnlineStatus != NewOnlineStatus )
	{
		`log("Setting online status to: " $ NewOnlineStatus,,'XCom_Online');

		OnlineStatus = NewOnlineStatus;
		RefreshOnlineStatus();
	}
}

/** Looks at the current Online Status and uses it to set the rich presence strings */
reliable client function RefreshOnlineStatus()
{
	local OnlinePlayerInterface PlayerInterface;
	local array<LocalizedStringSetting> LocalizedStringSettings;
	local array<SettingsProperty> Properties;

	if( bHasLogin )
	{
		PlayerInterface = OnlineSub.PlayerInterface;
		if (PlayerInterface != None)
		{
			`log("Refreshing online status." @ `ShowVar(LocalUserIndex) @ `ShowVar(OnlineStatus),,'XCom_Online');
			//<workshop> OSS_CHANGES JPS 2015/11/19
			//WAS:
			//PlayerInterface.SetOnlineStatus(LocalUserIndex, OnlineStatus, LocalizedStringSettings, Properties);
			PlayerInterface.SetOnlineStatus(LocalUserIndex, OnlineStatus, LocalizedStringSettings, Properties, m_aRichPresenceStrings[int(OnlineStatus)]);
			//</workshop>
		}
		else
		{
			`log("Failed to refresh online status: Missing player interface",,'XCom_Online');
		}
	}
}

reliable client function InitRichPresence()
{
	local int OnlineStatusID;
	local int UserIndex;
	local OnlinePlayerInterface PlayerInterface;
	local array<LocalizedStringSetting> LocalizedStringSettings;
	local array<SettingsProperty> Properties;

	//<workshop> RICH_PRESENCE_ENABLE kmartinez 2016-2-24
	//INS:
	if( !HasInitializedRichPresenceText )
	{
		if(`ISDURANGO)
		{
			m_aRichPresenceStrings[OnlineStatus_PlayingTheGame]="PlayingTheGame";
			m_aRichPresenceStrings[OnlineStatus_Strategy]="Strategy";
			m_aRichPresenceStrings[OnlineStatus_TacticalProgeny]="TacticalProgeny";
			m_aRichPresenceStrings[OnlineStatus_TacticalSacredCoil]="TacticalSacredCoil";
			m_aRichPresenceStrings[OnlineStatus_TacticalGrayPhoenix]="TacticalGrayPhoenix";
		}
		HasInitializedRichPresenceText = true;
	}
	//</workshop>

	PlayerInterface = OnlineSub.PlayerInterface;
	if (PlayerInterface != None)
	{
		if( bOnlineSubIsLive || bOnlineSubIsDingo || bOnlineSubIsNP )
		{
			// Set online status to OnlineStatus_PlayingTheGame for inactive users
			for( UserIndex = 0; UserIndex < 4; UserIndex++ )
			{
				if( UserIndex != LocalUserIndex ) // Do not set online status for active user. That comes later.
				{
					`log("Refreshing online status." @ `ShowVar(UserIndex),,'XCom_Online');
					PlayerInterface.SetOnlineStatus(UserIndex, OnlineStatus_PlayingTheGame, LocalizedStringSettings, Properties, m_aRichPresenceStrings[OnlineStatusID]);
				}
			}
		}
		else
		{
			`log("Initializing Rich Presence Strings",,'XCom_Online');
			for( OnlineStatusID = 0; OnlineStatusID < EOnlineStatusType.EnumCount; OnlineStatusID++ )
			{
				PlayerInterface.SetOnlineStatus(UserIndex, OnlineStatusID, LocalizedStringSettings, Properties, m_aRichPresenceStrings[OnlineStatusID]);
			}
		}
	}
	else
	{
		`log("Failed to init rich presence: Missing player interface",,'XCom_Online');
	}
}

private function RequestLoginFeatures()
{
	// called whenever the user is signed in.
	// perform any queries related to login features. e.g. request stats, friends, trophies

	OnlineSub.PlayerInterface.AddReadAchievementsCompleteDelegate(LocalUserIndex, ReadAchievementsCompleteDelegate);
	OnlineSub.PlayerInterface.ReadAchievements(LocalUserIndex);

	// need to initialize unique ID so things such as online subsystem work correctly. -tsmith 
	XComPlayerController(class'UIInteraction'.static.GetLocalPlayer(0).Actor).InitUniquePlayerId(); // GetLocalPlayer takes player index not controller index. Do not user LocalUserIndex.
}

//<workshop> CHARACTER_POOL_SERIALIZATION RJM 2016/02/12
//INS:
simulated function OnReadCharacterPoolComplete(bool bWasSuccessful,byte LocalUserNum,int DeviceId,string CharacterPoolName)
{	
	OnlineSub.ContentInterface.ClearReadCharacterPoolCompleteDelegate(`ONLINEEVENTMGR.LocalUserIndex, OnReadCharacterPoolComplete);
	//`CHARACTERPOOLMGR.PreCreateSoldiers(); //bsg-dcruz (09.12.2016) - no longer using deferred initialization for soldiers in the Character Pool
	PopulateLoadedCharacterPool();
	if(!bWasSuccessful)
	{
		ShowCorruptedCharacterPoolDialog();
	}
}

simulated function PopulateLoadedCharacterPool()
{
	local Actor TimerActor;

	TimerActor = class'WorldInfo'.static.GetWorldInfo().Spawn(class'DynamicPointInSpace');	
	TimerActor.Tag = 'Timer';

	//`CHARACTERPOOLMGR.CreateAndInitSoldiers(false); //bsg-dcruz (09.12.2016) - set to false, this wasn't iterating properly when booting from invite and then backing out
	//if(!`CHARACTERPOOLMGR.bSoldiersInitComplete)
	//{
	//	TimerActor.SetTimer(0.001, false, nameof(PopulateLoadedCharacterPool), self);
	//}
}

simulated function ShowCorruptedCharacterPoolDialog()
{
	ErrorMessageMgr.EnqueueError(SystemMessage_CorruptedCharacterPool);
}
//</workshop>

//<workshop> DISPLAYING_AUTOSAVE_MESSAGE kmartinez 2016-04-19
//INS:
simulated function ShowAutoSaveWarningDialog()
{
	//bsg-jneal 7.9.16: Use UIProgressDialogue for displaying the autosave warning
	local TProgressDialogData DialogData;

	DialogData.strTitle = ""; 
	DialogData.strDescription = m_sWarningAutoSave;
	DialogData.strAbortButtonText = class'UIDialogueBox'.default.m_strDefaultAcceptLabel;
	DialogData.fnCallback = ConfirmAutosave;

	DialogData.m_bIsAutosave = true;

	XComPlayerController(class'UIInteraction'.static.GetLocalPlayer(0).Actor).Pres.UIProgressDialog(DialogData);
	//bsg-jneal 7.9.16: end
	ShowSaveIndicatorTimedAtPctLocation(m_saveIndicatorDisplayTimeOnDialogBox, m_saveIndicatorXPct_OnDialogBox, m_saveIndicatorYPct_OnDialogBox);
}
//</workshop>

//bsg-jneal 7.9.16: UIProgressDialogue data needs a fnCallback to display button prompts so make a stub function here
private function ConfirmAutosave()
{
}
//bsg-jneal 7.9.16: end

function bool ShowGamerCardUI(UniqueNetID PlayerID)
{
	local OnlinePlayerInterfaceEx PlayerInterfaceEx;

	if (OnlineSub != None)
	{
		PlayerInterfaceEx = OnlineSub.PlayerInterfaceEx;
		if (PlayerInterfaceEx != None)
		{
			return PlayerInterfaceEx.ShowGamerCardUI(LocalUserIndex, PlayerID);
		}
		else
		{
			`log(self $ "::" $ GetFuncName() @ "OnlineSubsystem does not support the extended player interface. Can't show gamercard.", true, 'XCom_Online');
		}
	}
	else
	{
		`log(self $ "::" $ GetFuncName() @ "No OnlineSubsystem present. Can't show gamercard.", true, 'XCom_Online');
	}

	return false;
}

//<workshop> PS4/XB1 GamerCard Handling - JTA - 2016/3/2
//INS:
//PS4 needs the PlayerName to show the gamercard, while XB1 uses the UniqueNetID (Both can be found in XComGameState_Player)
//This function will decide which is necessary and call the proper function
function bool ShowGamerCardUIByIDAndName(UniqueNetId NetID, String PlayerName)
{
	local bool bSuccess;
	local OnlineSubsystem OnlineSubsystem;

	OnlineSubsystem = class'GameEngine'.static.GetOnlineSubsystem();

	if(`ISORBIS)
		bSuccess = OnlineSubsystem.PlayerInterfaceEx.ShowGamerCardUIByUsername(0, PlayerName);
	else if(`ISDURANGO)
		bSuccess = OnlineSubsystem.PlayerInterfaceEx.ShowGamerCardUI(0, NetID);
	else
		`log("Unexpected result when attempting to view GamerCard of Player" @ PlayerName);

	if(bSuccess)
		`log("Successful Request: View Gamercard of Player" @ PlayerName);
	else
		`log("Unsuccessful Request: View Gamercard of Player" @ PlayerName);

	return bSuccess;
}
//</workshop>

function bool GetSaveGames( out array<OnlineSaveGame> SaveGames )
{
	local OnlineContentInterface ContentInterface;
	local EOnlineEnumerationReadState ReadState;
	local bool bSuccess;

	SaveGames.Remove(0, SaveGames.Length);

	ContentInterface = OnlineSub.ContentInterface;
	if( ContentInterface != none )
	{
		ReadState = ContentInterface.GetSaveGames(LocalUserIndex, SaveGames);
		bSuccess = ReadState == OERS_Done || (!bOnlineSubIsLive && ReadState == OERS_NotStarted);
		CheckSaveIDs(SaveGames);

		`log(self $ "::" $ GetFuncName() @ `ShowVar(ReadState), true, 'XCom_Online');
	}
	else
	{
		bSuccess = false;

		`log(self $ "::" $ GetFuncName() $ " failed to retrieve content interface", true, 'XCom_Online');
	}

	return bSuccess;
}

//<workshop> LOADING_SAVE_HEADERS RJM 2016/03/31
//INS:
function bool GetSaveGameMetadata( out array<SaveGameMetadata> SaveGames )
{
	local OnlineContentInterface ContentInterface;
	local EOnlineEnumerationReadState ReadState;
	local bool bSuccess;

	SaveGames.Remove(0, SaveGames.Length);

	ContentInterface = OnlineSub.ContentInterface;
	if( ContentInterface != none )
	{
		ReadState = ContentInterface.GetSaveGameMetadata(LocalUserIndex, SaveGames);
		bSuccess = ReadState == OERS_Done;

		`log(self $ "::" $ GetFuncName() @ `ShowVar(ReadState), true, 'XCom_Online');
	}
	else
	{
		bSuccess = false;

		`log(self $ "::" $ GetFuncName() $ " failed to retrieve content interface", true, 'XCom_Online');
	}

	return bSuccess;
}
//</workshop>

function OnlineStatsRead GetOnlineStatsRead()
{
	return m_kStatsRead;
}

function bool GetOnlineStatsReadSuccess()
{
	return m_bStatsReadSuccessful;
}

function bool IsReadyForMultiplayer()
{
	// Check to make sure that we're logged in and that we're logged in to the correct local player.
	// The local player may change if an inactive controller accepts an invite. We want this to trigger a new "shell" login.
	return bHasProfileSettings && !bInShellLoginSequence && LocalUserIndex == LocalEngine.GamePlayers[0].PlayerIndex; //bsg-jrucker (8/11/16): Update to use PlayerIndex.
}

/**
 * @return true if inactive controllers are logged in, false otherwise
 */
function bool CheckForInactiveProfiles()
{
	local int UserIndex;
	local ELoginStatus InactiveUserLoginStatus;
	local OnlinePlayerInterface PlayerInterface;

	PlayerInterface = OnlineSub.PlayerInterface;
	if( PlayerInterface != none )
	{
		for( UserIndex = 0; UserIndex < 4; UserIndex++ )
		{
			if( UserIndex != LocalUserIndex ) // Do not check the active user
			{
				InactiveUserLoginStatus = PlayerInterface.GetLoginStatus(UserIndex);
				if( InactiveUserLoginStatus != LS_NotLoggedIn )
					return true;
			}
		}
	}

	return false;
}


function bool CheckOnlineConnectivity()
{
	local UniqueNetId ZeroID;
	local XComPlayerController xPlayerController;

	xPlayerController = XComPlayerController(class'UIInteraction'.static.GetLocalPlayer(0).Actor);
	if (OnlineSub.PlayerInterface.GetLoginStatus(LocalUserIndex) != LS_LoggedIn ||
	    xPlayerController.PlayerReplicationInfo == none ||
	    xPlayerController.PlayerReplicationInfo.UniqueId == ZeroID)
	{
		return false;
	}
	else if( class'WorldInfo'.static.IsConsoleBuild(CONSOLE_Xbox360) && OnlineSub.PlayerInterface.IsGuestLogin(LocalUserIndex) )
	{
		return false;
	}

	return true;
}

// Checks for any lingering system messages or dialogs to be displayed 
// since they may have been torn-down via a loading screen.
function PerformNewScreenInit()
{
	local XComPresentationLayerBase kPres;

	kPres = XComPlayerController(class'UIInteraction'.static.GetLocalPlayer(0).Actor).Pres;
	if(kPres != none)
	{
		// Display the controller unplugged message if it was unplugged before accepting a multiplayer invite
		if(`ISCONSOLE && m_bControllerUnplugged)
		{
				`log("Showing controller unplugged dialog",,'xcomui');
			kPres.UIControllerUnplugDialog(`ONLINEEVENTMGR.LocalUserIndex);
		}

		//kPres.SanitizeSystemMessages(); //bsg-cballinger (11.18.16): BSG_REMOVED, uses error message mgr now
	}

	if(m_bCurrentlyTriggeringBootInvite)
	{
		// Were there any critical system messages removed? (i.e. were there any problems loading the invite?)
		if(ErrorMessageMgr.CountErrorMsg() > 0)
		{
			InviteFailed(SystemMessage_BootInviteFailed);
		}
	}

	//ActivateAllSystemMessages(); // No longer trigger invites here, instead wait for an explicit call from the Loadout UI //bsg-cballinger (11.17.16): BSG_REMOVED old system message system
}

native function bool HasValidLoginAndStorage();

native function bool ReadProfileSettingsFromBuffer();
native function bool WriteProfileSettingsToBuffer();
native function bool IsDataBlobChanged();
// Save / Load functionality
//==================================================================================================================
function UpdateSaveGameList()
{
	local OnlineContentInterface ContentInterface;

	`log("Refreshing Save Game List",,'XCom_Online');

	bUpdateSaveListInProgress = true;

	ContentInterface = OnlineSub.ContentInterface;

	if( ContentInterface != none )
	{
		if( bHasStorageDevice )
		{
			CallUpdateSaveListStartedDelegates();
			ContentInterface.ReadContentList(LocalUserIndex, OCT_SaveGame, StorageDeviceIndex);
		}
		else
		{
			// Wipe out any cached saved games if there is no save device
			ContentInterface.ClearContentList(LocalUserIndex, OCT_SaveGame);
			OnUpdateSaveListComplete(true);
		}
	}
	else
	{
		// No content interface means a failed save game list update
		OnUpdateSaveListComplete(false);
	}
}

//<workshop> CONSOLE JPS 2015/11/18
//WAS:
//native function bool GetSaveSlotDescription(int SaveSlotIndex, out string Description);
//native function bool GetSaveSlotMapName(int SaveSlotIndex, out string MapName);
//native function bool GetSaveSlotLanguage(int SaveSlotIndex, out string Language);
function bool GetSaveSlotDescription(int SaveSlotIndex, out string Description)
{
	local array<OnlineContent> ContentList;
	local SaveGameHeader Header;
	local array<OnlineSaveGame> SaveGames;

	if ( SaveSlotIndex < 0 )
	{
		`log("Invalid SavedID sent to XComOnlineEventMgr.GetSaveSlotFriendlyName",,'DevOnline');
		return false;
	}

	if (OnlineSub != None && OnlineSub.ContentInterface != None)
	{
		OnlineSub.ContentInterface.GetContentList(LocalUserIndex, OCT_SaveGame, ContentList);
		OnlineSub.ContentInterface.GetSaveGames(LocalUserIndex, SaveGames);

		if ( SaveSlotIndex >= 0 && SaveSlotIndex < ContentList.Length )
		{
			if ( ContentList[SaveSlotIndex].bIsCorrupt || SaveGames[SaveSlotIndex].SaveGames.Length == 0 )
			{
				Description = m_sCorrupt @ ContentList[SaveSlotIndex].FriendlyName;
			}
			else 
			{
				Header = SaveGames[SaveSlotIndex].SaveGames[0].SaveGameHeader;
				if (Header.Description == "Crash Report Save" ||
					Header.Description == "Error Report Save")
				{
					Description = Header.Time $ "----" $ Header.Description;
				}
				else
				{
					Description = Header.Description;
				}

				if (Header.VersionNumber != 0 && Header.VersionNumber != CheckpointVersion) // VersionNumber is 0 if not set
				{
					Description $= " (Outdated)";
				}
			}

			return true;
		}
	}

	return false;
}

function bool GetSaveSlotMapName(int SaveSlotIndex, out string MapName)
{
	local array<OnlineContent> ContentList;
	local array<OnlineSaveGame> SaveGames;

	MapName = "";

	if ( SaveSlotIndex < 0 )
	{
		`log("Invalid SavedID sent to XComOnlineEventMgr.GetSaveSlotMapName",,'DevOnline');
		return false;
	}
	
	OnlineSub.ContentInterface.GetContentList(LocalUserIndex, OCT_SaveGame, ContentList);
	OnlineSub.ContentInterface.GetSaveGames(LocalUserIndex, SaveGames);
	if ( SaveSlotIndex >= 0 && SaveSlotIndex < SaveGames.Length )
	{
		if ( !ContentList[SaveSlotIndex].bIsCorrupt && SaveGames[SaveSlotIndex].SaveGames.Length > 0 )
		{
			if (!class'WorldInfo'.static.IsConsoleBuild(CONSOLE_PS3))
			{
				MapName = GrabMapNameFromMapCommand(SaveGames[SaveSlotIndex].SaveGames[0].SaveGameHeader.MapCommand);
			}

			if ( InStr(SaveGames[SaveSlotIndex].SaveGames[0].SaveGameHeader.MapCommand, "?") > -1 )
			{
				//If the save was loaded or saved, it will have a normal map command
				MapName = GrabMapNameFromMapCommand(SaveGames[SaveSlotIndex].SaveGames[0].SaveGameHeader.MapCommand);
			}
			else
			{
				//The PS3 is special and just stores the mapname in the MapCommand directly until the header is actually loaded ( when loading a saved game or saving one )
				MapName = SaveGames[SaveSlotIndex].SaveGames[0].SaveGameHeader.MapCommand;
			}
		}	
	}

	return Len(MapName) > 0;
}

function bool GetSaveSlotLanguage(int SaveSlotIndex, out string Language)
{
	local array<OnlineContent> ContentList;
	local SaveGameHeader Header;
	local OnlineSaveGame SavedGame;
	local array<OnlineSaveGame> SaveGames;
	local OnlineContent SavedGameContent;

	if ( SaveSlotIndex < 0 )
	{
		`log("Invalid SavedID sent to XComOnlineEventMgr.GetSaveSlotLanguage",,'DevOnline');
		return false;
	}

	if (OnlineSub != None && OnlineSub.ContentInterface != None)
	{
		OnlineSub.ContentInterface.GetContentList(LocalUserIndex, OCT_SaveGame, ContentList);
		OnlineSub.ContentInterface.GetSaveGames(LocalUserIndex, SaveGames);

		if ( SaveSlotIndex >= 0 && SaveSlotIndex < ContentList.Length )
		{
			SavedGame = SaveGames[SaveSlotIndex];
			SavedGameContent = ContentList[SaveSlotIndex];
			Header = SavedGame.SaveGames[0].SaveGameHeader;

			// mmg_aaron.lee (11/11/19) - Check if header.language is null for TRC R4096.
			//                            When Fake User Data Broken is on, the SaveGameContent gets reset and Header is emptied out.
			if ( SavedGameContent.bIsCorrupt || SavedGame.SaveGames.Length == 0 || header.Language == "" ) 
			{
				// We can't tell what the language is if the save is corrupt
				// Let's just assume the language is the current language so
				// it still appears in the save game list.
				Language = GetLanguage();
			}
			else 
			{
				if ( Header.VersionNumber != 0 && Header.Language == "" ) // VersionNumber is 0 if not set
				{
					Language = ""; // mmg_mike.anstine TODO! alee
				}
				else
				{
					Language = Header.Language;
				}
			}

			return true;
		}
	}

	return false;
}
//</workshop>

/**Events for the save games to get writter or read from native code*/
private event ReadSaveGameData(byte LocalUserNum,int DeviceId,string FriendlyName,string FileName,string SaveFileName)
{
	local OnlineContentInterface ContentInterface;

	ContentInterface = OnlineSub.ContentInterface;
	if( ContentInterface != none )
	{
		ContentInterface.ReadSaveGameData(LocalUserNum, DeviceId, FriendlyName, FileName, SaveFileName);
	}
}

//This method is called AFTER the successful / unsuccessful load of saved game data, but before the map open command has been sent.
private event PreloadSaveGameData(byte LocalUserNum, bool Success, int GameNum, int SaveID)
{
	local XComGameStateHistory History;
	local XComOnlineEventMgr EventManager;
	local array<X2DownloadableContentInfo> DLCInfos;
	local XComGameState_CampaignSettings Settings;
	local int i;
	local name DLCName;

	if(Success)
	{	
		History = `XCOMHISTORY;

		//bsg-jhilton (07.22.2016) - TTP 6768 - Properly disable achievements if the player has a super soldier
		//Disable achievements if a super soldier is being used
		CheckForSuperSoldier();
		//bsg-jhilton (07.22.2016) - End

		//Fills out the 'RequestedArchetypes' array in the content manager by iterating the state objects in the recently loaded history
		`CONTENT.RequestContent();

		//Check to see if we have campaign settings. If so, see if we have DLCs that have been newly added that should process - and if so
		//add them to our list of required DLC
		Settings = XComGameState_CampaignSettings(History.GetSingleGameStateObjectForClass(class'XComGameState_CampaignSettings', true));
		if(Settings != none)
		{	
			EventManager = `ONLINEEVENTMGR;
			
			// Let the DLC / Mods hook the creation of a new campaign
			DLCInfos = EventManager.GetDLCInfos(true);
			for(i = 0; i < DLCInfos.Length; ++i)
			{
				DLCInfos[i].OnLoadedSavedGame();
			}

			// Add new DLCs to the list of required DLCs. Directly writing to the state object outside of a game state change is 
			// unorthodox, but works for this situation
			for(i = 0; i < EventManager.GetNumDLC(); ++i)
			{
				DLCName = EventManager.GetDLCNames(i);					
				if(Settings.RequiredDLC.Find(DLCName) == -1)
				{
					Settings.AddRequiredDLC(DLCName);
				}
			}			
		}
	}
}

private event WriteSaveGameData(byte LocalUserNum, int DeviceId, string FileName, const out array<byte> SaveGameData, string FriendlyName, const out SaveGameHeader SaveHeader)
{
	local OnlineContentInterface ContentInterface;
	local bool bWritingSaveGameData;

	ContentInterface = OnlineSub.ContentInterface;
	if( ContentInterface != none )
	{
		m_sCustomSaveDescription = "";
		
		bWritingSaveGameData = ContentInterface.WriteSaveGameData(LocalUserNum, DeviceId, FriendlyName, FileName, FileName, SaveGameData, SaveHeader);

		if( bWritingSaveGameData )
			ShowSaveIndicator();
	}
}

//<workshop> DISPLAYING_AUTOSAVE_MESSAGE kmartinez 2016-04-19
//INS:
function ShowSaveIndicatorTimedAtPctLocation(float seconds, float xPct, float yPct)
{
	local XComPresentationLayerBase Presentation;

	Presentation = XComPlayerController(class'UIInteraction'.static.GetLocalPlayer(0).Actor).Pres; // GetLocalPlayer takes player index not controller index. Do not user LocalUserIndex.
	if( Presentation != none )
	{
		Presentation.GetAnchoredMessenger().Message(
		`ISCONSOLE? "" : m_strSaving, // No text for the save indicator on consoles
			xPct, yPct, BOTTOM_CENTER, seconds, "SaveIndicator", eIcon_Globe);
	}
}
//</workshop>

function ShowSaveIndicator(bool bProfileSave=false)
{
	//<workshop> SAVE_ICON RJM 2016/03/16
	//WAS:
	////RAM - disabling while Brit is refactoring the UI system
	////local float SaveIndicatorDuration;
	////local XComPresentationLayerBase Presentation;
	//
	////Presentation = XComPlayerController(class'UIInteraction'.static.GetLocalPlayer(0).Actor).Pres; // GetLocalPlayer takes player index not controller index. Do not user LocalUserIndex.
	////if( Presentation != none )
	////{
	////	if( class'WorldInfo'.static.IsConsoleBuild(CONSOLE_XBOX360) )
	////	{
	////		SaveIndicatorDuration = (bProfileSave)? 1.0f : 3.0f;
	////	}
	////	else if( class'WorldInfo'.static.IsConsoleBuild(CONSOLE_PS3) )
	////	{
	////		SaveIndicatorDuration = 3.0f;
	////	}
	////	else
	////	{
	////		SaveIndicatorDuration = 2.5f; // PC
	////	}
	//
	////	Presentation.QueueAnchoredMessage().Message(
	////		`ISCONSOLE? "" : m_strSaving, // No text for the save indicator on consoles
	////		0.9f, 0.9f, BOTTOM_CENTER, SaveIndicatorDuration, "SaveIndicator", eIcon_Globe);
	////}
	local XComPresentationLayerBase Presentation;
	local XComGameStateHistory History;
	local float xPct;
	local float yPct;

	History = `XCOMHISTORY;
	//if is tactical
	if(XComGameStateContext_TacticalGameRule(History.GetGameStateFromHistory(History.FindStartStateIndex()).GetContext()) != None)
	{
		xPct = m_saveIndicatorXPct_InTacticalMode;
		yPct = m_saveIndicatorYPct_InTacticalMode;
	}
	else
	{
		xPct = m_saveIndicatorXPct_InStrategyMode;
		yPct = m_saveIndicatorYPct_InStrategyMode;
	}

	Presentation = XComPlayerController(class'UIInteraction'.static.GetLocalPlayer(0).Actor).Pres; // GetLocalPlayer takes player index not controller index. Do not user LocalUserIndex.
	if( Presentation != none )
	{
		Presentation.GetAnchoredMessenger().Message(
			`ISCONSOLE? "" : m_strSaving, // No text for the save indicator on consoles
			xPct, yPct, BOTTOM_CENTER, m_saveIndicatorDisplayTimeNormaly, "SaveIndicator", eIcon_Globe);
	}
	//</workshop>

}

// Immediately hide a raised save indicator
function HideSaveIndicator()
{
	local XComPresentationLayerBase Presentation;

	Presentation = XComPlayerController(class'UIInteraction'.static.GetLocalPlayer(0).Actor).Pres; // GetLocalPlayer takes player index not controller index. Do not user LocalUserIndex.
	if( Presentation != none )
	{
		Presentation.GetAnchoredMessenger().RemoveMessage( "SaveIndicator" );
	}
}

//This description will be used in the next save operation ( and cleared after )
simulated function SetPlayerDescription(string CustomDescription)
{
	m_sCustomSaveDescription = CustomDescription;
}

event FillInHeaderForSave(out SaveGameHeader Header, string SaveType, out string SaveFriendlyName, optional int PartialHistorySaveIndex = -1)
{	
	local WorldInfo LocalWorldInfo;	
	local XComGameInfo LocalGameInfo;	
	local int Year, Month, DayOfWeek, Day, Hour, Minute, Second, Millisecond;
	local XComGameStateHistory History;
	local XComGameState_CampaignSettings CampaignSettingsStateObject;
	local int Index;	
	local string DLCName;
	local string DLCFriendlyName;
	local XComGameState_Player PlayerState;
	local XComGameState_BattleData BattleData;
	local XComGameState_Analytics AnalyticsState;
	local XGParamTag kTag;
	local XComGameState_LadderProgress LadderData;
	local X2TacticalGameRuleset TacticalGameRule;
		
	kTag = XGParamTag(`XEXPANDCONTEXT.FindTag("XGParam"));
	History = `XCOMHISTORY;
	TacticalGameRule = `TACTICALRULES;

	LocalWorldInfo = class'Engine'.static.GetCurrentWorldInfo();
	LocalGameInfo = XComGameInfo(LocalWorldInfo.Game);

	LocalWorldInfo.GetSystemTime(Year, Month, DayOfWeek, Day, Hour, Minute, Second, Millisecond);
	FormatTimeStamp(Header.Time, Year, Month, Day, Hour, Minute);

	BattleData = XComGameState_BattleData(History.GetSingleGameStateObjectForClass(class'XComGameState_BattleData', true) );
	CampaignSettingsStateObject = XComGameState_CampaignSettings(History.GetSingleGameStateObjectForClass(class'XComGameState_CampaignSettings', true));
	if(CampaignSettingsStateObject != none)
	{
		Header.DLCPackNames.Length = 0;
		Header.DLCPackFriendlyNames.Length = 0;
		for(Index = 0; Index < CampaignSettingsStateObject.RequiredDLC.Length; ++Index)
		{
			DLCName = string(CampaignSettingsStateObject.RequiredDLC[Index]);
			Header.DLCPackNames.AddItem(DLCName);
			DLCFriendlyName = GetDLCFriendlyName(DLCName);
			if(DLCFriendlyName != "")
			{
				Header.DLCPackFriendlyNames.AddItem(DLCFriendlyName);
			}
			else
			{
				Header.DLCPackFriendlyNames.AddItem(DLCName);
			}
		}

		Header.CampaignStartTime = CampaignSettingsStateObject.StartTime;		
		Header.GameNum = CampaignSettingsStateObject.GameIndex;
	}
	else
	{
		Header.CampaignStartTime = "DEBUG";
	}
			
	Header.Description = Header.Time;

	// fill in Month
	//StartDateTime = class'UIUtilities_Strategy'.static.GetResistanceHQ().StartTime;
	//CurrentTime = class'XComGameState_GeoscapeEntity'.static.GetCurrentTime();
	Header.Month = class'UIUtilities_Strategy'.static.GetGameTime().CurrentTime.m_iMonth;

	// fill in Turn/Actions taken
	foreach History.IterateByClassType(class'XComGameState_Player', PlayerState, , , PartialHistorySaveIndex)
	{
		if( PlayerState.GetTeam() == eTeam_XCom )
		{
			break;
		}
	}
	Header.Turn = PlayerState.PlayerTurnCount;
	Header.Action = PlayerState.ActionsTakenThisTurn;
	Header.SaveType = SaveType;

	// fill in Mission # (-1 for TQL)
	if( (BattleData != none) && BattleData.bIsTacticalQuickLaunch )
	{
		Header.Mission = -1;
	}
	else
	{
		AnalyticsState = XComGameState_Analytics(History.GetSingleGameStateObjectForClass(class'XComGameState_Analytics'));
		Header.Mission = AnalyticsState.GetFloatValue("BATTLES_WON") + AnalyticsState.GetFloatValue("BATTLES_LOST") + 1;
	}

	LadderData = XComGameState_LadderProgress( History.GetSingleGameStateObjectForClass(class'XComGameState_LadderProgress', true) );
	if (LadderData != none)
	{		
		Header.GameNum = LadderData.LadderIndex;
		Header.Mission = LadderData.LadderRung;
	}

	// user-generated description
	if( m_sCustomSaveDescription != "" )
	{
		Header.PlayerSaveDesc = m_sCustomSaveDescription;
	}	
	else
	{
		kTag.IntValue0 = Header.Turn;
		switch (SaveType)
		{
		case "Autosave":
		case "Ironman":
			if (TacticalGameRule != none)
			{
				Header.PlayerSaveDesc = class'XComLocalizer'.static.ExpandString(m_strTacticalAutosaveFormatString);
			}
			else
			{
				kTag.IntValue0 = `THIS_TURN;
				Header.PlayerSaveDesc = class'XComLocalizer'.static.ExpandString(m_strStrategyAutosaveFormatString);
			}
			break;
		case "TactSessionStart":
			Header.PlayerSaveDesc = class'XComLocalizer'.static.ExpandString(m_strTacticalSessionStartFormatString);
			break;
		case "TactEncounterStart":
			Header.PlayerSaveDesc = class'XComLocalizer'.static.ExpandString(m_strTacticalEncounterStartFormatString);
			break;
		case "StrategyTurnStart":
			kTag.IntValue0 = `THIS_TURN;
			Header.PlayerSaveDesc = class'XComLocalizer'.static.ExpandString(m_strStrategyTurnStartFormatString);
			break;
		}
	}

	// HELIOS BEGIN
	// One last fallback, obtain the Header from the LocalGameInfo
	if (Header.PlayerSaveDesc == "")
		Header.PlayerSaveDesc = LocalGameInfo.GetSaveGameHeader(SaveType);
	// HELIOS END
	
	// fallback - "Save #"
	if(Header.PlayerSaveDesc == "")
	{
		Header.PlayerSaveDesc = m_sEmptySaveString @ GetNextSaveID();
	}
			
	Header.Description $= "\n" $ Header.PlayerSaveDesc;
	Header.Description $= "\n" $ LocalGameInfo.GetSavedGameDescription();
	Header.MapCommand = LocalGameInfo.GetSavedGameCommand();
	Header.MapImage = LocalGameInfo.GetSavedGameMapBriefingImage();
	Header.VersionNumber = class'XComOnlineEventMgr'.const.CheckpointVersion;
	Header.Language = GetLanguage();

	if (class'WorldInfo'.static.IsConsoleBuild(CONSOLE_Xbox360)) 
		SaveFriendlyName = Header.Time; // The Xbox 360 dashboard has very limited space to show save game names
	//<workshop> ORBIS_SAVE RJM 2016/01/27
	//INS:
	else if(`ISORBIS)
	{
		`log("FillInHeaderForSave: " @ Header.PlayerSaveDesc,,'XCom_Online');
		SaveFriendlyName = Header.PlayerSaveDesc; // PS4 friendly name cannot contain '\n'.
	}
	//</workshop>
	else
		SaveFriendlyName = Header.Description;
}

//DLC references both mods and Firaxis DLCs.
native function bool IsDLCRequiredAtCampaignStart(string dlcName);
native function bool IsNewDLCInstalled(); // bsg-jhilton (05.03.2017) - Fix console DLC refreshing
native function name GetDLCNames(int index);
native function int GetNumDLC();
native function string GetDLCFriendlyName(string DLCName);

//Returns a list of X2DownloadableContentInfo corresponding to various DLCs and mods that are installed. Mods & DLCs aren't required to implement this, but
//it is highly recommended for them to do since many Mods/DLC need custom handling when being installed.
//
//If bNewDLCOnly is TRUE, the function retrieves the current campaign settings object from the history and only returns content infos for DLCs that are new
//to that campaign
native function array<X2DownloadableContentInfo> GetDLCInfos(bool bNewDLCOnly);

/** Create a time stamp string in the format used for X-Com saves */
native static function FormatTimeStamp(out string TimeStamp, int Year, int Month, int Day, int Hour, int Minute);
native static function string FormatTimeStampFor12HourClock(string TimeStamp);
native static function FormatTimeStampSingleLine12HourClock(out string TimeStamp, int Year, int Month, int Day, int Hour, int Minute);


/** Provided for the save / load UI - where saves need to be ordered from most recent to oldest*/
native function SortSavedGameListByTimestamp(out array<OnlineSavegame> SaveGameList, optional int MaxUserSaves = 100);

function bool ArePRIStatsNewerThanCachedVersion(XComPlayerReplicationInfo PRI)
{
	local int iPRIStatsSum;
	local int iCachedStatsSum;
	local bool bResult;
	local UniqueNetId kZeroID;

	bResult = false;
	`log(self $ "::" $ GetFuncName() @ PRI.ToString() @ "CachedStats=" $ TMPLastMatchInfo_Player_ToString(m_kMPLastMatchInfo.m_kLocalPlayerInfo), true, 'XCom_Online');
	// only want to use cached stats for ourself or if the cache -tsmith 
	if(PRI.UniqueId == m_kMPLastMatchInfo.m_kLocalPlayerInfo.m_kUniqueID) 
	{
		// our stats are always increasing so newer stats will always sum to a larger value -tsmith 
		iPRIStatsSum = PRI.m_iRankedDeathmatchMatchesWon + PRI.m_iRankedDeathmatchMatchesLost + PRI.m_iRankedDeathmatchDisconnects;
		iCachedStatsSum = m_kMPLastMatchInfo.m_kLocalPlayerInfo.m_iWins + m_kMPLastMatchInfo.m_kLocalPlayerInfo.m_iLosses + m_kMPLastMatchInfo.m_kLocalPlayerInfo.m_iDisconnects;
		`log(self $ "::" $  GetFuncName() @ `ShowVar(iPRIStatsSum) @ `ShowVar(iCachedStatsSum), true, 'XCom_Online');
		bResult = iPRIStatsSum >= iCachedStatsSum;
	}
	else
	{
		// if the cached stats unique id is empty that means the game has just started running so the PRI stats will definitely be newer. -tsmith 
		bResult = m_kMPLastMatchInfo.m_kLocalPlayerInfo.m_kUniqueID  == kZeroId;
	}

	return bResult;
}

static function FillPRIFromLastMatchPlayerInfo(out TMPLastMatchInfo_Player kLastMatchPlayerInfo, XComPlayerReplicationInfo kPRI)
{
	kPRI.UniqueId = kLastMatchPlayerInfo.m_kUniqueID;
	kPRI.m_iRankedDeathmatchMatchesWon = kLastMatchPlayerInfo.m_iWins;
	kPRI.m_iRankedDeathmatchMatchesLost = kLastMatchPlayerInfo.m_iLosses;
	kPRI.m_iRankedDeathmatchDisconnects = kLastMatchPlayerInfo.m_iDisconnects;
	kPRI.m_iRankedDeathmatchSkillRating = kLastMatchPlayerInfo.m_iSkillRating;
	kPRI.m_iRankedDeathmatchRank = kLastMatchPlayerInfo.m_iRank;
	kPRI.m_bRankedDeathmatchLastMatchStarted = kLastMatchPlayerInfo.m_bMatchStarted;

	`log(GetFuncName() @ TMPLastMatchInfo_Player_ToString(kLastMatchPlayerInfo), true, 'XCom_Net');
}

static function FillLastMatchPlayerInfoFromPRI(out TMPLastMatchInfo_Player kLastMatchPlayerInfo, XComPlayerReplicationInfo kPRI)
{
	kLastMatchPlayerInfo.m_kUniqueID = kPRI.UniqueId;
	kLastMatchPlayerInfo.m_iWins = kPRI.m_iRankedDeathmatchMatchesWon;
	kLastMatchPlayerInfo.m_iLosses = kPRI.m_iRankedDeathmatchMatchesLost;
	kLastMatchPlayerInfo.m_iDisconnects = kPRI.m_iRankedDeathmatchDisconnects;
	kLastMatchPlayerInfo.m_iSkillRating = kPRI.m_iRankedDeathmatchSkillRating;
	kLastMatchPlayerInfo.m_iRank = kPRI.m_iRankedDeathmatchRank;
	kLastMatchPlayerInfo.m_bMatchStarted = kPRI.m_bRankedDeathmatchLastMatchStarted;

	`log(GetFuncName() @ TMPLastMatchInfo_Player_ToString(kLastMatchPlayerInfo), true, 'XCom_Net');
}

static function string TMPLastMatchInfo_ToString(const out TMPLastMatchInfo kLastMatchInfo)
{
	local string strRep;

	strRep = "\n    IsRanked=" $ kLastMatchInfo.m_bIsRanked;
	strRep @= "\n    Automatch=" $ kLastMatchInfo.m_bAutomatch;
	strRep @= "\n    MapPlotType=" $ kLastMatchInfo.m_iMapPlotType;
	strRep @= "\n    MapBiomeType=" $ kLastMatchInfo.m_iMapBiomeType;
	strRep @= "\n    NetworkType=" $ kLastMatchInfo.m_eNetworkType;
	strRep @= "\n    GameType=" $ kLastMatchInfo.m_eGameType;
	strRep @= "\n    TurnTimeSeconds=" $ kLastMatchInfo.m_iTurnTimeSeconds;
	strRep @= "\n    MaxSquadCost=" $ kLastMatchInfo.m_iMaxSquadCost;
	strRep @= "\n    LocalPlayerInfo=" $ TMPLastMatchInfo_Player_ToString(kLastMatchInfo.m_kLocalPlayerInfo);
	strRep @= "\n    RemotePlayerInfo=" $ TMPLastMatchInfo_Player_ToString(kLastMatchInfo.m_kRemotePlayerInfo);

	return strRep;
}

static function string TMPLastMatchInfo_Player_ToString(const out TMPLastMatchInfo_Player kLastMatchInfoPlayer)
{
	local string strRep;

	strRep = "\n        PlayerUniqueNetId=" $ class'OnlineSubsystem'.static.UniqueNetIdToString(kLastMatchInfoPlayer.m_kUniqueID);
	strRep @= "\n        MatchStarted=" $ kLastMatchInfoPlayer.m_bMatchStarted;
	strRep @= "\n        Wins=" $ kLastMatchInfoPlayer.m_iWins;
	strRep @= "\n        Losses=" $ kLastMatchInfoPlayer.m_iLosses;
	strRep @= "\n        Disconnects=" $ kLastMatchInfoPlayer.m_iDisconnects;
	strRep @= "\n        SkillRating=" $ kLastMatchInfoPlayer.m_iSkillRating;
	strRep @= "\n        Rank=" $ kLastMatchInfoPlayer.m_iRank;

	return strRep;
}

//<workshop> Fixed Tutorial loading SCI 2015/10/26
//wAS:
//event OnDeleteSaveGameDataComplete(byte LocalUserNum)
event OnDeleteSaveGameDataComplete(bool bWasSuccessful, byte LocalUserNum, string SaveFileName)
//</workshop>
{
	local OnlineContentInterface ContentInterface;

	PendingSaveGameDataDeletes = false; //bsg-jneal (7.12.17): adding check if a save game delete is running to prevent a race condition where the delete might not complete until after the subsequent save had finished
	
	if (PendingDeleteSaveFilenames.length > 0)
	{
		ExecuteNextPendingSaveDelete();
	}
	else
	{
		ContentInterface = OnlineSub.ContentInterface;
		if (ContentInterface != none)
		{
			ContentInterface.ClearCachedSaveGames(LocalUserNum);
			UpdateSaveGameList();
		}
	}
}

private event DeleteSaveGameData(byte LocalUserNum, int DeviceId, string FileName)
{
	local OnlineContentInterface ContentInterface;

	ContentInterface = OnlineSub.ContentInterface;
	if( ContentInterface != none )
	{
		`log("Deleting Save File: " $ FileName,,'XCom_Online');
		//<workshop> OSS_CHANGES JPS 2015/10/22
		//
		//WAS:
		//ContentInterface.DeleteSaveGame(LocalUserNum, DeviceID, "", FileName);
		ContentInterface.DeleteSaveGameData(LocalUserNum, DeviceID, "", FileName);
		//</workshop>
	}
}

// bsg-dforrest (8.18.16): return true once history duplications for autosave are done
native function bool IsAutoSaveAsyncHistoryDuplicationComplete();
// bsg-dforrest (8.18.16): end

// bsg-dforrest (6.26.17): general check for is console save in progress in any way (duplication, or general save writing)
native function bool IsConsoleSaveInProgress();
// bsg-dforrest (6.26.17): end

// bsg-dforrest (6.27.17): photobooth close out before changing levels
event bool IsPhotoboothActive()
{
	local XComPresentationLayerBase Presentation;
	local bool bResult;
	bResult = false;

	Presentation = XComPlayerController(class'UIInteraction'.static.GetLocalPlayer(0).Actor).Pres;
	bResult =	Presentation.ScreenStack.HasInstanceOf(class'UITactical_Photobooth') ||
				Presentation.ScreenStack.HasInstanceOf(class'UIArmory_Photobooth'); // bsg-dforrest (6.30.17): add armory photobooth
	return bResult;
}
event ShutdownActivePhotobooth()
{
	local XComPresentationLayerBase Presentation;

	Presentation = XComPlayerController(class'UIInteraction'.static.GetLocalPlayer(0).Actor).Pres;
	if(	Presentation.ScreenStack.HasInstanceOf(class'UITactical_Photobooth') ||
		Presentation.ScreenStack.HasInstanceOf(class'UIArmory_Photobooth') ) // bsg-dforrest (6.30.17): add armory photobooth
	{
		Presentation.ShutdownActivePhotobooth();
	}
}

native function bool IsPhotoboothCapturing();
// bsg-dforrest (6.27.17): end

// bsg-dforrest (7.6.17): check if there are async sounds banks still loading, used to wait on sound sync before moving to the next turn
native function bool WaitForAudioRetryQueue();
// bsg-dforrest (7.6.17): end

// bsg-dforrest (7.10.17): Mark audio for dynamic reload. Should be called once per level transition. Note level transitions 
// can involve multiple load maps when dropship interior is used.
native function StartCleanupDynamicLoadBanks();
// bsg-dforrest (7.10.17): end

//Saving is simple, fire and forget
native function SaveGame(int SlotIndex, string SaveType, string AutosaveFilename = "", delegate<WriteSaveGameComplete> WriteSaveGameCompleteCallback = none, optional int PartialHistoryLength = -1, optional bool bAsyncHistoryDuplication = false);
//<workshop> LOADING_SAVE_HEADERS RJM 2016/03/31
//INS:
function SaveGameWithFilename(string Filename, bool IsAutosave, bool IsQuicksave, delegate<WriteSaveGameComplete> WriteSaveGameCompleteCallback = none, optional bool bAsyncHistoryDuplication = false)  // bsg-dforrest (8.18.16): request async history duplication
{
	WriteSaveGameComplete = WriteSaveGameCompleteCallback;

	if (bUpdateSaveListInProgress)
	{
		`log(`location @ "Save Failed: Cannot save while a save list update is in progress.");
		WriteSaveGameComplete(false);
		WriteSaveGameComplete = None;
		return;
	}

	if(class'WorldInfo'.static.GetWorldInfo().IsConsoleBuild())
	{
		if(!bHasLogin)
		{
			`log("Ignoring SaveGame() because there is no logged in user.",, 'XCom_Online');
			WriteSaveGameComplete(false);
			WriteSaveGameComplete = None;
			return;
		}
	}

	// bsg-dforrest (3.9.17): debug, premission, post mission flags broke this, added in defaults
	SaveGame(SaveNameToID(Filename), Filename, "", WriteSaveGameCompleteCallback, , bAsyncHistoryDuplication); // bsg-dforrest (8.18.16): request async history duplication //bsg-cballinger (1.25.17): Changed to Save and removed FinishSave, since FinishSave was only needed due to TWS changes
}

native function OnSaveCompleteInternal(bool bWasSuccessful, byte LocalUserNum, int DeviceId, string FriendlyName, string FileName, string SaveFileName); //The main purpose of this is to clear the save game serializing flag so that new saves can happen
native function SaveLadderGame( delegate<WriteSaveGameComplete> WriteSaveGameCompleteCallback = none );
 
// mmg_joshua.buckley (01/07/19) BEGIN - Removed to place the saving system back into the .cpp file
//<workshop> CONSOLE JPS 2015/11/17
//WAS:
//Loading is a 3 step process:
native function LoadGame(int SlotIndex, delegate<ReadSaveGameComplete> ReadSaveGameCompleteCallback = none);  //1. Initiate the (possibly async) read for a specific save from the player's storage. Calls OnReadSaveGameDataComplete when this is done.
////OnReadSaveGameDataComplete (delegate, above)	                                                              //2. Read the save data and initiate the map travel/load 
native function FinishLoadGame(); 	                                                                          //3. Load the save data ( instantiate saved actors ), this is done after the map loads.
//Loading is a 3 step process:
//1. Initiate the (possibly async) read for a specific save from the player's storage. Calls OnReadSaveGameDataComplete when this is done.
//2. Read the save data and initiate the map travel/load 
//3. Load the save data ( instantiate saved actors ), this is done after the map loads.
//function LoadGame(int SlotIndex, delegate<ReadSaveGameComplete> ReadSaveGameCompleteCallback = none) 
//{
//	local array<OnlineContent> ContentList;
//
//	ReadSaveGameComplete = ReadSaveGameCompleteCallback;
//
//	if (bUpdateSaveListInProgress)
//	{
//		`log("Load Failed: Cannot load while a save list update is in progress.",,'DevOnline');
//		ReadSaveGameComplete(false);
//		ReadSaveGameComplete = None;
//		return;
//	}
//
//	if (OnlineSub == None || OnlineSub.ContentInterface == None)
//	{
//		`log("Load Failed: Online subsystem is not availalbe.",,'DevOnline');
//		ReadSaveGameComplete(false);
//		ReadSaveGameComplete = None;
//		return;
//	}
//
//	OnlineSub.ContentInterface.GetContentList(LocalUserIndex, OCT_SaveGame, ContentList);
//	if (SlotIndex >= 0 && SlotIndex < ContentList.Length)
//	{
//		// bsg-dforrest (7.10.17): only clean up dynamic banks once per level transition
//		if(`ISCONSOLE)
//		{
//			`ONLINEEVENTMGR.StartCleanupDynamicLoadBanks();
//		}
//		// bsg-dforrest (7.10.17): end
//
//		LoadGameContentCacheIndex = SlotIndex;
//		ReadSaveGameData(LocalUserIndex, StorageDeviceIndex, ContentList[SlotIndex].FriendlyName, ContentList[SlotIndex].Filename, ContentList[SlotIndex].Filename);
//	}
//	else
//	{
//		`log("Invalid SavedID sent to UXComOnlineEventMgr::LoadGame",,'DevOnline');
//		ReadSaveGameComplete(false);
//		ReadSaveGameComplete = None;
//	}
//}
// mmg_joshua.buckley (01/07/19) END

private function OnReadSaveGameDataComplete(bool bWasSuccessful,byte LocalUserNum,int DeviceId,string FriendlyName,string FileName,string SaveFileName)
{
	local array<OnlineSaveGame> SaveGames;

	if (bWasSuccessful)
	{
		OnlineSub.ContentInterface.GetSaveGames(LocalUserIndex, SaveGames);
		if (LoadGameContentCacheIndex >= 0 && LoadGameContentCacheIndex < SaveGames.Length)
		{
			if (SaveGames[LoadGameContentCacheIndex].SaveGames.Length == 1)
			{
				FinishReadSaveGameDataComplete(LocalUserNum, SaveGames[LoadGameContentCacheIndex].SaveGames[0]);
			}
			else
			{
				`log(self @ "Invalid number of save games:" @ SaveGames[LoadGameContentCacheIndex].SaveGames.Length,,'DevOnline');
			}
		}
		else
		{
			`log(self @ "Invalid LoadGameContentCacheIndex value.",,'DevOnline');
		}
	}
	else
	{
		ReadSaveGameComplete(false);
	}

	ReadSaveGameComplete = None;
}

native function FinishReadSaveGameDataComplete(byte LocalUserNum, OnlineSaveGameDataMapping Mapping);

// mmg_joshua.buckley (01/07/19) BEGIN - Removed to place the saving system back into the .cpp file
//function FinishLoadGame() 
//{
//	local array<OnlineSaveGame> SaveGames;
//
//	if (OnlineSub == None || OnlineSub.ContentInterface == None)
//	{
//		`log("Failed to finish load game. Online subsystem is not available.",,'DevSave');
//		return;
//	}
//
//	//TODO
//	//for( INT i = 0; i < GWorld->Levels.Num(); ++i )
//	//{
//	//	ULevel& Level = *GWorld->Levels(i);
//	//
//	//	Level.RoutePostLoadGame();
//	//}
//
//	OnlineSub.ContentInterface.GetSaveGames(LocalUserIndex, SaveGames);
//	if (LoadGameContentCacheIndex >= 0 && LoadGameContentCacheIndex < SaveGames.Length)
//	{
//		`log("Finished loading" @ SaveGames[LoadGameContentCacheIndex].FriendlyName $"!",,'DevSave');
//		if (SaveGames[LoadGameContentCacheIndex].SaveGames.Length > 0)
//		{
//			SaveGames[LoadGameContentCacheIndex].SaveGames[0].SaveGameData.Length = 0;
//		}
//
//		ShowPostLoadMessages();
//	}
//	else
//	{
//		`log(self @ "Invalid value for LoadGameContentCacheIndex.",,'DevSave');
//	}
//
//	// bsg-mgabby-li (2016.8.29) : Restoring to pre-WS logic to fix double-start tutorial bug
//	bPerformingStandardLoad = false;
//	LoadGameContentCacheIndex = -1;
//	// bsg-mgabby-li (2016.8.29) : end
//}
//</workshop>
// mmg_joshua.buckley (01/07/19) END

// Implemented for tutorial mode, to load a save from a file not in your saves folder
native function LoadSaveFromFile(String SaveFile, delegate<ReadSaveGameComplete> ReadSaveGameCompleteCallback = none);

native function DeleteSaveGame(int SlotIndex);

function DeleteMultipleSameGames(array<string> SaveFilenames)
{
	PendingDeleteSaveFilenames = SaveFilenames;
	ExecuteNextPendingSaveDelete();
}

private function ExecuteNextPendingSaveDelete()
{
	local string SaveFilename;
	if (PendingDeleteSaveFilenames.length > 0)
	{
		PendingSaveGameDataDeletes = true;

		SaveFilename = PendingDeleteSaveFilenames[0];
		PendingDeleteSaveFilenames.Remove(0, 1);
		DeleteSaveGameWithFilename(SaveFilename);
	}
}

//<workshop> SAVE_OVERWRITE RJM 2016/04/14
//INS:
function DeleteSaveGameWithFilename(string SaveFileName)
{
	if (bUpdateSaveListInProgress)
	{
		`log("Delete Failed: Cannot delete a save while a save list update is in progress.",,'DevOnline');
		return;
	}

	if (Len(SaveFileName) == 0)
	{
		`log("Invalid SavedID sent to XComOnlineEventMgr.DeleteSaveGame",,'DevOnline');
		return;
	}

	DeleteSaveGameData(LocalUserIndex, StorageDeviceIndex, SaveFileName);
}
//</workshop>

// These save / load functions use in-memory checkpoints/saves
native function StartLoadFromStoredStrategy();  // Called from the tactical game when it finishes, starts the command1 map load / seamless travel
native function FinishLoadFromStoredStrategy(); // Called from the strategy game after the command1 map has finished loading, serializes in the saved strategy actors
native function SaveToStoredStrategy();         // Saves strategy actors to a binary blob for safe keeping
native function SaveTransport();
native function LoadTransport();
native function ReleaseCurrentTacticalCheckpoint(); // releases and nulls CurrentTacticalCheckpoint, 4.5+ megs of memory
//==================================================================================================================
//

native function int GetNextSaveID();
native function int SaveNameToID(string SaveFileName);
native function SaveIDToFileName(int SaveID, out string SaveFileName);
native function bool CheckSaveDLCRequirements(int SaveID, out string MissingDLC);
native function bool CheckSaveVersionRequirements(int SaveID);
native private function GetNewSaveFileName(out string SaveFileName, const out SaveGameHeader SaveHeader, bool bIsAutosave);

// Platform Specific Cert Functionality
//==================================================================================================================

/**
 * Calls the "Delete save data from a list" function for TRC R115
 * This brings up a list of save files and allows the user to pick
 * which files they wish to delete. ONLY AVAILABLE ON PS3! 
 */
native function DeleteSaveDataFromListPS3();

/**
 * On PS3 it is possible to transfer saves between profiles using
 * a USB stick to move the save off then back on the PS3. We need
 * to detect this circumstance and notify the user that they will
 * not be able to unlock trophies.
 * 
 * @return true if save data owned by another user has been loaded
 */
native function bool LoadedSaveDataFromAnotherUserPS3();

/**
 * Detect if a non-standard controller is in use. QA says that we
 * are suppose to prevent tha game from working with the Move controller
 * per TRC R026. This also checks for other non-standard controllers
 * like the Guitar controller or the DJ Deck controller.
 * 
 * @param ControllerIndex The index of the controller to check. Must be less than CELL_PAD_MAX_PORT_NUM.
 * @return true if the player is using a standard controller. false if the controller is non-standard OR not connected.
 */
native function bool StandardControllerInUsePS3(int ControllerIndex);

/**
 * Get the free space on the save device.
 * This is Xbox 360 only for now.
 * 
 * @return The free space on the save device in KB
 */
native function int GetSaveDeviceSpaceKB_Xbox360();

/**
 * Check to see if we have enough storage space for a new save game.
 * This is Xbox 360 only for now.
 * 
 * @return True if there is sufficient space to save. False otherwise.
 */
native function bool CheckFreeSpaceForSave_Xbox360();

/**
 * Use to determine if a gamepad is connected on PC
 * 
 * @return True if a gamepad is connected
 */
native static function bool GamepadConnected_PC();

/**
* Use to determine type of gamepad connected on PC
*
* @return -1 if a gamepad is not connected
* @return  0 if an xbox gamepad is connected
* @return  1 if a playstation gamepad is connected
*/
native static function int GamepadConnectedType_PC();

/**
 * Detect gamepads that have been connected since the game started.
 */
native static function EnumGamepads_PC();

// Update Save List Started Delegates
//==================================================================================================================
function AddUpdateSaveListStartedDelegate( delegate<UpdateSaveListStarted> Callback )
{
	`log(self $ "::" $ GetFuncName() @ `ShowVar(Callback), true, 'XCom_Online');
	if (m_UpdateSaveListStartedDelegates.Find(Callback) == INDEX_None)
	{
		m_UpdateSaveListStartedDelegates[m_UpdateSaveListStartedDelegates.Length] = Callback;
	}
}

function ClearUpdateSaveListStartedDelegate( delegate<UpdateSaveListStarted> Callback )
{
	local int i;

	`log(self $ "::" $ GetFuncName() @ `ShowVar(Callback), true, 'XCom_Online');
	i = m_UpdateSaveListStartedDelegates.Find(Callback);
	if (i != INDEX_None)
	{
		m_UpdateSaveListStartedDelegates.Remove(i, 1);
	}
}

private function CallUpdateSaveListStartedDelegates()
{
	local delegate<UpdateSaveListStarted> Callback;

	foreach m_UpdateSaveListStartedDelegates(Callback)
	{
		Callback();
	}
}

// Update Save List Complete Delegates
//==================================================================================================================
function AddUpdateSaveListCompleteDelegate( delegate<UpdateSaveListComplete> Callback )
{
	`log(self $ "::" $ GetFuncName() @ `ShowVar(Callback), true, 'XCom_Online');
	if (m_UpdateSaveListCompleteDelegates.Find(Callback) == INDEX_None)
	{
		m_UpdateSaveListCompleteDelegates[m_UpdateSaveListCompleteDelegates.Length] = Callback;
	}
}

function ClearUpdateSaveListCompleteDelegate( delegate<UpdateSaveListComplete> Callback )
{
	local int i;

	`log(self $ "::" $ GetFuncName() @ `ShowVar(Callback), true, 'XCom_Online');
	i = m_UpdateSaveListCompleteDelegates.Find(Callback);
	if (i != INDEX_None)
	{
		m_UpdateSaveListCompleteDelegates.Remove(i, 1);
	}
}

private function CallUpdateSaveListCompleteDelegates(bool bWasSuccessful)
{
	local delegate<UpdateSaveListComplete> Callback;

	foreach m_UpdateSaveListCompleteDelegates(Callback)
	{
		Callback(bWasSuccessful);
	}
}

// Login Status Changed Delegates
//==================================================================================================================
// While it may seem odd to route this event through the OnlineEventMgr it removes the complexity of having to worry
// about tracking the active user in systems other than the OnlineEventMgr. This helps for edge cases such as an
// inactive profile accepting an invite and therefore becoming the active controller.
//<workshop> CONSOLE JPS 2015/11/20
//WAS:
//function AddLoginStatusChangeDelegate( delegate<OnlinePlayerInterface.OnLoginStatusChange> Callback )
function AddLoginStatusChangeDelegate( delegate<OnLoginStatusChange> Callback )
//</workshop>
{
	`log(self $ "::" $ GetFuncName() @ `ShowVar(Callback), true, 'XCom_Online');
	if (m_LoginStatusChangeDelegates.Find(Callback) == INDEX_None)
	{
		m_LoginStatusChangeDelegates[m_LoginStatusChangeDelegates.Length] = Callback;
	}
}

//<workshop> CONSOLE JPS 2015/11/20
//WAS:
//function ClearLoginStatusChangeDelegate( delegate<OnlinePlayerInterface.OnLoginStatusChange> Callback )
function ClearLoginStatusChangeDelegate( delegate<OnLoginStatusChange> Callback )
//</workshop>
{
	local int i;

	`log(self $ "::" $ GetFuncName() @ `ShowVar(Callback), true, 'XCom_Online');
	i = m_LoginStatusChangeDelegates.Find(Callback);
	if (i != INDEX_None)
	{
		m_LoginStatusChangeDelegates.Remove(i, 1);
	}
}

private function CallLoginStatusChangeDelegates(ELoginStatus NewStatus, UniqueNetId NewId)
{
	//<workshop> CONSOLE JPS 2015/11/20
	//WAS:
	//local delegate<OnlinePlayerInterface.OnLoginStatusChange> Callback;
	local delegate<OnLoginStatusChange> Callback;
	//</workshop>
	
	foreach m_LoginStatusChangeDelegates(Callback)
	{
		Callback(NewStatus, NewId);
	}
}

// Save Device Lost Delegates
//==================================================================================================================
function AddSaveDeviceLostDelegate( delegate<OnSaveDeviceLost> Callback )
{
	`log(self $ "::" $ GetFuncName() @ `ShowVar(Callback), true, 'XCom_Online');
	if (m_SaveDeviceLostDelegates.Find(Callback) == INDEX_None)
	{
		m_SaveDeviceLostDelegates[m_SaveDeviceLostDelegates.Length] = Callback;
	}
}

function ClearSaveDeviceLostDelegate( delegate<OnSaveDeviceLost> Callback )
{
	local int i;

	`log(self $ "::" $ GetFuncName() @ `ShowVar(Callback), true, 'XCom_Online');
	i = m_SaveDeviceLostDelegates.Find(Callback);
	if (i != INDEX_None)
	{
		m_SaveDeviceLostDelegates.Remove(i, 1);
	}
}

private function CallSaveDeviceLostDelegates()
{
	local delegate<OnSaveDeviceLost> Callback;

	foreach m_SaveDeviceLostDelegates(Callback)
	{
		Callback();
	}
}

//bsg-jneal (7.17.16): Play Together hack for ORBIS, delegate handling, can expand implementation to account for using Play Together from elsewhere in the title
// Play Together Started
//==================================================================================================================
//
function AddPlayTogetherStartedDelegate( delegate<OnPlayTogetherStarted> Callback )
{
	`log(`location @ `ShowVar(Callback), true, 'XCom_Online');
	if (m_PlayTogetherStartedDelegates.Find(Callback) == INDEX_None)
	{
		m_PlayTogetherStartedDelegates[m_PlayTogetherStartedDelegates.Length] = Callback;
	}
}

function ClearPlayTogetherStartedDelegate( delegate<OnPlayTogetherStarted> Callback )
{
	local int i;

	`log(`location @ `ShowVar(Callback), true, 'XCom_Online');
	i = m_PlayTogetherStartedDelegates.Find(Callback);
	if (i != INDEX_None)
	{
		m_PlayTogetherStartedDelegates.Remove(i, 1);
	}
}

event CallPlayTogetherStartedDelegates()
{
// bsg-fchen (7/25/16): Updating supports for play together
	local XComPresentationLayerBase Presentation;
	local XComPlayerController xPlayerController;

	//bsg-jrucker (8/29/16): Fix to stop allowing the player to start a playtogether session before the game is installed.
	if (!OnlineSub.IsGameDownloaded())
	{
		InviteFailed(SystemMessage_GameStillInstalling);
		mbCurrentlyHandlingInvite = false;
		return;
	}
	//bsg-jrucker (8/29/16): End.

	xPlayerController = XComPlayerController(class'UIInteraction'.static.GetLocalPlayer(0).Actor);
	if (xPlayerController != none)
	{
		SetShuttleToMPInviteLoadout(false);
		Presentation = xPlayerController.Pres;
		if (Presentation != none && !GetShuttleToMPPlayTogetherLoadout()) //bsg-jneal (9.2.16): prevent multiple play together save dialogs if one is already displaying
		{
			// Trigger Play Together workflow
			//bsg-fchen (8/19/16): PlayTogether save screen check
			SetShuttleToMPPlayTogetherLoadout(true); 
			//bsg-fchen (8/22/16): Update Play Together to handle single player cases
			Presentation.DisplayMultiplayerSaveDialog(); //bsg-jneal (6.15.17): added confirmation prompts for normal invites when in single player or challenge mode
		}
	}
// bsg-fchen (7/25/16): End
}

//bsg-cballinger (8.28.16): BEGIN, check to see if we're on a screen the player can safely accept an invite on.
event bool IsOnValidScreenForInvite()
{
	local XComPresentationLayerBase Presentation;
	local XComPlayerController xPlayerController;

	xPlayerController = XComPlayerController(class'UIInteraction'.static.GetLocalPlayer(0).Actor);
	if (xPlayerController != none)
	{
		Presentation = xPlayerController.Pres;
		if (Presentation != none)
		{
			return Presentation.ValidScreenForInvite();
		}
	}
	return true;
}
//bsg-cballinger (8.28.16): END

//bsg-fchen (8/24/16): Adding a check and properly handling existing sessions before going into another session
function bool HandleExistingSessionGoingIntoAnotherSession()
{
	local OnlineSubsystem kOSS;
	local XComGameStateNetworkManager NetworkMgr;
	local OnlineGameInterface kGameInterface;
	local OnlineGameSettings kGameSettings;

	kGameInterface = `ONLINEEVENTMGR.OnlineSub.GameInterface;
	if (kGameInterface.GetGameSettings('Lobby') == None && kGameInterface.GetGameSettings('Game') == None)
	{
		return false;
	}

	if (kGameSettings == none)
	{
		kGameSettings = OnlineSub.GameInterface.GetGameSettings('Lobby');
	}

	if (`ONLINEEVENTMGR.GetShuttleToMPPlayTogetherLoadout())
	{
		//bsg-fchen (6.24.17): Clear any invite when you are starting a different session
		ClearAcceptedInvites();
	}

	kOSS = class'GameEngine'.static.GetOnlineSubsystem();
	kOSS.GameInterface.AddDestroyOnlineGameCompleteDelegate(OnDestroyedOnlineGame);
	//bsg-fchen (6.15.17): End the current multiplayer session before going into a different session
	kGameInterface.EndMultiplayer(`ONLINEEVENTMGR.LocalUserIndex);
	kGameInterface.DestroyOnlineGame(`ONLINEEVENTMGR.LocalUserIndex, kGameSettings.SessionTemplateName ~= "Lobby" ? 'Lobby' : 'Game');

	NetworkMgr = `XCOMNETMANAGER;
	NetworkMgr.Disconnect();
	return true;
}
//bsg-fchen (8/24/16): End

// Network Connection Problems
//==================================================================================================================
//
function AddNotifyConnectionProblemDelegate( delegate<OnConnectionProblem> Callback )
{
	`log(`location @ `ShowVar(Callback), true, 'XCom_Online');
	if (m_ConnectionProblemDelegates.Find(Callback) == INDEX_None)
	{
		m_ConnectionProblemDelegates[m_ConnectionProblemDelegates.Length] = Callback;
	}
}

function ClearNotifyConnectionProblemDelegate( delegate<OnConnectionProblem> Callback )
{
	local int i;

	`log(`location @ `ShowVar(Callback), true, 'XCom_Online');
	i = m_ConnectionProblemDelegates.Find(Callback);
	if (i != INDEX_None)
	{
		m_ConnectionProblemDelegates.Remove(i, 1);
	}
}

function NotifyConnectionProblem()
{
	local delegate<OnConnectionProblem> Callback;
	foreach m_ConnectionProblemDelegates(Callback)
	{
		Callback();
	}
}

// Invite System
//==================================================================================================================
//
function SwitchUsersThenTriggerAcceptedInvite()
{
	`log(`location @ `ShowVar(LocalUserIndex) @ `ShowVar(InviteUserIndex),,'XCom_Online');
	if (InviteUserIndex != LocalUserIndex)
	{
		AddBeginShellLoginDelegate(OnShellLoginComplete_SwitchUsers);
		BeginShellLogin(InviteUserIndex);
	}
	else
	{
		`log(`location @ "No need to switch users!",,'XCom_Online');
	}
}

function OnShellLoginComplete_SwitchUsers(bool bWasSuccessful)
{
	`log(`location,,'XCom_Online');
	ClearBeginShellLoginDelegate(OnShellLoginComplete_SwitchUsers);
	if (bWasSuccessful)
	{
		TriggerAcceptedInvite();
	}
}

/**
 *  OnGameInviteAccepted - Callback from the OnlineSubsystem whenever a player accepts an invite.  This will store
 *    the invite data, since it is not stored elsewhere, and will allow the game to process invites through load
 *    screens or whenever the PlayerController will be destroyed.
 *    
 *    NOTE: This will be called multiple times with the same InviteResult, due to the way the invite callbacks are
 *    registered on all controllers.
 */
//<workshop> TRC_R4109 JAS 2016/05/18
//WAS:
//function OnGameInviteAccepted(const out OnlineGameSearchResult InviteResult, bool bWasSuccessful)
//INS:
function OnGameInviteAccepted(const out OnlineGameSearchResult InviteResult, bool bWasSuccessful, EOnlineServerConnectionStatus Status) //bsg-jrucker (7/19/16): Updated to correct error code enum.
//</workshop>
{
	//bsg-jrucker (8/16/16): We can only handle one invite at a time, so if we're handling one right now, exit out of here and just ignore this call.
	if( mbCurrentlyHandlingInvite )
	{
		return;
	}
	mbCurrentlyHandlingInvite = true;
	//bsg-jrucker (8/16/16): End.

	//bsg-jrucker (8/16/16): Cache off the vars passed in for use later.
	mInviteResult = InviteResult;
	mbInviteWasSuccessful = bWasSuccessful;
	mInviteStatus = Status;
	//bsg-jrucker (8/16/16): End.

	`log(`location @ `ShowVar(InviteResult.GameSettings) @ `ShowVar(m_tAcceptedGameInviteResults.Length) @ `ShowEnum(ELoginStatus, OnlineSub.PlayerInterface.GetLoginStatus(LocalUserIndex), LoginStatus), true, 'XCom_Online');

	//bsg-fchen (8/24/16): Adding a check and properly handling existing sessions before going into another session
	if (!HandleExistingSessionGoingIntoAnotherSession())
	{
		HandleGameInviteAccepted();
	}
	//bsg-fchen (8/24/16): End
}

//bsg-jrucker (8/16/16): Callback for post destroying existing MP session for Lobby on an invite.
simulated function OnDestroyedOnlineGame(name SessionName,bool bWasSuccessful)
{
	local OnlineSubsystem kOSS;

	kOSS = class'GameEngine'.static.GetOnlineSubsystem();

	kOSS.GameInterface.ClearDestroyOnlineGameCompleteDelegate(OnDestroyedOnlineGame);
	HandleGameInviteAccepted();
}
//bsg-jrucker (8/16/16): End.

// bsg-nlong & fchen (9.29.16): 7718 & 7808: Functions that produce localized string lists of missing DLC names, currentDLC names
function string GetSessionDLCList()
{
	local int SessionDLCMask;
	local string DLCList;
	local int DLC_Index;
	local string currentDLC;
	local int currentDLCMask;

	DLCList = "";
	// DLC0 1
	// DLC1 2
	// DCL2 4
	// DLC3 8
	SessionDLCMask = class'GameEngine'.static.GetOnlineSubsystem().CurrentSessionDLCMask;
	if( SessionDLCMask == 0 )
	{
		return "";
	}

	for(DLC_Index = 0; DLC_Index < 5; ++DLC_Index)
	{
		currentDLCMask = (1 << DLC_Index);
		if( (SessionDLCMask & currentDLCMask) == currentDLCMask )
		{
			if( DLC_Index == 0 )
			{
				currentDLC = m_sDLC0Name;
			}

			if( DLC_Index == 1 )
			{
				currentDLC = m_sDLC1Name;
			}

			if( DLC_Index == 2 )
			{
				currentDLC = m_sDLC2Name;
			}

			if( DLC_Index == 3 )
			{
				currentDLC = m_sDLC3Name;
			}

			//bsg-cballinger (3.20.17): BEGIN, added Ozzy DLC name
			if( DLC_Index == 4 )
			{
				currentDLC = m_sDLC4Name;
			}
			//bsg-cballinger (3.20.17): END

			AppendMissingDLCList(DLCList, currentDLC);
		}
	}

	return DLCList;
}

function string GetDLCList()
{
	local array<X2DownloadableContentInfo> AllDLCInfos;
	local name DLCId;
	local string DLCList;
	local int k;

	DLCList = "";
	AllDLCInfos = GetDLCInfos(false);
	
	for(k = 0; k < AllDLCInfos.Length; ++k)
	{
		DLCId = name(AllDLCInfos[k].DLCIdentifier);

		if (DLCList != "")
		{
			DLCList = DLCList $ ", ";
		}

		if(DLCId == 'XCom_DLC_Day0') 
		{
			DLCList = DLCList $ m_sDLC0Name;
		}
		else if(DLCId == 'DLC_1')
		{
			DLCList = DLCList $ m_sDLC1Name;
		}
		else if(DLCId == 'DLC_2')
		{
			DLCList = DLCList $ m_sDLC2Name;
		}
		else if(DLCId == 'DLC_3')
		{
			DLCList = DLCList $ m_sDLC3Name;
		}
		//bsg-cballinger (3.20.17): BEGIN, added Ozzy DLC name
		else if(DLCId == name(DLC_4_Name))
		{
			DLCList = DLCList $ m_sDLC4Name;
		}
		//bsg-cballinger (3.20.17): END
	}

	return DLCList;
}

//bsg-jrebar (6/23/17): Read DLC list from passed in DLC mask
function string GetDLCListFromMask(const int DLCMask)
{
	local string DLCList;
	local int DLC_Index;
	local string currentDLC;
	local int currentDLCMask;

	DLCList = "";
	// DLC0 1
	// DLC1 2
	// DCL2 4
	// DLC3 8
	// DLC4 16
	if( DLCMask == 0 )
	{
		return "";
	}

	for(DLC_Index = 0; DLC_Index < 5; ++DLC_Index)
	{
		currentDLCMask = (1 << DLC_Index);
		if( (DLCMask & currentDLCMask) == currentDLCMask )
		{
			if( DLC_Index == 0 )
			{
				currentDLC = m_sDLC0Name;
			}
			else if( DLC_Index == 1 )
			{
				currentDLC = m_sDLC1Name;
			}
			else if( DLC_Index == 2 )
			{
				currentDLC = m_sDLC2Name;
			}
			else if( DLC_Index == 3 )
			{
				currentDLC = m_sDLC3Name;
			}
			//bsg-cballinger (3.20.17): BEGIN, added Ozzy DLC name
			else if( DLC_Index == 4 )
			{
				currentDLC = m_sDLC4Name;
			}
			//bsg-cballinger (3.20.17): END

			AppendMissingDLCList(DLCList, currentDLC);
			currentDLC = "";
		}
	}

	return DLCList;
}
//bsg-jrebar (6/23/17): end

function string GetMissingDLCList(optional array<int> preSpecifiedMissingDLC)
{
	local array<X2DownloadableContentInfo> AllDLCInfos;
	local name DLCId;
	local string sMissingDLC;
	local int k;
	local bool bHasDLC0;
	local bool bHasDLC1;
	local bool bHasDLC2;
	local bool bHasDLC3;
	local bool bHasDLC4;

	sMissingDLC = "";
	
	if( preSpecifiedMissingDLC.length <= 0 )
	{
		AllDLCInfos = GetDLCInfos(false);
		bHasDLC0 = false;
		bHasDLC1 = false;
		bHasDLC2 = false;
		bHasDLC3 = false;
		bHasDLC4 = false;

		for(k = 0; k < AllDLCInfos.Length; ++k)
		{
			DLCId = name(AllDLCInfos[k].DLCIdentifier);

			if(DLCId == 'XCom_DLC_Day0') 
			{
				bHasDLC0 = true;
			}
			else if(DLCId == 'DLC_1')
			{
				bHasDLC1 = true;
			}
			else if(DLCId == 'DLC_2')
			{
				bHasDLC2 = true;
			}
			else if(DLCId == 'DLC_3')
			{
				bHasDLC3 = true;
			}
			//bsg-cballinger (3.20.17): BEGIN, added Ozzy DLC name
			else if(DLCId == name(DLC_4_Name))
			{
				bHasDLC4 = true;
			}
			//bsg-cballinger (3.20.17): END
		}
	}
	else
	{
		bHasDLC0 = true;
		bHasDLC1 = true;
		bHasDLC2 = true;
		bHasDLC3 = true;
		bHasDLC4 = true;

		for(k = 0; k < preSpecifiedMissingDLC.length; ++k)
		{
			if( preSpecifiedMissingDLC[k] == 0 ) { bHasDLC0 = false; }
			if( preSpecifiedMissingDLC[k] == 1 ) { bHasDLC1 = false; }
			if( preSpecifiedMissingDLC[k] == 2 ) { bHasDLC2 = false; }
			if( preSpecifiedMissingDLC[k] == 3 ) { bHasDLC3 = false; }
			if( preSpecifiedMissingDLC[k] == 4 ) { bHasDLC4 = false; } //bsg-cballinger (3.20.17): added Ozzy DLC name
		}
	}

	if (!bHasDLC0)
	{
		AppendMissingDLCList(sMissingDLC, m_sDLC0Name);		
	}
	if (!bHasDLC1)
	{
		AppendMissingDLCList(sMissingDLC, m_sDLC1Name);		
	}
	if (!bHasDLC2)
	{
		AppendMissingDLCList(sMissingDLC, m_sDLC2Name);		
	}
	if (!bHasDLC3)
	{
		AppendMissingDLCList(sMissingDLC, m_sDLC3Name);		
	}
	//bsg-cballinger (3.20.17): BEGIN, added Ozzy DLC name
	if (!bHasDLC4)
	{
		AppendMissingDLCList(sMissingDLC, m_sDLC4Name);		
	}
	//bsg-cballinger (3.20.17): END
	
	return sMissingDLC;
}

function AppendMissingDLCList(out string sMissingDLC, string sDLCName)
{
	if (sMissingDLC != "")
	{
		sMissingDLC = sMissingDLC $ ", ";
	}
	sMissingDLC = sMissingDLC $ sDLCName;
}
// bsg-nlong & fchen (9.29.16): 7718 & 7808: end

//bsg-jrucker (8/16/16): Handle the cached invite values.
function HandleGameInviteAccepted()
{
	local OnlineGameSearchResult InviteResult;
	local bool bWasSuccessful;
	local EOnlineServerConnectionStatus Status;
	local XComPlayerController xPlayerController;
	local XComPresentationLayerBase Presentation;
	local UIScreenStack ScreenStack;
	local bool bIsMoviePlaying;
	local Actor TimerActor; //bsg-jneal (7.22.17): potential fix for boot invites on both platforms, continue attempting the boot invite until we get profile settings

	xPlayerController = XComPlayerController(class'UIInteraction'.static.GetLocalPlayer(0).Actor); // GetLocalPlayer takes player index not controller index. Do not user LocalUserIndex.
	
	//Make local copies so we can clear out the cached values for garbage collection.
	InviteResult = mInviteResult;

	bTutorial = false; //bsg-jneal (7.26.17): when accepting a game invite make sure to toggle us off the tutorial, this prevents an issue with the Y/TRIANGLE button not functioning when a MP invite fails when accepted during the initial New Game movie for Ozzy

	//bsg-fchen (6.24.17): The current cached invite has been handled already, do not try to re-handle it
	if (!mbCurrentlyHandlingInvite)
	{
		return ;
	}

	bWasSuccessful = mbInviteWasSuccessful;
	Status = mInviteStatus;

	//bsg-jrucker (8/16/16): Moved here from OnGameInviteAccepted.
	if (!bWasSuccessful)
	{
		if (OnlineSub.PlayerInterface.GetLoginStatus(LocalUserIndex) != LS_LoggedIn)
		{
			if (class'WorldInfo'.static.IsConsoleBuild(CONSOLE_PS3))
			{
				OnlineSub.PlayerInterface.AddLoginUICompleteDelegate(OnLoginUIComplete);
				//<workshop> LocalUserIndex
				//WAS:
				//OnlineSub.PlayerInterface.ShowLoginUI(true); // Show Online Only
				OnlineSub.PlayerInterface.ShowLoginUI(LocalUserIndex, true); // Show Online Only
				//</worksohp>

			}
			else
			{
				InviteFailed(SystemMessage_LostConnection);
			}
		}
		else
		{
			//<workshop> TRC_R4109 JAS 2016/05/18
			//WAS:
			//InviteFailed(SystemMessage_BootInviteFailed);
			//INS:
			Switch(Status)
			{
				//bsg-fchen (8/9/16): Added DLC check to invited games
				case OSCS_MismatchContent:
					InviteFailed(SystemMessage_MismatchContent);
					break;
				//bsg-fchen (8/9/16): End
				//bsg-jrucker (4/7/17): Adding ozzy content missmatch fail state
				case OSCS_OzzyContentMismatch:
					InviteFailed(SystemMessage_OzzyMismatchContent);
					break;
				//bsg-jrucker (4/7/17): End.
				//bsg-jrucker (7/19/16): Fixing these error calls.  The error ID's didn't match.
				case OSCS_TooYoung:
					InviteFailed(SystemMessage_TooYoung);
					break;
				case OSCS_UnavailablePrivilege:
					InviteFailed(SystemMessage_UnavailablePrivilige);
					break;
				//INVITE_FLOW_CHANGES RJM 2016/06/18
				case OSCS_InvalidUser:
					InviteFailed(SystemMessage_InvalidUser);
					break;
				//<BSG> TTP_5089_5073_ADDED_PATCH_REQ_AND_AGE_RESTRICTION_MSGS JHilton 06.21.2016
				//INS:
				case OSCS_UpdateRequired:
					InviteFailed(SystemMessage_UpdateRequired);
					break;
				//</BSG>
				case OSCS_PrivateSession:
					InviteFailed(SystemMessage_GameUnavailable);
					break;
				case OSCS_SessionFull:
					InviteFailed(SystemMessage_GameFull);
					break;
				//bsg-jrucker (8/5/16): Case for failure to connect to host
				case OSCS_NotConnected:
					InviteFailed(SystemMessage_BootInviteFailed);
					break;
				//bsg-jrucker (8/5/16): End.
				//</workshop>
				//bsg-fchen (9/7/16): Added UGC check to invited games
				case OSCS_UGCRestricted:
					ErrorMessageMgr.EnqueueError(SystemMessage_UGCRestricted);
					break;
				//bsg-fchen (9/7/16): End
				//bsg-fchen (7.15.17): Game has not finish installing, only has initial chunk
				case OSCS_GameNotDownloaded:
					InviteFailed(SystemMessage_GameStillInstalling);
					break;
				//bsg-fchen (7.15.17): End
				default:
					//bsg-cballinger(7.16.16): BEGIN, Added check for InvitePermissions failure so correct message can be displayed to the user
					if(xPlayerController == none || xPlayerController.CanAllPlayersPlayOnline())
						InviteFailed(SystemMessage_BootInviteFailed);
					else
						InviteFailed(SystemMessage_InvitePermissionsFailed);
					//bsg-cballinger(7.16.16): END
					break;
				//bsg-jrucker (7/19/16): End.
			}
			//</workshop>
		}
		mbCurrentlyHandlingInvite = false;
		return;
	}

	if (InviteResult.GameSettings == none)
	{
		// XCOM_EW: BUG 5321: [PCR] [360Only] Client receives the incorrect message 'Game Full' and 'you haven't selected a storage device' when accepting a game invite which has been dismissed.
		// BUG 20260: [ONLINE] - Users will soft crash when accepting an invite to a full lobby.
		InviteFailed(SystemMessage_InviteSystemError, !IsCurrentlyTriggeringBootInvite()); // Travel to the MP Menu only if the invite was made while in-game.
		mbCurrentlyHandlingInvite = false;
		return;
	}

	if ( ! InviteResult.GameSettings.bAllowInvites )
	{
		// BUG 20611: MP - Host can invite the Client into a ranked match through Steam.
		InviteFailed(SystemMessage_InviteRankedError, true);
		mbCurrentlyHandlingInvite = false;
		return;
	}

	if (CheckInviteGameVersionMismatch(XComOnlineGameSettings(InviteResult.GameSettings)))
	{
		InviteFailed(SystemMessage_VersionMismatch, true);
		mbCurrentlyHandlingInvite = false;
		return;
	}

	// <workshop> WKB 5-10-2016 DISABLE_MULTIPLAYER_INVITES_WHILE_INSTALLING
	// INS:
	if (!OnlineSub.IsGameDownloaded())
	{
		InviteFailed(SystemMessage_GameStillInstalling);
		mbCurrentlyHandlingInvite = false;
		return;
	}
	// </workshop> 

	//bsg-jneal (7.22.17): potential fix for boot invites on both platforms, continue attempting the boot invite until we get profile settings
	// If on the boot-train, ignore the rest of the checks and reprocess once at the next valid time.
	if (bWasSuccessful && !bHasProfileSettings)
	{
		`log(`location @ " -----> Shutting down the playing movie and returning to the MP Main Menu, then accepting the invite again.");
		//mbCurrentlyHandlingInvite = false; // do not set this to false as it will interrupt the way the invite flow is now working

		TimerActor = class'WorldInfo'.static.GetWorldInfo().Spawn(class'DynamicPointInSpace');	
		TimerActor.SetTimer(1, false, nameof(HandleGameInviteAccepted), self);
		return;
	}
	//bsg-jneal (7.22.17): end

	//<workshop> GAME_INVITE_PROFILE_CONFIRM JTA 2016/5/4
	//INS:
	if(`ISDURANGO)
	{
		bGameInviteProfileNeedsConfirmation = true;
	}
	//</workshop>

	// Mark that we accepted an invite. and active game is now marked failed
	SetShuttleToMPInviteLoadout();
	bAcceptedInviteDuringGameplay = true;
	m_tAcceptedGameInviteResults[m_tAcceptedGameInviteResults.Length] = InviteResult;
	ScreenStack = xPlayerController.Pres.ScreenStack;
	
	//bsg-cballinger (7.16.16): BEGIN, If the user accepts an invite on the start menu, take them directly to the MP menu to accept the invite and join the lobby.
	if(bWasSuccessful && xPlayerController !=none && ScreenStack != none)
	{
		//bsg-cballinger (7.28.16): we should only do this if we're on the "Press Start" screen. Prevent this from happening when the player enters the Character Pool from the start screen as well, otherwise joining the lobby will fail. Use HasInstanceOf, in case a dialog box is opened (e.g. warning/error) while on the character pool menu.
		if(!ScreenStack.HasInstanceOf(class'UIShell') && !ScreenStack.HasInstanceOf(class'UIFinalShell') && ScreenStack.HasInstanceOf(class'UIStartScreen'))
		{
			//If there are any system messages blocking the start screen, dismiss them so we can proceed to load the multiplayer menu.
			ScreenStack.PopUntilClass(class'UIStartScreen');

			UIStartScreen(ScreenStack.GetCurrentScreen()).BeginLogin(0); //MUST call BeginLogin here, otherwise bHasProfileSettings (checked below) is false, and StartMPShellState will fail to shuttle the player
			SetShuttleToMPInviteLoadout(false);
			xPlayerController.Pres.StartMPShellState();
			mbCurrentlyHandlingInvite = false;
			return;
		}
	}
	//bsg-cballinger (7.16.16): END

	bIsMoviePlaying = `XENGINE.IsAnyMoviePlaying();
	if (bIsMoviePlaying || IsPlayerReadyForInviteTrigger() )
	{
		//bsg-cballinger (7.16.16): BEGIN, If the user accepts an invite on the loading screen, then postpone processing the invite until after the loading screen finishes
		if(`XENGINE.IsLoadingMoviePlaying())
		{
			ControllerNotReadyForInvite();
		}
		//bsg-cballinger (7.16.16): END
		else if (bIsMoviePlaying)
		{
			// By-pass movie and continue accepting the invite.
			`XENGINE.StopCurrentMovie();
		}

		//bsg-jneal (6.15.17): added confirmation prompts for normal invites when in single player or challenge mode
		if(`HQPRES != none || `TACTICALGRI != none)
		{
			Presentation = xPlayerController.Pres;
			Presentation.DisplayMultiplayerSaveDialog();
		}
		else if (xPlayerController != none)
		{
			//<workshop> RESET_INVITE RJM 2016/05/10
			// Reset this flag as we are starting the MP shell state directly.
			//INS:
			SetShuttleToMPInviteLoadout(false);
			//</workshop>
			Presentation = xPlayerController.Pres;
			Presentation.StartMPShellState();
		}
		else
		{
			`RedScreen("Failing to transition to the MP Shell after accepting an invite. @ttalley");
		}
		//bsg-jneal (6.15.17): end
	}
	else
	{
		`log(`location @ "Waiting for whatever to finish and transition back to the MP Shell before entering the Loadout screen.");
	}
	//bsg-jrucker (8/16/16): End.
	
	mbCurrentlyHandlingInvite = false;
}
//bsg-jrucker (8/16/16): End.

function bool CheckInviteGameVersionMismatch(XComOnlineGameSettings InviteGameSettings)
{
	local string ByteCodeHash;
	local int InstalledDLCHash;
	local int InstalledModsHash;
	local string INIHash;

//<workshop> GAME_INVITE_MISMATCH_CONSOLE jmarshall 3-28-2016
//INS:
// This functionality isn't needed for the consoles, but TODO we need to add support for checking DLC's here.
	if(`ISCONSOLE)
	{
		return false;
	}
//</workshop>

	ByteCodeHash = class'Helpers'.static.NetGetVerifyPackageHashes();
	InstalledDLCHash = class'Helpers'.static.NetGetInstalledMPFriendlyDLCHash();
	InstalledModsHash = class'Helpers'.static.NetGetInstalledModsHash();
	INIHash = class'Helpers'.static.NetGetMPINIHash();

	if (ByteCodeHash == "") ByteCodeHash = "EMPTY";
	if (INIHash == "") INIHash = "EMPTY";

	`log(`location @ "InviteGameSettings=" $ InviteGameSettings.ToString(),, 'XCom_Online');
	`log(`location @ `ShowVar(InviteGameSettings.GetByteCodeHash()) @ `ShowVar(InviteGameSettings.GetInstalledDLCHash()) @ `ShowVar(InviteGameSettings.GetInstalledModsHash()) @ `ShowVar(InviteGameSettings.GetINIHash()), , 'XCom_Online');
	`log(`location @ `ShowVar(ByteCodeHash) @ `ShowVar(InstalledDLCHash) @ `ShowVar(InstalledModsHash) @ `ShowVar(INIHash),, 'XCom_Online');
	return  ByteCodeHash != InviteGameSettings.GetByteCodeHash() ||
			InstalledDLCHash != InviteGameSettings.GetInstalledDLCHash() ||
			InstalledModsHash != InviteGameSettings.GetInstalledModsHash() ||
			INIHash != InviteGameSettings.GetINIHash();
}

function bool IsPlayerInLobby()
{
	`log(self $ "::" $ GetFuncName() @ "IsInLobby=" $ XComPlayerController(class'UIInteraction'.static.GetLocalPlayer(0).Actor).IsInLobby(), true, 'XCom_Online');
	return XComPlayerController(class'UIInteraction'.static.GetLocalPlayer(0).Actor).IsInLobby();
}

// System Messaging
//==================================================================================================================
//

//BSG_REMOVED: moved to ErrorMgr
/*
//<workshop> TTP_2999 ALLOWING_THE_REMOVAL_OF_EITHER_BUTTONS_IF_NOT_NECESSARY kmartinez 2016-06-07
//WAS:
//function DisplaySystemMessage(string sSystemMessage, string sSystemTitle, optional delegate<DisplaySystemMessageComplete> dOnDisplaySystemMessageComplete=OnDisplaySystemMessageComplete)
function DisplaySystemMessage(string sSystemMessage, string sSystemTitle, optional delegate<DisplaySystemMessageComplete> dOnDisplaySystemMessageComplete=OnDisplaySystemMessageComplete, optional bool bShowAcceptButton = true, optional bool bShowCancelButton = true)
//</workshop>
{
	local XComPresentationLayerBase Presentation;
	local XComPlayerController xPlayerController;
	local UICallbackData_SystemMessage xSystemMessageData;
	local TDialogueBoxData kData;

	xPlayerController = XComPlayerController(class'UIInteraction'.static.GetLocalPlayer(0).Actor); // GetLocalPlayer takes player index not controller index. Do not user LocalUserIndex.
	if (xPlayerController != none)
	{
		Presentation = xPlayerController.Pres;
		if (Presentation != none)
		{
			if (!Presentation.UIIsShowingDialog()) // Ignore if a dialog is already up
			{
				`log( "DISPLAY SYSTEM MESSAGE:" @ `ShowVar(Presentation.m_kProgressDialogData.strTitle, Title) @ `ShowVar(Presentation.m_kProgressDialogData.strDescription, Description),,'XCom_Online');

				xSystemMessageData = new class'UICallbackData_SystemMessage';
				xSystemMessageData.dOnSystemMessageComplete = dOnDisplaySystemMessageComplete;

				kData.eType        = eDialog_Warning;
				kData.strTitle     = sSystemTitle;
				kData.strText      = sSystemMessage;
				kData.isModal      = true;
				kData.fnCallbackEx = OnSystemMessageDialogueClosed;
				kData.xUserData    = xSystemMessageData;

				Presentation.UIRaiseDialog( kData );
			}
			else
			{
				`warn(`location @ "Unable to display message as one is already being displayed." @ `ShowVar(Presentation.m_kProgressDialogData.strTitle, Title)@ `ShowVar(Presentation.m_kProgressDialogData.strDescription, Description)@ `ShowVar(Presentation.m_kProgressDialogData.strAbortButtonText, AbortText)@ `ShowVar(Presentation.m_kProgressDialogData.strAbortButtonText, fnCallback));
			}
		}
		else
		{
			`warn(`location @ "Unable to display message as the Pres was not found." @ `ShowVar(xPlayerController));
		}
	}
	else
	{
		`warn(`location @ "Unable to display message as the XComPlayerController was not found." @ `ShowVar(class'UIInteraction'.static.GetLocalPlayer(0)));
	}
}

simulated function OnSystemMessageDialogueClosed(Name eAction, UICallbackData xUserData)
{
	local UICallbackData_SystemMessage xSystemMessageData;

	`log("OnlineEventMgr::OnSystemMessageDialogueClosed" @ eAction @ `ShowVar(xUserData),,'XCom_Online');
	DebugPrintSystemMessageQueue();

	// This was closed automatically by the system, ignore calling the callbacks.
	if (eAction == 'eUIAction_Closed')
	{
		`log(`location @ "Waiting to fire off this system message at a later time.");
	}
	else if (xUserData != none)
	{
		xSystemMessageData = UICallbackData_SystemMessage(xUserData);
		if (xSystemMessageData != none)
		{
			xSystemMessageData.dOnSystemMessageComplete();
		}
	}
}
*/

simulated native function EnsureSavesAreComplete();

event OnSaveAsyncTaskComplete() //This is triggered when the GSaveDataTask_General task has been marked Done. Note that saving is not actually done at this point, but it is
								//safe to destroy actors
{

}

/**
 * MPLoadTimeout - The multiplayer load timer has elapsed.
 */
event OnMPLoadTimeout()
{
//bolson [PS3 TRC R180; bug 21140] - Hack to force the user back to the MP menus if they have spent too much time loading.
//                                   This can happen if the opponent disconnected while we were loading.
   m_fMPLoadTimeout = 0.0f;
`if(`isdefined(FINAL_RELEASE))  
	if( class'WorldInfo'.static.IsConsoleBuild(CONSOLE_PS3) //ps3 only to avoid rocking the boat.
		&& `XENGINE.IsAnyMoviePlaying()) //assume we're still at the loading screen if we're still playing a movie.
	{//we're still loading, which means we've been loading for too long.  
		//We're 10 seconds away from a loading time TRC violation on the consoles.  
		//We're going to abort back to the multiplayer menu before that happens. 
		`log(`location @ "Multiplayer loading timed out.  Your opponent probably disconnected. Returned to MP menu.", true, 'XCom_Online');
		ReturnToMPMainMenu(QuitReason_OpponentDisconnected);
	}
`endif 
}

function bool OnSystemMessage_AutomatchGameFull()
{
	local XComPresentationLayerBase Presentation;
	local XComPlayerController xPlayerController;
	local bool bSuccess;

	bSuccess = false;

	xPlayerController = XComPlayerController(class'UIInteraction'.static.GetLocalPlayer(0).Actor); // GetLocalPlayer takes player index not controller index. Do not user LocalUserIndex.
	if (xPlayerController != none)
	{
		Presentation = xPlayerController.Pres;
		if (Presentation != none)
		{
			bSuccess = Presentation.OnSystemMessage_AutomatchGameFull();
		}
	}

	return bSuccess;
}

function bool LastGameWasAutomatch()
{
	return m_kMPLastMatchInfo.m_bAutomatch;
}

function ResetAchievementState()
{
	bAchivementsEnabled = true;
	bAchievementsDisabledXComHero = false;
}

//<workshop> CONSOLE_DLC RJM 2016/04/14
//INS:
function OnContentChange()
{
	//bsg-fchen (9/14/16): Adding a delay to show the DLC prompt if player is not in the proper screen to show interact with the prompt
	local XComPresentationLayerBase Presentation;
	local Actor TimerActor;

	Presentation = XComPlayerController(class'UIInteraction'.static.GetLocalPlayer(0).Actor).Pres;
	if (Presentation != none)
	{
		if (!Presentation.ValidScreenForInvite())
		{
			TimerActor = class'WorldInfo'.static.GetWorldInfo().Spawn(class'DynamicPointInSpace');	
			TimerActor.SetTimer(1, false, nameof(OnContentChange), self);
			return ;
		}
	}
	//bsg-fchen (9/14/16): End

	// when new DLC is installed. A message was happening on every boot for XBox and not shoing up for PS4 unless DLC
	// finished installing while the game was running.
	ShowNewDLCMessage(IsNewDLCInstalled()); // bsg-jhilton (05.03.2017) - Fix console DLC refreshing
}

// bsg-nlong (9.1.16) 6917: Gave this function an option argumet set to true so if any other functions call it
// it should behave the same.
public function ShowNewDLCMessage(optional bool newDLCInstalled = true)
{
	local XComPresentationLayerBase Presentation;

	// bsg-nlong (9.1.16) 6917: Add a check if they are in the main menu or not. If they are show an information dialog
	// otherwise show the dialog that will prompt them to reload the game
	if( newDLCInstalled )
	{
		Presentation = XComPlayerController(class'UIInteraction'.static.GetLocalPlayer(0).Actor).Pres;
		if(Presentation.ScreenStack.HasInstanceOf(class'UIShell') && !Presentation.ScreenStack.HasInstanceOf(class'UICharacterPool') && !m_bInMessageBlockingScreenTransition) //bsg-jneal (9.13.16): show the in game prompt for character pool so we don't automatically lose changes
		{
			ErrorMessageMgr.EnqueueError(SystemMessage_NewDLCInstalled);
		}
		else
		{
			Presentation.ShowNewDLCInstalledMessage(); //bsg-jneal (6.24.17): keep checking to display DLC message when not in the frontend
		}
	}
}

// bsg-nlong (9.1.16) 6917: This function exists so that the UIShell can add the OnContentChange delegate when initialized
public function AddOnContentChangeDelegate()
{
	OnlineSub.ContentInterface.AddContentChangeDelegate(CheckForNewDLC); // bsg-nlong (9.7.16): Adding this delegate so that runtime data is updated when DLC is installed
	OnlineSub.ContentInterface.AddContentChangeDelegate(OnContentChange);
}

// bsg-nlong (9.1.16) 6917: end

//<workshop> CONSOLE JPS 2015/11/18
//INS:
/**
 * Helper for me and Brittany. Ryan Baker
 * No Sanity Checks btw so use with caution
 */
event string GrabMapNameFromMapCommand(string MapCommand)
{
	local array<string> SplitString;

	ParseStringIntoArray(MapCommand, SplitString, "?", true);
	if ( SplitString.Length > 0 )
	{
		return Right(SplitString[0], Len(SplitString[0]) - 5 ); //MINUS 5 FOR "open "
	}
	else
	{
		return "";
	}
}
//</workshop>

//Returns the state object cache from Temp history. TempHistory should only ever be used locally, never stored.
native function XComGameState LatestSaveState(out XComGameStateHistory TempHistory);

//Used when a piece of functionality needs to temporarily treat another history object as the canonical history. Takes the history to be considered the canonical history, returns the previous one.
native function XComGameStateHistory SwapHistory(XComGameStateHistory NewHistory);

// bsg-dforrest (9.14.16): Has autosave pending static duplication info. Checked to avoid any kind of GC while duplicating.
native function bool HasPendingSaveDuplicationInfo();
// bsg-dforrest (9.14.16): end

// Given an auto save type and campaign ID, retrieve the save slot. Returns INDEX_NONE if no save was found.
native function int FindAutosave(name AutosaveType, const out string CampaignID );

native function FindSavesForCampaign(const out string CampaignID, out array<string> OutSaveFilenames);

// cpptext & defaultproperties
//==================================================================================================================
//
cpptext
{
	/**
	 * Just calls the tick event
	 *
	 * @param DeltaTime The time that has passed since last frame.
	 */
	virtual void Tick(FLOAT DeltaTime);

	virtual void WaitForSavesToComplete();

	// Returns the local user's content cache, necessary to enumerate saved game content
	FContentListCache& GetLocalUserContentCache();
}

defaultproperties
{
	LocalUserIndex = 0
	LoginStatus = LS_NotLoggedIn
	StorageDeviceIndex = -1
	StorageDeviceName = ""
	bOnlineSubIsSteamworks = false
	bOnlineSubIsLive = false
	bOnlineSubIsPSN = false
//<workshop> CONSOLE_OSS wchen 10/28/2015
//INS:
	bOnlineSubIsDingo = false
	bOnlineSubIsNP = false
//</workshop>
	bHasLogin = false
	bHasProfileSettings = false
	bHasStorageDevice = false
	bShowingLoginUI = false
	//bShowingLossOfDataWarning = false
	//bShowingLoginRequiredWarning = false
	//bShowingLossOfSaveDeviceWarning = false
	bMCPEnabledByConfig = false
	bSaveExplanationScreenHasShown = false
	OnlineStatus = OnlineStatus_PlayingTheGame
	bStorageSelectPending = false
	bLoginUIPending = false
	//bSaveDeviceWarningPending = false
	fSaveDeviceWarningPendingTimer = 0
	bInShellLoginSequence = false
	bExternalUIOpen = false
	bUpdateSaveListInProgress = false
	bPerformingStandardLoad = false
	bPerformingTransferLoad = false
	m_bStatsReadSuccessful = false
	bAchivementsEnabled = true
	CheckpointIsSerializing = false
	CheckpointIsWritingToDisk = false
	ProfileIsSerializing = false
	bAcceptedInviteDuringGameplay = false
	ChallengeModeSeedGenNum = -1
	mbCurrentlyHandlingInvite = false; //bsg-jrucker (8/16/16): Initialize value to store currently handling an invite status.
	//<workshop> RICH_PRESENCE_ENABLE kmartinez 2016-2-24
	//INS:
	HasInitializedRichPresenceText = false
	//</workshop>
	//<workshop> SAVE_INDICATOR_PLACEMENT kmartinez 2016-04-19
	//INS:
	m_saveIndicatorDisplayTimeOnDialogBox = 3.0f
	m_saveIndicatorDisplayTimeNormaly = 3.0f
	m_saveIndicatorXPct_OnDialogBox = 0.9f
	m_saveIndicatorYPct_OnDialogBox = 0.92f
	m_saveIndicatorXPct_InStrategyMode = 0.9f
	m_saveIndicatorYPct_InStrategyMode = 0.88f
	m_saveIndicatorXPct_InTacticalMode = 0.9f
	m_saveIndicatorYPct_InTacticalMode = 0.85f
	//</workshop>
	//<workshop> GAME_INVITE_PROFILE_CONFIRM JTA 2016/5/4
	//INS:
	bGameInviteProfileNeedsConfirmation = false;
	//</workshop>

	bCanPlayTogether = false; //bsg-fchen (8/22/16): Update Play Together to handle single player cases
	bDoNotProcessNetworkIssues = false; //bsg-fchen (5.31.17): Adding a flag to prevent network handling to be processed while in the Rise of the Resistance bink movie
	FilterTextReplacementLength = 11; // bsg-nlong (9.29.16) 4427: Length of localized replacement array
	
	//bsg-jneal (6.24.17): no state for new game non-tutorial, adding bool to keep track
	m_bInMessageBlockingScreenTransition = false;
	m_bNeedsNewDLCInstalledMessage = false;
	//bsg-jneal (6.24.17): end

	PendingSaveGameDataDeletes = false; //bsg-jneal (7.12.17): adding check if a save game delete is running to prevent a race condition where the delete might not complete until after the subsequent save had finished
}
