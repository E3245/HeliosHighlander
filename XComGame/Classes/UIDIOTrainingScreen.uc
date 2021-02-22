//---------------------------------------------------------------------------------------
//  FILE:    	UISpecOpsScreen
//  AUTHOR:  	Brit Steiner 8/9/2019
//  PURPOSE: 	Choose a Spec Ops to start for the specified unit.
//           
//---------------------------------------------------------------------------------------
//  Copyright (c) 2019 Firaxis Games, Inc. All rights reserved.
//---------------------------------------------------------------------------------------
class UIDIOTrainingScreen extends UIScreen implements(UIDIOIconSwap);

var UIDIOHUD							DioHUD;
var UIList								OptionsList;
var UIButton							ConfirmButton;
var StateObjectReference				UnitRef;
var X2DioTrainingProgramTemplate		UnitCurrentTraining;
var bool								bUnitCanExecute;
var array<X2DioTrainingProgramTemplate>	AvailableTraining;
var array<name>							RawDataOptions;


var int									SelectedTrainingOption;

var localized string ScreenTitle;
var localized string ScreenTitleNoUnitSelected;
var localized string NoTrainingAvailableTitle;
var localized string NoTrainingAvailableText;
var localized string Confirm_BeginTraining;
var localized string Confirm_SwitchTraining;
var localized string Error_TrainingAlreadyInProgress; 
var localized string TagStr_UnitCompletedTraining;

//---------------------------------------------------------------------------------------


//---------------------------------------------------------------------------------------
//				INITIALIZATION
//---------------------------------------------------------------------------------------
simulated function InitScreen(XComPlayerController InitController, UIMovie InitMovie, optional name InitName)
{
	super.InitScreen(InitController, InitMovie, InitName);

	// mmg_aaron.lee (10/29/19) BEGIN - allow to edit through global.uci
	SetPanelScale(`ASSIGNMENTSCALER);
	SetPosition(`SCREENNAVILEFTOFFSET, `ASSIGNMENTTOPOFFSET);
	// mmg_aaron.lee (10/29/19) END

	OptionsList = Spawn(class'UIList', self).InitList('TrainingListMC', 67, 272, 449, 604); //forcing location and size, to try to combat weird squishing items. 
	OptionsList.bLoopSelection = true;
	OptionsList.bStickyClickyHighlight = true;
	OptionsList.OnSelectionChanged = OnSelectionChanged;
	OptionsList.OnItemClicked = OnItemClicked;
	OptionsList.bSelectFirstAvailable = true;
	OptionsList.OnSetSelectedIndex = OnSelectedIndexChanged;
	OptionsList.SetSelectedNavigation(); 

	if( `ISCONTROLLERACTIVE)
	{
		ConfirmButton = Spawn(class'UIButton', self).InitButton('trainingConfirmButton', class'UIUtilities_Text'.static.InjectImage(class'UIUtilities_Input'.static.GetGamepadIconPrefix() $ class'UIUtilities_Input'.const.ICON_A_X, 20, 20, 0) @ class'UIUtilities_Text'.default.m_strGenericConfirm, OnConfirm);
	}
	else
	{
		ConfirmButton = Spawn(class'UIButton', self).InitButton('trainingConfirmButton', class'UIUtilities_Text'.default.m_strGenericConfirm, OnConfirm);
	}
	ConfirmButton.Hide();
	ConfirmButton.SetGood(true);

	UpdateNavHelp();

	// HELIOS BEGIN
	// Move the refresh camera function to presentation base
	`PRESBASE.RefreshCamera(class'XComStrategyPresentationLayer'.const.TrainingAreaTag);
	// HELIOS END
}

simulated function OnInit()
{
	super.OnInit();

	DisplayOptions();
	OnItemClicked(OptionsList, 0);
	ShowCompletedTrainingPopups();

	UpdateNavHelp();
}

//---------------------------------------------------------------------------------------
simulated function BuildOption(name DataName, XComGameState_Unit Unit)
{
	local X2DioTrainingProgramTemplate TrainingProgramTemplate;
	local UIDIOTrainingListItem ListItem;

	TrainingProgramTemplate = X2DioTrainingProgramTemplate(`STRAT_TEMPLATE_MGR.FindStrategyElementTemplate(DataName));
	if(TrainingProgramTemplate == none)
	{
		return;
	}

	ListItem = GetListItemForTraining(TrainingProgramTemplate.DataName);
	ListItem.SetTraining(name(string(TrainingProgramTemplate.DataName)));

	if ( Unit != none && !TrainingProgramTemplate.CanStartNow(Unit))
	{
		ListItem.SetDisabled(true);
	}
	else
	{
		ListItem.SetDisabled(false);
	}
}

