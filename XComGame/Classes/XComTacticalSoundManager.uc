class XComTacticalSoundManager extends XComSoundManager dependson(XComTacticalMusicPlaylist) config(GameData);

// Initialization and cleanup events
var const config string InitializeTacticalAudioEvent;
var const config string CleanupTacticalAudioEvent;
var const config string SilenceCacophonyEvent;
var const config string UnsilenceCacophonyEvent;
var private transient bool bCleanedUp;

//Used to detect when we are in combat or not
var private int NumAlertedEnemies;
var privatewrite int NumCombatEvents;
var private bool bAmbienceStarted;
var private bool bDeferRequestStopHQ;
var private bool bDeferRequestStopHQAmb;

//WWise support
var config array<string> WiseSoundBankNames; //Sound banks for general use. These are loaded as part of initialization.
var array<AKBank> WiseSoundBanks; //Holds references to the wise sound banks for later use

struct PlaylistSetWithTransition
{
	var string PlaylistSetName;
	var float TransitionTime;
	var int Weight;

	structdefaultproperties
	{
		TransitionTime=3.0f
		Weight=50
	}
};

struct MusicPlaylistData
{
	var string								MusicStartEventPath;	// Name of music start event for this playlist
	var string								MusicStopEventPath;		// Name of music stop event for this playlist
	var string								MusicSwitchGroup;		// Name of switch group for this playlist
	var array<PlaylistSetWithTransition>	MusicPlaylistSets;		// Names of music sets for this playlist
};

struct NumberedEncounterMusic
{
	var bool bIncludeCommonPlaylist;
	var array<MusicPlaylistData> EncounterPlaylists;
};

//Combat sets
var const config string DefaultTacticalMusicSwitchGroup;
var const config array<PlaylistSetWithTransition> CommonTacticalMusicSets; //Each time the tactical music changes, a new set will be randomly selected

//Mission sound track event
var const config string MusicStartEventPath;
var const config string MusicStopEventPath;
var AkEvent MusicStartEvent;
var AkEvent MusicStopEvent;

//Tutorial and finale music
var const config NumberedEncounterMusic TutorialMusic;
var const config NumberedEncounterMusic FinaleMission1Music;
var const config NumberedEncounterMusic FinaleMission2Music;

//Mission end music
var const config name MissionEndSwitchGroup;
var const config name MissionSuccessSwitch;
var const config name MissionFailureSwitch;

var const config string MissionSuccessMusicEventPath;
var const config string MissionFailureMusicEventPath;
var privatewrite AkEvent MissionSuccessMusicEvent;
var privatewrite AkEvent MissionFailureMusicEvent;

//Tactical ambience state group
var const config name TacticalAmbienceStateGroup;
var const config name DefaultTacticalAmbienceState;
var private transient name CurrentTacticalAmbienceState;

//Parcel ambience events
var AkEvent PlotAmbienceStartEvent;
var AkEvent PlotAmbienceStopEvent;
var private transient string PlotAmbienceStartEventPathCached;
var private transient string PlotAmbienceStopEventPathCached;

//HQ audio
var AkEvent StopHQMusic;
var AkEvent StartHQMusic;

var AkEvent StopHQAmbience;
var AkEvent StartHQAmbience;

//This is for plot-specific audio that needs to be independent from XComAkSwitchVolumes
var const config array<name> AudioPlotNames;

struct PlotTypeSoundBankMapping
{
	var name PlotTypeName;
	var name BankName;
};

// Pre-Breach variables
var private transient int NumPreBreachUnitsPlaced;
var private transient bool bBreachReadySwitchStatus; // For preventing Wwise spam
var private transient bool bCombatAudioIsSet;

// Music switch names
var private transient const name MusicModeSwitch;
var private transient const name AnyUnitsPlacedSwitch;
var private transient const name BreachReadySwitch;

// DO NOT SHIP WITH FINAL RELEASE!
var XComTacticalMusicPlaylist CurrentMusicPlaylist;

var private transient bool bMusicHasBegun;

// Breach
var const config array<string> BreachButtonConfirmEventPaths;
var const config array<string> BreachFinishedEventPaths;
var private array<string> BreachButtonConfirmEvents;
var private array<string> BreachFinishedEvents;

var const config name CombatPlanningStateGroup;
var const config name CombatState;
var const config name PlanningState;

// Breach bookends
var const config string BreachStartEventPath;
var const config string BreachStopEventPath;
var privatewrite transient AkEvent BreachStartEvent;
var privatewrite transient AkEvent BreachStopEvent;
var private transient bool bBreachStarted; // Prevent spam

// Breach slomo
var const config string BreachTransitionToTargetingEventPath;
var const config string BreachSlomoOnEventPath;
var const config string BreachSlomoOffEventPath;
var privatewrite transient AkEvent BreachTransitionToTargetingEvent;
var privatewrite transient AkEvent BreachSlomoOnEvent;
var privatewrite transient AkEvent BreachSlomoOffEvent;
var private transient bool bBreachSlomoActivated; // Prevent spam

// Mission status
var private transient bool bInFirstEncounterOfMissionCached;
var private transient bool bFirstEncounterCacheValid;
var private transient bool bMissionStarted;
var private transient bool bMissionStatusInitialized;
var private transient bool bReactToBreachAction;

// Track current encounter for ambience
var private transient array<XComRoomVolume> EncountersPlayingAmbience;
var private transient array<XComRoomVolume> EncountersOccludingAudio;
var private transient bool bEncounterAmbienceInitialized;

var const config string CountUpAkEventName;

var private transient bool bRegisteredOnCivilianRescued;

struct ArrWrap
{
	var array<int> arr;
};

// Begin HELIOS Issue #43
// Most of the functions being private or protected makes it very difficult for mods to change the music willingly
// Un-private most of the functions so that mods can access the API.

//------------------------------------------------------------------------------
// Setup
//------------------------------------------------------------------------------
function Init()
{
	super.Init();
}

