// XCom Sound manager
// 
// Manages common sound and music related tasks for XCOM

class XComSoundManager extends XComSoundManagerNativeBase config(GameData);

struct native AkEventMapping
{
	var string strKey;
	var AkEvent TriggeredEvent;
};

// Sound Mappings
var config array<string> SoundEventPaths;
var config array<AkEventMapping> SoundEvents;

struct AmbientChannel
{
	var SoundCue Cue;
	var AudioComponent Component;
	var bool bHasPlayRequestPending;
};

// Map PostProcessEffect name to "on enable" and "on disable" AkEvent paths
struct PPEffectAkEventInfo
{
	var string EffectName;
	var string AkEventOnEnable;
	var string AkEventOnDisable;
	var bool bRetriggerable; // If true, enable event will still play when effect is active
};

var const config array<PPEffectAkEventInfo> PPEffectAkEventPaths;
var array<AkEventMapping> PPEffectSoundEvents; // Separate SoundEvents array for PPEffects because there will be duplicate AkEvent paths for PPEffects
var transient array<string> ActiveEffectNames; // This is to prevent multiple event triggers

// For timing UI sounds with visualization e.g. AI ability sounds
enum VisAudioTiming
{
	eVisAudioTiming_OnFlyover,			// Timed to X2Action_PlaySoundAndFlyOver's "Executing" state
	eVisAudioTiming_OnBlockStarted,		// Timed to ELD_OnVisualizationBlockStarted
	eVisAudioTiming_OnBlockCompleted	// Timed to ELD_OnVisualizationBlockCompleted
};

// Used to play AkEvents timed with visualization
struct VisAkEventInfo
{
	var name EventAlias;
	var AkEvent VisAkEvent;
	var VisAudioTiming Timing;
	var name VisAkEventName;
};

// Pairs a name with an AkEvent
struct AliasedAkEvent
{
	var name EventAlias;
	var AkEvent AliasedEvent;
	var name AliasedEventName;
};

var private transient array<VisAkEventInfo>			PendingAbilities;			// Activated abilities waiting for flyovers to trigger their sounds
var private transient array<AliasedAkEvent>			FlyoverQueue;				// For timing sounds with UI flyovers
var private transient array<name>					FlyoversPosted;				// Prevents flyover sounds from doubling up
var private transient array<EventListenerDeferral>	AbilityDeferralsActive;		// The deferrals at which this is listening to the 'AbilityActivated' game event
var private transient bool							bRegisteredFlyoverCleanup;	// Whether flyover queue cleanup function is registered for 'AbilityActivated' game event
var private transient bool							bFocusStateInitialized;		// Whether GameHasFocus state has been initialized

var const config string StopSoundsOnObjectEventPath;
var privatewrite transient AkEvent StopSoundsOnObjectEvent;

var const config name COPsStateGroup;
var const config name COPsStateOn;
var const config name COPsStateOff;

var const config float BinkMixVolumeDB; // Bink audio volume in decibels

var const config array<name> PermaloadBanks; // Sound banks to be loaded AT ALL TIMES. Do not abuse.

struct AkEventPlayOnLoadData
{
	var string AkEventName;
	var Actor AkEventActor;
};

var private transient array<AkEventPlayOnLoadData> PlayOnLoadQueue;

var const config array<CinematicAkEvent> CinematicEventOverrides;

var private transient UIScreen ActiveMouseoverScreen;

//------------------------------------------------------------------------------
// AmbientChannel Management
//------------------------------------------------------------------------------
protected function SetAmbientCue(out AmbientChannel Ambience, SoundCue NewCue)
{
	if (NewCue != Ambience.Cue)
	{
		if (Ambience.Component != none && Ambience.Component.IsPlaying())
		{
			Ambience.Component.FadeOut(0.5f, 0.0f);
			Ambience.Component = none;
		}

		Ambience.Cue = NewCue;
		Ambience.Component = CreateAudioComponent(NewCue, false, true);

		if (Ambience.bHasPlayRequestPending)
			StartAmbience(Ambience);
	}
}

//---------------------------------------------------------------------------------------
protected function StartAmbience(out AmbientChannel Ambience, optional float FadeInTime=0.5f)
{
	if (Ambience.Cue == none)
	{
		Ambience.bHasPlayRequestPending = true;
		return;
	}

	if (Ambience.Cue != none && Ambience.Component != none && ( !Ambience.Component.IsPlaying() || Ambience.Component.IsFadingOut() ) )
	{
		Ambience.Component.bIsMusic = (Ambience.Cue.SoundClass == 'Music'); // Make sure the music flag is correct
		Ambience.Component.FadeIn(FadeInTime, 1.0f);
	}
}

