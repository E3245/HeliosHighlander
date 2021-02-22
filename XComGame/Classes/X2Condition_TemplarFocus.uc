//---------------------------------------------------------------------------------------
//  FILE:    X2Condition_TemplarFocus.uc
//  AUTHOR:  Scott Spanburg
//  DATE:    25-February-2019
//           
//  NOTE: This condition checks if the unit has Templar Focus Level
//
//---------------------------------------------------------------------------------------
//  Copyright (c) 2018 Firaxis Games, Inc. All rights reserved.
//---------------------------------------------------------------------------------------
class X2Condition_TemplarFocus extends X2Condition;

var int RequiredLevel;
var bool bRequireTargetNotMaxLevel;

event name CallMeetsConditionWithSource(XComGameState_BaseObject kTarget, XComGameState_BaseObject kSource)
{
	local XComGameState_Unit UnitState;
	local name RetCode;
	local int FocusLevel;

	RetCode = 'AA_ValueCheckFailed';
	UnitState = XComGameState_Unit(kSource);
	if( UnitState != none )
	{
		FocusLevel = UnitState.GetTemplarFocusLevel();
		if( FocusLevel >= RequiredLevel )
		{
			RetCode = 'AA_Success';
		}
	}
	return RetCode;
}

event name CallMeetsCondition(XComGameState_BaseObject kTarget)
{
	local XComGameState_Unit UnitState;
	local int FocusLevel, MaxFocusLevel;

	UnitState = XComGameState_Unit(kTarget);
	if (UnitState != none)
	{
		FocusLevel = UnitState.GetTemplarFocusLevel();
		
		// HELIOS BEGIN
		// Fix that uses the Focus State's GetMaxFocus() function instead of a static reference
		MaxFocusLevel = UnitState.GetTemplarFocusEffectState().GetMaxFocus(UnitState);
		// HELIOS END

		if (bRequireTargetNotMaxLevel && FocusLevel >= MaxFocusLevel)
		{
			return 'AA_UnitHasMaxRage';
		}
	}
	return 'AA_Success';
}