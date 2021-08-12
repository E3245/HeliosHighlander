class X2TacticalElement_DefaultBreachPointTypes extends X2TacticalElement
	config(GameData)
	native(Core);

var config int ChanceForGuaranteedModToHaveAdditionalMods;

var config array<Name> ModifierDistributionByBreachPointType;

var config array<Name> ModifiersAvailableByType_Door;
var config array<Name> ModifiersAvailableByType_Keypad;
var config array<Name> ModifiersAvailableByType_SecurityDoor;
var config array<Name> ModifiersAvailableByType_Wall;
var config array<Name> ModifiersAvailableByType_XComVan;
var config array<Name> ModifiersAvailableByType_Window;
var config array<Name> ModifiersAvailableByType_Skylight;
var config array<Name> ModifiersAvailableByType_RopeSwing;
var config array<Name> ModifiersAvailableByType_Vent;
var config array<Name> ModifiersAvailableByType_Ladder;
var config array<Name> ModifiersAvailableByType_GrappleSummit;

var config array<Name> ModifiersAdditionalByType_Door;
var config array<Name> ModifiersAdditionalByType_Keypad;
var config array<Name> ModifiersAdditionalByType_SecurityDoor;
var config array<Name> ModifiersAdditionalByType_Wall;
var config array<Name> ModifiersAdditionalByType_XComVan;
var config array<Name> ModifiersAdditionalByType_Window;
var config array<Name> ModifiersAdditionalByType_Skylight;
var config array<Name> ModifiersAdditionalByType_RopeSwing;
var config array<Name> ModifiersAdditionalByType_Vent;
var config array<Name> ModifiersAdditionalByType_Ladder;
var config array<Name> ModifiersAdditionalByType_GrappleSummit;

static function array<X2DataTemplate> CreateTemplates()
{
	local array<X2DataTemplate> Templates;

	Templates.AddItem(Door());
	Templates.AddItem(Keypad());
	Templates.AddItem(SecurityDoor());
	Templates.AddItem(Wall());
	Templates.AddItem(XComVan());
	Templates.AddItem(Window());
	Templates.AddItem(Skylight());
	Templates.AddItem(RopeSwing());
	Templates.AddItem(Vent());
	Templates.AddItem(Ladder());
	Templates.AddItem(GrappleSummit());
	
	return Templates;
}

static function AddDarkEventModifiers(out BreachModifierInfo ModifierInfo)
{
	// HELIOS Issue #51 Vars
	local ConditionalBreachModifier ConditionalModifierInfo, EmptyConditionalModifierInfo;
	local HSHelpers					HSHelperObj;

	ConditionalModifierInfo.ModifierTemplateName = 'BreachModifier_HighResponse';
	ConditionalModifierInfo.IsConditionMetFunc = class'X2BreachPointModifierTemplate'.static.CheckStrategyGameplayTag;
	ConditionalModifierInfo.NameValue = 'DarkEventResponseTag';
	ModifierInfo.AvailableModifiers.AddItem(ConditionalModifierInfo);

	// Begin HELIOS Issue #51
	// Reset the variable to remove any lingering information
	ConditionalModifierInfo = EmptyConditionalModifierInfo;
	
	HSHelperObj = class'HSHelpers'.static.GetCDO();
	
	// Iterate through each config entry and add them to the avaliable modifiers
	foreach HSHelperObj.ModifiersAdditionalByDarkEvent(ConditionalModifierInfo)
	{
		ConditionalModifierInfo.IsConditionMetFunc = class'X2BreachPointModifierTemplate'.static.CheckStrategyGameplayTag;
		ModifierInfo.AvailableModifiers.AddItem(ConditionalModifierInfo);		
	}
	// End HELIOS Issue #51
}

static function AddAvailableModifiersByName(array<Name> ModifierNames, out BreachModifierInfo ModifierInfo)
{
	local ConditionalBreachModifier	Modifier, EmptyModifier;
	local Name ModifierName;
	foreach ModifierNames(ModifierName)
	{
		Modifier = EmptyModifier;
		Modifier.ModifierTemplateName = ModifierName;
		ModifierInfo.AvailableModifiers.AddItem(Modifier);
	}	
}