simulated function UIDIOTrainingListItem GetListItemForTraining(name DataName)
{
	local UIDIOTrainingListItem ListItem, NewListItem;

	ListItem = UIDIOTrainingListItem(OptionsList.GetItemMCNamed(name("TrainingListItem_" $ DataName)));
	if( ListItem != none ) return ListItem;

	NewListItem = UIDIOTrainingListItem(OptionsList.CreateItem(class'UIDIOTrainingListItem'));
	NewListItem.InitTrainingListItem(name("TrainingListItem_" $ DataName));
	NewListItem.OnMouseEventDelegate = OptionsList.OnChildMouseEvent;

	return NewListItem;
}

//---------------------------------------------------------------------------------------
simulated function DisplayOptions()
{
	local XComGameState_HeadquartersDio DioHQ;
	local XComGameState_Unit Unit;
	local name TrainingProgramName;

	OptionsList.ClearItems();

	if (UnitRef.ObjectID > 0)
	{
		// Unit-based options
		Unit = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(UnitRef.ObjectID));
		RawDataOptions = Unit.AvailableTrainingPrograms;

		// Append Specialty Training from DioHQ not already known
		DioHQ = `DIOHQ;
		foreach DioHQ.UnlockedUniversalTraining(TrainingProgramName)
		{
			if (Unit.CompletedTrainingPrograms.Find(TrainingProgramName) == INDEX_NONE)
			{
				RawDataOptions.AddItem(TrainingProgramName);
			}
		}

		RawDataOptions.Sort(SortTrainings);
	}
	else
	{
		RawDataOptions.Length = 0;
	}

	Refresh();
}

//---------------------------------------------------------------------------------------
simulated function int SortTrainings(name TargetA, name TargetB)
{
	local X2DioTrainingProgramTemplate TrainingA, TrainingB;

	TrainingA = X2DioTrainingProgramTemplate(`STRAT_TEMPLATE_MGR.FindStrategyElementTemplate(TargetA));
	TrainingB = X2DioTrainingProgramTemplate(`STRAT_TEMPLATE_MGR.FindStrategyElementTemplate(TargetB));

	if (TrainingA.Category == 'Scar' && TrainingB.Category != 'Scar')
		return -1;
	else if (TrainingB.Category == 'Scar' && TrainingA.Category != 'Scar')
		return 1;

	return 0;
}

//---------------------------------------------------------------------------------------
simulated function Refresh()
{
	local name OptionName;
	local XComGameState_Unit Unit;
	local XComGameState_StrategyAction UnitAssignedAction;

	// HELIOS BEGIN
	// Replace the hard reference with a reference to the main HUD	
	DioHUD = UIDIOHUD(`SCREENSTACK.GetScreen(`PRESBASE.UIHUD_Strategy));
	// HELIOS END	
	DioHUD.UpdateResources(self);

	Unit = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(UnitRef.ObjectID));
	if( Unit != none )
	{
		// Bringing back inclusion of current training [1/21/2020 dmcdonough]
		UnitAssignedAction = Unit.GetAssignedAction();
		if (UnitAssignedAction.GetMyTemplateName() == 'HQAction_Train')
		{
			UnitCurrentTraining = X2DioTrainingProgramTemplate(`STRAT_TEMPLATE_MGR.FindStrategyElementTemplate(UnitAssignedAction.TargetName));
		}

		AS_SetScreenInfo(class'UIUtilities_Text'.static.CapsCheckForGermanScharfesS(ScreenTitle), class'UIUtilities_Text'.static.CapsCheckForGermanScharfesS(Unit.GetName(eNameType_Full)), Unit.GetWorkerIcon());
	}
	else
	{
		AS_SetScreenInfo(class'UIUtilities_Text'.static.CapsCheckForGermanScharfesS(ScreenTitleNoUnitSelected), "", "");
	}
	
	//OptionsList.ClearItems();

	foreach RawDataOptions(OptionName)
	{
		BuildOption(OptionName, Unit);
	}

	if (SelectedTrainingOption < 0 || SelectedTrainingOption > OptionsList.ItemCount)
	{
		OptionsList.SetSelectedIndex(0);
		SelectedTrainingOption = 0;
	}
	else
	{
		OptionsList.SetSelectedIndex(SelectedTrainingOption);
	}

	RefreshDescription();
}

