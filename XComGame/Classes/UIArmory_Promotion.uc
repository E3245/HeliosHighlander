
class UIArmory_Promotion extends UIArmory
	dependson(X2Photobooth, X2Photobooth_AutoGenBase)
	native(UI);

const NUM_ABILITIES_PER_RANK = 2;

var XComGameState PromotionState;

var int PendingRank, PendingBranch;

var int PropagandaMinRank;
var localized string m_strMakePosterTitle;
var localized string m_strMakePosterBody;

var bool bAfterActionPromotion;	//Set to TRUE if we need to make a pawn and move the camera to the armory
var UIAfterAction AfterActionScreen; //If bAfterActionPromotion is true, this holds a reference to the after action screen

var localized string m_strSelectAbility;
var localized string m_strAbilityHeader;

var localized string m_strConfirmAbilityTitle;
var localized string m_strConfirmAbilityText;

var localized string m_strCorporalPromotionDialogTitle;
var localized string m_strCorporalPromotionDialogText;

var localized string m_strAWCUnlockDialogTitle;
var localized string m_strAWCUnlockDialogText;

var localized string m_strAbilityLockedTitle;
var localized string m_strAbilityLockedDescription;

var localized string m_strInfo;
var localized string m_strSelect;

var localized string m_strHotlinkToRecovery;

var localized string m_strNewAbilityAutoTitle;
var localized string m_tagStrNewAbilityAutoBody;

var int SelectedAbilityIndex;

var UIList  List;

var bool bShownClassPopup, bShownCorporalPopup, bShownAWCPopup; // DEPRECATED bsteiner 3/24/2016 

var protected int previousSelectedIndexOnFocusLost;

simulated function InitPromotion(StateObjectReference UnitRef, optional bool bInstantTransition)
{
	// If the AfterAction screen is running, let it position the camera
	AfterActionScreen = UIAfterAction(Movie.Stack.GetScreen(class'UIAfterAction'));
	if(AfterActionScreen != none)
	{
		bAfterActionPromotion = true;
		PawnLocationTag = AfterActionScreen.GetPawnLocationTag(UnitRef);
		CameraTag = AfterActionScreen.GetPromotionBlueprintTag(UnitRef);
		DisplayTag = name(AfterActionScreen.GetPromotionBlueprintTag(UnitRef));
	}
	else
	{
		CameraTag = GetPromotionBlueprintTag(UnitRef);
		DisplayTag = name(GetPromotionBlueprintTag(UnitRef));
	}
	
	bUseNavHelp = true;

	UnitReference = UnitRef;
	super.InitArmory(UnitRef,,,,,, bInstantTransition);

	List = Spawn(class'UIList', self).InitList('promoteList');
	//List.OnSelectionChanged = PreviewRow;
	List.bStickyHighlight = false;
	List.bAutosizeItems = false;

	PopulateData();
	List.Navigator.LoopSelection = false;

	Navigator.Clear();
	Navigator.LoopSelection = false;

	Navigator.AddControl(List);
	if (List.SelectedIndex < 0)
	{
		List.SetSelectedIndex(0, true);
		Navigator.SetSelected(List);
		UIArmory_PromotionItem(List.GetSelectedItem()).SetSelectedAbility(0); //bsg-crobinson (6.5.17): When first opening promote grab focus on left most skill
	}
	else
	{
		Navigator.SetSelected(List);
		UIArmory_PromotionItem(List.GetSelectedItem()).SetSelectedAbility(0); //bsg-crobinson (6.5.17): When first opening promote grab focus on left most skill
	}

	MC.FunctionVoid("animateIn");
}

simulated function OnInit()
{
	super.OnInit();

	SetTimer(0.1334, false, 'UpdateClassRowSelection');
}

