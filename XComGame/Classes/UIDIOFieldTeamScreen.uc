//---------------------------------------------------------------------------------------
//  FILE:    	UIDIOFieldTeamScreen
//  AUTHOR:  	David McDonough  --  6/14/2019
//  PURPOSE: 	View a Field Team from the city map, review its effects, and
//				purchase upgrades.
//           
//---------------------------------------------------------------------------------------
//  Copyright (c) 2019 Firaxis Games, Inc. All rights reserved.
//---------------------------------------------------------------------------------------
class UIDIOFieldTeamScreen extends UIScreen implements(UIDioAutotestInterface);

var StateObjectReference m_FieldTeamRef;
var StateObjectReference m_DistrictRef;

var array<UIFieldTeamManagerPanel> m_ManagerPanels;
var array<name> m_AllFieldTeamTemplateNames;
var int m_SelectedPanel; // mmg_john.hawley (11/7/19) - Implementing controller support for Field Team

// HUD elements
var UIDIOHUD					m_HUD;
var X2FieldTeamTemplate			m_newFieldTeamTemplate;

var localized String m_strConfirmUpgradeFieldTeamTitle;
var localized String m_strConfirmUpgradeFieldTeamText;
var localized String m_CannotBuildNewTitle;
var localized String m_BuildNewUnavailbleCannotAfford;
var localized String m_CannotUpgradeTitle;
var localized String m_UpgradeUnavailableTooManySteps;
var localized string m_UpgradeUnavailbleCannotAfford;
var localized string m_strConfirmReplaceFieldTeamTitle;
var localized string m_strConfirmReplaceFieldTeamText;
var localized String m_CannotReplaceTitle;
var localized string m_ReplaceUnavailbleCannotAfford;
var localized string ScreenTitle;
var localized String m_strCost;
var localized String m_strFree;
var localized String m_strFreeFieldTeam;

//---------------------------------------------------------------------------------------
//				INITIALIZATION
//---------------------------------------------------------------------------------------
simulated function InitScreen(XComPlayerController InitController, UIMovie InitMovie, optional name InitName)
{
	local int i;
	super.InitScreen(InitController, InitMovie, InitName);
	SetPosition(`FIELDTEAMXOFFSET, `FIELDTEAMYOFFSET); // mmg_aaron.lee (11/07/19) - reposition based on the value in Global.uci

	// HELIOS BEGIN
	// Replace the hard reference with a reference to the main HUD	
	m_HUD = UIDIOHUD(`SCREENSTACK.GetScreen(`PRESBASE.UIHUD_Strategy));
	// HELIOS END	
	m_HUD.NavHelp.AddSelectNavHelp();
	m_HUD.UpdateResources(self);

	// In order they should appear
	m_AllFieldTeamTemplateNames.Length = 0;
	m_AllFieldTeamTemplateNames.AddItem('FieldTeam_Finance');
	m_AllFieldTeamTemplateNames.AddItem('FieldTeam_Security');
	m_AllFieldTeamTemplateNames.AddItem('FieldTeam_Technology');

	m_SelectedPanel = 0; // mmg_john.hawley (11/7/19) - Implementing controller support for Field Team

	for (i = 0; i < 3; i++)
	{
		m_ManagerPanels.AddItem(Spawn(class'UIFieldTeamManagerPanel', self).InitFieldTeamManagerPanel(name("FTMItem_"$i)));
	}

	RegisterForEvents();
}

//---------------------------------------------------------------------------------------
simulated function OnInit()
{
	super.OnInit();
	ShowCityMapVisuals();
	LookAtDistrict();
	UpdateNavHelp();
}

