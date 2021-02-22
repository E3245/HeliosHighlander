class X2Dialogue_DefaultTags extends X2DialogueElements
	config(GameData);

static function array<X2DataTemplate> CreateTemplates()
{
	local array<X2DataTemplate> Templates;
	local array<name> NameList;

	Templates.AddItem(IsUnitUnderStatusEffect('Tag_isConfused', class'X2AbilityTemplateManager'.default.ConfusedName));

	Templates.AddItem(IsUnitLoadoutScreenActive('Tag_isFocusLocker'));

	Templates.AddItem(IsOnXBreach('Tag_1stBreach', 0));
	Templates.AddItem(IsOnXBreach('Tag_2ndBreach', 1));
	Templates.AddItem(IsOnXBreach('Tag_3rdBreach', 2));
	Templates.AddItem(IsOnXBreach('Tag_4thBreach', 3));
	
	Templates.AddItem(IsBreachingRoomIDX('Tag_isRoomID1', 1));
	Templates.AddItem(IsBreachingRoomIDX('Tag_isRoomID2', 2));
	Templates.AddItem(IsBreachingRoomIDX('Tag_isRoomID3', 3));
	Templates.AddItem(IsBreachingRoomIDX('Tag_isRoomID4', 4));
	Templates.AddItem(IsBreachingRoomIDX('Tag_isRoomID5', 5));

	Templates.AddItem(IsOnInvestigationX('Tag_onProgeny', 'Investigation_Progeny'));
	Templates.AddItem(IsOnInvestigationX('Tag_onSacredCoil', 'Investigation_SacredCoil'));
	Templates.AddItem(IsOnInvestigationX('Tag_onGrayPhoenix', 'Investigation_GrayPhoenix'));
	Templates.AddItem(IsOnInvestigationX('Tag_onFinale', 'Investigation_FinaleConspiracy'));

	Templates.AddItem(IsOnInvestigationStageX('Tag_isTier0', eStage_Groundwork));
	Templates.AddItem(IsOnInvestigationStageX('Tag_isTierTD', eStage_Takedown));
	Templates.AddItem(IsOnInvestigationStageX('Tag_compTDCurrentInv', eStage_Completed));

	Templates.AddItem(IsOnInvestigationActX('Tag_on1stInvestigation', 1));
	Templates.AddItem(IsOnInvestigationActX('Tag_on2ndInvestigation', 2));
	Templates.AddItem(IsOnInvestigationActX('Tag_on3rdInvestigation', 3));

	Templates.AddItem(CompletedXInvestigations('Tag_comp1stInvestigation', 1));
	Templates.AddItem(CompletedXInvestigations('Tag_comp2ndInvestigation', 2));
	Templates.AddItem(CompletedXInvestigations('Tag_comp3rdInvestigation', 3));

	Templates.AddItem(IsMissionNameX('Tag_IsMissionDestroyObject', 'DestroyObject'));
	Templates.AddItem(IsMissionNameX('Tag_IsMissionDisableObject', 'DisableObject'));
	Templates.AddItem(IsMissionNameX('Tag_IsMissionPreventActivity', 'PreventActivity'));
	Templates.AddItem(IsMissionNameX('Tag_IsMissionProtectObject', 'ProtectObject'));
	Templates.AddItem(IsMissionNameX('Tag_IsMissionRecoverObject', 'RecoverObject'));
	Templates.AddItem(IsMissionNameX('Tag_IsMissionNeutralizeVIP', 'NeutralizeVIP'));
	Templates.AddItem(IsMissionNameX('Tag_IsMissionRescueVIP', 'RescueVIP'));
	Templates.AddItem(IsMissionNameX('Tag_IsMissionExtractVIP', 'ExtractVIP'));
	Templates.AddItem(IsMissionNameX('Tag_IsMissionHoldGround', 'HoldGround'));
	Templates.AddItem(IsMissionNameX('Tag_IsMissionOutbreak', 'Outbreak'));
	Templates.AddItem(IsMissionNameX('Tag_IsMissionRecoverWeapon', 'RecoverWeapon'));
	Templates.AddItem(IsMissionNameX('Tag_IsMissionStopRobbery', 'StopRobbery'));
	Templates.AddItem(IsMissionNameX('Tag_IsMissionSweep', 'Sweep'));
	Templates.AddItem(IsMissionNameX('Tag_onCityHall', 'FinaleCityHall'));
	Templates.AddItem(IsMissionTierX('Tag_onAtlasAssault', "FinaleConspiracy_")); // using InStr compare here because conspiracy is a multi part mission(a,b,c)

	Templates.AddItem(IsMissionTierX('Tag_onTier1A1', "Tier1A1"));
	Templates.AddItem(IsMissionTierX('Tag_onTier1A2', "Tier1A2"));
	Templates.AddItem(IsMissionTierX('Tag_onTier1A3', "Tier1A3"));
	Templates.AddItem(IsMissionTierX('Tag_onTier1A4', "Tier1A4"));
	Templates.AddItem(IsMissionTierX('Tag_onTier1B1', "Tier1B1"));
	Templates.AddItem(IsMissionTierX('Tag_onTier1B2', "Tier1B2"));
	Templates.AddItem(IsMissionTierX('Tag_onTier1B3', "Tier1B3"));
	Templates.AddItem(IsMissionTierX('Tag_onTier1B4', "Tier1B4"));
	Templates.AddItem(IsMissionTierX('Tag_onTier2A1', "Tier2A1"));
	Templates.AddItem(IsMissionTierX('Tag_onTier2A2', "Tier2A2"));
	Templates.AddItem(IsMissionTierX('Tag_onTier2A3', "Tier2A3"));
	Templates.AddItem(IsMissionTierX('Tag_onTier2A4', "Tier2A4"));
	Templates.AddItem(IsMissionTierX('Tag_onTier2B1', "Tier2B1"));
	Templates.AddItem(IsMissionTierX('Tag_onTier2B2', "Tier2B2"));
	Templates.AddItem(IsMissionTierX('Tag_onTier2B3', "Tier2B3"));
	Templates.AddItem(IsMissionTierX('Tag_onTier2B4', "Tier2B4"));
	Templates.AddItem(IsMissionTierX('Tag_onTier3A1', "Tier3A1"));
	Templates.AddItem(IsMissionTierX('Tag_onTier3A2', "Tier3A2"));
	Templates.AddItem(IsMissionTierX('Tag_onTier3A3', "Tier3A3"));
	Templates.AddItem(IsMissionTierX('Tag_onTier3A4', "Tier3A4"));
	Templates.AddItem(IsMissionTierX('Tag_onTier3B1', "Tier3B1"));
	Templates.AddItem(IsMissionTierX('Tag_onTier3B2', "Tier3B2"));
	Templates.AddItem(IsMissionTierX('Tag_onTier3B3', "Tier3B3"));
	Templates.AddItem(IsMissionTierX('Tag_onTier3B4', "Tier3B4"));

	Templates.AddItem(IsMissionTierX('Tag_onGroundwork', "Groundwork"));
	Templates.AddItem(IsMissionTierX('Tag_onTakedown', "Takedown"));

	Templates.AddItem(IsActiveOperationTierX('Tag_isTier1A', "Tier1A"));
	Templates.AddItem(IsActiveOperationTierX('Tag_isTier1B', "Tier1B"));
	Templates.AddItem(IsActiveOperationTierX('Tag_isTier2A', "Tier2A"));
	Templates.AddItem(IsActiveOperationTierX('Tag_isTier2B', "Tier2B"));
	Templates.AddItem(IsActiveOperationTierX('Tag_isTier3A', "Tier3A"));
	Templates.AddItem(IsActiveOperationTierX('Tag_isTier3B', "Tier3B"));

	Templates.AddItem(IsOperationXCompleted('Tag_compCoil1A', 'InvestigationOp_SCTier1A'));
	Templates.AddItem(IsOperationXCompleted('Tag_compCoil1B', 'InvestigationOp_SCTier1B'));
	Templates.AddItem(IsOperationXCompleted('Tag_compCoil2A', 'InvestigationOp_SCTier2A'));
	Templates.AddItem(IsOperationXCompleted('Tag_compCoil2B', 'InvestigationOp_SCTier2B'));
	Templates.AddItem(IsOperationXCompleted('Tag_compCoil3A', 'InvestigationOp_SCTier3A'));
	Templates.AddItem(IsOperationXCompleted('Tag_compCoil3B', 'InvestigationOp_SCTier3B'));
															  				   
	Templates.AddItem(IsOperationXCompleted('Tag_compGray1A', 'InvestigationOp_GPTier1A'));
	Templates.AddItem(IsOperationXCompleted('Tag_compGray1B', 'InvestigationOp_GPTier1B'));
	Templates.AddItem(IsOperationXCompleted('Tag_compGray2A', 'InvestigationOp_GPTier2A'));
	Templates.AddItem(IsOperationXCompleted('Tag_compGray2B', 'InvestigationOp_GPTier2B'));
	Templates.AddItem(IsOperationXCompleted('Tag_compGray3A', 'InvestigationOp_GPTier3A'));
	Templates.AddItem(IsOperationXCompleted('Tag_compGray3B', 'InvestigationOp_GPTier3B'));
	
	Templates.AddItem(IsOperationXCompleted('Tag_compProg1A', 'InvestigationOp_TPTier1A'));
	Templates.AddItem(IsOperationXCompleted('Tag_compProg1B', 'InvestigationOp_TPTier1B'));
	Templates.AddItem(IsOperationXCompleted('Tag_compProg2A', 'InvestigationOp_TPTier2A'));
	Templates.AddItem(IsOperationXCompleted('Tag_compProg2B', 'InvestigationOp_TPTier2B'));
	Templates.AddItem(IsOperationXCompleted('Tag_compProg3A', 'InvestigationOp_TPTier3A'));
	Templates.AddItem(IsOperationXCompleted('Tag_compProg3B', 'InvestigationOp_TPTier3B'));

	Templates.AddItem(IsOperationXCompleted('Tag_compCityHall', 'InvestigationOp_FinaleCityHall'));


	Templates.AddItem(XOperationsOfTypeYCompletedInCurrentInvestigation('Tag_comp1OpInv', 1, eStage_Operations));
	Templates.AddItem(XOperationsOfTypeYCompletedInCurrentInvestigation('Tag_comp2OpInv', 2, eStage_Operations));
	Templates.AddItem(XOperationsOfTypeYCompletedInCurrentInvestigation('Tag_comp3OpInv', 3, eStage_Operations));

	Templates.AddItem(IsInvestgationStageCompleted('Tag_compCoilGW', 'Investigation_SacredCoil', eStage_Groundwork));
	Templates.AddItem(IsInvestgationStageCompleted('Tag_compGrayGW', 'Investigation_GrayPhoenix', eStage_Groundwork));
	Templates.AddItem(IsInvestgationStageCompleted('Tag_compProgGW', 'Investigation_Progeny', eStage_Groundwork));
	Templates.AddItem(IsInvestgationStageCompleted('Tag_compCoilTD', 'Investigation_SacredCoil', eStage_Takedown));
	Templates.AddItem(IsInvestgationStageCompleted('Tag_compGrayTD', 'Investigation_GrayPhoenix', eStage_Takedown));
	Templates.AddItem(IsInvestgationStageCompleted('Tag_compProgTD', 'Investigation_Progeny', eStage_Takedown));

	Templates.AddItem(IsMissionCategoryX('Tag_isMissionCategory31PD', 'ScheduleSource_City31'));
	Templates.AddItem(IsMissionCategoryX('Tag_isMissionCategoryEmergency', 'ScheduleSource_Emergencies'));
	Templates.AddItem(IsMissionCategoryX('Tag_isMissionCategoryInformant', 'ScheduleSource_Underworld'));
	Templates.AddItem(IsMissionCategoryX('Tag_isMissionCategoryXCOM', 'ScheduleSource_XCOM'));

	Templates.AddItem(IsLeadMission('Tag_onLead'));

	Templates.AddItem(HasTacticalGameplayTag('Tag_onTutorial', class'XComGameStateContext_LaunchTutorialMission'.default.TutorialMissionGamePlayTag));

	Templates.AddItem(IsOnBreachPointTypeX('Tag_isBreachDoor', eBreachPointType_Door));
	Templates.AddItem(IsOnBreachPointTypeX('Tag_isBreachWall', eBreachPointType_eWall));

	Templates.AddItem(IsInTacticalMission());
	Templates.AddItem(IsInStrategyGame());

	Templates.AddItem(XTargetsKilled('Tag_targetKilled', 1, TOP_Equal));
	Templates.AddItem(XTargetsKilled('Tag_targetAlive', 0, TOP_Equal));
	Templates.AddItem(XTargetsKilled('Tag_targetsKilled', 1, TOP_GreaterThan));

	Templates.AddItem(XTargetsHit('Tag_isTargetSingle', 1, TOP_Equal));
	Templates.AddItem(XTargetsHit('Tag_isTargetMultiple', 1, TOP_GreaterThan));

	Templates.AddItem(IsSourceUnitAbilityTarget('Tag_isAbilityTarget'));
	Templates.AddItem(IsHitResultX('Tag_criticalHit', eHit_Crit));

	Templates.AddItem(IsTargetArmored('Tag_targetArmored', true));
	Templates.AddItem(IsTargetArmored('Tag_targetUnarmored', false));

	Templates.AddItem(IsTargetFriendly('Tag_isTargetFriendly'));

	Templates.AddItem(IsUnitCharacterNameX('Tag_IsTargetBlueblood', 'XComGunslinger', false));
	Templates.AddItem(IsUnitCharacterNameX('Tag_IsTargetVerge', 'XComEnvoy', false));
	Templates.AddItem(IsUnitCharacterNameX('Tag_IsTargetTerminal', 'XComMedic', false));
	Templates.AddItem(IsUnitCharacterNameX('Tag_IsTargetAxiom', 'XComBreaker', false));
	Templates.AddItem(IsUnitCharacterNameX('Tag_IsTargetClaymore', 'XComDemoExpert', false));
	Templates.AddItem(IsUnitCharacterNameX('Tag_IsTargetGodmother', 'XComRanger', false));
	Templates.AddItem(IsUnitCharacterNameX('Tag_IsTargetPatchwork', 'XComOperator', false));
	Templates.AddItem(IsUnitCharacterNameX('Tag_IsTargetShelter', 'XComPsion', false));
	Templates.AddItem(IsUnitCharacterNameX('Tag_IsTargetTorque', 'XComInquisitor', false));
	Templates.AddItem(IsUnitCharacterNameX('Tag_IsTargetZephyr', 'XComHellion', false));
	Templates.AddItem(IsUnitCharacterNameX('Tag_IsTargetCherub', 'XcomWarden', false));

	Templates.AddItem(IsPreviousSpeakerCharacterNameX('Tag_fromBlueblood','XComGunslinger'));
	Templates.AddItem(IsPreviousSpeakerCharacterNameX('Tag_fromVerge','XComEnvoy'));
	Templates.AddItem(IsPreviousSpeakerCharacterNameX('Tag_fromTerminal','XComMedic'));
	Templates.AddItem(IsPreviousSpeakerCharacterNameX('Tag_fromAxiom','XComBreaker'));
	Templates.AddItem(IsPreviousSpeakerCharacterNameX('Tag_fromClaymore','XComDemoExpert'));
	Templates.AddItem(IsPreviousSpeakerCharacterNameX('Tag_fromGodmother','XComRanger'));
	Templates.AddItem(IsPreviousSpeakerCharacterNameX('Tag_fromPatchwork','XComOperator'));
	Templates.AddItem(IsPreviousSpeakerCharacterNameX('Tag_fromShelter','XComPsion'));
	Templates.AddItem(IsPreviousSpeakerCharacterNameX('Tag_fromTorque','XComInquisitor'));
	Templates.AddItem(IsPreviousSpeakerCharacterNameX('Tag_fromZephyr','XComHellion'));
	Templates.AddItem(IsPreviousSpeakerCharacterNameX('Tag_fromCherub','XcomWarden'));

	Templates.AddItem(IsUnitFactionX('Tag_isSacredCoil', 'SacredCoil', true));
	Templates.AddItem(IsUnitFactionX('Tag_isShrike', 'Conspiracy', true));
	Templates.AddItem(IsUnitFactionX('Tag_isProgeny', 'Progeny', true));
	Templates.AddItem(IsUnitFactionX('Tag_isGrayPhoenix', 'Gray', true));

	Templates.AddItem(IsUnitFactionX('Tag_isTargetSacredCoil', 'SacredCoil', false));
	Templates.AddItem(IsUnitFactionX('Tag_isTargetShrike', 'Conspiracy', false));
	Templates.AddItem(IsUnitFactionX('Tag_isTargetProgeny', 'Progeny', false));
	Templates.AddItem(IsUnitFactionX('Tag_isTargetGrayPhoenix', 'Gray', false));

	Templates.AddItem(HasUnitBeenOnXMissions('Tag_isVeteran', 15, TOP_GreaterThan));

	NameList.AddItem('XComBreaker');
	NameList.AddItem('XComInquisitor');
	NameList.AddItem('XComEnvoy');
	Templates.AddItem(AreUnitsOnSquad('Tag_squadAlien', NameList, 1));

	NameList.length = 0;
	NameList.AddItem('XComGunslinger');
	NameList.AddItem('XComDemoExpert');
	NameList.AddItem('XComRanger');
	NameList.AddItem('XComOperator');
	NameList.AddItem('XComPsion');
	NameList.AddItem('XComMedic');
	Templates.AddItem(AreUnitsOnSquad('Tag_squadHuman', NameList, 1));

	NameList.length = 0;
	NameList.AddItem('XcomWarden');
	NameList.AddItem('XComHellion');
	Templates.AddItem(AreUnitsOnSquad('Tag_squadHybrid', NameList, 1));

	Templates.AddItem(IsUnitOnSquad('Tag_isSquad', '', /*bCheckSourceUnit*/ true));
	Templates.AddItem(IsUnitOnSquad('Tag_squadBlueblood', 'XComGunslinger'));
	Templates.AddItem(IsUnitOnSquad('Tag_squadVerge', 'XComEnvoy'));
	Templates.AddItem(IsUnitOnSquad('Tag_squadTerminal', 'XComMedic'));
	Templates.AddItem(IsUnitOnSquad('Tag_squadAxiom', 'XComBreaker'));
	Templates.AddItem(IsUnitOnSquad('Tag_squadClaymore', 'XComDemoExpert'));
	Templates.AddItem(IsUnitOnSquad('Tag_squadGodmother', 'XComRanger'));
	Templates.AddItem(IsUnitOnSquad('Tag_squadPatchwork', 'XComOperator'));
	Templates.AddItem(IsUnitOnSquad('Tag_squadShelter', 'XComPsion'));
	Templates.AddItem(IsUnitOnSquad('Tag_squadTorque', 'XComInquisitor'));
	Templates.AddItem(IsUnitOnSquad('Tag_squadZephyr', 'XComHellion'));
	Templates.AddItem(IsUnitOnSquad('Tag_squadCherub', 'XcomWarden'));

	Templates.AddItem(IsUnitAtBase('Tag_atBaseBlueblood', 'XComGunslinger'));
	Templates.AddItem(IsUnitAtBase('Tag_atBaseVerge', 'XComEnvoy'));
	Templates.AddItem(IsUnitAtBase('Tag_atBaseTerminal', 'XComMedic'));
	Templates.AddItem(IsUnitAtBase('Tag_atBaseAxiom', 'XComBreaker'));
	Templates.AddItem(IsUnitAtBase('Tag_atBaseClaymore', 'XComDemoExpert'));
	Templates.AddItem(IsUnitAtBase('Tag_atBaseGodmother', 'XComRanger'));
	Templates.AddItem(IsUnitAtBase('Tag_atBasePatchwork', 'XComOperator'));
	Templates.AddItem(IsUnitAtBase('Tag_atBaseShelter', 'XComPsion'));
	Templates.AddItem(IsUnitAtBase('Tag_atBaseTorque', 'XComInquisitor'));
	Templates.AddItem(IsUnitAtBase('Tag_atBaseZephyr', 'XComHellion'));
	Templates.AddItem(IsUnitAtBase('Tag_atBaseCherub', 'XcomWarden'));
	Templates.AddItem(IsUnitAtBase('Tag_atBaseWhisper', 'Whisper'));

	Templates.AddItem(IsUnitAtBase('Tag_onStrategyMission', '', /*bCheckSourceUnit*/true, /*bFlipCondition*/true));


	Templates.AddItem(IsUnitInitiallySelectedSquadMember('Tag_isNewBlueblood', 'XComGunslinger', true));
	Templates.AddItem(IsUnitInitiallySelectedSquadMember('Tag_isNewVerge', 'XComEnvoy', true));
	Templates.AddItem(IsUnitInitiallySelectedSquadMember('Tag_isNewTerminal', 'XComMedic', true));
	Templates.AddItem(IsUnitInitiallySelectedSquadMember('Tag_isNewAxiom', 'XComBreaker', true));
	Templates.AddItem(IsUnitInitiallySelectedSquadMember('Tag_isNewClaymore', 'XComDemoExpert', true));
	Templates.AddItem(IsUnitInitiallySelectedSquadMember('Tag_isNewGodmother', 'XComRanger', true));
	Templates.AddItem(IsUnitInitiallySelectedSquadMember('Tag_isNewPatchwork', 'XComOperator', true));
	Templates.AddItem(IsUnitInitiallySelectedSquadMember('Tag_isNewShelter', 'XComPsion', true));
	Templates.AddItem(IsUnitInitiallySelectedSquadMember('Tag_isNewTorque', 'XComInquisitor', true));
	Templates.AddItem(IsUnitInitiallySelectedSquadMember('Tag_isNewZephyr', 'XComHellion', true));
	Templates.AddItem(IsUnitInitiallySelectedSquadMember('Tag_isNewCherub', 'XcomWarden', true));

	Templates.AddItem(IsAbilityTargetSelf('Tag_isTargetSelf'));
	Templates.AddItem(IsAbilityTargetSelf('Tag_isTargetNotSelf', true));

	Templates.AddItem(IsAbilityTargetisTargetRobotic('Tag_isTargetRobot'));
	Templates.AddItem(IsAbilityTargetisTargetRobotic('Tag_isTargetOrganic', true));

	Templates.AddItem(IsAbilityTargetisTargetSquadMember('Tag_isTargetSquad'));

	Templates.AddItem(DoesAbilityApplyPresistentEffect('Tag_isStatusRooting', class'X2AbilityTemplateManager'.default.RootedName));
	Templates.AddItem(DoesAbilityApplyEffect('Tag_isStatusDisabling', class'X2Effect_DisableWeapon'.Name));
	Templates.AddItem(DoesAbilityApplyWeaponDamageType('Tag_isStatusRupturing', 'Rupture'));

	Templates.AddItem(IsAbilityItemObjectX('Tag_isFragGrenade', 'FragGrenade'));
	Templates.AddItem(IsAbilityItemObjectX('Tag_isPlasmaGrenade', 'PlasmaGrenade'));
	Templates.AddItem(IsAbilityItemObjectX('Tag_isSmokeGrenade', 'SmokeGrenade'));
	Templates.AddItem(IsAbilityItemObjectX('Tag_isStunGrenade', 'FlashbangGrenade'));

	Templates.AddItem(IsUnitNearHazard('Tag_isNearFire', class'X2Effect_ApplyFireToWorld'.Name ));
	Templates.AddItem(IsUnitNearExplosives('Tag_isNearExplosion'));

	Templates.AddItem(IsUnitScarred('Tag_isScarred'));
	Templates.AddItem(XUnitScarred('Tag_isNoUnitScarred', 0, TOP_Equal));
	Templates.AddItem(XUnitScarred('Tag_isAnyUnitScarred', 0, TOP_GreaterThan));

	Templates.AddItem(IsInUIScreenX('Tag_stratMain', class'UIDIOStrategy'.Name));
	Templates.AddItem(IsInUIScreenX('Tag_stratArmory', class'UIArmory_MainMenu'.Name));
	Templates.AddItem(IsInUIScreenX('Tag_stratSquadSelect', class'UIDIOSquadSelect'.Name));
	Templates.AddItem(IsInUIScreenX('Tag_stratMapTable', class'UIDIOStrategyMapFlash'.Name));
	Templates.AddItem(IsInUIScreenX('Tag_inPhotobooth', class'UITactical_Photobooth'.Name));
	Templates.AddItem(IsInUIScreenX('Tag_stratTraining', class'UIDIOTrainingScreen'.Name));
	Templates.AddItem(IsInUIScreenX('Tag_stratSupply', class'UIBlackMarket_Buy'.Name));
	Templates.AddItem(IsInUIScreenX('Tag_stratAssembly', class'UIDIOAssemblyScreen'.Name));
	Templates.AddItem(IsInUIScreenX('Tag_stratInvestigations', class'UIDebriefScreen'.Name));
	Templates.AddItem(IsInUIScreenX('Tag_stratScavenger', class'UIScavengerMarket'.Name));
	Templates.AddItem(IsInUIScreenX('Tag_stratMissionBriefing', class'UIDIOWorkerReviewScreen'.Name));

	Templates.AddItem(IsDamageResultValueOfTypeGreaterThanX('Tag_targetShredded', 'Shred'));

	Templates.AddItem(HasConversationEnded('Tag_convEnded', '', /*bCheckSourceRule*/true));
	Templates.AddItem(HasConversationEnded('Tag_convNotEnded', '', /*bCheckSourceRule*/true, true));

	Templates.AddItem(HasConversationEnded('Tag_convEndedCoil1A1Mission1Breach2Chryssalids2', 'Coil1A1Mission1Breach2Chryssalids2'));
	Templates.AddItem(HasConversationEnded('Tag_convEndedCore0bReturn01startNoTutorial', 'Core0bReturn01startNoTutorial'));
	Templates.AddItem(HasConversationEnded('Tag_convEndedCore0bReturn01startTutorial', 'Core0bReturn01startTutorial'));
	Templates.AddItem(HasConversationEnded('Tag_convEndedCore1iSupply1start', 'Core1iSupply1start'));
	Templates.AddItem(HasConversationEnded('Tag_convEndedCore3bConspiracy1start', 'Core3bConspiracy1start'));
	Templates.AddItem(HasConversationEnded('Tag_convEndedRadioAdBurgerPalace1Intro1start', 'RadioAdBurgerPalace1Intro1start'));
	Templates.AddItem(HasConversationEnded('Tag_convEndedRadioAdBurgerPalace2Process1start', 'RadioAdBurgerPalace2Process1start'));
	Templates.AddItem(HasConversationEnded('Tag_convEndedRadioAdBurgerPalace3Compattibility1start', 'RadioAdBurgerPalace3Compattibility1start'));
	Templates.AddItem(HasConversationEnded('Tag_convEndedRadioShowCoil1Intro01start', 'RadioShowCoil1Intro01start'));
	Templates.AddItem(HasConversationEnded('Tag_convEndedRadioShowCoil2Words01start', 'RadioShowCoil2Words01start'));
	Templates.AddItem(HasConversationEnded('Tag_convEndedRadioShowConspiracy1Intro01start', 'RadioShowConspiracy1Intro01start'));
	Templates.AddItem(HasConversationEnded('Tag_convEndedRadioShowConspiracy2BondedStair01start', 'RadioShowConspiracy2BondedStair01start'));
	Templates.AddItem(HasConversationEnded('Tag_convEndedRadioShowConspiracy3Friend01start', 'RadioShowConspiracy3Friend01start'));
	Templates.AddItem(HasConversationEnded('Tag_convEndedRadioShowLocalNewsCoil1Intro01start', 'RadioShowLocalNewsCoil1Intro01start'));
	Templates.AddItem(HasConversationEnded('Tag_convEndedRadioShowLocalNewsCoil2Bonded01start', 'RadioShowLocalNewsCoil2Bonded01start'));
	Templates.AddItem(HasConversationEnded('Tag_convEndedRadioShowLocalNewsCoil3Protest01start', 'RadioShowLocalNewsCoil3Protest01start'));
	Templates.AddItem(HasConversationEnded('Tag_convEndedRadioShowLocalNewsGray1Intro01start', 'RadioShowLocalNewsGray1Intro01start'));
	Templates.AddItem(HasConversationEnded('Tag_convEndedRadioShowLocalNewsGray2Protests01start', 'RadioShowLocalNewsGray2Protests01start'));
	Templates.AddItem(HasConversationEnded('Tag_convEndedRadioShowLocalNewsGray3Clash01start', 'RadioShowLocalNewsGray3Clash01start'));
	Templates.AddItem(HasConversationEnded('Tag_convEndedRadioShowLocalNewsMayorsDeath1Intro1start', 'RadioShowLocalNewsMayorsDeath1Intro1start'));
	Templates.AddItem(HasConversationEnded('Tag_convEndedRadioShowLocalNewsMayorsDeath2Vigils1start', 'RadioShowLocalNewsMayorsDeath2Vigils1start'));
	Templates.AddItem(HasConversationEnded('Tag_convEndedRadioShowLocalNewsMayorsDeath3Deputy01start', 'RadioShowLocalNewsMayorsDeath3Deputy01start'));
	Templates.AddItem(HasConversationEnded('Tag_convEndedRadioShowLocalNewsProg1Intro01start', 'RadioShowLocalNewsProg1Intro01start'));
	Templates.AddItem(HasConversationEnded('Tag_convEndedRadioShowLocalNewsProg2Rights01start', 'RadioShowLocalNewsProg2Rights01start'));
	Templates.AddItem(HasConversationEnded('Tag_convEndedRadioShowLocalNewsProg3Disappear01start', 'RadioShowLocalNewsProg3Disappear01start'));
	Templates.AddItem(HasConversationEnded('Tag_convEndedRadioShowYouSayISay01Mayor01start', 'RadioShowYouSayISay01Mayor01start'));
	Templates.AddItem(HasConversationEnded('Tag_convEndedTalkAxiomGod1Awkward01start', 'TalkAxiomGod1Awkward01start'));
	Templates.AddItem(HasConversationEnded('Tag_convEndedTalkAxiomGod2Awkward01start', 'TalkAxiomGod2Awkward01start'));
	Templates.AddItem(HasConversationEnded('Tag_convEndedTalkAxiomGod3Awkward01start', 'TalkAxiomGod3Awkward01start'));
	Templates.AddItem(HasConversationEnded('Tag_convEndedTalkZephyrTerm1Accent01start', 'TalkZephyrTerm1Accent01start'));
	Templates.AddItem(OncePerDay());

	Templates.AddItem(CheckAmmoCountEqual('Tag_ammoOut', 0));
	Templates.AddItem(CheckAmmoCountGreaterThan('Tag_ammoLow', 2, /*bFlipCondition*/true));

	// Strategy-side tutorial checks
	Templates.AddItem(TutorialEnabled('Tag_isTutorialEnabled'));
	Templates.AddItem(TutorialEnabled('Tag_isTutorialDisabled', true));
	Templates.AddItem(BeginnerVOEnabled());

	Templates.AddItem(IsMovementDistanceGreaterThanX('Tag_minMove', 2));

	Templates.AddItem(IsResearchCompleted('Tag_isAndroidResearched', 'DioResearch_AndroidUnits'));

	Templates.AddItem(OwnXAndroids('Tag_isAndroidSlotOpen', 2, TOP_LessThan));

	Templates.AddItem(CanAffordAndroid('Tag_isAndroidAffordable'));


	// Temp tags
	Templates.AddItem(DummyTagTemplate('Tag_TEMPtag'));

	return Templates;
}