simulated function UpdateNavHelp() // bsg-jrebar (4/21/17): Changed UI flow and button positions per new additions
{
	local XComGameState_Unit Unit;

	if(!bIsFocused)
	{
		return;
	}

	m_HUD.NavHelp.ClearButtonHelp();
	m_HUD.NavHelp.bIsVerticalHelp = false;

	m_HUD.NavHelp.AddBackButton(OnCancel);
		
	if (UIArmory_PromotionItem(List.GetSelectedItem()).bEligibleForPromotion)
	{
		m_HUD.NavHelp.AddSelectNavHelp();
	}

	if( `ISCONTROLLERACTIVE )
	{
		if (IsAllowedToCycleSoldiers())
		{
			m_HUD.NavHelp.AddLeftHelp(`MAKECAPS(class'UIArmory'.default.ChangeSoldierLabel), class'UIUtilities_Input'.static.GetGamepadIconPrefix() $ class'UIUtilities_Input'.const.ICON_LBRB_L1R1);
			//m_HUD.NavHelp.AddCenterHelp(m_strTabNavHelp, class'UIUtilities_Input'.static.GetGamepadIconPrefix() $ class'UIUtilities_Input'.const.ICON_LBRB_L1R1); // bsg-jrebar (5/23/17): Removing inlined buttons
		}

		// Access info popups for abilities/scars
		m_HUD.NavHelp.AddLeftHelp(`MAKECAPS(class'UIArmory_MainMenu'.default.m_strAbilities), class'UIUtilities_Input'.static.GetGamepadIconPrefix() $ class'UIUtilities_Input'.const.ICON_LSTICK);

		Unit = GetUnit();
		if (Unit.Scars.Length > 0)
		{
			m_HUD.NavHelp.AddLeftHelp(`MAKECAPS(class'DioStrategyNotificationsHelper'.default.ScarsEarnedTitle), class'UIUtilities_Input'.static.GetGamepadIconPrefix() $ class'UIUtilities_Input'.const.ICON_RSTICK);
		}
	}
}

simulated function OnLoseFocus()
{
	super.OnLoseFocus();

	if( List.SelectedIndex != -1)
		previousSelectedIndexOnFocusLost = List.SelectedIndex;
}

// Don't allow soldier switching when promoting soldiers on top of avenger
simulated function bool IsAllowedToCycleSoldiers()
{
	return true;
}

