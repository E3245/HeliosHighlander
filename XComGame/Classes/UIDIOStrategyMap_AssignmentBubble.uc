class UIDIOStrategyMap_AssignmentBubble extends UIPanel
	config(UI);

var GFxObject RootMC;
var name m_AssignmentName;
var int m_AvailableWorkerSlots, m_SelectedWorkerSlot;
var array<UIDIOStrategyMap_WorkerSlot> WorkerSlots;
var UIDIOStrategyMap_WorkerTray WorkerTray;
var UITutorialHighlight TutorialHighlight;
var UIList OwningList;
var bool bIsPeekaboo;

var string BubbleColor;
var config string UnassignAgentSound;
var config string AssignAgentSound;

var localized string Title_CityMap;
var localized string APCStatus_NotEnoughUnitsOnBoard;
var localized string APCStatus_Ready;
var localized string APCStatus_ReturningToHQ;
var localized string Title_SpecOps;
var localized string SpecOpsStatus_Inactive;
var localized string Title_Assembly;
var localized string AssemblyStatus_Inactive;
var localized string Title_Training;
var localized string TrainingStatus_Active;
var localized string TrainingStatus_InActive;


simulated function UIDIOStrategyMap_AssignmentBubble InitAssignmentBubble(name InitName, name InAssignmentName)
{
	m_AssignmentName = InAssignmentName;

	InitPanel(InitName);

	return self;
}

simulated function OnInit()
{
	local int i;
	
	super.OnInit();

	OwningList = UIList(Owner.Owner); 

	RootMC = Movie.GetVariableObject(MCPath $ "");
	RegisterForEvents();

	for (i = 0; i < 4; i++) // Hard-coded 4 slots
	{
		WorkerSlots.AddItem(Spawn(class'UIDIOStrategyMap_WorkerSlot', self));
		WorkerSlots[i].InitWorkerSlot(name("slot"$i), i);
		WorkerSlots[i].OnClickedDelegate = WorkerSlotClicked;
		Navigator.RemoveControl(WorkerSlots[i]);
	}

	switch (m_AssignmentName)
	{
	case 'APC':		
		UpdateDataAPC();
		break;
	case 'Research':
		UpdateDataResearch();
		break;
	case 'SpecOps':
		UpdateDataSpecOps();
		break;
	case 'Train':
		UpdateDataTraining();
		break;
	case 'Armory':
		UpdateDataSimple(class'UIDIOStrategyScreenNavigation'.default.ArmoryScreenLabel, "img:///UILibrary_Common.StrategyHUDIcon_Armory");
		break;
	case 'Supply':
		UpdateDataSimple(class'UIDIOStrategyScreenNavigation'.default.SupplyScreenLabel, "img:///UILibrary_Common.StrategyHUDIcon_Supply");
		break;
	case 'Investigation':
		UpdateDataSimple(class'UIDIOStrategyScreenNavigation'.default.InvestigationScreenLabel, "img:///UILibrary_Common.StrategyHUDIcon_Investigation");
		break;
	case 'ScavengerMarket':
		UpdateDataSimple(class'UIDIOStrategyScreenNavigation'.default.ScavengerMarketScreenLabel, "img:///UILibrary_Common.StrategyHUDIcon_Scavenger");
		break;
	case 'Test':
		UpdateDataSimple("TEST");
		break;
	// HELIOS BEGIN
	// Overriding this in a child class does not work, because:
	//	1) when the show function activates, the items are realized and cannot be modified further (needs more testing, but I'm certain it's hardcoded in SWFMovie).
	//	2) actually overriding this function causes all other buttons to cease working (APC, Supply, etc).
	// The intent is to have a function that can be overriden in child classes so they can update their data as needed when init'd
	default:
		ResolveAssignmentName(m_AssignmentName);
		break;
	// HELIOS END
	}
	if (!class'DioStrategyAI'.static.IsAssignmentAvailable(m_AssignmentName))
	{
		Hide();
	}
	else
	{
		Show();
	}
}

