//---------------------------------------------------------------------------------------
//  FILE:    	UIDIOAssemblyScreen
//  AUTHOR:  	Brit Steiner 8/9/2019
//  PURPOSE: 	Choose an assembly project.
//           
//---------------------------------------------------------------------------------------
//  Copyright (c) 2019 Firaxis Games, Inc. All rights reserved.
//---------------------------------------------------------------------------------------
class UIDIOAssemblyScreen extends UIScreen implements(UIDIOIconSwap);

var UIDIOHUD							DioHUD;
var UIList								OptionsList;
var UIButton							ConfirmButton;
var bool								bUnitCanExecute;
var bool								bCanStartAnyResearch;	// Tracks if at least one project is available and affordable
var array<StateObjectReference>			UnitRefs;	// All Agents assigned to Research actions
var array<name>							RawDataOptions;
var array<UITabIconButton>				Tabs; 
var UIDIOStrategyMap_WorkerSlot			CurrentWorkerSlot;
var UIDIOStrategyMap_WorkerSlot			CurrentWorkerSlot2;
var UIDIOStrategyMap_WorkerSlot			CurrentWorkerSlot3;
var int									SelectedAssemblyOption;
var int									SelectedTab;

var localized string ScreenTitle;
var localized string ScreenSubTitle;
var localized string ScreenTitleNoUnitSelected;
var localized string StatusNoProject;

var localized string CategoryLabel_Armor;
var localized string CategoryLabel_CheckMark;
var localized string CategoryLabel_Grenade;
var localized string CategoryLabel_Gun;
var localized string CategoryLabel_Breach;
var localized string CategoryLabel_Robot;
var localized string CategoryLabel_Default;

var localized string ConfirmButton_BeginNewResearch;
var localized string ConfirmButton_SwitchResearch;

var localized string PromptExitWithoutProjectTitle;
var localized string PromptExitWithoutProjectBody;

//---------------------------------------------------------------------------------------


//---------------------------------------------------------------------------------------
//				INITIALIZATION
//---------------------------------------------------------------------------------------
simulated function InitScreen(XComPlayerController InitController, UIMovie InitMovie, optional name InitName)
{
	super.InitScreen(InitController, InitMovie, InitName);

	// mmg_aaron.lee (10/29/19) BEGIN - allow to edit through global.uci
	SetPanelScale(`ASSIGNMENTSCALER);
	SetPosition(`ASSEMBLYXOFFSET, `ASSEMBLYYOFFSET); // mmg_aaron.lee (11/07/19) - change from using SCREENNAVILEFTOFFSET and ASSIGNMENTTOPOFFSET due to weird margin of the panel.
	// mmg_aaron.lee (10/29/19) END

	OptionsList = Spawn(class'UIList', self);
	OptionsList.ScrollbarPadding = -25;
	OptionsList.bLoopSelection = true;
	OptionsList.bStickyClickyHighlight = true;
	OptionsList.OnSelectionChanged = OnSelectionChanged;
	OptionsList.OnItemClicked = OnItemClicked;
	OptionsList.bSelectFirstAvailable = true;
	OptionsList.OnSetSelectedIndex = OnSelectedIndexChanged;
	OptionsList.InitList('AssemblyListMC', 102, 320, 600, 608); //forcing location and size, to try to combat weird squishing items. 
	OptionsList.SetSelectedNavigation();

	if (`ISCONTROLLERACTIVE)
	{
		ConfirmButton = Spawn(class'UIButton', self).InitButton('trainingConfirmButton', class'UIUtilities_Text'.static.InjectImage(class'UIUtilities_Input'.static.GetGamepadIconPrefix() $ class'UIUtilities_Input'.const.ICON_A_X, 20, 20, 0) @ class'UIUtilities_Text'.default.m_strGenericConfirm, OnConfirm);
	}
	else
	{
		ConfirmButton = Spawn(class'UIButton', self).InitButton('trainingConfirmButton', class'UIUtilities_Text'.default.m_strGenericConfirm, OnConfirm);
	}
	ConfirmButton.SetWidth(312);
	ConfirmButton.SetX(849);
	ConfirmButton.SetY(891);
	ConfirmButton.SetGood(true);
	ConfirmButton.Hide();
	ConfirmButton.DisableNavigation();

	BuildTabs();
	UpdateNavHelp();
	RegisterForEvents();
	AddOnRemovedDelegate(UnRegisterForEventsFailsafe);

	MC.FunctionString("SetCategoryLabel", CategoryLabel_Default);

	// HELIOS BEGIN
	// Move the refresh camera function to presentation base
	`PRESBASE.RefreshCamera(class'XComStrategyPresentationLayer'.const.AssemblyAreaTag);
	// HELIOS END
}

simulated function OnInit()
{
	super.OnInit();

	DisplayOptions();
	UpdateNavHelp();
}

//---------------------------------------------------------------------------------------
function RegisterForEvents()
{
	local X2EventManager EventManager;
	local Object SelfObject;

	EventManager = `XEVENTMGR;
	SelfObject = self;

	EventManager.RegisterForEvent(SelfObject, 'STRATEGY_AgentDutyAssigned_Submitted', OnAgentDutyAssigned, ELD_OnStateSubmitted);
}
function UnRegisterForEventsFailsafe(UIPanel Panel)
{
	UnRegisterForEvents();
}