event PreBeginPlay()
{
	local int Index;
	local int SoundEventPathsIndex;
	local XComContentManager ContentMgr;
	local X2EventManager EventMgr;
	local object ThisObj;

	super.PreBeginPlay();

	ContentMgr = `CONTENT;

	for(Index = 0; Index < WiseSoundBankNames.Length; ++Index)
	{
		ContentMgr.RequestObjectAsync(WiseSoundBankNames[Index], self, OnWiseBankLoaded);
	}

	if (MusicStartEventPath != "")
	{
		ContentMgr.RequestObjectAsync(MusicStartEventPath, self, OnMissionSoundtrackLoaded);
	}
	if (MusicStopEventPath != "")
	{
		ContentMgr.RequestObjectAsync(MusicStopEventPath, self, OnMissionSoundtrackStopLoaded);
	}
	if (class'XComStrategySoundManager'.default.StopHQMusicEventPath != "")
	{
		ContentMgr.RequestObjectAsync(class'XComStrategySoundManager'.default.StopHQMusicEventPath, self, OnStopHQMusicAkEventLoaded);
	}
	if (class'XComStrategySoundManager'.default.PlayHQMusicEventPath != "")
	{
		ContentMgr.RequestObjectAsync(class'XComStrategySoundManager'.default.PlayHQMusicEventPath, self, OnStartHQMusicAkEventLoaded);
	}
	if (class'XComStrategySoundManager'.default.StopHQAmbienceEventPath != "")
	{
		ContentMgr.RequestObjectAsync(class'XComStrategySoundManager'.default.StopHQAmbienceEventPath, self, OnStopHQAmbienceAkEventLoaded);
	}
	if (class'XComStrategySoundManager'.default.PlayHQAmbienceEventPath != "")
	{
		ContentMgr.RequestObjectAsync(class'XComStrategySoundManager'.default.PlayHQAmbienceEventPath, self, OnStartHQAmbienceAkEventLoaded);
	}
	if (MissionSuccessMusicEventPath != "")
	{
		ContentMgr.RequestObjectAsync(MissionSuccessMusicEventPath, self, OnMissionSuccessMusicLoaded);
	}
	if (MissionFailureMusicEventPath != "")
	{
		ContentMgr.RequestObjectAsync(MissionFailureMusicEventPath, self, OnMissionFailureMusicLoaded);
	}

	for (Index = 0; Index < BreachButtonConfirmEventPaths.Length; ++Index)
	{
		SoundEventPathsIndex = SoundEventPaths.Find(BreachButtonConfirmEventPaths[Index]);
		if (SoundEventPathsIndex == INDEX_NONE)
		{
			ContentMgr.RequestObjectAsync(BreachButtonConfirmEventPaths[Index], self, OnAkEventMappingLoaded);
		}
		BreachButtonConfirmEvents.AddItem(GetEventNameFromPath(BreachButtonConfirmEventPaths[Index]));
	}

	for (Index = 0; Index < BreachFinishedEventPaths.Length; ++Index)
	{
		SoundEventPathsIndex = SoundEventPaths.Find(BreachFinishedEventPaths[Index]);
		if (SoundEventPathsIndex == INDEX_NONE)
		{
			ContentMgr.RequestObjectAsync(BreachFinishedEventPaths[Index], self, OnAkEventMappingLoaded);
		}
		BreachFinishedEvents.AddItem(GetEventNameFromPath(BreachFinishedEventPaths[Index]));
	}

	LoadBreachSounds(ContentMgr);

	bUsePersistentSoundAkObject = true;

	SubscribeToOnCleanupWorld();

	SetSwitch(BreachReadySwitch, 'False');
	ResetPreBreachUnitCount();

	ThisObj = self;
	EventMgr = `XEVENTMGR;
	EventMgr.RegisterForEvent(ThisObj, 'EncounterEnd', OnEncounterEnd, ELD_OnStateSubmitted);

	if (InitializeTacticalAudioEvent != "")
	{
		PlayAkEventDirect(InitializeTacticalAudioEvent, self);
	}
}

function PlaySoundOnCivilianRescued()
{
	local object ThisObj;

	if (!bRegisteredOnCivilianRescued)
	{
		`log("Sound manager will play UI sounds when civilians are rescued", , 'DevAudio');
		ThisObj = self;
		`XEVENTMGR.RegisterForEvent(ThisObj, 'CivilianRescued', OnCivilianRescued, ELD_OnVisualizationBlockStarted);
		bRegisteredOnCivilianRescued = true;
	}
}

function LoadUISounds()
{
	super.LoadUISounds();
	LoadUIScreenClassSounds(class'UIBreachAndroidReinforcementMenu');
}

function SilenceCacophony()
{
	if (SilenceCacophonyEvent != "")
	{
		PlayAkEventDirect(SilenceCacophonyEvent, self);
	}
}

function UnsilenceCacophony()
{
	if (UnsilenceCacophonyEvent != "")
	{
		PlayAkEventDirect(UnsilenceCacophonyEvent, self);
	}
}

//------------------------------------------------------------------------------
// Teardown
//------------------------------------------------------------------------------
function Cleanup()
{
	local Object ThisObj;
	local int Index;
	local XComContentManager ContentMgr;
	local X2EventManager EventMgr;

	if (bCleanedUp)
	{
		return;
	}

	if (CleanupTacticalAudioEvent != "")
	{
		PlayAkEventDirect(CleanupTacticalAudioEvent, self);
	}

	ContentMgr = `CONTENT;

	StopAllAmbience();

	for (Index = 0; Index < WiseSoundBankNames.Length; ++Index)
	{
		ContentMgr.UnCacheObject(WiseSoundBankNames[Index]);
	}

	ContentMgr.UnCacheObject(MusicStartEventPath);
	ContentMgr.UnCacheObject(MusicStopEventPath);
	ContentMgr.UnCacheObject(class'XComStrategySoundManager'.default.StopHQMusicEventPath);
	ContentMgr.UnCacheObject(class'XComStrategySoundManager'.default.PlayHQMusicEventPath);
	ContentMgr.UnCacheObject(class'XComStrategySoundManager'.default.StopHQAmbienceEventPath);
	ContentMgr.UnCacheObject(class'XComStrategySoundManager'.default.PlayHQAmbienceEventPath);

	if (MissionSuccessMusicEventPath != "")
	{
		ContentMgr.UnCacheObject(MissionSuccessMusicEventPath);
	}
	if (MissionFailureMusicEventPath != "")
	{
		ContentMgr.UnCacheObject(MissionFailureMusicEventPath);
	}

	if (PlotAmbienceStartEventPathCached != "")
	{
		ContentMgr.UnCacheObject(PlotAmbienceStartEventPathCached);
	}
	if (PlotAmbienceStopEventPathCached != "")
	{
		ContentMgr.UnCacheObject(PlotAmbienceStopEventPathCached);
	}

	UnloadBreachSounds(ContentMgr);

	ThisObj = self;	
	EventMgr = `XEVENTMGR;
	EventMgr.UnRegisterFromEvent(ThisObj, 'PlayerTurnBegun');
	EventMgr.UnRegisterFromEvent(ThisObj, 'BreachConfirmed');
	EventMgr.UnRegisterFromEvent(ThisObj, 'EncounterEnd');
	if (bRegisteredOnCivilianRescued)
	{
		EventMgr.UnRegisterFromEvent(ThisObj, 'CivilianRescued');
	}

	// Clear unit-placement Wwise/game syncs
	NumPreBreachUnitsPlaced = 0;
	UpdatePreBreachUnitCount();
	SetSwitch(BreachReadySwitch, 'False');

	super.Cleanup();
	bCleanedUp = true;
}

event Destroyed()
{
	Cleanup();
	super.Destroyed();
}

simulated event OnCleanupWorld()
{
	Cleanup();
	super.OnCleanupWorld();
}

//------------------------------------------------------------------------------
// Content loading callbacks
//------------------------------------------------------------------------------
function OnWiseBankLoaded(object LoadedArchetype)
{
	local AkBank LoadedBank;

	LoadedBank = AkBank(LoadedArchetype);	
	WiseSoundBanks.AddItem(LoadedBank);
}

function OnPlotAmbienceStartLoaded(object LoadedArchetype)
{
	PlotAmbienceStartEvent = AkEvent(LoadedArchetype);
	OnAkEventMappingLoaded(LoadedArchetype);
	PlayAkEvent(PlotAmbienceStartEvent);
	PlotAmbienceStartEventPathCached = PathName(PlotAmbienceStartEvent);
}

function OnPlotAmbienceStopLoaded(object LoadedArchetype)
{
	PlotAmbienceStopEvent = AkEvent(LoadedArchetype);
	OnAkEventMappingLoaded(LoadedArchetype);
	PlotAmbienceStopEventPathCached = PathName(PlotAmbienceStopEvent);
}

function OnMissionSoundtrackLoaded(object LoadedArchetype)
{
	MusicStartEvent = AkEvent(LoadedArchetype);
	OnAkEventMappingLoaded(LoadedArchetype); // Make mission soundtrack event callable by its name
}

function OnMissionSoundtrackStopLoaded(object LoadedArchetype)
{
	MusicStopEvent = AkEvent(LoadedArchetype);
	OnAkEventMappingLoaded(LoadedArchetype); // Make mission soundtrack event callable by its name
}