// Override in child classes
simulated function ResolveAssignmentName(name AssignmentName)
{
	
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
function EventListenerReturn OnAgentDutyAssigned(Object EventData, Object EventSource, XComGameState GameState, Name Event, Object CallbackData)
{
	UpdateData();
	return ELR_NoInterrupt;
}

// Check if this bubble represents a duty/assignment that Agents can be assigned to
simulated function bool ValidForWorkerAssignment()
{
	// Not Armory, Supply, Investigation, or Scavenger
	switch (m_AssignmentName)
	{
	case 'APC':
	case 'Research':
	case 'SpecOps':
	case 'Train':
		return true;
	}

	return false;
}

simulated function WorkerSlotClicked(int index)
{
	WorkerTray = `STRATPRES.DIOHUD.m_WorkerTray;

	if( `SCREENSTACK.IsInStack(class'UIArmoryLandingArea') )
	{
		`STRATPRES.UIClearToStrategyHUD();
	}

	WorkerTray.AttachToPanel(self, index);
	WorkerTray.UpdateData(WorkerSlots[index], BubbleColor);
	WorkerTray.SetVisible(true);
	WorkerTray.OnWorkerClickedDelegate = OnWorkerTrayItemClicked;  

}
//Note that we're reporting back which worker slot on the bubble activated the tray to open. 
function OnWorkerTrayItemClicked(UIDIOStrategyMap_WorkerSlot WorkerSlot, int WorkerObjectID)
{
	local XComStrategyPresentationLayer StratPres;
	local X2StrategyGameRuleset StratRules;
	local XComGameState_Unit Unit;
	local StateObjectReference UnitRef, previousUnitRef;

	StratRules = `STRATEGYRULES;
	StratPres = `STRATPRES;
	`log("Clicked on worker: " @ WorkerObjectID, , 'uixcom');

	UnitRef.ObjectID = WorkerObjectID;
	Unit = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(UnitRef.ObjectID));

	switch (m_AssignmentName)
	{
	case 'APC':
		if (WorkerSlot.WorkerObjectID == WorkerObjectID)
		{
			// Unassigning from APC is not destructive, no need to prompt
			StratRules.SubmitAssignAgentDuty(UnitRef, 'Unassign');
			`SOUNDMGR.PlayLoadedAkEvent(UnassignAgentSound);
		}
		else
		{
			// APC needs no picker so go straight to confirmation check
			if (class'DioStrategyAI'.static.IsAgentAssignmentChangeDestructive(UnitRef, 'APC'))
			{
				StratPres.UIConfirmSwitchDutyAssignment(Unit, 'APC', , WorkerSlot.WorkerObjectID);
			}
			else
			{
				if (WorkerSlot.WorkerObjectID != -1)
				{
					previousUnitRef.ObjectID = WorkerSlot.WorkerObjectID;
					StratRules.SubmitAssignAgentDuty(previousUnitRef, 'Unassign');
				}

				StratRules.SubmitAssignAgentDuty(UnitRef, 'APC');
				`SOUNDMGR.PlayLoadedAkEvent(AssignAgentSound);
			}
		}
		break;
	case 'Research':
		if (WorkerSlot.WorkerObjectID == WorkerObjectID)
		{
			// Unassigning from Research is not destructive, no need to prompt
			StratRules.SubmitAssignAgentDuty(UnitRef, 'Unassign');
			`SOUNDMGR.PlayLoadedAkEvent(UnassignAgentSound);
		}
		else
		{
			// Research needs no picker to pipe straight to commit or confirm
			if (class'DioStrategyAI'.static.IsAgentAssignmentChangeDestructive(UnitRef, 'Research'))
			{
				StratPres.UIConfirmSwitchDutyAssignment(Unit, 'Research', , WorkerSlot.WorkerObjectID);
			}
			else
			{
				if (WorkerSlot.WorkerObjectID != -1)
				{
					previousUnitRef.ObjectID = WorkerSlot.WorkerObjectID;
					StratRules.SubmitAssignAgentDuty(previousUnitRef, 'Unassign');
				}

				StratRules.SubmitAssignAgentDuty(UnitRef, 'Research');
				`SOUNDMGR.PlayLoadedAkEvent(AssignAgentSound);
			}
		}
		break;
	case 'SpecOps':
		if (WorkerSlot.WorkerObjectID == WorkerObjectID)
		{
			StratPres.PromptDestructiveUnassignAgentDuty(UnitRef);
		}
		else
		{
			if (WorkerSlot.WorkerObjectID > 0)
			{
				// Replacing Agents in Spec Ops cancels their action, prompt to confirm
				previousUnitRef.ObjectID = WorkerSlot.WorkerObjectID;
				StratPres.ConfirmReplaceSpecOpAgent(previousUnitRef, UnitRef, Callback_ReplaceSpecOps);
			}
			else
			{
				StratPres.UISpecOpsActionPicker(UnitRef);
			}
		}
		break;
	case 'Train':
		if (WorkerSlot.WorkerObjectID == WorkerObjectID)
		{
			StratPres.PromptDestructiveUnassignAgentDuty(UnitRef);
		}
		else
		{
			if (WorkerSlot.WorkerObjectID != -1)
			{
				previousUnitRef.ObjectID = WorkerSlot.WorkerObjectID;
				StratRules.SubmitAssignAgentDuty(previousUnitRef, 'Unassign');
			}
			StratPres.UITrainingActionPicker(UnitRef);
		}
		break;
	}

	WorkerTray.Hide();
	StratPres.DIOHUD.UpdateData(); //refresh assignment bubbles 
}

