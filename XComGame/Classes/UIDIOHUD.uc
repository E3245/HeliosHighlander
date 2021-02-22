
class UIDIOHUD extends UIScreen;

var UIPanel							MapBackgroundPanel;
var UIDIOResourceHeader				ResourcesPanel;
var UIDIOStrategyScreenNavigation	m_ScreensNav;
var UIDIOStrategyTurnControls		m_TurnControls;
var UIDIOCityUnrest					CityUnrest;
//var UIStrategyNotifications			Notifications; 
//var array<UIDIOStrategyMap_AssignmentBubble> m_assignments;
var UIList							AssignmentList; 
var array<UIDIOStrategyMap_WorkerSlot>		 m_ArmoryUnitHeads;
var UIFieldTeamHUD					FieldTeamHUD;
var UIStrategyObjectives			ObjectivesList;

var int m_iCurrentAssignmentActive; 
var int m_iCurrentDropdownActive;
var bool m_AllowAssignmentDropdowns;

var UIDIOStrategyMap_WorkerTray				 m_WorkerTray;
var UINavigationHelp NavHelp;

var UIPanel ArmoryHeadsContainer; 
var UIPanel	ArmoryHeadsBG;

var int NotificationIndex; // mmg_john.hawley (11/11/19) - Keep track of selected notification here

// var int CurrentSubItem; // mmg_john.hawley - UI gamepad fixes. For tracking submenu items if we decide to use it

//----------------------------------------------------------------------------
// MEMBERS

simulated function InitScreen(XComPlayerController InitController, UIMovie InitMovie, optional name InitName)
{
	local int i, Idx;
	local SeqEvent_DIOArmoryCharactersEntry LeaveArmoryEvent;
	local XComGameState_HeadquartersDio DioHQ;
	local array<SequenceObject> DIOArmoryEvents;
	local XComGameState_Unit myUnit;

	NotificationIndex = -1;

	// CurrentSubItem = -1; // mmg_john.hawley

	DioHQ = class'UIUtilities_DioStrategy'.static.GetDioHQ();

	super.InitScreen(InitController, InitMovie, InitName);
	
	RegisterForEvents();

	SetUpMapBackground();

	
	m_ScreensNav = Spawn(class'UIDIOStrategyScreenNavigation', self).InitScreenNavigation('ScreenNav');
	m_TurnControls = Spawn(class'UIDIOStrategyTurnControls', self).InitStrategyTurnControls('TurnControls');
	CityUnrest = Spawn(class'UIDIOCityUnrest', self).InitCityUnrestPanel();
	
	// Intentionally spawning the resources panel in front of the unrest meter, for mouse hittesting mappiness. 
	ResourcesPanel = Spawn(class'UIDIOResourceHeader', self).InitResourceHeader('Resources');

	//Notifications = Spawn(class'UIStrategyNotifications', self).InitStrategyNotification();

	FieldTeamHUD = Spawn(class'UIFieldTeamHUD', self).InitFieldTeamHUD();
	
	ResourcesPanel.OnSizeRealized = CityUnrest.RefreshLocation;
	RebuildArmoryHeads();

	class'Engine'.static.GetCurrentWorldInfo().GetGameSequence().FindSeqObjectsByClass(class'SeqEvent_DIOArmoryCharactersEntry', true, DIOArmoryEvents);
	for (Idx = 0; Idx < DIOArmoryEvents.Length; ++Idx)
	{
		LeaveArmoryEvent = SeqEvent_DIOArmoryCharactersEntry(DIOArmoryEvents[Idx]);
		for (i = 0; i < DioHQ.Squad.Length; i++)
		{
			myUnit = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(DioHQ.Squad[i].ObjectID));
			LeaveArmoryEvent.AddCharacterName(string(myUnit.GetSoldierClassTemplate().RequiredCharacterClass));
		}

		LeaveArmoryEvent.EnterArmory(PC);
	}

	m_WorkerTray = Spawn(class'UIDIOStrategyMap_WorkerTray', self).InitWorkerTray('workerTray');

	ObjectivesList = Spawn(class'UIStrategyObjectives', self).InitObjectives();

	NavHelp = Spawn(class'UINavigationHelp', self).InitNavHelp();
	NavHelp.bIsVerticalHelp = true;

	Navigator.Clear();
	Navigator.AddControl(m_ScreensNav);
	//Navigator.AddControl(Notifications);
}

simulated function OnInit()
{
	super.OnInit();

	Movie.InsertHighestDepthScreen(self);
}

