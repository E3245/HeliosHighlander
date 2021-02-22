//---------------------------------------------------------------------------------------
//  FILE:    	UIDIOStrategyGrayboxPicker
//  AUTHOR:  	David McDonough  --  4/15/2019
//  PURPOSE: 	Graybox base class for presenting a list of options from which the player
//				can choose one. Uses:
//
//				* UnlockCharacter
//				* UnlockCityRegion
//           
//---------------------------------------------------------------------------------------
//  Copyright (c) 2019 Firaxis Games, Inc. All rights reserved.
//---------------------------------------------------------------------------------------
class UIDIOStrategyGrayboxPicker extends UIScreen
	implements(UIDioAutotestInterface)
	native(UI);

struct native PickerOptionData
{
	var name IDName;
	var name TemplateName;
	var UIButton Button;
};

var UIDIOHUD			m_HUD;
var UITextContainer		MainContainer;
var UITextContainer		DescriptionContainer;
var UIList				OptionsList;
var UIButton			ConfirmButton;
var UINavigationHelp	NavHelp;

var array<name>				RawDataOptions;
var array<PickerOptionData> PickerOptions;
var int				SelectedIndex;
var float			Padding;
var float			HalfWidth;
var bool			bAllowedToBackOut;

var delegate<ConfirmCallback> m_ConfirmCallback;

var localized string HeaderText;
var localized string SubheaderText;

delegate ConfirmCallback(PickerOptionData Selection);

//---------------------------------------------------------------------------------------
//				INITIALIZATION
//---------------------------------------------------------------------------------------
simulated function InitScreen(XComPlayerController InitController, UIMovie InitMovie, optional name InitName)
{
	local string FormattedString;

	super.InitScreen(InitController, InitMovie, InitName);
	// HELIOS BEGIN
	// Replace the hard reference with a reference to the main HUD	
	m_HUD = UIDIOHUD(`SCREENSTACK.GetScreen(`PRESBASE.UIHUD_Strategy));
	// HELIOS END		
	m_HUD.UpdateResources(self);

	MainContainer = Spawn(class'UITextContainer', self).InitTextContainer('MainContainer', , 0, 0, Width, Height, true);
	MainContainer.AnchorCenter();
	MainContainer.SetPosition(-(Width / 2), -(Height / 2));	
	MainContainer.EnableNavigation();

	HalfWidth = (Width / 2) - (Padding * 2);

	OptionsList = Spawn(class'UIList', MainContainer).InitList('OptionsList', , , , , false, true);
	OptionsList.ItemPadding = Padding;
	OptionsList.SetPosition(Padding, 80);
	OptionsList.SetSize(HalfWidth, Height - (Padding * 2));
	OptionsList.bLoopSelection = false;
	OptionsList.Navigator.OnSelectedIndexChanged = OnSelectedIndexChanged;

	DescriptionContainer = Spawn(class'UITextContainer', MainContainer).InitTextContainer('DescriptionContainer');
	DescriptionContainer.SetPosition((Width / 2) + Padding, 80);
	DescriptionContainer.SetSize(HalfWidth, Height - (Padding * 2));

	FormattedString = `DIO_UI.default.strTerm_Confirm;
	if (`ISCONTROLLERACTIVE)
	{
		FormattedString = class'UIUtilities_Text'.static.InjectImage(class'UIUtilities_Input'.static.GetGamepadIconPrefix() $ class'UIUtilities_Input'.const.ICON_X_SQUARE, 20, 20, 0) @ FormattedString;
	}

	ConfirmButton = Spawn(class'UIButton', MainContainer).InitButton('Confirm', FormattedString, OnConfirm);
	ConfirmButton.SetColor(class'UIUtilities_Colors'.const.GOOD_HTML_COLOR);
	ConfirmButton.SetWidth(Width - (Padding * 2));
	ConfirmButton.SetPosition(Padding, Height - 32 - Padding);
	ConfirmButton.SetDisabled(true);
	ConfirmButton.DisableNavigation(); //Used for mouse only

	RegisterForEvents();
}

//---------------------------------------------------------------------------------------
simulated function OnInit()
{
	NavHelp = m_HUD.NavHelp;

	UpdateNavHelp();
	super.OnInit();
}

