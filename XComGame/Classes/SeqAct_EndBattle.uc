//-----------------------------------------------------------
// Ends a battle
//-----------------------------------------------------------
class SeqAct_EndBattle extends SequenceAction;

// If this battle was lost, specify if its unfailable.
var() UICombatLoseType LoseType;

// If true, this node will also generate a replay save that can be used to replay this mission, up to and including the
// save
var() bool GenerateReplaySave;

event Activated()
{
	local XComGameStateHistory History;
	local X2TacticalGameRuleset Ruleset;
	local XComGameState_Player PlayerState;
	local X2BenchmarkAutoTestMgr AutoTestMgr;
	local XComCheatManager CheatMgr;
	local array<ETeam> Teams;
	local ETeam ImpulseTeam;
	local int ImpulseIdx;
	local bool bHandled;

	History = `XCOMHISTORY;
	if(History == none) return;

	Ruleset = `TACTICALRULES;
	if(Ruleset == none) return;

	Teams.AddItem(eTeam_XCom);
	Teams.AddItem(eTeam_Alien);
	Teams.AddItem(eTeam_One);
	Teams.AddItem(eTeam_Two);
	Teams.AddItem(eTeam_TheLost);
	Teams.AddItem(eTeam_Resistance);

	CheatMgr = `CHEATMGR;

	//Let the auto test mgr force a victory
	AutoTestMgr = X2BenchmarkAutoTestMgr(class'WorldInfo'.static.GetWorldInfo().Game.MyAutoTestManager);
	if (AutoTestMgr != none && AutoTestMgr.bForceMissionVictory)
	{
		ImpulseTeam = eTeam_XCom;
	}
	else if (CheatMgr.bSimulatingCombat)
	{
		ImpulseTeam = eTeam_XCom;
	}
	else
	{
		for (ImpulseIdx = 0; ImpulseIdx < InputLinks.Length; ++ImpulseIdx)
		{
			if (InputLinks[ImpulseIdx].bHasImpulse)
			{
				ImpulseTeam = Teams[ImpulseIdx];
				break;
			}
		}
	}

	bHandled = false;

	foreach History.IterateByClassType(class'XComGameState_Player', PlayerState)
	{
		if (PlayerState.TeamFlag == ImpulseTeam)
		{
			// HELIOS BEGIN
			// Allow mods to change how EndBattle gets processed.
			if ( DLCOnMissionEndBattle(XGPlayer(PlayerState.GetVisualizer()), LoseType, GenerateReplaySave) )
			{
				bHandled = true;
			}

			if (!bHandled)
			{
				Ruleset.EndBattle(XGPlayer(PlayerState.GetVisualizer()), LoseType, GenerateReplaySave);
			}
			
			break;
			// HELIOS END
		}
	}
}

function bool DLCOnMissionEndBattle(XGPlayer VictoriousPlayer, UICombatLoseType UILoseType, bool bGenerateReplaySave)
{
	local array<X2DownloadableContentInfo> DLCInfos; 
	local int i; 
	
	DLCInfos = `ONLINEEVENTMGR.GetDLCInfos(false);

	for(i = 0; i < DLCInfos.Length; ++i)
	{
		if ( DLCInfos[i].OnMissionEndBattle(VictoriousPlayer, UILoseType, bGenerateReplaySave) )
		{
			return true;
		}
	}

	return false;
}

/**
* Return the version number for this class.  Child classes should increment this method by calling Super then adding
* a individual class version to the result.  When a class is first created, the number should be 0; each time one of the
* link arrays is modified (VariableLinks, OutputLinks, InputLinks, etc.), the number that is added to the result of
* Super.GetObjClassVersion() should be incremented by 1.
*
* @return	the version number for this specific class.
*/
static event int GetObjClassVersion()
{
	return Super.GetObjClassVersion() + 1;
}

defaultproperties
{
	ObjCategory="Gameplay"
	ObjName="End Battle"

	bConvertedForReplaySystem=true
	bCanBeUsedForGameplaySequence=true
	
	InputLinks(0)=(LinkDesc="XCom Victory")
	InputLinks(1)=(LinkDesc="Alien Victory")
	InputLinks(2)=(LinkDesc="Team One Victory")
	InputLinks(3)=(LinkDesc="Team Two Victory")
	InputLinks(4)=(LinkDesc="The Lost Victory")
	InputLinks(5)=(LinkDesc="Resistance Victory")

	OutputLinks.Empty
	VariableLinks.Empty
}
