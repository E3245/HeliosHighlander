//---------------------------------------------------------------------------------------
//  *********   FIRAXIS SOURCE CODE   ******************
//  FILE:    UISaveGame
//  AUTHOR:  Katie Hirsch       -- 01/22/10
//           Tronster           -- 04/25/12
//  PURPOSE: Serves as an interface for loading saved games.
//---------------------------------------------------------------------------------------
//  Copyright (c) 2009-2016 Firaxis Games, Inc. All rights reserved.
//--------------------------------------------------------------------------------------- 

class UISaveGame extends UIScreen
	dependson(UIDialogueBox)
	dependson(UIProgressDialogue)
	config(UI); //bsg-hlee (05.31.17): Limiting saves to 100. Brought over from Laz.

enum ESaveStage
{
	/** No save is taking place. */
	SaveStage_None,

	/** The save progress dialog is being open. */
	SaveStage_OpeningProgressDialog,

	/** The save game is being written to disk. */
	SaveStage_SavingGame,

	/** The user profile is being written to disk. */
	SaveStage_SavingProfile
};

var int m_iCurrentSelection;
var array<OnlineSaveGame> m_arrSaveGames;
var array<UISaveLoadGameListItem> m_arrListItems;
var OnlineSaveGame m_BlankSaveGame;

//bsg-jneal (11.11.16): distributing the UISaveLoadGameListItem spawns across multiple frames as this would cause the game to freeze on longer save lists
var bool m_bInitSaveLoadListItems;
var int m_iListItemIndex;
//bsg-jneal (11.11.16): end

var UIList List;
var UIPanel ListBG;

var ESaveStage m_SaveStage; // The current stage a save operation is in

var localized string m_sSaveTitle;
var localized string m_sEmptySlot;
var localized string m_sRefreshingSaveGameList;
var localized string m_sSavingInProgress;
var localized string m_sSavingInProgressPS3;
var localized string m_sOverwriteSaveTitle;
var localized string m_sOverwriteSaveText;
var localized string m_sDeleteSaveTitle;
var localized string m_sDeleteSaveText;
var localized string m_sSaveFailedTitle;
var localized string m_sSaveFailedText;
var localized string m_sStorageFull;
var localized string m_sSelectStorage;
var localized string m_sFreeUpSpace;
var localized string m_sNameSave;
//bsg-hlee (05.31.17): Limiting saves to 100. Taken from Laz.
var localized string m_sMaxUserSavesTitle;
var localized string m_sMaxUserSavesMessage;
//bsg-hlee (05.31.17): Lee

var bool m_bBlockingSavesFromOtherLanguages; //MUST BE ENABLED FOR SHIP!!! -bsteiner

var bool m_bUseStandardFormSaveMsg; // Set to true if saves go over 1 second on Xbox 360
var bool m_bSaveNotificationTimeElapsed; // true if the save notification time requirement has been satisfied
var bool m_bSaveSuccessful; // true when a save has successfully been made

var bool m_bNeedsToLoadDLC1MapImages; 
var bool m_bNeedsToLoadDLC2MapImages;
var bool m_bNeedsToLoadHQAssaultImage;
var bool m_bLoadCompleteCoreMapImages;
var bool m_bLoadCompleteDLC1MapImages;
var bool m_bLoadCompleteDLC2MapImages;
var bool m_bLoadCompleteHQAssaultImage;

// We need to hold references to the images to ensure they don't ever get unloaded by the Garbage Collector - sbatista 7/30/13
var array<object> m_arrLoadedObjects;

var UINavigationHelp NavHelp;

var private string m_sSaveToDelete; //bsg-jneal (2.20.17): fixing save game overwrites for console, overwritten saves need to be deleted

var config int MaxUserSaves; //bsg-hlee (05.31.17): Limiting saves to 100. Taken from Laz.

simulated function InitScreen(XComPlayerController InitController, UIMovie InitMovie, optional name InitName)
{
	super.InitScreen(InitController, InitMovie, InitName);

	if( `XENGINE.bReviewFlagged )
		m_bBlockingSavesFromOtherLanguages = true;
	else
		m_bBlockingSavesFromOtherLanguages = false;

	NavHelp = GetNavHelp();
	NavHelp.ClearButtonHelp();
	NavHelp.AddBackButton(OnCancel);

	ListBG = Spawn(class'UIPanel', self);
	ListBG.InitPanel('SaveLoadBG'); 
	ListBG.Show();
	ListBG.bShouldPlayGenericUIAudioEvents = false;

	List = Spawn(class'UIList', self);
	
	//bsg-jneal (2.21.17): turning off looping selection on the list
	if(`ISCONTROLLERACTIVE)
	{
		List.bLoopSelection = false;
	}
	//bsg-jneal (2.21.17): end	List.InitList('listMC');

	List.InitList('listMC');
	List.OnSelectionChanged = SelectedItemChanged;

	// send mouse scroll events to the list
	ListBG.ProcessMouseEvents(List.OnChildMouseEvent);

	XComInputBase(PC.PlayerInput).RawInputListener = RawInputHandler;
}