function RegisterForEvents()
{
	local Object SelfObject;

	SelfObject = self;

	`XEVENTMGR.RegisterForEvent(SelfObject, 'STRATEGY_AgentDutyAssigned_Submitted', OnAgentAssignmentChanged, ELD_OnVisualizationBlockCompleted, , );
	`XEVENTMGR.RegisterForEvent(SelfObject, 'STRATEGY_AltStrategyMarketAdded_Submitted', OnMarketStatusChanged, ELD_Immediate, , );
	`XEVENTMGR.RegisterForEvent(SelfObject, 'STRATEGY_AltStrategyMarketRemoved_Submitted', OnMarketStatusChanged, ELD_Immediate, , );
	`XEVENTMGR.RegisterForEvent(SelfObject, 'STRATEGY_FieldTeamTargetingActivated', OnFieldTeamTargetingActivated, ELD_Immediate, , );
	`XEVENTMGR.RegisterForEvent(SelfObject, 'STRATEGY_FieldTeamTargetingDeactivated', OnFieldTeamTargetingDeactivated, ELD_Immediate, , );
	`XEVENTMGR.RegisterForEvent(SelfObject, 'STRATEGY_OperationStarted_Submitted', OnOperationStarted, ELD_OnStateSubmitted);
	`XEVENTMGR.RegisterForEvent(SelfObject, 'STRATEGY_UnitBoughtPromotionAbility_Submitted', OnUnitPromoted, ELD_OnStateSubmitted);
}

event Destroyed()
{
	local Object SelfObject;

	SelfObject = self;

	`XEVENTMGR.UnRegisterFromEvent(SelfObject, 'STRATEGY_AgentDutyAssigned_Submitted');
	`XEVENTMGR.UnRegisterFromEvent(SelfObject, 'STRATEGY_AltStrategyMarketAdded_Submitted');
	`XEVENTMGR.UnRegisterFromEvent(SelfObject, 'STRATEGY_AltStrategyMarketRemoved_Submitted');
	`XEVENTMGR.UnRegisterFromEvent(SelfObject, 'STRATEGY_FieldTeamTargetingActivated');
	`XEVENTMGR.UnRegisterFromEvent(SelfObject, 'STRATEGY_FieldTeamTargetingDeactivated');
	`XEVENTMGR.UnRegisterFromEvent(SelfObject, 'STRATEGY_OperationStarted_Submitted');
	`XEVENTMGR.UnRegisterFromEvent(SelfObject, 'STRATEGY_UnitBoughtPromotionAbility_Submitted');
}

simulated function SetUpMapBackground()
{
	local UIPanel BlackBGFill;

	MapBackgroundPanel = Spawn(class'UIPanel', self).InitPanel();
	
	BlackBGFill = Spawn(class'UIPanel', MapBackgroundPanel).InitPanel('', class'UIUtilities_Controls'.const.MC_GenericPixel);
	BlackBGFill.AnchorTopLeft();
	BlackBGFill.SetSize(Movie.UI_RES_X * 2, Movie.UI_RES_Y * 2 ); //huuuuuuge
	BlackBGFill.SetColor(class'UIUtilities_Colors'.const.BLACK_HTML_COLOR);

	Spawn(class'UIImage', MapBackgroundPanel).InitImage('MapBackgroundImage', "img:///UILibrary_Common.CityMap_PerspectiveTest");
}

simulated function RefreshAll()
{
	m_ScreensNav.RefreshAll();
	ResourcesPanel.RefreshAll();
	m_TurnControls.RefreshAll();
	CityUnrest.RefreshAll();
	//Notifications.RefreshDisplay();
}

simulated function HideResources()
{
	ResourcesPanel.Hide();
	m_ScreensNav.Hide();
	m_TurnControls.Hide();
	CityUnrest.Hide();
	//Notifications.Collapse();
}

simulated function HideAssignmentBubbles()
{
	m_AllowAssignmentDropdowns = false;
	m_ScreensNav.Hide();
}

simulated function HideForDayTransition()
{
	HideAssignmentBubbles();
	m_ScreensNav.Hide(); 
	//Notifications.Hide();
}

