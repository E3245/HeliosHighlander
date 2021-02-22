//---------------------------------------------------------------------------------------
//  *********   FIRAXIS SOURCE CODE   ******************
//  FILE:    UIArmory
//  AUTHOR:  Sam Batista
//  PURPOSE: Base screen for Armory screens. 
//           It creates and manages the Soldier Pawn, and various UI controls
//			 that get reused on several UIArmory_ screens.
//---------------------------------------------------------------------------------------
//  Copyright (c) 2016 Firaxis Games, Inc. All rights reserved.
//--------------------------------------------------------------------------------------- 

class UIArmory extends UIScreen
	config(UI)
	dependson(XComGameState_StrategyInventory)
	native(UI);

var name DisplayTag;
var string CameraTag;
var bool bUseNavHelp;

var Actor ActorPawn;
var name PawnLocationTag;
var float LargeUnitScale;

var UIDIOHUD m_HUD;

var UISoldierHeader Header;
var bool bShowExtendedHeaderData;
var StateObjectReference UnitReference;
var XComGameState CheckGameState;
var UIAbilityInfoScreen AbilityInfoScreen;

var XComGameState_HeadquartersDio DioHQ;

var name DisplayEvent;
var name SoldierSpawnEvent;
var name NavigationBackEvent;
var name HideMenuEvent;
var name RemoveMenuEvent;

var config name EnableWeaponLightingEvent;
var config name DisableWeaponLightingEvent;

var localized string PrevSoldierKey;
var localized string NextSoldierKey;
var localized string m_strTabNavHelp;
var localized string m_strRotateNavHelp;
var localized string GarageLabel;
var localized string ChangeSoldierLabel;
var bool m_bAllowAbilityToCycle;

var private transient bool m_bSuppressNextConfirmSound;

delegate static bool IsSoldierEligible(XComGameState_Unit Soldier);

simulated function InitArmory(StateObjectReference UnitRef, optional name DispEvent, optional name SoldSpawnEvent, optional name NavBackEvent, optional name HideEvent, optional name RemoveEvent, optional bool bInstant = false, optional XComGameState InitCheckGameState)
{
	local float InterpTime;

	DioHQ = class'UIUtilities_DioStrategy'.static.GetDioHQ();

	IsSoldierEligible = CanCycleTo;
	CheckGameState = InitCheckGameState;
	DisplayEvent = DispEvent;
	SoldierSpawnEvent = SoldSpawnEvent;
	HideMenuEvent = HideEvent;
	RemoveMenuEvent = RemoveEvent;
	NavigationBackEvent = NavBackEvent;

	// HELIOS BEGIN
	// Replace the hard reference with a reference to the main HUD
	m_HUD = UIDIOHUD(`SCREENSTACK.GetScreen(`PRESBASE.UIHUD_Strategy));
	// HELIOS END
	m_HUD.UpdateResources(self);

	if (SoldierSpawnEvent != '' || DisplayEvent != '')
	{
		WorldInfo.RemoteEventListeners.AddItem(self);
	}

	if (DisplayEvent == '')
	{
		InterpTime = `HQINTERPTIME;

		if(bInstant)
		{
			InterpTime = 0;
		}

		class'UIUtilities'.static.DisplayUI3D(DisplayTag, name(CameraTag), InterpTime);
	}
	else
	{
		if(bIsIn3D) UIMovie_3D(Movie).HideAllDisplays();
	}

	Header = Spawn(class'UISoldierHeader', self).InitSoldierHeader(UnitRef, CheckGameState);

	if( bShowExtendedHeaderData )
		Header.ShowExtendedData();
	else
		Header.HideExtendedData();

	SetUnitReference(UnitRef);

	// mmg_mike.anstine TODO JHawley - UI differences - is this screen even still used?
	if(bUseNavHelp || `ISCONSOLE) //bsg-nlong (11.21.16): We'll want some form of NavHelp in the console no matter what
	{
		UpdateNavHelp();
	}
}

