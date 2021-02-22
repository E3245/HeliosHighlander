//---------------------------------------------------------------------------------------
//  FILE:    XComStrategySoundManager.uc
//  AUTHOR:  Mark Nauta  --  09/16/2014
//           
//---------------------------------------------------------------------------------------
//  Copyright (c) 2016 Firaxis Games, Inc. All rights reserved.
//---------------------------------------------------------------------------------------
class XComStrategySoundManager extends XComSoundManager config(GameData) dependson(X2StrategyGameRulesetDataStructures);

// Wwise support
var config array<string> WiseSoundBankNames; //Sound banks for general use. These are loaded as part of initialization.
var array<AKBank> WiseSoundBanks; //Holds references to the wise sound banks for later use

// HQ Music
var const config string PlayHQMusicEventPath;
var const config string StopHQMusicEventPath;
var const config string PlayHQAmbienceEventPath;
var const config string StopHQAmbienceEventPath;
var AkEvent PlayHQMusic;
var AkEvent StopHQMusic;
var AkEvent PlayHQAmbience;
var AkEvent StopHQAmbience;
var transient bool bSkipPlayHQMusicAfterTactical;

// Investigation HQ Music
var const config name StrategyMusicStateGroup;
var const config name Act1MusicState;
var const config name Act2MusicState;
var const config name Act3MusicState;

var private transient bool bLaunching;
var private transient bool bAmbientSoundsStarted;

struct AreaEvent
{
	var name AreaTag;
	var string AreaEventName;
};

var const config array<AreaEvent> AreaEvents;
var private transient name CurrentAreaTag;

var private transient StateObjectReference CurrentDistrictObjRef;
var private transient int CurrentDistrictCameraNum;

var private transient bool bBiographyScreenOpen;

//---------------------------------------------------------------------------------------
function Init()
{
	super.Init();	
	bUsePersistentSoundAkObject = true;
	bLaunching = false;
}

//---------------------------------------------------------------------------------------
event PreBeginPlay()
{
	local int idx;
	local XComContentManager ContentMgr;
	local object ThisObj;
	local X2EventManager EventMgr;

	super.PreBeginPlay();

	bLaunching = false;

	ContentMgr = `CONTENT;

	// Load Banks
	for(idx = 0; idx < WiseSoundBankNames.Length; idx++)
	{
		ContentMgr.RequestObjectAsync(WiseSoundBankNames[idx], self, OnWiseBankLoaded);
	}

	// Load Music Events
	if (PlayHQMusicEventPath != "")
	{
		ContentMgr.RequestObjectAsync(PlayHQMusicEventPath, self, OnPlayHQMusicAkEventLoaded);
	}
	if (StopHQMusicEventPath != "")
	{
		ContentMgr.RequestObjectAsync(StopHQMusicEventPath, self, OnStopHQMusicAkEventLoaded);
	}
	if (PlayHQAmbienceEventPath != "")
	{
		ContentMgr.RequestObjectAsync(PlayHQAmbienceEventPath, self, OnPlayHQAmbienceAkEventLoaded);
	}
	if (StopHQAmbienceEventPath != "")
	{
		ContentMgr.RequestObjectAsync(StopHQAmbienceEventPath, self, OnStopHQAmbienceAkEventLoaded);
	}

	SubscribeToOnCleanupWorld();

	ThisObj = self;
	EventMgr = `XEVENTMGR;
	EventMgr.RegisterForEvent(ThisObj, 'STRATEGY_InvestigationStageChanged_Submitted', OnInvestigationChanged, ELD_OnStateSubmitted);
	EventMgr.RegisterForEvent(ThisObj, 'STRATEGY_InvestigationStarted_Submitted', OnInvestigationChanged, ELD_OnStateSubmitted);
	EventMgr.RegisterForEvent(ThisObj, 'STRATEGY_InvestigationEnded_Immediate', OnInvestigationCompleted, ELD_Immediate);
	EventMgr.RegisterForEvent(ThisObj, 'STRATEGY_InvestigationOperationCompleted_Submitted', OnInvestigationOpEnded, ELD_OnStateSubmitted);
	EventMgr.RegisterForEvent(ThisObj, 'STRATEGY_InvestigationOperationFailed_Submitted', OnInvestigationOpEnded, ELD_OnStateSubmitted);
	EventMgr.RegisterForEvent(ThisObj, 'UIEvent_EnterBaseArea_Immediate', OnEnterBaseArea, ELD_Immediate);

	UpdateInvestigationStrategyMusic();
}