//---------------------------------------------------------------------------------------
protected function StopAmbience(out AmbientChannel Ambience, optional float FadeOutTime=1.0f)
{
	Ambience.bHasPlayRequestPending = false;

	if (Ambience.Component != none && Ambience.Component.IsPlaying())
	{
		Ambience.Component.FadeOut(FadeOutTime, 0.0f);
	}
}

//------------------------------------------------------------------------------
// Music management
//------------------------------------------------------------------------------
function PlayMusic( SoundCue NewMusicCue, optional float FadeInTime=0.0f )
{
	local MusicTrackStruct MusicTrack;

	MusicTrack.TheSoundCue = NewMusicCue;
	MusicTrack.FadeInTime = FadeInTime;
	MusicTrack.FadeOutTime = 1.0f;
	MusicTrack.FadeInVolumeLevel = 1.0f;
	MusicTrack.bAutoPlay = true;

	`log("XComSoundManager.PlayMusic: Starting" @ NewMusicCue,,'DevSound');

	WorldInfo.UpdateMusicTrack(MusicTrack);
}

//---------------------------------------------------------------------------------------
function StopMusic(optional float FadeOutTime=1.0f)
{
	local MusicTrackStruct MusicTrack;

	`log("XComSoundManager.StopMusic: Stopping" @ WorldInfo.CurrentMusicTrack.TheSoundCue,,'DevSound');

	MusicTrack.TheSoundCue = none;

	WorldInfo.CurrentMusicTrack.FadeOutTime = FadeOutTime;
	WorldInfo.UpdateMusicTrack(MusicTrack);
}

//---------------------------------------------------------------------------------------
// Basic play functions
//---------------------------------------------------------------------------------------
function PlaySoundEvent(string strKey)
{
	local int Index;

	Index = SoundEvents.Find('strKey', strKey);

	if(Index != INDEX_NONE)
	{
		WorldInfo.PlayAkEvent(SoundEvents[Index].TriggeredEvent);
	}
}

//---------------------------------------------------------------------------------------
function PlayPersistentSoundEvent(string strKey)
{
	local int Index;

	Index = SoundEvents.Find('strKey', strKey);

	if(Index != INDEX_NONE)
	{
		// Both Tactical and Strategy XCom sound managers have bUsePersistentSoundAkObject set to true,
		// so this will normally play on the Persistent Soundtrack object.
		PlayAkEvent(SoundEvents[Index].TriggeredEvent);
	}
}

//---------------------------------------------------------------------------------------
function bool PlayLoadedAkEvent(string AkEventNameOrPath, optional Actor actor)
{
	local int Index;

	Index = InStr(AkEventNameOrPath, ".");
	if (Index != INDEX_NONE)
	{
		AkEventNameOrPath = Mid(AkEventNameOrPath, Index + 1);
	}

	Index = SoundEvents.Find('strKey', AkEventNameOrPath);

	if (Index != INDEX_NONE)
	{
		if (actor == none)
		{
			actor = self;
		}
		actor.PlayAkEvent(SoundEvents[Index].TriggeredEvent);
		return true;
	}

	return false;
}

//---------------------------------------------------------------------------------------
function int PlayAkEventByName(name AkEventName, optional Actor actor)
{
	local string AkEventNameStr;

	AkEventNameStr = string(AkEventName);
	return PlayAkEventDirect(AkEventNameStr, actor);
}

//---------------------------------------------------------------------------------------
// Visualization audio
//---------------------------------------------------------------------------------------
function PlayQueuedFlyoverEventFromContext(XComGameStateContext Context)
{
	//`log("Ability Audio: PlayQueuedFlyoverEventFromContext called", , 'DevAudio');
	if (FlyoverQueue.Length > 0 && Context != none)
	{
		PlayQueuedFlyoverEvent(GetAliasFromContext(Context));
	}
}

//---------------------------------------------------------------------------------------
private function name GetAliasFromContext(XComGameStateContext Context)
{
	local XComGameStateContext_Ability AbilityContext;

	//`log("Ability Audio: GetAliasFromContext called", , 'DevAudio');
	AbilityContext = XComGameStateContext_Ability(Context);
	if (AbilityContext != none)
	{
		return AbilityContext.InputContext.AbilityTemplateName;
	}
	return '';
}

