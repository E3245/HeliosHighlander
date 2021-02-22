//---------------------------------------------------------------------------------------
//  FILE:    	UIDIOStrategyPicker_TrainingAction
//  AUTHOR:  	David McDonough  --  4/16/2019
//  PURPOSE: 	Specialization of UIDIOStrategyGrayboxPicker:
//				Choose a Training Program to start or resume for the given unit.
//           
//---------------------------------------------------------------------------------------
//  Copyright (c) 2019 Firaxis Games, Inc. All rights reserved.
//---------------------------------------------------------------------------------------
class UIDIOStrategyPicker_TrainingAction extends UIDIOStrategyGrayboxPicker;

var StateObjectReference				m_UnitRef;
var bool								m_bUnitCanExecute;
var array<X2DioTrainingProgramTemplate> m_AvailableTraining;

simulated function InitScreen(XComPlayerController InitController, UIMovie InitMovie, optional name InitName)
{
	super.InitScreen(InitController, InitMovie, InitName);

	// HELIOS BEGIN
	`PRESBASE.RefreshCamera(class'XComStrategyPresentationLayer'.const.TrainingAreaTag);
	// HELIOS END
}


//---------------------------------------------------------------------------------------
simulated function OnInit()
{
	super.OnInit();
}

//---------------------------------------------------------------------------------------
simulated function DisplayOptions(array<name> InOptions)
{
	local XComGameState_HeadquartersDio DioHQ;
	local XComGameState_Unit Unit;
	local name TrainingProgramName;

	DioHQ = `DIOHQ;

	Unit = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(m_UnitRef.ObjectID));
	if (Unit == none)
	{
		return;
	}

	// Unit-based options
	RawDataOptions = Unit.AvailableTrainingPrograms;

	// Append Specialty Training from DioHQ not already known
	foreach DioHQ.UnlockedUniversalTraining(TrainingProgramName)
	{
		if (Unit.CompletedTrainingPrograms.Find(TrainingProgramName) == INDEX_NONE)
		{
			RawDataOptions.AddItem(TrainingProgramName);
		}
	}
	
	Refresh();
}

//---------------------------------------------------------------------------------------
simulated function UIButton BuildOption(name DataName, out PickerOptionData OptionData)
{
	local X2DioTrainingProgramTemplate TrainingProgramTemplate;
	local UIButton TempButton;

	TrainingProgramTemplate = X2DioTrainingProgramTemplate(`STRAT_TEMPLATE_MGR.FindStrategyElementTemplate(DataName));
	if (TrainingProgramTemplate == none)
	{
		return none;
	}

	TempButton = UIButton(OptionsList.CreateItem(class'UIButton'));
	TempButton.bAnimateOnInit = false;
	TempButton.InitButton(name(string(TrainingProgramTemplate.DataName) $ "_Btn"), , OnOptionButton);
	TempButton.SetWidth(HalfWidth);
	TempButton.SetText(TrainingProgramTemplate.GetDisplayNameString());
	TempButton.SetTextAlign("center");

	OptionData.IDName = DataName;
	OptionData.TemplateName = DataName;
	OptionData.Button = TempButton;

	return TempButton;
}

//---------------------------------------------------------------------------------------
simulated function Refresh()
{
	local PickerOptionData UnlockData;
	local UIButton TempButton;
	local name OptionName;
	local int ButtonIdx;

	SetHeaderText();
	OptionsList.ClearItems();
	PickerOptions.Length = 0;
	
	UIText(OptionsList.CreateItem(class'UIText')).InitText(, `DIO_UI.static.FormatSubheader(SubheaderText, eUIState_Good, 32));

	foreach RawDataOptions(OptionName)
	{
		TempButton = BuildOption(OptionName, UnlockData);
		ButtonIdx = PickerOptions.AddItem(UnlockData);

		if (ButtonIdx == SelectedIndex)
		{
			TempButton.SetColor(class'UIUtilities_Colors'.const.GOOD_HTML_COLOR);
		}
		else
		{
			TempButton.SetColor(class'UIUtilities_Colors'.const.INTERACTIVE_BLUE_MEDIUM_HTML_COLOR);
		}
	}
	OptionsList.ShrinkToFit();

	RefreshDescription();
}