//---------------------------------------------------------------------------------------
simulated event OnCleanupWorld()
{
	Cleanup();

	super.OnCleanupWorld();
}

//---------------------------------------------------------------------------------------
event Destroyed()
{
	super.Destroyed();

	Cleanup();
}

//---------------------------------------------------------------------------------------
function Cleanup()
{	
	local int Index;
	local object ThisObj;
	local X2EventManager EventMgr;
	local XComContentManager ContentMgr;

	ContentMgr = `CONTENT;
	if (!bLaunching)
	{
		// The tactical sound manager will handle stopping ambience if the tactical game is launching
		StopAllAmbience();
		ContentMgr.UnCacheObject(StopHQMusicEventPath);
		ContentMgr.UnCacheObject(StopHQAmbienceEventPath);
	}

	for(Index = 0; Index < WiseSoundBankNames.Length; ++Index)
	{
		ContentMgr.UnCacheObject(WiseSoundBankNames[Index]);
	}

	ContentMgr.UnCacheObject(PlayHQMusicEventPath);
	ContentMgr.UnCacheObject(PlayHQAmbienceEventPath);

	ThisObj = self;
	EventMgr = `XEVENTMGR;
	EventMgr.UnRegisterFromEvent(ThisObj, 'STRATEGY_InvestigationStageChanged_Submitted');
	EventMgr.UnRegisterFromEvent(ThisObj, 'STRATEGY_InvestigationStarted_Submitted');
	EventMgr.UnRegisterFromEvent(ThisObj, 'STRATEGY_InvestigationEnded_Immediate');
	EventMgr.UnRegisterFromEvent(ThisObj, 'STRATEGY_InvestigationOperationCompleted_Submitted');
	EventMgr.UnRegisterFromEvent(ThisObj, 'STRATEGY_InvestigationOperationFailed_Submitted');
}

//---------------------------------------------------------------------------------------
function LoadUISounds()
{
	super.LoadUISounds();
	LoadUIScreenClassSounds(class'UIArmory');
	// HELIOS BEGIN
	LoadUIScreenClassSounds(`PRESBASE.Armory_MainMenu);
	// HELIOS END
	LoadUIScreenClassSounds(class'UIDIOStrategyPicker_CharacterUnlocks');
	LoadUIScreenClassSounds(class'UIDIOStrategyInvestigationChooserSimple');
	LoadUIScreenClassSounds(class'UIBlackMarket_Buy');
	LoadUIScreenClassSounds(class'UIDebriefScreen');
	LoadUIScreenClassSounds(class'UIDIOAssemblyScreen');
	LoadUIScreenClassSounds(class'UISpecOpsScreen');
	LoadUIScreenClassSounds(class'UIDIOTrainingScreen');
	LoadUIScreenClassSounds(class'UIDIOWorkerReviewScreen');
	// HELIOS BEGIN
	LoadUIScreenClassSounds(`PRESBASE.SquadSelect);
	LoadUIScreenClassSounds(`PRESBASE.UIDayTransitionScreen);
	LoadUIScreenClassSounds(`PRESBASE.SquadSelect);
	//HELIOS END
	LoadUIScreenClassSounds(class'UIDIOFieldTeamScreen');
	LoadUIScreenClassSounds(class'UIScavengerMarket');
	LoadUIScreenClassSounds(class'UICharacterUnlock');

	LoadAkEvent(class'UIDIOStrategyMap_AssignmentBubble'.default.AssignAgentSound);
	LoadAkEvent(class'UIDIOStrategyMap_AssignmentBubble'.default.UnassignAgentSound);
}

//---------------------------------------------------------------------------------------
function HandleLaunchMission()
{
	bLaunching = true;
}

//---------------------------------------------------------------------------------------
function StopAllAmbience()
{
	if (StopHQMusic != none)
	{
		PlayAkEvent(StopHQMusic);
	}
	if (StopHQAmbience != none)
	{
		PlayAkEvent(StopHQAmbience);
	}
}

//---------------------------------------------------------------------------------------
function OnWiseBankLoaded(object LoadedArchetype)
{
	local AkBank LoadedBank;

	LoadedBank = AkBank(LoadedArchetype);
	if (LoadedBank != none)
	{		
		WiseSoundBanks.AddItem(LoadedBank);
	}
}