//---------------------------------------------------------------------------------------
function PlayQueuedFlyoverEvent(name EventAlias)
{
	local int Index;
	local string AliasedEventNameString;

	//`log("Ability Audio: PlayQueuedFlyoverEvent called with EventAlias \"" $ string(EventAlias) $ "\"", , 'DevAudio');
	Index = FlyoverQueue.Find('EventAlias', EventAlias);
	if (Index != INDEX_NONE)
	{
		if (FlyoverQueue[Index].AliasedEvent != none)
		{
			PlayAkEvent(FlyoverQueue[Index].AliasedEvent);
			FlyoversPosted.AddItem(EventAlias);
		}
		else if (FlyoverQueue[Index].AliasedEventName != '')
		{
			AliasedEventNameString = string(FlyoverQueue[Index].AliasedEventName);
			PlayAkEventDirect(AliasedEventNameString);
			FlyoversPosted.AddItem(EventAlias);
		}
		FlyoverQueue.Remove(Index, 1);
	}
}

//---------------------------------------------------------------------------------------
function PlayDeferredAbilitySound(Name TemplateName, AkEvent AbilityAkEvent, VisAudioTiming Timing, optional string AbilityAkEventName = "")
{
	local EventListenerDeferral Deferral;
	local int DeferralIndex;

	//`log("Ability Audio: PlayDeferredAbilitySound called with TemplateName \"" $ string(TemplateName) $ "\"", , 'DevAudio');
	if (TemplateName == '' || (AbilityAkEvent == none && AbilityAkEventName == ""))
	{
		return;
	}

	PushAbilityVis(TemplateName, AbilityAkEvent, Timing, AbilityAkEventName);

	Deferral = (Timing == eVisAudioTiming_OnBlockCompleted) ? ELD_OnVisualizationBlockCompleted : ELD_OnVisualizationBlockStarted;
	DeferralIndex = AbilityDeferralsActive.Find(Deferral);

	if (DeferralIndex == INDEX_NONE)
	{
		AbilityDeferralsActive.AddItem(Deferral);
	}

	if (!bRegisteredFlyoverCleanup && Timing == eVisAudioTiming_OnFlyover)
	{
		bRegisteredFlyoverCleanup = true;
	}
}

//---------------------------------------------------------------------------------------
private function EventListenerReturn OnAbilityActivated(Object EventData, Object EventSource, XComGameState GameState, Name Event, Object CallbackData)
{
	return OnAbilityActivated_CheckTiming(EventData, EventSource, GameState, Event, CallbackData, ELD_OnVisualizationBlockStarted);
}

//---------------------------------------------------------------------------------------
private function EventListenerReturn OnAbilityActivated_CheckTiming(Object EventData, Object EventSource, XComGameState GameState, Name Event, Object CallbackData, EventListenerDeferral Deferral)
{
	local XComGameStateContext_Ability AbilityContext;
	local AkEvent AbilityAkEvent;
	local VisAudioTiming Timing;
	local name AbilityAkEventName;
	local int Index;

	if (PendingAbilities.Length > 0)
	{
		//`log("Ability Audio: OnAbilityActivated called", , 'DevAudio');
		AbilityContext = XComGameStateContext_Ability(GameState.GetContext());
		if (AbilityContext != none)
		{
			if (PeekAbilityVisTiming(AbilityContext.InputContext.AbilityTemplateName, Timing, Index))
			{
				if ((Deferral == ELD_OnVisualizationBlockCompleted) == (Timing == eVisAudioTiming_OnBlockCompleted)) // XNOR results of two comparisons
				{
					if (PopAbilityVis(AbilityContext.InputContext.AbilityTemplateName, AbilityAkEvent, Timing, AbilityAkEventName, Index))
					{
						PlayDeferredAbilitySoundInternal(AbilityContext.InputContext.AbilityTemplateName, AbilityAkEvent, Timing, AbilityAkEventName, Deferral);
						CheckAbilityGameEvent();
					}
				}
			}
		}
	}

	return ELR_NoInterrupt;
}

