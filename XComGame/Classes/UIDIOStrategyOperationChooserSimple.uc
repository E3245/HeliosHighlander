//---------------------------------------------------------------------------------------
//  FILE:    	UIDIOStrategyOperationChooser
//  PURPOSE: 	Popup to present options for selecting an Operation.
//           
//---------------------------------------------------------------------------------------
//  Copyright (c) 2020 Firaxis Games, Inc. All rights reserved.
//---------------------------------------------------------------------------------------
class UIDIOStrategyOperationChooserSimple extends UIScreen;

var UIButton		ConfirmButton;

var array<X2DioInvestigationOperationTemplate> m_OperationTemplates;
var array<UIDIOStrategyOperationChooserPanel> OperationPanels;
var int SelectedOperationTemplateIdx;

var localized string ScreenTitle;
var localized string TagStr_DarkEventPreview;


simulated function InitScreen(XComPlayerController InitController, UIMovie InitMovie, optional name InitName)
{
	super.InitScreen(InitController, InitMovie, InitName);

	InitOperationPanels();
	AS_SetScreenInfo(ScreenTitle);

	if( `ISCONTROLLERACTIVE)
	{
		// mmg_aaron.lee (11/22/19) - add gamepad icon prefix.  
		ConfirmButton = Spawn(class'UIButton', self).InitButton('unlockConfirmButton', class'UIUtilities_Text'.static.InjectImage(class'UIUtilities_Input'.static.GetGamepadIconPrefix() $ class'UIUtilities_Input'.const.ICON_X_SQUARE, 20, 20, 0) @ class'UIUtilities_Text'.default.m_strGenericConfirm,
																OnConfirm);
	}
	else
	{
		ConfirmButton = Spawn(class'UIButton', self).InitButton('unlockConfirmButton',
																class'UIUtilities_Text'.default.m_strGenericConfirm,
																OnConfirm);
	}
	ConfirmButton.SetWidth(400);
	ConfirmButton.SetGood(true);

	UpdateNavHelp();

	SelectPanel(SelectedOperationTemplateIdx);

	// HELIOS BEGIN
	// Replace the hard reference with a reference to the main HUD	
	UIDIOHUD(`SCREENSTACK.GetScreen(`PRESBASE.UIHUD_Strategy)).UpdateResources(self);
	// HELIOS END	
	
	return;
}

function InitOperationPanels()
{
	local XComGameState_Investigation Investigation;
	local X2DioInvestigationOperationTemplate OpTemplateA, OpTemplateB;
	local UIDIOStrategyOperationChooserPanel OpPanelA, OpPanelB;
	local XGParamTag LocTag;
	local string FormattedString;

	Investigation = class'DioStrategyAI'.static.GetCurrentInvestigation();
	Investigation.GetValidOperations(m_OperationTemplates, false, true, true);

	if (m_OperationTemplates.Length < 2)
	{
		`RedScreen("UIDIOStrategyOperationChooserSimple did not receive 2 operations!");
		OpTemplateA = Investigation.SelectNextRandomOperation();
		`STRATEGYRULES.SubmitStartOperation(OpTemplateA.DataName);
		return;
	}
	// Should only ever be 2
	else if (m_OperationTemplates.Length > 2)
	{
		`log("UIDIOStrategyOperationChooserSimple received more than 2 valid operations, truncating");
		m_OperationTemplates.Length = 2;
	}

	// Init each panel using the Dark Event from the *other* operation to indicate
	// that choosing an Op starts the unchosen Op's Dark Event
	OpTemplateA = m_OperationTemplates[0];
	OpTemplateB = m_OperationTemplates[1];
	LocTag = XGParamTag(`XEXPANDCONTEXT.FindTag("XGParam"));
	
	OpPanelA = Spawn(class'UIDIOStrategyOperationChooserPanel', self);
	
	LocTag.StrValue0 = OpTemplateB.GetDarkEventPreviewString();
	FormattedString = `XEXPAND.ExpandString(TagStr_DarkEventPreview);

	OpPanelA.InitChooserPanel('item_0', OpTemplateA, FormattedString, SelectPanel, 0);
	OperationPanels.AddItem(OpPanelA);

	OpPanelB = Spawn(class'UIDIOStrategyOperationChooserPanel', self);

	LocTag.StrValue0 = OpTemplateA.GetDarkEventPreviewString();
	FormattedString = `XEXPAND.ExpandString(TagStr_DarkEventPreview);

	OpPanelB.InitChooserPanel('item_1', OpTemplateB, FormattedString, SelectPanel, 1);
	OperationPanels.AddItem(OpPanelB);
}

simulated function bool OnUnrealCommand(int cmd, int arg)
{
	if(!bIsVisible) return true; 

	if (!CheckInputIsReleaseOrDirectionRepeat(cmd, arg))
		return false;

	switch (cmd)
	{
	case class'UIUtilities_Input'.const.FXS_DPAD_LEFT :
	case class'UIUtilities_Input'.const.FXS_VIRTUAL_LSTICK_LEFT :
	case class'UIUtilities_Input'.const.FXS_ARROW_LEFT :
	case class'UIUtilities_Input'.const.FXS_KEY_A :
		SelectPanel(0);
		break;

	case class'UIUtilities_Input'.const.FXS_DPAD_RIGHT :
	case class'UIUtilities_Input'.const.FXS_VIRTUAL_LSTICK_RIGHT :
	case class'UIUtilities_Input'.const.FXS_ARROW_RIGHT :
	case class'UIUtilities_Input'.const.FXS_KEY_D :
		SelectPanel(1);
		break;

	case class'UIUtilities_Input'.const.FXS_BUTTON_A :
	case class'UIUtilities_Input'.const.FXS_KEY_SPACEBAR :
	case class'UIUtilities_Input'.const.FXS_KEY_ENTER :
		ConfirmOperation();
		break;
	}

	return true;
}

simulated function AS_SetScreenInfo(string Title)
{
	MC.BeginFunctionOp("SetScreenInfo");
	MC.QueueString(Title);
	MC.EndOp();
}

function SelectPanel(int Index)
{
	local int i;

	PlayMouseClickSound();
	if( SelectedOperationTemplateIdx == Index )
	{
		//deselect, allowing to toggle off
		SelectedOperationTemplateIdx = -1;
	}
	else
	{
		SelectedOperationTemplateIdx = (Index + 2) % 2; //wrap selection
	}

	for( i = 0; i < OperationPanels.length; i++ )
	{
		OperationPanels[i].SetHighlighted(i == SelectedOperationTemplateIdx);
	}
	UpdateNavHelp();
}

//---------------------------------------------------------------------------------------
function OnConfirm(UIButton Button)
{
	ConfirmOperation();
}
//---------------------------------------------------------------------------------------
function bool CanConfirm()
{
	return (SelectedOperationTemplateIdx != -1);
}
//---------------------------------------------------------------------------------------
function ConfirmOperation()
{
	local X2StrategyGameRuleset StratRules;
	local UIDIOStrategyOperationChooserPanel Selection;
	local int i;
	local X2DioInvestigationOperationTemplate targetOp;

	if(!CanConfirm())
	{
		PlayNegativeMouseClickSound();
		return; 
	}

	StratRules = `STRATEGYRULES;
	targetOp = OperationPanels[SelectedOperationTemplateIdx].OperationTemplate;

	for( i = 0; i < OperationPanels.length; ++i )
	{
		Selection = OperationPanels[i];
		if( Selection.OperationTemplate.DataName == targetOp.DataName )
		{
			PlayConfirmSound();
			StratRules.SubmitStartOperation(Selection.OperationTemplate.DataName, true);
		}
		else
		{
			StratRules.SubmitLockOperation(Selection.OperationTemplate.DataName);
		}
	}

	`SCREENSTACK.Pop(self);
}
//---------------------------------------------------------------------------------------
simulated function OnReceiveFocus()
{
	super.OnReceiveFocus();
	UpdateNavHelp();
}

function UpdateNavHelp()
{
	local UIDIOHUD HUD;

	// HELIOS BEGIN
	// Replace the hard reference with a reference to the main HUD	
	HUD = UIDIOHUD(`SCREENSTACK.GetScreen(`PRESBASE.UIHUD_Strategy));
	// HELIOS END	
	HUD.NavHelp.ClearButtonHelp();
	ConfirmButton.SetDisabled(!CanConfirm());
}

//---------------------------------------------------------------------------------------
//UIDioAutotestInterface
function bool SimulateScreenInteraction()
{
	SelectedOperationTemplateIdx = 1;
	OperationPanels[SelectedOperationTemplateIdx].SelectThis(OperationPanels[SelectedOperationTemplateIdx].m_SelectButton);
	return true;
}

//---------------------------------------------------------------------------------------
defaultproperties
{
	Package = "/ package/gfxOperationPickerSimple/OperationPickerSimple";
	MCName = "theScreen";

	SelectedOperationTemplateIdx = 0
	bConsumeMouseEvents = true;
}
