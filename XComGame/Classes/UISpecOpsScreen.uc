//---------------------------------------------------------------------------------------
//  FILE:    	UISpecOpsScreen
//  AUTHOR:  	Brit Steiner 8/9/2019
//  PURPOSE: 	Choose a Spec Ops to start for the specified unit.
//           
//---------------------------------------------------------------------------------------
//  Copyright (c) 2019 Firaxis Games, Inc. All rights reserved.
//---------------------------------------------------------------------------------------
class UISpecOpsScreen extends UIScreen implements(UIDIOIconSwap);

var UIDIOHUD							DioHUD;
var UIList								OptionsList;
var UIButton							ConfirmButton;
var StateObjectReference				UnitRef;
var bool								bCanConfirm;
var array<X2DioSpecOpsTemplate>			AvailableSpecOps;
var array<name>							RawDataOptions;


var int									SelectedSpecOpsOption;

var localized string ScreenTitle;
var localized string ScreenTitleNoUnitSelected;
var localized string m_strPreviousAssignmentBubble;
var localized string m_strNextAssignmentBubble;
var localized string Confirm_BeginOperation;
var localized string Confirm_SwitchOperation;
var localized string Error_OperationAlreadyInProgress;
var localized string TagStr_UnitCompletedSpecOp;
var localized string TagStr_UnitCompletedSpecOpRewards;

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

	OptionsList = Spawn(class'UIList', self).InitList('SpecOpsListContainer', 75.5, 265.1, 453, 616); //forcing location and size, to try to combat weird squishing items. 
	OptionsList.bLoopSelection = true;
	OptionsList.bStickyClickyHighlight = true;
	OptionsList.OnSelectionChanged = OnSelectionChanged;
	OptionsList.OnItemClicked = OnItemClicked;
	OptionsList.bSelectFirstAvailable = true;
	OptionsList.OnSetSelectedIndex = OnSelectedIndexChanged;
	OptionsList.SetSelectedNavigation(); 

	if( `ISCONTROLLERACTIVE)
	{
		ConfirmButton = Spawn(class'UIButton', self).InitButton('specOpsConfirmButton', class'UIUtilities_Text'.static.InjectImage(class'UIUtilities_Input'.static.GetGamepadIconPrefix() $ class'UIUtilities_Input'.const.ICON_A_X, 20, 20, 0) @ class'UIUtilities_Text'.default.m_strGenericConfirm, OnConfirm);
	}
	else
	{
		ConfirmButton = Spawn(class'UIButton', self).InitButton('specOpsConfirmButton', class'UIUtilities_Text'.default.m_strGenericConfirm, OnConfirm);
	}
	/*ConfirmButton.SetWidth(378);
	ConfirmButton.SetX(414.85);
	ConfirmButton.SetY(836.25);*/
	ConfirmButton.SetGood(true);
	ConfirmButton.Hide();

	UpdateNavHelp();

	// HELIOS BEGIN	
	`PRESBASE.RefreshCamera(class'XComStrategyPresentationLayer'.const.SpecOpsAreaTag);
	// HELIOS END
	
}

simulated function OnInit()
{
	super.OnInit();

	ShowCompletedSpecOpsPopups();
	UpdateNavHelp();
}

