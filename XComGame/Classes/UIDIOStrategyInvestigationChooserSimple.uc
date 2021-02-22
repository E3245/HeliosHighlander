//---------------------------------------------------------------------------------------
//  FILE:    	UIDIOStrategyInvestigationChooserSimple
//  PURPOSE: 	Popup to present options for selecting an Investigation.
//           
//---------------------------------------------------------------------------------------
//  Copyright (c) 2019 Firaxis Games, Inc. All rights reserved.
//---------------------------------------------------------------------------------------
class UIDIOStrategyInvestigationChooserSimple extends UIScreen;

var UIButton ConfirmButton;
var UIDIOHUD m_HUD;

var CampaignStartData	m_CampaignStartData;
var array<X2DioInvestigationTemplate> m_InvestigationTemplates;
var int SelectedInvestigationTemplateIdx;
var array<UIDIOStrategyInvestigationChooserPanel> m_InvestPanels;

var localized string ScreenTitle;
var localized string InvestigationAlreadyCompletedTitle;
var localized string InvestigationAlreadyCompletedText;

simulated function UIDIOStrategyInvestigationChooserSimple InitPopup()
{
	local int i;	

	if (!class'DioStrategyAI'.static.GetMainActInvestigationNames(m_InvestigationTemplates))
	{
		`RedScreen("UIDIOStrategyInvestigationChooserSimple: No available Investigation Templates found! @gameplay");
		`SCREENSTACK.Pop(self);
	}

	m_InvestPanels.AddItem(Spawn(class'UIDIOStrategyInvestigationChooserPanel', self));
	m_InvestPanels.AddItem(Spawn(class'UIDIOStrategyInvestigationChooserPanel', self));
	m_InvestPanels.AddItem(Spawn(class'UIDIOStrategyInvestigationChooserPanel', self));

	// HELIOS BEGIN
	// Replace the hard reference with a reference to the main HUD	
	m_HUD = UIDIOHUD(`SCREENSTACK.GetScreen(`PRESBASE.UIHUD_Strategy));
	// HELIOS END		
	m_HUD.UpdateResources(self);

	for (i = 0; i < 3; i++)
	{
		m_InvestPanels[i].InitChooserPanel(name("item_"$i), m_InvestigationTemplates[i], i);

		//Stash the first available index for default selection.
		if( SelectedInvestigationTemplateIdx == -1 && !m_InvestPanels[i].bDisabled )
			SelectedInvestigationTemplateIdx = i; 
	}
	// HELIOS BEGIN
	// Replace the hard reference with a reference to the main HUD	
	UIDIOHUD(`SCREENSTACK.GetScreen(`PRESBASE.UIHUD_Strategy)).UpdateResources(self);
	// HELIOS END	
	UpdateNavHelp();
	
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

	SelectPanel(SelectedInvestigationTemplateIdx);

	SetAlpha(0);
	SetTimer(0.5, false, nameof(CheckCurrentScreen));
	
	return self;
}

function CheckCurrentScreen()
{
	local UIScreen ActiveScreen;

	ActiveScreen = `SCREENSTACK.GetCurrentScreen();
	if (ActiveScreen != self)
	{	
		SetTimer(0.5, false, nameof(CheckCurrentScreen));
	}
	else
	{
		SetAlpha(1.0);
	}
}

simulated function OnInit()
{
	super.OnInit();
	AS_SetScreenInfo(ScreenTitle);
}

simulated function OnReceiveFocus()
{
	super.OnReceiveFocus();
	UpdateNavHelp();
}

function SelectPanel(int Index)
{
	local int i;

	PlayMouseClickSound();
	if( SelectedInvestigationTemplateIdx == Index )
	{
		//deselect, allowing to toggle off
		SelectedInvestigationTemplateIdx = -1;
	}
	else
	{
		SelectedInvestigationTemplateIdx = (Index + 3)%3; //wrap selection
	}

	for( i = 0; i < m_InvestPanels.length; i++ )
	{
		m_InvestPanels[i].SetHighlighted(i == SelectedInvestigationTemplateIdx);
	}
	
	UpdateNavHelp();
}

function UpdateNavHelp()
{
	if( !bIsFocused )
		return;

	m_HUD.NavHelp.ClearButtonHelp();
	
	ConfirmButton.SetDisabled( !CanConfirm() );
	
	if( class'UIUtilities_DioStrategy'.static.ShouldShowMetaContentTags() )
	{
		if( `ISCONTROLLERACTIVE)
		{
			m_HUD.NavHelp.AddRightHelp(`META_TAG $ class'UIUtilities_DioStrategy'.default.ViewMetaContentLabel, class'UIUtilities_Input'.static.GetGamepadIconPrefix() $ class'UIUtilities_Input'.const.ICON_Y_TRIANGLE);
		}
		else
		{
			m_HUD.NavHelp.AddRightHelp(`META_TAG $ class'UIUtilities_DioStrategy'.default.ViewMetaContentLabel, , XComStrategyPresentationLayer(Movie.Pres).ViewMetaContent);
		}
	}
}

