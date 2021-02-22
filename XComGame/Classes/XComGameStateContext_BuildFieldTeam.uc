//---------------------------------------------------------------------------------------
//  FILE:    	XComGameStateContext_BuildFieldTeam
//  AUTHOR:  	David McDonough  --  6/13/2019
//  PURPOSE: 	Context for creating a new Field Team in a Dio City District.
//           
//---------------------------------------------------------------------------------------
//  Copyright (c) 2019 Firaxis Games, Inc. All rights reserved.
//---------------------------------------------------------------------------------------
class XComGameStateContext_BuildFieldTeam extends XComGameStateContext;

var() X2FieldTeamTemplate FieldTeamTemplate;
var() StateObjectReference DistrictRef;

//---------------------------------------------------------------------------------------
//				GameState Interface
//---------------------------------------------------------------------------------------
function bool Validate(optional EInterruptionStatus InInterruptionStatus)
{
	return true;
}

//---------------------------------------------------------------------------------------
function XComGameState ContextBuildGameState()
{
	local XComGameState NewGameState;
	local XComGameState_HeadquartersDio DioHQ;
	local XComGameState_DioCityDistrict District;
	local XComGameState_FieldTeam NewFieldTeam, CurFieldTeam;
	local int IntelCost, CreditsCost, EleriumCost;

	NewGameState = `XCOMHISTORY.CreateNewGameState(true, self);
	
	if (FieldTeamTemplate == none)
	{
		return NewGameState;
	}
	
	DioHQ = XComGameState_HeadquartersDio(NewGameState.ModifyStateObject(class'XComGameState_HeadquartersDio', `DIOHQ.ObjectID));	
	District = XComGameState_DioCityDistrict(NewGameState.ModifyStateObject(class'XComGameState_DioCityDistrict', DistrictRef.ObjectID));
	if (District == none)
	{
		return NewGameState;
	}

	// Consume free builds, if any
	if (DioHQ.FreeFieldTeamBuilds > 0)
	{
		DioHQ.ChangeFreeFieldTeamBuilds(NewGameState, -1);
		// HELIOS BEGIN
		// Replace the hard reference with a reference to the main HUD
		UIDIOHUD(`SCREENSTACK.GetScreen(`PRESBASE.UIHUD_Strategy)).RefreshAll();
		// HELIOS END	
	}
	else
	{
		// Determine what rank the FT will be after building
		CurFieldTeam = District.GetFieldTeam();
		// Calc costs
		class'DioStrategyAI'.static.CalculateFieldTeamCost(FieldTeamTemplate, CurFieldTeam, CreditsCost, IntelCost, EleriumCost);
		// Pay costs
		DioHQ.ChangeResources(NewGameState, -CreditsCost, -IntelCost, -EleriumCost);
	}

	// Build
	NewFieldTeam = FieldTeamTemplate.CreateInstanceFromTemplate(NewGameState);
	`XEVENTMGR.TriggerEvent('STRATEGY_FieldTeamCreated_Submitted', NewFieldTeam, NewFieldTeam, NewGameState);

	// Place
	NewFieldTeam.PlaceFieldTeam(NewGameState, DistrictRef);

	return NewGameState;
}

//---------------------------------------------------------------------------------------
protected function ContextBuildVisualization()
{
}

//---------------------------------------------------------------------------------------
function string SummaryString()
{
	return "XComGameStateContext_BuildFieldTeam";
}

//---------------------------------------------------------------------------------------
defaultproperties
{
}