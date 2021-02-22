//---------------------------------------------------------------------------------------
//  FILE:    	DioStrategyCrewMgr
//  AUTHOR:  	Ryan McFall  --  08/19/2019
//  PURPOSE: 	Handles placing crew around the base in response to user activity
//           
//---------------------------------------------------------------------------------------
//  Copyright (c) 2018 Firaxis Games, Inc. All rights reserved.
//---------------------------------------------------------------------------------------
class DioStrategyCrewMgr extends Actor 
	dependson(XComCrewPositionVisualizer, UIPawnMgr) 
	native(Core);

/* Allow a limit on how many crew can be placed per frame */
var protected int NumCrewToProcessPerFrame;

/* Units will go here if they are on the APC roster */
var protected name APCRosterAreaTag;

/* Stored reference to the pawn manager - used to track character pawns*/
var protected UIPawnMgr CachedPawnMgr;

/* Stored reference to the history */
var protected XComGameStateHistory CachedHistory;

/* Temporary storage for state code*/
var transient XComGameState_HeadquartersDio DioHQ;
var transient XComGameState_Unit ProcessUnit;
var transient int NumCrewProcessed;
var transient XComUnitPawn FocusedPawn;

/* Spots where the crew will hang out when the player is in the base view */
var protected array<XComCrewPositionVisualizer> CrewPositionVisualizers;

/* This flag is set while the view is set on the armory */
var protectedwrite bool bInArmory;

cpptext
{
	/* Actor interface method for initialization following world instantiation*/
	virtual void PostBeginPlay() override;
}

//Actor Interface
//===================

/* Actor interface method for initialization following world instantiation*/
event PostBeginPlay()
{
	super.PostBeginPlay();

	RegisterForEvents();
	
	// HELIOS BEGIN
	// Use the Presentation Base to get the UI Pawn Manager
	// Overhauls can manually override it if needed
	CachedPawnMgr = `PRESBASE.GetUIPawnMgr();
	// HELIOS END
	CachedHistory = `XCOMHISTORY;

	//Design would like the APC roster units to be looking at the strategy map table
	APCRosterAreaTag = class'XComStrategyPresentationLayer'.const.MapAreaTag;
}

//Event Handlers
//===================
function RegisterForEvents()
{
	local Object ThisObj;

	ThisObj = self;
	`XEVENTMGR.RegisterForEvent(ThisObj, 'UIEvent_EnterBaseArea_Immediate', OnEnterBaseArea, ELD_Immediate);
	`XEVENTMGR.RegisterForEvent(ThisObj, 'VisEvent_NewCampaign', OnNewCampaignVisualize, ELD_Immediate);
	`XEVENTMGR.RegisterForEvent(ThisObj, 'UIEvent_PawnFocusedArmory', OnPawnFocusedArmory, ELD_Immediate);
	`XEVENTMGR.RegisterForEvent(ThisObj, 'UIEvent_PawnUnfocusedArmory', OnPawnUnfocusedArmory, ELD_Immediate);
}

/* This message is called as a result of the player selecting to enter an area of the base */
function EventListenerReturn OnEnterBaseArea(Object EventData, Object EventSource, XComGameState GameState, Name Event, Object CallbackData)
{
	local XComEventObject_EnterHeadquartersArea Data;
	local bool bRequestingArmory;

	Data = XComEventObject_EnterHeadquartersArea(EventData);
	bRequestingArmory = Data != none &&
						(Data.AreaTag == class'XComStrategyPresentationLayer'.const.ArmoryAreaTag || InStr(string(Data.AreaTag), string(class'XComStrategyPresentationLayer'.const.ArmoryAreaTag)) > -1);

	//If the game is transitioning either into or out of the armory trigger the placing all crew state
	if ((bRequestingArmory && !bInArmory) || (!bRequestingArmory && bInArmory))
	{
		bInArmory = bRequestingArmory;
		GotoState('PlacingAllCrew');
	}

	return ELR_NoInterrupt;
}

/* This message is called after the player has selected their initial crew in the campaign */
function EventListenerReturn OnNewCampaignVisualize(Object EventData, Object EventSource, XComGameState GameState, Name Event, Object CallbackData)
{
	GotoState('PlacingAllCrew');
	return ELR_NoInterrupt;
}

