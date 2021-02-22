//---------------------------------------------------------------------------------------
//  *********   FIRAXIS SOURCE CODE   ******************
//  FILE:    UILoadGame
//  AUTHOR:  Katie Hirsch       -- 01/22/10
//           Tronster              
//  PURPOSE: Serves as an interface for loading saved games.
//---------------------------------------------------------------------------------------
//  Copyright (c) 2009-2016 Firaxis Games, Inc. All rights reserved.
//--------------------------------------------------------------------------------------- 

class UILoadGame extends UIScreen
	dependson(UIDialogueBox)
	dependson(UIProgressDialogue)
	config(UI); // mmg_aaron.lee (12/11/19) - Limiting saves to 100. Brought over from Laz.

var int m_iCurrentSelection;
var array<OnlineSaveGame> m_arrSaveGames;
var array<UISaveLoadGameListItem> m_arrListItems;
var bool m_bPlayerHasConfirmedLosingProgress; 
var bool m_bLoadInProgress;

//bsg-jneal (11.11.16): distributing the UISaveLoadGameListItem spawns across multiple frames as this would cause the game to freeze on longer save lists
var bool m_bInitSaveLoadListItems;
var int m_iListItemIndex;
//bsg-jneal (11.11.16): end

var UIList List;
var UIPanel ListBG;

var localized string m_sLoadTitle;
var localized string m_sLoadingInProgress;
var localized string m_sMissingDLCTitle;
var localized string m_sMissingDLCText;
var localized string m_sBadSaveVersionTitle;
var localized string m_sBadSaveVersionText;
var localized string m_sBadSaveVersionDevText;
var localized string m_sLoadFailedTitle;
var localized string m_sLoadFailedText;
var localized string m_sLoadFailedTextConsole; //bsg-nlong (11.14.16): Load failed text that omits mention of corruption
var localized string m_strLostProgressTitle;
var localized string m_strLostProgressBody;
var localized string m_strLostProgressConfirm;
var localized string m_strDeleteLabel;
var localized string m_strLanguageLabel;
var localized string m_strWrongLanguageText;
var localized string m_strSaveOutOfDateTitle;
var localized string m_strSaveOutOfDateBody;
var localized string m_strLoadAnyway;
var localized string m_strSaveDifferentLanguage;
var localized string m_strSaveDifferentLanguageBody;

var localized string m_sMissingDLCTextDingo;
var localized string m_sMissingDLCTextOrbis;
var localized string m_sCorruptedSaveTitle;
var localized string m_sCorruptedSave;

var array<int> SaveSlotStatus;

var bool m_bBlockingSavesFromOtherLanguages; //MUST BE ENABLED FOR SHIP!!! -bsteiner

var bool m_bNeedsToLoadDLC1MapImages; 
var bool m_bNeedsToLoadDLC2MapImages;
var bool m_bNeedsToLoadHQAssaultImage;
var bool m_bLoadCompleteCoreMapImages;
var bool m_bLoadCompleteDLC1MapImages;
var bool m_bLoadCompleteDLC2MapImages;
var bool m_bLoadCompleteHQAssaultImage;
var config int MaxUserSaves; // mmg_aaron.lee (12/11/19) - Limiting saves to 100.
// We need to hold references to the images to ensure they don't ever get unloaded by the Garbage Collector - sbatista 7/30/13
// Save the packagese, not the images. bsteiner 8/12/2013
var array<object> m_arrLoadedObjects;

var UINavigationHelp NavHelp;

