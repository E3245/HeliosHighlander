//---------------------------------------------------------------------------------------
//  FILE:    	UIDIOCityUnrest
//  AUTHOR:  	Brit Steiner - 08/08/2019
//  PURPOSE: 	City unrest bar HUD element. 
//           
//---------------------------------------------------------------------------------------
//  Copyright (c) 2018 Firaxis Games, Inc. All rights reserved.
//---------------------------------------------------------------------------------------

class UIDIOCityUnrest extends UIPanel
	dependson(UIDIOCityUnrest_Tooltip);

var UIPanel							m_GrayboxCityUnrestContainer;
var UIText							m_CitywideUnrestLabel;
var array<UIBGBox>					m_CityUnrestPips;
var UIButton						m_CitywideUnrestHelpButton;
var int								MaxPips;
var bool							bAnimateCityAnarchyChange;

var UIDIOCityUnrest_Tooltip UnrestTooltip;

var localized string	m_CitywideUnrestTitle;
var localized string	m_CitywideUnrestTitle1;
var localized string	m_CitywideUnrestTitle2;

var localized string	strAnarchyLabelLine1;
var localized string	strAnarchyLabelLine2;

var string m_CitywideUnrestHelpImage; 

//----------------------------------------------------------------------------
simulated function UIDIOCityUnrest InitCityUnrestPanel()
{
	local XComGameState_CampaignGoal CampaignGoal;

	super.InitPanel();
	
	AnchorTopRight();

	//TODO: need final unrest help button 
	m_CitywideUnrestHelpButton = Spawn(class'UIButton', m_GrayboxCityUnrestContainer).InitButton('CitywideUnrestHelpButton', "?", OnCitywideUnrestHelp);
	m_CitywideUnrestHelpButton.SetSize(32, 32);
	m_CitywideUnrestHelpButton.SetPosition(-220, 0);
	
	CampaignGoal = `DIOHQ.GetCampaignGoal();
	MaxPips = CampaignGoal.GetCityUnrestThreshold();

	// mmg_aaron.lee (10/29/19) BEGIN - allow to edit through global.uci
	SetY(`SAFEZONEVERTICAL);
	// mmg_aaron.lee (10/29/19) END

	RegisterForEvents();
	
	ProcessMouseEvents();
	InitializeTooltipData();
	
	return self;
}

//---------------------------------------------------------------------------------------
simulated function OnInit()
{
	super.OnInit();

	RefreshAll();
	RefreshLocation();
}

