class X2ExperienceConfig extends Object
	native(Core)
	config(GameData_XpData);


///////////////////////////////
// XP 

struct native DifficultyXPSet
{
	var() array<int>				  RequiredKills;    //  number of kills needed for each rank
};

//---------------------------------------------------------------------------------------
// DIO XP 

var protected config array<int>			RequiredXp;     //  Total XP needed for each rank
var protected config array<float>		ActMissionXp;	//  Base XP awarded for participating on a mission, by Act
var protected config array<float>		ActKillXp;		//  Base XP awarded for each combat kill, by Act
var protected config array<float>		ActMaxKillXp;	//  Max XP awarded for all kills in a mission, by Act

// END DIO XP
//---------------------------------------------------------------------------------------

// X2 PARAMS - DIO DEPRECATED [9/10/2019]
var protected config array<DifficultyXPSet>	PerDifficultyConfig;
var const config bool					bUseFullXpSystem; //  If true, RequiredXp and all XpEvents, BaseMissionXp, etc. are all used as designed. Otherwise, only RequiredKills matter.
var protected localized array<string>	RankNames;        //  there should be one name for each rank; e.g. Rookie, Squaddie, etc.
var protected localized array<string>	ShortNames;       //  the abbreviated rank name; e.g. Rk., Sq., etc.
var protected localized array<string>	PsiRankNames;     //  deprecated
var protected localized array<string>	PsiShortNames;    //  deprecated
var config array<XpEventDef>			XpEvents;         //  defines the name, shares, pool amount, and restrictions of all known XP-granting events
var protected config array<int>			BaseMissionXp;    //  configured by force level
var protected config array<int>			BonusMissionXp;   //  configured by force level
var protected config array<int>			MaxKillscore;     //  configured by force level
var protected config float				KillMissionXpCap; //  percentage modifier against the BonusMissionXp which determines the cap on kill xp
var const config float					KillXpBonusMult;  //  if the kill xp OTS unlock has been purchased, this is the bonus amount at the end of battle
var const config float					NumKillsBonus;    //  if the kill xP OTS unlock has been purchased, a soldier's number of kills gets this bonus multiplier when considering rank up

///////////////////////////////
// Squad Cohesion

var config int                        SquadmateScore_MedikitHeal;
var config int                        SquadmateScore_CarrySoldier;
var config int                        SquadmateScore_KillFlankingEnemy;
var config int                        SquadmateScore_Stabilize;

///////////////////////////////
// Alert Level

struct native AlertEventDef
{
	// The gameplay event which triggers this Alert Level modification.
	var name EventID;

	// The amount of value to be added to the current Alert Level when this event is triggered.
	var int AlertLevelBonus;

	// The friendly display string for this event in the post-mission completion UI.
	var localized string DisplayString;
};

// All of the Events for which there will be an Alert Level modification when triggered.
var private config array<AlertEventDef> AlertEvents;


///////////////////////////////
// Popular Support

struct native PopularSupportEventDef
{
	// The gameplay event which triggers this pop support modification.
	var name EventID;

	// The amount of value to be added to the current pop support when this event is triggered.
	var int PopularSupportBonus;

	// The friendly display string for this event in the post-mission completion UI.
	var localized string DisplayString;
};

// All of the Events for which there will be an pop support modification when triggered.
var private config array<PopularSupportEventDef> PopularSupportEvents;


//---------------------------------------------------------------------------------------
//				DIO XP
//---------------------------------------------------------------------------------------

static function int GetRequiredXp(const int Rank)
{
	CheckRank(Rank);
	return default.RequiredXp[Rank];
}

static function float GetActMissionXP(int Act)
{
	Act = Clamp(Act, 0, default.ActMissionXp.Length - 1);
	return default.ActMissionXp[Act];
}

static function float GetActKillXP(int Act)
{
	Act = Clamp(Act, 0, default.ActKillXp.Length - 1);
	return default.ActKillXp[Act];
}

static function float GetActMaxKillXP(int Act)
{
	Act = Clamp(Act, 0, default.ActMaxKillXp.Length - 1);
	return default.ActMaxKillXp[Act];
}