simulated function InitScreen(XComPlayerController InitController, UIMovie InitMovie, optional name InitName)
{
	super.InitScreen(InitController, InitMovie, InitName);
	
	if( `XENGINE.bReviewFlagged )
		m_bBlockingSavesFromOtherLanguages = true;
	else
		m_bBlockingSavesFromOtherLanguages = false;

	NavHelp = GetNavHelp(); 
	UpdateNavHelp(); //bsg-hlee (05.05.17): Moving over console changes for nav help.

	ListBG = Spawn(class'UIPanel', self);
	ListBG.bIsNavigable = false;
	ListBG.InitPanel('SaveLoadBG'); 
	ListBG.Show();
	ListBG.ProcessMouseEvents(OnChildMouseEvent);

	List = Spawn(class'UIList', self);
	
	//bsg-jneal (2.21.17): turning off looping selection on the list
	if(`ISCONTROLLERACTIVE)
	{
		List.bLoopSelection = false;
	}
	//bsg-jneal (2.21.17): end

	List.InitList('listMC');
	List.OnSelectionChanged = SelectedItemChanged; 	//bsg-jneal (2.21.17): adding selection changed function to update the selected index properly when using navigator

	XComInputBase(PC.PlayerInput).RawInputListener = RawInputHandler;
}