function Callback_ReplaceSpecOps(name eAction, UICallbackData xUserData)
{
	local UICallbackData_StateObjectReference CallbackData;
	local X2StrategyGameRuleset StratRules;

	if (eAction == 'eUIAction_Accept')
	{
		StratRules = `STRATEGYRULES;
		CallbackData = UICallbackData_StateObjectReference(xUserData);
		if (CallbackData == none)
		{
			return;
		}
	
		// Unassign previous unit	
		if (CallbackData.ObjectRef.ObjectID > 0)
		{
			StratRules.SubmitAssignAgentDuty(CallbackData.ObjectRef, 'Unassign');
			`SOUNDMGR.PlayLoadedAkEvent(AssignAgentSound);
		}
		
		// Show picker for new unit
		if (CallbackData.ObjectRef2.ObjectID > 0)
		{
			`STRATPRES.UISpecOpsActionPicker(CallbackData.ObjectRef2);
		}
	}
}

//---------------------------------------------------------------------------------------
simulated function UpdateData()
{
	if (!bIsInited)
	{
		return;
	}

	if (!class'DioStrategyAI'.static.IsAssignmentAvailable(m_AssignmentName))
	{
		Hide();
		SetY(-500);
		return;
	}

	switch (m_AssignmentName)
	{
	case 'APC':
		UpdateDataAPC();
		break;
	case 'Research':
		UpdateDataResearch();
		break;
	case 'SpecOps':
		UpdateDataSpecOps();
		break;
	case 'Train':
		UpdateDataTraining();
		break;
	case 'Armory':
		UpdateDataSimple(class'UIDIOStrategyScreenNavigation'.default.ArmoryScreenLabel, "img:///UILibrary_Common.StrategyHUDIcon_Armory");
		break;
	case 'Supply':
		UpdateDataSimple(class'UIDIOStrategyScreenNavigation'.default.SupplyScreenLabel, "img:///UILibrary_Common.StrategyHUDIcon_Supply");
		break;
	case 'Investigation':
		UpdateDataSimple(class'UIDIOStrategyScreenNavigation'.default.InvestigationScreenLabel, "img:///UILibrary_Common.StrategyHUDIcon_Investigation");
		break;
	case 'ScavengerMarket':
		UpdateDataSimple(class'UIDIOStrategyScreenNavigation'.default.ScavengerMarketScreenLabel, "img:///UILibrary_Common.StrategyHUDIcon_Scavenger");
		break;
	case 'Test':
		UpdateDataSimple("TEST");
		break;
	}

	Show();
	//RealizeLocation();
}

simulated function UpdateDataAPC()
{
	local XComGameState_HeadquartersDio DioHQ;
	local GFxObject gfxObjectData, gfxWorkerSlotsArray, gfxWorkerSlotData;
	local XComGameStateHistory History;
	local array<StateObjectReference> PlayerWorkers;
	local XComGameState_Unit Worker;
	local X2SoldierClassTemplate SoldierClassTemplate;
	local int i;

	History = `XCOMHISTORY;
	DioHQ = `DIOHQ;
	gfxObjectData = Movie.CreateObject("Object");
	gfxWorkerSlotsArray = Movie.CreateArray(true);

	gfxObjectData.SetString("name", Title_CityMap);
	
	m_AvailableWorkerSlots = 4; // Hard-coded

	PlayerWorkers = DioHQ.APCRoster;
	if (DioHQ.IsAPCReady())
	{
		if (PlayerWorkers.Length < 4)
		{
			gfxObjectData.SetString("status", APCStatus_NotEnoughUnitsOnBoard);
		}
		else
		{
			gfxObjectData.SetString("status", APCStatus_Ready);
		}
	}
	else
	{
		gfxObjectData.SetString("status", APCStatus_ReturningToHQ);
	}

	gfxObjectData.SetString("icon", class'UIUtilities_Image'.const.CityMapAssignment_City);
	BubbleColor = class'UIUtilities_Colors'.const.DIO_PURPLE_LIGHT_CITY_MAP;
	gfxObjectData.SetString("color", BubbleColor);
	gfxObjectData.SetBool("bNeedsAttention", class'DioStrategyNotificationsHelper'.static.APCNeedsAttention());

	gfxObjectData.SetFloat("meterPips", 0);
	
	for (i = 0; i < WorkerSlots.Length; i++)
	{
		if (i >= PlayerWorkers.Length)
		{
			WorkerSlots[i].WorkerObjectID = -1; 

			gfxWorkerSlotData = Movie.CreateObject("Object");

			gfxWorkerSlotData.SetString("name", " ");
			gfxWorkerSlotData.SetString("workerIcon", " ");
			gfxWorkerSlotData.SetString("regionColor", BubbleColor);
			gfxWorkerSlotData.SetBool("bHasScars", false);
			gfxWorkerSlotData.SetBool("bHasUpgrades", false);

			gfxWorkerSlotData.SetFloat("unitID", -1);
			WorkerSlots[i].SetObjectID(-1, BubbleColor);
			gfxWorkerSlotData.SetBool("isLocked", false);

			gfxWorkerSlotsArray.SetElementObject(i, gfxWorkerSlotData);
		}
		else
		{
			Worker = XComGameState_Unit(History.GetGameStateForObjectID(PlayerWorkers[i].ObjectID));
			if (Worker == none)
			{
				WorkerSlots[i].WorkerObjectID = -1;
				continue;
			}

			SoldierClassTemplate = Worker.GetSoldierClassTemplate();

			gfxWorkerSlotData = Movie.CreateObject("Object");

			gfxWorkerSlotData.SetString("name", Worker.GetFullName());
			gfxWorkerSlotData.SetString("workerIcon", SoldierClassTemplate.WorkerIconImage);
			//gfxWorkerSlotData.SetString("factionIcon", SoldierClassTemplate.PosedIconImage);
			gfxWorkerSlotData.SetString("regionColor", BubbleColor);
			gfxWorkerSlotData.SetBool("bHasScars", Worker.Scars.Length > 0);
			gfxWorkerSlotData.SetBool("bHasUpgrades", Worker.ShowPromoteIcon());

			gfxWorkerSlotData.SetFloat("unitID", PlayerWorkers[i].ObjectID);
			WorkerSlots[i].WorkerObjectID = PlayerWorkers[i].ObjectID;
			WorkerSlots[i].SetObjectID(PlayerWorkers[i].ObjectID, BubbleColor);
			gfxWorkerSlotData.SetBool("isLocked", false);

			gfxWorkerSlotsArray.SetElementObject(i, gfxWorkerSlotData);
		}
	}

	gfxObjectData.SetObject("workerSlots", gfxWorkerSlotsArray);

	UpdateAssignmentBubble(gfxObjectData);
}		

simulated function UpdateDataSpecOps()
{
	local GFxObject gfxObjectData, gfxWorkerArray, gfxWorkerSlotData;
	local XComGameStateHistory History;
	local XComGameState_Unit Worker;
	local X2StrategyElementTemplateManager StratMgr;
	local X2SoldierClassTemplate SoldierClassTemplate;
	local XComGameState_StrategyAction UnitAssignedAction;
	local X2DioSpecOpsTemplate SpecOpsTemplate;
	local array<string> AllSpecOpsTitles;
	local int i, workerSlot, numSpecOpsAgents; 

	m_AvailableWorkerSlots = class'DioStrategyAI'.static.GetSpecOpsAgentLimit();
	numSpecOpsAgents = 0;
	History = `XCOMHISTORY;
	StratMgr = `STRAT_TEMPLATE_MGR;
	gfxObjectData = Movie.CreateObject("Object");
	gfxWorkerArray = Movie.CreateArray(true);

	gfxObjectData.SetString("name", Title_SpecOps);
	BubbleColor = class'UIUtilities_Colors'.const.DIO_YELLOW_LIGHT_SPEC_OPS;
	gfxObjectData.SetString("color", BubbleColor);
	gfxObjectData.SetString("icon", class'UIUtilities_Image'.const.CityMapAssignment_SpecOps);
	gfxObjectData.SetBool("bNeedsAttention", class'DioStrategyNotificationsHelper'.static.SpecOpsNeedsAttention());
	  
	workerSlot = 0;
	foreach History.IterateByClassType(class'XComGameState_Unit', Worker)
	{
		UnitAssignedAction = Worker.GetAssignedAction();
		if (UnitAssignedAction.GetMyTemplateName() == 'HQAction_SpecOps')
		{
			SpecOpsTemplate = X2DioSpecOpsTemplate(StratMgr.FindStrategyElementTemplate(UnitAssignedAction.TargetName));
			if (SpecOpsTemplate != none)
			{
				AllSpecOpsTitles.AddItem(SpecOpsTemplate.DisplayName);
			}
			gfxWorkerSlotData = Movie.CreateObject("Object");

			SoldierClassTemplate = Worker.GetSoldierClassTemplate();

			gfxWorkerSlotData.SetString("workerIcon", SoldierClassTemplate.WorkerIconImage);
			gfxWorkerSlotData.SetString("regionColor", BubbleColor);
			gfxWorkerSlotData.SetBool("bHasScars", Worker.Scars.Length > 0);
			gfxWorkerSlotData.SetBool("bHasUpgrades", Worker.ShowPromoteIcon());
			gfxWorkerSlotData.SetString("trainingTime", string(UnitAssignedAction.GetTurnsUntilComplete()));

			gfxWorkerSlotData.SetFloat("unitID", Worker.ObjectID);
			WorkerSlots[workerSlot].WorkerObjectID = Worker.ObjectID;

			WorkerSlots[workerSlot].SetObjectID(Worker.ObjectID, BubbleColor);
			gfxWorkerSlotData.SetBool("isLocked", false);
			
			gfxWorkerArray.SetElementObject(workerSlot, gfxWorkerSlotData);			
			numSpecOpsAgents++;

			// Present meter for first Spec Ops, if any
			if (workerSlot == 0)
			{
				gfxObjectData.SetFloat("meterPips", SpecOpsTemplate.Duration);
				gfxObjectData.SetFloat("meterPipsFilled", SpecOpsTemplate.Duration - UnitAssignedAction.GetTurnsUntilComplete());
			}

			workerSlot++;
		}
	}

	if(numSpecOpsAgents > 0)
	{
		gfxObjectData.SetString("status", class'UIUtilities_Text'.static.StringArrayToCommaSeparatedLine(AllSpecOpsTitles));

		// Re-hide progress meter if more than one spec ops is in progress [12/11/2019 dmcdonough]
		if (numSpecOpsAgents > 1)
		{
			gfxObjectData.SetFloat("meterPips", 0);
			gfxObjectData.SetFloat("meterPipsFilled", 0);
		}
	}
	else
	{
		gfxObjectData.SetString("status", SpecOpsStatus_Inactive);
		gfxObjectData.SetFloat("meterPips", 0);
		gfxObjectData.SetFloat("meterPipsFilled", 0);
	}
	
	for (i = workerSlot; i < WorkerSlots.Length; i++)
	{
		if (i >= m_AvailableWorkerSlots)
		{
			WorkerSlots[i].Hide();
		}
		else
		{
			// fill in any extra empties 
			gfxWorkerSlotData = Movie.CreateObject("Object");

			gfxWorkerSlotData.SetString("name", (i == 1) ? " " : ""); //empty string results in hiding slot
			gfxWorkerSlotData.SetString("workerIcon", (i == 1) ? " " : "");
			gfxWorkerSlotData.SetString("regionColor", BubbleColor);

			gfxWorkerSlotData.SetFloat("unitID", -1);
			WorkerSlots[i].SetObjectID(-1, BubbleColor);
			WorkerSlots[i].Show();
			gfxWorkerSlotData.SetBool("isLocked", false);

			WorkerSlots[i].WorkerObjectID = -1;

			gfxWorkerArray.SetElementObject(i, gfxWorkerSlotData);
		}
	}

	gfxObjectData.SetObject("workerSlots", gfxWorkerArray);

	UpdateAssignmentBubble(gfxObjectData);
}

simulated function UpdateDataResearch()
{
	local GFxObject gfxObjectData, gfxWorkerSlotsArray, gfxWorkerSlotData;
	local XComGameStateHistory History;
	local XComGameState_HeadquartersDio DioHQ;
	local XComGameState_Unit Unit;
	local X2SoldierClassTemplate SoldierClassTemplate;
	local XComGameState_StrategyAction UnitAssignedAction;
	local XComGameState_DioResearch Research;
	local string TitleString;
	local int i, numUnits;

	History = `XCOMHISTORY;
	DioHQ = `DIOHQ;
	m_AvailableWorkerSlots = class'DioStrategyAI'.static.GetResearchAgentLimit();
	TitleString = Title_Assembly;

	// Reset to default info
	gfxObjectData = Movie.CreateObject("Object");
	gfxWorkerSlotsArray = Movie.CreateArray(true);
	
	BubbleColor = class'UIUtilities_Colors'.const.DIO_BLUE_LIGHT_ASSEMBLY;
	gfxObjectData.SetString("color", BubbleColor);
	gfxObjectData.SetString("icon", class'UIUtilities_Image'.const.CityMapAssignment_Assembly);
	gfxObjectData.SetBool("bNeedsAttention", class'DioStrategyNotificationsHelper'.static.AssemblyNeedsAttention());
	gfxObjectData.SetString("status", AssemblyStatus_Inactive);
	gfxObjectData.SetFloat("meterPips", 0);
	gfxObjectData.SetFloat("meterPipsFilled", 0);

	// Present Active Research status, if any
	if (DioHQ.ActiveResearchRef.ObjectID > 0)
	{
		Research = XComGameState_DioResearch(History.GetGameStateForObjectID(DioHQ.ActiveResearchRef.ObjectID));
		gfxObjectData.SetString("status", Research.GetMyTemplate().DisplayName);
		gfxObjectData.SetFloat("meterPips", Research.PointsRequired);
		gfxObjectData.SetFloat("meterPipsFilled", Research.PointsEarned);

		// Append time icon to title
		TitleString @= "(" $ `DIO_UI.static.FormatTimeIcon(Research.GetTurnsRemaining()) $ ")";
		
	}
	gfxObjectData.SetString("name", TitleString);

	numUnits = 0;
	foreach History.IterateByClassType(class'XComGameState_Unit', Unit)
	{
		UnitAssignedAction = Unit.GetAssignedAction();
		if (UnitAssignedAction.GetMyTemplateName() != 'HQAction_Research')
		{
			continue;
		}
		
		SoldierClassTemplate = Unit.GetSoldierClassTemplate();

		gfxWorkerSlotData = Movie.CreateObject("Object");
		gfxWorkerSlotData.SetString("workerIcon", SoldierClassTemplate.WorkerIconImage);
		gfxWorkerSlotData.SetString("factionIcon", SoldierClassTemplate.PosedIconImage);
		gfxWorkerSlotData.SetString("regionColor", "2cb2f0");
		gfxWorkerSlotData.SetBool("bHasScars", Unit.Scars.Length > 0);
		gfxWorkerSlotData.SetBool("bHasUpgrades", Unit.ShowPromoteIcon());
		gfxWorkerSlotData.SetFloat("unitID", Unit.ObjectID);
		
		WorkerSlots[numUnits].WorkerObjectID = Unit.ObjectID;
		WorkerSlots[numUnits].SetObjectID(Unit.ObjectID, BubbleColor);
		WorkerSlots[numUnits].Show();

		gfxWorkerSlotData.SetBool("isLocked", false);
		gfxWorkerSlotsArray.SetElementObject(numUnits, gfxWorkerSlotData);
		numUnits++;
	}

	// Hide excess unit slots
	for (i = numUnits; i < WorkerSlots.Length; i++)
	{
		if (i >= m_AvailableWorkerSlots)
		{
			WorkerSlots[i].Hide();
		}
		else
		{
			// fill in any extra empties 
			gfxWorkerSlotData = Movie.CreateObject("Object");

			gfxWorkerSlotData.SetString("name", (i == 1) ? " " : ""); //empty string results in hiding slot
			gfxWorkerSlotData.SetString("workerIcon", (i == 1) ? " " : "");
			gfxWorkerSlotData.SetString("regionColor", BubbleColor);

			gfxWorkerSlotData.SetFloat("unitID", -1);
			WorkerSlots[i].SetObjectID(-1, BubbleColor);
			WorkerSlots[i].Show();
			gfxWorkerSlotData.SetBool("isLocked", false);

			WorkerSlots[i].WorkerObjectID = -1;

			gfxWorkerSlotsArray.SetElementObject(i, gfxWorkerSlotData);
		}
	}
	gfxObjectData.SetObject("workerSlots", gfxWorkerSlotsArray);

	UpdateAssignmentBubble(gfxObjectData);
}

