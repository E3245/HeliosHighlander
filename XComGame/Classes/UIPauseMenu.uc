//---------------------------------------------------------------------------------------
//  *********   FIRAXIS SOURCE CODE   ******************
//  FILE:    UIPauseMenu
//  AUTHOR:  Brit Steiner       -- 02/26/09
//           Tronster Hartley   -- 04/14/09
//  PURPOSE: Controls the game side of the pause menu UI screen.
//---------------------------------------------------------------------------------------
//  Copyright (c) 2016 Firaxis Games, Inc. All rights reserved.
//--------------------------------------------------------------------------------------- 

class UIPauseMenu extends UIScreen;

var int       m_iCurrentSelection;
var int       MAX_OPTIONS;
var bool      m_bIsIronman;
var bool	  m_bIsHardcore;
var bool      m_bAllowSaving;

var UIList List;
var UIText Title;

var UIDIOHUD m_HUD;

var localized string m_sPauseMenu;
var localized string m_sSaveGame;
var localized string m_sReturnToGame;
var localized string m_sSaveAndExitGame;
var localized string m_sLoadGame;
var localized string m_sControllerMap;
var localized string m_sInputOptions;
var localized string m_sAbortMission;
var localized string m_sExitGame;
var localized string m_sQuitGame;
var localized string m_sAccept;
var localized string m_sCancel;
var localized string m_sAcceptInvitations;
var localized string m_kExitGameDialogue_title;
var localized string m_kExitGameDialogue_body;
var localized string m_kExitMPRankedGameDialogue_body;
var localized string m_kExitMPUnrankedGameDialogue_body;
var localized string m_kQuitGameDialogue_title;
var localized string m_kQuitGameDialogue_body;
var localized string m_kQuitChallengeGameDialogue_body;
var localized string m_kQuitReplayDialogue_body;
var localized string m_kQuitMPRankedGameDialogue_body;
var localized string m_kQuitMPUnrankedGameDialogue_body;
var localized string m_sRestartLevel;
var localized string m_sRestartConfirm_title;
var localized string m_sRestartConfirm_body;
var localized string m_sRestartEncounter;
var localized string m_sRestartEncounterConfirm_title;
var localized string m_sRestartEncounterConfirm_body;
var localized string m_sChangeDifficulty;
var localized string m_sViewSecondWave;
var localized string m_sUnableToSaveTitle;
var localized string m_sUnableToSaveBody;
var localized string m_sSavingIsInProgress;
var localized string m_sUnableToAbortTitle;
var localized string m_sUnableToAbortBody;
var localized string m_kSaveAndExitGameDialogue_title;
var localized string m_kSaveAndExitGameDialogue_body;
var localized string m_sChunkLocked;
var localized string m_sChunkLockedAccept;
var localized string m_sViewTutorialArchive;

var int m_optReturnToGame;
var int m_optSave;
var int m_optLoad;
var int m_optRestart;
var int m_optRestartEncounter;
var int m_optChangeDifficulty;
var int m_optViewSecondWave;
var int m_optControllerMap;
var int m_optOptions;
var int m_optViewTutorialArchive;
var int m_optExitGame;
var int m_optQuitGame;
var int m_optAcceptInvite;
var bool bWasInCinematicMode;

//bsg-crobinson (6.10.17): add in option to view player profile
var int m_optViewProfile;
var localized string m_sViewOpponentProfile;
var localized string m_sViewOpponentGamecard;
//bsg-crobinson (6.10.17): end

var protectedwrite UINavigationHelp NavHelp;
delegate OnCancel();
//</workshop>