simulated function RebuildArmoryHeads()
{
	local XComGameState_HeadquartersDio DioHQ;
	local int NumHeads, i, TargetWidth;
	local UIPanel leftHelp, rightHelp;

	if(ArmoryHeadsContainer == none)
	{
		ArmoryHeadsContainer = Spawn(class'UIPanel', self).InitPanel('ArmoryHeadsContainer'); 
		ArmoryHeadsContainer.AnchorTopRight();

		ArmoryHeadsBG = Spawn(class'UIPanel', ArmoryHeadsContainer).InitPanel('ArmoryHeadsBGPanel', 'ArmoryTrayBG');
		ArmoryHeadsBG.SetPosition(-35, 10); //takes in to account the left art/button help 
		ArmoryHeadsBG.DisableNavigation();
		ArmoryHeadsBG.bAnimateOnInit = false;

		leftHelp = Spawn(class'UIPanel', ArmoryHeadsBG).InitPanel('leftHelpMC');
		rightHelp = Spawn(class'UIPanel', ArmoryHeadsBG).InitPanel('rightHelpMC');

		// mmg_john.hawley (11/22/19) - Hiding armory bumper icons. When I simply remove them, error images remain. Not sure if there is another spot to wack or if it requires a recook.
		leftHelp.SetVisible(false);
		rightHelp.SetVisible(false);
	}

	DioHQ = `DIOHQ;
	
	NumHeads = DioHQ.Squad.Length + DioHQ.Androids.Length;
	
	for (i = NumHeads; i < m_ArmoryUnitHeads.Length; ++i)
	{
		//remove extra heads, if we've lost a unit/spot. 
		m_ArmoryUnitHeads[i].Remove();
	}

	// Center container based on contents
	TargetWidth = (NumHeads * 100);
	ArmoryHeadsContainer.SetPosition(-TargetWidth-50, 10);
	ArmoryHeadsBG.SetWidth(TargetWidth + 60); // TODO: need help icons for console here. 

	for (i = 0; i < NumHeads; i++)
	{
		if (i >= m_ArmoryUnitHeads.Length)
		{
			// Add any new heads needed 
			m_ArmoryUnitHeads.AddItem(Spawn(class'UIDIOStrategyMap_WorkerSlot', ArmoryHeadsContainer));
			m_ArmoryUnitHeads[i].bAnimateOnInit = false; 
			m_ArmoryUnitHeads[i].InitWorkerSlot(name("WorkerSlot_" $ i), i);
			m_ArmoryUnitHeads[i].SetPanelScale(1.5);
		}
		m_ArmoryUnitHeads[i].SetPosition((i * 100), 10);
		m_ArmoryUnitHeads[i].OnClickedDelegate = ArmoryHeadClickDelegate;
	}
}

simulated function ShowArmoryHeads()
{
	RefreshArmoryHeads();
	ArmoryHeadsContainer.Show();
}

simulated function RefreshArmoryHeads()
{
	local int i, j, NumHeads;
	local XComGameState_HeadquartersDio DioHQ;
	local array<StateObjectReference> squadList;

	DioHQ = class'UIUtilities_DioStrategy'.static.GetDioHQ();
	squadList = DioHQ.Squad;
	squadList.Sort(SortSquadList);
	NumHeads = DioHQ.Squad.Length + DioHQ.Androids.Length;

	if (NumHeads != m_ArmoryUnitHeads.Length)
	{
		RebuildArmoryHeads();
	}

	for (i = 0; i < NumHeads; ++i)
	{
		m_ArmoryUnitHeads[i].Show();
		if (i < squadList.Length)
		{
			m_ArmoryUnitHeads[i].SetObjectID(squadList[i].ObjectID);
		}
		else
		{
			j = Max(i - squadList.Length, 0);
			m_ArmoryUnitHeads[i].SetObjectID(DioHQ.Androids[j].ObjectID);
		}
	}
}

simulated function HideArmoryHeads()
{
	ArmoryHeadsContainer.Hide();
}

simulated function int SortSquadList(StateObjectReference TargetA, StateObjectReference TargetB)
{
	local XComGameStateHistory History;
	local XComGameState_Unit WorkerA, WorkerB;
	local int				cameraA, cameraB;

	History = `XCOMHISTORY;
	WorkerA = XComGameState_Unit(History.GetGameStateForObjectID(TargetA.ObjectID));
	WorkerB = XComGameState_Unit(History.GetGameStateForObjectID(TargetB.ObjectID));

	cameraA = GetCameraValue(WorkerA.GetSoldierClassTemplate().RequiredCharacterClass);
	cameraB = GetCameraValue(WorkerB.GetSoldierClassTemplate().RequiredCharacterClass);

	return cameraB - cameraA;
}