simulated function UpdateDataTraining()
{
	local GFxObject gfxObjectData, gfxWorkerSlotData, gfxWorkerSlotsArray;
	local XComGameStateHistory History;
	local XComGameState_Unit Unit;
	local X2SoldierClassTemplate SoldierClassTemplate;
	local XComGameState_StrategyAction UnitAssignedAction;
	local array<string> AllTrainingTitles;
	local X2DioTrainingProgramTemplate TrainingProgram;
	local int i, numUnits;
	local bool bHasTrainingAgent;

	History = `XCOMHISTORY;
	m_AvailableWorkerSlots = class'DioStrategyAI'.static.GetTrainingAgentLimit();
	gfxObjectData = Movie.CreateObject("Object");
	gfxWorkerSlotsArray = Movie.CreateArray(true);

	gfxObjectData.SetString("name", Title_Training);
	BubbleColor = class'UIUtilities_Colors'.const.DIO_GREEN_LIGHT_TRAINING;
	gfxObjectData.SetString("color",BubbleColor);
	gfxObjectData.SetString("icon", class'UIUtilities_Image'.const.CityMapAssignment_Training);
	gfxObjectData.SetBool("bNeedsAttention", class'DioStrategyNotificationsHelper'.static.TrainingNeedsAttention());

	numUnits = 0; 
	bHasTrainingAgent = false;

	foreach History.IterateByClassType(class'XComGameState_Unit', Unit)
	{
		UnitAssignedAction = Unit.GetAssignedAction();
		if (UnitAssignedAction.GetMyTemplateName() != 'HQAction_Train')
		{
			continue;
		}

		gfxWorkerSlotData = Movie.CreateObject("Object");

		SoldierClassTemplate = Unit.GetSoldierClassTemplate();

		TrainingProgram = X2DioTrainingProgramTemplate(`STRAT_TEMPLATE_MGR.FindStrategyElementTemplate(UnitAssignedAction.TargetName));
		if (TrainingProgram != none)
		{
			bHasTrainingAgent = true;
			AllTrainingTitles.AddItem(TrainingProgram.GetDisplayNameString());
		}

		gfxWorkerSlotData.SetString("workerIcon", SoldierClassTemplate.WorkerIconImage);
		gfxWorkerSlotData.SetString("factionIcon", SoldierClassTemplate.PosedIconImage);
		gfxWorkerSlotData.SetString("regionColor", BubbleColor);
		gfxWorkerSlotData.SetBool("bHasScars", Unit.Scars.Length > 0);
		gfxWorkerSlotData.SetBool("bHasUpgrades", Unit.ShowPromoteIcon());
		gfxWorkerSlotData.SetFloat("unitID", Unit.ObjectID);
		gfxWorkerSlotData.SetBool("isLocked", false);
		gfxWorkerSlotData.SetString("trainingTime", string(UnitAssignedAction.GetTurnsUntilComplete()));

		WorkerSlots[numUnits].WorkerObjectID = Unit.ObjectID;
		WorkerSlots[numUnits].SetObjectID(Unit.ObjectID, BubbleColor);
		WorkerSlots[numUnits].Show();

		gfxWorkerSlotData.SetBool("isLocked", false);
		gfxWorkerSlotsArray.SetElementObject(numUnits, gfxWorkerSlotData);
		numUnits++;
	}

	for( i = numUnits; i < WorkerSlots.Length; i++ )
	{
		if (i >= m_AvailableWorkerSlots)
		{
			WorkerSlots[i].Hide();
		}
		else
		{
			// fill in any extra empties 
			gfxWorkerSlotData = Movie.CreateObject("Object");

			gfxWorkerSlotData.SetString("name", (i == 1) ? " " : ""); //empty string results in hiding slot
			gfxWorkerSlotData.SetString("workerIcon", (i == 1) ? " " : "");
			gfxWorkerSlotData.SetString("regionColor", BubbleColor);

			gfxWorkerSlotData.SetFloat("unitID", -1);
			WorkerSlots[i].SetObjectID(-1, BubbleColor);
			WorkerSlots[i].Show();
			gfxWorkerSlotData.SetBool("isLocked", false);

			WorkerSlots[i].WorkerObjectID = -1;

			gfxWorkerSlotsArray.SetElementObject(i, gfxWorkerSlotData);
		}		
	}

	/*
	if (!bHasTrainingAgent)
	{
		gfxObjectData.SetString("status", TrainingStatus_Inactive);
		gfxObjectData.SetFloat("meterPips", 0);
	}*/

	if (bHasTrainingAgent)
	{
		gfxObjectData.SetString("status", class'UIUtilities_Text'.static.StringArrayToCommaSeparatedLine(AllTrainingTitles));
	}
	else
	{
		gfxObjectData.SetString("status", SpecOpsStatus_Inactive);
	}
	gfxObjectData.SetFloat("meterPips", 0);

	gfxObjectData.SetObject("workerSlots", gfxWorkerSlotsArray);

	UpdateAssignmentBubble(gfxObjectData);
}