static function AddAdditionalModifiersByName(array<Name> ModifierNames, out BreachModifierInfo ModifierInfo)
{
	local ConditionalBreachModifier	Modifier, EmptyModifier;
	local Name ModifierName;
	foreach ModifierNames(ModifierName)
	{
		Modifier = EmptyModifier;
		Modifier.ModifierTemplateName = ModifierName;
		ModifierInfo.AdditionalModifiers.AddItem(Modifier);
	}
}

static function AddStandardModifierFiltering(out BreachModifierInfo ModifierInfo, EBreachPointType PointType)
{
	local BreachModifierFilter					Filter, EmptyFilter;
	local Name DistributionName;

	DistributionName = 'RandomNoneOneTwo';


	if (default.ModifierDistributionByBreachPointType.Length > 0
		&& default.ModifierDistributionByBreachPointType.Length >= PointType)
	{
		DistributionName = default.ModifierDistributionByBreachPointType[PointType];
	}

	if (DistributionName == 'RandomNoneOneTwo')
	{
		Filter = EmptyFilter;
		Filter.Func = BreachModifierFilter_RandomSelectOneorTwo;
		ModifierInfo.AdditionalModifiersFilters.AddItem(Filter);
	}
	else if (DistributionName == 'RandomNoneOne')
	{
		Filter = EmptyFilter;
		Filter.Func = BreachModifierFilter_ChanceForOneRandom;
		ModifierInfo.AdditionalModifiersFilters.AddItem(Filter);
	}
	else if (DistributionName == 'RandomOne')
	{
		Filter = EmptyFilter;
		Filter.Func = BreachModifierFilter_RandomSelectOne;
		ModifierInfo.AdditionalModifiersFilters.AddItem(Filter);
	}

	Filter = EmptyFilter;
	Filter.Func = BreachModifierFilter_RemoveAlreadySelectedModifiers;
	ModifierInfo.AdditionalModifiersFilters.AddItem(Filter);
}

static function X2DataTemplate Door()
{
	local X2BreachPointTypeTemplate				Template;
	local BreachModifierInfo					ModifierInfo;

	`CREATE_X2TEMPLATE(class'X2BreachPointTypeTemplate', Template, 'BreachPointType_Door');

	Template.Type = eBreachPointType_Door;
	Template.bPinEntryTileDuringInitialMove = true;
	Template.bPinThroughTileDuringInitialMove = true;
	
	AddDarkEventModifiers(ModifierInfo);
	AddAvailableModifiersByName(default.ModifiersAvailableByType_Door, ModifierInfo);
	AddAdditionalModifiersByName(default.ModifiersAdditionalByType_Door, ModifierInfo);
	AddStandardModifierFiltering(ModifierInfo, Template.Type);
	
	Template.ModifierInfo = ModifierInfo;

	return Template;
}

static function X2DataTemplate Keypad()
{
	local X2BreachPointTypeTemplate				Template;
	local BreachModifierInfo					ModifierInfo;
	
	`CREATE_X2TEMPLATE(class'X2BreachPointTypeTemplate', Template, 'BreachPointType_Keypad');

	Template.Type = eBreachPointType_eKeypad;
	Template.bPinEntryTileDuringInitialMove = true;
	Template.bPinThroughTileDuringInitialMove = true;

	AddDarkEventModifiers(ModifierInfo);
	AddAvailableModifiersByName(default.ModifiersAvailableByType_Keypad, ModifierInfo);
	AddAdditionalModifiersByName(default.ModifiersAdditionalByType_Keypad, ModifierInfo);
	AddStandardModifierFiltering(ModifierInfo, Template.Type);

	Template.ModifierInfo = ModifierInfo;

	return Template;
}