function OnMissionSuccessMusicLoaded(object LoadedArchetype)
{
	MissionSuccessMusicEvent = AkEvent(LoadedArchetype);
	assert(MissionSuccessMusicEvent != none);
}

function OnMissionFailureMusicLoaded(object LoadedArchetype)
{
	MissionFailureMusicEvent = AkEvent(LoadedArchetype);
	assert(MissionFailureMusicEvent != none);
}

function OnStopHQMusicAkEventLoaded(object LoadedObject)
{
	StopHQMusic = AkEvent(LoadedObject);
	assert(StopHQMusic != none);
	if(bDeferRequestStopHQ)
	{
		StopHQMusicEvent();
	}
}

function OnStartHQMusicAkEventLoaded(object LoadedObject)
{
	StartHQMusic = AkEvent(LoadedObject);
	assert(StartHQMusic != none);	
}

function OnStopHQAmbienceAkEventLoaded(object LoadedObject)
{
	StopHQAmbience = AkEvent(LoadedObject);
	assert(StopHQAmbience != none);
	if (bDeferRequestStopHQAmb)
	{
		StopHQAmbienceEvent();
	}
}

function OnStartHQAmbienceAkEventLoaded(object LoadedObject)
{
	StartHQAmbience = AkEvent(LoadedObject);
	assert(StartHQAmbience != none);
}

function OnBreachStartLoaded(object LoadedObject)
{
	BreachStartEvent = AkEvent(LoadedObject);
	assert(BreachStartEvent != none);
}

function OnBreachStopLoaded(object LoadedObject)
{
	BreachStopEvent = AkEvent(LoadedObject);
	assert(BreachStopEvent != none);
}


function OnBreachTransitionToTargetingLoaded(object LoadedObject)
{
	BreachTransitionToTargetingEvent = AkEvent(LoadedObject);
	assert(BreachTransitionToTargetingEvent != none);
}

function OnBreachSlomoOnLoaded(object LoadedObject)
{
	BreachSlomoOnEvent = AkEvent(LoadedObject);
	assert(BreachSlomoOnEvent != none);
}

function OnBreachSlomoOffLoaded(object LoadedObject)
{
	BreachSlomoOffEvent = AkEvent(LoadedObject);
	assert(BreachSlomoOffEvent != none);
}

private function LoadBreachSounds(optional XComContentManager ContentMgr)
{
	if (ContentMgr == none)
	{
		ContentMgr = `CONTENT;
	}

	if (BreachStartEvent == none && !(BreachStartEventPath ~= ""))
	{
		ContentMgr.RequestObjectAsync(BreachStartEventPath, self, OnBreachStartLoaded);
	}

	if (BreachStopEvent == none && !(BreachStopEventPath ~= ""))
	{
		ContentMgr.RequestObjectAsync(BreachStopEventPath, self, OnBreachStopLoaded);
	}

	if (BreachTransitionToTargetingEvent == none && !(BreachTransitionToTargetingEventPath ~= ""))
	{
		ContentMgr.RequestObjectAsync(BreachTransitionToTargetingEventPath, self, OnBreachTransitionToTargetingLoaded);
	}

	if (BreachSlomoOnEvent == none && !(BreachSlomoOnEventPath ~= ""))
	{
		ContentMgr.RequestObjectAsync(BreachSlomoOnEventPath, self, OnBreachSlomoOnLoaded);
	}

	if (BreachSlomoOffEvent == none && !(BreachSlomoOffEventPath ~= ""))
	{
		ContentMgr.RequestObjectAsync(BreachSlomoOffEventPath, self, OnBreachSlomoOffLoaded);
	}
}

private function UnloadBreachSounds(optional XComContentManager ContentMgr)
{
	if (ContentMgr == none)
	{
		ContentMgr = `CONTENT;
	}

	if (BreachStartEvent != none)
	{
		BreachStartEvent = none;
		ContentMgr.UnCacheObject(BreachStartEventPath);
	}

	if (BreachStopEvent != none)
	{
		BreachStopEvent = none;
		ContentMgr.UnCacheObject(BreachStopEventPath);
	}

	if (BreachTransitionToTargetingEvent != none )
	{
		BreachTransitionToTargetingEvent = none;
		ContentMgr.UnCacheObject(BreachTransitionToTargetingEventPath);
	}

	if (BreachSlomoOnEvent != none)
	{
		BreachSlomoOnEvent = none;
		ContentMgr.UnCacheObject(BreachSlomoOnEventPath);
	}

	if (BreachSlomoOffEvent != none)
	{
		BreachSlomoOffEvent = none;
		ContentMgr.UnCacheObject(BreachSlomoOffEventPath);
	}
}

//------------------------------------------------------------------------------
// HQ events
//------------------------------------------------------------------------------
function StopHQMusicEvent()
{
	if (StopHQMusic != none)
	{
		PlayAkEvent(StopHQMusic);
	}
	else
	{
		bDeferRequestStopHQ = true;
	}
}

function StopHQAmbienceEvent()
{
	if (StopHQAmbience != none)
	{
		PlayAkEvent(StopHQAmbience);
	}
	else
	{
		bDeferRequestStopHQAmb = true;
	}
}

function StartEndBattleMusic()
{
	StopSounds();
	PlayAfterActionMusic();
}