static function X2DataTemplate DummyTagTemplate(name TemplateName)
{
	local X2DialogueTagTemplate Template;

	`CREATE_X2TEMPLATE(class'X2DialogueTagTemplate', Template, TemplateName);
	
	Template.IsConditionMetFn = class'X2DialogueTagTemplate'.static.AlwaysTrue;

	return Template;
}

static function X2DataTemplate IsSourceUnitSoldierClassX(name TemplateName, name SoldierClassName)
{
	local X2DialogueTagTemplate Template;

	`CREATE_X2TEMPLATE(class'X2DialogueTagTemplate', Template, TemplateName);

	Template.IsConditionMetFn = class'X2DialogueTagTemplate'.static.CheckEventSourceSoldierClassName;
	Template.NameValue = SoldierClassName;

	return Template;
}

static function X2DataTemplate IsUnitCharacterNameX(name TemplateName, name CharacterName, bool bCheckSourceUnit)
{
	local X2DialogueTagTemplate Template;

	`CREATE_X2TEMPLATE(class'X2DialogueTagTemplate', Template, TemplateName);

	Template.IsConditionMetFn = class'X2DialogueTagTemplate'.static.CheckCharacterTemplateName;
	Template.NameValue = CharacterName;
	Template.bCheckSourceUnit = bCheckSourceUnit;

	return Template;
}

static function X2DataTemplate IsUnitInitiallySelectedSquadMember(name TemplateName, name CharacterName, bool bFlipCondition = false)
{
	local X2DialogueTagTemplate Template;

	`CREATE_X2TEMPLATE(class'X2DialogueTagTemplate', Template, TemplateName);
	Template.IsConditionMetFn = class'X2DialogueTagTemplate'.static.CheckCharacterIsInitiallySelectedSquadMember;
	Template.NameValue = CharacterName;
	Template.bFlipCondition = bFlipCondition;

	return Template;
}