simulated function UpdateDataSimple( string DisplayName, optional string IconPath = "" )
{
	local GFxObject gfxObjectData, gfxWorkerSlotsArray;
	local int i;

	m_AvailableWorkerSlots = 0;
	gfxObjectData = Movie.CreateObject("Object");
	gfxWorkerSlotsArray = Movie.CreateArray(true);

	gfxObjectData.SetString("name", DisplayName);
	BubbleColor = class'UIUtilities_Colors'.const.INTERACTIVE_BLUE_MEDIUM_HTML_COLOR;
	gfxObjectData.SetString("color", BubbleColor);
	gfxObjectData.SetString("icon", IconPath);
	gfxObjectData.SetBool("bNeedsAttention", false);

	for( i = 0; i < WorkerSlots.Length; i++ )
	{
		WorkerSlots[i].Hide();
	}
	gfxObjectData.SetString("status", "");
	gfxObjectData.SetFloat("meterPips", 0);
	gfxObjectData.SetObject("workerSlots", gfxWorkerSlotsArray);

	UpdateAssignmentBubble(gfxObjectData);
}


simulated function OnMouseEvent(int cmd, array<string> args)
{	
	super.OnMouseEvent(cmd, args);

	if (cmd == class'UIUtilities_Input'.const.FXS_L_MOUSE_UP)
	{
		SelectAction(m_AssignmentName);	
	}
}