simulated function PopulateData()
{
	local int i, maxRank, previewIndex, currentRank;
	local string AbilityIcon1, AbilityIcon2, AbilityName1, AbilityName2, HeaderString;
	local bool bFirstUnnassignedRank, bHasAbility1, bHasAbility2, bHasRankAbility;
	local XComGameState_Unit Unit;
	local X2SoldierClassTemplate ClassTemplate;
	local X2AbilityTemplate AbilityTemplate1, AbilityTemplate2, PopupHighlightAbility;
	local X2AbilityTemplateManager AbilityTemplateManager;
	local array<SoldierClassAbilityType> AbilityTree;
	local UIArmory_PromotionItem Item;

	// We don't need to clear the list, or recreate the pawn here -sbatista
	//super.PopulateData();
	Unit = GetUnit();
	ClassTemplate = Unit.GetSoldierClassTemplate();
	currentRank = Unit.GetRank();

	HeaderString = m_strAbilityHeader;

	if(currentRank != 1 && Unit.HasAvailablePerksToAssign())
	{
		HeaderString = m_strSelectAbility;
	}

	AS_SetTitle(ClassTemplate.IconImage, HeaderString, `MAKECAPS(ClassTemplate.DisplayName));

	maxRank = ClassTemplate.GetMaxConfiguredRank();
	AbilityTemplateManager = class'X2AbilityTemplateManager'.static.GetAbilityTemplateManager();
	 
	for(i = 1; i < maxRank; ++i)
	{
		bHasRankAbility = false;
		Item = UIArmory_PromotionItem(List.GetItem(i - 1));
		if(Item == none)
			Item = UIArmory_PromotionItem(List.CreateItem(class'UIArmory_PromotionItem')).InitPromotionItem(i);

		Item.Rank = i;
		Item.ClassName = ClassTemplate.DataName;
		Item.SetRankData(class'UIUtilities_Image'.static.GetRankIcon(i, ClassTemplate.DataName), `MAKECAPS(class'X2ExperienceConfig'.static.GetRankName(i, ClassTemplate.DataName)));
		Item.ShowTrainingMessage(Unit.HasTrainingAvailableAtRank(Item.Rank));
		Item.AS_SetIndex(i); 

		AbilityTree = Unit.GetRankAbilities(Item.Rank);

		AbilityTemplate1 = (AbilityTree.Length > 0) ? AbilityTemplateManager.FindAbilityTemplate(AbilityTree[0].AbilityName) : None;
		if(AbilityTemplate1 != none)
		{
			Item.AbilityName1 = AbilityTemplate1.DataName;
			AbilityName1 = i > currentRank ? class'UIUtilities_Text'.static.GetColoredText(m_strAbilityLockedTitle, eUIState_Disabled) : `MAKECAPS(AbilityTemplate1.LocFriendlyName);
			AbilityIcon1 = i > currentRank ? class'UIUtilities_Image'.const.LockedAbilityIcon : AbilityTemplate1.IconImage;
			bHasAbility1 = Unit.HasSoldierAbility(Item.AbilityName1);
			bHasRankAbility = bHasAbility1;
		}

		AbilityTemplate2 = (AbilityTree.Length > 1) ? AbilityTemplateManager.FindAbilityTemplate(AbilityTree[1].AbilityName) : None;
		if(AbilityTemplate2 != none)
		{
			Item.AbilityName2 = AbilityTemplate2.DataName;
			AbilityName2 = i > currentRank ? class'UIUtilities_Text'.static.GetColoredText(m_strAbilityLockedTitle, eUIState_Disabled) : `MAKECAPS(AbilityTemplate2.LocFriendlyName);
			AbilityIcon2 = i > currentRank ? class'UIUtilities_Image'.const.LockedAbilityIcon : AbilityTemplate2.IconImage;
			
			bHasAbility1 = Unit.HasSoldierAbility(Item.AbilityName1);
			bHasAbility2 = Unit.HasSoldierAbility(Item.AbilityName2);
			bHasRankAbility = bHasAbility1 || bHasAbility2;

			Item.SetAbilityData(AbilityIcon1, AbilityName1, AbilityIcon2, AbilityName2);
			Item.SetEquippedAbilities(bHasAbility1, bHasAbility2);
		}
		else
		{
			AbilityName2 = "";
			AbilityIcon2 = "";

			Item.SetEquippedAbilities(bHasAbility1, true);
			Item.SetAbilityData( AbilityIcon1, AbilityName1, AbilityIcon2, AbilityName2);
		}

		if( bHasRankAbility || (i > currentRank && !Unit.HasAvailablePerksToAssign()))
		{
			Item.SetDisabled(false);
			Item.SetPromote(false);
			Item.AnimateNeedsAttention(false);
		}
		else if(i > currentRank)
		{
			Item.SetDisabled(true);
			Item.SetPromote(false);
			Item.AnimateNeedsAttention(false);
		}
		else // has available perks to assign
		{
			if(!bFirstUnnassignedRank)
			{
				if (AbilityIcon2 == "")
				{
					PendingRank = Item.Rank;
					PendingBranch = 0;
					ComfirmAbilityCallback('eUIAction_Accept');
					Item.AnimateNeedsAttention(true);

					// Show popup to highlight an automatically-unlocked ability
					PopupHighlightAbility = AbilityTemplate1;
				}
				else
				{
					bFirstUnnassignedRank = true;
					Item.SetDisabled(false);
					Item.SetPromote(true);
					Item.AnimateNeedsAttention();
				}
			}
			else
			{
				Item.SetDisabled(true);
				Item.SetPromote(false);
				Item.AnimateNeedsAttention(false);
			}
		}

		Item.RealizeVisuals();
	}

	class'UIUtilities_Strategy'.static.PopulateAbilitySummary(self, Unit, true);

	previewIndex = Max(currentRank - 1, 0); // Preview current rank - 1 since rank 0 is not visualized
	PreviewRow(List, previewIndex);
	
	Navigator.SetSelected(List);
	List.SetSelectedIndex(previewIndex);

	UpdateNavHelp();

	// Show popup, if any queued
	if (PopupHighlightAbility != none)
	{
		PopupHighlightUnlockedAbility(PopupHighlightAbility);
	}
}

simulated function OnClassRowMouseEvent(UIPanel Panel, int Cmd)
{
	if(Cmd == class'UIUtilities_Input'.const.FXS_L_MOUSE_IN || Cmd == class'UIUtilities_Input'.const.FXS_L_MOUSE_DRAG_OVER)
		PreviewRow(List, -1);
}

simulated function RequestPawn(optional Rotator DesiredRotation)
{
	local XComGameState_Unit UnitState;
	local name IdleAnimName;

	super.RequestPawn(DesiredRotation);

	UnitState = GetUnit();

	IdleAnimName = UnitState.GetMyTemplate().CustomizationManagerClass.default.StandingStillAnimName;

	// Play the "By The Book" idle to minimize character overlap with UI elements
	XComHumanPawn(ActorPawn).PlayHQIdleAnim(IdleAnimName);

	// Cache desired animation in case the pawn hasn't loaded the customization animation set
	XComHumanPawn(ActorPawn).CustomizationIdleAnim = IdleAnimName;
}