simulated function UINavigationHelp GetNavHelp()
{
	local UINavigationHelp Result;
	Result = PC.Pres.GetNavHelp();
	if( Result == None )
	{
		if( `PRES != none ) // Tactical
		{
			Result = Spawn(class'UINavigationHelp', self).InitNavHelp();
		}
		else 
		{
			// HELIOS BEGIN
			// Replace the hard reference with a reference to the main HUD	
			NavHelp = UIDIOHUD(`SCREENSTACK.GetScreen(`PRESBASE.UIHUD_Strategy)).NavHelp;
			// HELIOS END	
		}
	}
	return Result;
}

simulated function SelectedItemChanged(UIList ContainerList, int ItemIndex)
{
	m_iCurrentSelection = ItemIndex;
}

simulated function OnReadSaveGameListStarted()
{
	ShowRefreshingListDialog();
}

simulated function OnReadSaveGameListComplete(bool bWasSuccessful)
{
	if( bWasSuccessful )
		`ONLINEEVENTMGR.GetSaveGames(m_arrSaveGames);
	else
		m_arrSaveGames.Remove(0, m_arrSaveGames.Length);

	FilterSaveGameList();
	`ONLINEEVENTMGR.SortSavedGameListByTimestamp(m_arrSaveGames, MaxUserSaves); // mmg_aaron.lee (12/11/19) - pass in MaxUserSaves			

	BuildMenu();

	// Close progress dialog
	Movie.Stack.PopFirstInstanceOfClass(class'UIProgressDialogue', false);
}

simulated function FilterSaveGameList()
{
	local XComOnlineEventMgr OnlineEventMgr;
	local int SaveGameIndex;
	local int SaveGameID;
	local bool RemoveSave;
	local string CurrentLanguage;
	local string SaveLanguage;

	OnlineEventMgr = `ONLINEEVENTMGR;
	CurrentLanguage = GetLanguage();
	
	SaveGameIndex = 0;
	while( SaveGameIndex < m_arrSaveGames.Length )
	{
		RemoveSave = false;
		SaveGameID = OnlineEventMgr.SaveNameToID(m_arrSaveGames[SaveGameIndex].Filename);

		// Filter out save games made in other languages
		if( m_bBlockingSavesFromOtherLanguages )
		{
			OnlineEventMgr.GetSaveSlotLanguage(SaveGameID, SaveLanguage);
			if( CurrentLanguage != SaveLanguage )
				RemoveSave = true;
		}

		if( RemoveSave )
			m_arrSaveGames.Remove(SaveGameIndex, 1);
		else
			SaveGameIndex++;
	}
}

simulated function OnSaveDeviceLost()
{
	// Clear any dialogs on this screen
	Movie.Pres.Get2DMovie().DialogBox.ClearDialogs();

	// Back out of this screen entirely
	Movie.Stack.Pop( self ); 
}

//----------------------------------------------------------------------------
//	Set default values.
//
simulated function OnInit()
{
	local XComOnlineEventMgr OnlineEventMgr; 

	super.OnInit();	
	
	AS_SetTitle(`MAKECAPS(m_sSaveTitle));

	OnlineEventMgr = `ONLINEEVENTMGR;
	if( OnlineEventMgr != none )
	{
		OnlineEventMgr.AddUpdateSaveListStartedDelegate(OnReadSaveGameListStarted);
		OnlineEventMgr.AddUpdateSaveListCompleteDelegate(OnReadSaveGameListComplete);
		OnlineEventMgr.AddSaveDeviceLostDelegate(OnSaveDeviceLost);
	}

	MouseGuardInst.OnMouseEventDelegate = OnChildMouseEvent;

	SubscribeToOnCleanupWorld();	

	if( OnlineEventMgr.bUpdateSaveListInProgress )
		OnReadSaveGameListStarted();
	else
		OnReadSaveGameListComplete(true);

	Show();

	ShowRefreshingListDialog(); //bsg-jneal (11.11.16): distributing the UISaveLoadGameListItem spawns across multiple frames as this would cause the game to freeze on longer save lists
}

simulated function bool OnUnrealCommand(int ucmd, int ActionMask)
{
	local bool bHandled; //bsg-jneal (6.5.17): fix for input causing double virtual keyboard errors on console

	// Ignore releases, just pay attention to presses.
	if ( !CheckInputIsReleaseOrDirectionRepeat(ucmd, ActionMask) )
		return true;

	if( !bIsInited ) 
		return true;
	//if( !QueryAllImagesLoaded() ) return true; //If allow input before the images load, you will crash. Serves you right. -bsteiner

	// Don't accept input if we're in the middle of a save.
	if ( m_SaveStage != SaveStage_None )
		return true;

	bHandled = true; //bsg-jneal (6.5.17): fix for input causing double virtual keyboard errors on console

	switch(ucmd)
	{
		case (class'UIUtilities_Input'.const.FXS_BUTTON_A):
		case (class'UIUtilities_Input'.const.FXS_KEY_ENTER):
		case (class'UIUtilities_Input'.const.FXS_KEY_SPACEBAR):
			//bsg-hlee (5.02.17): Fixing flow for new saves.
			if(m_arrListItems[m_iCurrentSelection].ID == -1) //If this is a new save
			{
				OnRename(); //Allow players to create a new name.
			}
			else
			{
				OnAccept(); //Ask to overwrite the save.
			}
			//bsg-hlee (5.02.17): End
			break;
	
		case (class'UIUtilities_Input'.const.FXS_BUTTON_B):
		case (class'UIUtilities_Input'.const.FXS_KEY_ESCAPE):
		case class'UIUtilities_Input'.const.FXS_R_MOUSE_DOWN:
			OnCancel();
			break;

		case (class'UIUtilities_Input'.const.FXS_BUTTON_X):
			OnDelete();
			break;

		//bsg-jneal (2.21.17): disabling this input as it was duplicating input when wrapping through the save list, leaving commented out for now as we may reuse the functionality to add a proper list wrap later
		case class'UIUtilities_Input'.const.FXS_DPAD_UP:
		case class'UIUtilities_Input'.const.FXS_ARROW_UP:
		case class'UIUtilities_Input'.const.FXS_VIRTUAL_LSTICK_UP: 
		case class'UIUtilities_Input'.const.FXS_KEY_W:
			//OnDPadUp();
			bHandled = false;				// Remove this line if the list wrap is implemented
			if (m_iCurrentSelection > 0)	// Remove this line if the list wrap is implemented
				PlayMouseOverSound();		// Do NOT remove this line if implementing the list wrap
			break;

		case class'UIUtilities_Input'.const.FXS_DPAD_DOWN:
		case class'UIUtilities_Input'.const.FXS_ARROW_DOWN:
		case class'UIUtilities_Input'.const.FXS_VIRTUAL_LSTICK_DOWN:
		case class'UIUtilities_Input'.const.FXS_KEY_S:
			//OnDPadDown();
			bHandled = false;							// Remove this line if the list wrap is implemented
			if (m_iCurrentSelection < GetNumSaves())	// Remove this line if the list wrap is implemented
				PlayMouseOverSound();					// Do NOT remove this line if implementing the list wrap
			break;
		//bsg-jneal (2.21.17): end

		default:
			// Do not reset handled, consume input since this
			// is the pause menu which stops any other systems.
			bHandled = false; //bsg-jneal (6.5.17): fix for input causing double virtual keyboard errors on console
			break;			
	}


	return bHandled ? bHandled : super.OnUnrealCommand(ucmd, ActionMask); //bsg-jneal (6.5.17): fix for input causing double virtual keyboard errors on console
}

simulated function bool RawInputHandler(Name Key, int ActionMask, bool bCtrl, bool bAlt, bool bShift)
{
	if(ActionMask == class'UIUtilities_Input'.const.FXS_ACTION_PRESS && (Key == 'Delete' || Key == 'BackSpace') && !Movie.Pres.UIIsShowingDialog() )
	{
		OnDelete();
		return true;
	}
	return false;
}

simulated public function OnAccept(optional UIButton control)
{
	local TDialogueBoxData kDialogData;

	// Check to see if we're saving over an existing save game
	if( m_iCurrentSelection > 0 )
	{
		PlayMouseClickSound();

		// Warn about overwriting an existing save
		kDialogData.eType     = eDialog_Warning;
		kDialogData.strTitle  = m_sOverwriteSaveTitle;
		kDialogData.strText   = m_sOverwriteSaveText;
		kDialogData.strAccept = class'UIDialogueBox'.default.m_strDefaultAcceptLabel;
		kDialogData.strCancel = class'UIDialogueBox'.default.m_strDefaultCancelLabel;

		kDialogData.fnCallback  = OverwritingSaveWarningCallback;
		Movie.Pres.UIRaiseDialog( kDialogData );
	}
	else
	{
		//bsg-jedwards (1.26.17): Allowing for it to set the description for console
		// Saving into an empty slot
		if(!`ISCONSOLE)
		{
			`ONLINEEVENTMGR.SetPlayerDescription(GetCurrentSelectedFilename());
			Save();
		}
		else	
		{
			OnRename();
		}
		//bsg-jedwards (1.26.17): end
	}
}

simulated function OverwritingSaveWarningCallback(Name eAction)
{
	if (eAction == 'eUIAction_Accept')
	{
		PlayConfirmSound();
		`ONLINEEVENTMGR.SetPlayerDescription(GetCurrentSelectedFilename());
		Save();
	}
	else
	{
		PlayMouseClickSound();
	}
}

simulated function Save()
{
	local TProgressDialogData kDialogData;

	// Cannot do two saves at the same time
	if( m_SaveStage != SaveStage_None )
	{
		`log("UISaveGame cannot save. A save is already in progress.");
		return;
	}

	// Cannot create a new save if there is insufficient space
	if( WorldInfo.IsConsoleBuild(CONSOLE_Xbox360) && m_iCurrentSelection == 0 && !`ONLINEEVENTMGR.CheckFreeSpaceForSave_Xbox360() )
	{
		`log("UISaveGame cannot save. There is insufficient space on the save device.");
		`ONLINEEVENTMGR.ErrorMessageMgr.EnqueueError(SystemMessage_StorageFull);
		return;
	}

	//bsg-hlee (05.31.17): Limiting saves to 100. Taken from Laz.
	if(WorldInfo.IsConsoleBuild() && m_iCurrentSelection == 0 && GetSaveID(0) > MaxUserSaves)
	{
		`log("UISaveGame cannot save. MaxUserSaves [" $ MaxUserSaves $ "] limit has been reached.");
		MaxUserSavesDialog();
		return;
	}
	//bsg-hlee (05.31.17): End

	if( !WorldInfo.IsConsoleBuild() )
	{
		// On PC saving is synchronous and near instantaneous.
		// This being the case there is no point in opening a progress dialog.
		// Just skip straight to the saving game stage.
		m_SaveStage = SaveStage_SavingGame;
		`ONLINEEVENTMGR.SaveGame(GetSaveID(m_iCurrentSelection), "ManualSave", "", SaveGameComplete);
	}
	else
	{
		// On consoles saving is asynchronous and a little slow. We use a progress dialog here.

		// Cannot save if a progress dialog is open. It will conflict with the
		// progress dialog for the save game which could cause issues.
		if( Movie.Pres.IsInState('State_ProgressDialog') )
		{
			`log("UISaveGame cannot save. A progress dialog is open");
			return;
		}

		m_SaveStage = SaveStage_OpeningProgressDialog;

		if( m_bUseStandardFormSaveMsg )
			kDialogData.strTitle = WorldInfo.IsConsoleBuild(CONSOLE_Xbox360)? m_sSavingInProgress : m_sSavingInProgressPS3;
		else
			kDialogData.strTitle = class'XComOnlineEventMgr'.default.m_strSaving; // Short form saving message

		kDialogData.fnProgressDialogOpenCallback = SaveProgressDialogOpen;
		Movie.Pres.UIProgressDialog(kDialogData);
	}
}

simulated function SaveProgressDialogOpen()
{
	// Now we can move on to the save game stage
	m_SaveStage = SaveStage_SavingGame;

	//bsg-jneal (2.20.17): fixing save game overwrites for console, overwritten saves need to be deleted
	if(`ISCONSOLE)
	{
		if(m_iCurrentSelection > 0 && m_iCurrentSelection <= m_arrSaveGames.Length)
		{
			m_sSaveToDelete = m_arrSaveGames[m_iCurrentSelection-1].Filename;
		}

		`ONLINEEVENTMGR.SaveGame(GetSaveID(0), "ManualSave", "", SaveGameComplete); //bsg-jneal (1.27.17): save IDs get filtered away if they're autosaves or ironman leading to an invalid index, just grab a new ID
	}
	else
	{
		`ONLINEEVENTMGR.SaveGame(GetSaveID(m_iCurrentSelection), "ManualSave", "", SaveGameComplete);
	}
	//bsg-jneal (2.20.17): end

	m_bSaveNotificationTimeElapsed = false;
	SetTimer((m_bUseStandardFormSaveMsg)? 3 : 1, false, 'SaveNotificationTimeElapsed'); // bsg-nlong (12.2.16): The timer on Movie.Pres does not trigger in all instances
}																						// so we'll put the timer on this actor instead

simulated function SaveNotificationTimeElapsed()
{
	m_bSaveNotificationTimeElapsed = true;
	CloseSavingProgressDialogWhenReady();
}

simulated function SaveGameComplete(bool bWasSuccessful)
{
	if( bWasSuccessful )
	{
		m_bSaveSuccessful = true;

		// Save the profile settings
		m_SaveStage = SaveStage_SavingProfile;

		`ONLINEEVENTMGR.AddSaveProfileSettingsCompleteDelegate(SaveProfileSettingsComplete);
		`ONLINEEVENTMGR.SaveProfileSettings();

		CloseScreen();
	}
	else
	{
		// Close progress dialog
		Movie.Stack.PopFirstInstanceOfClass(class'UIProgressDialogue', false);

		m_SaveStage = SaveStage_None;

		// Warn about failed save
		if( `ONLINEEVENTMGR.OnlineSub.ContentInterface.IsStorageFull() )
			`ONLINEEVENTMGR.ErrorMessageMgr.EnqueueError(SystemMessage_StorageFull);
		else
			`ONLINEEVENTMGR.ErrorMessageMgr.EnqueueError(SystemMessage_FailedSave);
	}
}

simulated function SaveProfileSettingsComplete(bool bWasSuccessful)
{
	`ONLINEEVENTMGR.ClearSaveProfileSettingsCompleteDelegate(SaveProfileSettingsComplete);

	if( m_SaveStage == SaveStage_SavingProfile )
	{
		m_SaveStage = SaveStage_None;

		//bsg-jneal (2.20.17): fixing save game overwrites for console, overwritten saves need to be deleted
		if(m_sSaveToDelete != "")
		{
			// if we are overwriting a save we need to delete the old one
			`ONLINEEVENTMGR.OnlineSub.ContentInterface.AddDeleteSaveGameDataCompleteDelegate(`ONLINEEVENTMGR.LocalUserIndex, OnOverwriteSaveGameDataComplete);
			`ONLINEEVENTMGR.DeleteSaveGame( `ONLINEEVENTMGR.SaveNameToID(m_sSaveToDelete) );
			m_sSaveToDelete = "";
		}
		else
		{
			CloseSavingProgressDialogWhenReady();			
		}
		//bsg-jneal (2.20.17): end
	}
}

//bsg-jneal (2.20.17): fixing save game overwrites for console, overwritten saves need to be deleted
function OnOverwriteSaveGameDataComplete(bool bWasSuccessful, byte LocalUserNum, string SaveFileName)
{
	`ONLINEEVENTMGR.OnlineSub.ContentInterface.ClearDeleteSaveGameDataCompleteDelegate(`ONLINEEVENTMGR.LocalUserIndex, OnOverwriteSaveGameDataComplete);
	CloseSavingProgressDialogWhenReady();	
}
//bsg-jneal (2.20.17): end

/** Checks both the save stage and the progress dialog time to determine if it is ok to close the progress dialog */
simulated function CloseSavingProgressDialogWhenReady()
{
	// Close progress dialog if the save is complete
	if( m_SaveStage == SaveStage_None && m_bSaveNotificationTimeElapsed )
	{
		// Close the progress dialog
		Movie.Stack.PopFirstInstanceOfClass(class'UIProgressDialogue', false);

		// Close the save screen after a successful save is finished
		if( m_bSaveSuccessful )
			Movie.Stack.Pop(self);
	}
}

//bsg-hlee (05.31.17): Limiting saves to 100. Taken from Laz.
simulated function MaxUserSavesDialog()
{
	local TDialogueBoxData DialogData;

	DialogData.eType = eDialog_Warning;
	DialogData.strAccept = class'UIDialogueBox'.default.m_strDefaultAcceptLabel;

	DialogData.strTitle   = m_sMaxUserSavesTitle;
	DialogData.strText    = Repl(m_sMaxUserSavesMessage, "%VALUE", MaxUserSaves);

	Movie.Pres.UIRaiseDialog(DialogData);
}
//bsg-hlee (05.31.17): End

// Lower pause screen
simulated public function OnCancel()
{
	PlayMouseClickSound();
	CloseScreen();
}

simulated public function OnDelete(optional UIButton control)
{
	local TDialogueBoxData kDialogData;

	if( m_iCurrentSelection > 0 && m_iCurrentSelection <= m_arrSaveGames.Length )
	{
		PlayMouseClickSound();

		// Warn before deleting save
		kDialogData.eType     = eDialog_Warning;
		kDialogData.strTitle  = m_sDeleteSaveTitle;
		kDialogData.strText   = m_sDeleteSaveText @ GetCurrentSelectedFilename();
		kDialogData.strAccept = class'UIDialogueBox'.default.m_strDefaultAcceptLabel;
		kDialogData.strCancel = class'UIDialogueBox'.default.m_strDefaultCancelLabel;

		kDialogData.fnCallback  = DeleteSaveWarningCallback;
		Movie.Pres.UIRaiseDialog( kDialogData );
	}
	else
	{
		// Can't delete an empty save slot!
		PlayNegativeMouseClickSound();
	}
}

//bsg-hlee (5.02.17): Removing bottom left b button duplicate.
simulated function OnLoseFocus()
{
	super.OnLoseFocus();	
	NavHelp.ClearButtonHelp();
}

simulated function OnReceiveFocus()
{
	super.OnReceiveFocus();
	NavHelp.AddBackButton(OnCancel); //Add the back button back.
}
//bsg-hlee (5.02.17): end

simulated public function OnRename(optional UIButton control)
{
	local TInputDialogData kData;

	PlayMouseClickSound();

	//bsg-jedwards (1.26.17): Added condition to enable virtual keyboard with functions that had the name accepted or cancelled 
	if(!`ISCONSOLE)
	{
		kData.strTitle = m_sNameSave;
		kData.iMaxChars = 40;
		kData.strInputBoxText = GetCurrentSelectedFilename();
		kData.fnCallbackAccepted = SetCurrentSelectedFilename;
		kData.fnCallbackCancelled = PlayMouseClickSoundCallback;
	
		Movie.Pres.UIInputDialog(kData);
	}
	else
	{
		Movie.Pres.UIKeyboard(m_sNameSave,
			GetCurrentSelectedFileName(),
			VirtualKeyboard_InputBoxAccepted,
			VirtualKeyboard_InputBoxCancelled,
			false,
			40
		);
	}

	
}

simulated function VirtualKeyboard_InputBoxAccepted(string saveName, bool bAccepted)
{
	if(saveName == "")
	{
		saveName = GetCurrentSelectedFileName();
	}
	
	if(bAccepted)
	{
		SetCurrentSelectedFilename(saveName);
	} 
	else 
	{
		Save();
	}
}

simulated function VirtualKeyboard_InputBoxCancelled()
{
	
}
//bsg-jedwards (1.26.17): end

simulated function SetCurrentSelectedFilename(string text)
{	
	PlayConfirmSound();

	text = Repl(text, "\n", "", false);
	m_arrListItems[m_iCurrentSelection].UpdateSaveName(text);

	`ONLINEEVENTMGR.SetPlayerDescription(text); // Will be cleared by the saving process
	Save();		
}

simulated function PlayMouseClickSoundCallback(string text)
{
	PlayMouseClickSound();
}

simulated function string GetCurrentSelectedFilename()
{
	local string SaveName;
	if(m_iCurrentSelection > 0 && m_arrSaveGames[m_iCurrentSelection-1].SaveGames[0].SaveGameHeader.PlayerSaveDesc != "")
	{
		SaveName = m_arrSaveGames[m_iCurrentSelection-1].SaveGames[0].SaveGameHeader.PlayerSaveDesc;
	}
	else
	{
		SaveName = `ONLINEEVENTMGR.m_sEmptySaveString @ `ONLINEEVENTMGR.GetNextSaveID();
	}

	return SaveName;
}

simulated function DeleteSaveWarningCallback(Name eAction)
{
	if (eAction == 'eUIAction_Accept')
	{
		PlayConfirmSound();
		if (WorldInfo.IsConsoleBuild())
		{
			// On Console start by showing a progress dialog.
			// Then, when the dialog is open, delete the file.
			ShowRefreshingListDialog(DeleteSelectedSaveFile);
		}
		else
		{
			// On PC this is all nearly instantaneous.
			// Skip the progress dialog.
			DeleteSelectedSaveFile();
		}
	}
	else
	{
		PlayMouseClickSound();
	}
}

simulated function DeleteSelectedSaveFile()
{
	`ONLINEEVENTMGR.DeleteSaveGame( GetSaveID(m_iCurrentSelection) );
}

simulated function ShowRefreshingListDialog(optional delegate<UIProgressDialogue.ProgressDialogOpenCallback> ProgressDialogOpenCallback=none)
{
	local TProgressDialogData kDialogData;

	kDialogData.strDescription = m_sRefreshingSaveGameList; //bsg-jneal (5.19.17: moving title to description to address space constraints with localization
	Movie.Pres.UIProgressDialog(kDialogData);

	if(ProgressDialogOpenCallback != none)
	{
		ProgressDialogOpenCallback();
	}
}

simulated public function OnDPadUp()
{
	SetSelection(m_iCurrentSelection - 1);
}


simulated public function OnDPadDown()
{
	SetSelection(m_iCurrentSelection + 1);
}

simulated function SetSelection(int currentSelection)
{
	local int i; 

	for (i = 0; i < m_arrListItems.Length; i++)
	{
		m_arrListItems[i].OnLoseFocus();
	}
	if (m_iCurrentSelection >=0 && m_iCurrentSelection < m_arrListItems.Length)
	{
		m_arrListItems[m_iCurrentSelection].HideHighlight();
	}

	m_iCurrentSelection = currentSelection;
	
	if (m_iCurrentSelection < 0)
	{
		m_iCurrentSelection = GetNumSaves();
	}
	else if (m_iCurrentSelection >= (GetNumSaves() + 1))
	{
		m_iCurrentSelection = 0;
	}

	if (m_iCurrentSelection >=0 && m_iCurrentSelection < m_arrListItems.Length)
	{
		m_arrListItems[m_iCurrentSelection].ShowHighlight();
	}

	if( `ISCONTROLLERACTIVE )
	{
		m_arrListItems[m_iCurrentSelection].OnReceiveFocus();

		List.Scrollbar.SetThumbAtPercent(float(m_iCurrentSelection) / float(m_arrListItems.Length - 1));
	}
}

simulated function BuildMenu()
{
	AS_Clear(); // Will be called after deleting a save
	List.ClearItems();
	m_arrListItems.Remove(0, m_arrListItems.Length);

	m_arrListItems.AddItem(Spawn(class'UISaveLoadGameListItem', List.ItemContainer).InitSaveLoadItem(0, m_BlankSaveGame, true, OnAccept, OnDelete, OnRename, SetSelection));
	m_arrListItems[0].ProcessMouseEvents(OnChildMouseEvent);

	//bsg-jneal (11.11.16): distributing the UISaveLoadGameListItem spawns across multiple frames as this would cause the game to freeze on longer save lists
	m_bInitSaveLoadListItems = true; // start adding the save/load list items in Tick()	
	//bsg-jneal (11.11.16): end
}

simulated function OnChildMouseEvent(UIPanel Control, int cmd)
{
	//local bool bUtilityItemSelected;
	local float scrollbarPercent, percentChange, newPercent;

	// Ensure we're not processing any delayed mouse events if the user has requested to ignore mouse input.
	if (List.HasHitTestDisabled()) return;

	percentChange = 1.0f / float(m_arrListItems.Length - 1);
	scrollbarPercent = List.Scrollbar.percent;

	switch (cmd)
	{
	case class'UIUtilities_Input'.const.FXS_MOUSE_SCROLL_DOWN :
		newPercent = scrollbarPercent - percentChange;
		break;
	case class'UIUtilities_Input'.const.FXS_MOUSE_SCROLL_UP :
		newPercent = scrollbarPercent + percentChange;
		break;
	default:
		List.OnChildMouseEvent(Control, cmd);
		return;
	}
	if (newPercent > 1.0f)
		newPercent = 1.0f;
	else if (newPercent < 0.0f)
		newPercent = 0.0f;

	List.Scrollbar.SetThumbAtPercent(newPercent);
}

//bsg-jneal (11.11.16): distributing the UISaveLoadGameListItem spawns across multiple frames as this would cause the game to freeze on longer save lists
event Tick(float deltaTime)
{
	local int i;

	if(m_bInitSaveLoadListItems)
	{
		//bsg-jneal (3.2.17): reconfiguring save list item generation, now will not create an blank list item for empty save list
		if(m_arrSaveGames.Length != 0 )
		{
			// for loop used to distribute list item creation over multiple frames
			// can adjust termination check of i < 2 to a different number if desired to make more or less list items per tick
			for( i = 0; i < 2; i++ )
			{
				// spawn the list items and add them to the List
				m_arrListItems.AddItem(Spawn(class'UISaveLoadGameListItem', List.ItemContainer).InitSaveLoadItem(m_iListItemIndex + 1, m_arrSaveGames[m_iListItemIndex], true, OnAccept, OnDelete, , SetSelection)); //bsg-jneal (3.15.17): fix for save item list index
				m_arrListItems[m_iListItemIndex].ProcessMouseEvents(List.OnChildMouseEvent);
				m_iListItemIndex++;

				if(m_iListItemIndex >= m_arrSaveGames.Length)
					break;
			}
		}

		// once all list items have been added, refresh the List for display and remove the wait dialog
		if(m_iListItemIndex >= m_arrSaveGames.Length)
		{
			m_bInitSaveLoadListItems = false;
			m_iCurrentSelection = -1;
			m_iListItemIndex = 0; //bsg-jneal (1.27.17): reset the list item index for cases when the save list will refresh
			SetSelection(0);
			List.RealizeItems();
			List.RealizeList();
			List.Navigator.SetSelected(List.GetItem(0));
			Movie.Stack.PopFirstInstanceOfClass(class'UIProgressDialogue', false);
		}
		//bsg-jneal (3.2.17): end
	}
}
//bsg-jneal (11.11.16): end

simulated function int GetSaveID(int iIndex)
{
	if (iIndex > 0 && iIndex <= m_arrSaveGames.Length)
		return `ONLINEEVENTMGR.SaveNameToID(m_arrSaveGames[iIndex-1].Filename);

	return `ONLINEEVENTMGR.GetNextSaveID(); //  if not saving over an existing game, get a new save ID
}

simulated function int GetNumSaves()
{
	return m_arrSaveGames.Length;
}

simulated function CoreImagesLoaded(object LoadedObject) 
{
	m_arrLoadedObjects.AddItem( LoadedObject );
	m_bLoadCompleteCoreMapImages = true;
	TestAllImagesLoaded(); 
}
simulated function DLC1ImagesLoaded(object LoadedObject) 
{
	m_arrLoadedObjects.AddItem( LoadedObject );
	m_bLoadCompleteDLC1MapImages = true;
	TestAllImagesLoaded(); 
}
simulated function DLC2ImagesLoaded(object LoadedObject) 
{
	m_arrLoadedObjects.AddItem( LoadedObject );
	m_bLoadCompleteDLC2MapImages = true;
	TestAllImagesLoaded(); 
}
simulated function HQAssaultImagesLoaded(object LoadedObject) 
{
	m_arrLoadedObjects.AddItem( LoadedObject );
	m_bLoadCompleteHQAssaultImage = true;
	TestAllImagesLoaded();
}
simulated function bool QueryAllImagesLoaded()
{
	if( !m_bLoadCompleteCoreMapImages )
		return false;

	if( m_bNeedsToLoadDLC1MapImages && !m_bLoadCompleteDLC1MapImages )
		return false;
	
	if( m_bNeedsToLoadDLC2MapImages && !m_bLoadCompleteDLC2MapImages )
		return false;

	if( m_bNeedsToLoadHQAssaultImage && !m_bLoadCompleteHQAssaultImage )
		return false;
	
	return true;
}
simulated function TestAllImagesLoaded()
{
	if( !QueryAllImagesLoaded() ) return; 

	ClearTimer('ImageCheck'); 
	ReloadImages();
	Movie.Pres.UILoadAnimation(false);
}

simulated function ReloadImages() 
{
	//Must call this outside of the async request
	Movie.Pres.SetTimer( 0.1f, false, 'ImageCheck', self );
}

simulated function ImageCheck()
{
	local int i;
	local string mapName, mapImage;
	local Texture2D mapTextureTest;

	//Check to see if any images fail, and clear the image if failed so the default image will stay.
	for( i = 0; i < m_arrSaveGames.Length; i++ )
	{
		`ONLINEEVENTMGR.GetSaveSlotMapName(GetSaveID(i), mapName);
		if(mapName == "") continue;

		mapImage = class'UIUtilities_Image'.static.GetMapImagePackagePath( name(mapName) );
		`log("++++ UISaveGame: SetMapImage - '" $ mapImage $ "'",,'uixcom');
		mapTextureTest = Texture2D(DynamicLoadObject( mapImage, class'Texture2D'));
		
		if( mapTextureTest == none )
		{
			//Do nothing.
			m_arrListItems[i].ClearImage();
		}
	}
	
	AS_ReloadImages();
}

//----------------------------------------------------------------------------
// Flash calls
//----------------------------------------------------------------------------

simulated function AS_AddListItem( int id, string desc, string gameTime, string saveTime, bool bIsDisabled, string imagePath )
{
	Movie.ActionScriptVoid(screen.MCPath$".AddListItem");
}

simulated function AS_ReloadImages()
{
	Movie.ActionScriptVoid(screen.MCPath$".ReloadImages");
}

simulated function AS_Clear()
{
	Movie.ActionScriptVoid(screen.MCPath$".Clear");
}

simulated function AS_SetTitle( string sTitle )
{
	Movie.ActionScriptVoid(screen.MCPath$".SetTitle");
}

//----------------------------------------------------------------------------
// Cleanup
//----------------------------------------------------------------------------

event Destroyed()
{
	super.Destroyed();
	m_arrLoadedObjects.length = 0; 
	DetachDelegates();
	UnsubscribeFromOnCleanupWorld();
}

simulated event OnCleanupWorld()
{
	super.OnCleanupWorld();
	DetachDelegates();
}

simulated function DetachDelegates()
{
	local XComOnlineEventMgr OnlineEventMgr;

	OnlineEventMgr = `ONLINEEVENTMGR;
	if( OnlineEventMgr != none )
	{
		OnlineEventMgr.ClearUpdateSaveListStartedDelegate(OnReadSaveGameListStarted);
		OnlineEventMgr.ClearUpdateSaveListCompleteDelegate(OnReadSaveGameListComplete);
		OnlineEventMgr.ClearSaveProfileSettingsCompleteDelegate(SaveProfileSettingsComplete);
		OnlineEventMgr.ClearSaveDeviceLostDelegate(OnSaveDeviceLost);
	}
}

DefaultProperties
{
	m_iCurrentSelection = 0;
	m_SaveStage = SaveStage_None;

	Package   = "/ package/gfxSaveLoad/SaveLoad";

	InputState= eInputState_Consume;
	bConsumeMouseEvents=true

	m_bUseStandardFormSaveMsg=false // Set to true if saves go over 1 second on Xbox 360
	m_bSaveSuccessful=false
	
	bAlwaysTick=true; // ensure this screen ticks when the game is paused

	m_bNeedsToLoadDLC1MapImages=false
	m_bNeedsToLoadDLC2MapImages=false 
	m_bLoadCompleteDLC1MapImages=false
	m_bLoadCompleteDLC2MapImages=false
	m_bLoadCompleteCoreMapImages=true

	bIsVisible = false; // This screen starts hidden

	//bsg-jneal (11.11.16): distributing the UISaveLoadGameListItem spawns across multiple frames as this would cause the game to freeze on longer save lists
	m_bInitSaveLoadListItems=false;
	m_iListItemIndex = 0;
	//bsg-jneal (11.11.16): end
}