//---------------------------------------------------------------------------------------
function RefreshDescription()
{
	local XComGameState_Unit Unit;
	local X2DioTrainingProgramTemplate TrainingProgramTemplate;
	local array<string> CostStrings;
	local string FormattedString, TempString, EffectString;

	if (SelectedIndex < 0)
	{
		DescriptionContainer.SetText("");
		return;
	}

	TrainingProgramTemplate = X2DioTrainingProgramTemplate(`STRAT_TEMPLATE_MGR.FindStrategyElementTemplate(PickerOptions[SelectedIndex].TemplateName));
	if (TrainingProgramTemplate == none)
	{
		DescriptionContainer.SetText("");
		return;
	}

	// Description
	FormattedString = `DIO_UI.static.FormatBody(TrainingProgramTemplate.GetDescription(), , 20);
	FormattedString $= "<br><br>";

	// Effects
	EffectString = `DIO_UI.static.FormatBody(TrainingProgramTemplate.GetEffectsString(), , 22);
	if (EffectString != "")
	{
		FormattedString $= `DIO_UI.static.FormatSubheader(`DIO_UI.default.strTerm_Rewards, eUIState_Warning, 24);
		FormattedString $= "<br>" $ EffectString;
	}
	FormattedString $= "<br>";

	// Cost & Duration
	TempString = TrainingProgramTemplate.GetCostString();
	if (TempString != "")
	{
		CostStrings.AddItem(TempString);
	}
	TempString = TrainingProgramTemplate.GetDurationString();
	if (TempString != "")
	{
		CostStrings.AddItem(TempString);
	}
	if (CostStrings.Length > 0)
	{
		FormattedString $= `DIO_UI.static.FormatSubheader(`DIO_UI.default.strTerm_Cost, eUIState_Warning, 24);
		foreach CostStrings(TempString)
		{
			FormattedString $= "<br>" $ `DIO_UI.static.FormatBody(TempString, , 22);
		}
		FormattedString $= "<br>";
	}

	Unit = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(m_UnitRef.ObjectID));
	m_bUnitCanExecute = TrainingProgramTemplate.CanStartNow(Unit, TempString);
	if (!m_bUnitCanExecute && TempString != "")
	{
		FormattedString $= "<br>" $ `DIO_UI.static.FormatBody(TempString, eUIState_Bad, 22);;
	}

	DescriptionContainer.SetHTMLText(FormattedString);
}

//---------------------------------------------------------------------------------------
function bool CanConfirm()
{
	if (!m_bUnitCanExecute)
	{
		return false;
	}

	return super.CanConfirm();
}

//---------------------------------------------------------------------------------------
//				INPUT
//---------------------------------------------------------------------------------------

function OnConfirm(UIButton Button)
{
	local XComGameState_Unit Unit;

	if (class'DioStrategyAI'.static.IsAgentAssignmentChangeDestructive(m_UnitRef, 'Train'))
	{
		Unit = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(m_UnitRef.ObjectID));
		`STRATPRES.UIConfirmSwitchDutyAssignment(Unit, 'Train', OnSwitchDutyConfirm);
	}
	else
	{
		CommitSelection();
	}
}

function OnSwitchDutyConfirm(Name eAction, UICallbackData xUserData)
{
	if (eAction == 'eUIAction_Accept')
	{
		CommitSelection();
	}
}

// FINALLY submit the action and assignment change
function CommitSelection()
{
	local X2StrategyGameRuleset StratRules;
	local PickerOptionData Selection;

	StratRules = `STRATEGYRULES;

	if (SelectedIndex >= 0 && SelectedIndex < PickerOptions.Length)
	{
		Selection = PickerOptions[SelectedIndex];

		StratRules.SubmitTrainingAction(m_UnitRef, Selection.TemplateName);
		StratRules.SubmitAssignAgentDuty(m_UnitRef, 'Train');
	}

	CloseScreen();
}