//---------------------------------------------------------------------------------------
function OnPlayHQMusicAkEventLoaded(object LoadedObject)
{
	PlayHQMusic = AkEvent(LoadedObject);
	assert(PlayHQMusic != none);
}

//---------------------------------------------------------------------------------------
function OnStopHQMusicAkEventLoaded(object LoadedObject)
{
	StopHQMusic = AkEvent(LoadedObject);
	assert(StopHQMusic != none);
}

//---------------------------------------------------------------------------------------
function OnPlayHQAmbienceAkEventLoaded(object LoadedObject)
{
	PlayHQAmbience = AkEvent(LoadedObject);
	assert(PlayHQAmbience != none);
}

//---------------------------------------------------------------------------------------
function OnStopHQAmbienceAkEventLoaded(object LoadedObject)
{
	StopHQAmbience = AkEvent(LoadedObject);
	assert(StopHQAmbience != none);
}

//---------------------------------------------------------------------------------------
function PlayHQMusicEvent()
{
	if(!bSkipPlayHQMusicAfterTactical)
	{
		if (PlayHQMusic != none)
		{
			PlayAkEvent(PlayHQMusic);
		}
	}
	else
	{
		bSkipPlayHQMusicAfterTactical = false; // This flag is set in the state where X-Com returns from a mission. In this situation the HQ music is already playing
	}
}

//---------------------------------------------------------------------------------------
function StopHQMusicEvent()
{
	if(!bSkipPlayHQMusicAfterTactical)
	{
		if (StopHQMusic != none)
		{
			PlayAkEvent(StopHQMusic);
		}
	}
}

//---------------------------------------------------------------------------------------
function PlayHQAmbienceEvent()
{
	if (PlayHQAmbience != none)
	{
		PlayAkEvent(PlayHQAmbience);
	}
}

//---------------------------------------------------------------------------------------
function StopHQAmbienceEvent()
{
	if (StopHQAmbience != none)
	{
		PlayAkEvent(StopHQAmbience);
	}
}

//---------------------------------------------------------------------------------------
function StopDistrictAudio()
{
	UpdateDistrictAudio(none, -1);
}

//---------------------------------------------------------------------------------------
function UpdateDistrictAudio(XComGameState_DioCityDistrict District, int DistrictCameraNum)
{
	if (DistrictCameraNum != CurrentDistrictCameraNum)
	{
		if (CurrentDistrictCameraNum != -1)
		{
			StopDistrictAmbience(CurrentDistrictObjRef);
		}
		if (DistrictCameraNum != -1)
		{
			PlayDistrictAmbience(District);
		}

		if (District != none)
		{
			CurrentDistrictObjRef = District.GetReference();
		}
		else
		{
			CurrentDistrictObjRef.ObjectID = 0;
		}
		CurrentDistrictCameraNum = DistrictCameraNum;
	}
}

//---------------------------------------------------------------------------------------
private function PlayDistrictAmbience(XComGameState_DioCityDistrict District)
{
	PostDistrictAmbienceEvent(District, false);
}