static function X2DataTemplate IsUnitVoiceIDX(name TemplateName, name VoiceID, bool bCheckSourceUnit)
{
	local X2DialogueTagTemplate Template;

	`CREATE_X2TEMPLATE(class'X2DialogueTagTemplate', Template, TemplateName);

	Template.IsConditionMetFn = class'X2DialogueTagTemplate'.static.CheckCharacterVoiceID;
	Template.NameValue = VoiceID;
	Template.bCheckSourceUnit = bCheckSourceUnit;

	return Template;
}

static function X2DataTemplate IsMissionNameX(name TemplateName, name MissionName)
{
	local X2DialogueTagTemplate Template;

	`CREATE_X2TEMPLATE(class'X2DialogueTagTemplate', Template, TemplateName);

	Template.IsConditionMetFn = class'X2DialogueTagTemplate'.static.CheckMissionName;
	Template.NameValue = MissionName;

	return Template;
}

static function X2DataTemplate IsMissionTierX(name TemplateName, string Tier)
{
	local X2DialogueTagTemplate Template;

	`CREATE_X2TEMPLATE(class'X2DialogueTagTemplate', Template, TemplateName);

	Template.IsConditionMetFn = class'X2DialogueTagTemplate'.static.CheckMissionTier;
	Template.StringValue = Tier;

	return Template;
}

static function X2DataTemplate IsMissionCategoryX(name TemplateName, name MissionCategory)
{
	local X2DialogueTagTemplate Template;

	`CREATE_X2TEMPLATE(class'X2DialogueTagTemplate', Template, TemplateName);

	Template.IsConditionMetFn = class'X2DialogueTagTemplate'.static.CheckMissionCategory;
	Template.NameValue = MissionCategory;

	return Template;
}