//---------------------------------------------------------------------------------------
private function PlayDeferredAbilitySoundInternal(name TemplateName, AkEvent ConfirmSound, VisAudioTiming Timing, name ConfirmSoundName, EventListenerDeferral Deferral)
{
	local AliasedAkEvent FlyoverSound;
	local string ConfirmSoundNameString;

	//`log("Ability Audio: PlayDeferredAbilitySoundInternal called with TemplateName \"" $ string(TemplateName) $ "\"", , 'DevAudio');
	if (bRegisteredFlyoverCleanup && Timing == eVisAudioTiming_OnFlyover && Deferral == ELD_OnVisualizationBlockStarted && TemplateName != '')
	{
		FlyoverSound.EventAlias = TemplateName;
		FlyoverSound.AliasedEvent = ConfirmSound;
		FlyoverSound.AliasedEventName = ConfirmSoundName;
		FlyoverQueue.AddItem(FlyoverSound);
	}
	else if (ConfirmSound != none)
	{
		PlayAkEvent(ConfirmSound);
	}
	else if (ConfirmSoundName != '')
	{
		ConfirmSoundNameString = string(ConfirmSoundName);
		PlayAkEventDirect(ConfirmSoundNameString);
	}
}

//---------------------------------------------------------------------------------------
private function EventListenerReturn OnAbilityVisComplete(Object EventData, Object EventSource, XComGameState GameState, Name Event, Object CallbackData)
{
	local XComGameStateContext_Ability AbilityContext;
	local int Index;

	OnAbilityActivated_CheckTiming(EventData, EventSource, GameState, Event, CallbackData, ELD_OnVisualizationBlockCompleted);

	if (FlyoversPosted.Length > 0 || FlyoverQueue.Length > 0)
	{
		//`log("Ability Audio: OnAbilityVisComplete called", , 'DevAudio');
		AbilityContext = XComGameStateContext_Ability(GameState.GetContext());
		if (AbilityContext != none)
		{
			Index = FlyoversPosted.Find(AbilityContext.InputContext.AbilityTemplateName);
			if (Index != INDEX_NONE)
			{
				FlyoversPosted.Remove(Index, 1);
			}
			else
			{
				Index = FlyoverQueue.Find('EventAlias', AbilityContext.InputContext.AbilityTemplateName);
				if (Index != INDEX_NONE)
				{
					FlyoverQueue.Remove(Index, 1);
				}
			}

			CheckAbilityGameEvent();
		}
	}

	return ELR_NoInterrupt;
}

//---------------------------------------------------------------------------------------
private function PushAbilityVis(Name TemplateName, AkEvent AbilityAkEvent, VisAudioTiming Timing, const out string AbilityAkEventName)
{
	local VisAkEventInfo PendingAbility;

	//`log("Ability Audio: PushAbilityVis called with TemplateName \"" $ string(TemplateName) $ "\"", , 'DevAudio');
	if (TemplateName != '' && (AbilityAkEvent != none || AbilityAkEventName != ""))
	{
		PendingAbility.EventAlias = TemplateName;
		PendingAbility.VisAkEvent = AbilityAkEvent;
		PendingAbility.Timing = Timing;
		PendingAbility.VisAkEventName = name(AbilityAkEventName);
		PendingAbilities.AddItem(PendingAbility);
	}
}

//---------------------------------------------------------------------------------------
private function bool PopAbilityVis(Name TemplateName, out AkEvent AbilityAkEvent, out VisAudioTiming Timing, out name AbilityAkEventName, optional int Index = INDEX_NONE)
{
	//`log("Ability Audio: PopAbilityVis called with TemplateName \"" $ string(TemplateName) $ "\"", , 'DevAudio');
	if (Index == INDEX_NONE)
	{
		Index = PendingAbilities.Find('EventAlias', TemplateName);
	}
	else if (Index >= PendingAbilities.Length)
	{
		return false;
	}

	if (Index != INDEX_NONE)
	{
		AbilityAkEvent = PendingAbilities[Index].VisAkEvent;
		Timing = PendingAbilities[Index].Timing;
		AbilityAkEventName = PendingAbilities[Index].VisAkEventName;
		PendingAbilities.Remove(Index, 1);
		return true;
	}
	return false;
}