simulated function InitScreen(XComPlayerController InitController, UIMovie InitMovie, optional name InitName)
{	
	InitMovie.Stack.bPauseMenuInput = true;
	super.InitScreen(InitController, InitMovie, InitName);
	
	Movie.Pres.OnPauseMenu(true);
	Movie.Pres.StopDistort(); 

	if( `XWORLDINFO.GRI != none && `TACTICALGRI != none && `BATTLE != none )
		`BATTLE.m_bInPauseMenu = true;

	if (!IsA('UIShellStrategy') && !`XENGINE.IsMultiplayerGame())
	{
		PC.SetPause(true);
	}
	
	List = Spawn(class'UIList', self);
	List.InitList('ItemList', , , 415, 450);
	List.OnItemClicked = OnChildClicked;
	List.OnSelectionChanged = SetSelected; 
	List.OnItemDoubleClicked = OnChildClicked;

	if (XComTacticalController(PC) != none)
		XComTacticalController(PC).GetCursor().SetForceHidden(false);

	if (`PRESBASE != none)
		`PRESBASE.m_kUIMouseCursor.Show();

	// HELIOS BEGIN
	// Replace the hard reference with a reference to the main HUD
	m_HUD = UIDIOHUD(`SCREENSTACK.GetScreen(`PRESBASE.UIHUD_Strategy));
	// HELIOS END

	if (m_HUD != none)
	{
		m_HUD.UpdateResources(self);
		NavHelp = m_HUD.NavHelp;
	}
	else
	{
		NavHelp = Spawn(class'UINavigationHelp', self).InitNavHelp();
	}

	UpdateNavHelp();
}

//----------------------------------------------------------------------------
//	Set default values.
//
simulated function OnInit()
{
	local bool bInputBlocked; 
	local bool bInputGateRaised;

	super.OnInit();	
	
	BuildMenu();
	
	SetSelected(List, 0);
	List.SetSelectedIndex(0);

	//If you've managed to fire up the pause menu while the state was transitioning to block input, get back out of here. 
	bInputBlocked = XComTacticalInput(PC.PlayerInput) != none && XComTacticalInput(PC.PlayerInput).m_bInputBlocked;
	bInputGateRaised = Movie != none && Movie.Stack != none &&  Movie.Stack.IsInputBlocked;
	if( bInputBlocked || bInputGateRaised )
	{
		`log("UIPauseMenu: you've got in to a bad state where the input is blocked but the pause menu just finished async loading in. Killing the pause menu now. -bsteiner");
		OnUCancel();
	}

	BlockUntilStreamingInstallComplete();
	
	`SCREENSTACK.ClearStrategyNavHelp(); // mmg_john.hawley (11/23/19) - Clear existing UI to prevent stacking.
}

simulated function UpdateNavHelp()
{
	NavHelp.ClearButtonHelp();
	NavHelp.bIsVerticalHelp = `ISCONTROLLERACTIVE;
	NavHelp.AddBackButton(OnUCancel);

	if( `ISCONTROLLERACTIVE )
		NavHelp.AddSelectNavHelp();
}

simulated event ModifyHearSoundComponent(AudioComponent AC)
{
	AC.bIsUISound = true;
}

simulated function bool OnUnrealCommand(int ucmd, int ActionMask)
{
	// Ignore releases, only pay attention to presses.
	if ( !CheckInputIsReleaseOrDirectionRepeat(ucmd, ActionMask) )
		return true;

	switch(ucmd)
	{
		case class'UIUtilities_Input'.const.FXS_BUTTON_A:
		case class'UIUtilities_Input'.const.FXS_KEY_ENTER:
		case class'UIUtilities_Input'.const.FXS_KEY_SPACEBAR:
			PlayMouseClickSound();
			OnChildClicked(List, m_iCurrentSelection);
			break;
		
		case class'UIUtilities_Input'.const.FXS_BUTTON_B:
		case class'UIUtilities_Input'.const.FXS_KEY_ESCAPE:
		case class'UIUtilities_Input'.const.FXS_BUTTON_START:
		case class'UIUtilities_Input'.const.FXS_R_MOUSE_DOWN:
			PlayMouseClickSound();
			OnUCancel();
			break;

		case class'UIUtilities_Input'.const.FXS_DPAD_UP:
		case class'UIUtilities_Input'.const.FXS_ARROW_UP:
		case class'UIUtilities_Input'.const.FXS_VIRTUAL_LSTICK_UP:
		case class'UIUtilities_Input'.const.FXS_KEY_W:
			OnUDPadUp();
			return true; // bsg-jrebar (4/26/17): Fix to looping keypresses on pause
			break;

		case class'UIUtilities_Input'.const.FXS_DPAD_DOWN:
		case class'UIUtilities_Input'.const.FXS_ARROW_DOWN:
		case class'UIUtilities_Input'.const.FXS_VIRTUAL_LSTICK_DOWN:
		case class'UIUtilities_Input'.const.FXS_KEY_S:
			OnUDPadDown();
			return true; // bsg-jrebar (4/26/17): Fix to looping keypresses on pause
			break;

		default:
			// Do not reset handled, consume input since this
			// is the pause menu which stops any other systems.
			break;			
	}

	return super.OnUnrealCommand(ucmd, ActionMask);
}

simulated function OnMouseEvent(int cmd, array<string> args)
{
	switch( cmd )
	{
		case class'UIUtilities_Input'.const.FXS_L_MOUSE_IN:
			//Update the selection based on what the mouse rolled over
			//SetSelected( int(Split( args[args.Length - 1], "option", true)) );
			break;

		case class'UIUtilities_Input'.const.FXS_L_MOUSE_UP:
			//Update the selection based on what the mouse clicked
			m_iCurrentSelection = int(Split( args[args.Length - 1], "option", true));
			OnChildClicked(List, m_iCurrentSelection);
			break;
	}
}

simulated public function OnChildClicked(UIList ContainerList, int ItemIndex)
{
	local bool IsTutorial;
	local bool bFailedToOpen;

	IsTutorial = (`TACTICALGRI != none && `TUTORIAL != none);

	SetSelected(ContainerList, ItemIndex);

	switch( m_iCurrentSelection )
	{
		case m_optReturnToGame:
			OnUCancel();
			break; 
		case m_optSave: //Save Game
			bFailedToOpen = true;
			if (!IsTutorial)
			{
				if (Movie.Pres.AllowSaving())
				{
					// Dio: manual saves not allowed in ironman/hardcore mode
					if (!m_bIsIronman && !m_bIsHardcore)
					{
						Movie.Pres.UISaveScreen();
						bFailedToOpen = false;
					}
				}
				else
				{
					UnableToSaveDialogue(`ONLINEEVENTMGR.SaveInProgress());
				}
			}
			break;

		case m_optLoad: //Load Game 
			Movie.Pres.UILoadScreen();
			break;

		case m_optChangeDifficulty:
			Movie.Pres.UIDifficulty( true );
			break;

		case m_optViewSecondWave:
			Movie.Pres.UISecondWave( true );
			break;

		case m_optRestart: // Restart Mission (only valid in tactical)
			if (`BATTLE != none && WorldInfo.NetMode == NM_Standalone && !m_bIsIronman)
				RestartMissionDialogue();
			else
				bFailedToOpen = true;
			break;

		case m_optRestartEncounter:
			if (`BATTLE != none && WorldInfo.NetMode == NM_Standalone && !m_bIsIronman)
				RestartEncounterDialogue();
			else
				bFailedToOpen = true;
			break;

		case m_optControllerMap: //Controller Map
			Movie.Pres.UIControllerMap();
			break;

		case m_optOptions: // Input Options
			//`log(self @"OnUnrealCommand does not have game data designed and implemented for option #3.");
			//Movie.Pres.QueueAnchoredMessage("Edit Settings option is not available.", 0.55f, 0.8f, BOTTOM_CENTER, 4.0f);
			Movie.Pres.UIPCOptions();
			return;

			break;

		//bsg-crobinson (6.10.17): run view profile if button is clicked
		case m_optViewProfile:
			ViewOpponentProfile();
			return;
		//bsg-crobinson (6.10.17): end

		case m_optExitGame: //Exit Game
			ExitGameDialogue();
			break;

		case m_optQuitGame: //Quit Game
			QuitGameDialogue();
			break;
			
		case m_optAcceptInvite: // Show Invitations UI
			Movie.Pres.UIInvitationsMenu();
			break;

		case m_optViewTutorialArchive:
			Movie.Pres.UITutorialArchive();
			break;

		default:
			bFailedToOpen = true;
			`warn("Pause menu cannot accept an unexpected index of:" @ m_iCurrentSelection);
			break;
	}

	if (bFailedToOpen)
	{
		PlayNegativeMouseClickSound();
	}
}

simulated function OnLoseFocus()
{
	super.OnLoseFocus();
	NavHelp.ClearButtonHelp();
}

simulated function OnReceiveFocus() 
{
	super.OnReceiveFocus();
	SetSelected(List, m_iCurrentSelection);
	UpdateNavHelp();
}

simulated event Destroyed()
{
	super.Destroyed();	
}

function SaveAndExit()
{
	local AutosaveParameters AutosaveParams;

	AutosaveParams.AutosaveType = 'Autosave';
	`AUTOSAVEMGR.DoAutosave(AutosaveParams);

	XComPresentationLayer(Movie.Pres).GetTacticalHUD().Hide();
	Hide();

	Movie.RaiseInputGate();
}

