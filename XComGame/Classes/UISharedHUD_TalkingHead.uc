//---------------------------------------------------------------------------------------
//  *********   FIRAXIS SOURCE CODE   ******************
//  FILE:    UISharedHUD_TalkingHead.uc
//  PURPOSE:
//--------------------------------------------------------------------------------------- 

class UISharedHUD_TalkingHead extends UIScreen
	config(UI);

var GFxObject RootMC;
var GFxObject m_voiceObject;
var localized string m_strWhisper;
var localized string m_strSkipLine;
var bool m_consumeInput;
var UIDIOHUD DioHUD; 
var bool bLarge; 

var UINavigationHelp NavHelp;

var config array<name> DoNotMirrorCharacters; 



simulated function OnInit()
{
	super.OnInit();

	RootMC = Movie.GetVariableObject(MCPath $ "");

	OnCharacterVoice(m_voiceObject, true);
	ShowTalkingHead(true);

	Movie.InsertHighestDepthScreen(self, DioHUD);
	RegisterForScreenStackEvents();
}
//---------------------------------------------------------------------------------------

function RegisterForScreenStackEvents()
{
	local Object SelfObject;
	SelfObject = self;

	`XEVENTMGR.RegisterForEvent(SelfObject, 'UIEvent_ActiveScreenChanged', OnStackActiveScreenChanged, ELD_Immediate);
}

//---------------------------------------------------------------------------------------
function UnRegisterForEvents()
{
	local X2EventManager EventManager;
	local Object SelfObject;

	EventManager = `XEVENTMGR;
	SelfObject = self;

	EventManager.UnRegisterFromEvent(SelfObject, 'UIEvent_ActiveScreenChanged');
}

//---------------------------------------------------------------------------------------
//				INPUT HANDLER
//---------------------------------------------------------------------------------------