//---------------------------------------------------------------------------------------
private function bool PeekAbilityVisTiming(Name TemplateName, out VisAudioTiming Timing, out int Index)
{
	//`log("Ability Audio: PeekAbilityVisTiming called with TemplateName \"" $ string(TemplateName) $ "\"", , 'DevAudio');
	Index = PendingAbilities.Find('EventAlias', TemplateName);
	if (Index != INDEX_NONE)
	{
		Timing = PendingAbilities[Index].Timing;
		return true;
	}
	return false;
}

//---------------------------------------------------------------------------------------
private function CheckAbilityGameEvent()
{
	local EventListenerDeferral ActiveDeferral;

	//`log("Ability Audio: CheckAbilityGameEvent called", , 'DevAudio');
	if (PendingAbilities.Length == 0 && FlyoverQueue.Length == 0 && FlyoversPosted.Length == 0)
	{
		foreach AbilityDeferralsActive(ActiveDeferral)
		{
			if (ActiveDeferral == ELD_OnVisualizationBlockCompleted)
			{
				bRegisteredFlyoverCleanup = false;
			}
		}
		if (bRegisteredFlyoverCleanup)
		{
			bRegisteredFlyoverCleanup = false;
		}
		AbilityDeferralsActive.Length = 0;
	}
}

//---------------------------------------------------------------------------------------
function HandleAbilityTriggered(XComGameState_Ability AbilityState, Object EventSource)
{
	local XComGameState_Unit UnitState;
	local XComGameStateHistory History;
	local XComGameState_Player PlayerState;

	if (AbilityState == none)
	{
		return;
	}

	UnitState = XComGameState_Unit(EventSource);
	if (UnitState != none)
	{
		History = `XCOMHISTORY;
		PlayerState = XComGameState_Player(History.GetGameStateForObjectID(UnitState.ControllingPlayer.ObjectID));
		if (PlayerState != none)
		{
			if (PlayerState.IsAIPlayer())
			{
				AbilityState.GetMyTemplate().PlayAIAbilityConfirmSoundDeferred();
			}
			else
			{
				AbilityState.GetMyTemplate().PlayAbilityConfirmSound();
			}
		}
	}
}

//---------------------------------------------------------------------------------------
// Initialization and loading
//---------------------------------------------------------------------------------------
function Init()
{
	local int idx;
	local XComContentManager ContentMgr;
	local X2EventManager EventMgr;
	local Object ThisObj;

	ExitCOPsState();
	InitializeFocusChangeMute();

	ContentMgr = `CONTENT;

	// Load Events
	for( idx = 0; idx < SoundEventPaths.Length; idx++ )
	{
		ContentMgr.RequestObjectAsync(SoundEventPaths[idx], self, OnAkEventMappingLoaded);
	}

	// Load PostProcessEffect Events
	for( idx = 0; idx < PPEffectAkEventPaths.Length; idx++ )
	{
		ContentMgr.RequestObjectAsync(PPEffectAkEventPaths[idx].AkEventOnEnable, self, OnPPEffectAkEventMappingLoaded);
		ContentMgr.RequestObjectAsync(PPEffectAkEventPaths[idx].AkEventOnDisable, self, OnPPEffectAkEventMappingLoaded);
	}

	ContentMgr.RequestObjectAsync(StopSoundsOnObjectEventPath, self, OnStopGameObjectSoundsLoaded);

	ThisObj = self;
	EventMgr = `XEVENTMGR;		
	EventMgr.RegisterForEvent(ThisObj, 'AbilityActivated', OnAbilityActivated, ELD_OnVisualizationBlockStarted, , , false);
	EventMgr.RegisterForEvent(ThisObj, 'AbilityActivated', OnAbilityVisComplete, ELD_OnVisualizationBlockCompleted, , , false);
}

//---------------------------------------------------------------------------------------
function OnStopGameObjectSoundsLoaded(object LoadedObject)
{
	StopSoundsOnObjectEvent = AkEvent(LoadedObject);
	assert(StopSoundsOnObjectEvent != none);
}

//---------------------------------------------------------------------------------------
function OnAkEventMappingLoaded(object LoadedArchetype)
{
	local AkEvent TempEvent;
	local AkEventMapping EventMapping;

	TempEvent = AkEvent(LoadedArchetype);
	if( TempEvent != none )
	{
		EventMapping.strKey = string(TempEvent.name);
		EventMapping.TriggeredEvent = TempEvent;

		SoundEvents.AddItem(EventMapping);
	}
}

//---------------------------------------------------------------------------------------
function OnPPEffectAkEventMappingLoaded(object LoadedArchetype)
{
	local AkEvent TempEvent;
	local string TempEventPath;
	local AkEventMapping EventMapping;

	TempEvent = AkEvent(LoadedArchetype);
	if( TempEvent != none )
	{
		TempEventPath = PathName(TempEvent);
		if( PPEffectSoundEvents.Find('strKey', TempEventPath) == INDEX_NONE )
		{
			EventMapping.strKey = TempEventPath;
			EventMapping.TriggeredEvent = TempEvent;

			PPEffectSoundEvents.AddItem(EventMapping);
		}
	}
}

//---------------------------------------------------------------------------------------
function LoadAkEvent(string AkEventPath, optional bool bPlayOnLoad, optional Actor ActorToPlaySound)
{
	local AkEventPlayOnLoadData PlayOnLoadData;
	local bool bNeedsLoad;

	if (AkEventPath != "")
	{
		bNeedsLoad = true;
		if (bPlayOnLoad)
		{
			PlayOnLoadData.AkEventName = Split(AkEventPath, ".", true);
			PlayOnLoadData.AkEventActor = (ActorToPlaySound != none) ? ActorToPlaySound : self;
			if (!PlayLoadedAkEvent(PlayOnLoadData.AkEventName, PlayOnLoadData.AkEventActor))
			{
				PlayOnLoadQueue.AddItem(PlayOnLoadData);
			}
			else
			{
				bNeedsLoad = false;
			}
		}

		if (bNeedsLoad)
		{
			`CONTENT.RequestObjectAsync(AkEventPath, self, OnAkEventLoaded);
		}
	}
}