static function X2DataTemplate Wall()
{
	local X2BreachPointTypeTemplate				Template;
	local BreachModifierInfo					ModifierInfo;
	
	`CREATE_X2TEMPLATE(class'X2BreachPointTypeTemplate', Template, 'BreachPointType_Wall');

	Template.Type = eBreachPointType_eWall;
	Template.bPinEntryTileDuringInitialMove = true;
	Template.bPinThroughTileDuringInitialMove = true;

	AddDarkEventModifiers(ModifierInfo);
	AddAvailableModifiersByName(default.ModifiersAvailableByType_Wall, ModifierInfo);
	AddAdditionalModifiersByName(default.ModifiersAdditionalByType_Wall, ModifierInfo);
	AddStandardModifierFiltering(ModifierInfo, Template.Type);

	Template.ModifierInfo = ModifierInfo;

	return Template;
}

static function X2DataTemplate XComVan()
{
	local X2BreachPointTypeTemplate				Template;
	local BreachModifierInfo					ModifierInfo;
	
	`CREATE_X2TEMPLATE(class'X2BreachPointTypeTemplate', Template, 'BreachPointType_XComVan');

	Template.Type = eBreachPointType_eXComVan;
	Template.bPinEntryTileDuringInitialMove = true;
	
	AddDarkEventModifiers(ModifierInfo);
	AddAvailableModifiersByName(default.ModifiersAvailableByType_XComVan, ModifierInfo);
	AddAdditionalModifiersByName(default.ModifiersAdditionalByType_XComVan, ModifierInfo);
	AddStandardModifierFiltering(ModifierInfo, Template.Type);

	Template.ModifierInfo = ModifierInfo;

	return Template;
}

static function X2DataTemplate Window()
{
	local X2BreachPointTypeTemplate				Template;
	local BreachModifierInfo					ModifierInfo;
	
	`CREATE_X2TEMPLATE(class'X2BreachPointTypeTemplate', Template, 'BreachPointType_Window');

	Template.Type = eBreachPointType_eWindow;
	Template.bPinEntryTileDuringInitialMove = true;
	Template.bPinThroughTileDuringInitialMove = true;
	
	AddDarkEventModifiers(ModifierInfo);
	AddAvailableModifiersByName(default.ModifiersAvailableByType_Window, ModifierInfo);
	AddAdditionalModifiersByName(default.ModifiersAdditionalByType_Window, ModifierInfo);
	AddStandardModifierFiltering(ModifierInfo, Template.Type);

	Template.ModifierInfo = ModifierInfo;

	return Template;
}

static function X2DataTemplate Skylight()
{
	local X2BreachPointTypeTemplate				Template;
	local BreachModifierInfo					ModifierInfo;
	
	`CREATE_X2TEMPLATE(class'X2BreachPointTypeTemplate', Template, 'BreachPointType_Skylight');

	Template.Type = eBreachPointType_eSkylight;
	Template.bPinEntryTileDuringInitialMove = true;

	AddDarkEventModifiers(ModifierInfo);
	AddAvailableModifiersByName(default.ModifiersAvailableByType_Skylight, ModifierInfo);
	AddAdditionalModifiersByName(default.ModifiersAdditionalByType_Skylight, ModifierInfo);
	AddStandardModifierFiltering(ModifierInfo, Template.Type);

	Template.ModifierInfo = ModifierInfo;

	return Template;
}

static function X2DataTemplate RopeSwing()
{
	local X2BreachPointTypeTemplate				Template;
	local BreachModifierInfo					ModifierInfo;
	
	`CREATE_X2TEMPLATE(class'X2BreachPointTypeTemplate', Template, 'BreachPointType_RopeSwing');

	Template.Type = eBreachPointType_eRopeSwing;

	AddDarkEventModifiers(ModifierInfo);
	AddAvailableModifiersByName(default.ModifiersAvailableByType_RopeSwing, ModifierInfo);
	AddAdditionalModifiersByName(default.ModifiersAdditionalByType_RopeSwing, ModifierInfo);
	AddStandardModifierFiltering(ModifierInfo, Template.Type);

	Template.ModifierInfo = ModifierInfo;

	return Template;
}

static function X2DataTemplate Vent()
{
	local X2BreachPointTypeTemplate				Template;
	local BreachModifierInfo					ModifierInfo;
	
	`CREATE_X2TEMPLATE(class'X2BreachPointTypeTemplate', Template, 'BreachPointType_Vent');

	Template.Type = eBreachPointType_eVent;
	
	AddDarkEventModifiers(ModifierInfo);
	AddAvailableModifiersByName(default.ModifiersAvailableByType_Vent, ModifierInfo);
	AddAdditionalModifiersByName(default.ModifiersAdditionalByType_Vent, ModifierInfo);
	AddStandardModifierFiltering(ModifierInfo, Template.Type);

	Template.ModifierInfo = ModifierInfo;

	return Template;
}

