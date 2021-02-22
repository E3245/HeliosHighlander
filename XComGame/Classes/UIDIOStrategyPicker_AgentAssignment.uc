//---------------------------------------------------------------------------------------
//  FILE:    	UIDIOStrategyPicker_AgentAssignment
//  AUTHOR:  	David McDonough  --  5/23/2019
//  PURPOSE: 	View options for assigning a Squad Agent to a duty: APC, training, 
//				research, etc.
//           
//---------------------------------------------------------------------------------------
//  Copyright (c) 2019 Firaxis Games, Inc. All rights reserved.
//---------------------------------------------------------------------------------------
class UIDIOStrategyPicker_AgentAssignment extends UIDIOStrategyGrayboxPicker;

var StateObjectReference	m_UnitRef;
var bool					bCanConfirm;

var localized string APCAssignmentDescription;
var localized string SpecOpsAssignmentDescription;
var localized string ResearchAssignmentDescription;
var localized string TrainingAssignmentDescription;
var localized string UnassignDescription;

//---------------------------------------------------------------------------------------
simulated function SetHeaderText()
{
	local XComGameState_Unit Unit;
	local XGParamTag LocTag;
	local string FormattedString;

	if (m_UnitRef.ObjectID <= 0)
	{
		return;
	}

	Unit = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(m_UnitRef.ObjectID));	

	LocTag = XGParamTag(`XEXPANDCONTEXT.FindTag("XGParam"));
	LocTag.StrValue0 = Unit.GetNickName();
	FormattedString = `XEXPAND.ExpandString(HeaderText);
	MainContainer.SetHTMLText(`DIO_UI.static.FormatSubheader(FormattedString, eUIState_Warning, 40));
}

//---------------------------------------------------------------------------------------
simulated function DisplayOptions(array<name> InOptions)
{
	RawDataOptions.Length = 0;
	RawDataOptions.AddItem('APC');
	RawDataOptions.AddItem('SpecOps');
	RawDataOptions.AddItem('Assembly');
	RawDataOptions.AddItem('Training');
	RawDataOptions.AddItem('Unassign');

	Refresh();
}

//---------------------------------------------------------------------------------------
simulated function UIButton BuildOption(name DataName, out PickerOptionData OptionData)
{
	local UIButton TempButton;

	TempButton = UIButton(OptionsList.CreateItem(class'UIButton'));
	TempButton.bAnimateOnInit = false;
	TempButton.InitButton(name(string(DataName) $ "_Btn"), , OnOptionButton);
	TempButton.SetWidth(HalfWidth);
	TempButton.SetText(string(DataName));
	TempButton.SetTextAlign("center");

	OptionData.IDName = DataName;
	OptionData.TemplateName = DataName;
	OptionData.Button = TempButton;

	return TempButton;
}

//---------------------------------------------------------------------------------------
function RefreshDescription()
{
	local string FormattedString, UnavailableString;

	if (SelectedIndex < 0)
	{
		DescriptionContainer.SetText("");
		return;
	}
	
	switch (PickerOptions[SelectedIndex].IDName)
	{
	case 'APC':
		FormattedString = `DIO_UI.static.FormatBody(APCAssignmentDescription);
		bCanConfirm = class'DioStrategyAI'.static.CanAssignToAPC(m_UnitRef, UnavailableString);
		break;
	case 'SpecOps':
		FormattedString = `DIO_UI.static.FormatBody(SpecOpsAssignmentDescription);
		bCanConfirm = class'DioStrategyAI'.static.CanStartSpecOpsAction(m_UnitRef, UnavailableString);
		break;
	case 'Assembly':
		FormattedString = `DIO_UI.static.FormatBody(ResearchAssignmentDescription);
		bCanConfirm = class'DioStrategyAI'.static.CanStartResearchAction(m_UnitRef, UnavailableString);
		break;
	case 'Training':
		FormattedString = `DIO_UI.static.FormatBody(TrainingAssignmentDescription);
		bCanConfirm = class'DioStrategyAI'.static.CanStartTrainingAction(m_UnitRef, UnavailableString);
		break;
	case 'Unassign':
		FormattedString = `DIO_UI.static.FormatBody(UnassignDescription);
		bCanConfirm = true;
		break;
	}

	if (UnavailableString != "")
	{
		FormattedString $= "\n\n" $ `DIO_UI.static.FormatBody(UnavailableString, eUIState_Warning);
	}

	DescriptionContainer.SetHTMLText(FormattedString);
}

//---------------------------------------------------------------------------------------
function bool CanConfirm()
{
	return bCanConfirm;
}

//---------------------------------------------------------------------------------------
//				INPUT
//---------------------------------------------------------------------------------------

function OnConfirm(UIButton Button)
{
	local PickerOptionData Selection;

	if (SelectedIndex >= 0 && SelectedIndex < PickerOptions.Length)
	{
		Selection = PickerOptions[SelectedIndex];
		switch (Selection.IDName)
		{
		case 'APC':
			`STRATEGYRULES.SubmitAssignAgentDuty(m_UnitRef, 'APC');
			break;
		case 'SpecOps':
			`STRATPRES.UISpecOpsActionPicker(m_UnitRef);
			break;
		case 'Assembly':
			`STRATEGYRULES.SubmitAssignAgentDuty(m_UnitRef, 'Research');
			break;
		case 'Training':
			`STRATPRES.UITrainingActionPicker(m_UnitRef);
			break;
		case 'Unassign':
			`STRATEGYRULES.SubmitAssignAgentDuty(m_UnitRef, 'Unassign');
			break;
		}
	}
	// HELIOS BEGIN
	//Refresh assignments display: 
	UIDIOHUD(`SCREENSTACK.GetScreen(`PRESBASE.UIHUD_Strategy)).UpdateData();
	// HELIOS END
	CloseScreen();
}

//---------------------------------------------------------------------------------------
//				INPUT HANDLER
//---------------------------------------------------------------------------------------
simulated function bool OnUnrealCommand(int cmd, int arg)
{
	// Only allow releases through past this point.
	if ((arg & class'UIUtilities_Input'.const.FXS_ACTION_RELEASE) == 0)
	{
		return false;
	}

	switch (cmd)
	{
	case class'UIUtilities_Input'.const.FXS_BUTTON_B :
	case class'UIUtilities_Input'.const.FXS_KEY_ESCAPE :
		PlayMouseClickSound();
		CloseScreen();
		return true;
		break;
	}

	return Super.OnUnrealCommand(cmd, arg);
}