//---------------------------------------------------------------------------------------
function UnRegisterForEvents()
{
	local X2EventManager EventManager;
	local Object SelfObject;

	EventManager = `XEVENTMGR;
	SelfObject = self;

	EventManager.UnRegisterFromEvent(SelfObject, 'STRATEGY_AgentDutyAssigned_Submitted');
}

//---------------------------------------------------------------------------------------
simulated function BuildOption(name DataName, bool bActiveResearch)
{
	local X2DioResearchTemplate ResearchProgramTemplate;
	local UIDIOAssemblyListItem ListItem;

	ResearchProgramTemplate = X2DioResearchTemplate(`STRAT_TEMPLATE_MGR.FindStrategyElementTemplate(DataName));
	if (ResearchProgramTemplate == none)
	{
		return;
	}

	ListItem = GetListItemForResearch(ResearchProgramTemplate.DataName);
	ListItem.SetResearch(name(string(ResearchProgramTemplate.DataName)), bActiveResearch );

	if (!bActiveResearch && !ResearchProgramTemplate.CanStartNow())
	{
		ListItem.SetDisabled(true);
	}
	else
	{
		bCanStartAnyResearch = true;
	}
}

simulated function UIDIOAssemblyListItem GetListItemForResearch(name DataName)
{
	local UIDIOAssemblyListItem ListItem, NewListItem;
	
	ListItem = UIDIOAssemblyListItem(OptionsList.GetItemMCNamed(name("AssemblyListItem_" $ DataName)));
	if( ListItem != none ) return ListItem; 

	NewListItem = UIDIOAssemblyListItem(OptionsList.CreateItem(class'UIDIOAssemblyListItem'));
	NewListItem.InitAssemblyListItem(name("AssemblyListItem_" $ DataName));
	NewListItem.OnMouseEventDelegate = OptionsList.OnChildMouseEvent; 

	return NewListItem; 
}

//---------------------------------------------------------------------------------------
simulated function  array<name> RefreshDataOptions(optional name UICategory)
{
	local array<name> ResultData;
	local XComGameState_HeadquartersDio DioHQ;
	local array<X2StrategyElementTemplate> AllResearch;
	local X2DioResearchTemplate ResearchTemplate;
	local EResearchState ResearchState;
	local int i;

	DioHQ = `DIOHQ;
	AllResearch = `STRAT_TEMPLATE_MGR.GetAllTemplatesOfClass(class'X2DioResearchTemplate');	

	for (i = 0; i < AllResearch.Length; ++i)
	{
		ResearchTemplate = X2DioResearchTemplate(AllResearch[i]);
		if (ResearchTemplate == none)
		{
			continue;
		}

		if (UICategory != '')
		{
			if (ResearchTemplate.UICategory != UICategory)
			{
				continue;
			}
		}

		DioHQ.GetResearchStatuses(ResearchTemplate, ResearchState);
		if (ResearchState == eResearch_Locked)
		{
			// Only skip locked research if it is marked HideUntilUnlocked
			if (ResearchTemplate.bHideUntilUnlocked)
			{
				continue;
			}
		}
		else if (ResearchState == eResearch_Complete)
		{
			continue;
		}

		ResultData.AddItem(ResearchTemplate.DataName);
	}

	return ResultData;
}