static function X2DataTemplate IsInTacticalMission()
{
	local X2DialogueTagTemplate Template;

	`CREATE_X2TEMPLATE(class'X2DialogueTagTemplate', Template, 'Tag_onTacticalMission');

	Template.IsConditionMetFn = class'X2DialogueTagTemplate'.static.CheckIsOnTacticalMission;

	return Template;
}

static function X2DataTemplate IsInStrategyGame()
{
	local X2DialogueTagTemplate Template;

	`CREATE_X2TEMPLATE(class'X2DialogueTagTemplate', Template, 'Tag_atBase');

	Template.IsConditionMetFn = class'X2DialogueTagTemplate'.static.CheckIsInStrategyGame;

	return Template;
}

static function X2DataTemplate IsUnitAtBase(name TemplateName, name CharName, optional bool bCheckSourceUnit, optional bool bFlipCondition)
{
	local X2DialogueTagTemplate Template;

	`CREATE_X2TEMPLATE(class'X2DialogueTagTemplate', Template, TemplateName);

	Template.IsConditionMetFn = class'X2DialogueTagTemplate'.static.CheckUnitIsAtBase;
	Template.NameValue = CharName;
	Template.bCheckSourceUnit = bCheckSourceUnit;
	Template.bFlipCondition = bFlipCondition;

	return Template;
}

static function X2DataTemplate IsOnInvestigationX(name TemplateName, name InvestigationName)
{
	local X2DialogueTagTemplate Template;

	`CREATE_X2TEMPLATE(class'X2DialogueTagTemplate', Template, TemplateName);

	Template.IsConditionMetFn = class'X2DialogueTagTemplate'.static.CheckIsOnInvestigation;
	Template.NameValue = InvestigationName;

	return Template;
}

