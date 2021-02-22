//---------------------------------------------------------------------------------------
//  FILE:    	UIDIOStrategyScreenNavigation
//  AUTHOR:  	David McDonough  --  5/16/2019
//  PURPOSE: 	HUD element for navigating among major Strategy-layer subscreens.
//           
//---------------------------------------------------------------------------------------
//  Copyright (c) 2019 Firaxis Games, Inc. All rights reserved.
//---------------------------------------------------------------------------------------
class UIDIOStrategyScreenNavigation extends UIPanel
	config(GameCore);

var UIList m_SubscreenList;
var array<UIStrategyNotificationItem> Items;
//var array<UIDIOStrategyMap_AssignmentBubble> m_arrMechaItems;
var int CurrentButtonCount;

var config bool bUseTestMap; 
var config bool bEnableTestButton;

var bool bCompact; 
var float CompactWidth;

var localized string CityMapScreenLabel;
var localized string ArmoryScreenLabel;
var localized string SupplyScreenLabel;
var localized string ResearchScreenLabel;
var localized string ScavengerMarketScreenLabel;
var localized string ShiftReportScreenLabel;
var localized string InvestigationScreenLabel;
var localized string UrgentStatusLabel;
var localized string UrgentStatusDefaultSummary;
var localized string SelectHQAreaLabel; // mmg_john.hawley - NavHelp Text for Navigating HQ
var localized string CategoryLabel;
var localized string NotificationsLabel;
var localized string MenuLabel;
var localized string AgentSelectionMenu;

simulated function UIDIOStrategyScreenNavigation InitScreenNavigation(optional name InitName)
{
	InitPanel(InitName);

	AnchorTopRight();

	m_SubscreenList = Spawn(class'UIList', self);
	m_SubscreenList.bAnimateOnInit = false;
	m_SubscreenList.bSelectFirstAvailable = true;
	m_SubscreenList.InitList('AssignmentFacilityList');
	m_SubscreenList.SetPosition(-Width, 100);
	Expand();
	m_SubscreenList.SetSelectedNavigation();

	RegisterForEvents();
	return self;
}

//---------------------------------------------------------------------------------------
function RegisterForEvents()
{
	local X2EventManager EventManager;
	local Object SelfObject;

	EventManager = `XEVENTMGR;
	SelfObject = self;

	EventManager.RegisterForEvent(SelfObject, 'STRATEGY_AgentDutyAssigned_Submitted', OnAgentDutyAssigned, ELD_OnStateSubmitted);
	EventManager.RegisterForEvent(SelfObject, 'STRATEGY_NotificationAdded', OnNotificationsChanged, ELD_OnStateSubmitted);
	EventManager.RegisterForEvent(SelfObject, 'STRATEGY_NotificationRemoved', OnNotificationsChanged, ELD_OnStateSubmitted);
	EventManager.RegisterForEvent(SelfObject, 'STRATEGY_NotificationChanged', OnNotificationsChanged, ELD_OnStateSubmitted);
}

//---------------------------------------------------------------------------------------
event Destroyed()
{
	local X2EventManager EventManager;
	local Object SelfObject;

	EventManager = `XEVENTMGR;
	SelfObject = self;

	EventManager.UnRegisterFromEvent(SelfObject, 'STRATEGY_AgentDutyAssigned_Submitted');
	EventManager.UnRegisterFromEvent(SelfObject, 'STRATEGY_NotificationAdded');
	EventManager.UnRegisterFromEvent(SelfObject, 'STRATEGY_NotificationRemoved');
	EventManager.UnRegisterFromEvent(SelfObject, 'STRATEGY_NotificationChanged');
}

function EventListenerReturn OnNotificationsChanged(Object EventData, Object EventSource, XComGameState GameState, Name Event, Object CallbackData)
{
	RefreshAll();
	return ELR_NoInterrupt;
}

//---------------------------------------------------------------------------------------
function EventListenerReturn OnAgentDutyAssigned(Object EventData, Object EventSource, XComGameState GameState, Name Event, Object CallbackData)
{
	RefreshAll();
	return ELR_NoInterrupt;
}