// DEPRECATED bsteiner 3/24/2016
simulated function AwardRankAbilities(X2SoldierClassTemplate ClassTemplate, int Rank);
simulated function array<name> AwardAWCAbilities();
simulated function ShowCorporalDialog(X2SoldierClassTemplate ClassTemplate);
// END DEPRECATED ITEMS bsteiner 3/24/2016

simulated function ShowAWCDialog(array<name> AWCAbilityNames)
{
	local int i;
	local string tmpStr;
	local XGParamTag        kTag;
	local TDialogueBoxData  kDialogData;
	local X2AbilityTemplate AbilityTemplate;
	local X2AbilityTemplateManager AbilityTemplateManager;
	local XComGameState NewGameState;
	local XComGameState_Unit UnitState;

	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Display AWC Ability Popup");
	UnitState = XComGameState_Unit(NewGameState.ModifyStateObject(class'XComGameState_Unit', UnitReference.ObjectID));
	UnitState.bSeenAWCAbilityPopup = true;
	`GAMERULES.SubmitGameState(NewGameState);

	kTag = XGParamTag(`XEXPANDCONTEXT.FindTag("XGParam"));

	kDialogData.strTitle = m_strAWCUnlockDialogTitle;

	kTag.StrValue0 = "";
	AbilityTemplateManager = class'X2AbilityTemplateManager'.static.GetAbilityTemplateManager();
	for(i = 0; i < AWCAbilityNames.Length; ++i)
	{
		AbilityTemplate = AbilityTemplateManager.FindAbilityTemplate(AWCAbilityNames[i]);

		// Ability Name
		tmpStr = AbilityTemplate.LocFriendlyName != "" ? AbilityTemplate.LocFriendlyName : ("Missing 'LocFriendlyName' for ability '" $ AbilityTemplate.DataName $ "'");
		kTag.StrValue0 $= "- " $ `MAKECAPS(tmpStr) $ ":\n";

		// Ability Description
		tmpStr = AbilityTemplate.HasLongDescription() ? AbilityTemplate.GetMyLongDescription(, GetUnit()) : ("Missing 'LocLongDescription' for ability " $ AbilityTemplate.DataName $ "'");
		kTag.StrValue0 $= tmpStr $ "\n\n";
	}

	kDialogData.strText = `XEXPAND.ExpandString(m_strAWCUnlockDialogText);
	kDialogData.strAccept = class'UIUtilities_Text'.default.m_strGenericOK;

	Movie.Pres.UIRaiseDialog(kDialogData);
}