event OnRemoteEvent(name RemoteEventName)
{
	super.OnRemoteEvent(RemoteEventName);

	if (RemoteEventName == SoldierSpawnEvent)
	{
		CreateSoldierPawn();
	}
	else if (RemoteEventName == DisplayEvent)
	{
		class'UIUtilities'.static.DisplayUI3D(DisplayTag, name(CameraTag), 0);
	}
	else if (RemoteEventName == HideMenuEvent)
	{
		if(bIsIn3D) UIMovie_3D(Movie).HideDisplay(DisplayTag);
	}
	else if (RemoteEventName == RemoveMenuEvent)
	{
		Movie.Stack.PopFirstInstanceOfClass(class'UIArmory');		
	}
}

// override for custom behavior
simulated function PopulateData();

simulated function UpdateNavHelp()
{
	if(!bIsFocused)
		return; //bsg-crobinson (5.30.17): If not focused return

	// mmg_john.hawley (11/7/19) - Updating NavHelp
	if(bUseNavHelp)
	{		
		m_HUD.NavHelp.ClearButtonHelp();
		m_HUD.NavHelp.AddBackButton(OnCancel);

		if (`ISCONTROLLERACTIVE)
		{
			m_HUD.NavHelp.AddSelectNavHelp();
			if (IsAllowedToCycleSoldiers()) 
			{
				m_HUD.NavHelp.AddLeftHelp(Caps(ChangeSoldierLabel), class'UIUtilities_Input'.static.GetGamepadIconPrefix() $ class'UIUtilities_Input'.const.ICON_LBRB_L1R1);
			}	
		}

		//m_HUD.NavHelp.AddRightHelp(GarageLabel, , OnClickGarageScreen);
		//m_HUD.NavHelp.AddSelectNavHelp(); // bsg-jrebar (4/12/17): Moved Select Nav Help
		
		/*LocTag = XGParamTag(`XEXPANDCONTEXT.FindTag("XGParam"));
		LocTag.StrValue0 = Movie.Pres.m_kKeybindingData.GetKeyStringForAction(PC.PlayerInput, eTBC_PrevUnit);
		PrevKey = `XEXPAND.ExpandString(PrevSoldierKey);
		LocTag.StrValue0 = Movie.Pres.m_kKeybindingData.GetKeyStringForAction(PC.PlayerInput, eTBC_NextUnit);
		NextKey = `XEXPAND.ExpandString(NextSoldierKey);*/


		if (Movie.IsMouseActive() && IsAllowedToCycleSoldiers())
		{
			/*m_HUD.NavHelp.SetButtonType("XComButtonIconPC");
			i = eButtonIconPC_Prev_Soldier;
			m_HUD.NavHelp.AddCenterHelp(string(i), "", PrevSoldier, false, PrevKey);
			i = eButtonIconPC_Next_Soldier;
			m_HUD.NavHelp.AddCenterHelp(string(i), "", NextSoldier, false, NextKey);
			m_HUD.NavHelp.SetButtonType("");*/
		}

		if (`ISCONTROLLERACTIVE && 
			DioHQ != none && IsAllowedToCycleSoldiers())
		{
		//m_HUD.NavHelp.AddCenterHelp( m_strTabNavHelp, class'UIUtilities_Input'.static.GetGamepadIconPrefix() $ class'UIUtilities_Input'.const.ICON_LBRB_L1R1);// bsg-jrebar (4/26/17): Armory UI consistency changes, centering buttons, fixing overlaps, removed button inlining
		}
		
		//if( `ISCONTROLLERACTIVE )
			//m_HUD.NavHelp.AddCenterHelp( m_strRotateNavHelp, class'UIUtilities_Input'.static.GetGamepadIconPrefix() $ class'UIUtilities_Input'.const.ICON_RSTICK); // bsg-jrebar (4/26/17): Armory UI consistency changes, centering buttons, fixing overlaps, removed button inlining
	}
}

// Override in child screens that need to disable soldier switching for some reason (ex: when promoting soldiers on top of avenger)
simulated function bool IsAllowedToCycleSoldiers()
{
	return true;
}