//---------------------------------------------------------------------------------------
simulated function OnInit()
{
	super.OnInit();
	SetTimer(0.5, false, 'HACK_DelayCreateItems', self);
}
function HACK_DelayCreateItems()
{
	//TODO: Can we cache and show/hide/refresh instead? -bsteiner 
	//m_arrMechaItems.Length = 0;
	m_SubscreenList.ClearItems();
	Items.Length = 0;

	CreateAssignmentBubble('APC');
	CreateAssignmentBubble('Research');
	CreateAssignmentBubble('SpecOps');
	CreateAssignmentBubble('Train');
	CreateAssignmentBubble('Armory');
	CreateAssignmentBubble('Supply');
	CreateAssignmentBubble('Investigation');
	CreateAssignmentBubble('ScavengerMarket');
	//CreateAssignmentBubble('Test');

	RefreshAll();
	m_SubscreenList.SetSelectedIndex(0, true);
}

function Collapse( optional name PeekabooAssignment = '' )
{
	local int i;
	local UIDIOStrategyMap_AssignmentBubble Bubble;
	local UIStrategyNotificationItem Item;
	local UIPanel ListItem; 

	Show();

	if( !bCompact )
	{
		m_SubscreenList.RemoveTweens();
		m_SubscreenList.AnimateX(-CompactWidth, 0.5f);

		for( i = 0; i < m_SubscreenList.GetItemCount(); i++ )
		{
			ListItem = m_SubscreenList.GetItem(i); 
			Bubble = UIDIOStrategyMap_AssignmentBubble(ListItem);
			if(Bubble != none)
			{
				Bubble.Peekaboo(PeekabooAssignment);
			}
			Item = UIStrategyNotificationItem(ListItem);
			if(Item != none)
			{
				Item.Hide();
			}

		}

		m_SubscreenList.RealizeItems();
		bCompact = true;
	}
}

function Expand()
{
	local int i;
	local UIDIOStrategyMap_AssignmentBubble Bubble;
	local UIStrategyNotificationItem Item;
	local UIPanel ListItem;

	Show();
	if( bCompact )
	{
		m_SubscreenList.RemoveTweens();
		m_SubscreenList.AnimateX(-Width, 0.5f);

		for( i = 0; i < m_SubscreenList.GetItemCount(); i++ )
		{
			ListItem = m_SubscreenList.GetItem(i);
			Bubble = UIDIOStrategyMap_AssignmentBubble(ListItem);
			if(Bubble != none)
			{
				Bubble.RealizeDefaultX();
			}
			Item = UIStrategyNotificationItem(ListItem);
			if(Item != none)
			{
				Item.Show();
			}

			m_SubscreenList.RealizeItems();
		}

		bCompact = false;
	}
}

//---------------------------------------------------------------------------------------
simulated function Show()
{
	super.Show();
	//RefreshAll();
}

//---------------------------------------------------------------------------------------
simulated function RefreshAll()
{
	local int i; 
	local XComGameState_HeadquartersDio DioHQ;
	local UIStrategyNotificationItem Item;

	DioHQ = class'UIUtilities_DioStrategy'.static.GetDioHQ();

	for (i = 0; i < 8; i++)
	{
		UIDIOStrategyMap_AssignmentBubble(m_SubscreenList.GetItem(i)).UpdateData();
	}

	for (i = 0; i < DioHQ.Notifications.Length; i++)
	{
		// Build new items if we need to. 
		if (i > Items.Length - 1)
		{
			Item = UIStrategyNotificationItem(m_SubscreenList.CreateItem(class'UIStrategyNotificationItem')).InitItem(m_SubscreenList);
			Items.AddItem(Item);
		}

		// Grab our target Item
		Item = Items[i];

		//Update Data 
		Item.Refresh(DioHQ.Notifications[i]);

		if (bCompact)
		{
			Item.Hide();
		}
	}

	// Remove any excess list items if we didn't use them. 
	for (i = DioHQ.Notifications.Length; i < Items.Length; i++)
	{
		Items[i].Remove();
		Items.Remove(i, 1);
	}

	m_SubscreenList.RealizeItems();
}