//---------------------------------------------------------------------------------------
simulated function DisplayOptions()
{	
	local XComGameState NewGameState;
	local XComGameState_HeadquartersDio DioHQ;
	local XComGameState_DioResearch CompletedResearch;
	local X2DioResearchTemplate CompletedResearchTemplate;
	local string PopupTitle, PopupBody;
	local int i;

	RawDataOptions = RefreshDataOptions();
	Refresh();

	DioHQ = `DIOHQ;
	if (DioHQ.UnseenCompletedResearch.Length > 0)
	{
		// Show popups for just completed research
		for (i = 0; i < DioHQ.UnseenCompletedResearch.Length; ++i)
		{
			CompletedResearch = XComGameState_DioResearch(`XCOMHISTORY.GetGameStateForObjectID(DioHQ.UnseenCompletedResearch[i].ObjectID));
			if (CompletedResearch != none)
			{
				CompletedResearchTemplate = CompletedResearch.GetMyTemplate();
				PopupTitle = `DIO_UI.default.strTerm_Complete $ ":" @ CompletedResearchTemplate.DisplayName;
				PopupBody = CompletedResearchTemplate.FormatRewardsString();
				`STRATPRES.UIWarningDialog(PopupTitle, PopupBody, eDialog_NormalWithImage, CompletedResearchTemplate.Image);
			}
		}

		NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Clear Unseen Completed Research");
		DioHQ = XComGameState_HeadquartersDio(NewGameState.ModifyStateObject(class'XComGameState_HeadquartersDio', `DIOHQ.ObjectID));
		DioHQ.RemoveUnseenCompletedResearch(NewGameState);
		`GAMERULES.SubmitGameState(NewGameState);
	}
}