simulated function OnInit()
{
	local XComOnlineEventMgr OnlineEventMgr; 

	super.OnInit();	

	SetTitle(`MAKECAPS(m_sLoadTitle));

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

	Navigator.SetSelected(List);
	if (List.ItemCount > 0)
	{
		List.Navigator.SetSelected(List.GetItem(0));
	}

	ShowRefreshingListDialog(); //bsg-jneal (11.11.16): distributing the UISaveLoadGameListItem spawns across multiple frames as this would cause the game to freeze on longer save lists
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

//bsg-jneal (2.21.17): adding selection changed function to update the selected index properly when using navigator
simulated function SelectedItemChanged(UIList ContainerList, int ItemIndex)
{
	m_iCurrentSelection = ItemIndex;
}
//bsg-jneal (2.21.17): end

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

	if (FilterSaveGameList(m_arrSaveGames, m_bBlockingSavesFromOtherLanguages))
	{
		ShowSaveLanguageDialog();	
	}

	`ONLINEEVENTMGR.SortSavedGameListByTimestamp(m_arrSaveGames, MaxUserSaves); // mmg_aaron.lee (12/11/19) - pass in MaxUserSaves	

	BuildMenu();
}

simulated static function bool FilterSaveGameList( out array<OnlineSaveGame> SaveGames, bool bBlockingSavesFromOtherLanguages = true )
{
	local XComOnlineEventMgr OnlineEventMgr;
	local int SaveGameIndex;
	local int SaveGameID;
	local bool RemoveSave;
	local string CurrentLanguage;
	local string SaveLanguage;
	local bool bDifferentLanguageDetected;
	local SaveGameHeader Header;
	local bool bIsAutosave;

	OnlineEventMgr = `ONLINEEVENTMGR;
	CurrentLanguage = GetLanguage();
	
	SaveGameIndex = 0;
	while( SaveGameIndex < SaveGames.Length )
	{
		RemoveSave = false;
		SaveGameID = OnlineEventMgr.SaveNameToID(SaveGames[SaveGameIndex].Filename);

		// Filter out save games made in other languages
		if( bBlockingSavesFromOtherLanguages )
		{
			OnlineEventMgr.GetSaveSlotLanguage(SaveGameID, SaveLanguage);
			if( CurrentLanguage != SaveLanguage )
			{
				RemoveSave = true;
				bDifferentLanguageDetected = true;
			}
		}

		Header = SaveGames[SaveGameIndex].SaveGames[0].SaveGameHeader;
		bIsAutosave = class'XComAutosaveMgr'.default.AutosaveTypeList.find(name(Header.SaveType)) != -1;		
		if (bIsAutosave && class'XComAutosaveMgr'.default.HideAutosavesInLoadUI)
		{
			RemoveSave = true;
		}

		if( RemoveSave )
			SaveGames.Remove(SaveGameIndex, 1);
		else
			SaveGameIndex++;
	}

	return bDifferentLanguageDetected;
}

simulated function OnSaveDeviceLost()
{
	// Clear any dialogs on this screen
	Movie.Pres.Get2DMovie().DialogBox.ClearDialogs();

	// Back out of this screen entirely
	Movie.Stack.Pop( self );
}

simulated function bool OnUnrealCommand(int cmd, int arg)
{
	local int numSaves;

	// Only pay attention to presses or repeats; ignoring other input types
	// NOTE: Ensure repreats only occur with arrow keys
	if ( !CheckInputIsReleaseOrDirectionRepeat(cmd, arg) )
		return false;
	
	if( !bIsInited ) 
		return true;
	//if( !QueryAllImagesLoaded() ) return true; //If allow input before the images load, you will crash. Serves you right. -bsteiner

	switch(cmd)
	{
		case (class'UIUtilities_Input'.const.FXS_BUTTON_A):
		case (class'UIUtilities_Input'.const.FXS_KEY_ENTER):
		case class'UIUtilities_Input'.const.FXS_KEY_SPACEBAR:
			OnAccept();
			return true;
	
		case (class'UIUtilities_Input'.const.FXS_BUTTON_B):
		case (class'UIUtilities_Input'.const.FXS_KEY_ESCAPE):
		case class'UIUtilities_Input'.const.FXS_R_MOUSE_DOWN:
			OnCancel();
			return true;

		case (class'UIUtilities_Input'.const.FXS_BUTTON_X):
			OnDelete();
			return true;

		//bsg-jneal (2.21.17): disabling this input as it was duplicating input when wrapping through the save list, leaving commented out for now as we may reuse the functionality to add a proper list wrap later
		case class'UIUtilities_Input'.const.FXS_DPAD_UP:
		case class'UIUtilities_Input'.const.FXS_ARROW_UP:
		case class'UIUtilities_Input'.const.FXS_VIRTUAL_LSTICK_UP:
		case class'UIUtilities_Input'.const.FXS_KEY_W:
			if (GetNumSaves() > 1)
			{
				if (m_iCurrentSelection > 0)	// Remove this line if the list wrap is implemented
					PlayMouseOverSound();		// Do NOT remove this line if implementing the list wrap
			}
			//OnUDPadUp();
			//return true;  //bsg-jrebar (4.6.17): return once handled else will get caught in loop of unhandled input causing errors
			break;

		case class'UIUtilities_Input'.const.FXS_DPAD_DOWN:
		case class'UIUtilities_Input'.const.FXS_ARROW_DOWN:
		case class'UIUtilities_Input'.const.FXS_VIRTUAL_LSTICK_DOWN:
		case class'UIUtilities_Input'.const.FXS_KEY_S:
			numSaves = GetNumSaves();
			if (numSaves > 1)
			{
				if (m_iCurrentSelection < numSaves - 1) // Remove this line if the list wrap is implemented
					PlayMouseOverSound();				// Do NOT remove this line if implementing the list wrap
			}
			//OnUDPadDown();
			//return true;  //bsg-jrebar (4.6.17): return once handled else will get caught in loop of unhandled input causing errors
			break;
		//bsg-jneal (2.21.17): end

		default:
			break;			
	}

	// always give base class a chance to handle the input so key input is propogated to the panel's navigator
	return super.OnUnrealCommand(cmd, arg);
}

simulated function bool RawInputHandler(Name Key, int ActionMask, bool bCtrl, bool bAlt, bool bShift)
{
	if(ActionMask == class'UIUtilities_Input'.const.FXS_ACTION_PRESS && (Key == 'Delete' || Key == 'BackSpace') && !Movie.Pres.UIIsShowingDialog())
	{
		OnDelete();
		return true;
	}
	return false;
}

simulated function OnMouseEvent(int cmd, array<string> args)
{
	local string targetCallback;
	local int selected, buttonNum;

	targetCallBack = args[ 5 ];
	selected = int( Repl(targetCallBack, "saveItem", ""));
	targetCallBack = args[ args.Length - 1 ];
	buttonNum = int( Repl(targetCallBack, "Button", ""));

	if(cmd == class'UIUtilities_Input'.const.FXS_L_MOUSE_UP)
	{
		SetSelected(selected);
		
		if(buttonNum == 0)
		{			
			OnAccept();
		}
		else if(buttonNum == 1)
		{
			OnDelete();
		}
	}
	else if(cmd == class'UIUtilities_Input'.const.FXS_L_MOUSE_DOUBLE_UP)
	{
		SetSelected(selected);
		OnAccept();
	}
}

simulated public function OutdatedSaveWarningCallback(Name eAction)
{
	if (eAction == 'eUIAction_Accept')
	{
		LoadSelectedSlot();
	}
	else
	{
		PlayMouseClickSound();
		//Reset this confirmation	
		m_bPlayerHasConfirmedLosingProgress = false;
	}
}

simulated public function DifferentLangSaveWarningCallback(Name eAction)
{
	if (eAction == 'eUIAction_Accept')
	{
		LoadSelectedSlot();
	}
	else
	{
		//Reset this confirmation	
		m_bPlayerHasConfirmedLosingProgress = false;
	}
}

simulated function ShowSaveLanguageDialog()
{
	local TDialogueBoxData DialogData;

	DialogData.eType = eDialog_Normal;
	DialogData.strText = m_strWrongLanguageText;
	DialogData.strAccept = class'UIDialogueBox'.default.m_strDefaultAcceptLabel;

	XComPresentationLayerBase(Owner).UIRaiseDialog(DialogData);
}

simulated function LoadSelectedSlot(bool IgnoreVersioning = false)
{
	local int SaveID;
	local TDialogueBoxData DialogData;
	local TProgressDialogData ProgressDialogData;
	local string MissingDLC;

	SaveID = GetSaveID(m_iCurrentSelection);

	if ( !`ONLINEEVENTMGR.CheckSaveVersionRequirements(SaveID) && !IgnoreVersioning)
	{
		if(`ISCONSOLE)
		{
			PlayNegativeMouseClickSound();
			`ONLINEEVENTMGR.ErrorMessageMgr.EnqueueError(SystemMessage_LazSave);
			m_bPlayerHasConfirmedLosingProgress = false; //bsg-hlee (06.01.17): Make sure to reset this or it will not ask the player to confirm.
		}
		else
		{
			PlayMouseClickSound();

			DialogData.eType = eDialog_Warning;
			DialogData.strTitle = m_sBadSaveVersionTitle;

		`if(`notdefined(FINAL_RELEASE))
			DialogData.strAccept = m_strLoadAnyway;
			DialogData.strText = m_sBadSaveVersionDevText;
		`else
			DialogData.strText = m_sBadSaveVersionText;
		`endif

			DialogData.strCancel = class'UIDialogueBox'.default.m_strDefaultCancelLabel;
			DialogData.fnCallback = DevVersionCheckOverride;
			DialogData.bMuteAcceptSound = true;

			Movie.Pres.UIRaiseDialog( DialogData );
		}
	}
	else if( !`ONLINEEVENTMGR.CheckSaveDLCRequirements(SaveID, MissingDLC) )
	{
		if(`ISCONSOLE)
		{
			PlayNegativeMouseClickSound();
			// mmg_mike.anstine TODO! ALee - Ozzy / Lazarus / Make sure CheckSaveDLCRequirements() won't affect Dio
			if(InStr(MissingDLC,`ONLINEEVENTMGR.const.Laz_Name)  >= 0) //bsg-cballinger (3.20.17): add message specifically for loading a Laz save in Ozzy
				`ONLINEEVENTMGR.ErrorMessageMgr.EnqueueError(SystemMessage_LazSave);
			else
				`ONLINEEVENTMGR.ErrorMessageMgr.EnqueueError(SystemMessage_DLCMissing);

			m_bPlayerHasConfirmedLosingProgress = false; //bsg-hlee (06.01.17): Make sure to reset this or it will not ask the player to confirm.
		}
		else
		{
			PlayMouseClickSound();

			DialogData.eType = eDialog_Warning;
			DialogData.strTitle = m_sMissingDLCTitle;
			DialogData.strAccept = class'UIDialogueBox'.default.m_strDefaultAcceptLabel;
				
			DialogData.strText = Repl(m_sMissingDLCText, "%modnames%", MissingDLC);

			DialogData.strAccept = m_strLoadAnyway;
			DialogData.strCancel = class'UIDialogueBox'.default.m_strDefaultCancelLabel;
			DialogData.fnCallback = DevDownloadableContentCheckOverride;
			DialogData.bMuteAcceptSound = true;

			Movie.Pres.UIRaiseDialog( DialogData );
		}
	}
	else
	{
		PlayConfirmSound();

		m_bLoadInProgress = true; //bsg-hlee (06.01.17): Should be placed here after all the fail checks. If not and it fails here then this will may not get reset and block loading of other saves.
		`ONLINEEVENTMGR.LoadGame(SaveID, ReadSaveGameComplete);

		// Show a progress dialog if the load is being completed asynchronously
		if( m_bLoadInProgress )
		{
			ProgressDialogData.strTitle = m_sLoadingInProgress;
			Movie.Pres.UIProgressDialog(ProgressDialogData);
		}
	}
}

simulated function ReadSaveGameComplete(bool bWasSuccessful)
{
	m_bLoadInProgress = false;

	// Close progress dialog
	Movie.Stack.PopFirstInstanceOfClass(class'UIProgressDialogue', false);

	if( bWasSuccessful )
	{
		// Close the load screen
		Movie.Stack.Pop(self);
	}
	else
	{
		`ONLINEEVENTMGR.ErrorMessageMgr.EnqueueError(SystemMessage_FailedLoad);

		// Reset this confirmation
		m_bPlayerHasConfirmedLosingProgress = false;
	}
}

simulated public function ProgressCheckCallback(Name eAction)
{
	if (eAction == 'eUIAction_Accept')
	{
		m_bPlayerHasConfirmedLosingProgress = true;
		OnAccept();
	}
	else
	{
		m_bPlayerHasConfirmedLosingProgress = false;
	}
}

simulated public function PlayMouseClickSoundCallback(Name eAction)
{
	PlayMouseClickSound();
}

simulated function PlayConfirmSound()
{
	// Play on sound mgr to use persistent sound object so that loading doesn't cut the sound off
	if (m_ConfirmSound != "")
	{
		`SOUNDMGR.PlayLoadedAkEvent(m_ConfirmSound);
	}
}

simulated function DevDownloadableContentCheckOverride(Name eAction)
{
	`ONLINEEVENTMGR.ErrorMessageMgr.HandleDialogActionErrorMsg(eAction);
	if (eAction == 'eUIAction_Accept')
	{
		PlayConfirmSound();
		`ONLINEEVENTMGR.LoadGame(GetSaveID(m_iCurrentSelection), ReadSaveGameComplete);
	}
	else
	{
		m_bLoadInProgress = false;
	}
}