function PlayAfterActionMusic()
{
	local XComGameStateHistory History;
	local XComGameState_BattleData BattleData;
	local XComGameState_HeadquartersXCom XComHQ;
	local bool bVictory;
	local bool bPlayedEvent;

	if (MissionSuccessMusicEvent != none ||
		MissionFailureMusicEvent != none ||
		(MissionEndSwitchGroup != '' && (MissionSuccessSwitch != '' || MissionFailureSwitch != '')))
	{
		History = `XCOMHISTORY;
		BattleData = XComGameState_BattleData(History.GetSingleGameStateObjectForClass(class'XComGameState_BattleData', true));

		if (BattleData != none)
		{
			bVictory = BattleData.bLocalPlayerWon;
		}
		else
		{
			XComHQ = XComGameState_HeadquartersXCom(History.GetSingleGameStateObjectForClass(class'XComGameState_HeadquartersXCom'));
			bVictory = XComHQ.bSimCombatVictory;
		}

		if (bVictory)
		{
			if (MissionEndSwitchGroup != '' && MissionSuccessSwitch != '')
			{
				SetSwitch(MissionEndSwitchGroup, MissionSuccessSwitch);
			}

			if (MissionSuccessMusicEvent != none)
			{
				PlayAkEvent(MissionSuccessMusicEvent);
				bPlayedEvent = true;
			}
		}
		else
		{
			if (MissionEndSwitchGroup != '' && MissionFailureSwitch != '')
			{
				SetSwitch(MissionEndSwitchGroup, MissionFailureSwitch);
			}

			if (MissionFailureMusicEvent != none)
			{
				PlayAkEvent(MissionFailureMusicEvent);
				bPlayedEvent = true;
			}
		}
	}

	if (!bPlayedEvent)
	{
		PlayAkEvent(StartHQMusic);
	}
}

event OnActiveUnitChanged(XComGameState_Unit NewActiveUnit)
{
	//In previous systems, this would turn on/off environmental sounds such as rain depending on where the unit is
}

//------------------------------------------------------------------------------
// Tactical music
//------------------------------------------------------------------------------
function MeasurePlaylistStatistics()
{
	`if(`notdefined(FINAL_RELEASE))
	local int i;
	local int j;
	local array<ArrWrap> Hist;
	local int sum;
	local int grandSum;
	local int prevGroup;
	local int streak;
	local int longestStreak;

	CurrentMusicPlaylist.DeactivateLog();

	prevGroup = -1;
	longestStreak = 0;
	for (i = 0; i < 1000000; ++i)
	{
		CurrentMusicPlaylist.ReadyForNextSet();
		CurrentMusicPlaylist.ChooseRandomMusicSet();

		if (prevGroup != CurrentMusicPlaylist.SelectedPlaylistGroupIdx)
		{
			prevGroup = CurrentMusicPlaylist.SelectedPlaylistGroupIdx;
			streak = 0;
		}
		else if (++streak > longestStreak)
		{
			longestStreak = streak;
		}

		if (Hist.Length <= CurrentMusicPlaylist.SelectedPlaylistGroupIdx)
		{
			Hist.Length = CurrentMusicPlaylist.SelectedPlaylistGroupIdx + 1;
		}

		if (Hist[CurrentMusicPlaylist.SelectedPlaylistGroupIdx].arr.Length <= CurrentMusicPlaylist.SelectedPlaylistSetIdx)
		{
			j = Hist[CurrentMusicPlaylist.SelectedPlaylistGroupIdx].arr.Length;
			Hist[CurrentMusicPlaylist.SelectedPlaylistGroupIdx].arr.Length = CurrentMusicPlaylist.SelectedPlaylistSetIdx + 1;
			for (j = j; j < Hist[CurrentMusicPlaylist.SelectedPlaylistGroupIdx].arr.Length - 1; ++j)
			{
				Hist[CurrentMusicPlaylist.SelectedPlaylistGroupIdx].arr[j] = 0;
			}
			Hist[CurrentMusicPlaylist.SelectedPlaylistGroupIdx].arr[CurrentMusicPlaylist.SelectedPlaylistSetIdx] = 1;
		}
		else
		{
			Hist[CurrentMusicPlaylist.SelectedPlaylistGroupIdx].arr[CurrentMusicPlaylist.SelectedPlaylistSetIdx] += 1;
		}
	}

	`log("Music playlist histogram:", , 'DevAudio');
	grandSum = 0;
	for (i = 0; i < Hist.Length; ++i)
	{
		`log("	Group " $ string(i) $ ":", , 'DevAudio');
		`log("		Longest streak: " $ string(longestStreak), , 'DevAudio');
		sum = 0;
		for (j = 0; j < Hist[i].arr.Length; ++j)
		{
			`log("		Set " $ string(j) $ ": " $ string(Hist[i].arr[j]), , 'DevAudio');
			sum += Hist[i].arr[j];
		}
		`log("		Total for Group " $ string(i) $ ": " $ string(sum), , 'DevAudio');
		grandSum += sum;
	}
	`log("	Total grand sum: " $ string(grandSum), , 'DevAudio');

	Hist.Length = 0;
	prevGroup = -1;
	longestStreak = 0;
	for (i = 0; i < 1000000; ++i)
	{
		CurrentMusicPlaylist.ResetNoRepeatQueue();
		CurrentMusicPlaylist.ReadyForNextSet();
		CurrentMusicPlaylist.ChooseRandomMusicSet();

		if (prevGroup != CurrentMusicPlaylist.SelectedPlaylistGroupIdx)
		{
			prevGroup = CurrentMusicPlaylist.SelectedPlaylistGroupIdx;
			streak = 0;
		}
		else if (++streak > longestStreak)
		{
			longestStreak = streak;
		}

		if (Hist.Length <= CurrentMusicPlaylist.SelectedPlaylistGroupIdx)
		{
			Hist.Length = CurrentMusicPlaylist.SelectedPlaylistGroupIdx + 1;
		}

		if (Hist[CurrentMusicPlaylist.SelectedPlaylistGroupIdx].arr.Length <= CurrentMusicPlaylist.SelectedPlaylistSetIdx)
		{
			j = Hist[CurrentMusicPlaylist.SelectedPlaylistGroupIdx].arr.Length;
			Hist[CurrentMusicPlaylist.SelectedPlaylistGroupIdx].arr.Length = CurrentMusicPlaylist.SelectedPlaylistSetIdx + 1;
			for (j = j; j < Hist[CurrentMusicPlaylist.SelectedPlaylistGroupIdx].arr.Length - 1; ++j)
			{
				Hist[CurrentMusicPlaylist.SelectedPlaylistGroupIdx].arr[j] = 0;
			}
			Hist[CurrentMusicPlaylist.SelectedPlaylistGroupIdx].arr[CurrentMusicPlaylist.SelectedPlaylistSetIdx] = 1;
		}
		else
		{
			Hist[CurrentMusicPlaylist.SelectedPlaylistGroupIdx].arr[CurrentMusicPlaylist.SelectedPlaylistSetIdx] += 1;
		}
	}

	`log("Music playlist histogram with repeats:", , 'DevAudio');
	grandSum = 0;
	for (i = 0; i < Hist.Length; ++i)
	{
		`log("	Group " $ string(i) $ ":", , 'DevAudio');
		`log("		Longest streak: " $ string(longestStreak), , 'DevAudio');
		sum = 0;
		for (j = 0; j < Hist[i].arr.Length; ++j)
		{
			`log("		Set " $ string(j) $ ": " $ string(Hist[i].arr[j]), , 'DevAudio');
			sum += Hist[i].arr[j];
		}
		`log("		Total for Group " $ string(i) $ ": " $ string(sum), , 'DevAudio');
		grandSum += sum;
	}
	`log("	Total grand sum: " $ string(grandSum), , 'DevAudio');

	CurrentMusicPlaylist.ActivateLog();
	`endif
}

function SelectRandomTacticalMusicSet()
{
	CurrentMusicPlaylist.ChooseRandomMusicSet();
	CurrentMusicPlaylist.SubmitMusicGameState();
}

function ChooseTacticalMusicSet(const int GroupIdx, const int SetIdx)
{
	CurrentMusicPlaylist.ChooseMusicSet(GroupIdx, SetIdx);
	CurrentMusicPlaylist.SubmitMusicGameState();
}

function ForceTacticalMusicSet(const int GroupIdx, const int SetIdx, optional bool bSave = false)
{
	local bool bWasReady;

	bWasReady = CurrentMusicPlaylist.IsReadyForNextSet();
	CurrentMusicPlaylist.ReadyForNextSet();
	CurrentMusicPlaylist.ChooseMusicSet(GroupIdx, SetIdx);

	if (bSave)
	{
		CurrentMusicPlaylist.SubmitMusicGameState();
	}

	if (bWasReady)
	{
		CurrentMusicPlaylist.ReadyForNextSet();
	}
}

function string GetTacticalMusicDescription()
{
	local int GroupIdx;
	local int SetIdx;
	local string GroupTab;
	local string SetTab;
	local string SetMemberTab;
	local string MusicInfo;
	local string SelectedStartEventPath;
	local name SelectedSwitchGroup;
	local name SelectedSwitchValue;

	GroupTab = "         ";
	SetTab = GroupTab $ "      ";
	SetMemberTab = SetTab $ "       ";
	MusicInfo = "Current tactical music playlist:\n";
	for (GroupIdx = 0; GroupIdx < CurrentMusicPlaylist.PlaylistGroups.Length; ++GroupIdx)
	{
		MusicInfo $= "Group " $ GroupIdx $ ": Start event: " $
			CurrentMusicPlaylist.PlaylistGroups[GroupIdx].StartEventPath $ "\n" $ GroupTab $ "Stop event: " $
			CurrentMusicPlaylist.PlaylistGroups[GroupIdx].StopEventPath $ "\n" $ GroupTab $ "Group name: " $
			CurrentMusicPlaylist.PlaylistGroups[GroupIdx].SwitchGroup $ "\n" $ GroupTab $ "Sets: ";
		for (SetIdx = 0; SetIdx < CurrentMusicPlaylist.PlaylistGroups[GroupIdx].PlaylistSets.Length; ++SetIdx)
		{
			if (SetIdx > 0)
			{
				MusicInfo $= SetTab;
			}
			MusicInfo $= "Set " $ SetIdx $ ": Set name: " $
				CurrentMusicPlaylist.PlaylistGroups[GroupIdx].PlaylistSets[SetIdx] $ "\n" $ SetMemberTab $ "Transition time: " $
				CurrentMusicPlaylist.PlaylistGroups[GroupIdx].TransitionTimes[SetIdx] $ "\n";
		}
	}
	if (CurrentMusicPlaylist.GetSelectedMusicData(SelectedStartEventPath, SelectedSwitchGroup, SelectedSwitchValue))
	{
		MusicInfo $= "Selected event: " $ SelectedStartEventPath $
			"\nSelected switch group: " $ string(SelectedSwitchGroup) $
			"\nSelected switch value: " $ string(SelectedSwitchValue) $ "\n";
	}
	else
	{
		MusicInfo $= "No playlist set selected.\n";
	}

	return MusicInfo;
}

public function bool GetSelectedMusicData(out string StartEventPath, out name SwitchGroup, out name SwitchValue)
{
	return CurrentMusicPlaylist.GetSelectedMusicData(StartEventPath, SwitchGroup, SwitchValue);
}

public function InitializeMusicPlaylist()
{
	local XComGameStateHistory History;
	local XComGameState_TacticalMusicPlaylist TacticalMusic;
	local int NumPlaylistGameStates;
	local XComGameState_HeadquartersDio DioHQ;
	local XComGameState_Investigation CurrentInvestigation;

	if (CurrentMusicPlaylist == none)
	{
		CurrentMusicPlaylist = new class'XComTacticalMusicPlaylist';
	}
	else
	{
		CurrentMusicPlaylist.ClearPlaylistGroups();
	}

	History = `XCOMHISTORY;
	foreach History.IterateByClassType(class'XComGameState_TacticalMusicPlaylist', TacticalMusic)
	{
		++NumPlaylistGameStates;
	}
	`log("XComTacticalSoundManager.InitializeMusicPlaylist: Found " $ string(NumPlaylistGameStates) $ " playlist game states", , 'DevAudio');

	TacticalMusic = XComGameState_TacticalMusicPlaylist(History.GetSingleGameStateObjectForClass(class'XComGameState_TacticalMusicPlaylist', true));
	DioHQ = `DIOHQ;
	if (DioHQ != none)
	{
		if (DioHQ.TacticalGameplayTags.Find(class'XComGameStateContext_LaunchTutorialMission'.default.TutorialMissionGamePlayTag) != INDEX_NONE)
		{
			LogAudio("XComTacticalSoundManager.InitializeMusicPlaylist: Initializing tutorial music playlist", true);
			InitializeSpecialMusicPlaylist(TacticalMusic, TutorialMusic);
		}
		else
		{
			CurrentInvestigation = XComGameState_Investigation(History.GetGameStateForObjectID(DioHQ.CurrentInvestigation.ObjectID));
			if (CurrentInvestigation != none &&
				(CurrentInvestigation.TacticalGameplayTags.Find('Finale') != INDEX_NONE || DioHQ.TacticalGameplayTags.Find('Finale') != INDEX_NONE))
			{
				LogAudio("XComTacticalSoundManager.InitializeMusicPlaylist: Found Finale gameplay tag", true);
				if (CurrentInvestigation.Stage == eStage_Groundwork)
				{
					LogAudio("XComTacticalSoundManager.InitializeMusicPlaylist: Initializing finale mission 1 music playlist", true);
					InitializeSpecialMusicPlaylist(TacticalMusic, FinaleMission1Music);
				}
				else if (CurrentInvestigation.Stage == eStage_Takedown)
				{
					LogAudio("XComTacticalSoundManager.InitializeMusicPlaylist: Initializing finale mission 2 music playlist", true);
					InitializeSpecialMusicPlaylist(TacticalMusic, FinaleMission2Music);
				}
			}
			else
			{
				LogAudio("XComTacticalSoundManager.InitializeMusicPlaylist: Didn't find any gameplay tags for special music", true);
			}
		}

		`XEVENTMGR.TriggerEvent('TACTICAL_MusicChanged_Submitted', TacticalMusic, TacticalMusic, none);
	}

	if (CurrentMusicPlaylist.PlaylistGroups.Length == 0)
	{
		LogAudio("XComTacticalSoundManager.InitializeMusicPlaylist: Initializing normal music playlist", true);
		InitializeNormalMusicPlaylist(TacticalMusic, History);
	}
}

public function InitializeSpecialMusicPlaylist(XComGameState_TacticalMusicPlaylist TacticalMusic, const out NumberedEncounterMusic MusicData)
{
	local TacticalMusicPlaylistGroup PlaylistGroup;
	local int EncounterPlaylistIdx;
	local int PlaylistSetIdx;

	CurrentMusicPlaylist.SetEncounterTracking(TacticalMusic, true);
	if (MusicData.bIncludeCommonPlaylist)
	{
		GetCommonPlaylist(PlaylistGroup);
		CurrentMusicPlaylist.AddPlaylistGroup(PlaylistGroup);
	}

	for (EncounterPlaylistIdx = 0; EncounterPlaylistIdx < MusicData.EncounterPlaylists.length; ++EncounterPlaylistIdx)
	{
		PlaylistGroup.EncounterNumber = EncounterPlaylistIdx;
		PlaylistGroup.StartEventPath = MusicData.EncounterPlaylists[EncounterPlaylistIdx].MusicStartEventPath;
		PlaylistGroup.StopEventPath = MusicData.EncounterPlaylists[EncounterPlaylistIdx].MusicStopEventPath;
		PlaylistGroup.SwitchGroup = name(MusicData.EncounterPlaylists[EncounterPlaylistIdx].MusicSwitchGroup);

		PlaylistGroup.PlaylistSets.Length = 0;
		PlaylistGroup.TransitionTimes.Length = 0;
		PlaylistGroup.Weights.Length = 0;
		for (PlaylistSetIdx = 0; PlaylistSetIdx < MusicData.EncounterPlaylists[EncounterPlaylistIdx].MusicPlaylistSets.length; ++PlaylistSetIdx)
		{
			PlaylistGroup.PlaylistSets.AddItem(name(MusicData.EncounterPlaylists[EncounterPlaylistIdx].MusicPlaylistSets[PlaylistSetIdx].PlaylistSetName));
			PlaylistGroup.TransitionTimes.AddItem(MusicData.EncounterPlaylists[EncounterPlaylistIdx].MusicPlaylistSets[PlaylistSetIdx].TransitionTime);
			PlaylistGroup.Weights.AddItem(MusicData.EncounterPlaylists[EncounterPlaylistIdx].MusicPlaylistSets[PlaylistSetIdx].Weight);
		}

		CurrentMusicPlaylist.AddPlaylistGroup(PlaylistGroup);
	}
}

public function InitializeNormalMusicPlaylist(XComGameState_TacticalMusicPlaylist TacticalMusic, optional XComGameStateHistory History)
{
	local XComGameState_TacticalMusicGroup TacticalMusicGroup;
	local TacticalMusicPlaylistGroup CommonPlaylistGroup;
	local int ComponentObjectIdx;

	if (TacticalMusic != none && TacticalMusic.ComponentObjectIds.Length > 0)
	{
		`log("XComTacticalSoundManager.InitializeNormalMusicPlaylist: Found music playlist game state; setting playlist accordingly.", , 'DevAudio');
		CurrentMusicPlaylist.SetEncounterTracking(TacticalMusic);

		if (History == none)
		{
			History = `XCOMHISTORY;
		}

		for (ComponentObjectIdx = 0; ComponentObjectIdx < TacticalMusic.ComponentObjectIds.Length; ++ComponentObjectIdx)
		{
			TacticalMusicGroup = XComGameState_TacticalMusicGroup(History.GetGameStateForObjectID(TacticalMusic.ComponentObjectIds[ComponentObjectIdx]));
			if (TacticalMusicGroup != none)
			{
				if (TacticalMusicGroup.IsEmpty())
				{
					`log("XComTacticalSoundManager.InitializeNormalMusicPlaylist: Adding common playlist group", , 'DevAudio');
					GetCommonPlaylist(CommonPlaylistGroup);
					CurrentMusicPlaylist.AddPlaylistGroup(CommonPlaylistGroup);
				}
				else
				{
					`log("XComTacticalSoundManager.InitializeNormalMusicPlaylist: Adding game state playlist group", , 'DevAudio');
					CurrentMusicPlaylist.AddPlaylistGroupFromGameStateObject(TacticalMusicGroup);
				}
			}
		}

		if (TacticalMusic.IsTakedownPlaylist() || !CurrentMusicPlaylist.ChooseMusicSet(TacticalMusic.SelectedGroupIdx, TacticalMusic.SelectedSetIdx))
		{
			`log("XComTacticalSoundManager.InitializeNormalMusicPlaylist: No music set selection in music playlist game state; choosing set based on gameplay.", , 'DevAudio');
			// Selection will happen when planning/combat audio is evaluated
		}
		else
		{
			`log("XComTacticalSoundManager.InitializeNormalMusicPlaylist: Chose saved selection, which was group " $ TacticalMusic.SelectedGroupIdx $ ", set " $ TacticalMusic.SelectedSetIdx $ ".", , 'DevAudio');
		}

		CurrentMusicPlaylist.SetNoRepeatQueue(TacticalMusic);
	}
	else
	{
		`log("XComTacticalSoundManager.InitializeNormalMusicPlaylist: No music playlist game state; choosing from default playlist based on gameplay.", , 'DevAudio');
		GetCommonPlaylist(CommonPlaylistGroup);
		CurrentMusicPlaylist.AddPlaylistGroup(CommonPlaylistGroup);
		// Selection will happen when planning/combat audio is evaluated
	}
}

public function GetCommonPlaylist(out TacticalMusicPlaylistGroup CommonPlaylistGroup)
{
	local int CommonPlaylistIdx;

	CommonPlaylistGroup.StartEventPath = MusicStartEventPath;
	CommonPlaylistGroup.StopEventPath = MusicStopEventPath;
	CommonPlaylistGroup.StartEvent = MusicStartEvent;
	CommonPlaylistGroup.StopEvent = MusicStopEvent;
	CommonPlaylistGroup.SwitchGroup = name(DefaultTacticalMusicSwitchGroup);
	CommonPlaylistGroup.EncounterNumber = INDEX_NONE;
	CommonPlaylistGroup.PlaylistSets.Length = 0;
	CommonPlaylistGroup.TransitionTimes.Length = 0;
	CommonPlaylistGroup.Weights.Length = 0;
	for (CommonPlaylistIdx = 0; CommonPlaylistIdx < CommonTacticalMusicSets.Length; ++CommonPlaylistIdx)
	{
		CommonPlaylistGroup.PlaylistSets.AddItem(name(CommonTacticalMusicSets[CommonPlaylistIdx].PlaylistSetName));
		CommonPlaylistGroup.TransitionTimes.AddItem(CommonTacticalMusicSets[CommonPlaylistIdx].TransitionTime);
		CommonPlaylistGroup.Weights.AddItem(CommonTacticalMusicSets[CommonPlaylistIdx].Weight);
	}
}

public function PlayCurrentPlaylistSelection()
{
	CurrentMusicPlaylist.PlaySelectedSet();
}

public function HandleMusicOverride()
{
	local XComGameState_BattleData BattleData;
	local array<XComRoomVolume> EncounterVolumes;
	local XComRoomVolume EncounterRoomVolume;

	BattleData = XComGameState_BattleData(`XCOMHISTORY.GetSingleGameStateObjectForClass(class'XComGameState_BattleData'));
	`XWORLD.GetRoomVolumesByRoomID(BattleData.MapData.RoomIDs[BattleData.BreachingRoomListIndex], EncounterVolumes);
	if (EncounterVolumes.Length == 1)
	{
		EncounterRoomVolume = EncounterVolumes[0];

		`log("TacticalSoundManager.HandleMusicOverride: Checking music override data for \"" $
			PathName(EncounterRoomVolume) $ "\"", , 'DevAudio');

		if (CurrentMusicPlaylist.TryMusicOverride(EncounterRoomVolume))
		{
			`log("TacticalSoundManager.HandleMusicOverride: Tactical music overridden.", , 'DevAudio');
		}
	}
	`if(`notdefined(FINAL_RELEASE))
	else if (EncounterVolumes.Length > 1)
	{
		`RedScreen("An encounter has multiple room volumes; encounter-based music override data should be moved to a more suitable location than XComRoomVolume. @dprice");
	}
	`endif
}

//------------------------------------------------------------------------------
// Ambience
//------------------------------------------------------------------------------
function StartAllAmbience()
{
	local XComGameState_BattleData BattleData;

	local XComParcelManager ParcelMgr;
	local PlotDefinition PlotDef;

	if(!bAmbienceStarted)
	{
		// Get the relevant environment ambiance settings.
		BattleData = XComGameState_BattleData(`XCOMHISTORY.GetSingleGameStateObjectForClass(class'XComGameState_BattleData', true));
		ParcelMgr = `PARCELMGR;

		// Ambiance event is played by OnParcelAmbienceStartLoaded.
		StopAllAmbience();

		// Plot-based ambiance event		
		PlotDef = ParcelMgr.GetPlotDefinition(BattleData.MapData.PlotMapName);

		`log("Attempting to play plot-based ambience audio event.", , 'DevAudio');
		if (PlotDef.AudioAmbienceStartEventPath != "")
		{
			`CONTENT.RequestObjectAsync(PlotDef.AudioAmbienceStartEventPath, self, OnPlotAmbienceStartLoaded);
			if (PlotDef.AudioAmbienceStopEventPath != "") // Nested so that stop event isn't loaded if no start event is
			{
				`CONTENT.RequestObjectAsync(PlotDef.AudioAmbienceStopEventPath, self, OnPlotAmbienceStopLoaded);
			}
		}
		else
		{
			`RedScreen("Plot" @ PlotDef.MapName @ "did not have an AudioAmbienceStartEventPath defined - ambient audio may not play. @dprice");
		}
		
		// Set the ambiance switches.
		SetAmbienceState();

		InitializeMusicPlaylist();

		InitializeAudioOcclusion();

		NumCombatEvents = 0;
		bAmbienceStarted = true;
	}

	StartAllAmbientSounds();
}

function StopAllAmbience()
{
	if (PlotAmbienceStopEvent != None)
	{
		PlayAkEvent(PlotAmbienceStopEvent);
	}
	SetSwitch( MusicModeSwitch, 'None' );
	UnsetCombatPlanningState();
	CurrentMusicPlaylist.StopCurrentSet();
}

//------------------------------------------------------------------------------
// Pre-Breach and Breach
//------------------------------------------------------------------------------
private function UpdatePreBreachUnitCount()
{
	`log("PreBreach unit count:" @ NumPreBreachUnitsPlaced, , 'DevAudio');

	SetRTPCValue('Planning_Units_Placed', float(NumPreBreachUnitsPlaced));

	if (NumPreBreachUnitsPlaced > 0)
	{
		SetSwitch(AnyUnitsPlacedSwitch, 'True');
	}
	else
	{
		SetSwitch(AnyUnitsPlacedSwitch, 'False');
	}
}

// Breach ready status depends on completed unit-placement visualization,
// so this must be called after unit-placement visualization completes to be effective
function UpdateBreachReadySwitch()
{
	local bool bUnitsBreachReady;

	bUnitsBreachReady = class'XComBreachHelpers'.static.AreUnitsBreachReady();
	if (bUnitsBreachReady != bBreachReadySwitchStatus)
	{
		if (bUnitsBreachReady)
		{
			SetSwitch(BreachReadySwitch, 'True');
		}
		else
		{
			SetSwitch(BreachReadySwitch, 'False');
		}
		bBreachReadySwitchStatus = bUnitsBreachReady;
	}
}

function PreBreachUnitPlaced()
{
	++NumPreBreachUnitsPlaced;
	UpdatePreBreachUnitCount();
}

function PreBreachUnitUnplaced()
{
	--NumPreBreachUnitsPlaced;
	UpdatePreBreachUnitCount();
}

function OverridePreBreachUnitCount(const int NumUnitsPlaced)
{
	SetRTPCValue('Planning_Units_Placed', float(NumUnitsPlaced));

	if (NumUnitsPlaced > 0)
	{
		SetSwitch(AnyUnitsPlacedSwitch, 'True');
	}
	else
	{
		SetSwitch(AnyUnitsPlacedSwitch, 'False');
	}
}

function ResetPreBreachUnitCountOverride()
{
	UpdatePreBreachUnitCount();
}

private function ResetPreBreachUnitCount()
{
	class'XComBreachHelpers'.static.AreUnitsBreachReady(NumPreBreachUnitsPlaced);

	UpdatePreBreachUnitCount();
}

function BeginPreBreachAudio()
{
	local object ThisObj;
	local bool bMissionHasStarted;

	bMissionHasStarted = !IsCurrentEncounterFirstInMission(true);
	SetMissionStatus(bMissionHasStarted);

	// The sound system reacts to units being placed during pre-breach, so reset its counters
	ResetPreBreachUnitCount();

	SetPlanningAudio();

	ThisObj = self;
	`XEVENTMGR.RegisterForEvent(ThisObj, 'BreachConfirmed', OnBreachConfirmed);
}

function BeginBreachAudio()
{
	local object ThisObj;
	local int Index;
	local XComGameState_BattleData BattleData;
	local array<XComRoomVolume> EncounterVolumes;

	`log("Tactical sound manager beginning breach audio", , 'DevAudio');

	SetMissionStatus(true);

	for (Index = 0; Index < BreachButtonConfirmEvents.Length; ++Index)
	{
		PlayPersistentSoundEvent(BreachButtonConfirmEvents[Index]);
	}
	bReactToBreachAction = true;

	// Activate occlusion in the current encounter on breach confirm before deactivating it in the previous encounter on combat begin
	BattleData = XComGameState_BattleData(`XCOMHISTORY.GetSingleGameStateObjectForClass(class'XComGameState_BattleData'));
	`XWORLD.GetRoomVolumesByRoomID(BattleData.MapData.RoomIDs[BattleData.BreachingRoomListIndex], EncounterVolumes);
	if (EncounterVolumes.Length > 0)
	{
		ActivateAudioOcclusion(EncounterVolumes[0].AmbienceComponent);
		EncountersOccludingAudio.AddItem(EncounterVolumes[0]);
	}

	ThisObj = self;
	`XEVENTMGR.UnRegisterFromEvent(ThisObj, 'BreachConfirmed');
}

function OnWaitForBreachAction()
{
	if (bReactToBreachAction)
	{
		CurrentMusicPlaylist.StopCurrentSet(true); // Stop music during breach
		PlayBreachStart();
		bReactToBreachAction = false;
	}
}

public function SetMissionStatus(const bool bStarted)
{
	if (!bMissionStatusInitialized || bMissionStarted != bStarted)
	{
		SetState('MissionStatus', (bStarted) ? 'MissionStarted' : 'PreMission');
		bMissionStarted = bStarted;
		bMissionStatusInitialized = true;
	}
}

function bool IsCurrentEncounterFirstInMission(optional const bool bClearCache)
{
	if (bClearCache)
	{
		bFirstEncounterCacheValid = false;
	}

	if (!bFirstEncounterCacheValid)
	{
		bInFirstEncounterOfMissionCached = CurrentMusicPlaylist.CurrentEncounterNumber == 0;
		bFirstEncounterCacheValid = true;
	}

	return bInFirstEncounterOfMissionCached;
}

function EndEncounter()
{
	if (CurrentMusicPlaylist.IncrementEncounter())
	{
		LogAudio("Room cleared. Submitting music game state.", true);
		CurrentMusicPlaylist.SubmitMusicGameState();
	}
}

private function EventListenerReturn OnEncounterEnd(Object EventData, Object EventSource, XComGameState GameState, Name EventID, Object CallbackData)
{
	EndEncounter();
	return ELR_NoInterrupt;
}

private function EventListenerReturn OnBreachConfirmed(Object EventData, Object EventSource, XComGameState GameState, Name EventID, Object CallbackData)
{
	BeginBreachAudio();
	return ELR_NoInterrupt;
}

private function EventListenerReturn OnCivilianRescued(Object EventData, Object EventSource, XComGameState GameState, Name EventID, Object CallbackData)
{
	PlayAkEventDirect(CountUpAkEventName);
	return ELR_NoInterrupt;
}

function EnsureCombatAudioBegun()
{
	if (!bCombatAudioIsSet)
	{
		SetCombatAudio();
	}
}

public function SetPlanningAudio()
{
	local XComGameStateHistory History;
	local XComGameState_BattleData BattleData;
	local int PreviousEncounterID;
	local XComWorldData WorldData;
	local array<XComRoomVolume> PreviousEncounterVolumes;

	`log("Tactical sound manager beginning planning audio", , 'DevAudio');

	CurrentMusicPlaylist.SetEncounterPlaylist();

	// Handle loading a game saved during breach for a non-first encounter
	History = `XCOMHISTORY;
	BattleData = XComGameState_BattleData(History.GetSingleGameStateObjectForClass(class'XComGameState_BattleData'));

	if (BattleData.BreachingRoomListIndex > 0)
	{
		if (!bEncounterAmbienceInitialized)
		{
			PreviousEncounterID = BattleData.MapData.RoomIDs[BattleData.BreachingRoomListIndex - 1];
			WorldData = `XWORLD;
			WorldData.GetRoomVolumesByRoomID(PreviousEncounterID, PreviousEncounterVolumes);
			if (PreviousEncounterVolumes.Length > 0)
			{
				PlayEncounterVolumeAmbience(PreviousEncounterVolumes[0]);
			}

			bEncounterAmbienceInitialized = true;
		}
	}

	SetSwitch(MusicModeSwitch, 'Planning');
	SetPlanningState();
	CycleSetIfReady(CurrentMusicPlaylist.IsReadyForNextSet());
	bCombatAudioIsSet = false;
}

public function SetCombatAudio()
{
	`log("Tactical sound manager beginning combat audio", , 'DevAudio');

	PlayBreachStop();

	ClearEncounterAmbience();
	StartPostBreachAmbience();
	bEncounterAmbienceInitialized = true;

	SetSwitch(MusicModeSwitch, 'Combat');
	SetCombatState();
	if (bMusicHasBegun)
	{
		CurrentMusicPlaylist.PlaySelectedSetNoTransition(); // Music was stopped during breach
	}
	else
	{
		CurrentMusicPlaylist.SetEncounterPlaylist();
	}
	CycleSetIfReady(); // Handle starting Tactical in combat, such as when loading from a save
	CurrentMusicPlaylist.ReadyForNextSet();

	bCombatAudioIsSet = true;
}

public function ClearEncounterAmbience()
{
	local XComRoomVolume Encounter;

	if (StopSoundsOnObjectEvent != None)
	{
		foreach EncountersPlayingAmbience(Encounter)
		{
			Encounter.PlayAkEvent(StopSoundsOnObjectEvent);
		}
	}
	else
	{
		foreach EncountersPlayingAmbience(Encounter)
		{
			Encounter.StopSounds();
		}
	}

	foreach EncountersOccludingAudio(Encounter)
	{
		DeactivateAudioOcclusion(Encounter.AmbienceComponent);
	}

	EncountersPlayingAmbience.Length = 0;
	EncountersOccludingAudio.Length = 0;
}

public function StartPostBreachAmbience()
{
	local XComGameState_BattleData BattleData;
	local array<XComRoomVolume> EncounterVolumes;

	BattleData = XComGameState_BattleData(`XCOMHISTORY.GetSingleGameStateObjectForClass(class'XComGameState_BattleData'));
	`XWORLD.GetRoomVolumesByRoomID(BattleData.MapData.RoomIDs[BattleData.BreachingRoomListIndex], EncounterVolumes);
	if (EncounterVolumes.Length == 1)
	{
		PlayEncounterVolumeAmbience(EncounterVolumes[0]);
	}
	`if(`notdefined(FINAL_RELEASE))
	else if (EncounterVolumes.Length > 1)
	{
		`RedScreen("An encounter has multiple room volumes; audio data needs to be reorganized to prevent conflicts. @dprice");
	}
	`endif
}

public function PlayEncounterVolumeAmbience(XComRoomVolume EncounterRoomVolume)
{
	local bool bPlayedAtLeastOne;
	local AkEvent PostBreachEvent;

	if (EncounterRoomVolume.PostBreachAkEvents.Length > 0)
	{
		bPlayedAtLeastOne = false;
		foreach EncounterRoomVolume.PostBreachAkEvents(PostBreachEvent)
		{
			if (PostBreachEvent != None)
			{
				EncounterRoomVolume.PlayAkEvent(PostBreachEvent);
				bPlayedAtLeastOne = true;
			}
		}

		if (bPlayedAtLeastOne)
		{
			EncountersPlayingAmbience.AddItem(EncounterRoomVolume);
		}
	}

	SetAmbienceState(EncounterRoomVolume.AudioAmbienceState);

	if (!IsOcclusionActivated(EncounterRoomVolume))
	{
		ActivateAudioOcclusion(EncounterRoomVolume.AmbienceComponent);
		EncountersOccludingAudio.AddItem(EncounterRoomVolume);
	}
}

function bool IsOcclusionActivated(XComRoomVolume EncounterRoomVolume)
{
	return !EncounterRoomVolume.AmbienceComponent.ShouldOccludeEncompassedSounds();
}

public function SetAmbienceState(optional const name AudioAmbienceState = '')
{
	if (TacticalAmbienceStateGroup != '')
	{
		if (AudioAmbienceState != '')
		{
			if (AudioAmbienceState != CurrentTacticalAmbienceState)
			{
				SetState(TacticalAmbienceStateGroup, AudioAmbienceState);
				CurrentTacticalAmbienceState = AudioAmbienceState;
			}
		}
		else
		{
			SetState(TacticalAmbienceStateGroup, DefaultTacticalAmbienceState);
			CurrentTacticalAmbienceState = DefaultTacticalAmbienceState;
		}
	}
}

public function CycleSetIfReady(const bool bReady = true)
{
	if (bReady || !bMusicHasBegun)
	{
		HandleMusicOverride();
		if (!CurrentMusicPlaylist.OverrideIsSelected())
		{
			SelectRandomTacticalMusicSet();
		}
		CurrentMusicPlaylist.PlaySelectedSet();
		bMusicHasBegun = true;
	}
}

function EnsureCombatMusic()
{
	if (!bCombatAudioIsSet)
	{
		SetCombatAudio();
	}
}

function OverrideBreachAudio(const bool bCombat)
{
	if (bCombat)
	{
		SetSwitch(MusicModeSwitch, 'Combat');
		SetCombatState();
	}
	else
	{
		SetSwitch(MusicModeSwitch, 'Planning');
		SetPlanningState();
		CurrentMusicPlaylist.PlaySelectedSet();
	}
}

function PlayBreachStart()
{
	if (!bBreachStarted)
	{
		if (BreachStartEvent != none)
		{
			PlayAkEvent(BreachStartEvent);
		}
		bBreachStarted = true;
	}
}

function PlayBreachStop()
{
	local int Index;

	if (bBreachStarted)
	{
		if (BreachStopEvent != none)
		{
			PlayAkEvent(BreachStopEvent);
		}

		for (Index = 0; Index < BreachFinishedEvents.Length; ++Index)
		{
			PlayPersistentSoundEvent(BreachFinishedEvents[Index]);
		}

		bBreachStarted = false;
	}
}

function PlayBreachTransitionToTargeting()
{
	if (BreachTransitionToTargetingEvent != none)
	{
		PlayAkEvent(BreachTransitionToTargetingEvent);
	}
}

function PlayBreachSlomoOn()
{
	if (!bBreachSlomoActivated)
	{
		if (BreachSlomoOnEvent != none)
		{
			PlayAkEvent(BreachSlomoOnEvent);
		}
		bBreachSlomoActivated = true;
	}
}

function PlayBreachSlomoOff()
{
	if (bBreachSlomoActivated)
	{
		if (BreachSlomoOffEvent != none)
		{
			PlayAkEvent(BreachSlomoOffEvent);
		}
		bBreachSlomoActivated = false;
	}
}

public function SetPlanningState()
{
	if (CombatPlanningStateGroup != '')
	{
		SetState(CombatPlanningStateGroup, (PlanningState != '') ? PlanningState : 'None');
	}
}

public function SetCombatState()
{
	if (CombatPlanningStateGroup != '')
	{
		SetState(CombatPlanningStateGroup, (CombatState != '') ? CombatState : 'None');
	}
}

public function UnsetCombatPlanningState()
{
	if (CombatPlanningStateGroup != '')
	{
		SetState(CombatPlanningStateGroup, 'None');
	}
}

//------------------------------------------------------------------------------
// UI
//------------------------------------------------------------------------------
function PlayCountUpSound(optional Actor ActorToPlay)
{
	PlayAkEventDirect(CountUpAkEventName, ActorToPlay);
}

//------------------------------------------------------------------------------
// Utility
//------------------------------------------------------------------------------
public function string GetLoadedEventPath(coerce string EventName)
{
	local int idx;

	idx = SoundEvents.Find('strKey', EventName);
	if (idx != INDEX_NONE)
	{
		return PathName(SoundEvents[idx].TriggeredEvent);
	}
	return "";
}

public function string GetEventNameFromPath(string EventPath)
{
	local string EventName;

	EventName = EventPath;
	while (InStr(EventName, ".") != -1)
	{
		EventName = Split(EventName, ".", true);
	}

	return EventName;
}

// End HELIOS Issue #43

defaultproperties
{
	MusicModeSwitch=Tactical_Mode
	AnyUnitsPlacedSwitch=Tactical_AnyUnitsPlaced
	BreachReadySwitch=Tactical_BreachReady
}