//---------------------------------------------------------------------------------------
simulated function Refresh()
{
	local XComGameState_DioResearch CurrentResearch;
	local string StatusString;
	local name OptionName, CurrentResearchName;
	local int TotalPips, FilledPips, UnitObjectID, UnitObjectID2;

	// HELIOS BEGIN
	// Replace the hard reference with a reference to the main HUD	
	DioHUD = UIDIOHUD(`SCREENSTACK.GetScreen(`PRESBASE.UIHUD_Strategy));
	// HELIOS END	
	DioHUD.UpdateResources(self);

	AS_SetScreenInfo(ScreenTitle, ScreenSubTitle, "");

	CurrentResearch = `DIOHQ.GetActiveResearch();
	if (CurrentResearch != none)
	{
		CurrentResearchName = CurrentResearch.GetMyTemplateName();
		StatusString = CurrentResearch.GetStatusString() $ GetCurrentResearchFormattedTime();
		TotalPips = CurrentResearch.PointsRequired;
		FilledPips = CurrentResearch.PointsEarned;
	}
	else
	{
		CurrentResearchName = '';
		StatusString = StatusNoProject;
		TotalPips = 1;
		FilledPips = 0;
	}

	UnitObjectID = -1; // default empty but showing   
	UnitObjectID2 = -2;  //default hiding 

	class'DioStrategyAI'.static.GetAllAgentsOnAssignment('Research', UnitRefs);
	if( UnitRefs.Length > 0 )
	{
		UnitObjectID = UnitRefs[0].ObjectID;

		// More than 1 Agent can be assigned to assembly at a time
		if( `DIOHQ.HasCompletedResearchByName('DioResearch_ImprovedAssembly') )
		{
			if( UnitRefs.length > 1 )
			{
				UnitObjectID2 = UnitRefs[1].ObjectID;
			}
			else
			{
				UnitObjectID2 = -1; //force show empty slot 
			}
		}
	}
	else
	{
		UnitObjectID = -1;
		if (`DIOHQ.HasCompletedResearchByName('DioResearch_ImprovedAssembly'))
		{
			UnitObjectID2 = -1; //force show empty slot 
		}
	}
	
	SetCurrentAssemblyInfo(StatusString, TotalPips, FilledPips, UnitObjectID, UnitObjectID2);
	//OptionsList.ClearItems(); //DO NOT NUKE LIST. We're refreshing current ones in the build option sequence. 

	bCanStartAnyResearch = false;
	foreach RawDataOptions(OptionName)
	{
		BuildOption(OptionName, CurrentResearchName == OptionName);		
	}

	if (SelectedAssemblyOption < 0 || SelectedAssemblyOption > OptionsList.ItemCount)
	{
		OptionsList.SetSelectedIndex(0);
		SelectedAssemblyOption = 0; 
	}
	else
	{
		OptionsList.SetSelectedIndex(SelectedAssemblyOption);
	}

	RefreshDescription();
}

function string GetCurrentResearchFormattedTime()
{
	local XComGameState_DioResearch CurrentResearch;
	CurrentResearch = `DIOHQ.GetActiveResearch();
	
	if( CurrentResearch == none ) return "";

	return " (" $ `DIO_UI.static.FormatTimeIcon(CurrentResearch.GetTurnsRemaining()) $ ")";
}

//---------------------------------------------------------------------------------------
function RefreshDescription()
{
	local XComGameState_DioResearch CurrentResearch;
	local X2DioResearchTemplate ResearchTemplate;
	local array<string> PrereqStrings;
	local array<string> CostStrings;	
	local string FormattedString, TempString, NameString, PrereqString;

	// Clear out the subheader infos 
	MC.FunctionVoid("ClearInfo");

	if (OptionsList.SelectedIndex < 0)
	{
		return;
	}

	CurrentResearch = `DIOHQ.GetActiveResearch();

	UIDIOAssemblyListItem(OptionsList.GetSelectedItem()).RefreshSelectionState( false );
	SelectedAssemblyOption = OptionsList.SelectedIndex;
	UIDIOAssemblyListItem(OptionsList.GetSelectedItem()).RefreshSelectionState(true);

	ResearchTemplate = X2DioResearchTemplate(`STRAT_TEMPLATE_MGR.FindStrategyElementTemplate(RawDataOptions[SelectedAssemblyOption]));
	if (ResearchTemplate == none)
	{
		return;
	}

	// -----------------------------------------------------------
	// Research Name, narrative, and icon 
	NameString = ResearchTemplate.DisplayName;
	AS_UpdateInfoPanel(0,
		NameString,
		ResearchTemplate.GetSummaryString(),
		ResearchTemplate.Image);

	// -----------------------------------------------------------
	// Prereqs
	PrereqStrings = ResearchTemplate.GetRequirementStrings();
	FormattedString = "";
	if (PrereqStrings.Length > 0)
	{
		foreach PrereqStrings(PrereqString)
		{
			if (FormattedString != "")
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
	TempString = ResearchTemplate.GetCostString();
	if (TempString != "")
	{
		CostStrings.AddItem(TempString);
	}
	TempString = ResearchTemplate.GetTurnsRequiredPreviewString();
	if (TempString != "")
	{
		CostStrings.AddItem(TempString);
	}
	if (CostStrings.Length > 0)
	{
		FormattedString = class'UIUtilities_Text'.static.StringArrayToCommaSeparatedLine(CostStrings);
		/*foreach CostStrings(TempString)
		{
			if (FormattedString != "")
			{
				//Don't put a break before any other info 
				FormattedString $= "\n";
			}
			FormattedString $= TempString;
		}*/
		AS_UpdateInfoPanel(2, `DIO_UI.default.strTerm_Cost, FormattedString);
	}

	// -----------------------------------------------------------
	// Effects
	FormattedString = ResearchTemplate.FormatRewardsString();
	AS_UpdateInfoPanel(3, `DIO_UI.default.strTerm_Rewards, FormattedString);


	// -----------------------------------------------------------
	// Confirm button 
	bUnitCanExecute = ResearchTemplate.CanStartNow(TempString);
	if( bUnitCanExecute && CurrentResearch != none )
	{
		//Can't re-execute the same research you're already in progress on
		bUnitCanExecute = CurrentResearch.GetMyTemplate() != ResearchTemplate;
	}

	ConfirmButton.SetDisabled(!bUnitCanExecute);
	if (!bUnitCanExecute && TempString != "")
	{
		//TODO: INJECT [a] icon 
		MC.FunctionString("DisplayErrorMessage", TempString);
		ConfirmButton.Hide();
	}
	else
	{
		if( CurrentResearch == none )
		{
			ConfirmButton.SetText(ConfirmButton_BeginNewResearch);
		}
		else
		{
			ConfirmButton.SetText(ConfirmButton_SwitchResearch);
		}
		ConfirmButton.Show();

		MC.FunctionString("DisplayErrorMessage", "");
	}
}

function AS_UpdateInfoPanel(int index, string title, string body, string imagePath = "")
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


//---------------------------------------------------------------------------------------
function bool CanConfirm()
{
	if (!bUnitCanExecute)
	{
		return false;
	}

	return SelectedAssemblyOption >= 0;
}

//---------------------------------------------------------------------------------------
function EventListenerReturn OnAgentDutyAssigned(Object EventData, Object EventSource, XComGameState GameState, Name Event, Object CallbackData)
{
	Refresh();
	return ELR_NoInterrupt;
}

//---------------------------------------------------------------------------------------
//				INPUT
//---------------------------------------------------------------------------------------

function OnConfirm(UIButton Button)
{
	// Destructive? Route through extra confirmation
	if (`DIOHQ.ActiveResearchRef.ObjectID > 0)
	{
		`STRATPRES.ConfirmChangeAssemblyProject(CommitSelection);
	}
	else
	{
		CommitSelection('eUIAction_Accept');
	}
}

function OnWorkerSlotClicked(int SlotIndex)
{
	local UIDIOStrategyMap_AssignmentBubble Bubble;

	PlayMouseClickSound();
	Bubble = DioHUD.m_ScreensNav.GetBubbleAssignedTo('Research');
	if (Bubble != none)
	{
		Bubble.WorkerSlotClicked(SlotIndex);
	}
}

function CommitSelection(Name eAction)
{
	local X2StrategyGameRuleset StratRules;
	local X2DioResearchTemplate newResearch;

	if (eAction == 'eUIAction_Accept')
	{
		StratRules = `STRATEGYRULES;

		if (SelectedAssemblyOption >= 0 && SelectedAssemblyOption < RawDataOptions.Length)
		{
			newResearch = X2DioResearchTemplate(`STRAT_TEMPLATE_MGR.FindStrategyElementTemplate(RawDataOptions[SelectedAssemblyOption]));
			StratRules.SubmitStartResearch(newResearch);
			PlayConfirmSound();
		}

		DioHUD.UpdateData();
		Refresh();
	}
}

simulated function PreCloseScreen()
{
	local TDialogueBoxData DialogData;
	local XComGameState_HeadquartersDio DIOHQ;

	DioHQ = `DIOHQ;
	
	if (DioHQ.ActiveResearchRef.ObjectID > 0)
	{
		DioHQ.RemoveNotificationByType(eSNT_AssemblyIdle);
		CloseScreen();
	}
	// If leaving the screen with no active research *AND* player can afford one, prompt to confirm
	else if (bCanStartAnyResearch)
	{
		DialogData.eType = eDialog_Warning;
		DialogData.strTitle = PromptExitWithoutProjectTitle;
		DialogData.strText = PromptExitWithoutProjectBody;
		DialogData.strAccept = class'UIDialogueBox'.default.m_strDefaultAcceptLabel;
		DialogData.strCancel = class'UIDialogueBox'.default.m_strDefaultCancelLabel;
		DialogData.bMuteAcceptSound = true; // Generic confirm sound steps on screen-specific confirm and assign-agent sounds
		DialogData.fnCallback = OnConfirmExitWithoutProject;

		`STRATPRES.UIRaiseDialog(DialogData);
	}
	else
	{
		DioHQ.RemoveNotificationByType(eSNT_AssemblyIdle);
		CloseScreen();
	}
}

function OnConfirmExitWithoutProject(name eAction)
{
	if (eAction == 'eUIAction_Accept')
	{
		PlayMouseClickSound();
		CloseScreen();
	}
}

simulated function CloseScreen()
{
	UnRegisterForEvents();
	super.CloseScreen();
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

//---------------------------------------------------------------------------------------
function UpdateNavHelp()
{
	DioHUD.NavHelp.ClearButtonHelp();
	DioHUD.NavHelp.AddBackButton(PreCloseScreen);

	// mmg_john.hawley (11/7/19) - Updating NavHelp
	if (`ISCONTROLLERACTIVE)
	{
		DioHUD.NavHelp.AddSelectNavHelp(); // mmg_john.hawley (11/5/19) - Updating NavHelp for new controls
		DioHUD.NavHelp.AddLeftHelp(Caps(class'UIDIOStrategyMapFlash'.default.m_strOpenAssignment), class'UIUtilities_Input'.static.GetGamepadIconPrefix() $ class'UIUtilities_Input'.const.ICON_X_SQUARE);
		DioHUD.NavHelp.AddLeftHelp(Caps(class'UIDIOStrategyScreenNavigation'.default.CategoryLabel), class'UIUtilities_Input'.static.GetGamepadIconPrefix() $ class'UIUtilities_Input'.const.ICON_LTRT_L2R2);
		// Unused [2/27/2020 dmcdonough]
		//DioHUD.NavHelp.AddLeftHelp(Caps(class'UIDIOStrategyScreenNavigation'.default.SelectHQAreaLabel), class'UIUtilities_Input'.static.GetGamepadIconPrefix() $ class'UIUtilities_Input'.const.ICON_LBRB_L1R1);
	}
}

function BuildTabs()
{
	local UITabIconButton Tab;

	Tabs.AddItem(CreateTab(0, class'UIUtilities_Image'.const.CategoryIcon_Gun,		CategoryLabel_Gun));
	Tabs.AddItem(CreateTab(1, class'UIUtilities_Image'.const.CategoryIcon_Armor,	CategoryLabel_Armor));
	Tabs.AddItem(CreateTab(2, class'UIUtilities_Image'.const.CategoryIcon_CheckMark,CategoryLabel_CheckMark));
	Tabs.AddItem(CreateTab(3, class'UIUtilities_Image'.const.CategoryIcon_Grenade,	CategoryLabel_Grenade));
	Tabs.AddItem(CreateTab(4, class'UIUtilities_Image'.const.CategoryIcon_Breach,	CategoryLabel_Breach));
	Tabs.AddItem(CreateTab(5, class'UIUtilities_Image'.const.CategoryIcon_Robot,	CategoryLabel_Robot));
	Tabs.AddItem(CreateTab(6, class'UIUtilities_Image'.const.CategoryIcon_All,		CategoryLabel_Default));

	// mmg_john.hawley (11/25/19) - Do not let dpad input navigate tabs.
	foreach Tabs(Tab)
	{
		Tab.DisableNavigation();
	}
}

function UITabIconButton CreateTab(int index, string iconPath, string Label)
{
	local UITabIconButton Tab; 

	Tab = Spawn(class'UITabIconButton', self);
	Tab.InitButton(Name("IconTabMC_" $ index));
	Tab.SetIcon(iconPath);
	Tab.OnClickedDelegate = OnClickedTab;
	Tab.metadataString = Label;

	return Tab; 
}

function NextTab()
{
	SelectTabByIndex((SelectedTab + 1) % Tabs.length );
}

function PreviousTab()
{
	SelectTabByIndex((SelectedTab + Tabs.length - 1) % Tabs.length);
}

function OnClickedTab(UIButton Button)
{
	// Wait to set SelectedTab in SelectTabByIndex so that changes can be detected
	SelectTabByIndex(int(GetRightMost(Button.MCName)));
}

function SelectTabByIndex(int newIndex)
{
	local UITabIconButton Tab;
	local int i;

	if (newIndex != SelectedTab)
	{
		PlayMouseClickSound();
	}

	SelectedTab = newIndex; 

	RawDataOptions = RefreshDataOptions(GetTabResearchCategory(SelectedTab));
	OptionsList.ClearItems();
	Refresh();

	for( i = 0; i < Tabs.length; i++ )
	{
		Tab = Tabs[i];
		Tab.SetSelected(SelectedTab == i);
	}

	MC.FunctionString("SetCategoryLabel", Tabs[SelectedTab].metadataString);
}

function name GetTabResearchCategory(int Index)
{
	switch (Index)
	{
	case 0:	return 'Weapon';
	case 1:	return 'Armor';
	case 2:	return 'Base';
	case 3:	return 'Gear';
	case 4:	return 'Breach';
	case 5:	return 'Android';
	case 6: return '';
	}

	return 'Base';
}

function SetCurrentAssemblyInfo(string Label, int maxPips, int filledPips, int objectID, int objectID2 )
{
	MC.BeginFunctionOp("SetCurrentAssemblyInfo");
	MC.QueueString(Label);
	MC.QueueNumber(maxPips);
	MC.QueueNumber(filledPips);
	MC.EndOp();

	if( CurrentWorkerSlot == none )
	{
		CurrentWorkerSlot = Spawn(class'UIDIOStrategyMap_WorkerSlot', self).InitWorkerSlot('currentWorkerMC', 0);
		CurrentWorkerSlot.OnClickedDelegate = OnWorkerSlotClicked;
	}
	if( CurrentWorkerSlot2 == none )
	{
		CurrentWorkerSlot2 = Spawn(class'UIDIOStrategyMap_WorkerSlot', self).InitWorkerSlot('currentWorkerMC2', 0);
		CurrentWorkerSlot2.OnClickedDelegate = OnWorkerSlotClicked;
		
	}
	if( CurrentWorkerSlot3 == none )
	{
		CurrentWorkerSlot3 = Spawn(class'UIDIOStrategyMap_WorkerSlot', self).InitWorkerSlot('currentWorkerMC3', 0);
		CurrentWorkerSlot3.OnClickedDelegate = OnWorkerSlotClicked;
		CurrentWorkerSlot3.m_Index = 1;
	}

	if( objectID2 == -2 ) // Hidden
	{
		MC.FunctionVoid("FormatForSingleWorker");
		CurrentWorkerSlot.SetObjectID(objectID, class'UIUtilities_Colors'.const.DIO_BLUE_LIGHT_ASSEMBLY);
		CurrentWorkerSlot.Show();

		CurrentWorkerSlot2.Hide();
		CurrentWorkerSlot3.Hide();
	}
	else
	{
		MC.FunctionVoid("FormatForDoubleWorker");
		CurrentWorkerSlot.Hide();

		CurrentWorkerSlot2.SetObjectID(objectID, class'UIUtilities_Colors'.const.DIO_BLUE_LIGHT_ASSEMBLY);
		CurrentWorkerSlot2.Show();

		CurrentWorkerSlot3.SetObjectID(objectID2, class'UIUtilities_Colors'.const.DIO_BLUE_LIGHT_ASSEMBLY);
		CurrentWorkerSlot3.Show();
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

	switch (cmd)
	{
	case class'UIUtilities_Input'.const.FXS_MOUSE_5 :
	case class'UIUtilities_Input'.const.FXS_KEY_TAB :
	//case class'UIUtilities_Input'.const.FXS_BUTTON_RBUMPER :
	case class'UIUtilities_Input'.const.FXS_BUTTON_RTRIGGER :
		NextTab();
		break;

	case class'UIUtilities_Input'.const.FXS_MOUSE_4 :
	case class'UIUtilities_Input'.const.FXS_KEY_LEFT_SHIFT :
	//case class'UIUtilities_Input'.const.FXS_BUTTON_LBUMPER :
	case class'UIUtilities_Input'.const.FXS_BUTTON_LTRIGGER :
		PreviousTab();
		break;

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
		PreCloseScreen();
		bInputConsumed = true;
		break;
	
	default:
		bInputConsumed = bInputConsumed || false;
		break;
	}

	if (!bInputConsumed)
	{
		return OptionsList.OnUnrealCommand(cmd, arg);
	}

	return bInputConsumed;
}


//---------------------------------------------------------------------------------------

function bool SimulateScreenInteraction()
{
	OnConfirm(ConfirmButton);
	return true;
}

// mmg_john.hawley (11/13/19) - Update NavHelp when player swaps input device
simulated function OnReceiveFocus()
{
	super.OnReceiveFocus();
	
	Refresh();
	
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
	Package = "/ package/gfxAssembly/Assembly";
	MCName = "theScreen";

	bHideOnLoseFocus = false;
	bAnimateOnInit = true;
	bProcessMouseEventsIfNotFocused = false;
}