simulated function bool OnUnrealCommand(int cmd, int arg)
{
	local XComGameStateHistory History;
	local XComGameState_DialogueManager DialogueManager;

	// Only allow releases through past this point.
	if ((arg & class'UIUtilities_Input'.const.FXS_ACTION_RELEASE) == 0)
	{
		return false;
	}

	if (!m_consumeInput)
	{
		return false;
	}

	History = `XCOMHISTORY;
	DialogueManager = XComGameState_DialogueManager(History.GetSingleGameStateObjectForClass(class'XComGameState_DialogueManager'));

	switch (cmd)
	{
	case class'UIUtilities_Input'.const.FXS_BUTTON_A :
	case class'UIUtilities_Input'.const.FXS_BUTTON_B :
	case class'UIUtilities_Input'.const.FXS_KEY_SPACEBAR :
	case class'UIUtilities_Input'.const.FXS_KEY_ENTER :
		PlayMouseClickSound();
		DialogueManager.SkipCurrentVOLine();
		break;
	case class'UIUtilities_Input'.const.FXS_BUTTON_Y :
	case class'UIUtilities_Input'.const.FXS_KEY_TAB:
`if (`notdefined(FINAL_RELEASE))
		`SOUNDMGR.ExitCOPsState();
		PlayMouseClickSound();
		DialogueManager.StopCurrentConversation();
		Movie.Pres.ShowUIForCinematics();
`endif
		break;
	case class'UIUtilities_Input'.const.FXS_KEY_ESCAPE :
	case class'UIUtilities_Input'.const.FXS_BUTTON_START :
		DialogueManager.StopCurrentConversation();
		Movie.Pres.UIPauseMenu();
		break;
	default:
		break;
	}

	return true;
}

function OnCharacterVoice(GFxObject CharacterVoice, bool Activated)
{
	RootMC.ActionScriptVoid("OnCharacterVoice");
	if( DioHUD == none )
	{
		// HELIOS BEGIN
		// Replace the hard reference with a reference to the main HUD
		DioHUD = UIDIOHUD(`SCREENSTACK.GetScreen(`PRESBASE.UIHUD_Strategy));
		// HELIOS END
		if (DioHUD != None)
		{
			if (!DioHUD.bIsInited || !DioHUD.bIsVisible)
			{
				DioHUD.Show();
			}
		}
	}
	
	if(bLarge)
		DioHUD.UpdateResources(self); //Refreshed visuals for what should show/hide beneath this screen in the HUD. 
}

function ShowTalkingHead(bool isShowing)
{
	local bool inPreBreach;

	if (isShowing)
	{
		Show();

		inPreBreach = `BATTLE != none && `BATTLE.GetDesc().IsInBreachSelection();

		MC.FunctionBool("ShowTalkingHeadWidget", inPreBreach);
		if(bLarge)
			DioHUD.UpdateResources(self); //Refreshed visuals for what should show/hide beneath this screen in the HUD. 
	}
	else
	{
		Hide();
	}
}

function MakeUnitVoice(XComGameState_Unit UnitState, optional string DialogueLineText = "", optional string Emotion = "", optional bool conversationOriginator = true)
{
	local X2SoldierClassTemplate soldierClassTemplate;
	local X2CharacterTemplate characterTemplate;
	local bool bIsSoldier, bUseMirror;
	local string profileicon, iconPath, archetypePath, imagePrefix;

	if (m_voiceObject == None)
	{
		m_voiceObject = Movie.CreateObject("Object", , false);
	}

	m_voiceObject.SetFloat("objectID", UnitState.ObjectID);

	soldierClassTemplate = UnitState.GetSoldierClassTemplate();
	characterTemplate = UnitState.GetMyTemplate();
	bIsSoldier = (soldierClassTemplate != none);

	m_voiceObject.SetString("soldierNick", bIsSoldier ? UnitState.GetNickName(true) : characterTemplate.strCharacterName);

	if (Emotion == "")
	{
		if (characterTemplate != none && characterTemplate.ChatterIcon != "")
		{
			iconPath = characterTemplate.ChatterIcon;
		}
		else if (soldierClassTemplate != none)
		{
			iconPath = soldierClassTemplate.ProfileIconImage;
		}
	}
	else
	{
		profileicon = bIsSoldier ? soldierClassTemplate.NarrativeImage : characterTemplate.COPSIcon;
		iconPath = profileicon$"_"$Emotion;

		archetypePath = iconPath;
		imagePrefix = "img:///";
		if (InStr(archetypePath, imagePrefix) != INDEX_NONE)
		{
			// trim off the img prefix. will cause issues when searching for outer most
			archetypePath = right(archetypePath, Len(archetypePath) - Len(imagePrefix));
		}

		// This expects these images to be preloaded in UXComGameState_DialogueManager::RequestResources
		if (Texture2D(`CONTENT.RequestGameArchetype(archetypePath)) == none)
		{
			iconPath = profileicon;
		}
	}

	//For anyone who does not yet have an image defined, use the temp default image. 
	if(iconPath == "" )
	{
		iconPath = "img:///UILibrary_Common.ChatterPortraits.Chatter_Unknown";
	}

	bLarge = (Emotion != "");

	m_voiceObject.SetString("icon", class'UIUtilities_Image'.static.ValidateImagePath(iconPath));
	m_voiceObject.SetBool("useLarge", bLarge);
	m_voiceObject.SetString("lineText", DialogueLineText);

	if(DoNotMirrorCharacters.Find(characterTemplate.DataName) > -1)
	{
		bUseMirror = false;
	}
	else
	{
		bUseMirror = !conversationOriginator;
	}

	m_voiceObject.SetBool("useMirror", bUseMirror);
}