//---------------------------------------------------------------------------------------
function RefreshDescription()
{
	local X2DioTrainingProgramTemplate TrainingTemplate;
	local XComGameState_Unit Unit;
	local XComGameState_StrategyAction UnitAction;
	//local array<string> PrereqStrings;
	local array<string> CostStrings;
	local string FormattedString, TempString, NameString, EffectString;// , PrereqString;
	local int index;

	// Clear out the subheader infos 
	MC.FunctionVoid("ClearInfo");

	Unit = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(UnitRef.ObjectID));
	if (Unit == none)
	{
		ConfirmButton.SetText(`DIO_UI.default.strStatus_NeedToSelectUnit);
		ConfirmButton.Show();
		return;
	}

	// Early out: unit has no training available
	if (RawDataOptions.Length == 0)
	{
		ConfirmButton.Hide();
		AS_UpdateInfoPanel(0, NoTrainingAvailableTitle, NoTrainingAvailableText, "");
		return;
	}

	UIDIOTrainingListItem(OptionsList.GetSelectedItem()).RefreshSelectionState(false);
	SelectedTrainingOption = OptionsList.SelectedIndex;
	UIDIOTrainingListItem(OptionsList.GetSelectedItem()).RefreshSelectionState(true);

	TrainingTemplate = X2DioTrainingProgramTemplate(`STRAT_TEMPLATE_MGR.FindStrategyElementTemplate(RawDataOptions[SelectedTrainingOption]));
	if (TrainingTemplate == none)
	{
		return;
	}

	index = 0;
	// -----------------------------------------------------------
	// Operation Name, narrative, and icon 
	NameString = TrainingTemplate.GetDisplayNameString(, Unit);
	// Prefix if this is the unit's active training
	if (TrainingTemplate == UnitCurrentTraining)
	{
		TempString = `DIO_UI.static.FormatTimeIcon(UIDIOTrainingListItem(OptionsList.GetSelectedItem()).GetTurnsRemaining());
		NameString @= "\n(" $ TempString $ ")";
	}

	AS_UpdateInfoPanel(index++,
		NameString,
		TrainingTemplate.GetDescription(, Unit),
		""); //  SpecOpsTemplate.Image ); //disabling image until we have final art. 
	// -----------------------------------------------------------
	// Prereqs
	/*PrereqStrings = TrainingTemplate.GetPrereqStrings();
	FormattedString = "";
	if( PrereqStrings.Length > 0 )
	{
		foreach PrereqStrings(PrereqString)
		{
			if( FormattedString != "" )
			{
				//Don't put a break before any other info
				FormattedString $= "<br>";
			}
			FormattedString $= PrereqString;
		}

		AS_UpdateInfoPanel(1, `DIO_UI.default.strTerm_Required, FormattedString);
	}*/

	// -----------------------------------------------------------
	// Cost & Duration
	FormattedString = "";
	if (TrainingTemplate == UnitCurrentTraining)
	{
		UnitAction = Unit.GetAssignedAction();
		FormattedString = `DIO_UI.static.FormatDaysRemaining(UnitAction.GetTurnsUntilComplete());
		AS_UpdateInfoPanel(index++, `DIO_UI.default.strTerm_Status, FormattedString);
	}
	else
	{
		TempString = TrainingTemplate.GetCostString();
		if (TempString != "")
		{
			CostStrings.AddItem(TempString);
		}
		TempString = TrainingTemplate.GetDurationString();
		if (TempString != "")
		{
			CostStrings.AddItem(TempString);
		}
		if (CostStrings.Length > 0)
		{
			foreach CostStrings(TempString)
			{
				if (FormattedString != "")
				{
					//Don't put a break before any other info 
					FormattedString $= "<br>";
				}
				FormattedString $= TempString;
			}
			AS_UpdateInfoPanel(index++, `DIO_UI.default.strTerm_Cost, FormattedString);
		}
	}

	// -----------------------------------------------------------
	// Effects
	EffectString = TrainingTemplate.GetEffectsString();
	if (EffectString != "")
	{
		EffectString = "<Bullet/>" @ EffectString;
		AS_UpdateInfoPanel(index++, `DIO_UI.default.strTerm_Rewards, `XEXPAND.ExpandString(EffectString));
	}

	// -----------------------------------------------------------
	// Confirm button 
	if (Unit != none)
	{
		// Can start? Must not already be in progress and affordable
		if (TrainingTemplate == UnitCurrentTraining)
		{
			DisplayErrorMessage(class'UIUtilities_Text'.static.GetColoredText( Error_TrainingAlreadyInProgress, eUIState_Warning));
			ConfirmButton.Hide();
			bUnitCanExecute = false;
		}
		else if (!TrainingTemplate.CanStartNow(Unit, TempString))
		{
			if (TempString != "")
			{
				//TODO: INJECT [a] icon 
				DisplayErrorMessage(TempString);
			}
			ConfirmButton.Hide();
			bUnitCanExecute = false;
		}
		else
		{
			if( UnitCurrentTraining == none )
			{
				ConfirmButton.SetText(Confirm_BeginTraining);
			}
			else
			{
				ConfirmButton.SetText(Confirm_SwitchTraining);
			}
			ConfirmButton.Show();
			DisplayErrorMessage("");

			bUnitCanExecute = true;
		}
	}
}

//---------------------------------------------------------------------------------------
simulated function DeselectUnit()
{
	UnitRef.ObjectID = 0;
	DisplayOptions();
	UpdateNavHelp();
}

//---------------------------------------------------------------------------------------
simulated function ShowCompletedTrainingPopups()
{
	local XComGameStateHistory History;
	local XComGameState_HeadquartersDio DioHQ;
	local XComGameState_Unit Unit;
	local XComGameState_StrategyAction TrainingAction;
	local X2DioTrainingProgramTemplate TrainingTemplate;
	local string PopupTitle, PopupBody;
	local XGParamTag LocTag;
	local int i, k;

	History = `XCOMHISTORY;
	DioHQ = `DIOHQ;
	for (i = 0; i < DioHQ.Squad.Length; ++i)
	{
		Unit = XComGameState_Unit(History.GetGameStateForObjectID(DioHQ.Squad[i].ObjectID));
		if (Unit.UnseenCompletedTrainingActions.Length == 0)
		{
			continue;
		}

		for (k = 0; k < Unit.UnseenCompletedTrainingActions.Length; ++k)
		{
			TrainingAction = XComGameState_StrategyAction(History.GetGameStateForObjectID(Unit.UnseenCompletedTrainingActions[k].ObjectID));
			if (TrainingAction == none)
			{
				continue;
			}

			TrainingTemplate = X2DioTrainingProgramTemplate(`STRAT_TEMPLATE_MGR.FindStrategyElementTemplate(TrainingAction.TargetName));
			if (TrainingTemplate == none)
			{
				continue;
			}

			LocTag = XGParamTag(`XEXPANDCONTEXT.FindTag("XGParam"));
			LocTag.StrValue0 = Unit.GetNickName(true);
			LocTag.StrValue1 = TrainingTemplate.GetDisplayNameString(, Unit);
			PopupTitle = `XEXPAND.ExpandString(default.TagStr_UnitCompletedTraining);

			PopupBody = TrainingTemplate.GetEffectsString();
			`STRATPRES.UIWarningDialog(PopupTitle, PopupBody, eDialog_NormalWithImage, Unit.GetSoldierClassTemplate().WorkerIconImage);
		}

		// Clear
		class'DioStrategyNotificationsHelper'.static.SubmitClearUnseenTrainingPrograms(Unit.GetReference());
	}
}

//---------------------------------------------------------------------------------------
function AS_UpdateInfoPanel( int index, string title, string body, string imagePath = "" )
{
	MC.BeginFunctionOp("UpdateInfoPanel");
	MC.QueueNumber(index);
	MC.QueueString(title);
	MC.QueueString(body); 
	MC.QueueString(imagePath);
	MC.EndOp();
}

function AS_SetScreenInfo(string title, string body, string portraitImagePath = "")
{
	MC.BeginFunctionOp("SetScreenInfo");
	MC.QueueString(title);
	MC.QueueString(body);
	MC.QueueString(portraitImagePath);
	MC.EndOp();
}

function DisplayErrorMessage(string body)
{
	MC.BeginFunctionOp("DisplayErrorMessage");
	MC.QueueString(body);
	MC.EndOp();
}


//---------------------------------------------------------------------------------------
function bool CanConfirm()
{
	local XComGameState_Unit trainingUnit;

	trainingUnit = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(UnitRef.ObjectID));
	if (trainingUnit == none)
	{
		return true;
	}
	else if(!bUnitCanExecute)
	{
		return false;
	}

	return SelectedTrainingOption >= 0;
}


//---------------------------------------------------------------------------------------
//				INPUT
//---------------------------------------------------------------------------------------

function OnConfirm(UIButton Button)
{
	local XComGameState_Unit Unit;
	local UIDIOStrategyMap_AssignmentBubble Bubble;

	Unit = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(UnitRef.ObjectID));

	if (Unit == none)
	{
		PlayMouseClickSound();
		Bubble = DioHUD.m_ScreensNav.GetBubbleAssignedTo('Train');
		if( Bubble != none )
		{
			Bubble.WorkerSlotClicked(0);
		}
	}
	else
	{
		if (class'DioStrategyAI'.static.IsAgentAssignmentChangeDestructive(UnitRef, 'Train'))
		{
			PlayMouseClickSound();
			Unit = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(UnitRef.ObjectID));
			`STRATPRES.UIConfirmSwitchDutyAssignment(Unit, 'Train', OnSwitchDutyConfirm);
		}
		else
		{
			CommitSelection();
		}
	}
}