static function AwardMissionXP(XComGameState ModifyStateObject, XComGameState_StrategyAction_Mission MissionAction, bool bIgnoreMissionXP)
{
	local XComGameState_Unit Unit;
	local int i, UnitTotalXP, MissionXP, NumKills, CurrentAct;
	local float XPScalar, fScaledMissionXP, fKillsXP, fScaledKillsXP, fTotalXP, fMaxKillXP;

	local XComLWTuple Tuple; // HELIOS VARIABLES

	`Log("AWARD MISSION XP", , 'XCom_XP');

	XPScalar = MissionAction.XPScalar;
	// Early out: this mission awards no XP
	if (XPScalar <= 0.0)
	{
		`Log("** XPScalar is ZERO, mission awards no XP", , 'XCom_XP');
		return;
	}

	CurrentAct = class'DioStrategyAI'.static.GetCurrentActIndex();
	MissionXP = GetActMissionXP(CurrentAct);
	fKillsXP = GetActKillXP(CurrentAct);
	fMaxKillXP = GetActMaxKillXP(CurrentAct);
	
	// Base mission XP awarded to all units
	fScaledMissionXP = float(MissionXP) * XPScalar;

	`Log("** CurrentAct [" @ CurrentAct @ "]", , 'XCom_XP');
	`Log("** fKillsXP [" @ fKillsXP @ "] based upon Act", , 'XCom_XP');
	`Log("** fMaxKillXP [" @ fMaxKillXP @ "] based upon Act", , 'XCom_XP');
	`Log("** MissionXP [" @ MissionXP @ "] based upon act", , 'XCom_XP');

	if (bIgnoreMissionXP) // if the mission was aborted etc, no mission XP
	{
		fScaledMissionXP = 0;
		`Log("** MissionXP [" @ fScaledMissionXP @ "] changed because bIgnoreMissionXP (aborted likely)", , 'XCom_XP');
	}

	for (i = 0; i < MissionAction.AssignedUnitRefs.Length; ++i)
	{
		Unit = XComGameState_Unit(ModifyStateObject.ModifyStateObject(class'XComGameState_Unit', MissionAction.AssignedUnitRefs[i].ObjectID));
		`Log("** Unit [" @ Unit.GetNickName(true) @ "] [" @ Unit.ObjectID @ "]", , 'XCom_XP');
		NumKills = Unit.KilledUnitsLastMission.Length;//TODO-DIO-STRATEGY Confirm? [9/10/2019 dmcdonough]
		`Log("**** Kills [" @ NumKills @ "]", , 'XCom_XP');
		if (NumKills > 0)
		{
			fScaledKillsXP = (float(NumKills) * fKillsXP) * XPScalar;
			`Log("**** Kill XP [" @ fScaledKillsXP @ "]", , 'XCom_XP');
			if (fScaledKillsXP > fMaxKillXP)
			{
				fScaledKillsXP = fMaxKillXP;
				`Log("**** Kill XP [" @ fScaledKillsXP @ "] clamped to max kill XP", , 'XCom_XP');
			}
		}
		`Log("**** Mission XP [" @ fScaledMissionXP @ "]", , 'XCom_XP');
		fTotalXP = fScaledMissionXP + fScaledKillsXP;
		UnitTotalXP = Round(fTotalXP);

		// HELIOS BEGIN
		// Add a hook that allows modders to modify or add to the Total XP gained from a mission.
		// The Tuple will be sent as the Event Data, and the Unitstate will be sent as the Event Source!
		// The Unit is already being modified while this function is in the stack, so there's no need to call ModifyStateObject on it!
		Tuple = new class'XComLWTuple';
		Tuple.Id = 'HELIOS_Data_XPAwardToUnit';
		Tuple.Data.Add(3);
		Tuple.Data[0].kind 		= XComLWTVInt;
		Tuple.Data[0].i 		= UnitTotalXP;		// Add the total calculated XP gain to the tuple
		Tuple.Data[1].kind		= XComLWTVFloat;
		Tuple.Data[1].f			= fScaledMissionXP;	// Add the calculated scaled mission XP
		Tuple.Data[2].kind		= XcomLWTVObject;
		Tuple.Data[2].o			= MissionAction;	// Add the mission action so modders can access information on the mission site

		`XEVENTMGR.TriggerEvent('HELIOS_AwardUnitXP', Tuple, Unit, ModifyStateObject);

		// If the value has changed, log and replace value
		if (Tuple.Data[0].i != UnitTotalXP)
		{
			`Log("**** XP Reward was changed from" @ UnitTotalXP @" to [" @ Tuple.Data[0].i @ "]", , 'XCom_XP');
			UnitTotalXP = Tuple.Data[0].i;
		}
		// HELIOS END

		`Log("**** Total XP [" @ UnitTotalXP @ "]", , 'XCom_XP');
		Unit.AddXp(UnitTotalXP);
	}
}

//---------------------------------------------------------------------------------------
//				OLD X2 XP 
//---------------------------------------------------------------------------------------

static native function int GetBaseMissionXp(int ForceLevel);
static native function int GetBonusMissionXp(int ForceLevel);
static native function int GetMaxKillscore(int ForceLevel);

static function string GetRankName(const int Rank, name ClassName)
{
	local X2SoldierClassTemplate ClassTemplate;

	CheckRank(Rank);
	
	ClassTemplate = class'X2SoldierClassTemplateManager'.static.GetSoldierClassTemplateManager().FindSoldierClassTemplate(ClassName);
	
	if (ClassTemplate != none && ClassTemplate.RankNames.Length > 0)
		return ClassTemplate.RankNames[Rank];
	else
		return default.RankNames[Rank];
}

static function string GetShortRankName(const int Rank, name ClassName)
{
	local X2SoldierClassTemplate ClassTemplate;

	CheckRank(Rank);

	ClassTemplate = class'X2SoldierClassTemplateManager'.static.GetSoldierClassTemplateManager().FindSoldierClassTemplate(ClassName);

	if (ClassTemplate != none && ClassTemplate.ShortNames.Length > 0)
		return ClassTemplate.ShortNames[Rank];
	else
		return default.ShortNames[Rank];
}

static function int GetRequiredKills(const int Rank)
{
	local array<int> KillsForRank;
	local int Index;

	CheckRank(Rank);

	for( Index = 0; Index < default.PerDifficultyConfig.Length; ++Index )
	{
		KillsForRank.AddItem(default.PerDifficultyConfig[Index].RequiredKills[Rank]);
	}

	return `ScaleStrategyArrayInt(KillsForRank);
}

