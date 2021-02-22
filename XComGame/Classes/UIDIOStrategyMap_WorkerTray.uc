class UIDIOStrategyMap_WorkerTray extends UIPanel;

var GFxObject RootMC;
var int m_SelectedIndex;
var int m_PreviousSelectedIndex;
var int m_NumWorkers;
var string MainBubbleColor;
var UIDIOStrategyMap_WorkerSlot TargetWorkerSlot;
var UIDIOStrategyMap_AssignmentBubble m_AttachedPanel;
var int m_SelectedSlot;
var array<StateObjectReference> SortedUnits;
var bool bShowHeader; 
var UIDIOHUD m_HUD;

var localized string m_strRemoveLabel;
var localized string m_strChooseUnit;

delegate OnWorkerClickedDelegate(UIDIOStrategyMap_WorkerSlot SlotID, int WorkerID);
delegate bool CanWorkerBeAssignedDelegate(XComGameState_Unit Worker);

simulated function UIDIOStrategyMap_WorkerTray InitWorkerTray(name InitName)
{
	InitPanel(InitName);

	SetPosition(10, 400);

	return self;
}

simulated function OnInit()
{
	super.OnInit();

	RootMC = Movie.GetVariableObject(MCPath $ "");
	// HELIOS BEGIN
	// Replace the hard reference with a reference to the main HUD	
	m_HUD = UIDIOHUD(`SCREENSTACK.GetScreen(`PRESBASE.UIHUD_Strategy));
	// HELIOS END	
	UpdateData();

	//Initial hide, as interactions will specifically show/hide this panel.
	Hide();
}