static function X2DataTemplate IsOnXBreach(name TemplateName, int BreachIndex)
{
	local X2DialogueTagTemplate Template;

	`CREATE_X2TEMPLATE(class'X2DialogueTagTemplate', Template, TemplateName);

	Template.IsConditionMetFn = class'X2DialogueTagTemplate'.static.CheckIsOnXBreach;
	Template.IntValue = BreachIndex;

	return Template;
}

static function X2DataTemplate IsBreachingRoomIDX(name TemplateName, int RoomID)
{
	local X2DialogueTagTemplate Template;

	`CREATE_X2TEMPLATE(class'X2DialogueTagTemplate', Template, TemplateName);

	Template.IsConditionMetFn = class'X2DialogueTagTemplate'.static.CheckIsBreachingRoomX;
	Template.IntValue = RoomID;

	return Template;
}

static function X2DataTemplate IsOnInvestigationStageX(name TemplateName, int InvestigationStage)
{
	local X2DialogueTagTemplate Template;

	`CREATE_X2TEMPLATE(class'X2DialogueTagTemplate', Template, TemplateName);

	Template.IsConditionMetFn = class'X2DialogueTagTemplate'.static.CheckIsOnInvestigationStage;
	Template.IntValue = InvestigationStage;

	return Template;
}

static function X2DataTemplate IsOnInvestigationActX(name TemplateName, int Act)
{
	local X2DialogueTagTemplate Template;

	`CREATE_X2TEMPLATE(class'X2DialogueTagTemplate', Template, TemplateName);

	Template.IsConditionMetFn = class'X2DialogueTagTemplate'.static.CheckIsOnInvestigationAct;
	Template.IntValue = Act;

	return Template;
}