function OnSaveGameCompleteRefresh(bool bWasSuccessful)
{
	if( bWasSuccessful )
	{
		SetTimer(0.15, false, 'RefreshSaveGameList', self);
	}
}

function RefreshSaveGameList()
{
	`ONLINEEVENTMGR.UpdateSaveGameList();
}

function OnSaveGameComplete(bool bWasSuccessful)
{
	Movie.LowerInputGate();

	if( bWasSuccessful )
	{
		Disconnect();
	}
	else
	{
		`RedScreen("[@Systems] Save failed to complete");

		//bsg-hlee (06.28.17): If save failed then pop up a message.
		if( `ONLINEEVENTMGR.OnlineSub.ContentInterface.IsStorageFull() )
			`ONLINEEVENTMGR.ErrorMessageMgr.EnqueueError(SystemMessage_StorageFull);
		else
			`ONLINEEVENTMGR.ErrorMessageMgr.EnqueueError(SystemMessage_FailedSave);
		//bsg-hlee (06.28.17): End
	}
}

function Disconnect()
{
	local XComGameState_BattleData BattleData;
	BattleData = XComGameState_BattleData(`XCOMHISTORY.GetSingleGameStateObjectForClass(class'XComGameState_BattleData'));
	if (`TACTICALRULES != none && "Prologue" == BattleData.MapData.ActiveMission.sType)
	{
		`DNA.TelemetryTutorial(false);
	}
	
	// End all currently playing VO when exiting the game before clearing the history
	Movie.Pres.m_kNarrativeUIMgr.EndCurrentConversation(true);
	Movie.Pres.UIEndGame();
	`XCOMHISTORY.ResetHistory();
	ConsoleCommand("disconnect");
}

function ExitGameDialogue() 
{
	local TDialogueBoxData      kDialogData;
	local XComMPTacticalGRI     kMPGRI;

	kMPGRI = XComMPTacticalGRI(WorldInfo.GRI);

	kDialogData.eType = eDialog_Warning;

	if(kMPGRI != none)
	{
		if(kMPGRI.m_bIsRanked)
		{
			kDialogData.strText = m_kExitMPRankedGameDialogue_body; 
		}
		else
		{
			kDialogData.strText = m_kExitMPUnrankedGameDialogue_body; 
		}
		kDialogData.fnCallback = ExitMPGameDialogueCallback;
	}
	else
	{
		kDialogData.strText = m_kExitGameDialogue_body; 
		if (Movie.Pres.ScreenStack.HasInstanceOf(class'UIReplay') && !`REPLAY.bInTutorial)
			kDialogData.strText = m_kQuitReplayDialogue_body;
		else if (Movie.Pres.ScreenStack.HasInstanceOf(class'UIChallengeModeHUD'))
			kDialogData.strText = m_kQuitChallengeGameDialogue_body;

		kDialogData.fnCallback = ExitGameDialogueCallback;
	}

	kDialogData.strTitle = m_kExitGameDialogue_title;
	kDialogData.strAccept = m_sAccept; 
	kDialogData.strCancel = m_sCancel; 

	Movie.Pres.UIRaiseDialog( kDialogData );
}