//---------------------------------------------------------------------------------------
function OnAkEventLoaded(object LoadedObject)
{
	local AkEvent LoadedAkEvent;
	local AkEventMapping EventMapping;
	local int Index;

	LoadedAkEvent = AkEvent(LoadedObject);
	if (LoadedAkEvent != none)
	{
		EventMapping.strKey = string(LoadedAkEvent.name);
		EventMapping.TriggeredEvent = LoadedAkEvent;

		SoundEvents.AddItem(EventMapping);

		Index = PlayOnLoadQueue.Find('AkEventName', EventMapping.strKey);
		if (Index != INDEX_NONE)
		{
			PlayLoadedAkEvent(PlayOnLoadQueue[Index].AkEventName, PlayOnLoadQueue[Index].AkEventActor);
			PlayOnLoadQueue.Remove(Index, 1);
		}
	}
}

//---------------------------------------------------------------------------------------
// Which game mode (Tactical, Strategy, Shell) a particular UIScreen class belongs to is not known until an instance of it
// is spawned, so in order to load all UI sounds for a game mode when its UI system is loaded, the relevant classes must
// be hand coded in the appropriate sound manager. //dio/audiodev/WwiseProjectDIO/Tools/BatchFiles/UpdateLoadUISounds.bat
// can be used (with Python installed) to add UI classes that have sounds specified and aren't loaded in any sound managers
// to this function. The new calls to LoadUIScreenClassSounds can then be moved to the appropriate sound manager.
function LoadUISounds()
{
	LoadUIScreenClassSounds(class'UIMissionSummary');
	LoadUIScreenClassSounds(class'UILoadGame');
	LoadUIScreenClassSounds(class'UIInputDialogue');
	LoadUIScreenClassSounds(class'UISaveGame');
	LoadUIScreenClassSounds(class'UIKeybindingsPCScreen');
	LoadUIScreenClassSounds(class'UITutorialBox');
	LoadUIScreenClassSounds(class'UIShellDifficulty');
	LoadUIScreenClassSounds(class'UICredits');
	LoadUIScreenClassSounds(class'UIScreen');
	LoadUIScreenClassSounds(class'UIDialogueBox');
	LoadUIScreenClassSounds(class'UIPauseMenu');
	LoadUIScreenClassSounds(class'UIOptionsPCScreen');
}

//---------------------------------------------------------------------------------------
// HELIOS BEGIN
// Unprotect function so that mods can load up AKEvents for the menus
function LoadUIScreenClassSounds(class<UIScreen> UIScreenClass)
{
	LoadAkEvent(UIScreenClass.default.m_MenuOpenSound);
	LoadAkEvent(UIScreenClass.default.m_MenuCloseSound);
	LoadAkEvent(UIScreenClass.default.m_MenuCloseSound_Stop);
	LoadAkEvent(UIScreenClass.default.m_ConfirmSound);
	LoadAkEvent(UIScreenClass.default.m_MouseOverSound);
	LoadAkEvent(UIScreenClass.default.m_MouseClickSound);
	LoadAkEvent(UIScreenClass.default.m_NegativeMouseClickSound);
}
// HELIOS END

