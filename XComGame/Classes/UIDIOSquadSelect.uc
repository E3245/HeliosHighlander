//---------------------------------------------------------------------------------------
//  *********   FIRAXIS SOURCE CODE   ******************
//  FILE:    UISquadSelect
//  AUTHOR:  Sam Batista -- 5/1/14
//  PURPOSE: This file controls the squad select screen. 
//---------------------------------------------------------------------------------------
//  Copyright (c) 2016 Firaxis Games, Inc. All rights reserved.
//--------------------------------------------------------------------------------------- 

class UIDIOSquadSelect extends UIScreen implements(UIDioAutotestInterface, UIDIOIconSwap)
	config(UI);

const LIST_ITEM_PADDING = 6;

var UIDIOHUD					m_HUD;
var UIPawnMgr					m_kPawnMgr;
var array<XComUnitPawn>			UnitPawns;
var SkeletalMeshActor			Cinedummy;
var UISquadSelectMissionInfo	m_kMissionInfo;
var UIList						m_kSlotList; 
var UINavigationHelp			NavHelp; 

var XComGameState_StrategyAction_Mission MissionAction;
var int SoldierSlotCount;
var int SquadCount;
var string m_strPawnLocationIdentifier;

var privatewrite int PendingSwapUnitID;
// HELIOS BEGIN
// Change to protected write for subclasses to override
var protectedwrite bool bLaunchEventPending;
// HELIOS END

var int CurrentAgentIndex;
var bool bSelectingLaunch; 

// Because game state changes happen when we call UpdateData, 
// we need to wait until the new XComHQ is created before adding Soldiers to the squad.
var StateObjectReference PendingSoldier;

var localized string SelectUnitLabel;
var localized string LaunchMissionLabel;

// Constructor
simulated function InitScreen(XComPlayerController InitController, UIMovie InitMovie, optional name InitName)
{
	local int listX, listWidth, listYOffsetReinforcements;
	
	super.InitScreen(InitController, InitMovie, InitName);

	CurrentAgentIndex = -1;

	// HELIOS BEGIN
	// Replace the hard reference with a reference to the main HUD
	m_HUD = UIDIOHUD(`SCREENSTACK.GetScreen(`PRESBASE.UIHUD_Strategy));
	// HELIOS END
	m_HUD.UpdateResources(self);
	m_HUD.NavHelp.ClearButtonHelp();
	NavHelp = m_HUD.NavHelp; 

	Navigator.HorizontalNavigation = true;

	m_kMissionInfo = Spawn(class'UISquadSelectMissionInfo', self).InitMissionInfo();
	m_kPawnMgr = Spawn(class'UIPawnMgr', Owner);

	// mmg_aaron.lee (10/29/19) BEGIN - allow to edit through global.uci
	m_kMissionInfo.SetX(`SAFEZONEHORIZONTAL);
	// mmg_aaron.lee (10/29/19) END

	SoldierSlotCount = 4 + (`DIOHQ.Androids.Length >= 2 ? 2 : `DIOHQ.Androids.Length);
	SquadCount = 1;
	if( SoldierSlotCount > 5 )
	{
		listYOffsetReinforcements = 100;
	}
	else
	{
		listYOffsetReinforcements = 50;
	}

	listWidth = SoldierSlotCount * (class'UIDIOSquadSelect_ListItem'.default.width + LIST_ITEM_PADDING);
	listX = Clamp((Movie.UI_RES_X / 2) - (listWidth / 2), 10, Movie.UI_RES_X / 2);

	//m_kSlotList = Spawn(class'UIList', self);
	m_kSlotList = Spawn(class'UIList', self);
	m_kSlotList.bIsHorizontal = true;
	m_kSlotList.bCascadeFocus = false;

	// mmg_aaron.lee (10/29/19) BEGIN - allow to edit through global.uci
	m_kSlotList.InitList('', listX, -350 - listYOffsetReinforcements - `SAFEZONEVERTICAL, Movie.UI_RES_X - 20, 310, true).AnchorBottomLeft();
	// mmg_aaron.lee (10/29/19) END

	m_kSlotList.itemPadding = LIST_ITEM_PADDING;

	UpdateData(true);
	UpdateNavHelp();
	RegisterForEvents();
}

//---------------------------------------------------------------------------------------
simulated function OnInit()
{
	super.OnInit();

	OnReceiveFocus();
}