simulated function int GetCameraValue(name CharacterClass)
{
	switch (CharacterClass)
	{
	case 'XComInquisitor':
		return 1;
	case 'XComDemoExpert':
		return 2;
	case 'XComPsion':
		return 3;
	case 'XComRanger':
		return 4;
	case 'XComMedic':
		return 5;
	case 'XComWarden':
		return 6;
	case 'XComEnvoy':
		return 7;
	case 'XComGunslinger':
		return 8;
	case 'XComOperator':
		return 9;
	case 'XComHellion':
		return 10;
	case 'XComBreaker':
		return 11;
	}

	return 99;
}

simulated function UpdateData()
{
	m_ScreensNav.RefreshAll();
}

//Updated the resources based on the current screen context. 
simulated function UpdateResources(UIScreen CurrentScreen)
{
	local UIDayTransitionScreen DayTransition; 
	
	// HELIOS BEGIN
	DayTransition = UIDayTransitionScreen(`SCREENSTACK.GetScreen(`PRESBASE.UIDayTransitionScreen));
	//HELIOS END

	UpdateData();
	HideArmoryHeads();
	m_WorkerTray.Hide();
	MapBackgroundPanel.Hide();
	m_TurnControls.Hide();
	if( DayTransition != none && !DayTransition.bIsFocused) DayTransition.Hide();
	//Notifications.Collapse(); 
	FieldTeamHUD.Hide();
	ObjectivesList.Hide();
	CityUnrest.Show();

	if (AreAssignmentBubblesActive())
	{
		m_ScreensNav.RefreshAll();
		
		m_AllowAssignmentDropdowns = true;
	}
	else
	{
		m_AllowAssignmentDropdowns = false;
		HideAssignmentBubbles();
	}

	switch (CurrentScreen.Class)
	{
	case class'UIDIOStrategyInvestigationChooserSimple' :
	case class'UICharacterUnlock' :
	case class'UIPauseMenu':	
		HideResources();
		m_ScreensNav.Hide();
		break;
	// HELIOS BEGIN
	// Reference the class that is set in the Presentation Base
	case `PRESBASE.UIPrimaryStrategyLayer:
	// HELIOS END	
		ResourcesPanel.Show();
		m_ScreensNav.Expand();
		if( DayTransition != none ) DayTransition.ShowSteady();
		//Notifications.Show();
		ObjectivesList.Show();
		break;
	case class'UIDIOWorkerReviewScreen' :
		ResourcesPanel.Show();
		m_ScreensNav.Hide();
		break;
	case class'UIResearchUnlocked':
	case class'UIResearchReport':
		ResourcesPanel.Show();
		m_ScreensNav.Collapse('Research');
		break;
	case class'UIDIOStrategyMap' :
	case class'UIDIOStrategyMapFlash' :
		ResourcesPanel.Show();
		m_ScreensNav.Collapse('APC');
		m_TurnControls.Show();
		if( DayTransition != none ) DayTransition.ShowSteady();
		FieldTeamHUD.Show();
		ObjectivesList.Show();
		break;
	case class'UIBlackMarket_Buy' :
		ResourcesPanel.Show();
		m_ScreensNav.Collapse('Supply');
		break;
	case class'UIScavengerMarket' :
		ResourcesPanel.Show();
		m_ScreensNav.Collapse('ScavengerMarket');
		break;
	case class'UIArmory_CompactLoadout':
		if (UIArmory_CompactLoadout(CurrentScreen).bComingFromSquadSelect)
		{
			break;
		}
	// HELIOS BEGIN
	// Reference the class that is set in the Presentation Base
	case `PRESBASE.ArmoryLandingArea :
	case `PRESBASE.Armory_MainMenu:
	// HELIOS END
	case class'UIArmory_Loadout' :
	case class'UIArmory_AndroidUpgrades':
	case class'UIArmory_Promotion' :
		HideResources();
	case class'UIDIOArmory_AndroidRepair':
		ShowArmoryHeads();
		m_ScreensNav.Collapse('Armory');
		break;
	case class'UIDIOSquadSelect' :
	case class'UICombatLose' :
		HideResources();
		m_ScreensNav.Hide();
		break; 
	case class'UIDIOTrainingScreen':
		ResourcesPanel.Show();
		m_ScreensNav.Collapse('Train');
		break;
	case class'UISpecOpsScreen' :
		ResourcesPanel.Show();
		m_ScreensNav.Collapse('SpecOps');
		break;
	case class'UIDIOAssemblyScreen' :
		ResourcesPanel.Show();
		m_ScreensNav.Collapse('Research');
		break;
	case class'UISharedHUD_TalkingHead' :
		//Notifications.Expand();
		break;
	case class'UIDebriefScreen' :
		HideResources();
		if (`STRATPRES.PendingDebriefScreen)
		{
			m_ScreensNav.Hide();
		}
		else
		{
			m_ScreensNav.Collapse('Investigation');
		}
		break;
	case class'UIDIOStrategyInvestigationChooserSimple':
		HideResources();
		m_ScreensNav.Hide();
		break;
	case class'UIDIOFieldTeamScreen' :
		m_ScreensNav.Hide();
		break;
	case class'UIEndGameStats' :
	case class'UICredits' :
	case class'UIDIOStrategyPicker_Operation':
	case class'UIDIOStrategyOperationChooserSimple':
		HideAssignmentBubbles();
		HideResources();
		m_ScreensNav.Hide();
		//Notifications.Hide();
		break;
	case class'UITutorialBox' :
		m_ScreensNav.Hide();
		//Notifications.Hide();
		break;
	default:
		HideResources();
		break;
	}
}