simulated function DevVersionCheckOverride(Name eAction)
{
	if (eAction == 'eUIAction_Accept')
	{
		LoadSelectedSlot( true ); // call back into here ignoring the version, but doing the DLC check
	}
	else
	{
		m_bLoadInProgress = false;
	}
}

simulated function MissingDLCCheckCallback(Name eAction)
{
	m_bLoadInProgress = false;
}

simulated public function OnAccept(optional UIButton control)
{
	local TDialogueBoxData kDialogData;
	local string mapName;

	if(m_bLoadInProgress)
		return;

	if( control != None && control.Owner != None && UISaveLoadGameListItem(control.Owner.Owner) != None )
	{
		SetSelection(UISaveLoadGameListItem(control.Owner.Owner).Index);
	}

	mapName = WorldInfo.GetMapName();
	class'UIUtilities_Image'.static.StripSpecialMissionFromMapName( mapName );

	if (m_iCurrentSelection < 0 || m_iCurrentSelection >= m_arrSaveGames.Length )
	{
		PlayNegativeMouseClickSound();
	}
	else if (!m_bPlayerHasConfirmedLosingProgress && WorldInfo.GRI.GameClass.name != 'XComShell') //Do not verify while in shell. This is also a sad hack to be able to check for this. But so it be. 
	{
		PlayMouseClickSound();

		kDialogData.eType       = eDialog_Warning;
		kDialogData.strTitle    = m_strLostProgressTitle;
		kDialogData.strText     = m_strLostProgressBody;
		kDialogData.strAccept   = m_strLostProgressConfirm;
		kDialogData.strCancel   = class'UIDialogueBox'.default.m_strDefaultCancelLabel;	
		kDialogData.fnCallback  = ProgressCheckCallback;
		kDialogData.bMuteAcceptSound = true;

		Movie.Pres.UIRaiseDialog( kDialogData );
	}
	else if (m_arrSaveGames[m_iCurrentSelection].bIsCorrupt)
	{
		PlayMouseClickSound();

		//bsg-fchen (5.22.17): update the string to use the proper game save is corrupted string
		kDialogData.eType       = eDialog_Warning;
		kDialogData.strTitle    = m_sCorruptedSaveTitle;//"CORRUPTED SAVE";
		kDialogData.strText     = m_sCorruptedSave;//"This save game is corrupted and cannot be loaded."
		kDialogData.strAccept   = class'UIDialogueBox'.default.m_strDefaultAcceptLabel;
		kDialogData.fnCallback	= PlayMouseClickSoundCallback;
		kDialogData.bMuteAcceptSound = true;
		kDialogData.bMuteCancelSound = true;
		//bsg-fchen (5.22.17): end
		Movie.Pres.UIRaiseDialog( kDialogData );
	}
	else if (m_arrListItems[m_iCurrentSelection].bIsDifferentLanguage)
	{
		PlayMouseClickSound();

		kDialogData.eType       = eDialog_Warning;
		kDialogData.strTitle    = m_strSaveDifferentLanguage;			//"SAVE USED A DIFFERENT LANGUAGE";
		kDialogData.strText     = m_strSaveDifferentLanguageBody;		//"This save used a different language and may have some missing glyphs. Load anyway?";
		kDialogData.strAccept   = m_strLoadAnyway;
		kDialogData.strCancel   = class'UIDialogueBox'.default.m_strDefaultCancelLabel;	
		kDialogData.fnCallback  = DifferentLangSaveWarningCallback;
		kDialogData.bMuteAcceptSound = true;

		Movie.Pres.UIRaiseDialog( kDialogData );
	}
	else
	{
		LoadSelectedSlot();
	}
}