static function X2DataTemplate CompletedXInvestigations(name TemplateName, int CompletedCount, EDialogTagEvalOpCode CompareOp = TOP_Equal)
{
	local X2DialogueTagTemplate Template;

	`CREATE_X2TEMPLATE(class'X2DialogueTagTemplate', Template, TemplateName);

	Template.IsConditionMetFn = class'X2DialogueTagTemplate'.static.CheckCompletedInvestigationCount;
	Template.IntValue = CompletedCount;
	Template.CompareOp = CompareOp;

	return Template;
}

static function X2DataTemplate IsOnBreachPointTypeX(name TemplateName, EBreachPointType Type)
{
	local X2DialogueTagTemplate Template;

	`CREATE_X2TEMPLATE(class'X2DialogueTagTemplate', Template, TemplateName);

	Template.IsConditionMetFn = class'X2DialogueTagTemplate'.static.CheckIsOnBreachPointTypeX;
	Template.IntValue = Type;

	return Template;
}

static function X2DataTemplate XTargetsKilled(name TemplateName, int KillCount, EDialogTagEvalOpCode CompareOp)
{
	local X2DialogueTagTemplate Template;

	`CREATE_X2TEMPLATE(class'X2DialogueTagTemplate', Template, TemplateName);

	Template.IsConditionMetFn = class'X2DialogueTagTemplate'.static.CheckKilledTargetCount;
	Template.IntValue = KillCount;
	Template.CompareOp = CompareOp;

	return Template;
}

static function X2DataTemplate XTargetsHit(name TemplateName, int TargetCount, EDialogTagEvalOpCode CompareOp)
{
	local X2DialogueTagTemplate Template;

	`CREATE_X2TEMPLATE(class'X2DialogueTagTemplate', Template, TemplateName);

	Template.IsConditionMetFn = class'X2DialogueTagTemplate'.static.CheckMultiTargetCount;
	Template.IntValue = TargetCount;
	Template.CompareOp = CompareOp;

	return Template;
}

static function X2DataTemplate IsHitResultX(name TemplateName, EAbilityHitResult HitResult)
{
	local X2DialogueTagTemplate Template;

	`CREATE_X2TEMPLATE(class'X2DialogueTagTemplate', Template, TemplateName);

	Template.IsConditionMetFn = class'X2DialogueTagTemplate'.static.CheckHitResult;
	Template.IntValue = HitResult;

	return Template;
}

static function X2DataTemplate IsAbilityItemObjectX(name TemplateName, name ItemTemplateName, optional bool bFlipCondition = false)
{
	local X2DialogueTagTemplate Template;

	`CREATE_X2TEMPLATE(class'X2DialogueTagTemplate', Template, TemplateName);

	Template.IsConditionMetFn = class'X2DialogueTagTemplate'.static.CheckAbilityItemObjectTemplate;
	Template.NameValue = ItemTemplateName;

	return Template;
}

static function X2DataTemplate IsSourceUnitAbilityTarget(name TemplateName, bool bIsTarget = true)
{
	local X2DialogueTagTemplate Template;

	`CREATE_X2TEMPLATE(class'X2DialogueTagTemplate', Template, TemplateName);

	Template.IsConditionMetFn = class'X2DialogueTagTemplate'.static.CheckEventSourceIsAbilityTarget;
	Template.BoolValue = bIsTarget;

	return Template;
}

static function X2DataTemplate HasTacticalGameplayTag(name TemplateName, name RequiredGameplayTag)
{
	local X2DialogueTagTemplate Template;

	`CREATE_X2TEMPLATE(class'X2DialogueTagTemplate', Template, TemplateName);

	Template.IsConditionMetFn = class'X2DialogueTagTemplate'.static.CheckHasGameplayTag;
	Template.NameValue = RequiredGameplayTag;

	return Template;
}

static function X2DataTemplate IsTargetArmored(name TemplateName, bool bHasArmor)
{
	local X2DialogueTagTemplate Template;

	`CREATE_X2TEMPLATE(class'X2DialogueTagTemplate', Template, TemplateName);

	Template.IsConditionMetFn = class'X2DialogueTagTemplate'.static.CheckIsTargetArmored;
	Template.BoolValue = bHasArmor;

	return Template;
}

static function X2DataTemplate IsTargetFriendly(name TemplateName)
{
	local X2DialogueTagTemplate Template;

	`CREATE_X2TEMPLATE(class'X2DialogueTagTemplate', Template, TemplateName);
	Template.IsConditionMetFn = class'X2DialogueTagTemplate'.static.CheckIsTargetFriendly;

	return Template;
}

static function X2DataTemplate IsPreviousSpeakerCharacterNameX(name TemplateName, name CharName)
{
	local X2DialogueTagTemplate Template;

	`CREATE_X2TEMPLATE(class'X2DialogueTagTemplate', Template, TemplateName);

	Template.IsConditionMetFn = class'X2DialogueTagTemplate'.static.CheckPreviousSpeakersCharacterName;
	Template.NameValue = CharName;

	return Template;
}

static function X2DataTemplate IsUnitFactionX(name TemplateName, name FactionName, bool bCheckSourceUnit)
{
	local X2DialogueTagTemplate Template;

	`CREATE_X2TEMPLATE(class'X2DialogueTagTemplate', Template, TemplateName);

	Template.IsConditionMetFn = class'X2DialogueTagTemplate'.static.CheckSpeakerFactionName;
	Template.NameValue = FactionName;
	Template.bCheckSourceUnit = bCheckSourceUnit;

	return Template;
}

static function X2DataTemplate IsUnitOnSquad(name TemplateName, name CharacterName, optional bool bCheckSourceUnit)
{
	local X2DialogueTagTemplate Template;

	`CREATE_X2TEMPLATE(class'X2DialogueTagTemplate', Template, TemplateName);

	Template.IsConditionMetFn = class'X2DialogueTagTemplate'.static.CheckUnitOnSquad;
	Template.NameValue = CharacterName;
	Template.bCheckSourceUnit = bCheckSourceUnit;

	return Template;
}

static function X2DataTemplate AreUnitsOnSquad(name TemplateName, const out array<name> CharNames, int MinRequiredMemberCount = 1)
{
	local X2DialogueTagTemplate Template;

	`CREATE_X2TEMPLATE(class'X2DialogueTagTemplate', Template, TemplateName);

	Template.IsConditionMetFn = class'X2DialogueTagTemplate'.static.CheckUnitsOnSquad;
	Template.IntValue = MinRequiredMemberCount;
	Template.NameArrayValue = CharNames;

	return Template;
}

static function X2DataTemplate IsAbilityTargetStyleX(name TemplateName, name TargetStyleClassName, optional bool bFlipCondition = false)
{
	local X2DialogueTagTemplate Template;

	`CREATE_X2TEMPLATE(class'X2DialogueTagTemplate', Template, TemplateName);

	Template.IsConditionMetFn = class'X2DialogueTagTemplate'.static.CheckAbilityTargetStyle;
	Template.NameValue = TargetStyleClassName;
	Template.bFlipCondition = bFlipCondition;

	return Template;
}

static function X2DataTemplate IsAbilityTargetSelf(name TemplateName, optional bool bFlipCondition = false)
{
	local X2DialogueTagTemplate Template;

	`CREATE_X2TEMPLATE(class'X2DialogueTagTemplate', Template, TemplateName);

	Template.IsConditionMetFn = class'X2DialogueTagTemplate'.static.CheckAbilityTargetSelf;
	Template.bFlipCondition = bFlipCondition;

	return Template;
}