//---------------------------------------------------------------------------------------
function RegisterForEvents()
{
	local X2EventManager EventManager;
	local Object SelfObject;

	EventManager = `XEVENTMGR;
	SelfObject = self;

	EventManager.RegisterForEvent(SelfObject, 'STRATEGY_OverallCityUnrestChanged_Submitted', OnUnrestChanged, ELD_OnStateSubmitted);
	EventManager.RegisterForEvent(SelfObject, 'STRATEGY_ExecuteStrategyAction_Submitted', OnExecuteStrategyAction, ELD_OnStateSubmitted);
	EventManager.RegisterForEvent(SelfObject, 'STRATEGY_RevertStrategyAction_Submitted', OnRevertStrategyAction, ELD_OnStateSubmitted);
	EventManager.RegisterForEvent(SelfObject, 'STRATEGY_CollectionAddedWorker_Submitted', OnWorkerPlacementChanged, ELD_OnStateSubmitted);
	EventManager.RegisterForEvent(SelfObject, 'STRATEGY_CollectionRemovedWorker_Submitted', OnWorkerPlacementChanged, ELD_OnStateSubmitted);
	EventManager.RegisterForEvent(SelfObject, 'STRATEGY_WorkerMaskedChanged_Submitted', OnWorkerMaskChanged, ELD_OnStateSubmitted);
	EventManager.RegisterForEvent(SelfObject, 'STRATEGY_FieldTeamCreated_Submitted', OnFieldTeamCreated, ELD_OnStateSubmitted);
	EventManager.RegisterForEvent(SelfObject, 'STRATEGY_InvestigationStarted_Submitted', OnInvestigationStarted, ELD_OnStateSubmitted);
	EventManager.RegisterForEvent(SelfObject, 'STRATEGY_TurnChanged_Submitted', OnTurnChanged, ELD_OnStateSubmitted);
	EventManager.RegisterForEvent(SelfObject, 'STRATEGY_FieldTeamTargetingActivated', OnFieldTeamAbilityTargetingActivated, ELD_Immediate);
	EventManager.RegisterForEvent(SelfObject, 'STRATEGY_FieldTeamTargetingDeactivated', OnFieldTeamAbilityTargetingDeactivated, ELD_Immediate);
}

//---------------------------------------------------------------------------------------
function UnRegisterForEvents()
{
	local X2EventManager EventManager;
	local Object SelfObject;

	EventManager = `XEVENTMGR;
	SelfObject = self;

	EventManager.UnRegisterFromEvent(SelfObject, 'STRATEGY_OverallCityUnrestChanged_Submitted');
	EventManager.UnRegisterFromEvent(SelfObject, 'STRATEGY_ExecuteStrategyAction_Submitted');
	EventManager.UnRegisterFromEvent(SelfObject, 'STRATEGY_RevertStrategyAction_Submitted');
	EventManager.UnRegisterFromEvent(SelfObject, 'STRATEGY_CollectionAddedWorker_Submitted');
	EventManager.UnRegisterFromEvent(SelfObject, 'STRATEGY_CollectionRemovedWorker_Submitted');
	EventManager.UnRegisterFromEvent(SelfObject, 'STRATEGY_WorkerMaskedChanged_Submitted');
	EventManager.UnRegisterFromEvent(SelfObject, 'STRATEGY_FieldTeamCreated_Submitted');
	EventManager.UnRegisterFromEvent(SelfObject, 'STRATEGY_InvestigationStarted_Submitted');
	EventManager.UnRegisterFromEvent(SelfObject, 'STRATEGY_TurnChanged_Submitted');
	EventManager.UnRegisterFromEvent(SelfObject, 'STRATEGY_FieldTeamTargetingActivated');
	EventManager.UnRegisterFromEvent(SelfObject, 'STRATEGY_FieldTeamTargetingDeactivated');
}

function InitializeTooltipData()
{
	UnrestTooltip = Spawn(class'UIDIOCityUnrest_Tooltip', Movie.Pres.m_kTooltipMgr);
	UnrestTooltip.InitTooltip();
	UnrestTooltip.targetPath = string(MCPath);

	UnrestTooltip.ID = Movie.Pres.m_kTooltipMgr.AddPreformedTooltip(UnrestTooltip);
}

//---------------------------------------------------------------------------------------
simulated function Show()
{
	if (!class'DioStrategyTutorialHelper'.static.IsUnrestTutorialLocked())
	{
		super.Show();
	}
}

simulated function Hide()
{
	super.Hide();
}

function RefreshLocation()
{
	local UIDIOHUD DioHUD; 
	local float ResourcesWidth; 

	// HELIOS BEGIN
	// Replace the hard reference with a reference to the main HUD	
	DioHUD = UIDIOHUD(`SCREENSTACK.GetScreen(`PRESBASE.UIHUD_Strategy));
	// HELIOS END	
	ResourcesWidth = DioHUD.ResourcesPanel.Width; 

	SetPosition(-ResourcesWidth - Width - 18, Y); 
}

simulated function OnCommand(string cmd, string arg)
{
	local array<string> sizeData;
	if( cmd == "RealizeSize" )
	{
		sizeData = SplitString(arg, ",");
		Width = float(sizeData[0]);
		Height = float(sizeData[1]);

		RefreshLocation();
	}
}