static function X2DataTemplate Ladder()
{
	local X2BreachPointTypeTemplate				Template;
	local BreachModifierInfo					ModifierInfo;
	
	`CREATE_X2TEMPLATE(class'X2BreachPointTypeTemplate', Template, 'BreachPointType_Ladder');

	Template.Type = eBreachPointType_eLadder;
	Template.bPinEntryTileDuringInitialMove = true;
	
	AddDarkEventModifiers(ModifierInfo);
	AddAvailableModifiersByName(default.ModifiersAvailableByType_Ladder, ModifierInfo);
	AddAdditionalModifiersByName(default.ModifiersAdditionalByType_Ladder, ModifierInfo);
	AddStandardModifierFiltering(ModifierInfo, Template.Type);

	Template.ModifierInfo = ModifierInfo;

	return Template;
}

static function X2DataTemplate SecurityDoor()
{
	local X2BreachPointTypeTemplate				Template;
	local BreachModifierInfo					ModifierInfo;
	
	`CREATE_X2TEMPLATE(class'X2BreachPointTypeTemplate', Template, 'BreachPointType_SecurityDoor');

	Template.Type = eBreachPointType_eSecurityDoor;
	Template.bPinEntryTileDuringInitialMove = true;
	Template.bPinThroughTileDuringInitialMove = true;

	AddDarkEventModifiers(ModifierInfo);
	AddAvailableModifiersByName(default.ModifiersAvailableByType_SecurityDoor, ModifierInfo);
	AddAdditionalModifiersByName(default.ModifiersAdditionalByType_SecurityDoor, ModifierInfo);
	AddStandardModifierFiltering(ModifierInfo, Template.Type);

	Template.ModifierInfo = ModifierInfo;

	return Template;
}

static function X2DataTemplate GrappleSummit()
{
	local X2BreachPointTypeTemplate				Template;
	local BreachModifierInfo					ModifierInfo;
	
	`CREATE_X2TEMPLATE(class'X2BreachPointTypeTemplate', Template, 'BreachPointType_GrappleSummit');

	Template.Type = eBreachPointType_eGrappleSummit;

	AddDarkEventModifiers(ModifierInfo);
	AddAvailableModifiersByName(default.ModifiersAvailableByType_GrappleSummit, ModifierInfo);
	AddAdditionalModifiersByName(default.ModifiersAdditionalByType_GrappleSummit, ModifierInfo);
	AddStandardModifierFiltering(ModifierInfo, Template.Type);

	Template.ModifierInfo = ModifierInfo;

	return Template;
}

//Filters
static function BreachModifierFilter_RemoveAlreadySelectedModifiers(const out BreachModifierFilter FilterInfo, const array<X2BreachPointModifierTemplate> Modifiers, const out array<X2BreachPointModifierTemplate> AlreadySelectedModifiers, const out array<X2BreachPointModifierTemplate> ChosenAvailableModifiers, out array<X2BreachPointModifierTemplate> OutModifiers, const out int PointIndex, const out int NumBreachPoints)
{
	local X2BreachPointModifierTemplate						Modifier;

	foreach Modifiers(Modifier) //Heavily prefer to pick nonchosen modifiers 
	{
		if (AlreadySelectedModifiers.Find(Modifier) == INDEX_NONE) //Is the currently checked modifier NOT in the AlreadySelectedModifiers array?
		{
			OutModifiers.AddItem(Modifier);
		}
	}

	// if there's no new modifier, just pick one randomly 
	// we want to make sure there's at least one modifier for every breach point
	if (OutModifiers.length < 1 && Modifiers.length > 0)
	{
		Modifier = Modifiers[`SYNC_RAND_STATIC(Modifiers.length)];
		OutModifiers.AddItem(Modifier);
	}
	
}