protected function StartAllAmbientSounds()
{
	local AmbientSound SoundActor;
	local float TimeOffsetToStart;

	//Start all the ambient sounds, and space out their start events so that Wise doesn't explode
	//Rate of 0 disables the timer, so start at 1 ms
	TimeOffsetToStart = 0.001f;
	foreach WorldInfo.AllActors(class'AmbientSound', SoundActor)
	{
		SetTimer(TimeOffsetToStart, false, 'AutoPlaySound', SoundActor);
		TimeOffsetToStart += 0.01f;	//10 ms spaced out to keep the pressure off of Wise
	}
}

//------------------------------------------------------------------------------
// Teardown
//------------------------------------------------------------------------------
function Cleanup()
{
	local Object ThisObj;
	local X2EventManager EventMgr;

	ThisObj = self;
	EventMgr = `XEVENTMGR;
	EventMgr.UnRegisterFromEvent(ThisObj, 'AbilityActivated');
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

//---------------------------------------------------------------------------------------
// Post-process effect audio
//---------------------------------------------------------------------------------------
function PlayPostProcessEffectTransitionAkEvents(name EffectName, bool bEffectEnabled)
{
	local int EffectIndex;
	local PPEffectAkEventInfo EffectEventInfo;
	local int IsActiveIndex;

	EffectIndex = PPEffectAkEventPaths.Find('EffectName', string(EffectName));
	if( EffectIndex != INDEX_NONE )
	{
		EffectEventInfo = PPEffectAkEventPaths[EffectIndex];
		IsActiveIndex = ActiveEffectNames.Find(EffectEventInfo.EffectName);

		if( bEffectEnabled ) // Enable
		{
			if( IsActiveIndex == INDEX_NONE )
			{
				PlayPPEffectAkEvent(EffectEventInfo.AkEventOnEnable);
				ActiveEffectNames.AddItem(EffectEventInfo.EffectName);
			}
			else if( EffectEventInfo.bRetriggerable ) // Separate branch for retriggerable sounds so that they don't add to ActiveEffectNames indefinitely
			{
				PlayPPEffectAkEvent(EffectEventInfo.AkEventOnEnable);
			}
		}
		else if( IsActiveIndex != INDEX_NONE ) // Disable
		{
			PlayPPEffectAkEvent(EffectEventInfo.AkEventOnDisable);
			ActiveEffectNames.RemoveItem(EffectEventInfo.EffectName);
		}
	}
}

//---------------------------------------------------------------------------------------
function PlayPPEffectAkEvent(string AkEventPath)
{
	local int AkEventIndex;

	AkEventIndex = PPEffectSoundEvents.Find('strKey', AkEventPath);
	if( AkEventIndex != INDEX_NONE )
	{
		PlayAkEvent(PPEffectSoundEvents[AkEventIndex].TriggeredEvent);
	}
}

//---------------------------------------------------------------------------------------
// Fades out all sounds playing on an actor
function StopActor(Actor actor)
{
	if (StopSoundsOnObjectEvent != None && actor != None)
	{
		actor.PlayAkEvent(StopSoundsOnObjectEvent);
	}
}

//---------------------------------------------------------------------------------------
// Application audio
//---------------------------------------------------------------------------------------
function UpdateFocusChangeMute(optional XComHUD XComHud)
{
	local XComInputBase XComInput;

	if (XComHud == none)
	{
		XComInput = XComInputBase(class'Engine'.static.GetCurrentWorldInfo().GetALocalPlayerController().PlayerInput);
		if (XComInput != none)
		{
			XComHud = XComInput.GetXComHUD();
		}
	}

	UpdateHUDFocusChangedDelegate(`XPROFILESETTINGS.Data.m_bMuteOnLoseFocus, XComHud);
}