static function X2DataTemplate IsAbilityMultiTargetStyleX(name TemplateName, name TargetStyleClassName, optional bool bFlipCondition = false)
{
	local X2DialogueTagTemplate Template;

	`CREATE_X2TEMPLATE(class'X2DialogueTagTemplate', Template, TemplateName);

	Template.IsConditionMetFn = class'X2DialogueTagTemplate'.static.CheckAbilityMultiTargetStyle;
	Template.NameValue = TargetStyleClassName;
	Template.bFlipCondition = bFlipCondition;

	return Template;
}

static function X2DataTemplate IsAbilityTargetisTargetRobotic(name TemplateName, optional bool bFlipCondition = false)
{
	local X2DialogueTagTemplate Template;

	`CREATE_X2TEMPLATE(class'X2DialogueTagTemplate', Template, TemplateName);
	Template.IsConditionMetFn = class'X2DialogueTagTemplate'.static.CheckIsAbilityTargetRobotic;
	Template.bFlipCondition = bFlipCondition;

	return Template;
}

static function X2DataTemplate IsAbilityTargetisTargetSquadMember(name TemplateName, optional bool bFlipCondition = false)
{
	local X2DialogueTagTemplate Template;

	`CREATE_X2TEMPLATE(class'X2DialogueTagTemplate', Template, TemplateName);
	Template.IsConditionMetFn = class'X2DialogueTagTemplate'.static.CheckIsAbilityTargetSquadMember;
	Template.bFlipCondition = bFlipCondition;

	return Template;
}

static function X2DataTemplate DoesAbilityApplyPresistentEffect(name TemplateName, name EffectName, optional bool bFlipCondition = false)
{
	local X2DialogueTagTemplate Template;

	`CREATE_X2TEMPLATE(class'X2DialogueTagTemplate', Template, TemplateName);
	Template.IsConditionMetFn = class'X2DialogueTagTemplate'.static.CheckAbilityTargetEffects;
	Template.bFlipCondition = bFlipCondition;
	Template.NameValue = EffectName;

	return Template;
}

static function X2DataTemplate DoesAbilityApplyEffect(name TemplateName, name EffectClassName, optional bool bFlipCondition = false)
{
	local X2DialogueTagTemplate Template;

	`CREATE_X2TEMPLATE(class'X2DialogueTagTemplate', Template, TemplateName);
	Template.IsConditionMetFn = class'X2DialogueTagTemplate'.static.CheckAbilityTargetEffects;
	Template.bFlipCondition = bFlipCondition;
	Template.NameValue = EffectClassName;

	return Template;
}

static function X2DataTemplate DoesAbilityApplyWeaponDamageType(name TemplateName, name DamageValueTypeName, optional bool bFlipCondition = false)
{
	local X2DialogueTagTemplate Template;

	`CREATE_X2TEMPLATE(class'X2DialogueTagTemplate', Template, TemplateName);
	Template.IsConditionMetFn = class'X2DialogueTagTemplate'.static.CheckAbilityWeaponDamageValue;
	Template.NameValue = DamageValueTypeName;
	Template.bFlipCondition = bFlipCondition;

	return Template;
}

static function X2DataTemplate IsUnitNearHazard(name TemplateName, name HazardEffectName)
{
	local X2DialogueTagTemplate Template;

	`CREATE_X2TEMPLATE(class'X2DialogueTagTemplate', Template, TemplateName);

	Template.IsConditionMetFn = class'X2DialogueTagTemplate'.static.CheckUnitIsNearHazardTiles;
	Template.NameValue = HazardEffectName;

	return Template;
}

static function X2DataTemplate IsUnitNearExplosives(name TemplateName)
{
	local X2DialogueTagTemplate Template;

	`CREATE_X2TEMPLATE(class'X2DialogueTagTemplate', Template, TemplateName);

	Template.IsConditionMetFn = class'X2DialogueTagTemplate'.static.CheckUnitIsNearExplosives;

	return Template;
}


static function X2DataTemplate IsInUIScreenX(name TemplateName, name ScreenClassName)
{
	local X2DialogueTagTemplate Template;

	`CREATE_X2TEMPLATE(class'X2DialogueTagTemplate', Template, TemplateName);

	Template.IsConditionMetFn = class'X2DialogueTagTemplate'.static.CheckCurrentUIScreen;
	Template.NameValue = ScreenClassName;

	return Template;
}

static function X2DataTemplate IsDamageResultValueOfTypeGreaterThanX(name TemplateName, name DamageValueTypeName, int MinValueRequred = 1)
{
	local X2DialogueTagTemplate Template;

	`CREATE_X2TEMPLATE(class'X2DialogueTagTemplate', Template, TemplateName);

	Template.IsConditionMetFn = class'X2DialogueTagTemplate'.static.CheckDamageResultValueOfTypeGreaterThanX;
	Template.NameValue = DamageValueTypeName;
	Template.IntValue = MinValueRequred;

	return Template;
}

static function X2DataTemplate HasConversationEnded(name TemplateName, name RuleName, optional bool bCheckSourceRule, optional bool bFlipCondition)
{
	local X2DialogueTagTemplate Template;

	`CREATE_X2TEMPLATE(class'X2DialogueTagTemplate', Template, TemplateName);

	Template.IsConditionMetFn = class'X2DialogueTagTemplate'.static.CheckHasConversationEnded;
	Template.bFlipCondition = bFlipCondition;
	Template.bCheckSourceUnit = bCheckSourceRule;
	Template.NameValue = RuleName;

	return Template;
}

static function X2DataTemplate CheckAmmoCountGreaterThan(name TemplateName, int Count, optional bool bFlipCondition)
{
	local X2DialogueTagTemplate Template;

	`CREATE_X2TEMPLATE(class'X2DialogueTagTemplate', Template, TemplateName);

	Template.IsConditionMetFn = class'X2DialogueTagTemplate'.static.CheckUnitAmmoCountGreaterThan;
	Template.IntValue = Count;
	Template.bFlipCondition = bFlipCondition;

	return Template;
}

static function X2DataTemplate CheckAmmoCountEqual(name TemplateName, int Count)
{
	local X2DialogueTagTemplate Template;

	`CREATE_X2TEMPLATE(class'X2DialogueTagTemplate', Template, TemplateName);

	Template.IsConditionMetFn = class'X2DialogueTagTemplate'.static.CheckUnitAmmoCountEquals;
	Template.IntValue = Count;

	return Template;
}

static function X2DataTemplate IsUnitUnderStatusEffect(name TemplateName, name EffectName)
{
	local X2DialogueTagTemplate Template;

	`CREATE_X2TEMPLATE(class'X2DialogueTagTemplate', Template, TemplateName);

	Template.IsConditionMetFn = class'X2DialogueTagTemplate'.static.CheckUnitStatusEffect;
	Template.NameValue = EffectName;

	return Template;
}

static function X2DataTemplate IsLeadMission(name TemplateName)
{
	local X2DialogueTagTemplate Template;

	`CREATE_X2TEMPLATE(class'X2DialogueTagTemplate', Template, TemplateName);

	Template.IsConditionMetFn = class'X2DialogueTagTemplate'.static.CheckIsLeadMission;

	return Template;
}

// Strategy-layer only: conversation only allowed once per campaign day
static function X2DataTemplate OncePerDay()
{
	local X2DialogueTagTemplate Template;

	`CREATE_X2TEMPLATE(class'X2DialogueTagTemplate', Template, 'Tag_OncePerDay');
	Template.IsConditionMetFn = class'X2DialogueTagTemplate'.static.CheckOncePerDay;

	return Template;
}