static function BreachModifierFilter_RandomSelectOneorTwo(const out BreachModifierFilter FilterInfo, const array<X2BreachPointModifierTemplate> Modifiers, const out array<X2BreachPointModifierTemplate> AlreadySelectedModifiers, const out array<X2BreachPointModifierTemplate> ChosenAvailableModifiers, out array<X2BreachPointModifierTemplate> OutModifiers, const out int PointIndex, const out int NumBreachPoints)
{
	local X2BreachPointModifierTemplate				SelectedModifier;
	local int										LastRandIndex, ModLength, i, RandIndex, NegModifierCount;
	local array<name>								IncompatibleModifierNames;
	local name										ModifierName;
	local bool										bAlreadySelected, bTooManyDebuffs, bIncompatible;

	// No more than 2 modifiers MAX including always-on ones
	if (ChosenAvailableModifiers.length >= 2)
		return; 

	ModLength = Modifiers.length;
	if (ModLength == 0)
	{
		return;
	}

	if (`SYNC_RAND_STATIC(100) < 75 && ChosenAvailableModifiers.length > 0)
	{
		// high chance we'll have 0 additional modifiers
	}	
	else if (`SYNC_RAND_STATIC(100) < 75 || ChosenAvailableModifiers.length > 0)
	{
		// choose one modifier due to chance, or because we already have one modifier
		RandIndex = `SYNC_RAND_STATIC(ModLength);
		SelectedModifier = Modifiers[RandIndex];
		OutModifiers.AddItem(SelectedModifier);
	}
	else
	{
		LastRandIndex = -1;
		NegModifierCount = 0;

		for (i = 0; i < ModLength; i++)
		{
			if (OutModifiers.length >= 2)
			{
				break;
			}

			RandIndex = `SYNC_RAND_STATIC(ModLength);
			SelectedModifier = Modifiers[RandIndex];

			bAlreadySelected = (RandIndex == LastRandIndex);
			bTooManyDebuffs = (!SelectedModifier.bGood && NegModifierCount > 0);
			bIncompatible = (IncompatibleModifierNames.Find(SelectedModifier.DataName) != INDEX_NONE);

			if (bAlreadySelected || bTooManyDebuffs || bIncompatible)
			{
				continue;
			}

			LastRandIndex = RandIndex;
			if (!SelectedModifier.bGood)
			{
				NegModifierCount++;
			}

			OutModifiers.AddItem(SelectedModifier);

			// collect incompatible modifiers from the newly selected modifier
			// make sure we don't roll these in the next run
			foreach SelectedModifier.IncompatibleBreachModifiers(ModifierName)
			{
				IncompatibleModifierNames.AddItem(ModifierName);
			}
		}
	}

}

static function BreachModifierFilter_NoNegativeModifiers(const out BreachModifierFilter FilterInfo, const array<X2BreachPointModifierTemplate> Modifiers, const out array<X2BreachPointModifierTemplate> AlreadySelectedModifiers, const out array<X2BreachPointModifierTemplate> ChosenAvailableModifiers, out array<X2BreachPointModifierTemplate> OutModifiers, const out int PointIndex, const out int NumBreachPoints)
{
	local X2BreachPointModifierTemplate						Modifier;

	foreach Modifiers(Modifier) //Heavily prefer to pick nonchosen modifiers 
	{
		if (Modifier.bGood)
		{
			OutModifiers.AddItem(Modifier);
		}
	}
}

static function BreachModifierFilter_ChanceForOneRandom(const out BreachModifierFilter FilterInfo, const array<X2BreachPointModifierTemplate> Modifiers, const out array<X2BreachPointModifierTemplate> AlreadySelectedModifiers, const out array<X2BreachPointModifierTemplate> ChosenAvailableModifiers, out array<X2BreachPointModifierTemplate> OutModifiers, const out int PointIndex, const out int NumBreachPoints)
{
	local X2BreachPointModifierTemplate		SelectedModifier;
	local int								ModLength, RandIndex;

	ModLength = Modifiers.length;

	if (ModLength == 0)
	{
		return;
	}

	if (`SYNC_RAND_STATIC(100) < default.ChanceForGuaranteedModToHaveAdditionalMods)
	{
		RandIndex = `SYNC_RAND_STATIC(ModLength);
		SelectedModifier = Modifiers[RandIndex];
		OutModifiers.AddItem(SelectedModifier);
	}
}

static function BreachModifierFilter_RandomSelectOne(const out BreachModifierFilter FilterInfo, const array<X2BreachPointModifierTemplate> Modifiers, const out array<X2BreachPointModifierTemplate> AlreadySelectedModifiers, const out array<X2BreachPointModifierTemplate> ChosenAvailableModifiers, out array<X2BreachPointModifierTemplate> OutModifiers, const out int PointIndex, const out int NumBreachPoints)
{
	local X2BreachPointModifierTemplate		SelectedModifier;
	local int								ModLength, RandIndex;

	ModLength = Modifiers.length;

	if (ModLength == 0)
	{
		return;
	}

	RandIndex = `SYNC_RAND_STATIC(ModLength);
	SelectedModifier = Modifiers[RandIndex];
	OutModifiers.AddItem(SelectedModifier);
}
