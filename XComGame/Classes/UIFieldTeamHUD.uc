//----------------------------------------------------------------------------
//  *********   FIRAXIS SOURCE CODE   ******************
//  FILE:    UIFieldTeamHUD.uc
//  AUTHOR:  Brit Steiner
//  PURPOSE: Containers holding current field team ability icons.
//----------------------------------------------------------------------------
//  Copyright (c) 2019 Firaxis Games, Inc. All rights reserved.
//----------------------------------------------------------------------------

class UIFieldTeamHUD extends UIPanel;

// These values must be mirrored in the AbilityContainer actionscript file.
const MAX_NUM_ABILITIES = 4; // 4 abilities

var array<UIFieldTeamAbility> Abilities;
var UIFieldTeamAbility ActiveTargetingAbility;
var bool bTargetingActive;
var UIButton ActionButton;

var UIDIOStrategyMapFlash StrategyMapScreen; // mmg_john.hawley - we want abilities to work with strategy screen. Abilities are available in this screen.

var localized string strBuildFieldTeamLabel;
var localized string PanelTitle;
var localized string DirectionsSelectADistrict;

//----------------------------------------------------------------------------
// METHODS
//

simulated function UIFieldTeamHUD InitFieldTeamHUD()
{
	local int i;
	local UIFieldTeamAbility kItem;

	InitPanel();

	// Pre-cache UI data array
	for(i = 0; i < MAX_NUM_ABILITIES; ++i)
	{	
		kItem = Spawn(class'UIFieldTeamAbility', self);
		kItem.InitAbilityItem(name(class'UIFieldTeamAbility'.default.MCName $ i)); //Link to stage instance name 
		kItem.OnClickedDelegate = OnClickedAbility;
		kItem.FieldTeamHUD = self; 
		Abilities.AddItem(kItem);
	}
	
	ActionButton = Spawn(class'UIButton', self);
	ActionButton.InitButton('fieldTeamActionButton', "", OnClickActionButton);
	//ActionButton.SetPosition(-141, 2); //Centered over the 4th FT ability icon ---- 3/3/2020 Hector ----
	ActionButton.SetWidth(456); 
	ActionButton.Hide();

	MC.FunctionString("SetPanelTitle", PanelTitle);

	RegisterForEvents();

	return self;
}

simulated function OnInit()
{
	super.OnInit();
	UpdateData();
	SetActionButtonHighlight(false);
}

simulated function Show()
{
	local int i;
	
	if (class'DioStrategyTutorialHelper'.static.AreFieldTeamsAvailable())
	{
		for (i = 0; i < MAX_NUM_ABILITIES; i++)
		{
			Abilities[i].OnReceiveFocus();
			Abilities[i].OnLoseFocus();
		}
		UpdateData();
		super.Show();
	}
}

function RegisterForEvents()
{
	local X2EventManager EventManager;
	local Object SelfObject;

	EventManager = `XEVENTMGR;
	SelfObject = self;

	EventManager.RegisterForEvent(SelfObject, 'UIEvent_DistrictTargetSelected_Immediate', OnDistrictTargetSelected, ELD_Immediate);
}

function UnRegisterForEvents()
{
	local X2EventManager EventManager;
	local Object SelfObject;

	EventManager = `XEVENTMGR;
	SelfObject = self;

	EventManager.UnRegisterFromEvent(SelfObject, 'UIEvent_DistrictTargetSelected_Immediate');
}

function OnClickedAbility(UIFieldTeamAbility TargetAbility)
{
	local int i;
	for (i = 0; i < MAX_NUM_ABILITIES; ++i)
	{
		if (Abilities[i] != TargetAbility)
			Abilities[i].OnLoseFocus();
	}
	Navigator.SetSelected(TargetAbility);
	ActivateTargeting(TargetAbility);
}

function bool IsTargetingActive()
{
	return bTargetingActive;
}

function X2FieldTeamEffectTemplate GetActiveTargetingFieldTeamAbility()
{
	if (ActiveTargetingAbility != none)
	{
		return ActiveTargetingAbility.m_FieldTeamAbilityTemplate;
	}

	return none;
}