// mmg_john.hawley (12/7/19) BEGIN - Creating our own functionality for handling input on this screen.
function SelectNextAgent()
{
	Navigator.Next();
}

function SelectPrevAgent()
{
	Navigator.Prev();
}

function ClearSquadSelectUI()
{
	local int i;

	for (i = 0; i < SoldierSlotCount - 1; i++)
	{
		GetAgentSquadSelectUI(i).OnLoseFocus();
	}
}

function UIDioSquadSelect_ListItem GetAgentSquadSelectUI(int Index)
{
	return UIDioSquadSelect_ListItem(m_kSlotList.GetItem(Index));
}
// mmg_john.hawley (12/7/19) END

//---------------------------------------------------------------------------------------
function RegisterForEvents()
{
	local X2EventManager EventManager;
	local Object SelfObject;

	EventManager = `XEVENTMGR;
	SelfObject = self;

	EventManager.RegisterForEvent(SelfObject, 'STRATEGY_UnitLoadoutChange_Submitted', OnLoadoutChanged, ELD_OnStateSubmitted);
	EventManager.RegisterForEvent(SelfObject, 'STRATEGY_ExecuteStrategyAction_Submitted', OnActionSubmitted, ELD_OnStateSubmitted);
}

//---------------------------------------------------------------------------------------
function UnRegisterForEvents()
{
	local X2EventManager EventManager;
	local Object SelfObject;

	EventManager = `XEVENTMGR;
	SelfObject = self;

	EventManager.UnRegisterFromEvent(SelfObject, 'STRATEGY_UnitLoadoutChange_Submitted');
	EventManager.UnRegisterFromEvent(SelfObject, 'STRATEGY_ExecuteStrategyAction_Submitted');
}

simulated function UpdateData(optional bool bFillSquad)
{
	local UIDioSquadSelect_ListItem ListItem;
	local XComGameState_HeadquartersDio DioHQ;
	local int SlotIndex;	//Index into the list of places where a soldier can stand in the after action scene, from left to right

	if (MissionAction == none)
	{
		return;
	}

	DioHQ = `DIOHQ;

	// Fill mission data
	m_kMissionInfo.UpdateMissionActionData(MissionAction);

	// Add slots in the list if necessary.
	m_kSlotList.ClearItems();
	while( m_kSlotList.itemCount < SoldierSlotCount)
	{
		UIDioSquadSelect_ListItem(m_kSlotList.CreateItem(class'UIDioSquadSelect_ListItem').InitPanel());
	}

	ClearPawns();

	UnitPawns.Length = SoldierSlotCount;
	// Fill slots up to squad count
	for (SlotIndex = 0; SlotIndex < SoldierSlotCount; ++SlotIndex)
	{
		// We want the slots to match the visual order of the pawns in the slot list.
		ListItem = UIDioSquadSelect_ListItem(m_kSlotList.GetItem(SlotIndex));

		if (SoldierSlotCount == 6)
		{
			if (SlotIndex == 0)
			{
				ListItem.UpdateData(5, true, true);
			}
			else
			{
				ListItem.UpdateData(SlotIndex - 1, true, true);
			}
		}
		else
		{
			ListItem.UpdateData(SlotIndex, true, true);
		}

		if (SlotIndex >= DioHQ.APCRoster.Length)
		{
			if (UnitPawns[SlotIndex] != none)
			{
				m_kPawnMgr.ReleaseCinematicPawn(self, `DIOHQ.Androids[SlotIndex - DioHQ.APCRoster.Length].ObjectID);
			}

			UnitPawns[SlotIndex] = CreatePawn(`DIOHQ.Androids[SlotIndex - DioHQ.APCRoster.Length], SlotIndex);
		}
		else
		{
			if (DioHQ.APCRoster[SlotIndex].ObjectID > 0)
			{
				if (UnitPawns[SlotIndex] != none)
				{
					m_kPawnMgr.ReleaseCinematicPawn(self, DioHQ.APCRoster[SlotIndex].ObjectID);
				}

				UnitPawns[SlotIndex] = CreatePawn(	DioHQ.APCRoster[SlotIndex], SlotIndex);
			}
		}
	}
}

function GoToSupplyScreen()
{
	local XComStrategyPresentationLayer Pres;

	// Early out: blocked by tutorial
	if (class'DioStrategyTutorialHelper'.static.IsSupplyTutorialLocked())
	{
		return;
	}

	ClearPawns();

	Pres = `STRATPRES;
	Pres.UIHQXCOMStoreScreen();
}