//---------------------------------------------------------------------------------------
simulated function BuildOption(name DataName, optional XComGameState_Unit Unit)
{
	local X2DioSpecOpsTemplate SpecOpsTemplate;
	local UISpecOpsListItem ListItem;

	SpecOpsTemplate = X2DioSpecOpsTemplate(`STRAT_TEMPLATE_MGR.FindStrategyElementTemplate(DataName));
	if( SpecOpsTemplate == none )
	{
		return;
	}

	ListItem = GetListItemForSpecOp(SpecOpsTemplate.DataName);
	ListItem.SetOperation(name(string(SpecOpsTemplate.DataName)));

	if (!CanStartSpecOpsNow(SpecOpsTemplate, Unit))
	{
		ListItem.SetDisabled(true);
	}
	else
	{
		ListItem.SetDisabled(false);
	}
}

simulated function UISpecOpsListItem GetListItemForSpecOp(name DataName)
{
	local UISpecOpsListItem ListItem, NewListItem;

	ListItem = UISpecOpsListItem(OptionsList.GetItemMCNamed(name("SpecOpsListItem_" $ DataName)));
	if( ListItem != none ) return ListItem;

	NewListItem = UISpecOpsListItem(OptionsList.CreateItem(class'UISpecOpsListItem'));
	NewListItem.InitSpecOpsListItem(name("SpecOpsListItem_" $ DataName));
	NewListItem.OnMouseEventDelegate = OptionsList.OnChildMouseEvent;

	return NewListItem;
}

//---------------------------------------------------------------------------------------
simulated function DisplayOptions(array<name> InOptions)
{
	RawDataOptions = InOptions;
	RawDataOptions.Sort(SortSpecOps);
	Refresh();
}
//---------------------------------------------------------------------------------------
simulated function Refresh()
{
	local name OptionName;
	local XComGameState_Unit Unit;

	// HELIOS BEGIN
	// Replace the hard reference with a reference to the main HUD	
	DioHUD = UIDIOHUD(`SCREENSTACK.GetScreen(`PRESBASE.UIHUD_Strategy));
	// HELIOS END	
	DioHUD.UpdateResources(self);

	Unit = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(UnitRef.ObjectID));
	if (Unit != none)
	{
		AS_SetScreenInfo(ScreenTitle, `MAKECAPS(Unit.GetName(eNameType_Full)), Unit.GetWorkerIcon());
	}
	else
	{
		AS_SetScreenInfo(class'UIDioStrategyMap_AssignmentBubble'.default.Title_SpecOps, "", "");
	}

	foreach RawDataOptions(OptionName)
	{
		BuildOption(OptionName, Unit);
	}

	if (SelectedSpecOpsOption < 0 || SelectedSpecOpsOption > OptionsList.GetItemCount())
	{
		SelectedSpecOpsOption = 0;
	}

	OptionsList.SetSelectedIndex(SelectedSpecOpsOption);
	RefreshDescription();
}

//---------------------------------------------------------------------------------------
function RefreshDescription()
{
	local X2DioSpecOpsTemplate SpecOpsTemplate, UnitCurrentSpecOpsTemplate;
	local XComGameState_Unit Unit;
	local XComGameState_StrategyAction UnitAction;
	local array<string> PrereqStrings;
	local array<string> CostStrings;
	local string FormattedString, NameString, TempString, EffectString, PrereqString;

	// Clear out the subheader infos 
	MC.FunctionVoid("ClearInfo");

	if( OptionsList.SelectedIndex < 0 )
	{
		return;
	}
	
	UISpecOpsListItem(OptionsList.GetSelectedItem()).RefreshSelectionState(false);
	SelectedSpecOpsOption = OptionsList.SelectedIndex;
	UISpecOpsListItem(OptionsList.GetSelectedItem()).RefreshSelectionState(true);

	SpecOpsTemplate = X2DioSpecOpsTemplate(`STRAT_TEMPLATE_MGR.FindStrategyElementTemplate(UISpecOpsListItem(OptionsList.GetSelectedItem()).DataName));
	if( SpecOpsTemplate == none )
	{
		return;
	}

	Unit = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(UnitRef.ObjectID));
	if (Unit != none)
	{
		UnitAction = Unit.GetAssignedAction();
		if (UnitAction.GetMyTemplateName() == 'HQAction_SpecOps')
		{
			UnitCurrentSpecOpsTemplate = X2DioSpecOpsTemplate(`STRAT_TEMPLATE_MGR.FindStrategyElementTemplate(UnitAction.TargetName));
		}
	}

	// -----------------------------------------------------------
	// Operation Name, narrative, and icon 
	NameString = SpecOpsTemplate.DisplayName;
	// Prefix if this is the unit's active spec op
	if (SpecOpsTemplate == UnitCurrentSpecOpsTemplate)
	{
		TempString = `MAKECAPS(`DIO_UI.default.strTerm_InProgress);
		NameString $= "\n(" $`DIO_UI.static.FormatTimeIcon(UnitAction.GetTurnsUntilComplete()) $ ")";
	}
	AS_UpdateInfoPanel(0,
					   NameString,
					   SpecOpsTemplate.GetDescription(),
					   ""); //  SpecOpsTemplate.Image ); //disabling image until we have final art. 


	// -----------------------------------------------------------
	// Prereqs
	PrereqStrings = SpecOpsTemplate.GetPrereqStrings();
	FormattedString = ""; 
	if( PrereqStrings.Length > 0 )
	{
		foreach PrereqStrings(PrereqString)
		{
			if( FormattedString != "" )
			{
				//Don't put a break before any other info 
				FormattedString $= "\n";
			}
			FormattedString $= PrereqString;
		}

		AS_UpdateInfoPanel(1, `DIO_UI.default.strTerm_Required, FormattedString);
	}


	// -----------------------------------------------------------
	// Cost & Duration
	FormattedString = "";
	TempString = SpecOpsTemplate.GetCostString();
	if (TempString != "")
	{
		CostStrings.AddItem(TempString);
	}
	TempString = SpecOpsTemplate.GetDurationString();
	if (TempString != "")
	{
		CostStrings.AddItem(TempString);
	}
	if (CostStrings.Length > 0)
	{
		foreach CostStrings(TempString)
		{
			if( FormattedString != "" )
			{
				//Don't put a break before any other info 
				FormattedString $= "\n";
			}
			FormattedString $= TempString;
		}
		AS_UpdateInfoPanel(2, `DIO_UI.default.strTerm_Cost, FormattedString);
	}
	
	// -----------------------------------------------------------
	// Effects
	EffectString = SpecOpsTemplate.GetEffectsString();
	if (EffectString != "")
	{
		EffectString = "<Bullet/>" $ EffectString;
		AS_UpdateInfoPanel(3, `DIO_UI.default.strTerm_Rewards, `XEXPAND.ExpandString(EffectString));
	}


	// -----------------------------------------------------------
	// Confirm button 
	bCanConfirm = CanStartSpecOpsNow(SpecOpsTemplate, Unit, TempString);

	// Can start? Must not already be in progress and affordable
	if( UISpecOpsListItem(OptionsList.GetSelectedItem()).bIsInProgress )
	{

		//TODO: do we want to change the confirm to a yellow "remove from duty?" button in this case? 
		DisplayErrorMessage(class'UIUtilities_Text'.static.GetColoredText(Error_OperationAlreadyInProgress, eUIState_Warning));
		ConfirmButton.Hide();
	}
	else if (!bCanConfirm)
	{
		ConfirmButton.Hide();
		MC.FunctionString("DisplayErrorMessage", TempString);
	}
	else
	{
		if (Unit != none)
		{
			if( UnitCurrentSpecOpsTemplate == none )
			{
				ConfirmButton.SetText(Confirm_BeginOperation);
			}
			else
			{
				ConfirmButton.SetText(Confirm_SwitchOperation);
			}

			ConfirmButton.SetDisabled(false);
			ConfirmButton.Show();

			MC.FunctionString("DisplayErrorMessage", "");
		}
		else
		{
			ConfirmButton.SetText(`DIO_UI.default.strStatus_NeedToSelectUnit);
			ConfirmButton.Show();

			MC.FunctionString("DisplayErrorMessage", "");
		}
	}
}