static function X2DataTemplate IsMovementDistanceGreaterThanX(name TemplateName, int TileDistance)
{
	local X2DialogueTagTemplate Template;

	`CREATE_X2TEMPLATE(class'X2DialogueTagTemplate', Template, TemplateName);
	Template.IsConditionMetFn = class'X2DialogueTagTemplate'.static.CheckMovementDistance;
	Template.IntValue = TileDistance;

	return Template;
}

// Strategy-layer only: valid if the tutorial is enabled
static function X2DataTemplate TutorialEnabled(name TemplateName, optional bool bFlipCondition=false)
{
	local X2DialogueTagTemplate Template;

	`CREATE_X2TEMPLATE(class'X2DialogueTagTemplate', Template, TemplateName);
	Template.IsConditionMetFn = class'X2DialogueTagTemplate'.static.CheckTutorialEnabled;
	Template.bFlipCondition = bFlipCondition;

	return Template;
}

// Strategy-layer only: valid if the player has *not* yet completed the tutorial for this concept
static function X2DataTemplate ReadyForTutorial(name TemplateName, name TutorialConceptName, optional bool bFlipCondition=false)
{
	local X2DialogueTagTemplate Template;

	`CREATE_X2TEMPLATE(class'X2DialogueTagTemplate', Template, TemplateName);
	Template.IsConditionMetFn = class'X2DialogueTagTemplate'.static.CheckReadyForTutorial;
	Template.NameValue = TutorialConceptName;
	Template.bFlipCondition = bFlipCondition;

	return Template;
}
static function X2DataTemplate IsOperationActive(name TemplateName, name OpName)
{
	local X2DialogueTagTemplate Template;

	`CREATE_X2TEMPLATE(class'X2DialogueTagTemplate', Template, TemplateName);
	Template.IsConditionMetFn = class'X2DialogueTagTemplate'.static.CheckIsOperationActive;
	Template.NameValue = OpName;

	return Template;
}

static function X2DataTemplate IsActiveOperationTierX(name TemplateName, string TierString)
{
	local X2DialogueTagTemplate Template;

	`CREATE_X2TEMPLATE(class'X2DialogueTagTemplate', Template, TemplateName);
	Template.IsConditionMetFn = class'X2DialogueTagTemplate'.static.CheckActiveOperationTier;
	Template.StringValue = TierString;

	return Template;
}

static function X2DataTemplate IsOperationXCompleted(name TemplateName, name OpName)
{
	local X2DialogueTagTemplate Template;

	`CREATE_X2TEMPLATE(class'X2DialogueTagTemplate', Template, TemplateName);
	Template.IsConditionMetFn = class'X2DialogueTagTemplate'.static.CheckIsOperationCompleted;
	Template.NameValue = OpName;

	return Template;
}

static function X2DataTemplate IsInvestgationStageCompleted(name TemplateName, name InvestigationName, EInvestigationStage Stage)
{
	local X2DialogueTagTemplate Template;

	`CREATE_X2TEMPLATE(class'X2DialogueTagTemplate', Template, TemplateName);
	Template.IsConditionMetFn = class'X2DialogueTagTemplate'.static.CheckStageCompletedForInvestigation;
	Template.NameValue = InvestigationName;
	Template.IntValue = Stage;
	return Template;
}

static function X2DataTemplate XOperationsOfTypeYCompletedInCurrentInvestigation(name TemplateName, int CompletedOpCount, EInvestigationStage InvestigationStage)
{
	local X2DialogueTagTemplate Template;

	`CREATE_X2TEMPLATE(class'X2DialogueTagTemplate', Template, TemplateName);
	Template.IsConditionMetFn = class'X2DialogueTagTemplate'.static.CheckCompletedOperationCountInCurrentInvestigation;
	Template.IntValue = CompletedOpCount;
	Template.EnumValue = InvestigationStage;

	return Template;
}

static function X2DataTemplate DoesUnitHavePromotion(name TemplateName)
{
	local X2DialogueTagTemplate Template;

	`CREATE_X2TEMPLATE(class'X2DialogueTagTemplate', Template, TemplateName);

	Template.IsConditionMetFn = class'X2DialogueTagTemplate'.static.CheckUnitHasPromotion;

	return Template;
}

static function X2DataTemplate BeginnerVOEnabled()
{
	local X2DialogueTagTemplate Template;

	`CREATE_X2TEMPLATE(class'X2DialogueTagTemplate', Template, 'Tag_verboseMode');

	Template.IsConditionMetFn = class'X2DialogueTagTemplate'.static.CheckBeginnerVOEnabled;

	return Template;
}

static function X2DataTemplate IsUnitScarred(name TemplateName)
{
	local X2DialogueTagTemplate Template;

	`CREATE_X2TEMPLATE(class'X2DialogueTagTemplate', Template, TemplateName);

	Template.IsConditionMetFn = class'X2DialogueTagTemplate'.static.CheckUnitScars;

	return Template;
}

static function X2DataTemplate XUnitScarred(name TemplateName, int UnitCount, EDialogTagEvalOpCode CompareOp)
{
	local X2DialogueTagTemplate Template;

	`CREATE_X2TEMPLATE(class'X2DialogueTagTemplate', Template, TemplateName);

	Template.IsConditionMetFn = class'X2DialogueTagTemplate'.static.CheckScarredSquadMembers;
	Template.IntValue = UnitCount;
	Template.CompareOp = CompareOp;

	return Template;
}


static function X2DataTemplate HasUnitBeenOnXMissions(name TemplateName, int MissionCount, EDialogTagEvalOpCode CompareOp)
{
	local X2DialogueTagTemplate Template;

	`CREATE_X2TEMPLATE(class'X2DialogueTagTemplate', Template, TemplateName);

	Template.IsConditionMetFn = class'X2DialogueTagTemplate'.static.CheckUnitMissionCount;
	Template.IntValue = MissionCount;
	Template.CompareOp = CompareOp;

	return Template;
}

static function X2DataTemplate IsUnitLoadoutScreenActive(name TemplateName, bool bCheckSourceUnit = true)
{
	local X2DialogueTagTemplate Template;

	`CREATE_X2TEMPLATE(class'X2DialogueTagTemplate', Template, TemplateName);

	Template.IsConditionMetFn = class'X2DialogueTagTemplate'.static.CheckArmoryUnitRef;
	Template.bCheckSourceUnit = bCheckSourceUnit;

	return Template;
}

static function X2DataTemplate IsResearchCompleted(name TemplateName, name ResearchName)
{
	local X2DialogueTagTemplate Template;

	`CREATE_X2TEMPLATE(class'X2DialogueTagTemplate', Template, TemplateName);

	Template.IsConditionMetFn = class'X2DialogueTagTemplate'.static.CheckCompletedResearch;
	Template.NameValue = ResearchName;

	return Template;
}

static function X2DataTemplate CanAffordAndroid(name TemplateName)
{
	local X2DialogueTagTemplate Template;

	`CREATE_X2TEMPLATE(class'X2DialogueTagTemplate', Template, TemplateName);

	Template.IsConditionMetFn = class'X2DialogueTagTemplate'.static.CheckCanAffordAndroid;
	return Template;
}

static function X2DataTemplate OwnXAndroids(name TemplateName, int AndroidCount, EDialogTagEvalOpCode CompareOp)
{
	local X2DialogueTagTemplate Template;

	`CREATE_X2TEMPLATE(class'X2DialogueTagTemplate', Template, TemplateName);

	Template.IsConditionMetFn = class'X2DialogueTagTemplate'.static.CheckOwnedAnroidNum;
	Template.IntValue = AndroidCount;
	Template.CompareOp = CompareOp;

	return Template;
}