function UpdateNavHelp()
{
	local UIDioSquadSelect_ListItem CurrentSelectedAgentUI;

	NavHelp.ClearButtonHelp();
	NavHelp.bIsVerticalHelp = `ISCONTROLLERACTIVE;
	NavHelp.AddBackButton(OnCancel);
	NavHelp.AddContinueButton(StartMissionAction,,LaunchMissionLabel);
	
	if( bSelectingLaunch )
	{
		//Highlight [LAUNCH]
		NavHelp.ContinueButton.OnReceiveFocus();
		//NavHelp.ContinueButton.SetGood(true);  //green
		NavHelp.ContinueButton.SetSelected(true);
	}
	else
	{
		NavHelp.ContinueButton.OnLoseFocus();
		//NavHelp.ContinueButton.SetGood(false); //Blue
		NavHelp.ContinueButton.SetSelected(false);
		GetAgentSquadSelectUI(CurrentAgentIndex).OnReceiveFocus();
	}
	if (`ISCONTROLLERACTIVE)
	{
		// Early out: blocked by tutorial
		if (!class'DioStrategyTutorialHelper'.static.IsSupplyTutorialLocked())
		{
			NavHelp.AddLeftHelp(class'UIDIOStrategyScreenNavigation'.default.SupplyScreenLabel, class'UIUtilities_Input'.static.GetGamepadIconPrefix() $ class'UIUtilities_Input'.const.ICON_RT_R2);
		}
		NavHelp.AddLeftHelp(Caps(SelectUnitLabel), class'UIUtilities_Input'.static.GetGamepadIconPrefix() $ class'UIUtilities_Input'.const.ICON_DPAD_HORIZONTAL);
		
		CurrentSelectedAgentUI = GetAgentSquadSelectUI(CurrentAgentIndex);
		if (CurrentSelectedAgentUI != none)
		{
			CurrentSelectedAgentUI.UpdateNavHelp();
		}
		else
		{
			ClearSquadSelectUI();
		}
	}
	else
	{
		// Early out: blocked by tutorial
		if (!class'DioStrategyTutorialHelper'.static.IsSupplyTutorialLocked())
		{
			NavHelp.AddLeftHelp(class'UIDIOStrategyScreenNavigation'.default.SupplyScreenLabel, , GoToSupplyScreen);
		}
		ClearSquadSelectUI();
		CurrentAgentIndex = -1;
	}
}

simulated function SwapAssignedUnits(StateObjectReference OldUnitRef, StateObjectReference NewUnitRef)
{
	local X2StrategyGameRuleset StratRules;
	local XComGameState_Unit Unit;
	local int SlotIndex;

	if (class'DioStrategyAI'.static.IsAgentAssignmentChangeDestructive(NewUnitRef, 'APC'))
	{
		PendingSwapUnitID = OldUnitRef.ObjectID;
		Unit = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(NewUnitRef.ObjectID));
		`STRATPRES.UIConfirmSwitchDutyAssignment(Unit, 'APC', ConfirmSwapUnit);
	}
	else
	{
		SlotIndex = `DIOHQ.APCRoster.Find('ObjectID', OldUnitRef.ObjectID);

		StratRules = `STRATEGYRULES;
		StratRules.SubmitAssignAgentDuty(OldUnitRef, 'Unassign');
		StratRules.SubmitAssignAgentDuty(NewUnitRef, 'APC', SlotIndex);

		PendingSwapUnitID = -1;
		UpdateData();
	}
}

function ConfirmSwapUnit(name eAction, UICallbackData xUserData)
{
	local UICallbackData_StateObjectReference CallbackData;
	local StateObjectReference OldUnitRef;
	local X2StrategyGameRuleset StratRules;

	if (eAction == 'eUIAction_Accept')
	{
		StratRules = `STRATEGYRULES;

		OldUnitRef.ObjectID = PendingSwapUnitID;
		if (PendingSwapUnitID > 0)
		{
			StratRules.SubmitAssignAgentDuty(OldUnitRef, 'Unassign');
		}

		CallbackData = UICallbackData_StateObjectReference(xUserData);
		StratRules.SubmitAssignAgentDuty(CallbackData.ObjectRef, 'APC');

		PendingSwapUnitID = -1;
		UpdateData();
	}
}