static function int GetMaxRank()
{
	return default.RequiredXp.Length - 1;
}

static function bool CheckRank(const int Rank)
{
	if (Rank < 0 || Rank >= default.RequiredXp.Length)
	{
		`RedScreen("Rank" @ Rank @ "is out of bounds for configured XP (" $ default.RequiredXp.Length $ ")\n" $ GetScriptTrace());
		return false;
	}
	return true;
}

static function bool FindXpEvent(name EventID, out XpEventDef EventDef)
{
	local int i;

	for (i = 0; i < default.XpEvents.Length; ++i)
	{
		if (default.XpEvents[i].EventID == EventID)
		{
			EventDef = default.XpEvents[i];
			return true;
		}
	}
	return false;
}


///////////////////////////////
// Squad Cohesion

static function int GetSquadCohesionValue(array<XComGameState_Unit> Units)
{
	local int TotalCohesion, i, j;
	local SquadmateScore Score;

	TotalCohesion = 0;

	for (i = 0; i < Units.Length; ++i)
	{
		for (j = i + 1; j < Units.Length; ++j)
		{
			if (Units[i].GetSquadmateScore(Units[j].ObjectID, Score))
			{
				TotalCohesion += Score.Score;
			}
		}
	}
	return TotalCohesion;
}


///////////////////////////////
// Alert Level

static function int GetAlertLevelBonusForEvent( Name InEvent )
{
	local int i;

	for( i = 0; i < default.AlertEvents.length; ++i )
	{
		if( InEvent == default.AlertEvents[i].EventID )
		{
			return default.AlertEvents[i].AlertLevelBonus;
		}
	}

	return 0;
}

static function int GetAlertLevelDataForEvent( Name InEvent, out string OutDisplayString )
{
	local int i;

	for( i = 0; i < default.AlertEvents.length; ++i )
	{
		if( InEvent == default.AlertEvents[i].EventID )
		{
			OutDisplayString = default.AlertEvents[i].DisplayString;
			return default.AlertEvents[i].AlertLevelBonus;
		}
	}

	return 0;
}


///////////////////////////////
// Popular Support

static function int GetPopularSupportBonusForEvent( Name InEvent )
{
	local int i;

	for( i = 0; i < default.PopularSupportEvents.length; ++i )
	{
		if( InEvent == default.PopularSupportEvents[i].EventID )
		{
			return default.PopularSupportEvents[i].PopularSupportBonus;
		}
	}

	return 0;
}

static function int GetPopularSupportDataForEvent( Name InEvent, out string OutDisplayString )
{
	local int i;

	for( i = 0; i < default.PopularSupportEvents.length; ++i )
	{
		if( InEvent == default.PopularSupportEvents[i].EventID )
		{
			OutDisplayString = default.PopularSupportEvents[i].DisplayString;
			return default.PopularSupportEvents[i].PopularSupportBonus;
		}
	}

	return 0;
}