function OnSwitchDutyConfirm(Name eAction, UICallbackData xUserData)
{
	if (eAction == 'eUIAction_Accept')
	{
		`SOUNDMGR.PlayLoadedAkEvent(class'UIDIOStrategyMap_AssignmentBubble'.default.AssignAgentSound, self);
		CommitSelection();
	}
}

// FINALLY submit the action and assignment change
function CommitSelection()
{
	local X2StrategyGameRuleset StratRules;
	local name Selection;

	PlayConfirmSound();

	StratRules = `STRATEGYRULES;

	if (SelectedTrainingOption >= 0 && SelectedTrainingOption < RawDataOptions.Length)
	{
		Selection = RawDataOptions[SelectedTrainingOption];

		StratRules.SubmitTrainingAction(UnitRef, Selection);
		StratRules.SubmitAssignAgentDuty(UnitRef, 'Train');
	}

	Refresh();
}
//---------------------------------------------------------------------------------------
simulated function OnSelectedIndexChanged(UIList ContainerList, int ItemIndex)
{
	RefreshDescription();
	ConfirmButton.SetDisabled(!CanConfirm());
}

function OnSelectionChanged(UIList ContainerList, int ItemIndex)
{
	if (`ISCONTROLLERACTIVE)
	{
		RefreshDescription();
		ConfirmButton.SetDisabled(!CanConfirm());
	}
}

function OnItemClicked(UIList ContainerList, int ItemIndex)
{
	RefreshDescription();
	ConfirmButton.SetDisabled(!CanConfirm());
}

function OnBackClicked()
{
	/*if (UnitRef.ObjectID > 0)
	{
		DeselectUnit();
		OptionsList.ClearItems();
		DisplayErrorMessage("");
	}
	else
	{*/
		CloseScreen();
	//}
}

//---------------------------------------------------------------------------------------
function UpdateNavHelp()
{
	DioHUD.NavHelp.ClearButtonHelp();
	DioHUD.NavHelp.AddBackButton(OnBackClicked);

	// mmg_john.hawley (11/7/19) - Updating NavHelp
	if (`ISCONTROLLERACTIVE)
	{
		DioHUD.NavHelp.AddSelectNavHelp(); // mmg_john.hawley (11/5/19) - Updating NavHelp for new controls
		DioHUD.NavHelp.AddLeftHelp(Caps(class'UIDIOStrategyMapFlash'.default.m_strOpenAssignment), class'UIUtilities_Input'.static.GetGamepadIconPrefix() $ class'UIUtilities_Input'.const.ICON_X_SQUARE);
		// Unused [2/27/2020 dmcdonough]
		//DioHUD.NavHelp.AddLeftHelp(Caps(class'UIDIOStrategyScreenNavigation'.default.SelectHQAreaLabel), class'UIUtilities_Input'.static.GetGamepadIconPrefix() $ class'UIUtilities_Input'.const.ICON_LBRB_L1R1);
	}
}

//---------------------------------------------------------------------------------------
simulated function bool OnUnrealCommand(int cmd, int arg)
{
	local bool bInputConsumed;

	// Only pay attention to presses or repeats; ignoring other input types
	if (!CheckInputIsReleaseOrDirectionRepeat(cmd, arg))
		return false;

	if (DioHUD.m_WorkerTray.bIsVisible)
	{
		return DioHUD.m_WorkerTray.OnUnrealCommand(cmd, arg);
	}

	bInputConsumed = OptionsList.OnUnrealCommand(cmd, arg);

	switch (cmd)
	{
	case class'UIUtilities_Input'.const.FXS_BUTTON_A :
	case class'UIUtilities_Input'.const.FXS_KEY_ENTER :
	case class'UIUtilities_Input'.const.FXS_KEY_SPACEBAR :
		
		ConfirmButton.Click();
		bInputConsumed = true;
		break;
		
	case class'UIUtilities_Input'.const.FXS_BUTTON_B :
	case class'UIUtilities_Input'.const.FXS_KEY_ESCAPE :
	case class'UIUtilities_Input'.const.FXS_R_MOUSE_DOWN :
		PlayMouseClickSound();
		OnBackClicked();
		bInputConsumed = true;
		break;

	default:
		break;
	}

	if (!bInputConsumed)
	{
		return Super.OnUnrealCommand(cmd, arg);
	}

	return bInputConsumed;
}


//---------------------------------------------------------------------------------------

function bool SimulateScreenInteraction()
{
	local XComGameState_Unit Unit;

	Unit = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(UnitRef.ObjectID));

	if( Unit == none )
	{
		CloseScreen();
	}
	else
	{
		OnConfirm(ConfirmButton);
	}
	return true;
}

// mmg_john.hawley (11/13/19) - Update NavHelp when player swaps input device
simulated function OnReceiveFocus()
{
	Refresh();

	super.OnReceiveFocus();

	UpdateNavHelp();
}

// mmg_john.hawley (12/9/19) - Update NavHelp ++ 
function IconSwapPlus(bool IsMouse)
{
	if (`SCREENSTACK.IsTopScreen(self))
	{
		UpdateNavHelp();
	}
}

// ===========================================================================
//  DEFAULTS:
// ===========================================================================
defaultproperties
{
	Package = "/ package/gfxTraining/Training";
	MCName = "theScreen";

	bHideOnLoseFocus = false;
	bAnimateOnInit = true;
	bProcessMouseEventsIfNotFocused = false;
	SelectedTrainingOption = 0;
}