// Lower pause screen
simulated public function OnCancel()
{
	NavHelp.ClearButtonHelp();
	`ONLINEEVENTMGR.bInitiateReplayAfterLoad = false;
	PlayMouseClickSound();
	Movie.Stack.Pop(self);
}

simulated public function OnDelete(optional UIButton control)
{
	local TDialogueBoxData kDialogData;

	if( m_iCurrentSelection >= 0 && m_iCurrentSelection < m_arrSaveGames.Length )
	{
		PlayMouseClickSound();

		// Warn before deleting save
		kDialogData.eType     = eDialog_Warning;
		kDialogData.strTitle  = class'UISaveGame'.default.m_sDeleteSaveTitle;
		kDialogData.strText   = class'UISaveGame'.default.m_sDeleteSaveText @ GetCurrentSelectedFilename();
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

simulated function DeleteSaveWarningCallback(Name eAction)
{
	if (eAction == 'eUIAction_Accept')
	{
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
}

simulated function DeleteSelectedSaveFile()
{
	`ONLINEEVENTMGR.DeleteSaveGame( GetSaveID(m_iCurrentSelection) );
}

simulated function string GetCurrentSelectedFilename()
{
	local string SaveName;
	if(m_arrSaveGames[m_iCurrentSelection].SaveGames[0].SaveGameHeader.PlayerSaveDesc != "")
	{
		SaveName = m_arrSaveGames[m_iCurrentSelection].SaveGames[0].SaveGameHeader.PlayerSaveDesc;
	}
	else
	{
		SaveName = `ONLINEEVENTMGR.m_sEmptySaveString @ `ONLINEEVENTMGR.GetNextSaveID();
	}

	return SaveName;
}