function EventListenerReturn OnUnitVoiceStarted(Object EventData, Object EventSource, XComGameState GameState, Name Event, Object CallbackData)
{
	local XComGameState_Unit UnitState;
	local XComGameState_DialogueManager DialogueManager;
	local string DialogueLineText;
	local string Emotion;
	local bool conversationOriginator;
	
	DialogueManager = XComGameState_DialogueManager(EventData);
	UnitState = XComGameState_Unit(EventSource);

	if (DialogueManager == None && UnitState == None)
		return ELR_NoInterrupt;

	DialogueLineText = DialogueManager.lastPlayedResponseLine.LineText;

	Emotion = DialogueManager.lastPlayedResponseLine.Emotion;

	Movie.InsertHighestDepthScreen(self, DioHUD);

	if (Emotion != "")
	{
		m_consumeInput = true;
		Movie.Pres.HideUIForCinematics();
		
		if ((DialogueManager.lastPlayedLineRuntimeInfo.ConversationOriginatorObjectID == -1 && UnitState == None) ||
			DialogueManager.lastPlayedLineRuntimeInfo.ConversationOriginatorObjectID == UnitState.ObjectID)
		{
			conversationOriginator = true;
		}
		else
		{
			conversationOriginator = false;
		}

		if (NavHelp == None)
		{
			NavHelp = Spawn(class'UINavigationHelp', self).InitNavHelp();
			if (`ISCONTROLLERACTIVE)
			{
				NavHelp.bIsVerticalHelp = `ISCONTROLLERACTIVE;
				NavHelp.AddCenterHelp(m_strSkipLine, class'UIUtilities_Input'.static.GetAdvanceButtonIcon()); // mmg_aaron.lee (11/24/19) - change from icon string to GetAdvanceButtonIcon to reflect enter button assignment.
			}
			else
			{
				NavHelp.AddContinueButton(SkipCurrentVOLine, 'DioButton', m_strSkipLine, false);
			}
		}

		`SOUNDMGR.EnterCOPsState();
	}
	else
	{
		m_consumeInput = false;
	}

	MakeUnitVoice(UnitState, DialogueLineText, Emotion, conversationOriginator);
	if (bIsInited)
	{
		OnCharacterVoice(m_voiceObject, true);
		ShowTalkingHead(true);
	}

	return ELR_NoInterrupt;
}

function EventListenerReturn OnUnitVoiceEnded(Object EventData, Object EventSource, XComGameState GameState, Name Event, Object CallbackData)
{
	local XComGameState_Unit UnitState;
	local XComGameState_DialogueManager DialogueManager;
	local name emptyName;

	DialogueManager = XComGameState_DialogueManager(EventData);
	UnitState = XComGameState_Unit(EventSource);

	MakeUnitVoice(UnitState);
	
	if(DialogueManager.lastPlayedResponseLine.FollowUpEvent == emptyName)
	{
		OnCharacterVoice(m_voiceObject, false);
		Movie.Pres.ShowUIForCinematics();
		CloseScreen();

		`SOUNDMGR.ExitCOPsState();
	}
	else
	{
		OnCharacterVoice(m_voiceObject, true);
	}

	return ELR_NoInterrupt;
}

simulated function CloseScreen()
{
	local XComPresentationLayerBase Presentation;
	local UIDayTransitionScreen DayTransition;	

	//DO NOT call super. This screen may not be in the stack, which is ok.
	
	PlayMenuCloseSound();
	Movie.RemoveHighestDepthScreen(self);
	
	if(`ScreenStack.GetScreen(class'UISharedHUD_TalkingHead') != none )
	{
		Movie.Stack.Pop(self);
	}
	else
	{
		Movie.RemoveScreen(self);
	}

	`STRATPRES.ForceRefreshActiveScreenChanged();

	Presentation = XComPlayerController(class'UIInteraction'.static.GetLocalPlayer(0).Actor).Pres;
	Presentation.m_kTalkingHead = None;

	// HELIOS BEGIN
	DayTransition = UIDayTransitionScreen(`SCREENSTACK.GetScreen(`PRESBASE.UIDayTransitionScreen));
	//HELIOS END
	if (!(DayTransition != none && DayTransition.bIsFocused))
	{		
		//Don't route this if the player is in squad select. Transitions out of squad select will do this if needed.
		if (UIDIOSquadSelect(`SCREENSTACK.GetCurrentScreen()) == none) 
		{
			DioHUD.UpdateResources(`SCREENSTACK.GetCurrentScreen());
		}
	}
}
simulated function SkipCurrentVOLine()
{
	local XComGameStateHistory History;
	local XComGameState_DialogueManager DialogueManager;

	PlayMouseClickSound();

	History = `XCOMHISTORY;
	DialogueManager = XComGameState_DialogueManager(History.GetSingleGameStateObjectForClass(class'XComGameState_DialogueManager'));

	DialogueManager.SkipCurrentVOLine();
}

function EventListenerReturn OnStackActiveScreenChanged(Object EventData, Object EventSource, XComGameState GameState, Name Event, Object CallbackData)
{
	if( UIArmoryLandingArea(EventData) != none || UIArmory(EventData) != none )
	{
		if( DioHUD.m_ArmoryUnitHeads.Length > 6 ) // We only need the adjustment in armory, with many agents. 
			MC.FunctionString("UpdateLayoutForArea", "Armory");
		else
			MC.FunctionString("UpdateLayoutForArea", ""); //No area 
	}
	else
	{
		MC.FunctionString("UpdateLayoutForArea", ""); //No area 
	}

	return ELR_NoInterrupt;
}
defaultproperties
{
	LibID = "DioNarrativeController";
	
	bShowDuringCinematic = true;
	bHideOnLoseFocus = false;
}