//---------------------------------------------------------------------------------------
function UpdateHUDFocusChangedDelegate(bool bAddDelegate, XComHUD XComHud)
{
	if (XComHud != none)
	{
		if (bAddDelegate)
		{
			XComHud.AddFocusChangedCallback(self.FocusChangeMuteAudio);
			FocusChangeMuteAudio(XComHud.bGameWindowHasFocus);
			ActivateMovieFocusLossMute();
		}
		else
		{
			XComHud.RemoveFocusChangedCallback(self.FocusChangeMuteAudio);
			FocusChangeMuteAudio(true);
			DeactivateMovieFocusLossMute();
		}
	}
}

//---------------------------------------------------------------------------------------
private function FocusChangeMuteAudio(bool bHasFocus)
{
	SetState('GameHasFocus', (bHasFocus) ? 'True' : 'False');
	bFocusStateInitialized = true;
}

//---------------------------------------------------------------------------------------
private function InitializeFocusChangeMute()
{
	if (!bFocusStateInitialized)
	{
		SetState('GameHasFocus', 'True');
		bFocusStateInitialized = true;
	}
}

//---------------------------------------------------------------------------------------
function EnterCOPsState()
{
	SetState(COPsStateGroup, COPsStateOn);
}

//---------------------------------------------------------------------------------------
function ExitCOPsState()
{
	SetState(COPsStateGroup, COPsStateOff);
}

//---------------------------------------------------------------------------------------
event bool GetCinematicEventTable(out array<CinematicAkEvent> Table)
{
	local CinematicAkEvent BinkEvent;

	foreach CinematicEventOverrides(BinkEvent)
	{
		Table.AddItem(BinkEvent);
	}
	return true;
}

//---------------------------------------------------------------------------------------
static event float GetBinkMixVolumeDB()
{
	return class'XComSoundManager'.default.BinkMixVolumeDB;
}

//---------------------------------------------------------------------------------------
static event array<name> GetPermaloadBanks()
{
	return class'XComSoundManager'.default.PermaloadBanks;
}

//---------------------------------------------------------------------------------------
// UI Audio
//---------------------------------------------------------------------------------------
// Activate mouseover sound on cursor leaving the negative space of the interactives,
// which is occupied by the mouse guard.
function ActivateGuardBasedMouseover(UIScreen ActiveScreen)
{
	local UIScreen MouseGuard;

	if (ActiveScreen == none || ActiveScreen.Movie == none)
	{
		return;
	}

	MouseGuard = ActiveScreen.Movie.Stack.GetScreen(class'UIMouseGuard');
	if (MouseGuard != none)
	{
		if (MouseGuard.OnMouseEventDelegate != none)
		{
			`Redscreen(string(ActiveScreen.Class) $ " couldn't give callback to mouse guard. Mouseover audio on this screen may not work correctly. -dprice");
		}
		else
		{
			MouseGuard.OnMouseEventDelegate = OnMouseGuardMouseEvent;
			ActiveMouseoverScreen = ActiveScreen;
		}
	}
}

//---------------------------------------------------------------------------------------
// Deactivate mouseover sound on cursor leaving the mouse guard.
function DeactivateGuardBasedMouseover(UIScreen ActiveScreen)
{
	local UIScreen MouseGuard;

	if (ActiveScreen == none || ActiveScreen.Movie == none)
	{
		return;
	}

	MouseGuard = ActiveScreen.Movie.Stack.GetScreen(class'UIMouseGuard');
	if (MouseGuard != none && MouseGuard.OnMouseEventDelegate == OnMouseGuardMouseEvent && ActiveScreen == ActiveMouseoverScreen)
	{
		MouseGuard.OnMouseEventDelegate = none;
	}
}

//---------------------------------------------------------------------------------------
simulated function OnMouseGuardMouseEvent(UIPanel Panel, int Cmd)
{
	local Vector2D MousePos;
	local Vector2D ViewportSize;
	local Engine Engine;

	if (ActiveMouseoverScreen == none)
	{
		return;
	}

	switch (Cmd)
	{
	case class'UIUtilities_Input'.const.FXS_L_MOUSE_OUT:
		MousePos = LocalPlayer(GetALocalPlayerController().Player).ViewportClient.GetMousePosition();
		Engine = class'Engine'.static.GetEngine();
		Engine.GameViewport.GetViewportSize(ViewportSize);
		if (MousePos.X >= 0.0f && MousePos.Y >= 0.0f && MousePos.X <= ViewportSize.X && MousePos.Y <= ViewportSize.Y)
		{
			ActiveMouseoverScreen.PlayMouseOverSound();
		}
		break;
	}
}

defaultproperties
{
}