// MUST ATTACH BEFORE DATA IS SET for header to update properly. 
function AttachToPanel(UIPanel targetPanel, int targetSlot)
{
	local int newX;

	bShowHeader = true; 
	AnchorTopRight();

	m_SelectedSlot = targetSlot;
	m_AttachedPanel = UIDIOStrategyMap_AssignmentBubble(targetPanel);

	//newX = targetPanel.X + 215 + ((4 - targetSlot) * 55);

	//Cap so we don't go off screen right 
	//if( newX > 1500 ) newX = 1500;
	if (UIDIOStrategyMap_AssignmentBubble(targetPanel).bIsPeekaboo)
	{
		newX = -(450 + (UIDIOStrategyMap_AssignmentBubble(targetPanel).m_AvailableWorkerSlots * 50));
	}
	else
	{
		newX = -(400 + `STRATPRES.DIOHUD.m_ScreensNav.GetWidth());
	}

	SetPosition(newX, targetPanel.Y + 105);
	UpdateNavHelp();
}

// MUST ATTACH BEFORE DATA IS SET for header to update properly. 
function AttachToSquadSelectPanel(UIPanel targetPanel, int targetSlot )
{
	local int newX, yOffset; 

	bShowHeader = false; 
	m_SelectedSlot = targetSlot;
	m_AttachedPanel = none; 

	AnchorBottomLeft(); 
	newX = targetPanel.X + (targetPanel.Width * 0.5f) + 30;
	yOffset = -520;
	 
	SetPosition(newX, yOffset - (m_NumWorkers * 75));
}

simulated function UpdateData(UIDIOStrategyMap_WorkerSlot NewTargetWorkerSlot = none, string BubbleColor = "")
{
	local GFxObject gfxWorkerSlot, gfxObjectData, gfxWorkerArray, gfxWorkerSlotSlotsArray, gfxWorkerSlotData;
	local XComGameStateHistory History;
	local XComGameState_Unit Unit;
//	local XComGameState_DioWorker Worker;
//	local XComGameState_DioWorkerCollection WorkerCollection;
	local int i;// , j, Cost;
	local X2SoldierClassTemplate SoldierClassTemplate;
	local EUIState UIState;
//	local bool bCanAfford; 

	AS_ClearWorkerList();

	History = `XCOMHISTORY;
	gfxObjectData = Movie.CreateObject("Object");
	gfxWorkerArray = Movie.CreateArray(true);

	gfxObjectData.SetString("title", (bShowHeader ? m_strChooseUnit : "") );

	if (NewTargetWorkerSlot != none)
	{
		TargetWorkerSlot = NewTargetWorkerSlot;
		MainBubbleColor = BubbleColor;
	}
	
	gfxObjectData.SetString("BubbleColor", MainBubbleColor);

	m_NumWorkers = 0;
	SortedUnits.length = 0; 

	SortedUnits = `DIOHQ.Squad; 

	SortedUnits.Sort(SortByAssignment);

	// Squad Agents
	for (i = 0; i < SortedUnits.Length; i++)
	{
		Unit = XComGameState_Unit(History.GetGameStateForObjectID(SortedUnits[i].ObjectID));
		if (CanWorkerBeAssignedDelegate != none && !CanWorkerBeAssignedDelegate(Unit))
		{
			SortedUnits.Remove(i--, 1);
			continue;
		}
		if (Unit != none)
		{
			SoldierClassTemplate = Unit.GetSoldierClassTemplate();
			
			gfxWorkerSlot = Movie.CreateObject("Object");

			if (`ISCONTROLLERACTIVE && m_SelectedIndex == m_NumWorkers)
			{
				gfxWorkerSlot.SetString("name", class'UIUtilities_Text'.static.InjectImage(class'UIUtilities_Input'.static.GetGamepadIconPrefix() $ class'UIUtilities_Input'.const.ICON_A_X, 20, 20, 0) @ `MAKECAPS(Unit.GetName(eNameType_Full)));
			}
			else
			{
				gfxWorkerSlot.SetString("name", `MAKECAPS(Unit.GetName(eNameType_Full)));
			}
			
			UIState = eUIState_Normal;
			if( TargetWorkerSlot != none && TargetWorkerSlot.WorkerObjectID == Unit.ObjectID )
			{
				gfxWorkerSlot.SetString("status", m_strRemoveLabel);
			}
			else
			{
				gfxWorkerSlot.SetString("status", `DIO_UI.static.GetAbridgedUnitStatusString(Unit, UIState));
			}

			gfxWorkerSlot.SetString("icon", `DIO_UI.static.GetUnitDutyIconString(Unit));
			gfxWorkerSlot.SetString("color", class'UIUtilities_DioStrategy'.static.GetUnitDutyIconColor(Unit));
			gfxWorkerSlot.SetBool("bHasScars", Unit.Scars.Length > 0);
			gfxWorkerSlot.SetBool("bHasUpgrades", Unit.ShowPromoteIcon());

			gfxWorkerSlotSlotsArray = Movie.CreateArray(true);
			gfxWorkerSlotData = Movie.CreateObject("Object");

			gfxWorkerSlot.SetString("workerIcon", SoldierClassTemplate.WorkerIconImage);

			gfxWorkerSlotData.SetString("workerIcon", SoldierClassTemplate.WorkerIconImage);
			//gfxWorkerSlotData.SetString("factionIcon", SoldierClassTemplate.PosedIconImage);
			gfxWorkerSlotData.SetString("regionColor", class'UIUtilities_Colors'.static.GetHexColorFromState(UIState));

			gfxWorkerSlotData.SetFloat("unitID", Unit.ObjectID);
			gfxWorkerSlotData.SetBool("isLocked", false);

			gfxWorkerSlotSlotsArray.SetElementObject(0, gfxWorkerSlotData);

			gfxWorkerSlot.SetObject("slots", gfxWorkerSlotSlotsArray);

			gfxWorkerArray.SetElementObject(m_NumWorkers, gfxWorkerSlot);
			m_NumWorkers++;
		}
	}

	gfxObjectData.SetObject("workerSlots", gfxWorkerArray);

	UpdateWorkers(gfxObjectData);
}