simulated function bool OnUnrealCommand(int cmd, int arg)
{
	local bool bHandled;

	bHandled = false;
	
	if (!CheckInputIsReleaseOrDirectionRepeat(cmd, arg))
		return bHandled;

	// Route input based on the cmd
	switch (cmd)
	{
		case class'UIUtilities_Input'.const.FXS_BUTTON_A:
		case class'UIUtilities_Input'.const.FXS_KEY_ENTER:
		case class'UIUtilities_Input'.const.FXS_KEY_SPACEBAR:
			Screen.PlayMouseClickSound();

			SelectAction(m_AssignmentName);

			bHandled = true;
		break;

		case class'UIUtilities_Input'.const.FXS_BUTTON_X:
			if (ValidForWorkerAssignment() && m_SelectedWorkerSlot >= 0)
			{
				Screen.PlayMouseClickSound();
				WorkerSlotClicked(m_SelectedWorkerSlot);
			}

			bHandled = true;
			break;

		case class'UIUtilities_Input'.const.FXS_ARROW_RIGHT :
		case class'UIUtilities_Input'.const.FXS_VIRTUAL_LSTICK_RIGHT :
		case class'UIUtilities_Input'.const.FXS_DPAD_RIGHT :
			if (m_AvailableWorkerSlots > 0)
			{
				Screen.PlayMouseOverSound();
				WorkerSlots[m_SelectedWorkerSlot].OnLoseFocus();
				m_SelectedWorkerSlot--;
				if (m_SelectedWorkerSlot< 0)
				{
					m_SelectedWorkerSlot = m_AvailableWorkerSlots - 1;
				}

				WorkerTray.UpdateData(WorkerSlots[m_SelectedWorkerSlot], BubbleColor);

				WorkerSlots[m_SelectedWorkerSlot].OnReceiveFocus();
			}
			bHandled = true;
			break;
		case class'UIUtilities_Input'.const.FXS_ARROW_LEFT :
		case class'UIUtilities_Input'.const.FXS_VIRTUAL_LSTICK_LEFT :
		case class'UIUtilities_Input'.const.FXS_DPAD_LEFT :
			if (m_AvailableWorkerSlots > 0)
			{
				Screen.PlayMouseOverSound();
				WorkerSlots[m_SelectedWorkerSlot].OnLoseFocus();
				m_SelectedWorkerSlot++;
				if (m_SelectedWorkerSlot >= m_AvailableWorkerSlots)
				{
					m_SelectedWorkerSlot = 0;
				}

				WorkerTray.UpdateData(WorkerSlots[m_SelectedWorkerSlot], BubbleColor);

				WorkerSlots[m_SelectedWorkerSlot].OnReceiveFocus();
			}
			bHandled = true;
			break;

	default:
		bHandled = false;
		break;
	}

	return bHandled;
}