simulated function bool OnUnrealCommand(int cmd, int arg)
{
	local bool bHandled; // Has input been 'consumed'?

	bHandled = false;
	if (!CheckInputIsReleaseOrDirectionRepeat(cmd, arg))
		return false;

	if (m_WorkerTray.bIsVisible && m_WorkerTray.OnUnrealCommand(cmd, arg))
	{
		return true;
	}
	
	// mmg_john.hawley (12/16/19) - Don't let input leak through if we are in these menus
	// HELIOS BEGIN
	if (`SCREENSTACK.IsInStack(`PRESBASE.Armory_MainMenu) 
		|| `SCREENSTACK.IsInStack(`PRESBASE.ArmoryLandingArea) 
		|| `SCREENSTACK.IsInStack(class'UIBlackMarket_Buy') 
		|| `SCREENSTACK.IsInStack(class'UIDebriefScreen')
		|| `SCREENSTACK.IsInStack(class'UIDIOSquadSelect')) // HELIOS END
	{
		return true;
	}
	
	// Route input based on the cmd
	switch (cmd)
	{

	case class'UIUtilities_Input'.const.FXS_BUTTON_L3 :
		if (!m_TurnControls.bHidden)
		{
			bHandled = true;
			m_TurnControls.OnToggleAutoResolveButton(); // mmg_john.hawley
		}
		break;

	case class'UIUtilities_Input'.const.FXS_BUTTON_R3 :
		if (!m_TurnControls.bHidden)
		{
			bHandled = true;
			// mmg_aaron.lee (06/12/19) HACK BEGIN - save crash when spamming y button on end day
			if (!`ONLINEEVENTMGR.IsConsoleSaveInProgress())
			{
				// mmg_john.hawley (11/25/19) - Go to strategy map before we prompt the crit mission or end turn
				if (`SCREENSTACK.GetCurrentClass() != class'UIDIOStrategyMapFlash')
				{
					`STRATPRES.UIHQCityMapScreen();
					
				}
				
				m_TurnControls.OnTurnButton();		
			}
			// mmg_aaron.lee (06/12/19) HACK END
		}
		break;

	default:
		bHandled = false;
		break;
	}

	/*if (!bHandled && m_ScreensNav.bIsVisible)
		bHandled = m_ScreensNav.OnUnrealCommand(cmd, arg);
	else if (!bHandled) // mmg_john.hawley - Handle input for UI List as well
		bHandled = Notifications.OnUnrealCommand(cmd, arg);*/

	if (!bHandled)
	{
		return Navigator.OnUnrealCommand(cmd, arg); // mmg_john.hawle - warning: ungated this was causing a crash. should we even call it?
	}
	
	return bHandled;
}

simulated function OnMouseEvent(int cmd, array<string> args)
{
//	local int actionSelected;

	switch (cmd)
	{
	case class'UIUtilities_Input'.const.FXS_L_MOUSE_UP:
		if (InStr(args[4], "WorkerTray") != -1) // we clicked on a worker in the tray
		{
			m_workerTray.OnMouseEvent(cmd, args);
		}
		break;
	case class'UIUtilities_Input'.const.FXS_L_MOUSE_IN:
	case class'UIUtilities_Input'.const.FXS_L_MOUSE_OVER:
	case class'UIUtilities_Input'.const.FXS_L_MOUSE_DRAG_OVER:
		if (InStr(args[4], "WorkerTray") != -1)
		{
			PlayMouseOverSound();
		}
		break;
	}
}