simulated function PreviewRow(UIList ContainerList, int ItemIndex)
{
	local int Rank;
	local string TmpStr;
	local X2AbilityTemplate AbilityTemplate;
	local array<SoldierClassAbilityType> AbilityTree;
	local X2AbilityTemplateManager AbilityTemplateManager;
	local XComGameState_Unit Unit;

	Unit = GetUnit();

	if(ItemIndex == INDEX_NONE)
		Rank = 0;
	else
		Rank = UIArmory_PromotionItem(List.GetItem(ItemIndex)).Rank;

	MC.BeginFunctionOp("setAbilityPreview");

	if(Rank > Unit.GetRank())
	{
		MC.QueueString(class'UIUtilities_Image'.const.LockedAbilityIcon); // icon
		MC.QueueString(class'UIUtilities_Text'.static.GetColoredText(m_strAbilityLockedTitle, eUIState_Good)); // name
		MC.QueueString(class'UIUtilities_Text'.static.GetColoredText(m_strAbilityLockedDescription, eUIState_Disabled)); // description
		MC.QueueBoolean(false); // isClassIcon
	}
	else
	{
		AbilityTree = Unit.GetRankAbilities(Rank);
		AbilityTemplateManager = class'X2AbilityTemplateManager'.static.GetAbilityTemplateManager();

		AbilityTemplate = AbilityTemplateManager.FindAbilityTemplate(AbilityTree[SelectedAbilityIndex].AbilityName);

		Header.UpdateDataAbility(Unit, AbilityTemplate);
		
		if(AbilityTemplate != none)
		{
			MC.QueueString(AbilityTemplate.IconImage); // icon

			TmpStr = AbilityTemplate.LocFriendlyName != "" ? AbilityTemplate.LocFriendlyName : ("Missing 'LocFriendlyName' for " $ AbilityTemplate.DataName);
			MC.QueueString(`MAKECAPS(TmpStr)); // name

			TmpStr = AbilityTemplate.HasLongDescription() ? AbilityTemplate.GetMyLongDescription(, Unit) : ("Missing 'LocLongDescription' for " $ AbilityTemplate.DataName);
			MC.QueueString(TmpStr); // description
			MC.QueueBoolean(false); // isClassIcon
		}
		else if(SelectedAbilityIndex > 0)
		{
			SelectedAbilityIndex = 0;

			AbilityTemplate = AbilityTemplateManager.FindAbilityTemplate(AbilityTree[SelectedAbilityIndex].AbilityName);

			if (AbilityTemplate != none)
			{
				MC.QueueString(AbilityTemplate.IconImage); // icon

				TmpStr = AbilityTemplate.LocFriendlyName != "" ? AbilityTemplate.LocFriendlyName : ("Missing 'LocFriendlyName' for " $ AbilityTemplate.DataName);
				MC.QueueString(`MAKECAPS(TmpStr)); // name

				TmpStr = AbilityTemplate.HasLongDescription() ? AbilityTemplate.GetMyLongDescription(, Unit) : ("Missing 'LocLongDescription' for " $ AbilityTemplate.DataName);
				MC.QueueString(TmpStr); // description
				MC.QueueBoolean(false); // isClassIcon
			}
		}
	}

	MC.EndOp();
	
	UIArmory_PromotionItem(List.GetItem(ItemIndex)).SetSelectedAbility(SelectedAbilityIndex);
	UpdateNavHelp();
}

simulated function HideRowPreview()
{
	MC.FunctionVoid("hideAbilityPreview");
}