simulated function SelectAction(name InAssignmentName)
{
	switch(InAssignmentName)
	{
	case 'APC':
		OnClickMapScreen();
		break;
	case 'SpecOps':
		OnClickSpecOps();
		break;
	case 'Research':
		OnClickResearchScreen();
		break;
	case 'Train':
		OnClickTrainingScreen();
		break;
	case 'Armory':
		OnClickArmoryScreen();
		break;
	case 'Supply':
		OnClickSupplyScreen();
		break;
	case 'Investigation':
		OnClickInvestigationScreen();
		break;
	case 'ScavengerMarket':
		OnClickScavengerMarketScreen();
		break;
	case 'Test':
		OnTest();
		break;
	}
}

function OnClickResearchScreen()
{
	local XComStrategyPresentationLayer Pres;

	Pres = `STRATPRES;
	Pres.UIClearToStrategyHUD();
	Pres.UIHQResearchScreen();
}

function OnClickMapScreen()
{
	local XComStrategyPresentationLayer Pres;

	if (`SCREENSTACK.IsNotInStack(class'UIDIOStrategyMapFlash', false))
	{
		Pres = `STRATPRES;
		Pres.UIClearToStrategyHUD();
		Pres.UIHQCityMapScreen();
	}
}

function OnClickSpecOps()
{
	local XComStrategyPresentationLayer Pres;
	local StateObjectReference NoneRef; 

	if (`SCREENSTACK.IsNotInStack(class'UISpecOpsScreen', false))
	{
		Pres = `STRATPRES;
		Pres.UIClearToStrategyHUD();
		Pres.UISpecOpsActionPicker(NoneRef);
	}
}

function OnClickTrainingScreen()
{
	local XComStrategyPresentationLayer Pres;
	local StateObjectReference UnitRef;


	if (`SCREENSTACK.IsNotInStack(class'UIDIOTrainingScreen', false))
	{
		Pres = `STRATPRES;
		UnitRef.ObjectID = WorkerSlots[0].WorkerObjectID;
		Pres.UITrainingActionPicker(UnitRef);
	}
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
	Pres.UIHQArmoryScreen();
	// HELIOS END
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
		`STRATPRES.DIOHUD.m_ScreensNav.ShowUrgentStatusPopup();
	}
	else
	{
		Pres.UIClearToStrategyHUD();
		Pres.UIDebriefScreen();
	}
}