//---------------------------------------------------------------------------------------
simulated function SetHeaderText()
{
	MainContainer.SetHTMLText(`DIO_UI.static.FormatSubheader(HeaderText, eUIState_Warning, 40));
}

//---------------------------------------------------------------------------------------
simulated function Display()
{
	// Entry point for pickers that generate their own options, override in subclasses
	Refresh();
}

//---------------------------------------------------------------------------------------
simulated function DisplayOptions(array<name> InOptions)
{
	RawDataOptions = InOptions;
	Refresh();
}

//---------------------------------------------------------------------------------------
function RegisterForEvents()
{
	//local Object SelfObject;
	//SelfObject = self;
}

//---------------------------------------------------------------------------------------
function UnRegisterForEvents()
{
	//local Object SelfObject;
	//SelfObject = self;
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
simulated function UIButton BuildOption(name DataName, out PickerOptionData OptionData)
{
	local UIButton TempButton;

	TempButton = UIButton(OptionsList.CreateItem(class'UIButton'));
	TempButton.bAnimateOnInit = false;
	TempButton.InitButton(name(string(DataName) $ "_Btn"), , OnOptionButton);
	TempButton.SetWidth(HalfWidth);
	TempButton.SetText("[FPO]" @ string(DataName));
	TempButton.SetTextAlign("center");

	OptionData.IDName = DataName;
	OptionData.TemplateName = DataName;
	OptionData.Button = TempButton;
	
	return TempButton;
}

//---------------------------------------------------------------------------------------
simulated function bool OnUnrealCommand(int cmd, int arg)
{
	local bool bHandled;

	if (!CheckInputIsReleaseOrDirectionRepeat(cmd, arg))
		return false;

	bHandled = true;

	switch (cmd)
	{
	case class'UIUtilities_Input'.const.FXS_BUTTON_A :
	case class'UIUtilities_Input'.const.FXS_BUTTON_X :
		OnConfirm(ConfirmButton);
		break;
	case class'UIUtilities_Input'.const.FXS_BUTTON_START :
		`HQPRES.UIPauseMenu(, true);
		break;
	case class'UIUtilities_Input'.const.FXS_BUTTON_B :
	case class'UIUtilities_Input'.const.FXS_KEY_ESCAPE :
	case class'UIUtilities_Input'.const.FXS_R_MOUSE_DOWN :
		if(bAllowedToBackOut)
		{
			PlayMouseClickSound();
			CloseScreen();
		}
		else
		{
			PlayNegativeMouseClickSound();
		}
		break;
	default:
		bHandled = false;
		break;
	}

	return bHandled || super.OnUnrealCommand(cmd, arg);
}

//---------------------------------------------------------------------------------------
function RefreshDescription()
{
	// Override in subclasses
}

//---------------------------------------------------------------------------------------
function bool CanConfirm()
{
	return SelectedIndex >= 0;
}

//---------------------------------------------------------------------------------------
function UpdateNavHelp()
{
	NavHelp.ClearButtonHelp();
	NavHelp.AddBackButton(OnCancel);
}

//---------------------------------------------------------------------------------------
//				INPUT
//---------------------------------------------------------------------------------------

function OnOptionButton(UIButton Button)
{
	local int i;

	for (i = 0; i < PickerOptions.Length; ++i)
	{
		if (Button == PickerOptions[i].Button)
		{
			OnSelectedIndexChanged(i);
			return;
		}
	}
}

//---------------------------------------------------------------------------------------
simulated function OnSelectedIndexChanged(int NewIndex)
{
	PlayMouseClickSound();
	SelectedIndex = NewIndex;
	Refresh();
	ConfirmButton.SetDisabled(!CanConfirm());
}

//---------------------------------------------------------------------------------------
function OnConfirm(UIButton Button)
{
	PlayConfirmSound();

	if (SelectedIndex >= 0 && SelectedIndex < PickerOptions.Length)
	{
		if (m_ConfirmCallback != none)
		{
			m_ConfirmCallback(PickerOptions[SelectedIndex]);
		}
	}

	CloseScreen();
}

//---------------------------------------------------------------------------------------
simulated function OnCancel()
{
	PlayMouseClickSound();
	CloseScreen();
}

//---------------------------------------------------------------------------------------
simulated function CloseScreen()
{
	UnRegisterForEvents();
	super.CloseScreen();
}

//---------------------------------------------------------------------------------------
//UIDioAutotestInterface
function bool SimulateScreenInteraction()
{
	// Always select first option
	SelectedIndex = 0;
	OnConfirm(none);
	return true;
}

//---------------------------------------------------------------------------------------
defaultproperties
{
	Width = 1024
	Height = 640
	Padding = 10
	SelectedIndex=-1
	bConsumeMouseEvents = true;
	InputState = eInputState_Consume;

	bAllowedToBackOut = true;
}