//---------------------------------------------------------------------------------------
function bool CanStartSpecOpsNow(X2DioSpecOpsTemplate SpecOpsTemplate, optional XComGameState_Unit Unit, optional out string TipString)
{
	local XComGameState_StrategyAction UnitAction;
	local X2DioSpecOpsTemplate UnitCurrentSpecOpsTemplate;

	if (Unit != none)
	{
		UnitAction = Unit.GetAssignedAction();
		if (UnitAction.GetMyTemplateName() == 'HQAction_SpecOps')
		{
			UnitCurrentSpecOpsTemplate = X2DioSpecOpsTemplate(`STRAT_TEMPLATE_MGR.FindStrategyElementTemplate(UnitAction.TargetName));
		}

		if (UnitCurrentSpecOpsTemplate == SpecOpsTemplate)
		{
			return false;
		}
		if (!SpecOpsTemplate.CanUnitExecute(Unit, TipString))
		{
			return false;
		}
	}
	if (!SpecOpsTemplate.ArePrereqsMet(false,TipString))
	{
		return false;
	}
	if (!SpecOpsTemplate.CanAfford())
	{
		TipString = `DIO_UI.default.strStatus_NotEnoughResourcesGeneric;
		return false;
	}
	
	return true;
}

//---------------------------------------------------------------------------------------
simulated function ShowCompletedSpecOpsPopups()
{
	local XComGameStateHistory History;
	local XComGameState_HeadquartersDio DioHQ;
	local XComGameState_Unit Unit;
	local XComGameState_StrategyAction SpecOpsAction;
	local X2DioSpecOpsTemplate SpecOpsTemplate;
	local string PopupTitle, PopupBody;
	local XGParamTag LocTag;
	local int i, k;

	History = `XCOMHISTORY;
	DioHQ = `DIOHQ;
	for (i = 0; i < DioHQ.Squad.Length; ++i)
	{
		Unit = XComGameState_Unit(History.GetGameStateForObjectID(DioHQ.Squad[i].ObjectID));
		if (Unit.UnseenCompletedSpecOpsActions.Length == 0)
		{
			continue;
		}

		for (k = 0; k < Unit.UnseenCompletedSpecOpsActions.Length; ++k)
		{
			SpecOpsAction = XComGameState_StrategyAction(History.GetGameStateForObjectID(Unit.UnseenCompletedSpecOpsActions[k].ObjectID));
			if (SpecOpsAction == none)
			{
				continue;
			}

			SpecOpsTemplate = X2DioSpecOpsTemplate(`STRAT_TEMPLATE_MGR.FindStrategyElementTemplate(SpecOpsAction.TargetName));
			if (SpecOpsTemplate == none)
			{
				continue;
			}

			LocTag = XGParamTag(`XEXPANDCONTEXT.FindTag("XGParam"));
			LocTag.StrValue0 = Unit.GetNickName(true);
			LocTag.StrValue1 = SpecOpsTemplate.DisplayName;
			PopupTitle = `XEXPAND.ExpandString(default.TagStr_UnitCompletedSpecOp);

			LocTag = XGParamTag(`XEXPANDCONTEXT.FindTag("XGParam"));
			LocTag.StrValue0 = SpecOpsTemplate.GetEffectsString();
			PopupBody = `XEXPAND.ExpandString(default.TagStr_UnitCompletedSpecOpRewards);
			`STRATPRES.UIWarningDialog(PopupTitle, PopupBody, eDialog_NormalWithImage, Unit.GetSoldierClassTemplate().WorkerIconImage);
		}

		// Clear
		class'DioStrategyNotificationsHelper'.static.SubmitClearUnseenSpecOpsPrograms(Unit.GetReference());
	}
}

//---------------------------------------------------------------------------------------
simulated function DeselectUnit()
{
	UnitRef.ObjectID = 0;
	DisplayOptions(`DIOHQ.UnlockedSpecOps);
}

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
	local XComGameState_Unit Unit;

	Unit = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(UnitRef.ObjectID));

	if( Unit == none )
	{
		return true;
	}
	else if (!bCanConfirm)
	{
		return false;
	}

	return OptionsList.SelectedIndex >= 0;
}


//---------------------------------------------------------------------------------------
//				INPUT
//---------------------------------------------------------------------------------------

function OnConfirm(UIButton Button)
{
	local XComGameState_Unit Unit;
	local UIDIOStrategyMap_AssignmentBubble Bubble; 

	Unit = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(UnitRef.ObjectID));

	if( Unit == none )
	{
		PlayMouseClickSound();
		Bubble = DioHUD.m_ScreensNav.GetBubbleAssignedTo('SpecOps');
		if( Bubble != none )
		{
			Bubble.WorkerSlotClicked(0);
		}
	}
	else
	{
		if (class'DioStrategyAI'.static.IsAgentAssignmentChangeDestructive(UnitRef, 'SpecOps'))
		{
			PlayMouseClickSound();
			Unit = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(UnitRef.ObjectID));
			`STRATPRES.UIConfirmSwitchDutyAssignment(Unit, 'SpecOps', OnSwitchDutyConfirm);
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

	if (SelectedSpecOpsOption >= 0 && SelectedSpecOpsOption < RawDataOptions.Length)
	{
		Selection = UISpecOpsListItem(OptionsList.GetSelectedItem()).DataName;

		StratRules.SubmitStartSpectOps(UnitRef, Selection);
		StratRules.SubmitAssignAgentDuty(UnitRef, 'SpecOps');
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
function int SortSpecOps(name DataA, name DataB)
{
	local X2StrategyElementTemplateManager StratMgr;
	local X2DioSpecOpsTemplate TemplateA, TemplateB;

	StratMgr = `STRAT_TEMPLATE_MGR;
	TemplateA = X2DioSpecOpsTemplate(StratMgr.FindStrategyElementTemplate(DataA));
	TemplateB = X2DioSpecOpsTemplate(StratMgr.FindStrategyElementTemplate(DataB));

	// First sort by prereq agent rank
	if (TemplateA.PrereqAgentRank < TemplateB.PrereqAgentRank)
	{
		return 1;
	}
	else if (TemplateA.PrereqAgentRank > TemplateB.PrereqAgentRank)
	{
		return -1;
	}
	
	// Then sort by duration
	return TemplateA.Duration <= TemplateB.Duration? 1 : -1;
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
	Package = "/ package/gfxSpecOps/SpecOps";
	MCName = "theScreen";

	bHideOnLoseFocus = false;
	bAnimateOnInit = true;
	bProcessMouseEventsIfNotFocused = false;
	SelectedSpecOpsOption = -1;
}