function  ActivateTargeting(UIFieldTeamAbility TargetAbility)
{
	local bool bAbilityUseable;
	local string PanelTitleString;

	bTargetingActive = true;
	ActiveTargetingAbility = TargetAbility;

	bAbilityUseable = TargetAbility.IsAbilityUseable();
	MC.FunctionBool("Activate", bAbilityUseable);	

	UpdateNavHelp();
	if( TargetAbility.m_FieldTeamAbilityTemplate.bUntargeted )
	{
		ActionButton.Show();
		ActionButton.SetText(class'UIUtilities_Text'.static.GetSizedText(`MAKECAPS(TargetAbility.m_FieldTeamAbilityTemplate.DisplayName), 24));
		//MC.FunctionString("SetPanelTitle", `MAKECAPS(TargetAbility.m_FieldTeamAbilityTemplate.DisplayName)); //black text area 
		MC.FunctionString("SetPanelTitle", "");
		SetActionButtonHighlight(true); //AFTER setting title text 
	}
	else
	{
		ActionButton.Hide();
		PanelTitleString = `MAKECAPS(TargetAbility.m_FieldTeamAbilityTemplate.DisplayName);
		if (bAbilityUseable)
		{
			PanelTitleString $= ":" @ DirectionsSelectADistrict;
		}
		MC.FunctionString("SetPanelTitle", PanelTitleString);
		SetActionButtonHighlight(false);
	}

	if( bAbilityUseable )
	{
		ActionButton.SetGood(true);
		ActionButton.SetDisabled(false);
		`XEVENTMGR.TriggerEvent('STRATEGY_FieldTeamTargetingActivated', TargetAbility.m_FieldTeamAbilityTemplate);
	}
	else
	{
		`XEVENTMGR.TriggerEvent('STRATEGY_FieldTeamTargetingActivated');
		ActionButton.SetDisabled(true);
		SetActionButtonHighlight(false);
	}

	MC.FunctionString("SetActivationButtonText", `MAKECAPS(TargetAbility.m_FieldTeamAbilityTemplate.DisplayName));

	// TODO: @hantunez : Uncomment this to see the field team camera in field team ability targeting mode. 
	`STRATPRES.RefreshCamera(class'XComStrategyPresentationLayer'.const.FieldTeamTargetingTag);

	`STRATPRES.ForceRefreshActiveScreenChanged();
}

function CancelTargeting()
{
	local int i;
		
	ActiveTargetingAbility = none;

	if( !bTargetingActive ) return; 
	
	bTargetingActive = false;

	MC.FunctionVoid("Deactivate");

	Navigator.GetSelected().OnLoseFocus();

	MC.FunctionString("SetPanelTitle", PanelTitle);

	ActionButton.Hide();
	SetActionButtonHighlight(false);

	UpdateNavHelp();

	//TODO : reset map-related visuals. 

	for( i = 0; i < Abilities.length; ++i )
	{
		Abilities[i].Deactivate();
	}

	`STRATPRES.RefreshCamera(class'XComStrategyPresentationLayer'.const.MapAreaTag);

	`XEVENTMGR.TriggerEvent('STRATEGY_FieldTeamTargetingDeactivated');
	`STRATPRES.ForceRefreshActiveScreenChanged();
}

function SetActionButtonHighlight(bool bShouldHighlight)
{
	MC.FunctionBool("SetActionButtonHighlight", bShouldHighlight);
}

function UpdateNavHelp()
{
	local UIDIOHUD DIOHUD; 

	// HELIOS BEGIN
	// Replace the hard reference with a reference to the main HUD	
	DioHUD = UIDIOHUD(`SCREENSTACK.GetScreen(`PRESBASE.UIHUD_Strategy));
	// HELIOS END	
	DioHUD.NavHelp.ClearButtonHelp();

	if( ActiveTargetingAbility != none )
	{
		DioHUD.NavHelp.AddBackButton(CancelTargeting);
	}
}

simulated function bool OnUnrealCommand(int cmd, int arg)
{
	local bool bHandled;
	local UIDIOStrategyMapFlash mapScreen;
	
	bHandled = false;

	if( !CheckInputIsReleaseOrDirectionRepeat(cmd, arg) )
		return false;

	mapScreen = UIDIOStrategyMapFlash(`SCREENSTACK.GetScreen(class'UIDIOStrategyMapFlash'));

	switch(cmd)
	{
		case (class'UIUtilities_Input'.const.FXS_KEY_ENTER):
		case (class'UIUtilities_Input'.const.FXS_KEY_SPACEBAR):
		case (class'UIUtilities_Input'.const.FXS_BUTTON_A):
			
			if (IsTargetingActive())
			{
				if (ActiveTargetingAbility.m_FieldTeamAbilityTemplate.bUntargeted)
				{
					OnClickActionButton(ActionButton);
				}
				else
				{
					StrategyMapScreen = UIDIOStrategyMapFlash(`SCREENSTACK.GetScreen(class'UIDIOStrategyMapFlash'));
					StrategyMapScreen.OnDistrictTargeted(mapScreen.Navigator.SelectedIndex);
				}
				bHandled = true;
			}
			else if (Navigator.SelectedIndex >= 0 && Navigator.SelectedIndex < Abilities.Length)
			{
				GetAbility(Navigator.SelectedIndex).Activate();

				bHandled = true;
			}
		
			break;

		case (class'UIUtilities_Input'.const.FXS_KEY_ESCAPE):
		case (class'UIUtilities_Input'.const.FXS_BUTTON_B):
		case class'UIUtilities_Input'.const.FXS_R_MOUSE_DOWN :
			if( IsTargetingActive() )
			{
				Screen.PlayMouseClickSound();
				CancelTargeting();
				bHandled = true;
			}
			break;
			
		case (class'UIUtilities_Input'.const.FXS_KEY_TAB):
		//case (class'UIUtilities_Input'.const.FXS_BUTTON_RBUMPER):
		//case (class'UIUtilities_Input'.const.FXS_BUTTON_RTRIGGER):
		//case (class'UIUtilities_Input'.const.FXS_DPAD_RIGHT):	
		case (class'UIUtilities_Input'.const.FXS_ARROW_RIGHT):
			if (!IsTargetingActive())
			{
				SelectAbility(Navigator.SelectedIndex + 1);
				bHandled = true;
			}

		case (class'UIUtilities_Input'.const.FXS_KEY_LEFT_SHIFT):
		//case (class'UIUtilities_Input'.const.FXS_BUTTON_LBUMPER):
		//case (class'UIUtilities_Input'.const.FXS_BUTTON_LTRIGGER):
		//case (class'UIUtilities_Input'.const.FXS_DPAD_LEFT):
		case (class'UIUtilities_Input'.const.FXS_ARROW_LEFT):
			if( !IsTargetingActive() )
			{
				SelectAbility(Navigator.SelectedIndex - 1);
				bHandled = true;
			}
			break;

		case (class'UIUtilities_Input'.const.FXS_BUTTON_RTRIGGER):
			if (!IsTargetingActive())
			{
				Screen.PlayMouseOverSound();
				SelectAbilityController(Navigator.SelectedIndex + 1);
				bHandled = true;
			}
			break;

		case (class'UIUtilities_Input'.const.FXS_BUTTON_LTRIGGER):
			if (!IsTargetingActive())
			{
				Screen.PlayMouseOverSound();
				SelectAbilityController(Navigator.SelectedIndex - 1);
				bHandled = true;
			}
			break;
	
		/*
		case (class'UIUtilities_Input'.const.FXS_KEY_1):	SelectAbility( 0 ); break;
		case (class'UIUtilities_Input'.const.FXS_KEY_2):	SelectAbility( 1 ); break;
		case (class'UIUtilities_Input'.const.FXS_KEY_3):	SelectAbility( 2 ); break;
		case (class'UIUtilities_Input'.const.FXS_KEY_4):	SelectAbility( 3 ); break;
		case (class'UIUtilities_Input'.const.FXS_KEY_5):	SelectAbility( 4 ); break;
		case (class'UIUtilities_Input'.const.FXS_KEY_6):	SelectAbility( 5 ); break;
		*/

		default: 
			if (`ISCONTROLLERACTIVE) // Exclude mouse events
			{
				ClearAbility(); // mmg_john.hawley (11/26/19) - Stop targeting if player does anothing but navigate and fire the ability. IE analog inputs will dismiss selection.
			}
			bHandled = false;
			break;
	}

	

	if (!bHandled)
	{
		super.OnUnrealCommand(cmd, arg);
	}

	return bHandled;
}


// Select ability at index, and then update all associated visuals. 
simulated function bool SelectAbility( int index, optional bool ActivateViaHotKey )
{
	//Make sure we get a valid index: 
	index += Abilities.length; 
	index = index % Abilities.length; 

	Abilities[index].Activate();
	Navigator.OnLoseFocus();
	Navigator.SetSelected(Abilities[index]);

	return true;
}
// mmg_john.hawley BEGIN - Controller Select for abilities
// mmg_john.hawley - Do not immediately activate ability when first selected
simulated function bool SelectAbilityController(int index, optional bool ActivateViaHotKey)
{
	`log( "Select ability" @ string(index) );

	index += Abilities.length;
	index = index % Abilities.length;

	ClearAbility();

	Navigator.SetSelected(Abilities[index]);
	Abilities[index].ControllerShowAntenna();	

	return true;
}

function UIFieldTeamAbility GetAbility(int index)
{
	return Abilities[index];
}

function ClearAbility()
{
	UIFieldTeamAbility(Navigator.GetSelected()).HideAntenna();
	Navigator.OnLoseFocus();
	Navigator.SelectedIndex = -1;
}
// mmg_john.hawley END

simulated public function bool ConfirmDistrictTarget(StateObjectReference DistrictRef)
{
	local string AkEventName;
	
	if( !CanActivateCurrentSelectedAbility() )
	{
		return false;
	}
	
	if (ActiveTargetingAbility.m_FieldTeamAbilityTemplate.CanTargetDistrict(DistrictRef))
	{
		AkEventName = "UI_Strategy_FieldTeams_Ability_Apply";
		`SOUNDMGR.PlayAkEventDirect(AkEventName, ActiveTargetingAbility);
		`STRATEGYRULES.SubmitExecuteFieldTeamAbility(ActiveTargetingAbility.m_FieldTeamAbilityTemplate, DistrictRef);
	}

	CancelTargeting();
	UpdateData(); 

	return true; 
}


// Build Flash pieces based on abilities loaded.
simulated function UpdateData()
{
	local array<X2FieldTeamEffectTemplate> ActiveAbilities;
	local int i; 

	class'DioStrategyAI'.static.FindAllFieldTeamAbilityTemplates(ActiveAbilities);
	for( i = 0; i < Abilities.length; ++i )
	{
		Abilities[i].UpdateTemplateAbility(ActiveAbilities[i]);
	}
}

function OnClickActionButton(UIButton Button)
{
	local UIFieldTeamAbility SelectedAbilityButton;
	local string AkEventName;

	SelectedAbilityButton = UIFieldTeamAbility(Navigator.GetSelected());
	if( SelectedAbilityButton == none )
	{
		return;
	}
	if( !CanActivateCurrentSelectedAbility() )
	{
		return;
	}

	if( ActiveTargetingAbility.m_FieldTeamAbilityTemplate.bUntargeted )
	{
		AkEventName = "UI_Strategy_FieldTeams_Ability_Apply";
		`SOUNDMGR.PlayAkEventDirect(AkEventName, SelectedAbilityButton);

		`STRATEGYRULES.SubmitExecuteFieldTeamAbility(ActiveTargetingAbility.m_FieldTeamAbilityTemplate);
		UpdateData();
		CancelTargeting();
		ActiveTargetingAbility.Deactivate();
	}
}

function SetDesc(string DescTitle, string DescBody)
{
	MC.BeginFunctionOp("SetDesc");
	MC.QueueString(DescTitle);
	MC.QueueString(DescBody);
	MC.EndOp();
}

function bool CanActivateCurrentSelectedAbility()
{
	if( ActiveTargetingAbility == none )
	{
		return false;
	}
	return ActiveTargetingAbility.IsAbilityUseable(); 
}
//---------------------------------------------------------------------------------------
//				EVENT LISTENERS
//---------------------------------------------------------------------------------------
function EventListenerReturn OnDistrictTargetSelected(Object EventData, Object EventSource, XComGameState GameState, Name Event, Object CallbackData)
{	
	local XComGameState_DioCityDistrict District;

	District = XComGameState_DioCityDistrict(EventData);
	if (District != none)
	{
		ConfirmDistrictTarget(District.GetReference());
	}

	return ELR_NoInterrupt;
}


// ===========================================================================
//  DEFAULTS:
// ===========================================================================
defaultproperties
{
	LibID = "FieldTeamHUD";
	MCName = "fieldTeamHUDMC";
		
	bAnimateOnInit = false;
}