simulated public function ExitGameDialogueCallback(Name eAction)
{
	if (eAction == 'eUIAction_Accept')
	{
		PlayConfirmSound();
		PlayMenuCloseSound();

		// Hide the UI so the user knows their input was accepted
		XComPresentationLayer(Movie.Pres).GetTacticalHUD().Hide();
		Hide();

		SetTimer(0.15, false, 'Disconnect'); // Give time for the UI to hide before disconnecting
	}
	else if( eAction == 'eUIAction_Cancel' )
	{
		PlayMouseClickSound();
	}
}

simulated public function ExitMPGameDialogueCallback(Name eAction)
{
	if (eAction == 'eUIAction_Accept')
	{
		PlayConfirmSound();
		PlayMenuCloseSound();
		Movie.Pres.UIEndGame();
		XComTacticalController(PC).AttemptExit();
		// bsg-jrebar (6/20/17): Disconnect when retruning to main menu
		if(`ISORBIS)
			HandleSessionDisconnect();
		// bsg-jrebar (6/20/17): end
	}
	else if( eAction == 'eUIAction_Cancel' )
	{
		PlayMouseClickSound();
	}
}

// bsg-jrebar (6/20/17): Disconnect when retruning to main menu
function bool HandleSessionDisconnect()
{
	local XComGameStateNetworkManager NetworkMgr;
	local OnlineGameInterface kGameInterface;
	local OnlineGameSettings kGameSettings;

	kGameInterface = class'GameEngine'.static.GetOnlineSubsystem().GameInterface;
	if (kGameInterface.GetGameSettings('Lobby') == None && kGameInterface.GetGameSettings('Game') == None)
	{
		return false;
	}

	if (kGameSettings == none)
	{
		kGameSettings = kGameInterface.GetGameSettings('Lobby');
	}

	//bsg-fchen (6.15.17): End the current multiplayer session before going into a different session
	kGameInterface.EndMultiplayer(`ONLINEEVENTMGR.LocalUserIndex);
	kGameInterface.DestroyOnlineGame(`ONLINEEVENTMGR.LocalUserIndex, kGameSettings.SessionTemplateName ~= "Lobby" ? 'Lobby' : 'Game');

	NetworkMgr = `XCOMNETMANAGER;
	NetworkMgr.Disconnect();
	return true;
}
// bsg-jrebar (6/20/17): end

function IronmanSaveAndExitDialogue()
{
	local TDialogueBoxData kDialogData;

	kDialogData.eType       = eDialog_Warning;
	kDialogData.strTitle    = m_kSaveAndExitGameDialogue_title;
	kDialogData.strText     = m_kSaveAndExitGameDialogue_body; 
	kDialogData.strAccept   = m_sAccept; 
	kDialogData.strCancel   = m_sCancel; 
	kDialogData.fnCallback  = IronmanSaveAndExitDialogueCallback;

	Movie.Pres.UIRaiseDialog( kDialogData );
}

simulated public function IronmanSaveAndExitDialogueCallback(Name eAction)
{	
	if (eAction == 'eUIAction_Accept')
	{
		PlayConfirmSound();
		PlayMenuCloseSound();
		SaveAndExit();
	}
	else if( eAction == 'eUIAction_Cancel' )
	{
		PlayMouseClickSound();
	}
}


function UnableToSaveDialogue(bool bSavingInProgress)
{
	local TDialogueBoxData kDialogData;

	kDialogData.eType       = eDialog_Warning;
	kDialogData.strTitle    = m_sUnableToSaveTitle;
	if( bSavingInProgress )
	{
		kDialogData.strText = m_sSavingIsInProgress;
	}
	else
	{
		kDialogData.strText = m_sUnableToSaveBody;
	}
	kDialogData.strAccept   = m_sAccept;	

	Movie.Pres.UIRaiseDialog( kDialogData );
}

function UnableToAbortDialogue()
{
	local TDialogueBoxData kDialogData;

	kDialogData.eType       = eDialog_Warning;
	kDialogData.strTitle    = m_sUnableToAbortTitle;
	kDialogData.strText     = m_sUnableToAbortBody; 
	kDialogData.strAccept   = m_sAccept;	

	Movie.Pres.UIRaiseDialog( kDialogData );
}

function RestartMissionDialogue()
{
	local TDialogueBoxData kDialogData;

	kDialogData.eType       = eDialog_Warning;
	kDialogData.strTitle    = m_sRestartConfirm_title;
	kDialogData.strText     = m_sRestartConfirm_body; 
	kDialogData.strAccept   = m_sAccept; 
	kDialogData.strCancel   = m_sCancel; 
	kDialogData.fnCallback  = RestartMissionDialgoueCallback;

	Movie.Pres.UIRaiseDialog( kDialogData );
}

simulated public function RestartMissionDialgoueCallback(Name eAction)
{	
	if (eAction == 'eUIAction_Accept')
	{
		`PRES.m_kNarrative.RestoreNarrativeCounters();
		PC.RestartLevel();
	}
}

function RestartEncounterDialogue()
{
	local TDialogueBoxData kDialogData;

	kDialogData.eType = eDialog_Warning;
	kDialogData.strTitle = m_sRestartEncounterConfirm_title;
	kDialogData.strText = m_sRestartEncounterConfirm_body;
	kDialogData.strAccept = m_sAccept;
	kDialogData.strCancel = m_sCancel;
	kDialogData.fnCallback = RestartEncounterDialgoueCallback;

	Movie.Pres.UIRaiseDialog(kDialogData);
}

simulated public function RestartEncounterDialgoueCallback(Name eAction)
{
	if (eAction == 'eUIAction_Accept')
	{
		PC.RestartEncounter();
	}
}

function QuitGameDialogue() 
{
	local TDialogueBoxData kDialogData; 
	local XComMPTacticalGRI     kMPGRI;

	kMPGRI = XComMPTacticalGRI(WorldInfo.GRI);

	if(kMPGRI != none && kMPGRI.m_bIsRanked)
	{
		kDialogData.strText     = m_kQuitMPRankedGameDialogue_body; 
		kDialogData.fnCallback  = QuitGameMPRankedDialogueCallback;
	}
	else
	{
		if(kMPGRI != none )
			kDialogData.strText     = m_kQuitMPUnrankedGameDialogue_body; 
		else if (Movie.Pres.ScreenStack.HasInstanceOf(class'UIReplay') && !`REPLAY.bInTutorial)
			kDialogData.strText		= m_kQuitReplayDialogue_body;
		else if (Movie.Pres.ScreenStack.HasInstanceOf(class'UIChallengeModeHUD'))
			kDialogData.strText = m_kQuitChallengeGameDialogue_body;
		else
			kDialogData.strText     = m_kQuitGameDialogue_body; 
		kDialogData.fnCallback  = QuitGameDialogueCallback;
	}

	kDialogData.eType       = eDialog_Warning;
	kDialogData.strTitle    = m_kQuitGameDialogue_title;
	kDialogData.strAccept   = m_sAccept; 
	kDialogData.strCancel   = m_sCancel; 

	Movie.Pres.UIRaiseDialog( kDialogData );
}

simulated public function QuitGameDialogueCallback(Name eAction)
{
	if (eAction == 'eUIAction_Accept')
	{
		PlayConfirmSound();
		PlayMenuCloseSound();
		Movie.Pres.UIEndGame();
		ConsoleCommand("exit");
	}
	else if( eAction == 'eUIAction_Cancel' )
	{
		PlayMouseClickSound();
	}
}

simulated public function QuitGameMPRankedDialogueCallback(Name eAction)
{
	if (eAction == 'eUIAction_Accept')
	{
		PlayConfirmSound();
		PlayMenuCloseSound();
		Movie.Pres.UIEndGame();
		ConsoleCommand("exit");
	}
	else if( eAction == 'eUIAction_Cancel' )
	{
		PlayMouseClickSound();
	}
}

//bsg-crobinson (6.10.17): Allow player to view opponents profile/gamercard
function ViewOpponentProfile()
{
	local PlayerReplicationInfo LocalPRI;
	local XComGameState_Player PlayerState;

	LocalPRI = GetALocalPlayerController().PlayerReplicationInfo;

	ForEach `XCOMHISTORY.IterateByClassType(class'XComGameState_Player', PlayerState)
	{
		if(LocalPRI.PlayerName != PlayerState.PlayerName)
		{			
			`ONLINEEVENTMGR.ShowGamerCardUIByIDAndName(PlayerState.GetGameStatePlayerNetId(), PlayerState.PlayerName);
			return;
		}
	}
}
//bsg-crobinson (6.10.17): end