// mmg_john.hawley - BEGIN creating functionality for alternate UI handling with gamepad
simulated function DeactivateAssignmentBubble()
{
	// mmg_john.hawley (11/7/19)
	/*if (m_iCurrentAssignmentActive >= 0 && m_iCurrentAssignmentActive < 4)
	{
		m_assignments[m_iCurrentAssignmentActive].AS_SetGlow(false);
		m_iCurrentAssignmentActive = -1;
	}*/
}

simulated function HighlightNextAssignmentBubble()
{
	// local XComStrategyPresentationLayer Pres;
	/*local int i, testAssignment;

	for (i = 1; i < m_assignments.Length; i++)
	{

		testAssignment = (m_iCurrentAssignmentActive + i) % m_assignments.Length;

		if (class'DioStrategyAI'.static.IsAssignmentAvailable(m_assignments[testAssignment].m_AssignmentName) == false)
		{
			continue;
		}

		//Pres = `STRATPRES;
			//Pres.UIClearToStrategyHUD();

		if (m_iCurrentAssignmentActive > -1)
		{
			m_assignments[m_iCurrentAssignmentActive].AS_SetGlow(false);
		}
		m_iCurrentAssignmentActive = testAssignment;

		//m_assignments[m_iCurrentAssignmentActive].Activate();
		m_assignments[m_iCurrentAssignmentActive].AS_SetGlow(true);

		return;
	}

	if (m_iCurrentAssignmentActive >= 0)
	{
		//m_assignments[m_iCurrentAssignmentActive].Activate();
		m_assignments[m_iCurrentAssignmentActive].AS_SetGlow(true);
	}*/
}

// mmg_john.hawley - BEGIN Requirements for navigating the submenus
//simulated function NavigateSubMenu()
//{
//	// Clamp value
//	if (CurrentSubItem < 0)
//	{
//		CurrentSubItem = 2;
//	}
//	else if (CurrentSubItem > 2)
//	{
//		CurrentSubItem = 0;
//	}
//
//	// Pick sub menu item
//	if (CurrentSubItem == 0)
//	{
//		OnClickArmoryScreen();
//	}
//	else if (CurrentSubItem == 1)
//	{
//		OnClickSupplyScreen();
//	}
//	else if (CurrentSubItem == 2)
//	{
//		OnClickInvestigationScreen();
//	}
//}
//
//function OnClickArmoryScreen()
//{
//	local XComStrategyPresentationLayer Pres;
//
//	Pres = `STRATPRES;
//	Pres.UIClearToStrategyHUD();
//	Pres.UIHQArmoryScreen();
//}
//
//function OnClickSupplyScreen()
//{
//	local XComStrategyPresentationLayer Pres;
//
//	Pres = `STRATPRES;
//	Pres.UIClearToStrategyHUD();
//	Pres.UIHQXCOMStoreScreen();
//}
//
//function OnClickInvestigationScreen()
//{
//	local XComStrategyPresentationLayer Pres;
//
//	Pres = `STRATPRES;
//	Pres.UIClearToStrategyHUD();
//}
// mmg_john.hawley - END

simulated function HighlightPreviousAssignmentBubble()
{
	// local XComStrategyPresentationLayer Pres;
	/*local int i, testAssignment;

	for (i = 1; i < m_assignments.Length; i++)
	{

		if (m_iCurrentAssignmentActive == -1)
		{
			m_iCurrentAssignmentActive = m_assignments.Length;
		}

		testAssignment = (m_iCurrentAssignmentActive - i + m_assignments.Length) % m_assignments.Length;

		if (class'DioStrategyAI'.static.IsAssignmentAvailable(m_assignments[testAssignment].m_AssignmentName) == false)
		{
			continue;
		}

		//Pres = `STRATPRES;
			//Pres.UIClearToStrategyHUD();

		if (m_iCurrentAssignmentActive > -1)
		{
			m_assignments[m_iCurrentAssignmentActive].AS_SetGlow(false);
		}
		m_iCurrentAssignmentActive = testAssignment;

		//m_assignments[m_iCurrentAssignmentActive].Activate();
		m_assignments[m_iCurrentAssignmentActive].AS_SetGlow(true);

		return;
	}

	if (m_iCurrentAssignmentActive >= 0)
	{
		m_assignments[m_iCurrentAssignmentActive].Activate();
		m_assignments[m_iCurrentAssignmentActive].AS_SetGlow(true);
	}*/
}