simulated function ShowRefreshingListDialog(optional delegate<UIProgressDialogue.ProgressDialogOpenCallback> ProgressDialogOpenCallback=none)
{
	local TProgressDialogData kDialogData;

	kDialogData.strTitle = class'UISaveGame'.default.m_sRefreshingSaveGameList;
	Movie.Pres.UIProgressDialog(kDialogData);

	if(ProgressDialogOpenCallback != none)
	{
		ProgressDialogOpenCallback();
	}
}

simulated public function OnUDPadUp()
{
	local int numSaves;
	local int newSel;
	numSaves = GetNumSaves();

	newSel = m_iCurrentSelection - 1;
	if (newSel < 0)
		newSel = numSaves - 1;

	SetSelection( newSel );
}


simulated public function OnUDPadDown()
{
	local int numSaves;
	local int newSel;
	numSaves = GetNumSaves();

	newSel = m_iCurrentSelection + 1;
	if (newSel >= numSaves)
		newSel = 0;

	SetSelection( newSel );
}

simulated function SetTitle( string sTitle )
{
	local ASValue myValue;
	local Array<ASValue> myArray;

	myValue.Type = AS_String;

	myValue.s = sTitle;
	myArray.AddItem( myValue );

	Invoke("SetTitle", myArray);
}