//---------------------------------------------------------------------------------------
//				DISPLAY
//---------------------------------------------------------------------------------------

//---------------------------------------------------------------------------------------
simulated function RefreshAll()
{
	local XComGameState_CampaignGoal CampaignGoal;
	local int i;
	local string NewColor; 

	if (class'DioStrategyTutorialHelper'.static.IsUnrestTutorialLocked())
	{
		Hide();
	}
	else
	{
		//Show(); // mmg_john.hawley - I think this may be incorrect. Overriding when we try to Hide() in UIDIOHUD when going into Strategy
	}

	CampaignGoal = `DIOHQ.GetCampaignGoal();
	NewColor = class'UIUtilities_Colors'.static.GetHexColorFromState(CampaignGoal.GetCurrentAnarchyUIState());

	// Glow the pips that changed since last turn
	if (bAnimateCityAnarchyChange)
	{
		for (i = CampaignGoal.PrevTurnOverallCityUnrest; i < CampaignGoal.OverallCityUnrest; ++i)
		{
			SetArrowGlow(i, true, NewColor);
		}
	}

	MC.BeginFunctionOp("UpdateData");
	MC.QueueString(strAnarchyLabelLine1);
	MC.QueueString(strAnarchyLabelLine2);
	MC.QueueString(class'UIUtilities_Image'.const.EventQueue_Resistance); //TODO: need final icon 
	MC.QueueString(NewColor);
	MC.QueueNumber(CampaignGoal.OverallCityUnrest);
	MC.QueueNumber(MaxPips);
	MC.EndOp();
}

//Use this to put a giant glow ring around the entire meter. 
simulated function SetOverallGlow(bool bShow, optional string newColor = "")
{
	MC.BeginFunctionOp("SetOverallGlow");
	MC.QueueBoolean(bShow);
	MC.QueueString(newColor);
	MC.EndOp();
}

//Use this to animate and colorize specific arrow-pips.
simulated function SetArrowGlow(int arrowIndex, bool bShow, optional string newColor = "")
{
	MC.BeginFunctionOp("SetArrowGlow");
	MC.QueueNumber(arrowIndex);
	MC.QueueBoolean(bShow);
	MC.QueueString(newColor);
	MC.EndOp();
}

simulated function OnMouseEvent(int cmd, array<string> args)
{
	if (cmd == class'UIUtilities_Input'.const.FXS_L_MOUSE_UP)
	{
		OnCitywideUnrestHelp(none);
	}
	else
	{
		switch (cmd)
		{
		case class'UIUtilities_Input'.const.FXS_L_MOUSE_IN:
		case class'UIUtilities_Input'.const.FXS_L_MOUSE_OVER:
		case class'UIUtilities_Input'.const.FXS_L_MOUSE_DRAG_OVER:
			Screen.PlayMouseOverSound();
			break;
		}
	}
}

simulated function OnCitywideUnrestHelp(UIButton Button)
{
	local string SummaryString;

	Screen.PlayMouseClickSound();

	// Help popup just clones the tooltip text
	SummaryString = class'UIDIOCityUnrest_Tooltip'.static.BuildTooltipDescription();
	`STRATPRES.UIWarningDialog(m_CitywideUnrestTitle, SummaryString, eDialog_Normal, m_CitywideUnrestHelpImage);
}