simulated function ConfirmAbilitySelection(int Rank, int Branch)
{
	local XGParamTag LocTag;
	local TDialogueBoxData DialogData;
	local X2AbilityTemplate AbilityTemplate;
	local X2AbilityTemplateManager AbilityTemplateManager;
	local array<SoldierClassAbilityType> AbilityTree;

	PendingRank = Rank;
	PendingBranch = Branch;

	DialogData.eType = eDialog_Alert;
	DialogData.bMuteAcceptSound = true;
	DialogData.strTitle = m_strConfirmAbilityTitle;
	DialogData.strAccept = class'UIUtilities_Text'.default.m_strGenericYes;
	DialogData.strCancel = class'UIUtilities_Text'.default.m_strGenericNO;
	DialogData.fnCallback = ComfirmAbilityCallback;
	DialogData.bMuteAcceptSound = true;
	
	AbilityTree = GetUnit().GetRankAbilities(Rank);
	AbilityTemplateManager = class'X2AbilityTemplateManager'.static.GetAbilityTemplateManager();
	AbilityTemplate = AbilityTemplateManager.FindAbilityTemplate(AbilityTree[Branch].AbilityName);

	LocTag = XGParamTag(`XEXPANDCONTEXT.FindTag("XGParam"));
	LocTag.StrValue0 = AbilityTemplate.LocFriendlyName;
	DialogData.strText = `XEXPAND.ExpandString(m_strConfirmAbilityText);
	Movie.Pres.UIRaiseDialog(DialogData);
	UpdateNavHelp();
}

simulated function ComfirmAbilityCallback(Name Action)
{
	local XComGameStateHistory History;
	local bool bSuccess;
	local XComGameState UpdateState;
	local XComGameState_Unit UpdatedUnit;
	local XComGameStateContext_ChangeContainer ChangeContainer;
	

	if(Action == 'eUIAction_Accept')
	{
		History = `XCOMHISTORY;
		ChangeContainer = class'XComGameStateContext_ChangeContainer'.static.CreateEmptyChangeContainer("Soldier Promotion");
		UpdateState = History.CreateNewGameState(true, ChangeContainer);

		UpdatedUnit = XComGameState_Unit(UpdateState.ModifyStateObject(class'XComGameState_Unit', GetUnit().ObjectID));
		bSuccess = UpdatedUnit.BuySoldierProgressionAbility(UpdateState, PendingRank, PendingBranch);

		if(bSuccess)
		{
			// Update notifications
			class'DioStrategyNotificationsHelper'.static.RefreshPromotionNotifications(UpdateState);

			// Submit			
			`XEVENTMGR.TriggerEvent('Analytics_PromotionAbilitySelected', self, self, none);
			`GAMERULES.SubmitGameState(UpdateState);

			Header.PopulateData();
			PopulateData();
		}
		else
			History.CleanupPendingGameState(UpdateState);

		PlayConfirmSound();
	}
	else 	// if we got here it means we were going to upgrade an ability, but then we decided to cancel
	{
		List.SetSelectedIndex(previousSelectedIndexOnFocusLost, true);
		UIArmory_PromotionItem(List.GetSelectedItem()).SetSelectedAbility(SelectedAbilityIndex);
	}
}

simulated function PopupHighlightUnlockedAbility(X2AbilityTemplate AbilityTemplate)
{
	local XComGameState_Unit Unit;
	local X2SoldierClassTemplate ClassTemplate;
	local XGParamTag LocTag;
	local string RankName, TitleString, BodyString;

	TitleString = m_strNewAbilityAutoTitle;

	Unit = GetUnit();
	ClassTemplate = Unit.GetSoldierClassTemplate();
	RankName = class'X2ExperienceConfig'.static.GetRankName(Unit.GetRank(), ClassTemplate.DataName);

	LocTag = XGParamTag(`XEXPANDCONTEXT.FindTag("XGParam"));
	LocTag.StrValue0 = RankName;
	LocTag.StrValue1 = `MAKECAPS(AbilityTemplate.LocFriendlyName);
	BodyString = `XEXPAND.ExpandString(m_tagStrNewAbilityAutoBody);

	BodyString $="!\n\n" $ AbilityTemplate.GetMyLongDescription(, Unit);

	`STRATPRES.UIWarningDialog(TitleString, BodyString, eDialog_Normal, AbilityTemplate.IconImage);
}

simulated function MakePosterButton()
{
	local UIArmory_Photobooth photoscreen;
	local PhotoboothDefaultSettings autoDefaultSettings;
	local AutoGenPhotoInfo requestInfo;

	requestInfo.TextLayoutState = ePBTLS_PromotedSoldier;
	requestInfo.UnitRef = UnitReference;
	autoDefaultSettings = `HQPRES.GetPhotoboothAutoGen().SetupDefault(requestInfo);
	autoDefaultSettings.SoldierAnimIndex.AddItem(-1); // Todo: change anims to duo pose.  -1 will randomize

	photoscreen = XComHQPresentationLayer(Movie.Pres).UIArmory_Photobooth(UnitReference);
	photoscreen.DefaultSetupSettings = autoDefaultSettings;
}

simulated function bool OnUnrealCommand(int cmd, int arg)
{
	local XComGameStateHistory History;
	local bool bHandled;
	//local name SoldierClassName;
	local XComGameState_Unit UpdatedUnit;
	local XComGameState UpdateState;
	local XComGameStateContext_ChangeContainer ChangeContainer;
	//local XComGameState_Unit Unit;
	//Unit = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(UnitReference.ObjectID));

	// Only pay attention to presses or repeats; ignoring other input types
	if ( !CheckInputIsReleaseOrDirectionRepeat(cmd, arg) )
		return false;
	if (List.GetSelectedItem().OnUnrealCommand(cmd, arg))
	{
		UpdateNavHelp();
		return true;
	}

	bHandled = true;

	switch( cmd )
	{
		// DEBUG: Press Tab to rank up the soldier
		`if (`notdefined(FINAL_RELEASE))
		case class'UIUtilities_Input'.const.FXS_KEY_TAB:
			History = `XCOMHISTORY;
			ChangeContainer = class'XComGameStateContext_ChangeContainer'.static.CreateEmptyChangeContainer("DEBUG Unit Rank Up");
			UpdateState = History.CreateNewGameState(true, ChangeContainer);
			UpdatedUnit = XComGameState_Unit(UpdateState.ModifyStateObject(class'XComGameState_Unit', GetUnit().ObjectID));

			UpdatedUnit.RankUpSoldier(UpdateState);

			// Update notifications
			class'DioStrategyNotificationsHelper'.static.RefreshPromotionNotifications(UpdateState);

			// Submit
			`GAMERULES.SubmitGameState(UpdateState);

			PopulateData();
			break;
		`endif
		case class'UIUtilities_Input'.const.FXS_MOUSE_5:
		case class'UIUtilities_Input'.const.FXS_KEY_TAB:
		//case class'UIUtilities_Input'.const.FXS_BUTTON_RBUMPER:
		case class'UIUtilities_Input'.const.FXS_MOUSE_4:
		case class'UIUtilities_Input'.const.FXS_KEY_LEFT_SHIFT:
		//case class'UIUtilities_Input'.const.FXS_BUTTON_LBUMPER:
			// Prevent switching soldiers during AfterAction promotion
			if( UIAfterAction(Movie.Stack.GetScreen(class'UIAfterAction')) == none )
				bHandled = false;
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
			SuppressNextNonCursorConfirmSound();
			bHandled = false;
			break;
			
		case class'UIUtilities_Input'.const.FXS_DPAD_UP:
		case class'UIUtilities_Input'.const.FXS_DPAD_DOWN:
		case class'UIUtilities_Input'.const.FXS_VIRTUAL_LSTICK_UP:
		case class'UIUtilities_Input'.const.FXS_VIRTUAL_LSTICK_DOWN:
		case class'UIUtilities_Input'.const.FXS_KEY_W:
		case class'UIUtilities_Input'.const.FXS_KEY_S:
		case class'UIUtilities_Input'.const.FXS_ARROW_UP:
		case class'UIUtilities_Input'.const.FXS_ARROW_DOWN:
			PlayMouseOverSound();
			bHandled = false;
			break;
		case class'UIUtilities_Input'.const.FXS_BUTTON_L3 :
			ShowAbilityInfoPopup();
			break;
		case class'UIUtilities_Input'.const.FXS_BUTTON_R3 :
			ShowScarInfoPopup();
			break;

		default:
			bHandled = false;
			break;
	}

	//if (List.Navigator.OnUnrealCommand(cmd, arg))
	//{
	//	return true;
	//}
	
	return bHandled || super.OnUnrealCommand(cmd, arg);
}

simulated function OnReceiveFocus()
{
	local int i;
	local XComHQPresentationLayer HQPres;

	super.OnReceiveFocus();

	HQPres = XComHQPresentationLayer(Movie.Pres);

	if(HQPres != none)
	{
		if(bAfterActionPromotion) //If the AfterAction screen is running, let it position the camera
			HQPres.CAMLookAtNamedLocation(AfterActionScreen.GetPromotionBlueprintTag(UnitReference), `HQINTERPTIME);
		else
			HQPres.CAMLookAtNamedLocation(CameraTag, `HQINTERPTIME);
	}

	for(i = 0; i < List.ItemCount; ++i)
	{
		UIArmory_PromotionItem(List.GetItem(i)).RealizePromoteState();
	}

	if (previousSelectedIndexOnFocusLost >= 0)
	{
		Navigator.SetSelected(List);
		List.SetSelectedIndex(previousSelectedIndexOnFocusLost);
		UIArmory_PromotionItem(List.GetSelectedItem()).SetSelectedAbility(SelectedAbilityIndex);
	}

	UpdateNavHelp();
}

simulated function string GetPromotionBlueprintTag(StateObjectReference UnitRef)
{
	local XComGameState_Unit UnitState;

	UnitState = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(UnitRef.ObjectID));
	if(UnitState.IsGravelyInjured())
		return default.DisplayTag $ "Injured";
	return string(default.DisplayTag);
}

simulated static function CycleToSoldier(StateObjectReference NewRef)
{
	local UIArmory_MainMenu MainMenu;

	super.CycleToSoldier(NewRef);
	
	// HELIOS BEGIN
	// Prevent the spawning of popups while we reload the promotion screen
	MainMenu = UIArmory_MainMenu(`SCREENSTACK.GetScreen(`PRESBASE.Armory_MainMenu));
	// HELIOS END
	MainMenu.bIsHotlinking = true;

	// Reload promotion screen since we might need a separate instance (regular or psi promote) depending on unit
	`SCREENSTACK.PopFirstInstanceOfClass(class'UIArmory_Promotion');
	MainMenu.OnClickArmoryPromotion();

	MainMenu.bIsHotlinking = false;
}

simulated function OnRemoved()
{
	if(ActorPawn != none)
	{
		// Restore the character's default idle animation
		XComHumanPawn(ActorPawn).CustomizationIdleAnim = '';
		XComHumanPawn(ActorPawn).PlayHQIdleAnim();
	}

	// Reset soldiers out of view if we're promoting this unit on top of the avenger.
	// NOTE: This can't be done in UIAfterAction.OnReceiveFocus because that function might trigger when user dismisses the new class cinematic.
	if(AfterActionScreen != none)
	{
		AfterActionScreen.ResetUnitLocations();
	}

	super.OnRemoved();
}

simulated function OnCancel()
{
	if( UIAfterAction(Movie.Stack.GetScreen(class'UIAfterAction')) != none || 
		class'XComGameState_HeadquartersXCom'.static.IsObjectiveCompleted('T0_M2_WelcomeToArmory') )
	{
		super.OnCancel();
	}
}

simulated function ShowAbilityInfoPopup()
{
	local XComGameState_Unit Unit;
	local array<AbilitySetupData> AbilityData;
	local array<string> Strings;
	local string Title, Text, TempHeader, TempDesc;
	local int i;

	Unit = GetUnit();	

	// 1st. Abilities
	AbilityData = Unit.GatherUnitAbilitiesForInit(, , true);
	for (i = 0; i < AbilityData.Length; ++i)
	{
		if (AbilityData[i].Template.bDontDisplayInAbilitySummary)
		{
			continue;
		}

		TempHeader = class'XComGameState_AnarchyUnrestResult'.static.FormatGoodHeader(AbilityData[i].Template.LocFriendlyName);
		TempDesc = AbilityData[i].Template.GetMyLongDescription(, Unit);

		if (TempHeader != "" && TempDesc != "")
		{
			Strings.AddItem(TempHeader);
			Strings.AddItem(TempDesc);
		}
	}

	if (Strings.Length > 0)
	{
		Title = `MAKECAPS(class'UIArmory_MainMenu'.default.m_strAbilities);
		Text = class'UIUtilities_Text'.static.StringArrayToNewLineList(Strings);
		`STRATPRES.UIWarningDialog(Title, Text, eDialog_Normal);
	}
}

simulated function ShowScarInfoPopup()
{
	local XComGameStateHistory History;
	local XComGameState_Unit Unit;
	local XComGameState_UnitScar Scar;
	local array<string> Strings;
	local string Title, Text, TempHeader, TempDesc;
	local int i;

	History = `XCOMHISTORY;
	Unit = GetUnit();

	for (i = 0; i < Unit.Scars.Length; ++i)
	{
		Scar = XComGameState_UnitScar(History.GetGameStateForObjectID(Unit.Scars[i].ObjectID));
		if (Scar == none)
		{
			continue;
		}

		TempHeader = class'XComGameState_AnarchyUnrestResult'.static.FormatWarningHeader(Scar.GetScarNameString());
		TempDesc = Scar.GetScarEffectsString();

		if (TempHeader != "" && TempDesc != "")
		{
			Strings.AddItem(TempHeader);
			Strings.AddItem(TempDesc);
		}
	}

	if (Strings.Length > 0)
	{
		Title = `MAKECAPS(class'DioStrategyNotificationsHelper'.default.ScarsEarnedTitle);
		Text = class'UIUtilities_Text'.static.StringArrayToNewLineList(Strings);
		`STRATPRES.UIWarningDialog(Title, Text, eDialog_Normal);
	}
}

//==============================================================================

simulated function AS_SetTitle(string Image, string TitleText, string ClassTitle)
{
	MC.BeginFunctionOp("setPromotionTitle");
	MC.QueueString(Image);
	MC.QueueString(TitleText);
	MC.QueueString(ClassTitle);
	MC.EndOp();
}

simulated static function bool CanCycleTo(XComGameState_Unit Unit)
{
	return !Unit.IsAndroid();
}

//==============================================================================

defaultproperties
{
	LibID = "PromotionScreenMC";
	bHideOnLoseFocus = false;
	bAutoSelectFirstNavigable = false;
	DisplayTag = "UIBlueprint_Promotion";
	CameraTag = "UIBlueprint_Promotion";
	previousSelectedIndexOnFocusLost = 0;
	SelectedAbilityIndex = 0;

	PropagandaMinRank = 5;
	bShowExtendedHeaderData = true;
}