simulated function int SortByAssignment(StateObjectReference A, StateObjectReference B)
{
	local XComGameStateHistory History;
	local XComGameState_Unit UnitA, UnitB;
	local bool bUnitBusy_A, bUnitBusy_B;
	local int priA, priB, targetSlotPri; 

	History = `XCOMHISTORY; 
	UnitA = XComGameState_Unit(History.GetGameStateForObjectID(A.ObjectID));
	UnitB = XComGameState_Unit(History.GetGameStateForObjectID(B.ObjectID));

	targetSlotPri = 100; // way low on the list unless set. 

	//Push the currently assigned unit up to the top 
	if( TargetWorkerSlot != none )
	{
			if( TargetWorkerSlot.WorkerObjectID == UnitB.ObjectID )
			{
				return -1;
			}
			else if( TargetWorkerSlot.WorkerObjectID == UnitA.ObjectID )
			{
				return 1;
			}
			targetSlotPri = class'UIUtilities_DioStrategy'.static.GetUnitDutyPriority(UnitA); 
	}

	//push unassigned units above assigned units 
	bUnitBusy_B = class'UIUtilities_DioStrategy'.static.IsUnitAssignedAnyDuty(UnitB);
	bUnitBusy_A = class'UIUtilities_DioStrategy'.static.IsUnitAssignedAnyDuty(UnitA);
	if( bUnitBusy_A && !bUnitBusy_B ) 
	{
		return -1;
	}
	else if( !bUnitBusy_A && bUnitBusy_B )
	{
		return 1;
	}

	// Use priority to group same assignment units together 
	priA = class'UIUtilities_DioStrategy'.static.GetUnitDutyPriority(UnitA);
	priB = class'UIUtilities_DioStrategy'.static.GetUnitDutyPriority(UnitB);

	if( targetSlotPri == priB ||  priA < priB )
	{
		return 1;
	}
	else if( targetSlotPri == priA || priB < priA )
	{
		return -1;
	}

	return 0; 
}

simulated function SelectFirstWorker()
{
	m_SelectedIndex = 0;
	MC.FunctionVoid("DeselectAllWorkers");
	MC.FunctionNum("SelectWorker", m_SelectedIndex);
}

simulated function SelectNextWorker()
{
	m_SelectedIndex++;
	if (m_SelectedIndex >= m_NumWorkers)
		m_SelectedIndex = 0;

	UpdateData();
}

simulated function SelectPreviousWorker()
{
	m_SelectedIndex--;
	if (m_SelectedIndex < 0)
		m_SelectedIndex = m_NumWorkers - 1;

	UpdateData();
}

simulated function SelectNextSlot()
{
	m_SelectedSlot++;
	if (m_SelectedSlot >= m_AttachedPanel.m_AvailableWorkerSlots)
		m_SelectedSlot = 0;

	AttachToPanel(m_AttachedPanel, m_SelectedSlot);
	TargetWorkerSlot = m_AttachedPanel.WorkerSlots[m_SelectedSlot];
	UpdateData();
}

simulated function SelectPreviousSlot()
{
	m_SelectedSlot--;
	if (m_SelectedSlot < 0)
		m_SelectedSlot = m_AttachedPanel.m_AvailableWorkerSlots - 1;

	AttachToPanel(m_AttachedPanel, m_SelectedSlot);
	TargetWorkerSlot = m_AttachedPanel.WorkerSlots[m_SelectedSlot];
	UpdateData();
}

// mmg_john.hawley (12/9/19) - Creating unique NavHelp for workertray panel
function UpdateNavHelp()
{
	local bool bIsTactical;

	//bIsTactical = (XComGameStateContext_TacticalGameRule(History.GetGameStateFromHistory(History.FindStartStateIndex()).GetContext()) != None);
	bIsTactical = `TACTICALGRI != none;

	m_HUD.NavHelp.ClearButtonHelp();
	m_HUD.NavHelp.bIsVerticalHelp = bIsTactical ? false : true;
	
	if (`ISCONTROLLERACTIVE)
	{
		m_HUD.NavHelp.AddBackButton();
		m_HUD.NavHelp.AddSelectNavHelp();
		m_HUD.NavHelp.AddLeftHelp(Caps(`DIO_UI.default.strStatus_NeedToSelectUnit), class'UIUtilities_Input'.static.GetGamepadIconPrefix() $ class'UIUtilities_Input'.const.ICON_DPAD_VERTICAL);
		if (bIsTactical)
		{
			m_HUD.NavHelp.AddLeftHelp(Caps(class'XLocalizedData'.default.BreachChoosePosition), class'UIUtilities_Input'.static.GetGamepadIconPrefix() $ class'UIUtilities_Input'.const.ICON_LTRT_L2R2);
		}
	}
}

