//---------------------------------------------------------------------------------------
//  FILE:    	UIScavengerMarket
//  AUTHOR:  	Brit Steiner 8/17/2019
//  PURPOSE: 	UI for handling display and purchasing of items from an 
//				XComGameState_StrategyMarket object.
//           
//---------------------------------------------------------------------------------------
//  Copyright (c) 2019 Firaxis Games, Inc. All rights reserved.
//---------------------------------------------------------------------------------------
class UIScavengerMarket extends UIScreen;


var StateObjectReference MarketRef;
var array<Commodity>				arrItems;
var array<UIScavengerMarketItem>	Items; 

var UIDIOHUD	m_HUD;

var localized string m_strTitle;
var localized string tagStr_ScavengerStatusString;

const MAX_ITEMS = 3;

//---------------------------------------------------------------------------------------
simulated function InitScreen(XComPlayerController InitController, UIMovie InitMovie, optional name InitName)
{
	local int i;

	super.InitScreen(InitController, InitMovie, InitName);
	
	// HELIOS BEGIN
	// Replace the hard reference with a reference to the main HUD
	m_HUD = UIDIOHUD(`SCREENSTACK.GetScreen(`PRESBASE.UIHUD_Strategy));
	// HELIOS END

	for (i = 0; i < MAX_ITEMS; ++i)
	{
		Items.AddItem(Spawn(class'UIScavengerMarketItem', self).InitItem(name("ScavengerPanel_"$i)));
	}
	Navigator.HorizontalNavigation = true;
	Navigator.LoopSelection = true;

	// HELIOS BEGIN	
	`PRESBASE.RefreshCamera(class'XComStrategyPresentationLayer'.const.MarketAreaTag);
	// HELIOS END
	
	UpdateNavHelp();
	RegisterForEvents();
}

//---------------------------------------------------------------------------------------
simulated function OnInit()
{
	super.OnInit();
	m_HUD.UpdateResources(self);
	UpdateNavHelp();
	Refresh();
}

//---------------------------------------------------------------------------------------
function RegisterForEvents()
{
	local X2EventManager EventManager;
	local Object SelfObject;

	EventManager = `XEVENTMGR;
	SelfObject = self;

	EventManager.RegisterForEvent(SelfObject, 'STRATEGY_MarketTransactionComplete_Submitted', OnTransactionComplete, ELD_OnStateSubmitted);
}

//---------------------------------------------------------------------------------------
function UnRegisterForEvents()
{
	local X2EventManager EventManager;
	local Object SelfObject;

	EventManager = `XEVENTMGR;
	SelfObject = self;

	EventManager.UnRegisterFromEvent(SelfObject, 'STRATEGY_MarketTransactionComplete_Submitted');
}

//---------------------------------------------------------------------------------------
function Refresh()
{
	local XGParamTag LocTag;
	local string DescString;
	local int DaysUntilNextMarket;

	m_HUD.RefreshAll();
	
	DaysUntilNextMarket = `DIOHQ.NextScavengerMarketTurn - `THIS_TURN;

	LocTag = XGParamTag(`XEXPANDCONTEXT.FindTag("XGParam"));
	LocTag.IntValue0 = DaysUntilNextMarket;
	DescString = `XEXPAND.ExpandString(tagStr_ScavengerStatusString);
	AS_SetScreenInfo(m_strTitle, DescString);

	PopulateData();
}

simulated function PopulateData()
{
	local int i;

	GetItems();
	for (i = 0; i < MAX_ITEMS; ++i)
	{
		if (i < arrItems.Length)
		{
			Items[i].PopulateData(arrItems[i]);
			Items[i].Show();
		}
		else
		{
			Items[i].Hide();
		}
	}
}

function UpdateNavHelp()
{
	m_HUD.NavHelp.ClearButtonHelp();
	m_HUD.NavHelp.AddBackButton(CloseScreen);
	if (`ISCONTROLLERACTIVE)
	{
		m_HUD.NavHelp.AddSelectNavHelp();
		//m_HUD.NavHelp.AddLeftHelp(Caps(class'UIArmory'.default.ChangeSoldierLabel), class'UIUtilities_Input'.static.GetGamepadIconPrefix() $ class'UIUtilities_Input'.const.ICON_DPAD_HORIZONTAL);
	}

	if( class'UIUtilities_DioStrategy'.static.ShouldShowMetaContentTags() )
	{
		if( `ISCONTROLLERACTIVE)
		{
			m_HUD.NavHelp.AddLeftHelp(`META_TAG $ class'UIUtilities_DioStrategy'.default.ViewMetaContentLabel, class'UIUtilities_Input'.static.GetGamepadIconPrefix() $ class'UIUtilities_Input'.const.ICON_Y_TRIANGLE);
		}
		else
		{
			m_HUD.NavHelp.AddLeftHelp(`META_TAG $ class'UIUtilities_DioStrategy'.default.ViewMetaContentLabel, , XComStrategyPresentationLayer(Movie.Pres).ViewMetaContent);
		}
	}
}

//---------------------------------------------------------------------------------------
function EventListenerReturn OnTransactionComplete(Object EventData, Object EventSource, XComGameState GameState, Name Event, Object CallbackData)
{
	GetItems();
	PopulateData();
	return ELR_NoInterrupt;
}

//---------------------------------------------------------------------------------------
function AS_SetScreenInfo(string title, string desc )
{
	MC.BeginFunctionOp("SetScreenInfo");
	MC.QueueString(title);
	MC.QueueString(desc);
	MC.EndOp();
}

//-------------- GAME DATA HOOKUP --------------------------------------------------------
simulated function XComGameState_StrategyMarket GetMarket()
{
	return XComGameState_StrategyMarket(`XCOMHISTORY.GetGameStateForObjectID(MarketRef.ObjectID));
}

//---------------------------------------------------------------------------------------
simulated function GetItems()
{
	arrItems = GetMarket().PrepareForSaleItems();
	// Truncate
	arrItems.Length = Min(arrItems.Length, MAX_ITEMS);
}

//---------------------------------------------------------------------------------------
simulated function bool OnUnrealCommand(int cmd, int arg)
{
	local bool bHandled;

	if (!CheckInputIsReleaseOrDirectionRepeat(cmd, arg))
		return false;

	bHandled = false;
	switch (cmd)
	{
	case class'UIUtilities_Input'.const.FXS_BUTTON_B :
	case class'UIUtilities_Input'.const.FXS_KEY_ESCAPE :
	case class'UIUtilities_Input'.const.FXS_R_MOUSE_DOWN :
		PlayMouseClickSound();
		CloseScreen();
		bHandled = true;
		break;

	case class'UIUtilities_Input'.const.FXS_BUTTON_Y :
	case class'UIUtilities_Input'.const.FXS_KEY_Y :
		`STRATPRES.UIMetaContentScreen();
		break;
	default:
		break;
	}

	return bHandled || super.OnUnrealCommand(cmd, arg);
}

//---------------------------------------------------------------------------------------
simulated function OnReceiveFocus()
{
	super.OnReceiveFocus();

	m_HUD.UpdateResources(self);
	UpdateNavHelp();
}

//---------------------------------------------------------------------------------------
simulated function CloseScreen()
{
	UnRegisterForEvents();
	super.CloseScreen();
}

//---------------------------------------------------------------------------------------
defaultproperties
{
	Package = "/ package/gfxScavengerMarket/ScavengerMarket";
	MCName = "theScreen";
}