function OnTest()
{
	`STRATEGYRULES.UIDIOStrategyTestButton();
}


//---------------------------------------------------------------------------------------
function EventListenerReturn OnTurnOrRoundChanged(Object EventData, Object EventSource, XComGameState GameState, Name Event, Object CallbackData)
{
	UpdateData();
	return ELR_NoInterrupt;
}

simulated event Removed()
{
	UnRegisterForEvents();
	super.Removed();
}

function UpdateAssignmentBubble(GFxObject RegionData)
{
	RootMC.ActionScriptVoid("updateAssignmentData");
}

function HighlightForTutorial(bool bShouldShowHighlight)
{
	if( TutorialHighlight != none )
	{
		TutorialHighlight.SetVisible(bShouldShowHighlight);
	}
	else
	{
		if( bShouldShowHighlight )
		{
			//Spawn to the owning Screen, so that it can place itself relative to global (0,0). 
			TutorialHighlight = UITutorialHighlight(Spawn(class'UITutorialHighlight', Screen).InitPanel());
			//TutorialHighlight.AttachTo(self);
			TutorialHighlight.AttachWithDetails(self, 0, 0, -20, -10);
		}
	}
}

function AS_SetGlow(bool bShouldGlow)
{
	MC.FunctionBool("SetGlow", bShouldGlow);
}

function Activate()
{
	SelectAction(m_AssignmentName);
}

simulated function OnLoseFocus()
{
	super.OnLoseFocus();

	AS_SetGlow(false);

	WorkerSlots[m_SelectedWorkerSlot].OnLoseFocus();
}

simulated function OnReceiveFocus()
{
	super.OnReceiveFocus();

	AS_SetGlow(true);

	WorkerSlots[m_SelectedWorkerSlot].OnReceiveFocus();

	`STRATPRES.DIOStrategy.UpdateNavHelp();
}

simulated function Show()
{
	super.Show();
	//Height = default.Height; 
	if(OwningList != none) OwningList.RealizeItems();
}

simulated function Hide()
{
	super.Hide();
	//Height = 0; //Not calling over to flash, rather, we're spoofing the height when the UIList layout code on realizing item locations. 
	if(OwningList != none ) OwningList.RealizeItems();
}

/*
simulated function OnCommand(string cmd, string arg)
{
	local array<string> sizeData;
	local float cachedHeight; 

	cachedHeight = Height; 

	if( cmd == "RealizeHeight" )
	{
		Height = float(arg);
	}
	else if( cmd == "RealizeSize" )
	{
		sizeData = SplitString(arg, ",");
		Width = float(sizeData[0]);
		Height = float(sizeData[1]);
	}
	
	// Notify change if relevant 
	if( Height != cachedHeight )
	{
		if( OwningList != none )
			OwningList.RealizeItems();
	}
}*/

simulated function RealizeLocation()
{
	super.RealizeLocation();
}

simulated function RealizeDefaultX()
{
	if( bIsPeekaboo )
	{
		MC.FunctionVoid("RealizeDefaultLayout");
		bIsPeekaboo = false;
	}
}

simulated function Peekaboo(optional name PeekabooAssignment = 'NOT_SET')
{
	if( !bIsPeekaboo && m_AssignmentName == PeekabooAssignment )
	{
		MC.FunctionVoid("RealizePeekabooLayout");
		bIsPeekaboo = true;
	}
}


defaultproperties
{
	m_SelectedWorkerSlot = 0;
	m_AvailableWorkerSlots = 0;
	LibID = "DIOCityMap_AssignmentBubble";
	Height = 66; //TODO: be dynamic based on callback from flash 
	Width = 490;
	bAnimateOnInit = false; 
	bIsPeekaboo = false; 
	bCascadeFocus = false;
}