function CreateAssignmentBubble(name UniqueName)
{
	local UIDIOStrategyMap_AssignmentBubble NewBubble;

	//if( class'DioStrategyAI'.static.IsAssignmentAvailable(UniqueName) )
	//{
		NewBubble = UIDIOStrategyMap_AssignmentBubble(m_SubscreenList.CreateItem(class'UIDIOStrategyMap_AssignmentBubble'));
		NewBubble.InitAssignmentBubble(name("Assignment_" $ m_SubscreenList.GetItemCount()), UniqueName);
		//NewBubble.UpdateData();
	//}
}

function bool HighlightTutorialItem(name AssignmentName, optional bool bShouldHighlight = true)
{
	local UIDIOStrategyMap_AssignmentBubble Bubble;
	local int i; 

	for( i=0; i < m_SubscreenList.NumChildren(); i++ )
	{
		Bubble = UIDIOStrategyMap_AssignmentBubble(m_SubscreenList.GetChildAt(i, false));
		if( Bubble == none ) continue; 

		if( Bubble.m_AssignmentName == AssignmentName )
		{
			Bubble.HighlightForTutorial(bShouldHighlight);
			return true; // found a tag
		}
	}
	return false; // no tag found 
}

function UIDIOStrategyMap_AssignmentBubble GetControllerSelectedBubble()
{
	if (`ISCONTROLLERACTIVE)
	{
		return UIDIOStrategyMap_AssignmentBubble(m_SubscreenList.GetSelectedItem());
	}
	return none;
}


function UIDIOStrategyMap_AssignmentBubble GetBubbleAssignedTo(name AssignmentName)
{
	local UIDIOStrategyMap_AssignmentBubble Bubble;
	local int i;

	for( i = 0; i < m_SubscreenList.ItemCount; i++ )
	{
		Bubble = UIDIOStrategyMap_AssignmentBubble(m_SubscreenList.GetItem(i));
		if( Bubble == none ) continue;

		if( Bubble.m_AssignmentName == AssignmentName )
		{
			return Bubble; // found a tag
		}
	}
	return none;
}

function ActivateIfPossible(name AssignmentName)
{
	local UIDIOStrategyMap_AssignmentBubble Bubble;
	Bubble = GetBubbleAssignedTo(AssignmentName);
	if (Bubble != none) 
	{
		Bubble.Activate();
	}
}

simulated function bool OnUnrealCommand(int cmd, int arg)
{
	local bool bHandled; // Has input been 'consumed'?
	bHandled = false;

	if( !CheckInputIsReleaseOrDirectionRepeat(cmd, arg) )
		return false;

	// Route input based on the cmd
	switch( cmd )
	{
	case class'UIUtilities_Input'.const.FXS_KEY_1 : ActivateIfPossible('APC');			break;
	case class'UIUtilities_Input'.const.FXS_KEY_2 : ActivateIfPossible('Research');		break;
	case class'UIUtilities_Input'.const.FXS_KEY_3 : ActivateIfPossible('SpecOps');		break;
	case class'UIUtilities_Input'.const.FXS_KEY_4 : ActivateIfPossible('Train');		break;
	case class'UIUtilities_Input'.const.FXS_KEY_5 : ActivateIfPossible('Armory');		break;
	case class'UIUtilities_Input'.const.FXS_KEY_6 : ActivateIfPossible('Supply');		break;
	case class'UIUtilities_Input'.const.FXS_KEY_7 : ActivateIfPossible('Investigation');break;
	case class'UIUtilities_Input'.const.FXS_KEY_8 : ActivateIfPossible('ScavengerMarket'); break;

		case class'UIUtilities_Input'.const.FXS_KEY_Z :
		//case class'UIUtilities_Input'.const.FXS_BUTTON_RBUMPER : // mmg_john.hawley - Disabling to prevent interference with new control scheme
			Navigator.Next();
		break;

		case class'UIUtilities_Input'.const.FXS_KEY_C :
		//case class'UIUtilities_Input'.const.FXS_BUTTON_LBUMPER : // mmg_john.hawley - Disabling to prevent interference with new control scheme
			Navigator.Prev();
		break;

		default:
			bHandled = false;
			break;
	}

	if( !bHandled )
	{
		bHandled = m_SubscreenList.OnUnrealCommand(cmd, arg);
	}
	return bHandled;
}

//---------------------------------------------------------------------------------------
function bool ShowInvestigationStatusButton()
{
	if (class'DioStrategyTutorialHelper'.static.IsInvestigationStatusTutorialLocked())
	{
		return false;
	}
	
	return true;
}

function OnClickArmoryScreen()
{
	local XComStrategyPresentationLayer Pres;

	// Early out: blocked by tutorial
	if( class'DioStrategyTutorialHelper'.static.IsArmoryTutorialLocked() )
	{
		return;
	}

	Pres = `STRATPRES;
	Pres.UIClearToStrategyHUD();
	// HELIOS BEGIN
	`PRESBASE.UIHQArmoryScreen();
	// HELIOS END
}

function OnClickMapScreen()
{
	local XComStrategyPresentationLayer Pres;

	if( `SCREENSTACK.IsNotInStack(class'UIDIOStrategyMapFlash', false) )
	{
		Pres = `STRATPRES;
			Pres.UIClearToStrategyHUD();
		Pres.UIHQCityMapScreen();
	}
}
function OnClickSupplyScreen()
{
	local XComStrategyPresentationLayer Pres;

	// Early out: blocked by tutorial
	if( class'DioStrategyTutorialHelper'.static.IsSupplyTutorialLocked() )
	{
		return;
	}

	Pres = `STRATPRES;
		Pres.UIClearToStrategyHUD();
	Pres.UIHQXCOMStoreScreen();
}

function OnClickScavengerMarketScreen()
{
	local XComStrategyPresentationLayer Pres;

	if( !`DIOHQ.IsScavengerMarketAvailable() )
	{
		return;
	}

	Pres = `STRATPRES;
		Pres.UIClearToStrategyHUD();
	Pres.UIScavengerMarketScreen();
}

function OnClickInvestigationScreen()
{
	local XComGameState_Investigation CurrentInvestigation;
	local XComStrategyPresentationLayer Pres;

	Pres = `STRATPRES;

		// Non-standard Investigations show a popup instead of the full screen
		CurrentInvestigation = class'DioStrategyAI'.static.GetCurrentInvestigation();
	if( CurrentInvestigation.GetMyTemplateName() == 'Investigation_Tutorial' ||
	   CurrentInvestigation.GetMyTemplateName() == 'Investigation_FinaleConspiracy' )
	{
		// Show title and briefing for the current operation worker
		ShowUrgentStatusPopup();
	}
	else
	{
		Pres.UIClearToStrategyHUD();
		Pres.UIDebriefScreen();
	}
}



function ShowUrgentStatusPopup()
{
	local XComStrategyPresentationLayer StratPres;
	local XComGameState_InvestigationOperation Operation;
	local X2DioInvestigationOperationTemplate OpTemplate;
	local string Title, Text;

	StratPres = `STRATPRES;
	Operation = class'DioStrategyAI'.static.GetCurrentOperation();
	OpTemplate = Operation.GetMyTemplate();

	if (OpTemplate.OnGetUrgentStatusHeader != none)
	{
		Title = OpTemplate.OnGetUrgentStatusHeader(OpTemplate);
	}
	
	if (OpTemplate.OnGetUrgentStatusText != none)
	{
		Text = OpTemplate.OnGetUrgentStatusText(OpTemplate);
	}

	// Failsafe
	if (Title == "")
	{
		Title = UrgentStatusLabel;
	}
	if (Text == "")
	{
		Text = UrgentStatusDefaultSummary;
	}

	StratPres.UIWarningDialog(Title, Text, eDialog_Alert);
}

function OnTest()
{
	`STRATEGYRULES.UIDIOStrategyTestButton();
}

function float GetWidth()
{
	return bCompact ? default.CompactWidth : default.Width;
}

defaultproperties
{
	bAnimateOnInit = false; 
	Width = 490;
	CompactWidth = 55;
	bCompact = false;
}