// mmg_john.hawley - END

simulated function ActivateNextAssignmentBubble()
{
	/*local XComStrategyPresentationLayer Pres;
	local int i, testAssignment;

	for (i = 1; i < m_assignments.Length; i++)
	{

		testAssignment = (m_iCurrentAssignmentActive + i) % m_assignments.Length;

		if (class'DioStrategyAI'.static.IsAssignmentAvailable(m_assignments[testAssignment].m_AssignmentName) == false)
		{
			continue;
		}

		Pres = `STRATPRES;
		Pres.UIClearToStrategyHUD();

		if (m_iCurrentAssignmentActive > -1)
		{
			m_assignments[m_iCurrentAssignmentActive].AS_SetGlow(false);
		}
		m_iCurrentAssignmentActive = testAssignment;

		m_assignments[m_iCurrentAssignmentActive].Activate();
		m_assignments[m_iCurrentAssignmentActive].AS_SetGlow(true);

		return;
	}	

	if (m_iCurrentAssignmentActive >= 0)
	{
		m_assignments[m_iCurrentAssignmentActive].Activate();
		m_assignments[m_iCurrentAssignmentActive].AS_SetGlow(true);
	}*/
}

simulated function ActivatePreviousAssignmentBubble()
{
	/*local XComStrategyPresentationLayer Pres;
	local int i, testAssignment;

	for (i = 1; i < m_assignments.Length; i++)
	{
		testAssignment = (m_iCurrentAssignmentActive - i + m_assignments.Length) % m_assignments.Length;

		if (class'DioStrategyAI'.static.IsAssignmentAvailable(m_assignments[testAssignment].m_AssignmentName) == false)
		{
			continue;
		}

		Pres = `STRATPRES;
			Pres.UIClearToStrategyHUD();

		if (m_iCurrentAssignmentActive > -1)
		{
			m_assignments[m_iCurrentAssignmentActive].AS_SetGlow(false);
		}
		m_iCurrentAssignmentActive = testAssignment;

		m_assignments[m_iCurrentAssignmentActive].Activate();
		m_assignments[m_iCurrentAssignmentActive].AS_SetGlow(true);

		return;
	}

	if (m_iCurrentAssignmentActive >= 0)
	{
		m_assignments[m_iCurrentAssignmentActive].Activate();
		m_assignments[m_iCurrentAssignmentActive].AS_SetGlow(true);
	}*/
}

simulated function HighlightTutorialAssignmentBubble(name AssignmentName, optional bool bShouldHighlight = true)
{
	/*local int i;
	local bool bFoundTag; 

	for( i = 0; i < m_assignments.Length; ++i )
	{
		if( m_assignments[i].m_AssignmentName == AssignmentName )
		{
			m_assignments[i].HighlightForTutorial(bShouldHighlight);
			return;
		}
	}

	// Assignment wasn't a bubble, so notify the screen nav
	bFoundTag = m_ScreensNav.HighlightTutorialItem(AssignmentName, bShouldHighlight);
	if( bFoundTag ) return; */
}

simulated function HighlightAssignmentBubble(name AssignmentName)
{
	/*local int i;

	for (i = 0; i < m_assignments.Length; ++i)
	{
		if (m_assignments[i].m_AssignmentName == AssignmentName)
		{
			m_iCurrentAssignmentActive = i;
			m_assignments[m_iCurrentAssignmentActive].AS_SetGlow(true);
		}
	}*/
}