simulated function bool OnUnrealCommand(int cmd, int arg)
{
	if (!CheckInputIsReleaseOrDirectionRepeat(cmd, arg))
		return false;

	switch (cmd)
	{
	case class'UIUtilities_Input'.const.FXS_DPAD_LEFT :
	case class'UIUtilities_Input'.const.FXS_VIRTUAL_LSTICK_LEFT :
	case class'UIUtilities_Input'.const.FXS_ARROW_LEFT :
	case class'UIUtilities_Input'.const.FXS_KEY_A :
		SelectPanel(SelectedInvestigationTemplateIdx - 1);
		break;

	case class'UIUtilities_Input'.const.FXS_DPAD_RIGHT :
	case class'UIUtilities_Input'.const.FXS_VIRTUAL_LSTICK_RIGHT :
	case class'UIUtilities_Input'.const.FXS_ARROW_RIGHT :
	case class'UIUtilities_Input'.const.FXS_KEY_D :
		SelectPanel(SelectedInvestigationTemplateIdx + 1);
		break;

	case class'UIUtilities_Input'.const.FXS_BUTTON_X :
	case class'UIUtilities_Input'.const.FXS_KEY_SPACEBAR :
	case class'UIUtilities_Input'.const.FXS_KEY_ENTER :
		ConfirmInvestigation();
		break;

	case class'UIUtilities_Input'.const.FXS_BUTTON_Y :
	case class'UIUtilities_Input'.const.FXS_KEY_Y :
		if( class'UIUtilities_DioStrategy'.static.ShouldShowMetaContentTags() )
		{
			`STRATPRES.UIMetaContentScreen();
		}
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

//---------------------------------------------------------------------------------------
function OnConfirm(UIButton Button)
{
	ConfirmInvestigation();
}
//---------------------------------------------------------------------------------------
function bool CanConfirm()
{
	return (SelectedInvestigationTemplateIdx != -1);
}
//---------------------------------------------------------------------------------------
function ConfirmInvestigation()
{	
	local XComGameState_HeadquartersDio DioHQ;
	local XComStrategyPresentationLayer StratPres;
	local X2StrategyGameRuleset StratRules;
	local name InvestigationTemplateName; 

	if (!CanConfirm())
	{
		return;
	}

	StratRules = `STRATEGYRULES;
	StratPres = `STRATPRES;
	DioHQ = `DIOHQ;
	InvestigationTemplateName = m_InvestigationTemplates[SelectedInvestigationTemplateIdx].DataName; 

	// Early out: can't start this investigation
	if (DioHQ.HasCompletedInvestigation(InvestigationTemplateName))
	{
		PlayNegativeMouseClickSound();
		StratPres.UIWarningDialog(InvestigationAlreadyCompletedTitle, InvestigationAlreadyCompletedText, eDialog_Normal);
		return;
	}

	PlayConfirmSound();

	if (!`DIOHQ.IsCampaignSetupComplete())
	{
		m_CampaignStartData.InvestigationTemplateName = InvestigationTemplateName;
		StratRules.SubmitNewCampaignSetup(m_CampaignStartData);
	}
	else
	{
		StratRules.SubmitStartInvestigation(InvestigationTemplateName);
	}

	CloseScreen();
}

//---------------------------------------------------------------------------------------
//UIDioAutotestInterface
function bool SimulateScreenInteraction()
{
	SelectedInvestigationTemplateIdx = 1;
	ConfirmInvestigation();
	return true;
}

//---------------------------------------------------------------------------------------
defaultproperties
{
	Package = "/ package/gfxInvestigationPickerSimple/InvestigationPickerSimple";
	MCName = "theScreen";

	Width = 1024
		Height = 640
		SelectedInvestigationTemplateIdx = -1;
	bConsumeMouseEvents = true;
}