simulated function SetSelected( int iTarget )
{
	if (iTarget >=0 && iTarget < List.GetItemCount())
	{
		Navigator.SetSelected(List.GetItem(iTarget));
	}
	else
	{
		Navigator.SetSelected(none);
	}
}

simulated function SetSelection(int currentSelection)
{
	local int i;
	if( currentSelection == m_iCurrentSelection )
	{
		return;
	}

	for (i = 0; i < m_arrListItems.Length; i++)
	{
		m_arrListItems[i].HideHighlight();  //bsg-jrebar (4.6.17): Hide all highlights
		m_arrListItems[i].OnLoseFocus();	
	}

	m_iCurrentSelection = currentSelection;
	
	if (m_iCurrentSelection < 0)
	{
		m_iCurrentSelection = GetNumSaves();
	}
	else if (m_iCurrentSelection > GetNumSaves())
	{
		m_iCurrentSelection = 0;
	}

	m_arrListItems[m_iCurrentSelection].ShowHighlight();

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

	//bsg-jneal (11.11.16): distributing the UISaveLoadGameListItem spawns across multiple frames as this would cause the game to freeze on longer save lists
	m_bInitSaveLoadListItems = true; // start adding the save/load list items in Tick()
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
				
				// mmg_aaron.lee (07/01/19) BEGIN - fix for save item list index
				m_arrListItems.AddItem(Spawn(class'UISaveLoadGameListItem', List.ItemContainer).InitSaveLoadItem(m_iListItemIndex, m_arrSaveGames[m_iListItemIndex], false, OnAccept, OnDelete, , SetSelection)); //bsg-jneal (3.15.17): fix for save item list index
				// mmg_aaron.lee (07/01/19) END - fix for save item list index

				m_arrListItems[m_iListItemIndex].ProcessMouseEvents(OnChildMouseEvent);
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

simulated function  int GetSaveID(int iIndex)
{
	if (iIndex >= 0 && iIndex < m_arrSaveGames.Length)
		return `ONLINEEVENTMGR.SaveNameToID(m_arrSaveGames[iIndex].Filename);

	return -1;      //  if it's not in the save game list it can't be loaded 
}

simulated function int GetNumSaves()
{
	return m_arrSaveGames.Length;
}

simulated function CoreImagesLoaded(object LoadedObject) 
{
	m_arrLoadedObjects.AddItem(LoadedObject);
	m_bLoadCompleteCoreMapImages = true;
	TestAllImagesLoaded(); 
}
simulated function DLC1ImagesLoaded(object LoadedObject) 
{
	m_arrLoadedObjects.AddItem(LoadedObject);
	m_bLoadCompleteDLC1MapImages = true;
	TestAllImagesLoaded(); 
}
simulated function DLC2ImagesLoaded(object LoadedObject) 
{
	m_arrLoadedObjects.AddItem(LoadedObject);
	m_bLoadCompleteDLC2MapImages = true;
	TestAllImagesLoaded(); 
}
simulated function HQAssaultImagesLoaded(object LoadedObject) 
{
	m_arrLoadedObjects.AddItem(LoadedObject);
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
	Movie.Pres.SetTimer( 0.2f, false, 'ImageCheck', self );
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
		mapTextureTest = Texture2D(DynamicLoadObject( mapImage, class'Texture2D'));
		
		if( mapTextureTest != none )
		{
			AS_ClearImage( i );
		}
	}
	
	AS_ReloadImages();
}

simulated function AS_Clear()
{
	Movie.ActionScriptVoid(screen.MCPath$".Clear");
}

simulated function AS_ReloadImages()
{
	Movie.ActionScriptVoid(screen.MCPath$".ReloadImages");
}

simulated function AS_ClearImage( int iIndex )
{
	Movie.ActionScriptVoid(screen.MCPath$".ClearImage");
}

event Destroyed()
{
	super.Destroyed();
	m_arrLoadedObjects.Length = 0;
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
		OnlineEventMgr.ClearSaveDeviceLostDelegate(OnSaveDeviceLost);
	}
}

//bsg-hlee (05.05.17): Moving over console changes for nav help.
//bsg-jneal (4.21.17): fixing extra navhelp showing after screen loses focus
simulated function UpdateNavHelp()
{
	NavHelp.ClearButtonHelp();
	NavHelp.AddBackButton(OnCancel);
	NavHelp.Show();
}

simulated function OnReceiveFocus()
{
	super.OnReceiveFocus();
	UpdateNavHelp();
}

simulated function OnLoseFocus()
{
	NavHelp.ClearButtonHelp();
	super.OnLoseFocus();
}
//bsg-jneal (4.21.17): end

DefaultProperties
{
	m_iCurrentSelection = 0;
	m_bLoadInProgress = false;

	Package = "/ package/gfxSaveLoad/SaveLoad";
	//MCName = "theScreen";

	InputState = eInputState_Evaluate;
	bConsumeMouseEvents=true

	m_bPlayerHasConfirmedLosingProgress=false;

	bAlwaysTick=true; // ensure this screen ticks when the game is paused

	m_bNeedsToLoadDLC1MapImages=false
	m_bNeedsToLoadDLC2MapImages=false 
	m_bLoadCompleteDLC1MapImages=false
	m_bLoadCompleteDLC2MapImages=false
	m_bLoadCompleteCoreMapImages=false
	
	bIsVisible = false; // This screen starts hidden
	bShowDuringCinematic = true;

	//bsg-jneal (11.11.16): distributing the UISaveLoadGameListItem spawns across multiple frames as this would cause the game to freeze on longer save lists
	m_bInitSaveLoadListItems=false;
	m_iListItemIndex = 0;
	//bsg-jneal (11.11.16): end
}