function LookAtDistrict()
{
	local XComGameState_DioCityDistrict District;
	local int iDistrictCamera;

	District = XComGameState_DioCityDistrict(`XCOMHISTORY.GetGameStateForObjectID(m_DistrictRef.ObjectID));
	`XEVENTMGR.TriggerEvent('UIEvent_ManageFieldTeamBegin', none, District);
	
	iDistrictCamera = FindDistrictCamera(m_DistrictRef);
	if( iDistrictCamera != -1 )
	{
		`STRATPRES.RefreshCamera(name("StrategyMap_Region_" $ iDistrictCamera));
	}

	`XSTRATEGYSOUNDMGR.UpdateDistrictAudio(District, iDistrictCamera);

}

simulated function ShowCityMapVisuals()
{
	local UIDIOStrategyMapFlash Map;

	Map = UIDIOStrategyMapFlash(`SCREENSTACK.GetScreen(class'UIDIOStrategyMapFlash'));
	Map.Show();
}


//---------------------------------------------------------------------------------------
function RegisterForEvents()
{
	local X2EventManager EventManager;
	local Object SelfObject;

	EventManager = `XEVENTMGR;
	SelfObject = self;

	EventManager.RegisterForEvent(SelfObject, 'STRATEGY_ResourceChange_Submitted', OnResourceChange, ELD_OnStateSubmitted);
	EventManager.RegisterForEvent(SelfObject, 'STRATEGY_FieldTeamPlaced_Submitted', OnFieldTeamPlaced, ELD_OnStateSubmitted);
	EventManager.RegisterForEvent(SelfObject, 'STRATEGY_FieldTeamRankChanged_Submitted', OnFieldTeamChanged, ELD_OnStateSubmitted);
}

//---------------------------------------------------------------------------------------
function UnRegisterForEvents()
{
	local X2EventManager EventManager;
	local Object SelfObject;

	EventManager = `XEVENTMGR;
	SelfObject = self;

	EventManager.UnRegisterFromEvent(SelfObject, 'STRATEGY_ResourceChange_Submitted');
	EventManager.UnRegisterFromEvent(SelfObject, 'STRATEGY_FieldTeamPlaced_Submitted');
	EventManager.UnRegisterFromEvent(SelfObject, 'STRATEGY_FieldTeamRankChanged_Submitted');
}

//---------------------------------------------------------------------------------------
//				DISPLAY
//---------------------------------------------------------------------------------------

function DisplayFieldTeam(StateObjectReference InFieldTeamRef)
{
	local XComGameStateHistory History;
	local X2StrategyElementTemplateManager StratMgr;
	local X2FieldTeamTemplate FieldTeamTemplate;
	local XComGameState_FieldTeam FieldTeam;
	local int i;

	History = `XCOMHISTORY;
	StratMgr = `STRAT_TEMPLATE_MGR;
	m_FieldTeamRef = InFieldTeamRef;

	// Tutorial failsafe: if the tutorial requires a field team build and the player does not possess 1 free build, 
	//	grant them one here:
	if (class'UIDIOStrategyMapFlash'.static.MustBuildFieldTeam() && `DIOHQ.FreeFieldTeamBuilds == 0)
	{
		`STRATEGYRULES.SubmitForceChangeResources(, , , 1);
	}

	FieldTeam = XComGameState_FieldTeam(History.GetGameStateForObjectID(m_FieldTeamRef.ObjectID));
	if (FieldTeam != none)
	{
		m_DistrictRef = FieldTeam.DistrictRef;
	}
	
	// Update display of all field team category templates
	for (i = 0; i < m_ManagerPanels.Length; ++i)
	{
		if (i >= m_AllFieldTeamTemplateNames.Length)
		{
			break;
		}

		FieldTeamTemplate = X2FieldTeamTemplate(StratMgr.FindStrategyElementTemplate(m_AllFieldTeamTemplateNames[i]));
		m_ManagerPanels[i].UpdateData(FieldTeamTemplate, FieldTeam);
	}	

	Refresh();
}

//---------------------------------------------------------------------------------------
function Refresh()
{
	local int i;

	AS_SetScreenInfo(ScreenTitle);

	for (i = 0; i < m_ManagerPanels.Length; ++i)
	{
		if (i == 0)
		{
			Navigator.SetSelected(m_ManagerPanels[i]);
		}
		else
		{
			m_ManagerPanels[i].OnLoseFocus();
		}
	}
}

// mmg_john.hawley (11/7/19) BEGIN - Implementing controller support for Field Team
function SelectPanelPrev()
{
	Navigator.OnLoseFocus();

	PlayMouseOverSound();
	m_ManagerPanels[m_SelectedPanel].OnLoseFocus();
	m_SelectedPanel--;
	m_SelectedPanel = (m_SelectedPanel < 0) ? m_ManagerPanels.Length - 1 : m_SelectedPanel;
	m_ManagerPanels[m_SelectedPanel].SetSelectedNavigation();
}

function SelectPanelNext()
{
	Navigator.OnLoseFocus();

	PlayMouseOverSound();
	m_SelectedPanel++;
	m_SelectedPanel = (m_SelectedPanel > m_ManagerPanels.Length - 1) ? 0 : m_SelectedPanel;
	m_ManagerPanels[m_SelectedPanel].SetSelectedNavigation();
}

function UIFieldTeamManagerPanel GetSelectedPanel()
{
	return m_ManagerPanels[m_SelectedPanel];
}
// mmg_john.hawley (11/7/19) END

simulated function AS_SetScreenInfo(string Title)
{
	MC.BeginFunctionOp("SetScreenInfo");
	MC.QueueString(Title);
	MC.EndOp();
}

//---------------------------------------------------------------------------------------
//				NAVIGATION
//---------------------------------------------------------------------------------------

function UpdateNavHelp()
{
	m_HUD.NavHelp.ClearButtonHelp();
	m_HUD.NavHelp.AddBackButton(OnCancel);

	// @jcortese
	// mmg_john.hawley (11/7/19) - Updating NavHelp
	if (`ISCONTROLLERACTIVE)
	{
		m_HUD.NavHelp.AddSelectNavHelp();
	}
}


//---------------------------------------------------------------------------------------
//				INPUT HANDLER
//---------------------------------------------------------------------------------------
function OnPanelActivated(X2FieldTeamTemplate FieldTeamTemplate)
{
	local XComGameState_FieldTeam FieldTeam;

	FieldTeam = XComGameState_FieldTeam(`XCOMHISTORY.GetGameStateForObjectID(m_FieldTeamRef.ObjectID));	
	if (FieldTeam == none)
	{
		HandleNewTeam(FieldTeamTemplate);
	}
	else if (FieldTeam.GetMyTemplate() == FieldTeamTemplate)
	{
		HandleUpgradeTeam();
	}
	else
	{
		HandleReplaceTeam(FieldTeamTemplate);
	}
}

//---------------------------------------------------------------------------------------
function DisplayConfirmNewTeamDialog(X2FieldTeamTemplate FieldTeamTemplate)
{
	local TDialogueBoxData kConfirmData;
	local XComGameState_FieldTeam FieldTeam;
	local XComGameState_DioCityDistrict District;
	local XGParamTag LocTag;
	local string BodyText;

	PlayMouseClickSound();

	m_newFieldTeamTemplate = FieldTeamTemplate;
	District = XComGameState_DioCityDistrict(`XCOMHISTORY.GetGameStateForObjectID(m_DistrictRef.ObjectID));

	kConfirmData.eType = eDialog_Normal;
	kConfirmData.strTitle = class'UIDIOStrategyPicker_FieldTeamBuilder'.default.m_strConfirmBuildFieldTeamTitle;

	LocTag = XGParamTag(`XEXPANDCONTEXT.FindTag("XGParam"));
	LocTag.StrValue0 = FieldTeamTemplate.DisplayName;
	LocTag.StrValue1 = District.GetMyTemplate().DisplayName;
	BodyText = `XEXPAND.ExpandString(class'UIDIOStrategyPicker_FieldTeamBuilder'.default.m_strConfirmBuildFieldTeamText);

	FieldTeam = XComGameState_FieldTeam(`XCOMHISTORY.GetGameStateForObjectID(m_FieldTeamRef.ObjectID));
	BodyText $= "<br><br>" $ BuildCostString(FieldTeamTemplate, FieldTeam);

	kConfirmData.strText = BodyText;
	kConfirmData.strAccept = class'UIUtilities_Text'.default.m_strGenericConfirm;
	kConfirmData.strCancel = class'UIUtilities_Text'.default.m_strGenericCancel;
	kConfirmData.bMuteCancelSound = true;
	kConfirmData.bMuteAcceptSound = true;

	kConfirmData.fnCallback = OnConfirmBuildFieldTeam;

	Movie.Pres.UIRaiseDialog(kConfirmData);
}

//---------------------------------------------------------------------------------------
function OnConfirmBuildFieldTeam(Name eAction)
{
	local X2FieldTeamTemplate FieldTeamTemplate;
	local string AkEventName;

	if (eAction == 'eUIAction_Accept')
	{
		FieldTeamTemplate = m_newFieldTeamTemplate;
		if (FieldTeamTemplate == none)
		{
			CloseScreen();
		}

		AkEventName = "UI_Strategy_FieldTeams_Create";
		`SOUNDMGR.PlayAkEventDirect(AkEventName, self);
		`STRATEGYRULES.SubmitBuildFieldTeam(FieldTeamTemplate, m_DistrictRef);
	}
	else if (eAction == 'eUIAction_Cancel')
	{
		PlayMouseClickSound();
	}
}

//---------------------------------------------------------------------------------------
function HandleNewTeam(X2FieldTeamTemplate NewFieldTeamTemplate)
{
	local string DialogTitle, DialogBody;

	// Blocked: can't afford
	if (!NewFieldTeamTemplate.CanAfford(none))
	{
		DialogTitle = m_CannotBuildNewTitle;
		DialogBody = m_BuildNewUnavailbleCannotAfford $ "<br><br>" $ BuildCostString(NewFieldTeamTemplate, none);
		DisplayUnavailableDialog(DialogTitle, DialogBody);
		return;
	}

	DisplayConfirmNewTeamDialog(NewFieldTeamTemplate);
}

//---------------------------------------------------------------------------------------
function HandleUpgradeTeam()
{
	local XComGameState_FieldTeam FieldTeam;
	local X2FieldTeamTemplate FieldTeamTemplate;
	local string DialogTitle, DialogBody;

	FieldTeam = XComGameState_FieldTeam(`XCOMHISTORY.GetGameStateForObjectID(m_FieldTeamRef.ObjectID));
	FieldTeamTemplate = FieldTeam.GetMyTemplate();

	// Blocked: can't afford
	if (!FieldTeamTemplate.CanAfford(FieldTeam))
	{
		DialogTitle = m_CannotUpgradeTitle;
		DialogBody = m_UpgradeUnavailbleCannotAfford $ "<br><br>" $ BuildCostString(FieldTeamTemplate, FieldTeam);
		DisplayUnavailableDialog(DialogTitle, DialogBody);
		return;
	}

	// Upgrade blocked for prereq reasons
	if (!FieldTeam.CanBuildCombineNow(FieldTeam.GetMyTemplate(), DialogBody))
	{
		DialogTitle = m_CannotUpgradeTitle;
		DisplayUnavailableDialog(DialogTitle, DialogBody);
		return;
	}

	DisplayConfirmUpgradeTeamDialog();
}

//---------------------------------------------------------------------------------------
function HandleReplaceTeam(X2FieldTeamTemplate NewFieldTeamTemplate)
{
	local XComGameState_FieldTeam FieldTeam;
	local string DialogTitle, DialogBody;

	FieldTeam = XComGameState_FieldTeam(`XCOMHISTORY.GetGameStateForObjectID(m_FieldTeamRef.ObjectID));
	
	// Blocked: can't afford
	if (!NewFieldTeamTemplate.CanAfford(FieldTeam))
	{
		DialogTitle = m_CannotReplaceTitle;
		DialogBody = m_ReplaceUnavailbleCannotAfford $ "<br><br>" $ BuildCostString(NewFieldTeamTemplate, FieldTeam);
		DisplayUnavailableDialog(DialogTitle, DialogBody);
		return;
	}

	DisplayConfirmReplaceTeamDialog(NewFieldTeamTemplate);
}

//---------------------------------------------------------------------------------------
function DisplayConfirmUpgradeTeamDialog()
{
	local TDialogueBoxData kConfirmData;
	local XComGameState_FieldTeam FieldTeam;
	local X2FieldTeamTemplate FieldTeamTemplate;
	local XGParamTag LocTag;
	local string BodyText;

	PlayMouseClickSound();

	FieldTeam = XComGameState_FieldTeam(`XCOMHISTORY.GetGameStateForObjectID(m_FieldTeamRef.ObjectID));
	FieldTeamTemplate = FieldTeam.GetMyTemplate();

	kConfirmData.eType = eDialog_Normal;
	kConfirmData.strTitle = m_strConfirmUpgradeFieldTeamTitle;

	LocTag = XGParamTag(`XEXPANDCONTEXT.FindTag("XGParam"));
	LocTag.StrValue0 = FieldTeamTemplate.DisplayName;
	LocTag.IntValue0 = FieldTeam.Rank + 1;
	BodyText = `XEXPAND.ExpandString(m_strConfirmUpgradeFieldTeamText);

	BodyText $= "<br><br>" $ BuildCostString(FieldTeamTemplate, FieldTeam);
	kConfirmData.strText = BodyText;
	kConfirmData.strAccept = class'UIUtilities_Text'.default.m_strGenericConfirm;
	kConfirmData.strCancel = class'UIUtilities_Text'.default.m_strGenericCancel;

	kConfirmData.fnCallback = OnConfirmUpgradeFieldTeam;

	Movie.Pres.UIRaiseDialog(kConfirmData);
}

//---------------------------------------------------------------------------------------
function OnConfirmUpgradeFieldTeam(Name eAction)
{
	local XComGameState_FieldTeam FieldTeam;
	local string AkEventName;

	FieldTeam = XComGameState_FieldTeam(`XCOMHISTORY.GetGameStateForObjectID(m_FieldTeamRef.ObjectID));
	if (eAction == 'eUIAction_Accept')
	{
		AkEventName = "UI_Strategy_FieldTeams_Upgrade";
		`SOUNDMGR.PlayAkEventDirect(AkEventName, self);
		`STRATEGYRULES.SubmitBuildFieldTeam(FieldTeam.GetMyTemplate(), FieldTeam.DistrictRef);
	}
	else if (eAction == 'eUIAction_Cancel')
	{
		PlayMouseClickSound();
	}
}

//---------------------------------------------------------------------------------------
function DisplayConfirmReplaceTeamDialog(X2FieldTeamTemplate NewFieldTeamTemplate)
{
	local TDialogueBoxData kConfirmData;
	local UICallbackData_POD CallbackData;
	local XComGameState_FieldTeam FieldTeam;
	local X2FieldTeamTemplate OldFieldTeamTemplate;
	local XGParamTag LocTag;
	local string BodyText;

	PlayMouseClickSound();

	FieldTeam = XComGameState_FieldTeam(`XCOMHISTORY.GetGameStateForObjectID(m_FieldTeamRef.ObjectID));
	OldFieldTeamTemplate = FieldTeam.GetMyTemplate();

	kConfirmData.eType = eDialog_Normal;
	kConfirmData.strTitle = m_strConfirmReplaceFieldTeamTitle;

	LocTag = XGParamTag(`XEXPANDCONTEXT.FindTag("XGParam"));
	LocTag.StrValue0 = OldFieldTeamTemplate.DisplayName;
	LocTag.StrValue1 = NewFieldTeamTemplate.DisplayName;
	BodyText = `XEXPAND.ExpandString(m_strConfirmReplaceFieldTeamText);

	BodyText $= "<br><br>" $ BuildCostString(NewFieldTeamTemplate, FieldTeam);
	kConfirmData.strText = BodyText;
	kConfirmData.strAccept = class'UIUtilities_Text'.default.m_strGenericConfirm;
	kConfirmData.strCancel = class'UIUtilities_Text'.default.m_strGenericCancel;

	CallbackData = new class'UICallbackData_POD';
	CallbackData.NameValue = NewFieldTeamTemplate.DataName;
	kConfirmData.xUserData = CallbackData;
	kConfirmData.fnCallbackEx = OnConfirmReplaceFieldTeam;

	Movie.Pres.UIRaiseDialog(kConfirmData);
}

//---------------------------------------------------------------------------------------
function OnConfirmReplaceFieldTeam(Name eAction, UICallbackData xUserData)
{
	local X2FieldTeamTemplate NewFieldTeamTemplate;
	local UICallbackData_POD CallbackData;
	local string AkEventName;

	if (eAction == 'eUIAction_Accept')
	{
		AkEventName = "UI_Strategy_FieldTeams_Create";
		`SOUNDMGR.PlayAkEventDirect(AkEventName, self);

		CallbackData = UICallbackData_POD(xUserData);
		NewFieldTeamTemplate = X2FieldTeamTemplate(`STRAT_TEMPLATE_MGR.FindStrategyElementTemplate(CallbackData.NameValue));

		`STRATEGYRULES.SubmitBuildFieldTeam(NewFieldTeamTemplate, m_DistrictRef);
	}
	else if (eAction == 'eUIAction_Cancel')
	{
		PlayMouseClickSound();
	}
}

//---------------------------------------------------------------------------------------
function DisplayUnavailableDialog(string Title, string Body)
{
	local TDialogueBoxData kConfirmData;

	PlayNegativeMouseClickSound();

	kConfirmData.eType = eDialog_Alert;
	kConfirmData.strTitle = Title;
	kConfirmData.strText = Body;
	kConfirmData.strAccept = class'UIUtilities_Text'.default.m_strGenericConfirm;
	kConfirmData.bMuteAcceptSound = true;
	kConfirmData.fnCallback = DisplayUnavailableDialogOnConfirm;

	Movie.Pres.UIRaiseDialog(kConfirmData);
}

//---------------------------------------------------------------------------------------
private function DisplayUnavailableDialogOnConfirm(Name eAction)
{
	if (eAction == 'eUIAction_Accept')
	{
		PlayMouseClickSound();
	}
}

//---------------------------------------------------------------------------------------
static function string BuildCostString(X2FieldTeamTemplate FieldTeamTemplate, XComGameState_FieldTeam FieldTeam)
{
	local XGParamTag LocTag;
	local string FormattedString;

	LocTag = XGParamTag(`XEXPANDCONTEXT.FindTag("XGParam"));
	LocTag.StrValue0 = FieldTeamTemplate.GetCostString(FieldTeam);

	if (`DIOHQ.FreeFieldTeamBuilds > 0)
	{
		LocTag.StrValue1 = `DIO_UI.static.FormatFreeFieldTeamValue(`DIOHQ.FreeFieldTeamBuilds);
		FormattedString = `XEXPAND.ExpandString(default.m_strFree);
	}
	else
	{
		FormattedString = `XEXPAND.ExpandString(default.m_strCost);
	}

	return FormattedString;
}

//---------------------------------------------------------------------------------------
static function string BuildPurchaseString(X2FieldTeamTemplate FieldTeamTemplate, XComGameState_FieldTeam FieldTeam)
{
	local XGParamTag LocTag;
	local string FormattedString;

	LocTag = XGParamTag(`XEXPANDCONTEXT.FindTag("XGParam"));

	if (`DIOHQ.FreeFieldTeamBuilds > 0)
	{
		LocTag.StrValue0 = FieldTeamTemplate.GetCostString(FieldTeam);
		FormattedString = `XEXPAND.ExpandString(default.m_strFreeFieldTeam);
	}
	else
	{
		FormattedString = FieldTeamTemplate.GetCostString(FieldTeam);
	}

	return FormattedString;
}

//---------------------------------------------------------------------------------------
//				EVENT LISTENERS
//---------------------------------------------------------------------------------------
function EventListenerReturn OnResourceChange(Object EventData, Object EventSource, XComGameState GameState, Name Event, Object CallbackData)
{
	m_HUD.ResourcesPanel.RefreshAll();
	DisplayFieldTeam(m_FieldTeamRef);
	return ELR_NoInterrupt;
}

function EventListenerReturn OnFieldTeamPlaced(Object EventData, Object EventSource, XComGameState GameState, Name Event, Object CallbackData)
{
	local XComGameState_FieldTeam FieldTeam;

	FieldTeam = XComGameState_FieldTeam(EventData);
	if (FieldTeam.DistrictRef == m_DistrictRef)
	{
		DisplayFieldTeam(FieldTeam.GetReference());
		`STRATPRES.ForceRefreshActiveScreenChanged();
	}

	return ELR_NoInterrupt;
}

//---------------------------------------------------------------------------------------
function EventListenerReturn OnFieldTeamChanged(Object EventData, Object EventSource, XComGameState GameState, Name Event, Object CallbackData)
{
	local XComGameState_FieldTeam FieldTeam;

	FieldTeam = XComGameState_FieldTeam(EventData);
	if (FieldTeam.DistrictRef == m_DistrictRef)
	{
		DisplayFieldTeam(FieldTeam.GetReference());
		`STRATPRES.ForceRefreshActiveScreenChanged();
	}

	return ELR_NoInterrupt;
}

//---------------------------------------------------------------------------------------
function OnCancel()
{
	CloseScreen();
}

//---------------------------------------------------------------------------------------
simulated function CloseScreen()
{
	`XSTRATEGYSOUNDMGR.StopDistrictAudio();
	UnRegisterForEvents();
	`XEVENTMGR.TriggerEvent('UIEvent_ManageFieldTeamEnd');
	super.CloseScreen();
}

//---------------------------------------------------------------------------------------
simulated function bool OnUnrealCommand(int cmd, int arg)
{
	local bool bHandled;

	if (!CheckInputIsReleaseOrDirectionRepeat(cmd, arg))
		return false;
	
	bHandled = false;
	switch (cmd)
	{
	// mmg_john.hawley (11/7/19) - Implementing controller support for Field Team
	case class'UIUtilities_Input'.const.FXS_BUTTON_A :
	case class'UIUtilities_Input'.const.FXS_KEY_ENTER :
	case class'UIUtilities_Input'.const.FXS_KEY_SPACEBAR :
		GetSelectedPanel().ConfirmButton.Click();
		//SelectPanel(1).SetSelectedNavigation();
		bHandled = true;
		break;

		case class'UIUtilities_Input'.const.FXS_DPAD_RIGHT :
		case class'UIUtilities_Input'.const.FXS_VIRTUAL_LSTICK_RIGHT:
		SelectPanelNext();
		bHandled = true;
		break;

		case class'UIUtilities_Input'.const.FXS_DPAD_LEFT :
		case class'UIUtilities_Input'.const.FXS_VIRTUAL_LSTICK_LEFT :
		SelectPanelPrev();
		bHandled = true;
		break;

	case class'UIUtilities_Input'.const.FXS_BUTTON_B :
	case class'UIUtilities_Input'.const.FXS_KEY_ESCAPE :
	case class'UIUtilities_Input'.const.FXS_R_MOUSE_DOWN :
		PlayMouseClickSound();
		CloseScreen();
		bHandled = true;
		break;
	default:
		break;
	}

	return bHandled || super.OnUnrealCommand(cmd, arg);
}

//---------------------------------------------------------------------------------------
function int FindDistrictCamera(StateObjectReference DistrictRef)
{
	local UIDIOStrategyMapFlash StrategyMapScreen;

	StrategyMapScreen = UIDIOStrategyMapFlash(`SCREENSTACK.GetScreen(class'UIDIOStrategyMapFlash'));
	if( StrategyMapScreen == none )	return -1;

	return StrategyMapScreen.GetDistrictIndex(DistrictRef);
}


//---------------------------------------------------------------------------------------
//UIDioAutotestInterface
function bool SimulateScreenInteraction()
{
	OnCancel();
	return true;
}

simulated function OnReceiveFocus()
{
	super.OnReceiveFocus();

	m_HUD.UpdateResources(self);
	UpdateNavHelp();
}

//---------------------------------------------------------------------------------------
defaultproperties
{
	Package = "/ package/gfxFieldTeamManager/FieldTeamManager";
	MCName = "theScreen";
	bProcessMouseEventsIfNotFocused = false;
}