// Lower pause screen
simulated public function OnUCancel()
{
	if( !bIsInited || !bIsVisible)
		return;

	if( `XWORLDINFO.GRI != none && `TACTICALGRI != none && `BATTLE != none )
		`BATTLE.m_bInPauseMenu = false;
	if (OnCancel != none)
	{
		OnCancel();
	}

	//bsg-jneal (7.11.17): clear the m_bDisallowSaving bool in the presentation layer when closing the pause menu, this could unintentionally block autosaves if opening the menu at a time when you're not allowed to save
	if(`ISCONSOLE)
	{
		Movie.Pres.SetDisallowSaving(false);
	}
	//bsg-jneal (7.11.17): end

	PlayMenuCloseSound();
	Movie.Stack.Pop(self);
}

simulated public function OnUDPadUp()
{
	local int originalSelection;
	originalSelection = m_iCurrentSelection;

	do
	{
		--m_iCurrentSelection;
		if (m_iCurrentSelection < 0)
			m_iCurrentSelection = MAX_OPTIONS-1;
	}
	until (List.GetItem(m_iCurrentSelection).bIsVisible || m_iCurrentSelection == originalSelection);

	PlayMouseOverSound();
	SetSelected(List, m_iCurrentSelection);
}


simulated public function OnUDPadDown()
{
	local int originalSelection;
	originalSelection = m_iCurrentSelection;
	
	do
	{
		++m_iCurrentSelection;
		if (m_iCurrentSelection >= MAX_OPTIONS)
			m_iCurrentSelection = 0;
	}
	until (List.GetItem(m_iCurrentSelection).bIsVisible || m_iCurrentSelection == originalSelection);

	PlayMouseOverSound();
	SetSelected( List, m_iCurrentSelection );
}

simulated function SetSelected(UIList ContainerList, int ItemIndex)
{
	m_iCurrentSelection = ItemIndex;
	ContainerList.SetSelectedIndex(ItemIndex); // bsg-jrebar (4/26/17): Fix to looping keypresses on pause
}

simulated function int GetSelected()
{
	return m_iCurrentSelection; 
}

simulated function BuildMenu()
{
	local int iCurrent; 
	local XComMPTacticalGRI kMPGRI;
	local UIListItemString SaveGameListItem;
	local bool IsTutorial, IsBreachMode, bRestartDisabled;

	kMPGRI = XComMPTacticalGRI(WorldInfo.GRI);

	MC.FunctionString("SetTitle", m_sPauseMenu);

	//AS_Clear();
	List.ClearItems();

	iCurrent = 0; 

	//set options to -1 so they don't interfere with the switch statement on selection
	m_optSave = -1;
	m_optLoad = -1; 

	IsBreachMode = XGBattle_SP(`BATTLE).m_kDesc.bInBreachPhase;

	//Return to game option is always 0 
	m_optReturnToGame = iCurrent++;
	//AS_AddOption(m_optReturnToGame, m_sReturnToGame, 0);
	UIListItemString(List.CreateItem()).InitListItem(m_sReturnToGame);

	// no save/load in multiplayer -tsmith 
	if (kMPGRI == none && !`ONLINEEVENTMGR.bIsChallengeModeGame && !`REPLAY.bInReplay)
	{
		if( m_bAllowSaving )
		{
			IsTutorial = (`TACTICALGRI != none && `TUTORIAL != none);

			m_optSave = iCurrent++; 
			//AS_AddOption(m_optSave, m_sSaveAndExitGame, 0);
			SaveGameListItem = UIListItemString(List.CreateItem()).InitListItem(m_sSaveGame);
		
			if (IsTutorial)
			{
				SaveGameListItem.DisableListItem(class'XGLocalizedData'.default.SaveDisabledForTutorial);
			}
			else if (m_bIsIronman || m_bIsHardcore)
			{
				SaveGameListItem.DisableListItem(class'XGLocalizedData'.default.SaveDisabledForIronman);
			}
		}
		
		// in ironman, you cannot load at any time that saving would normally be disabled
		if( m_bAllowSaving || !m_bIsIronman )
		{
			m_optLoad = iCurrent++;
			//AS_AddOption(m_optLoad, m_sLoadGame, 0);
			UIListItemString(List.CreateItem()).InitListItem(m_sLoadGame);
		}
	}

	if( Movie.IsMouseActive() || `REPLAY.bInReplay)
	{
		m_optControllerMap = -1; 
	}
	else
	{
		m_optControllerMap = iCurrent++; 
		//AS_AddOption(m_optControllerMap, m_sControllerMap, 0);
		UIListItemString(List.CreateItem()).InitListItem(m_sControllerMap);
	}

	// Some menu items not allowed during BREACH MODE:
	// - Edit Options
	// - View Tutorial Archive
	if (!IsBreachMode)
	{
		m_optOptions = iCurrent++;
		UIListItemString(List.CreateItem()).InitListItem(m_sInputOptions);

		m_optViewTutorialArchive = iCurrent++;
		UIListItemString(List.CreateItem()).InitListItem(m_sViewTutorialArchive);
	}

	// no restart in multiplayer -tsmith 
	bRestartDisabled = m_bIsIronman;
	bRestartDisabled = bRestartDisabled || kMPGRI != none;
	bRestartDisabled = bRestartDisabled || XComPresentationLayer(Movie.Pres) == none;
	bRestartDisabled = bRestartDisabled || `TACTICALGRI == none;
	bRestartDisabled = bRestartDisabled || XGBattle_SP(`BATTLE).m_kDesc == None;
	//dakota 5/2/19: Dio allows Restart on all missions
	//bRestartDisabled = bRestartDisabled || (XGBattle_SP(`BATTLE).m_kDesc.m_iMissionType != eMission_Final && !XGBattle_SP(`BATTLE).m_kDesc.m_bIsFirstMission && XGBattle_SP(`BATTLE).m_kDesc.m_iMissionType != eMission_HQAssault); //Only visible in temple ship or first mission, per Jake. -bsteiner 6/12/12
	bRestartDisabled = bRestartDisabled || `ONLINEEVENTMGR.bIsChallengeModeGame;
	if(!bRestartDisabled)
	{
		m_optRestart = iCurrent++; 
		//AS_AddOption(m_optRestart, m_sRestartLevel, 0);
		UIListItemString(List.CreateItem()).InitListItem(m_sRestartLevel);

		m_optRestartEncounter = iCurrent++;
		UIListItemString(List.CreateItem()).InitListItem(m_sRestartEncounter);
	}
	else
	{
		m_optRestart = -1;  //set options to -1 so they don't interfere with the switch statement on selection
		m_optRestartEncounter = -1;
	}

	// Only allow changing difficulty if in an active single player game and only at times where saving is permitted
	if( Movie.Pres.m_eUIMode != eUIMode_Shell && kMPGRI == none && m_bAllowSaving && !`ONLINEEVENTMGR.bIsChallengeModeGame && !`REPLAY.bInReplay)
	{
		m_optChangeDifficulty = iCurrent++; 
		//AS_AddOption(m_optChangeDifficulty, m_sChangeDifficulty, 0);
		UIListItemString(List.CreateItem()).InitListItem(m_sChangeDifficulty);
	}
	else
		m_optChangeDifficulty = -1;  //set options to -1 so they don't interfere with the switch statement on selection

	// Only show second wave options in single player
	if ( `XPROFILESETTINGS.Data.IsSecondWaveUnlocked() && Movie.Pres.m_eUIMode != eUIMode_Shell && kMPGRI == none )
	{
		m_optViewSecondWave = iCurrent++; 
		//AS_AddOption(m_optViewSecondWave, m_sViewSecondWave, 0);
		UIListItemString(List.CreateItem()).InitListItem(m_sViewSecondWave);
	}
	else
		m_optViewSecondWave = -1;  //set options to -1 so they don't interfere with the switch statement on selection
	
	//bsg-crobinson (6.10.17): Initialize the menu option depending on which console
	if(kMPGRI != None)
	{
		m_optViewProfile = iCurrent++;
		if(`ISDURANGO) //Xbox uses "gamercard"
		{
			UIListItemString(List.CreateItem()).InitListItem(m_sViewOpponentGamecard);
		}
		else
		{
			UIListItemString(List.CreateItem()).InitListItem(m_sViewOpponentProfile);
		}
	}
	else
		m_optViewProfile = -1;
	//bsg-crobinson (6.10.17): end

	// Remove the invite option -ttalley
	//m_optAcceptInvite = iCurrent++;
	//AS_AddOption( m_optAcceptInvite, m_sAcceptInvitations, 0);

	m_optExitGame = iCurrent++; 
	//AS_AddOption(m_optExitGame, m_sExitGame, 0); 
	UIListItemString(List.CreateItem()).InitListItem(m_sExitGame);

	// no quit game on console or in MP. MP we only want exit so it will record a loss for you. -tsmith 

	if (`XPROFILESETTINGS != none && !`ISCONSOLE) //bsg-nlong (12.13.16): Don't add "Quit to Desktop" on consoles
	{
		if( `CHEATMGR == None || !`CHEATMGR.bMonkeyRun )
		{
			m_optQuitGame = iCurrent++;
			//AS_AddOption(m_optQuitGame, m_sQuitGame, 0);
			UIListItemString(List.CreateItem()).InitListItem(m_sQuitGame);
		}
	}

	MAX_OPTIONS = iCurrent;

	MC.FunctionVoid("AnimateIn");
}

simulated function OnRemoved()
{
	PC.SetPause(false); //Uses Movie.Stack.bPauseMenuInput, so do this first
	Movie.Stack.bPauseMenuInput = false; 	
	Movie.Pres.OnPauseMenu(false);
}

simulated function OnExitButtonClicked(UIButton button)
{
	CloseScreen();
}

simulated function CloseScreen()
{
	NavHelp.ClearButtonHelp();
	super.CloseScreen();
}

event Tick( float deltaTime )
{
	local XComTacticalController XTC;

	super.Tick( deltaTime );

	XTC = XComTacticalController(PC);
	if (XTC != none && XTC.GetCursor().bHidden)
	{
		XTC.GetCursor().SetVisible(true);
	}
}

simulated function BlockUntilStreamingInstallComplete()
{
	if (!class'GameEngine'.static.GetOnlineSubsystem().IsGameDownloaded())
	{
		List.GetItem(m_optLoad).Hide();
		SetTimer(1.0f, false, nameof(BlockUntilStreamingInstallComplete));
	}
	else
	{
		List.GetItem(m_optLoad).Show();
	}
}

DefaultProperties
{
	m_iCurrentSelection = 0;
	MAX_OPTIONS = -1;
	m_bIsIronman = false;

	Package   = "/ package/gfxPauseMenu/PauseMenu";
	MCName      = "thePauseMenu";

	InputState= eInputState_Consume;
	bConsumeMouseEvents = true;

	bAlwaysTick = true
	bShowDuringCinematic = true
}