// Animates pips above or below the current value
function PreviewUnrestChange(int PreviewUnrestValue)
{
	local XComGameState_CampaignGoal CampaignGoal;
	local int i, Start, End;

	CampaignGoal = `DIOHQ.GetCampaignGoal();
	if (PreviewUnrestValue < CampaignGoal.OverallCityUnrest)
	{
		Start = PreviewUnrestValue;
		End = CampaignGoal.OverallCityUnrest;
	}
	else if (PreviewUnrestValue > CampaignGoal.OverallCityUnrest)
	{
		Start = CampaignGoal.OverallCityUnrest;
		End = PreviewUnrestValue;
	}
	
	for (i = Start; i < End; ++i)
	{
		SetArrowGlow(i, true);
	}
}

function StopAnimateCityAnarchyChange()
{
	local int i;

	bAnimateCityAnarchyChange = false;
	for (i = 0; i < MaxPips; ++i)
	{
		SetArrowGlow(i, false);
	}
}

//---------------------------------------------------------------------------------------
//				EVENT LISTENERS
//---------------------------------------------------------------------------------------

function EventListenerReturn OnUnrestChanged(Object EventData, Object EventSource, XComGameState GameState, Name Event, Object CallbackData)
{
	RefreshAll();
	return ELR_NoInterrupt;
}

function EventListenerReturn OnExecuteStrategyAction(Object EventData, Object EventSource, XComGameState GameState, Name Event, Object CallbackData)
{
	RefreshAll();
	return ELR_NoInterrupt;
}

function EventListenerReturn OnTurnChanged(Object EventData, Object EventSource, XComGameState GameState, Name Event, Object CallbackData)
{
	bAnimateCityAnarchyChange = true;
	RefreshAll();
	SetTimer(12.0f, false, nameof(StopAnimateCityAnarchyChange));

	return ELR_NoInterrupt;
}

function EventListenerReturn OnWorkerPlacementChanged(Object EventData, Object EventSource, XComGameState GameState, Name Event, Object CallbackData)
{
	RefreshAll();
	return ELR_NoInterrupt;
}

function EventListenerReturn OnRevertStrategyAction(Object EventData, Object EventSource, XComGameState GameState, Name Event, Object CallbackData)
{
	RefreshAll();
	return ELR_NoInterrupt;
}

function EventListenerReturn OnWorkerMaskChanged(Object EventData, Object EventSource, XComGameState GameState, Name Event, Object CallbackData)
{
	RefreshAll();
	return ELR_NoInterrupt;
}

function EventListenerReturn OnFieldTeamCreated(Object EventData, Object EventSource, XComGameState GameState, Name Event, Object CallbackData)
{
	RefreshAll();
	return ELR_NoInterrupt;
}

function EventListenerReturn OnInvestigationStarted(Object EventData, Object EventSource, XComGameState GameState, Name Event, Object CallbackData)
{
	RefreshAll();
	return ELR_NoInterrupt;
}

function EventListenerReturn OnFieldTeamAbilityTargetingActivated(Object EventData, Object EventSource, XComGameState GameState, Name Event, Object CallbackData)
{
	local X2FieldTeamEffectTemplate EffectTemplate;
	local XComGameState_CampaignGoal CampaignGoal;
	local int AnarchyDelta, PreviewValue;

	EffectTemplate = X2FieldTeamEffectTemplate(EventData);
	if (EffectTemplate == none)
	{
		return ELR_NoInterrupt;
	}

	AnarchyDelta = EffectTemplate.CalcCityAnarchyChangeFromEffect();
	if (AnarchyDelta != 0)
	{
		CampaignGoal = `DIOHQ.GetCampaignGoal();
		PreviewValue = Max(CampaignGoal.OverallCityUnrest + AnarchyDelta, 0);
		PreviewUnrestChange(PreviewValue);
	}

	return ELR_NoInterrupt;
}

function EventListenerReturn OnFieldTeamAbilityTargetingDeactivated(Object EventData, Object EventSource, XComGameState GameState, Name Event, Object CallbackData)
{
	StopAnimateCityAnarchyChange();
	return ELR_NoInterrupt;
}

//---------------------------------------------------------------------------------------
DefaultProperties
{
	MCName = "DioCityUnrestMC";
	LibID = "DioCityUnrest";
	
	m_CitywideUnrestHelpImage="img:///UILibrary_StrategyImages.X2StrategyMap.DarkEvent_NewConstruction";
	MaxPips = 1; 
}