//---------------------------------------------------------------------------------------
//				INPUT HANDLER
//---------------------------------------------------------------------------------------
simulated function bool OnUnrealCommand(int cmd, int arg)
{
	local int workerID;

	if (!CheckInputIsReleaseOrDirectionRepeat(cmd, arg))
		return false;

	switch (cmd)
	{
	case class'UIUtilities_Input'.const.FXS_BUTTON_A :
	case class'UIUtilities_Input'.const.FXS_KEY_ENTER :
	case class'UIUtilities_Input'.const.FXS_KEY_SPACEBAR :
		if(`ISCONTROLLERACTIVE)
		{
			Screen.PlayMouseClickSound();
			workerID = SortedUnits[m_SelectedIndex].ObjectID;
			OnWorkerClickedDelegate(TargetWorkerSlot, workerID);
		}
		return true;

	case class'UIUtilities_Input'.const.FXS_ARROW_UP :
	case class'UIUtilities_Input'.const.FXS_DPAD_UP :
	case class'UIUtilities_Input'.const.FXS_VIRTUAL_LSTICK_UP :
		Screen.PlayMouseOverSound();
		SelectPreviousWorker();
		return true;
	case class'UIUtilities_Input'.const.FXS_ARROW_DOWN :
	case class'UIUtilities_Input'.const.FXS_DPAD_DOWN :
	case class'UIUtilities_Input'.const.FXS_VIRTUAL_LSTICK_DOWN :
		Screen.PlayMouseOverSound();
		SelectNextWorker();
		return true;
	case class'UIUtilities_Input'.const.FXS_KEY_Q :
	case class'UIUtilities_Input'.const.FXS_BUTTON_LTRIGGER :
	//case class'UIUtilities_Input'.const.FXS_BUTTON_RBUMPER :
		Screen.PlayMouseClickSound();
		SelectNextSlot();
		return true;

	case class'UIUtilities_Input'.const.FXS_KEY_E :
	case class'UIUtilities_Input'.const.FXS_BUTTON_RTRIGGER :
	//case class'UIUtilities_Input'.const.FXS_BUTTON_LBUMPER :
		Screen.PlayMouseClickSound();
		SelectPreviousSlot();
		return true;
	}

	return Super.OnUnrealCommand(cmd, arg);
}

function UpdateWorkers(GFxObject RegionData)
{
	RootMC.ActionScriptVoid("updateData");
}

function AS_ClearWorkerList()
{
	RootMC.ActionScriptVoid("clearWorkers");
}

simulated function OnReceiveFocus()
{
	super.OnReceiveFocus();

	m_SelectedIndex = m_PreviousSelectedIndex;
	UpdateData();
}

simulated function OnLoseFocus()
{
	super.OnLoseFocus();

	m_PreviousSelectedIndex = m_SelectedIndex;
	m_SelectedIndex = -1;
	UpdateData();
}

simulated function OnMouseEvent(int cmd, array<string> args)
{
	local int workerNum, workerID; 

	super.OnMouseEvent(cmd, args);


	switch( cmd )
	{
	case class'UIUtilities_Input'.const.FXS_L_MOUSE_UP:

		workerNum = int(GetRightMost(args[5]));
		workerID = SortedUnits[workerNum].ObjectID;
		
		if( OnWorkerClickedDelegate != none )
		{
			OnWorkerClickedDelegate(TargetWorkerSlot, workerID);
		}
		break;
	
	}
}

// mmg_john.hawley (12/9/19) - Since this is not a screen, requires special case to update NavHelp appropriately when we close it
simulated function Hide()
{
	if (bIsVisible)
	{
		Screen.PlayMouseClickSound();
		`SCREENSTACK.RefreshFocus();
	}
	super.Hide();
}

defaultproperties
{
	LibID = "DIOCityMap_WorkerTray";

	m_SelectedIndex = 0;
	m_NumWorkers = 0;
	bShowHeader = true; 
}