//---------------------------------------------------------------------------------------
private function StopDistrictAmbience(StateObjectReference DistrictStateObjectRef)
{
	local XComGameState_DioCityDistrict District;

	District = XComGameState_DioCityDistrict(`XCOMHISTORY.GetGameStateForObjectID(DistrictStateObjectRef.ObjectID));
	PostDistrictAmbienceEvent(District, true);
}

//---------------------------------------------------------------------------------------
private function PostDistrictAmbienceEvent(XComGameState_DioCityDistrict District, bool bStop)
{
	local string AkEventNameOrPath;
	local int Index;

	if (District != none)
	{
		AkEventNameOrPath = District.GetMyTemplate().DistrictAmbienceEvent;
		if (AkEventNameOrPath != "")
		{
			Index = InStr(AkEventNameOrPath, ".");
			if (Index != INDEX_NONE)
			{
				AkEventNameOrPath = Mid(AkEventNameOrPath, Index + 1);
			}

			if (bStop)
			{
				AkEventNameOrPath $= "_Stop";
			}

			// District ambience events are in sound banks loaded when the Strategy sound manager is initialized,
			// so just play the event directly.
			PlayAkEventDirect(AkEventNameOrPath, self);
		}
	}
}

//---------------------------------------------------------------------------------------
function PlayAfterActionMusic()
{
	local XComGameStateHistory History;
	local XComGameState_BattleData BattleData;
	local XComGameState_HeadquartersXCom XComHQ;
	local XComGameState_Unit UnitState;
	local bool bCasualties, bVictory;
	local int idx;

	History = `XCOMHISTORY;
	BattleData = XComGameState_BattleData(History.GetSingleGameStateObjectForClass(class'XComGameState_BattleData', true));
	XComHQ = XComGameState_HeadquartersXCom(History.GetSingleGameStateObjectForClass(class'XComGameState_HeadquartersXCom'));
	bCasualties = false;

	if(BattleData != none)
	{
		bVictory = BattleData.bLocalPlayerWon;
	}
	else
	{
		bVictory = XComHQ.bSimCombatVictory;
	}

	if(!bVictory)
	{
		SetSwitch('StrategyScreen', 'PostMissionFlow_Fail');
	}
	else
	{
		for(idx = 0; idx < XComHQ.Squad.Length; idx++)
		{
			UnitState = XComGameState_Unit(History.GetGameStateForObjectID(XComHQ.Squad[idx].ObjectID));

			if(UnitState != none && UnitState.IsDead())
			{
				bCasualties = true;
				break;
			}
		}

		if(bCasualties)
		{
			SetSwitch('StrategyScreen', 'PostMissionFlow_Pass');
		}
		else
		{
			SetSwitch('StrategyScreen', 'PostMissionFlow_FlawlessVictory');
		}
	}
}

//---------------------------------------------------------------------------------------
private function EventListenerReturn OnInvestigationOpEnded(Object EventData, Object EventSource, XComGameState GameState, Name Event, Object CallbackData)
{
	local XComGameState_TacticalMusicPlaylist TacticalMusic;
	local XComGameState MusicGameState;
	local X2StrategyGameRuleset Rules;

	TacticalMusic = XComGameState_TacticalMusicPlaylist(`XCOMHISTORY.GetSingleGameStateObjectForClass(class'XComGameState_TacticalMusicPlaylist', true));
	if (TacticalMusic != none)
	{
		// Reset music selection
		MusicGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Reset music selection");
		TacticalMusic = XComGameState_TacticalMusicPlaylist(MusicGameState.ModifyStateObject(class'XComGameState_TacticalMusicPlaylist', TacticalMusic.ObjectID));
		TacticalMusic.ResetSelection();
		TacticalMusic.ResetEncounterTracking();

		// Submit game state
		Rules = `STRATEGYRULES;
		if (Rules != none)
		{
			if (!Rules.SubmitGameState(MusicGameState))
			{
				`Redscreen("Strategy sound manager failed to submit new music state.");
				LogAudio("Strategy sound manager failed to submit new music state.", true);
			}
		}
		else
		{
			`Redscreen("Strategy sound manager failed to get strategy rules.");
			LogAudio("Strategy sound manager failed to get strategy rules.", true);
		}
	}

	return ELR_NoInterrupt;
}

//---------------------------------------------------------------------------------------
private function EventListenerReturn OnInvestigationCompleted(Object EventData, Object EventSource, XComGameState GameState, Name Event, Object CallbackData)
{
	UpdateInvestigationStrategyMusic();
	return ELR_NoInterrupt;
}

//---------------------------------------------------------------------------------------
private function UpdateInvestigationStrategyMusic()
{
	local int Index;
	local int MusicAct;
	local XComGameState_Investigation Investigation;
	local XComGameStateHistory History;
	local XComGameState_HeadquartersDio DioHQ;

	MusicAct = 1;
	History = `XCOMHISTORY;
	DioHQ = `DioHQ;

	if (History != none && DioHQ != none)
	{
		// Iterate in reverse, since the highest act completed will most likely be at the end
		for (Index = DioHQ.CompletedInvestigations.Length - 1; Index >= 0; --Index)
		{
			Investigation = XComGameState_Investigation(History.GetGameStateForObjectID(DioHQ.CompletedInvestigations[Index].ObjectID));
			if (Investigation != none && Investigation.Act >= MusicAct)
			{
				MusicAct = Investigation.Act + 1;
				if (MusicAct >= 3)
				{
					MusicAct = 3;
					break;
				}
			}
		}
	}

	SetStrategyMusicAct(MusicAct);
}

//---------------------------------------------------------------------------------------
function SetStrategyMusicAct(const int ActNum)
{
	switch (ActNum)
	{
	case 1:
		SetState(StrategyMusicStateGroup, Act1MusicState);
		break;
	case 2:
		SetState(StrategyMusicStateGroup, Act2MusicState);
		break;
	case 3:
		SetState(StrategyMusicStateGroup, Act3MusicState);
		break;
	default:
		SetState(StrategyMusicStateGroup, 'None');
		break;
	}
}

//---------------------------------------------------------------------------------------
private function EventListenerReturn OnInvestigationChanged(Object EventData, Object EventSource, XComGameState GameState, Name Event, Object CallbackData)
{
	local XComGameState_Investigation Investigation;

	Investigation = XComGameState_Investigation(EventData);
	if (Investigation != none)
	{
		`log("Attempting to update investigation music data...", , 'DevAudio');
		UpdateInvestigationMusicData(Investigation);
	}
	return ELR_NoInterrupt;
}

//---------------------------------------------------------------------------------------
function UpdateInvestigationMusicData(optional XComGameState_Investigation Investigation)
{
	local XComGameState_HeadquartersDio DioHQ;
	local XComGameStateHistory History;
	local XComGameState GameState;
	local X2StrategyGameRuleset Rules;
	
	// Ensure investigation state is valid
	if (Investigation == none)
	{
		DioHQ = `DioHQ;
		if (DioHQ != none)
		{
			History = `XCOMHISTORY;
			Investigation = XComGameState_Investigation(History.GetGameStateForObjectID(DioHQ.CurrentInvestigation.ObjectID));
		}
		if (Investigation == none)
		{
			`Redscreen("Sound manager couldn't get game state for current investigation - @dprice");
			LogAudio("Sound manager couldn't get game state for current investigation.", true);
			return;
		}
	}
	
	// Ensure Strategy rules are valid
	Rules = `STRATEGYRULES;
	if (Rules == none)
	{
		`Redscreen("Strategy sound manager failed to get strategy rules.");
		LogAudio("Strategy sound manager failed to get strategy rules.", true);
		return;
	}

	// Create change game state and verify
	GameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Set investigation-based tactical music parameters");
	if (GameState == none)
	{
		`Redscreen("Strategy sound manager failed to create game state change container.");
		LogAudio("Strategy sound manager failed to create game state change container.");
		return;
	}

	// Update investigation music state
	self.static.UpdateInvestigationMusicDataStatic(GameState, Investigation, History); // History can be none here

	// Submit
	if (!Rules.SubmitGameState(GameState))
	{
		`Redscreen("Strategy sound manager failed to submit new music state.");
		LogAudio("Strategy sound manager failed to submit new music state.", true);
	}
}

//---------------------------------------------------------------------------------------
static function UpdateInvestigationMusicDataStatic(XComGameState GameState, XComGameState_Investigation Investigation, optional XComGameStateHistory History)
{
	local X2DioInvestigationTemplate InvestigationTemplate;
	local XComGameState_TacticalMusicPlaylist TacticalMusic;
	local int ComponentObjectIdx;
	local int NumGroupsNeeded;
	local int SpecificPlaylistIdx;

	if (GameState == none)
	{
		return;
	}

	if (History == none)
	{
		History = `XCOMHISTORY;
	}

	LogAudioStatic("Updating music state for investigation in stage \"" $ string(Investigation.Stage) $ "\".", true);

	// Get playlist
	TacticalMusic = XComGameState_TacticalMusicPlaylist(History.GetSingleGameStateObjectForClass(class'XComGameState_TacticalMusicPlaylist', true));
	if (TacticalMusic == none)
	{
		TacticalMusic = XComGameState_TacticalMusicPlaylist(GameState.CreateNewStateObject(class'XComGameState_TacticalMusicPlaylist'));
	}
	else
	{
		TacticalMusic = XComGameState_TacticalMusicPlaylist(GameState.ModifyStateObject(class'XComGameState_TacticalMusicPlaylist', TacticalMusic.ObjectID));
	}

	TacticalMusic.ResetSelection();
	TacticalMusic.ResetEncounterTracking();

	if (Investigation == none)
	{
		return;
	}

	TacticalMusic.SetTakedownPlaylist(Investigation);

	InvestigationTemplate = Investigation.GetMyTemplate();
	if (InvestigationTemplate == none)
	{
		return;
	}

	// Get playlist groups
	ComponentObjectIdx = 0;
	if (InvestigationNeedsCommonPlaylist(InvestigationTemplate, Investigation))
	{
		if (ComponentObjectIdx < TacticalMusic.ComponentObjectIds.Length)
		{
			ModifyMusicGroup(none, GameState, TacticalMusic.ComponentObjectIds[ComponentObjectIdx], Investigation.Stage);
		}
		else
		{
			CreateMusicGroup(none, GameState, TacticalMusic, Investigation.Stage);
		}
		++ComponentObjectIdx;
	}

	NumGroupsNeeded = GetNumTacticalMusicGroups(InvestigationTemplate, Investigation.Stage);
	for (SpecificPlaylistIdx = 0; SpecificPlaylistIdx < NumGroupsNeeded; ++SpecificPlaylistIdx)
	{
		if (ComponentObjectIdx < TacticalMusic.ComponentObjectIds.Length)
		{
			ModifyMusicGroup(InvestigationTemplate, GameState, TacticalMusic.ComponentObjectIds[ComponentObjectIdx], Investigation.Stage, SpecificPlaylistIdx);
		}
		else
		{
			CreateMusicGroup(InvestigationTemplate, GameState, TacticalMusic, Investigation.Stage, SpecificPlaylistIdx);
		}
		++ComponentObjectIdx;
	}

	while (ComponentObjectIdx < TacticalMusic.ComponentObjectIds.Length)
	{
		RemoveMusicGroup(History, GameState, TacticalMusic, TacticalMusic.ComponentObjectIds[TacticalMusic.ComponentObjectIds.Length - 1]);
	}
}

//---------------------------------------------------------------------------------------
static private function int GetNumTacticalMusicGroups(X2DioInvestigationTemplate InvestigationTemplate, EInvestigationStage InvestigationStage)
{
	if (InvestigationStage == eStage_Takedown && InvestigationTemplate.TakedownMusic.EncounterPlaylists.Length > 0)
	{
		return InvestigationTemplate.TakedownMusic.EncounterPlaylists.Length;
	}
	return (InvestigationTemplate.MusicStartEventPath != "" && InvestigationTemplate.MusicSwitchGroup != "" && InvestigationTemplate.MusicPlaylistSets.Length > 0) ? 1 : 0;
}

//---------------------------------------------------------------------------------------
static private function bool InvestigationHasMusicPlaylistSets(X2DioInvestigationTemplate InvestigationTemplate, EInvestigationStage InvestigationStage)
{
	if (InvestigationStage == eStage_Takedown)
	{
		return InvestigationTemplate.TakedownMusic.EncounterPlaylists.Length > 0;
	}
	else
	{
		return InvestigationTemplate.MusicPlaylistSets.Length > 0;
	}
}

//---------------------------------------------------------------------------------------
static private function bool InvestigationNeedsCommonPlaylist(X2DioInvestigationTemplate InvestigationTemplate, XComGameState_Investigation Investigation)
{
	return Investigation == none || Investigation.Stage != eStage_Takedown || InvestigationTemplate == none || InvestigationTemplate.TakedownMusic.bIncludeCommonPlaylist;
}


//---------------------------------------------------------------------------------------
static private function XComGameState_TacticalMusicGroup CreateMusicGroup(
	X2DioInvestigationTemplate InvestigationTemplate,
	XComGameState GameState,
	XComGameState_TacticalMusicPlaylist TacticalMusic,
	EInvestigationStage InvestigationStage,
	optional const int EncounterPlaylistIdx = INDEX_NONE)
{
	local XComGameState_TacticalMusicGroup TacticalMusicGroup;

	`assert(GameState != none);
	`assert(TacticalMusic != none);

	TacticalMusicGroup = XComGameState_TacticalMusicGroup(GameState.CreateNewStateObject(class'XComGameState_TacticalMusicGroup', InvestigationTemplate));
	TacticalMusicGroup.SetInvestigationMusicData(InvestigationTemplate, InvestigationStage, EncounterPlaylistIdx);
	TacticalMusic.AddComponentObject(TacticalMusicGroup);

	if (InvestigationTemplate != none)
	{
		LogAudioStatic("Created music group game state with start event \"" $ TacticalMusicGroup.StartEventPath $
			"\" for investigation \"" $ InvestigationTemplate.DisplayName $ "\" in stage \"" $ string(InvestigationStage) $ "\".", true);
	}
	else
	{
		LogAudioStatic("Created common music group game state for investigation in stage \"" $ string(InvestigationStage) $ "\".", true);
	}

	return TacticalMusicGroup;
}

//---------------------------------------------------------------------------------------
static private function XComGameState_TacticalMusicGroup ModifyMusicGroup(
	X2DioInvestigationTemplate InvestigationTemplate,
	XComGameState GameState,
	int TacticalMusicGroupID,
	EInvestigationStage InvestigationStage,
	optional const int EncounterPlaylistIdx = INDEX_NONE)
{
	local XComGameState_TacticalMusicGroup TacticalMusicGroup;

	`assert(GameState != none);

	TacticalMusicGroup = XComGameState_TacticalMusicGroup(GameState.ModifyStateObject(class'XComGameState_TacticalMusicGroup', TacticalMusicGroupID));
	if (TacticalMusicGroup == none)
	{
		`Redscreen("XComStrategySoundManager.ModifyMusicGroup called with invalid Tactical Music Group object ID.");
		return TacticalMusicGroup;
	}

	if (InvestigationTemplate == none)
	{
		TacticalMusicGroup.ResetInvestigationMusicData();
	}
	else
	{
		TacticalMusicGroup.SetInvestigationMusicData(InvestigationTemplate, InvestigationStage, EncounterPlaylistIdx);
	}

	LogAudioStatic("Modified music group game state with start event \"" $ TacticalMusicGroup.StartEventPath $
		"\" for investigation \"" $ InvestigationTemplate.DisplayName $ "\" in stage \"" $ string(InvestigationStage) $ "\".", true);

	return TacticalMusicGroup;
}

//---------------------------------------------------------------------------------------
static private function RemoveMusicGroup(
	XComGameStateHistory History,
	XComGameState GameState,
	XComGameState_TacticalMusicPlaylist TacticalMusic,
	int TacticalMusicGroupID)
{
	local XComGameState_TacticalMusicGroup TacticalMusicGroup;

	`assert(History != none);
	`assert(GameState != none);
	`assert(TacticalMusic != none);

	TacticalMusicGroup = XComGameState_TacticalMusicGroup(History.GetGameStateForObjectID(TacticalMusicGroupID));
	if (TacticalMusicGroup == none)
	{
		`Redscreen("XComStrategySoundManager.RemoveMusicGroup called with invalid Tactical Music Group object ID.");
	}
	else
	{
		LogAudioStatic("Removing music group game state with start event \"" $ TacticalMusicGroup.StartEventPath $ "\".", true);

		TacticalMusic.RemoveComponentObject(TacticalMusicGroup);
		GameState.RemoveStateObject(TacticalMusicGroup.ObjectID);
	}
}

//---------------------------------------------------------------------------------------
function EventListenerReturn OnEnterBaseArea(Object EventData, Object EventSource, XComGameState GameState, Name Event, Object CallbackData)
{
	local XComEventObject_EnterHeadquartersArea Data;

	Data = XComEventObject_EnterHeadquartersArea(EventData);
	if (Data != none)
	{
		PlayAreaEvent(Data.AreaTag);
	}
	else
	{
		PlayAreaEvent(class'XComStrategyPresentationLayer'.const.HQOverviewAreaTag);
		StartAllAmbientSounds();
	}

	return ELR_NoInterrupt;
}

//---------------------------------------------------------------------------------------
protected function StartAllAmbientSounds()
{
	if (bAmbientSoundsStarted)
	{
		return;
	}

	super.StartAllAmbientSounds();
	bAmbientSoundsStarted = true;
}

//---------------------------------------------------------------------------------------
function PlayAreaEvent(const name AreaTag)
{
	local int Idx;

	if (AreaTag != CurrentAreaTag)
	{
		Idx = AreaEvents.Find('AreaTag', AreaTag);
		if (Idx != INDEX_NONE)
		{
			PlayAkEventDirect(AreaEvents[Idx].AreaEventName);
			CurrentAreaTag = AreaTag;
		}
	}
}

//---------------------------------------------------------------------------------------
function BiographyScreenOpened()
{
	bBiographyScreenOpen = true;
}

//---------------------------------------------------------------------------------------
function BiographyScreenClosed()
{
	bBiographyScreenOpen = false;
}

//---------------------------------------------------------------------------------------
function bool IsBiographyScreenOpen()
{
	return bBiographyScreenOpen;
}

//---------------------------------------------------------------------------------------
DefaultProperties
{
	CurrentDistrictCameraNum=-1
}