simulated function StartMissionAction()
{
	`STRATEGYRULES.ExecuteSingleStrategyAction(MissionAction.GetReference());
}

simulated function LaunchMission()
{
	local XComStrategySoundManager SoundMgr;

	SoundMgr = `XSTRATEGYSOUNDMGR;
	if (SoundMgr != none)
	{
		SoundMgr.HandleLaunchMission();
	}
	TriggerMissionLaunchEvent();
}

// HELIOS BEGIN
// Change to protected for subclasses to override (while maintaining the private functionality)
protected simulated function TriggerMissionLaunchEvent()
{
	local XComGameState_MissionSite Mission;

	bLaunchEventPending = false;
	Mission = XComGameState_MissionSite(`XCOMHISTORY.GetGameStateForObjectID(MissionAction.MissionRef.ObjectID));
	`assert(Mission != none);
	`STRATEGYRULES.LaunchMission(Mission);
}
// HELIOS END

function EventListenerReturn OnLoadoutChanged(Object EventData, Object EventSource, XComGameState GameState, Name Event, Object CallbackData)
{
	UpdateData();
	return ELR_NoInterrupt;
}

function EventListenerReturn OnActionSubmitted(Object EventData, Object EventSource, XComGameState GameState, Name Event, Object CallbackData)
{
	local XComGameState_StrategyAction_Mission EventMissionAction;

	EventMissionAction = XComGameState_StrategyAction_Mission(EventData);
	if (EventMissionAction.ObjectID == MissionAction.ObjectID)
	{
		// Auto-resolve?
		if (`STRATEGYRULES.IsAutoResolveOn())
		{
			`STRATPRES.UIHQCityMapScreen();
			class'DioStrategySimCombat'.static.AutoResolveMissionAction(EventMissionAction);
		}
		else
		{
			LaunchMission();
		}
	}

	return ELR_NoInterrupt;
}

// override in child classes to provide custom behavior
simulated function OnCancel()
{
	CloseScreen();
}

simulated function CloseScreen()
{
	UnRegisterForEvents();
	ClearPawns();
	super.CloseScreen();	

	// HELIOS BEGIN
	// Make the screen point to the assigned variable here
	m_HUD.m_WorkerTray.CanWorkerBeAssignedDelegate = none;
	
	//Camera refactoring
	`PRESBASE.RefreshCamera('StrategyMap');
	// HELIOS END
}

simulated function bool OnUnrealCommand(int cmd, int arg)
{
	local bool bHandled;

	if (!bIsVisible)
	{
		return true;
	}

	// mmg_john.hawley - Don't let input through when using the armory on APC
	if (`SCREENSTACK.IsInStack(class'UIArmory_CompactLoadout'))
	{
		return true;
	}

	if (!bSelectingLaunch)
	{
		CurrentAgentIndex = Navigator.GetSelectedIndex();
	}

	if (m_HUD.m_WorkerTray.bIsVisible)
	{
		if (m_HUD.m_WorkerTray.OnUnrealCommand(cmd, arg))
		{
			return true;
		}
	}

	if (!CheckInputIsReleaseOrDirectionRepeat(cmd, arg))
		return false;

	bHandled = true;

	switch (cmd)
	{
	case class'UIUtilities_Input'.const.FXS_DPAD_LEFT :
		if (bSelectingLaunch)
		{
			bSelectingLaunch = false;
			NavHelp.ContinueButton.OnLoseFocus();
			NavHelp.ContinueButton.SetSelected(false);
		}
		PlayMouseOverSound();
		SelectPrevAgent();
		UpdateNavHelp();
		break;

	case class'UIUtilities_Input'.const.FXS_DPAD_RIGHT :
		if (bSelectingLaunch)
		{
			bSelectingLaunch = false;
			NavHelp.ContinueButton.OnLoseFocus();
			NavHelp.ContinueButton.SetSelected(false);
		}
		PlayMouseOverSound();
		SelectNextAgent();
		UpdateNavHelp();
		break;

	case class'UIUtilities_Input'.const.FXS_ARROW_RIGHT :
	case class'UIUtilities_Input'.const.FXS_KEY_D:
	case class'UIUtilities_Input'.const.FXS_ARROW_LEFT :
	case class'UIUtilities_Input'.const.FXS_KEY_A :
		if (bSelectingLaunch)
		{
			bSelectingLaunch = false;
			NavHelp.ContinueButton.OnLoseFocus();
			NavHelp.ContinueButton.SetSelected(false);
			UpdateNavHelp();
		}
		bHandled = false; //Let this fall through to be handled by list. 
		break;

	case class'UIUtilities_Input'.const.FXS_ARROW_DOWN :
	case class'UIUtilities_Input'.const.FXS_KEY_S:
		if( !bSelectingLaunch )
		{
			bSelectingLaunch = true; 
			NavHelp.ContinueButton.OnReceiveFocus();
			NavHelp.ContinueButton.SetSelected(true);
			UpdateNavHelp();
		}
		else
		{
			bHandled = false;
		}
		break;
	case class'UIUtilities_Input'.const.FXS_ARROW_UP :
	case class'UIUtilities_Input'.const.FXS_KEY_W :
		if( bSelectingLaunch )
		{
			bSelectingLaunch = false;
			NavHelp.ContinueButton.OnLoseFocus();
			NavHelp.ContinueButton.SetSelected(false);
			UpdateNavHelp();
		}
		else
		{
			bHandled = false;
		}
		break;

	case class'UIUtilities_Input'.const.FXS_KEY_SPACEBAR :
	case class'UIUtilities_Input'.const.FXS_KEY_ENTER:
		
		if( bSelectingLaunch )
		{
			PlayConfirmSound();
			StartMissionAction();
		}
		else
		{
			bHandled = false;
		}
		break;

	case class'UIUtilities_Input'.const.FXS_BUTTON_B :
	case class'UIUtilities_Input'.const.FXS_KEY_ESCAPE :
	case class'UIUtilities_Input'.const.FXS_R_MOUSE_DOWN :
		if (m_HUD.m_WorkerTray.bIsVisible)
		{
			m_HUD.m_WorkerTray.Hide();
		}
		else
		{
			PlayMouseClickSound();
			CloseScreen();
		}
		break;
	case class'UIUtilities_Input'.const.FXS_BUTTON_X :
		PlayConfirmSound();
		StartMissionAction();
		break;
	case class'UIUtilities_Input'.const.FXS_BUTTON_START:
		`HQPRES.UIPauseMenu(, true);
		break;
	case class'UIUtilities_Input'.const.FXS_BUTTON_RTRIGGER :
		GoToSupplyScreen();
		break;
	case class'UIUtilities_Input'.const.FXS_BUTTON_LTRIGGER :
	case class'UIUtilities_Input'.const.FXS_BUTTON_LBUMPER :
	case class'UIUtilities_Input'.const.FXS_BUTTON_RBUMPER :
		bHandled = true; // fallthrough
		break;

	case class'UIUtilities_Input'.const.FXS_VIRTUAL_LSTICK_LEFT :
	case class'UIUtilities_Input'.const.FXS_VIRTUAL_LSTICK_RIGHT :
		PlayMouseOverSound();
		bHandled = false;
		break;

	default:
		bHandled = false;
		break;
	}

	return bHandled || super.OnUnrealCommand(cmd, arg);
}

simulated function OnReceiveFocus()
{
	super.OnReceiveFocus();

	UpdateData(); // TODO: Fix selection bug occuring within UpdateData()

	m_HUD.UpdateResources(self);
	ClearSquadSelectUI();
	if (CurrentAgentIndex != -1)
	{
		GetAgentSquadSelectUI(CurrentAgentIndex).OnReceiveFocus();
	}
	UpdateNavHelp();

	// HELIOS BEGIN
	`PRESBASE.RefreshCamera('SquadSelect');
	// HELIOS END
}

//---------------------------------------------------------------------------------------
//UIDioAutotestInterface
function bool SimulateScreenInteraction()
{
	if (!bLaunchEventPending)
	{
		StartMissionAction();
	}

	return true;
}


simulated function XComUnitPawn CreatePawn(StateObjectReference UnitRef, int index)
{
	local name LocationName;
	local PointInSpace PlacementActor;
	local XComGameState_Unit UnitState;
	local XComUnitPawn UnitPawn;
	local int locationIndex;

	locationIndex = index;
	LocationName = name(m_strPawnLocationIdentifier $ locationIndex);
	foreach WorldInfo.AllActors(class'PointInSpace', PlacementActor)
	{
		if (PlacementActor != none && PlacementActor.Tag == LocationName)
			break;
	}

	UnitState = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(UnitRef.ObjectID));
	UnitPawn = m_kPawnMgr.RequestCinematicPawn(self, UnitRef.ObjectID, PlacementActor.Location, PlacementActor.Rotation, name("Soldier"$index), '', true);
	UnitPawn.GotoState('CharacterCustomization');

	UnitPawn.CreateVisualInventoryAttachments(m_kPawnMgr, UnitState, , , false); // spawn weapons and other visible equipment

	return UnitPawn;
}

// Override for custom cleanup logic
simulated function OnRemoved()
{
	super.OnRemoved();
	ClearPawns();
}

simulated function ClearPawns()
{
	local XComUnitPawn UnitPawn;
	foreach UnitPawns(UnitPawn)
	{
		if (UnitPawn != none)
		{
			m_kPawnMgr.ReleaseCinematicPawn(self, UnitPawn.ObjectID, true);
		}
	}
	UnitPawns.Length = 0;
}

state Cinematic_PawnControl
{
	//Similar to the after action report, the characters walk up to the camera
	function StartPawnAnimation(name AnimState, name GremlinAnimState)
	{
		local int PawnIndex;
		local XComGameState_HeadquartersDio DioHQ;
		local XComGameState_Unit UnitState;
		local StateObjectReference UnitRef;
		local XComGameStateHistory History;
		local X2SoldierPersonalityTemplate PersonalityData;
		local XComHumanPawn HumanPawn;
		local XComUnitPawn Gremlin;

		History = `XCOMHISTORY;
		DioHQ = `DIOHQ;

		for (PawnIndex = 0; PawnIndex < DioHQ.APCRoster.Length; ++PawnIndex)
		{
			UnitRef = DioHQ.APCRoster[PawnIndex];
			if (UnitRef.ObjectID > 0)
			{
				UnitState = XComGameState_Unit(History.GetGameStateForObjectID(UnitRef.ObjectID));
				PersonalityData = UnitState.GetPersonalityTemplate();

				UnitPawns[PawnIndex].EnableFootIK(true);

				if ('SquadLineup_Walkaway' == AnimState)
				{
					UnitPawns[PawnIndex].SetHardAttach(true);
					UnitPawns[PawnIndex].SetBase(Cinedummy);

					//RAM - this combination of flags is necessary to correct an update order issue between the characters, the lift, and their body parts.
					UnitPawns[PawnIndex].SetTickGroup(TG_PostAsyncWork);
					UnitPawns[PawnIndex].Mesh.bForceUpdateAttachmentsInTick = false;
				}

				HumanPawn = XComHumanPawn(UnitPawns[PawnIndex]);
				if (HumanPawn != none)
				{
					HumanPawn.GotoState(AnimState);

					Gremlin = m_kPawnMgr.GetCosmeticPawn(eInvSlot_SecondaryWeapon, UnitRef.ObjectID);
					if (Gremlin != none && GremlinAnimState != '' && !Gremlin.IsInState(GremlinAnimState))
					{
						Gremlin.SetLocation(HumanPawn.Location);
						Gremlin.GotoState(GremlinAnimState);
					}
				}
				else
				{
					UnitPawns[PawnIndex].PlayFullBodyAnimOnPawn(PersonalityData.IdleAnimName, true);
				}
			}
		}
	}
}

//During the after action report, the characters walk up to the camera - this state represents that time
state Cinematic_PawnsWalkingUp extends Cinematic_PawnControl
{
	simulated event BeginState(name PreviousStateName)
	{
		StartPawnAnimation('SquadLineup_Walkup', 'Gremlin_WalkUp');
	}
}

state Cinematic_PawnsCustomization extends Cinematic_PawnControl
{
	simulated event BeginState(name PreviousStateName)
	{
		StartPawnAnimation('CharacterCustomization', '');
	}
}

state Cinematic_PawnsIdling extends Cinematic_PawnControl
{
	simulated event BeginState(name PreviousStateName)
	{
		StartPawnAnimation('CharacterCustomization', 'Gremlin_Idle');
	}
}

state Cinematic_PawnsWalkingAway extends Cinematic_PawnControl
{
	simulated event BeginState(name PreviousStateName)
	{
		StartPawnAnimation('SquadLineup_Walkaway', 'Gremlin_WalkBack');
	}
}

// mmg_john.hawley (12/9/19) - Update NavHelp ++ 
function IconSwapPlus(bool IsMouse)
{
	if (`SCREENSTACK.IsTopScreen(self))
	{
		UpdateNavHelp();
	}
	ClearSquadSelectUI();
}

DefaultProperties
{
	Package = "/ package/gfxSquadList/SquadList"; 
	m_strPawnLocationIdentifier = "PreM_UIPawnLocation_SquadSelect_";
}