simulated function PrevSoldier()
{
	local StateObjectReference NewUnitRef;
	if( class'UIUtilities_DioStrategy'.static.CycleSoldiers(-1, UnitReference, CanCycleTo, NewUnitRef) )
		CycleToSoldier(NewUnitRef);
}

simulated function NextSoldier()
{
	local StateObjectReference NewUnitRef;
	if( class'UIUtilities_DioStrategy'.static.CycleSoldiers(1, UnitReference, CanCycleTo, NewUnitRef) )
		CycleToSoldier(NewUnitRef);
}

simulated function OnClickGarageScreen()
{
	// DIO DEPRECATED [1/2/2020 dmcdonough]
}

simulated static function bool CanCycleTo(XComGameState_Unit Unit)
{
	return true;
}

simulated static function CycleToSoldier(StateObjectReference NewRef)
{
	local int i;
	local UIArmory ArmoryScreen, CurrentScreen;
	local UIScreenStack ScreenStack;
	local Rotator CachedRotation, ZeroRotation;

	ScreenStack = `SCREENSTACK;

	for( i = ScreenStack.Screens.Length - 1; i >= 0; --i )
	{
		ArmoryScreen = UIArmory(ScreenStack.Screens[i]);
		if( ArmoryScreen != none )
		{
			CachedRotation = ArmoryScreen.ActorPawn != none ? ArmoryScreen.ActorPawn.Rotation : ZeroRotation;

			ArmoryScreen.SetUnitReference(NewRef);
			ArmoryScreen.CreateSoldierPawn(CachedRotation);
			ArmoryScreen.PopulateData();

			ArmoryScreen.Header.UnitRef = NewRef;
			ArmoryScreen.Header.PopulateData(ArmoryScreen.GetUnit());

			// Signal focus change (even if focus didn't actually change) to ensure modders get notified of soldier switching
			ArmoryScreen.SignalOnReceiveFocus();
		}
	}

	CurrentScreen = UIArmory(ScreenStack.GetCurrentScreen());
	if( CurrentScreen != none )
	{
		if( CurrentScreen.bShowExtendedHeaderData )
			ArmoryScreen.Header.ShowExtendedData();
		else
			ArmoryScreen.Header.HideExtendedData();
	}

	// TTP[7879] - Immediately process queued commands to prevent 1 frame delay of customization menu options
	if( ArmoryScreen != none )
		ArmoryScreen.Movie.ProcessQueuedCommands();

	`XEVENTMGR.TriggerEvent('UIEvent_CycleSoldier', none, none, none);
}

simulated function StateObjectReference GetUnitRef()
{
	return UnitReference;
}

simulated function SetUnitReference(StateObjectReference NewUnitRef)
{
	/*local int i;
	local SeqEvent_DIOArmoryCameraZoom CameraZoomEvent;
	local array<SequenceObject> DIOArmoryEvents;

	class'Engine'.static.GetCurrentWorldInfo().GetGameSequence().FindSeqObjectsByClass(class'SeqEvent_DIOArmoryCameraZoom', true, DIOArmoryEvents);

	for (i = 0; i < DIOArmoryEvents.Length; ++i)
	{
		CameraZoomEvent = SeqEvent_DIOArmoryCameraZoom(DIOArmoryEvents[i]);
		CameraZoomEvent.ZoomOut(String(GetUnit().GetSoldierClassTemplate().RequiredCharacterClass), PC);
	}*/

	UnitReference = NewUnitRef;
}