/* This message is received from the armory UI when a specific character is focused */
function EventListenerReturn OnPawnFocusedArmory(Object EventData, Object EventSource, XComGameState GameState, Name Event, Object CallbackData)
{
	local XComGameState_Unit UnitState;
	local XComUnitPawn NewFocusedPawn;
	local XComCrewPositionVisualizer FocusedCrewPosition;

	UnitState = XComGameState_Unit(EventData);
	NewFocusedPawn = CachedPawnMgr.RequestPawnByState(self, UnitState);

	//Ignore if this unit is already the focused one
	if (NewFocusedPawn != FocusedPawn)
	{
		//Previously focused unit should sit
		FocusedCrewPosition = FindVisualizer(FocusedPawn);
		if (FocusedCrewPosition != none)
		{
			FocusedCrewPosition.SetSitting(true);
		}

		//Newly focused unit stands up	
		FocusedCrewPosition = FindVisualizer(NewFocusedPawn);
		if (FocusedCrewPosition != none)
		{
			FocusedCrewPosition.SetSitting(false);
		}

		//Update our cached focus pawn
		FocusedPawn = NewFocusedPawn;
	}

	return ELR_NoInterrupt;
}

/* This message is received from the armory UI when a specific character is unfocused */
function EventListenerReturn OnPawnUnfocusedArmory(Object EventData, Object EventSource, XComGameState GameState, Name Event, Object CallbackData)
{	
	return ELR_NoInterrupt;
}

//External API methods
//===================
/* Given a unit state, create/retrieve a unit pawn and place it in a valid base crew position */
native function AssignCrewMemberPosition(XComGameState_Unit UnitState);

/* Given a unit pawn, return the crew position visualizer that has that pawn */
native function XComCrewPositionVisualizer FindVisualizer(XComUnitPawn UnitPawn);

//Internal methods
//===================
/* Cache the crew position visualizers we will use to place crew members */
native private function RegisterCrewPositions();

/* Used when switching between the armory view and base views, clears all crew positions ( except armory spots, as these cannot be shared between units ) */
native private function ClearAllCrewPositions();

/* Would love to nativize the whole pawn creation process, but that is out of scope for the crew manager implementation */
event GetPawnFromPawnMgr(XComGameState_Unit UnitStateObject, out XComUnitPawnNativeBase OutUnitPawn, out XComUnitPawnNativeBase OutCosmeticUnitPawn)
{	
	OutUnitPawn = CachedPawnMgr.RequestPawnByState(self, UnitStateObject);
	if (OutUnitPawn != none)
	{
		XComUnitPawn(OutUnitPawn).CreateVisualInventoryAttachments(CachedPawnMgr, UnitStateObject); // spawn weapons and other visible equipment

		//Perform any necessary pawn configuration in here
		OutUnitPawn.EnableFootIK(false);

		//Fetch the cosmetic unit pawn if there is one
		OutCosmeticUnitPawn = CachedPawnMgr.GetCosmeticPawn(eInvSlot_SecondaryWeapon, UnitStateObject.ObjectID);
	}	
}

/* Entered immediately following level load */
auto state Startup
{
	event BeginState(name PreviousStateName)
	{

	}

Begin:
	//@TODO Verify that the assets are loaded for the base characters
}

/* The purpose of this state is to "reset" the positions of all crew members. It is used any time that the crew all need to either
   go somewhere specific (ie. armory) or when initializing the system */
state PlacingAllCrew
{
	event BeginState(name PreviousStateName)
	{		
		ClearAllCrewPositions();
	}

Begin:
	//Allow for latent execution so we can amortize the cost of placing characters
	NumCrewProcessed = 0;
	DioHQ = XComGameState_HeadquartersDio(CachedHistory.GetSingleGameStateObjectForClass(class'XComGameState_HeadquartersDio', true));
	while(NumCrewProcessed < DioHQ.Squad.Length)	
	{		
		if (DioHQ.Squad[NumCrewProcessed].ObjectID > 0)
		{
			ProcessUnit = XComGameState_Unit(CachedHistory.GetGameStateForObjectID(DioHQ.Squad[NumCrewProcessed].ObjectID));
			if (ProcessUnit != none)
			{
				AssignCrewMemberPosition(ProcessUnit);
			}
		}

		++NumCrewProcessed;

		//Wait a frame if directed
		if (NumCrewProcessed % NumCrewToProcessPerFrame == 0)
		{	
			Sleep(0.0f);
		}
	}

	Sleep(0.0f);
	NumCrewProcessed = 0;

	while (NumCrewProcessed < DioHQ.Androids.Length)
	{
		if (DioHQ.Androids[NumCrewProcessed].ObjectID > 0)
		{
			ProcessUnit = XComGameState_Unit(CachedHistory.GetGameStateForObjectID(DioHQ.Androids[NumCrewProcessed].ObjectID));
			if (ProcessUnit != none)
			{
				AssignCrewMemberPosition(ProcessUnit);
			}
		}

		++NumCrewProcessed;

		//Wait a frame if directed
		if (NumCrewProcessed % NumCrewToProcessPerFrame == 0)
		{
			Sleep(0.0f);
		}
	}

	GotoState('Idle');
}

/* Resting state for the crew mgr */
state Idle
{
	event BeginState(name PreviousStateName)
	{
		
	}
}

defaultproperties
{
	NumCrewToProcessPerFrame=2
}