simulated function bool AreAssignmentBubblesActive()
{
	switch (`SCREENSTACK.GetCurrentClass())
	{
	case class'UIDIOStrategyInvestigationChooserSimple' :
	case class'UICharacterUnlock' :
	case class'UIPauseMenu' :
	case class'UIDialogueBox' :
	case class'UITutorialBox' :
	case class'UIDIOWorkerReviewScreen' :
	case class'UIResearchUnlocked' :
	case class'UIResearchReport' :
	case class'UIDIOStrategyMap' :
	case class'UIDIOStrategyMapFlash' :
	case class'UIBlackMarket_Buy' :
	case class'UIDIOStrategyPicker_CharacterUnlocks' :
	// HELIOS BEGIN
	// Reference the class that is set in the Presentation Base
	case `PRESBASE.ArmoryLandingArea :
	case `PRESBASE.Armory_MainMenu:
	// HELIOS END
	case class'UIArmory_Loadout' :
	case class'UIArmory_CompactLoadout' :
	case class'UIArmory_AndroidUpgrades' :
	case class'UIArmory_Promotion' :
	case class'UIDIOSquadSelect' :
	case class'UICombatLose' :
	case class'UIDebriefScreen' :
	case class'UIDIOStrategyInvestigationChooserSimple' :
	case class'UIDIOFieldTeamScreen' :
	case class'UIDIOArmory_AndroidRepair':
		return false;
	}

	return true;
}

simulated function ArmoryHeadClickDelegate(int index)
{
	local UIArmory ArmoryScreen;
	local XComGameState_Unit Unit;

	Unit = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(m_ArmoryUnitHeads[index].WorkerObjectID));
	
	if( Unit == none ) return; 

	ArmoryScreen = UIArmory(`SCREENSTACK.GetFirstInstanceOf(class'UIArmory'));

	if( ArmoryScreen == none )
	{
		`STRATPRES.UIArmorySelectUnit(Unit.GetReference());
	}
	else
	{
		ArmoryScreen.CycleToSoldier(Unit.GetReference());
		
		if (!ArmoryScreen.CanCycleTo(Unit))
		{
			ArmoryScreen.OnCancel();
		}
	}
}

// mmg_aaron.lee (06/12/19) BEGIN - this function is to refresh turn button when the SaveStatus changed
function RefreshTurnButton()
{
	m_TurnControls.RefreshAll();
}
// mmg_aaron.lee (06/12/19) END


//---------------------------------------------------------------------------------------
//				EVENT LISTENERS
//---------------------------------------------------------------------------------------

function EventListenerReturn OnAgentAssignmentChanged(Object EventData, Object EventSource, XComGameState GameState, Name Event, Object CallbackData)
{
	UpdateData();
	return ELR_NoInterrupt;
}

function EventListenerReturn OnMarketStatusChanged(Object EventData, Object EventSource, XComGameState GameState, Name Event, Object CallbackData)
{
	local int i;
	local SeqEvent_DIOScavengerMarketStatus ScavengerMarketEvent;
	local array<SequenceObject> DIOEvents;
	local bool bMarketIsOpen; 

	bMarketIsOpen = `DIOHQ.IsScavengerMarketAvailable();

	class'Engine'.static.GetCurrentWorldInfo().GetGameSequence().FindSeqObjectsByClass(class'SeqEvent_DIOScavengerMarketStatus', true, DIOEvents);

	for (i = 0; i < DIOEvents.Length; ++i)
	{
		ScavengerMarketEvent = SeqEvent_DIOScavengerMarketStatus(DIOEvents[i]);
		ScavengerMarketEvent.Reset();
		ScavengerMarketEvent.UpdateStatus(bMarketIsOpen, PC);
	}
	return ELR_NoInterrupt;
}


function EventListenerReturn OnFieldTeamTargetingActivated(Object EventData, Object EventSource, XComGameState GameState, Name Event, Object CallbackData)
{
	local UIDayTransitionScreen DayTransition;

	// HELIOS BEGIN
	DayTransition = UIDayTransitionScreen(`SCREENSTACK.GetScreen(`PRESBASE.UIDayTransitionScreen));
	//HELIOS END
	if( DayTransition != none ) DayTransition.HideClock();

	m_ScreensNav.Hide();
	//Notifications.Hide();
	ObjectivesList.Hide(); 
	m_TurnControls.Hide();
	HideAssignmentBubbles();

	return ELR_NoInterrupt;
}

function EventListenerReturn OnFieldTeamTargetingDeactivated(Object EventData, Object EventSource, XComGameState GameState, Name Event, Object CallbackData)
{
	UpdateResources(`screenstack.GetCurrentScreen());

	return ELR_NoInterrupt;
}

function EventListenerReturn OnOperationStarted(Object EventData, Object EventSource, XComGameState GameState, Name Event, Object CallbackData)
{
	if (ObjectivesList != none)
	{
		ObjectivesList.RefreshAll();
	}

	return ELR_NoInterrupt;
}

function EventListenerReturn OnUnitPromoted(Object EventData, Object EventSource, XComGameState GameState, Name Event, Object CallbackData)
{
	// Trigger armory head refresh
	RefreshArmoryHeads();
	return ELR_NoInterrupt;
}

//---------------------------------------------------------------------------------------


defaultproperties
{
	MCName = "theScreen";
	Package = "/ package/gfxDIOHUD/DIOHUD";

	bHideOnLoseFocus = false;
	bProcessMouseEventsIfNotFocused = true;
	m_iCurrentAssignmentActive = -1;
}