/* "Create" is a misnomer here, as the pawn in most cases will have been created already... but ehhhh... */
simulated function CreateSoldierPawn(optional Rotator DesiredRotation)
{
	local XComEventObject_EnterHeadquartersArea EnterAreaMessage;

	//Trigger the camera to pan over to the unit
	EnterAreaMessage = new class'XComEventObject_EnterHeadquartersArea';
	if (GetUnit().IsAndroid())
	{
		if (`DIOHQ.Androids[0] == GetUnitRef())
		{
			EnterAreaMessage.AreaTag = name(GetUnit().GetSoldierClassTemplate().DefaultHeadquartersAreaTag);
		}
		else
		{
			EnterAreaMessage.AreaTag = 'Armory_Locker_13';
		}
	}
	else
	{
		EnterAreaMessage.AreaTag = name(GetUnit().GetSoldierClassTemplate().DefaultHeadquartersAreaTag);
	}
	`XEVENTMGR.TriggerEvent('UIEvent_EnterBaseArea_Immediate', EnterAreaMessage, self, none);

	//Trigger pawn focusing event
	`XEVENTMGR.TriggerEvent('UIEvent_PawnFocusedArmory', GetUnit(), self, none);
}

// Override this function to provide custom pawn behavior
simulated function RequestPawn(optional Rotator DesiredRotation)
{
	ActorPawn = Movie.Pres.GetUIPawnMgr().RequestPawnByID(self, UnitReference.ObjectID, GetPlacementActor().Location, DesiredRotation);
	ActorPawn.GotoState('CharacterCustomization');
}

simulated function ReleasePawn(optional bool bForce)
{	
	ActorPawn = none;
}

// spawn weapons and other visible equipment - ovewritten in Loadout to provide custom behavior
simulated function LoadSoldierEquipment()
{	
	XComUnitPawn(ActorPawn).CreateVisualInventoryAttachments(Movie.Pres.GetUIPawnMgr(), GetUnit());
}

// Used in UIArmory_WeaponUpgrade & UIArmory_WeaponList
simulated function CreateWeaponPawn(XComGameState_Item Weapon, optional Rotator DesiredRotation)
{
	local Rotator NoneRotation;
	local XGWeapon WeaponVisualizer;
	
	// Make sure to clean up weapon actors left over from previous Armory screens.
	if(ActorPawn == none)
		ActorPawn = UIArmory(Movie.Stack.GetLastInstanceOf(class'UIArmory')).ActorPawn;

	// Clean up previous weapon actor
	if( ActorPawn != none )
		ActorPawn.Destroy();

	WeaponVisualizer = XGWeapon(Weapon.GetVisualizer());
	if( WeaponVisualizer != none )
	{
		WeaponVisualizer.Destroy();
	}

	class'XGItem'.static.CreateVisualizer(Weapon);
	WeaponVisualizer = XGWeapon(Weapon.GetVisualizer());
	ActorPawn = WeaponVisualizer.GetEntity();

	PawnLocationTag = X2WeaponTemplate(Weapon.GetMyTemplate()).UIArmoryCameraPointTag;

	if(DesiredRotation == NoneRotation)
		DesiredRotation = GetPlacementActor().Rotation;

	ActorPawn.SetLocation(GetPlacementActor().Location);
	ActorPawn.SetRotation(DesiredRotation);
	ActorPawn.SetHidden(false);
}

simulated function XComGameState_Unit GetUnit()
{
	return XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(UnitReference.ObjectID));
}

simulated function PointInSpace GetPlacementActor()
{
	local Actor TmpActor;
	local array<Actor> Actors;
	local XComBlueprint Blueprint;
	local PointInSpace PlacementActor;

	foreach WorldInfo.AllActors(class'PointInSpace', PlacementActor)
	{
		if (PlacementActor != none && PlacementActor.Tag == 'PointInSpace')
			break;
	}

	if(PlacementActor == none)
	{
		foreach WorldInfo.AllActors(class'XComBlueprint', Blueprint)
		{
			if (Blueprint.Tag == PawnLocationTag)
			{
				Blueprint.GetLoadedLevelActors(Actors);
				foreach Actors(TmpActor)
				{
					PlacementActor = PointInSpace(TmpActor);
					if(PlacementActor != none)
					{
						break;
					}
				}
			}
		}
	}

	return PlacementActor;
}

//==============================================================================

// override for custom behavior
simulated function OnCancel()
{
	local XComEventObject_EnterHeadquartersArea EnterAreaMessage;

	if (RemoveMenuEvent == '' || NavigationBackEvent == '')
	{
		Movie.Stack.PopFirstInstanceOfClass(class'UIArmory');
	}
	else
	{
		OnLoseFocus(); //bsg-jneal (5.23.17): we are leaving this screen through a remote event, lose focus now to prevent input during transition
		`XCOMGRI.DoRemoteEvent(NavigationBackEvent);
	}
	
	if (`SCREENSTACK.IsCurrentClass(`PRESBASE.ArmoryLandingArea))// only go back to armory overview from main screen
	{
		//Issue a message informing the visuals / game that we are switching locations
		EnterAreaMessage = new class'XComEventObject_EnterHeadquartersArea';
		EnterAreaMessage.AreaTag = class'XComStrategyPresentationLayer'.const.ArmoryAreaTag; //Should match the area tag for an XComHeadquartersAreaVisualizer actor placed into the strategy map

		`XEVENTMGR.TriggerEvent('UIEvent_EnterBaseArea_Immediate', EnterAreaMessage, self, none);
		
		//Trigger pawn focusing event, clear the selection
		`XEVENTMGR.TriggerEvent('UIEvent_PawnFocusedArmory', none, self, none);
	}
	else
	{
		// HELIOS BEGIN
		// Redirection to Presentation Base
		if (!`SCREENSTACK.IsCurrentClass(`PRESBASE.SquadSelect))
		{
			`PRESBASE.UIHQArmoryScreen();
		}
		// HELIOS END
	}
}

// override for custom behavior
simulated function OnAccept();

simulated function bool OnUnrealCommand(int cmd, int arg)
{
	local bool bHandled;


	if(!bIsFocused)
	{
		return false;
	}

	if (AbilityInfoScreen != none && Movie.Pres.ScreenStack.IsInStack(class'UIAbilityInfoScreen'))
	{
		if (AbilityInfoScreen.OnUnrealCommand(cmd, arg))
		{
			return true;
		}
	}

	if ( !CheckInputIsReleaseOrDirectionRepeat(cmd, arg) )
		return false;

	bHandled = true;

	switch( cmd )
	{
		case class'UIUtilities_Input'.const.FXS_MOUSE_5:
		case class'UIUtilities_Input'.const.FXS_KEY_TAB:
		case class'UIUtilities_Input'.const.FXS_BUTTON_RBUMPER:
			if(class'UIUtilities_Strategy'.static.GetXComHQ_Dio(true) != none)
			{
				if( m_bAllowAbilityToCycle && IsAllowedToCycleSoldiers())
				{
					PlayMouseClickSound();
					NextSoldier();
				}
			}
			break;
		case class'UIUtilities_Input'.const.FXS_MOUSE_4:
		case class'UIUtilities_Input'.const.FXS_KEY_LEFT_SHIFT:
		case class'UIUtilities_Input'.const.FXS_BUTTON_LBUMPER:
			if(class'UIUtilities_Strategy'.static.GetXComHQ_Dio(true) != none)
			{
				if (m_bAllowAbilityToCycle && IsAllowedToCycleSoldiers())
				{
					PlayMouseClickSound();
					PrevSoldier();
				}
			}
			break;
		case class'UIUtilities_Input'.const.FXS_BUTTON_B:
		case class'UIUtilities_Input'.const.FXS_KEY_ESCAPE:
		case class'UIUtilities_Input'.const.FXS_R_MOUSE_DOWN:
			PlayMouseClickSound();
			OnCancel();
			break;
		case class'UIUtilities_Input'.const.FXS_BUTTON_A:
		case class'UIUtilities_Input'.const.FXS_KEY_ENTER:
		case class'UIUtilities_Input'.const.FXS_KEY_SPACEBAR:
			if (m_bSuppressNextConfirmSound)
			{
				m_bSuppressNextConfirmSound = false;
			}
			else
			{
				PlayConfirmSound();
			}
			OnAccept();
			break;
		default:
			bHandled = false;
			break;
	}

	return bHandled || super.OnUnrealCommand(cmd, arg);
}

simulated protected function SuppressNextNonCursorConfirmSound()
{
	m_bSuppressNextConfirmSound = true;
}

function MoveCosmeticPawnOnscreen()
{
	local XComHumanPawn UnitPawn;
	local XComUnitPawn CosmeticPawn;

	UnitPawn = XComHumanPawn(ActorPawn);
	if (UnitPawn == none)
		return;

	CosmeticPawn = Movie.Pres.GetUIPawnMgr().GetCosmeticPawn(eInvSlot_SecondaryWeapon, UnitReference.ObjectID);
	if (CosmeticPawn == none)
		return;

	if (CosmeticPawn.IsInState('Onscreen'))
		return;

	if (CosmeticPawn.IsInState('Offscreen'))
	{
		CosmeticPawn.GotoState('StartOnscreenMove');
	}
	else
	{
		CosmeticPawn.GotoState('FinishOnscreenMove');
	}
}

simulated function Show()
{
	local float InterpTime;

	super.Show();

	InterpTime = `HQINTERPTIME;

	class'UIUtilities'.static.DisplayUI3D(DisplayTag, name(CameraTag), InterpTime);
}

simulated function Hide()
{
	super.Hide();
}

simulated function OnReceiveFocus()
{
	super.OnReceiveFocus();

	if( bShowExtendedHeaderData )
		Header.ShowExtendedData();
	else
		Header.HideExtendedData();

	m_HUD.UpdateResources(self);

	UpdateNavHelp();
	MoveCosmeticPawnOnscreen();
}

simulated function OnLoseFocus()
{
	super.OnLoseFocus();
	
	// Immediately process commands to prevent 1 frame delay of screens hiding when navigating the armory
	Movie.ProcessQueuedCommands();
}

simulated function OnRemoved()
{
	local array<SequenceObject> DIOArmoryEvents;
	local SeqEvent_DIOArmoryCameraZoom CameraZoomEvent;
	local SeqEvent_DIOArmoryCharactersEntry LeaveArmoryEvent;
	local int Idx;

	super.OnRemoved();

	class'Engine'.static.GetCurrentWorldInfo().GetGameSequence().FindSeqObjectsByClass(class'SeqEvent_DIOArmoryCameraZoom', true, DIOArmoryEvents);

	for (Idx = 0; Idx < DIOArmoryEvents.Length; ++Idx)
	{
		CameraZoomEvent = SeqEvent_DIOArmoryCameraZoom(DIOArmoryEvents[Idx]);
		CameraZoomEvent.ZoomOut("default", PC);
	}

	class'Engine'.static.GetCurrentWorldInfo().GetGameSequence().FindSeqObjectsByClass(class'SeqEvent_DIOArmoryCharactersEntry', true, DIOArmoryEvents);
	for (Idx = 0; Idx < DIOArmoryEvents.Length; ++Idx)
	{
		LeaveArmoryEvent = SeqEvent_DIOArmoryCharactersEntry(DIOArmoryEvents[Idx]);
		LeaveArmoryEvent.Leave(PC);
	}
	
	// Only destroy the pawn when all UIArmory screens are closed
	if(ActorPawn != none)
	{		
		if(bIsIn3D) Movie.Pres.Get3DMovie().HideDisplay(DisplayTag);		
	}
}

//==============================================================================

defaultproperties
{
	Package         = "/ package/gfxArmory/Armory";
	InputState      = eInputState_Evaluate;
	PawnLocationTag = "UIPawnLocation_Armory";
	//UIDisplay       = "UIBlueprint_Customize"; // overridden in child screens
	//UIDisplayCam    = "UIBlueprint_Customize"; // overridden in child screens
	bUseNavHelp = true;
	bAnimateOnInit = true;

	LargeUnitScale = 0.84;

	bConsumeMouseEvents = false;
	MouseGuardClass = class'UIMouseGuard_RotatePawn';
	m_bAllowAbilityToCycle = true;

	bShowExtendedHeaderData = false;
}
