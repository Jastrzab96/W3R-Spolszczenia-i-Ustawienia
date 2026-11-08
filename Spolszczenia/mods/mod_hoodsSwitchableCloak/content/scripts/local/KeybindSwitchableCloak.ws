/*
	Script author: Priler
	https://next.nexusmods.com/profile/Priler?gameId=952

	Mod Github page: https://github.com/Priler/SwitchableCloak
*/

@addField( CR4Player )
public var ArdCloakSwitch : KeybindSwitchableCloak;

@wrapMethod( CR4Player ) function OnSpawned( spawnData : SEntitySpawnData )
{
	ArdCloakSwitch = new KeybindSwitchableCloak in this;
	ArdCloakSwitch.Init();

	wrappedMethod(spawnData);

	SetVanityValidationTimer();
}

@wrapMethod( CR4Player ) function OnStartFistfightMinigame()
{
	// thePlayer.ArdCloakSwitch.InitVanityItemState();
	//if (GetWitcherPlayer().IsInFistFight() && !thePlayer.IsInFistFightMiniGame()) {
	thePlayer.ArdCloakSwitch.UnequipVanityItemDuringFistFightMinigame();
	//}

	wrappedMethod();
}

@wrapMethod( CR4Player ) function OnEndFistfightMinigame()
{
	// thePlayer.ArdCloakSwitch.InitVanityItemState();
	//if (GetWitcherPlayer().IsInFistFight() && !thePlayer.IsInFistFightMiniGame()) {
	thePlayer.ArdCloakSwitch.EquipVanityItemAfterFistFightMinigame();
	//}

	wrappedMethod();
}

@addMethod(CR4Player) function SetToggleVanityItemOnTimer()
{
	if (thePlayer.ArdCloakSwitch.GetVanityItemType() == VanityCloak) {
		// Cloak etc timer
		AddTimer( 'TimerToggleVanityItemOn', 1.9, false );
	} else {
		// Hoods etc timer
		AddTimer( 'TimerToggleVanityItemOn', 0.7, false );
	}
}

@addMethod(CR4Player) function SetToggleVanityItemOffTimer()
{
	if (thePlayer.ArdCloakSwitch.GetVanityItemType() == VanityCloak) {
		// Cloak etc timer
		AddTimer( 'TimerToggleVanityItemOff', 1.7, false );
	} else {
		// Hoods etc timer
		AddTimer( 'TimerToggleVanityItemOff', 0.7, false );
	}
}

@addMethod(CR4Player) timer function TimerToggleVanityItemOff( dt : float, it : int )
{
	ArdCloakSwitch.UnequipVanityItem();
}

@addMethod(CR4Player) timer function TimerToggleVanityItemOn( dt : float, it : int )
{
	ArdCloakSwitch.EquipVanityItem();
}


@addField( CR4Player )
public var _vanityItemChangedCheckTimer: float;

@addMethod(CR4Player) function SetVanityValidationTimer()
{
	/*
	@TODO: Rewrite using hooks?
	*/
	AddTimer( 'TimerVanityValidation', 15, false ); // check every 10 seconds
}

@addMethod(CR4Player) timer function TimerVanityValidation( dt : float, it : int )
{

	thePlayer.ArdCloakSwitch.ValidateEquippedVanityItem();

	SetVanityValidationTimer(); // loop the timer
}

@wrapMethod(CR4Player) function OnWeatherChanged()
{
	wrappedMethod();

	thePlayer.ArdCloakSwitch.OnWeatherChanged();
}

@wrapMethod(CR4Player) function OnCombatStart()
{
	wrappedMethod();

	thePlayer.ArdCloakSwitch.OnCombatStart();
}

@wrapMethod(CR4Player) function OnCombatFinished()
{
	wrappedMethod();

	thePlayer.ArdCloakSwitch.OnCombatFinished();
}

@wrapMethod(CStoryScenePlayer) function OnBlockingSceneStarted( scene: CStoryScene )
{
	wrappedMethod(scene);

	thePlayer.ArdCloakSwitch.OnBlockingSceneStarted(scene);
}

@wrapMethod(CStoryScenePlayer) function OnBlockingSceneEnded( output : CStorySceneOutput )
{
	wrappedMethod(output);

	thePlayer.ArdCloakSwitch.OnBlockingSceneEnded(output);
}

// @wrapMethod(CPlayer) function OnBlockingSceneEnded()
// {
// 	wrappedMethod();
// }

@wrapMethod(CR4Player) function OnInteriorStateChanged( inInterior : bool )
{
	wrappedMethod(inInterior);

	thePlayer.ArdCloakSwitch.SetIsInterior(inInterior);
	AddTimer( 'TimerInteriorEnvsUpdateDelay', 0.5f, false ); // delay required, in order to detect dark placesd (like caves, dungeons etc)
	// thePlayer.ArdCloakSwitch.OnInteriorStateChanged(inInterior);
}

@wrapMethod(CExplorationStateManager) function PostStateChange()
{
	wrappedMethod();

	if (m_StatesSArr[ m_StateCurI ].m_InputContextE == EGCI_Swimming) {
		// swimming
		thePlayer.ArdCloakSwitch.OnSwimming(true);
	} else
		// any other state
		thePlayer.ArdCloakSwitch.OnSwimming(false);
}

@addMethod(CR4Player) timer function TimerInteriorEnvsUpdateDelay( dt : float, it : int )
{
	thePlayer.ArdCloakSwitch.OnInteriorStateChanged();
}

// @wrapMethod(CR4Player) function IsInDarkPlace()
// {
// 	LogChannel('modSwitchableCloak', "GetVanityItemState: " + GetVanityItemState());
// }

//@wrapMethod(CHairCutSceneChoiceAction) function GetActionIcon()
//{
//	thePlayer.ArdCloakSwitch.InitVanityItemState();
	//if (GetWitcherPlayer().IsInFistFight() && !thePlayer.IsInFistFightMiniGame()) {
//	thePlayer.ArdCloakSwitch.UnequipVanityItemDuringFistFightMinigame();
	//}
//
//	wrappedMethod();
//}

@addMethod( W3PlayerWitcher ) public function SwitchableCloakCPWInvisibilityCloak()
{
	// Crutch for compatibility patch w/Cloak of Invisibility mod
}

enum VanityItemState
{
	VanityItemUnknown,
	VanityItemOn,
	VanityItemOff
}

enum VanityItemType
{
	VanityUnknown,
	VanityCloak,
	VanityHood
}

exec function ISC()
{
	LogChannel('modSwitchableCloak', "ISC: " + theGame.isCutscenePlaying);
}

class KeybindSwitchableCloak
{

	protected var lastEquippedVanityItem: SItemUniqueId;
	protected var factsLoaded : bool; default factsLoaded = false;
	protected var vanityItemState: VanityItemState; default vanityItemState = VanityItemUnknown; // get only
	protected var vanityType: VanityItemType; default vanityType = VanityUnknown; // get only
	protected var lastVanityType: VanityItemType; default lastVanityType = VanityUnknown;
	protected var toggleDisabled: bool; default toggleDisabled = false;
	protected var isPlayerSwimming: bool; default isPlayerSwimming = false;
	protected var isInInterior: bool; default isInInterior = false;

	protected var autoUnequippedInCombat: bool; default autoUnequippedInCombat = false;
	protected var autoUnequippedInInterior: bool; default autoUnequippedInInterior = false;
	protected var autoUnequippedInCutscene: bool; default autoUnequippedInCutscene = false;
	protected var autoUnequippedDuringSwimming: bool; default autoUnequippedDuringSwimming = false;

	protected var autoUnequippedDuringFistFightMiniGame: bool; default autoUnequippedDuringFistFightMiniGame = false;
	protected var autoUnequippedDuringBarberVisit: bool; default autoUnequippedDuringBarberVisit = false;

	private 		var previousWeather 				: name;
	private 		var previousRainStrength			: float;

	// comp. patch w/Invisibility Cloak mod
	protected var compatibilityWithInvisibilityCloak__Enabled: bool; default compatibilityWithInvisibilityCloak__Enabled = false;
	protected var compatibilityWithInvisibilityCloak__CloakName: CName; default compatibilityWithInvisibilityCloak__CloakName = 'Cloak of Invisibility';

	/*
		@TODO:
		- (CANCEL) backward settings restore? via facts system maybe
		+ mod enabled/disabled (via mod menu)
		+ check/fix on cutscene auto-unequip
		+ double commenting on auto-equip in bad weather
		+ auto unequip during swimming (and equip back after)
		+ (added as additional option) fix auto equip during strong wind (it should not be considered bad weather)
		+ add on/off to auto re-equip after barber visit (so user can turn it off, to always view new haircut) ?add in the proper auto-unequip section, maybe
		+ add on/off to auto re-equip after fist fight? (if possible)

		- add an option to enable masks only

		- Auto equip-back cloak/cape after the good weather returns? (if was auto unequipped before)
		- Fix cloak/cape appear on Ciri (possible auto-equip issue) + disable cloak toggle for Ciri
		- No auto equip-back after death

		- Fix swimming not being auto-unequiped when jumping into the water (https://www.youtube.com/watch?v=Z-2-bacyr7g)

		- The mod doesn't work at all when you're on horseback and the weather is bad

		- Doesn't work with Professor's spectacles unfortunately (and Tourney champion's laurels, idk about any other "masks")

		- Add a feature to automatically unequip the cloak after harsh weather passes (basically auto-equip back after bad weather)

		- [bug] Equips back after cutscene/fist fight even if there was no cloak before

		- HOODS lower/raise animation???? (check how it's implemented and its source code)
	*/

	public function Init() {
		// init base values
		factsLoaded = false;
		vanityItemState = VanityItemUnknown;

		// init listeners
		theInput.RegisterListener(this, 'OnToggleVanityItem', 'SwitchCloak');

		// backward compatibility with previous versions
		// BackwardCompatibilityRestoreSettings();
	}


	event OnToggleVanityItem(action: SInputAction)
	{
		var stateMachine: SwitchableCloakStateMachine;

		if (!IsPressed(action) || toggleDisabled || !IsModEnabled())
			return false;

		stateMachine = GetSwitchableCloakStateMachine();

		if (!stateMachine || stateMachine.IsPlayingAnim())
			return false;

		if (!ModGetConfigValueBool('ModSwitchableCloakGeneral', 'AllowSwitchOnHorse') && thePlayer.IsInState( 'HorseRiding' ))
			return false;

		// just do it
		toggleDisabled = true;
		ToggleVanityItem();

		return true;
	}


	public function EnableToggle()
	{
		toggleDisabled = false;
	}


	public function IsModEnabled(): bool
	{
		return ModGetConfigValueBool('ModSwitchableCloakGeneral', 'ModEnabled');
	}


	public function SetIsInterior(val: bool)
	{
		isInInterior = val;
	}


	public function OnSwimming(swimStarted: bool)
	{
		if (swimStarted == isPlayerSwimming)
			return;

		isPlayerSwimming = swimStarted;

		if (ModGetConfigValueBool('ModSwitchableCloakOther', 'IsDebugEnabled'))
			theGame.GetGuiManager().ShowNotification("On swimming TRIGGERED!");

		if (!IsModEnabled())
			return;

		InitFacts();

		LogChannel('modSwitchableCloak', "OnSwimming("+swimStarted+")");

		if (ModGetConfigValueBool('ModSwitchableCloakAutoUnequip', 'AutoUnequipCloaksOnly') && lastVanityType != VanityCloak) {

			// unequip cloaks/capes only (if set in mod menu)
			// if it's not cloak/cape, return
			LogChannel('modSwitchableCloak', "Equipped vanity item is NOT cloak/cape!");
			return;
		}

		LogChannel('modSwitchableCloak', "isPlayerSwimming: "+isPlayerSwimming);

		if (isPlayerSwimming) {
			// swimming started

			if ( GetVanityItemState() == VanityItemOn && // if vanity item is equipped
				ModGetConfigValueBool('ModSwitchableCloakAutoUnequip', 'AllowAutoUnequipDuringSwimming')) { // and auto-unequip during swimming is enabled

				autoUnequippedDuringSwimming = true; // remember it was auto-unequipped
				ToggleVanityItemOff(ModGetConfigValueBool('ModSwitchableCloakAutoUnequip', 'AutoUnequipIgnoreAnimation')); // unequip
			}
		} else {
			// possibly swimming ended? check.

			if (!autoUnequippedDuringSwimming)
				return; // procede only if it was previously auto-unequipped

			if ( GetVanityItemState() == VanityItemOff && // if vanity item is not equipped
				ModGetConfigValueBool('ModSwitchableCloakAutoUnequip', 'AllowAutoEquipBackAfterSwimming') && // and auto-equip-back after swimming is enabled
				(!theGame.IsDialogOrCutscenePlaying() 
					&& !thePlayer.IsInNonGameplayCutscene()
					&& !thePlayer.IsInGameplayScene()
					&& !theGame.IsCurrentlyPlayingNonGameplayScene() // and if not in cutscene (is there any swim state cutscenes?? IDK :3)
				)) {

				autoUnequippedDuringSwimming = false; // reset memory
				ToggleVanityItemOn(ModGetConfigValueBool('ModSwitchableCloakAutoUnequip', 'AutoUnequipIgnoreAnimation')); // equip back
			}
		}
	}


	public function OnCombatStart()
	{
		if (ModGetConfigValueBool('ModSwitchableCloakOther', 'IsDebugEnabled'))
			theGame.GetGuiManager().ShowNotification("On combat started TRIGGERED!");

		if (!IsModEnabled())
			return;

		InitFacts();

		LogChannel('modSwitchableCloak', "OnCombatStart()");
		LogChannel('modSwitchableCloak', "GetVanityItemState: " + GetVanityItemState());

		if (ModGetConfigValueBool('ModSwitchableCloakAutoUnequip', 'AutoUnequipCloaksOnly') && lastVanityType != VanityCloak) {

			// unequip cloaks/capes only (if set in mod menu)
			// if it's not cloak/cape, return
			LogChannel('modSwitchableCloak', "Equipped vanity item is NOT cloak/cape!");
			return;
		}

		if ( GetVanityItemState() == VanityItemOn && // if vanity item is equipped
			ModGetConfigValueBool('ModSwitchableCloakAutoUnequip', 'AllowAutoUnequipInCombat')) { // and auto-unequip in combat is enabled

			autoUnequippedInCombat = true; // remember it was auto-unequipped
			ToggleVanityItemOff(ModGetConfigValueBool('ModSwitchableCloakAutoUnequip', 'AutoUnequipIgnoreAnimation')); // unequip
		}
	}


	public function OnCombatFinished()
	{
		if (ModGetConfigValueBool('ModSwitchableCloakOther', 'IsDebugEnabled'))
			theGame.GetGuiManager().ShowNotification("On combat finished TRIGGERED!");

		if (!IsModEnabled())
			return;

		InitFacts();

		LogChannel('modSwitchableCloak', "OnCombatFinished()");
		LogChannel('modSwitchableCloak', "GetVanityItemState: " + GetVanityItemState());

		if (ModGetConfigValueBool('ModSwitchableCloakAutoUnequip', 'AutoUnequipCloaksOnly') && lastVanityType != VanityCloak) {

			// unequip cloaks/capes only (if set in mod menu)
			// if it's not cloak/cape, return
			LogChannel('modSwitchableCloak', "Equipped vanity item is NOT cloak/cape!");
			return;
		}

		if ( GetVanityItemState() == VanityItemOff && // if vanity item is not equipped
			ModGetConfigValueBool('ModSwitchableCloakAutoUnequip', 'AllowAutoEquipBackInCombat') && // and auto-equip-back in combat is enabled
			autoUnequippedInCombat && // and it was previously auto-unequipped
			(!theGame.IsDialogOrCutscenePlaying() 
				&& !thePlayer.IsInNonGameplayCutscene()
				&& !thePlayer.IsInGameplayScene()
				&& !theGame.IsCurrentlyPlayingNonGameplayScene() // and if not in cutscene
			)) {

			autoUnequippedInCombat = false; // reset memory
			ToggleVanityItemOn(ModGetConfigValueBool('ModSwitchableCloakAutoUnequip', 'AutoUnequipIgnoreAnimation')); // equip back
		}
	}


	public function OnBlockingSceneStarted(scene: CStoryScene)
	{
		var isStoryScene: bool;

		if (ModGetConfigValueBool('ModSwitchableCloakOther', 'IsDebugEnabled'))
			theGame.GetGuiManager().ShowNotification("On cutscene TRIGGERED!");

		if (!IsModEnabled())
			return;

		InitFacts();
		isStoryScene = StrContains(scene, "quests");

		LogChannel('modSwitchableCloak', "OnBlockingSceneStarted("+scene+")");
		LogChannel('modSwitchableCloak', "isStoryScene: " + isStoryScene);
		LogChannel('modSwitchableCloak', "GetVanityItemState: " + GetVanityItemState());

		if (!isStoryScene) {
			LogChannel('modSwitchableCloak', "Not a story scene.");
			return; // only auto-unequip on story scenes
		}

		if (ModGetConfigValueBool('ModSwitchableCloakAutoUnequip', 'AutoUnequipCloaksOnly') && lastVanityType != VanityCloak) {

			// unequip cloaks/capes only (if set in mod menu)
			// if it's not cloak/cape, return
			LogChannel('modSwitchableCloak', "Equipped vanity item is NOT cloak/cape!");
			return;
		}

		if ( GetVanityItemState() == VanityItemOn && // if vanity item is equipped
			ModGetConfigValueBool('ModSwitchableCloakAutoUnequip', 'AllowAutoUnequipInCutscenes')) { // and auto-unequip in cutscenes is enabled
			//isStoryScene) { // and story scene is playing (not merchants etc)

			autoUnequippedInCutscene = true; // remember it was auto-unequipped
			ToggleVanityItemOff(ModGetConfigValueBool('ModSwitchableCloakAutoUnequip', 'AutoUnequipIgnoreAnimation')); // unequip
		}
	}


	public function OnBlockingSceneEnded(output : CStorySceneOutput)
	{
		// var isStoryScene: bool;

		if (!IsModEnabled())
			return;

		if (ModGetConfigValueBool('ModSwitchableCloakOther', 'IsDebugEnabled'))
			theGame.GetGuiManager().ShowNotification("On cutscene TRIGGERED!");
		
		InitFacts();

		// isStoryScene = StrContains(scene, "quests");

		LogChannel('modSwitchableCloak', "OnBlockingSceneEnded("+output+")");
		// LogChannel('modSwitchableCloak', "isStoryScene: " + isStoryScene);
		LogChannel('modSwitchableCloak', "GetVanityItemState: " + GetVanityItemState());

		if (ModGetConfigValueBool('ModSwitchableCloakAutoUnequip', 'AutoUnequipCloaksOnly') && lastVanityType != VanityCloak) {

			// unequip cloaks/capes only (if set in mod menu)
			// if it's not cloak/cape, return
			LogChannel('modSwitchableCloak', "Equipped vanity item is NOT cloak/cape!");
			return;
		}

		if ( GetVanityItemState() == VanityItemOff && // if vanity item is not equipped
		 		  ModGetConfigValueBool('ModSwitchableCloakAutoUnequip', 'AllowAutoEquipBackInCutscenes') && // and auto-equip-back after cutscenes is enabled
		 		  //!isStoryScene && // and story scene is playing (not merchants etc)
				  autoUnequippedInCutscene) { // and it was previously auto-unequipped

			autoUnequippedInCutscene = false; // reset memory
			ToggleVanityItemOn(ModGetConfigValueBool('ModSwitchableCloakAutoUnequip', 'AutoUnequipIgnoreAnimation')); // equip back
		}
	}


	function OnInteriorStateChanged()
	{
		var envs : array< string >;
		var i: int;

		if (ModGetConfigValueBool('ModSwitchableCloakOther', 'IsDebugEnabled'))
			theGame.GetGuiManager().ShowNotification("On interior TRIGGERED!");

		if (!IsModEnabled())
			return;

		InitFacts();

		GetActiveAreaEnvironmentDefinitions( envs );

		LogChannel('modSwitchableCloak', "OnInteriorStateChanged("+isInInterior+")");
		LogChannel('modSwitchableCloak', "GetVanityItemState: " + GetVanityItemState());

		LogChannel('modSwitchableCloak', "Envs:");

		//for (i = 0; i < envs.Size(); i += 1) {
		//	LogChannel('modSwitchableCloak', envs[i]);
		//}

		if (theGame.IsDialogOrCutscenePlaying() 
				|| thePlayer.IsInNonGameplayCutscene()
				|| thePlayer.IsInGameplayScene()
				|| theGame.IsCurrentlyPlayingNonGameplayScene()) {

			// return, if interior state change was triggered during a cutscene
			// in other words, don't equip/unequip vanity item during cutscenes
			return;
		}

		if (!GetWitcherPlayer() || GetWitcherPlayer().IsInDarkPlace()) {

			// return, if interior is dark place (i.e. cave, dungeon etc)
			return;
		}

		if (ModGetConfigValueBool('ModSwitchableCloakAutoUnequip', 'AutoUnequipCloaksOnly') && lastVanityType != VanityCloak) {

			// unequip cloaks/capes only (if set in mod menu)
			// if it's not cloak/cape, return
			LogChannel('modSwitchableCloak', "Equipped vanity item is NOT cloak/cape!");
			return;
		}

		if ( GetVanityItemState() == VanityItemOn && // if vanity item is equipped
			ModGetConfigValueBool('ModSwitchableCloakAutoUnequip', 'AllowAutoUnequipInInterior') && // and auto-unequip in interior is enabled
			isInInterior) { // and is entering interior

			autoUnequippedInInterior = true; // remember it was auto-unequipped
			ToggleVanityItemOff(ModGetConfigValueBool('ModSwitchableCloakAutoUnequip', 'AutoUnequipIgnoreAnimation')); // unequip
		}
		else if ( GetVanityItemState() == VanityItemOff && // if vanity item is not equipped
		 		  ModGetConfigValueBool('ModSwitchableCloakAutoUnequip', 'AllowAutoEquipBackInInterior') && // and auto-equip-back when leaving interiors is enabled
		 		  !isInInterior && // and leaving interior
				  autoUnequippedInInterior) { // and it was previously auto-unequipped

			autoUnequippedInInterior = false; // reset memory
			ToggleVanityItemOn(ModGetConfigValueBool('ModSwitchableCloakAutoUnequip', 'AutoUnequipIgnoreAnimation')); // equip back
		}
	}


	public function OnWeatherChanged()
	{
		// auto-toggle cloaks (only) when it's raining, snow etc
		var l_weather: name;
		var rain_strength: float;
		var area_is_cold: bool;
		var conditions__storm : array<string>;
		var conditions__snow : array<string>;
		var perform_equip: bool;
		var perform_voiceset: string;

		if (ModGetConfigValueBool('ModSwitchableCloakOther', 'IsDebugEnabled'))
			theGame.GetGuiManager().ShowNotification("On weather changed TRIGGERED!");

		if (!IsModEnabled())
			return;

		InitFacts();

		perform_equip = false;
		l_weather = GetWeatherConditionName();
		rain_strength = GetRainStrength();
		area_is_cold = AreaIsCold();

		if( GetVanityItemState() == VanityItemOn // if not already equipped
			|| (ModGetConfigValueBool('ModSwitchableCloakAutoEquip', 'AutoEquipCloaksOnly') && lastVanityType != VanityCloak) // if it's not cloak (if only cloaks must be equipped, that is)
			|| (thePlayer.IsInInterior() && !ModGetConfigValueBool('ModSwitchableCloakAutoEquip', 'AutoEquipInInterior')) // if in interior etc (if not set otherwise)
			|| (thePlayer.GetCurrentStateName() != 'Exploration' && !ModGetConfigValueBool('ModSwitchableCloakAutoEquip', 'AutoEquipAnyState')) // if not in exploration state (if not set otherwise)
			|| (thePlayer.IsInCombat() && !ModGetConfigValueBool('ModSwitchableCloakAutoEquip', 'AutoEquipInCombat'))  // if in combat (if not set otherwise)
			|| ((theGame.IsDialogOrCutscenePlaying() 
				|| thePlayer.IsInNonGameplayCutscene()
				|| thePlayer.IsInGameplayScene()
				|| theGame.IsCurrentlyPlayingNonGameplayScene()) && !ModGetConfigValueBool('ModSwitchableCloakAutoEquip', 'AutoEquipInCutscenes') // if in cutscene (if not set otherwise)
			)
			|| theGame.IsFading()
			|| theGame.IsBlackscreen()
			|| !(ModGetConfigValueBool('ModSwitchableCloakAutoEquip', 'AllowAutoEquipWhenRain')
				|| ModGetConfigValueBool('ModSwitchableCloakAutoEquip', 'AllowAutoEquipWhenStorm')
				|| ModGetConfigValueBool('ModSwitchableCloakAutoEquip', 'AllowAutoEquipWhenSnow')
				|| ModGetConfigValueBool('ModSwitchableCloakAutoEquip', 'AllowAutoEquipWhenCold')) ) {

			LogChannel('modSwitchableCloak', "RETURN");
			LogChannel('modSwitchableCloak', "1: " + (GetVanityItemState() == VanityItemOn));
			LogChannel('modSwitchableCloak', "2: " + (ModGetConfigValueBool('ModSwitchableCloakAutoEquip', 'AutoEquipCloaksOnly') && lastVanityType != VanityCloak) + " (vanityType is "+lastVanityType+")");
			LogChannel('modSwitchableCloak', "3: " + thePlayer.IsInInterior());
			LogChannel('modSwitchableCloak', "4: " + (thePlayer.GetCurrentStateName() != 'Exploration'));

			previousRainStrength 	= rain_strength;
			previousWeather 		= l_weather;

			return;
		}

		// conditions__storm.PushBack("Storm");
		// conditions__storm.PushBack("Rain");
		// conditions__storm.PushBack("Rain");
		// conditions__snow.PushBack("Snow");
		// conditions__snow.PushBack("Clouds");

		// cold weather
		if (((l_weather == 'WT_Mid_Clouds' && (area_is_cold && previousWeather == 'WT_Clear')) ||
			 (l_weather == 'WT_Light_Clouds' && (area_is_cold && previousWeather == 'WT_Clear'))) &&
			 ModGetConfigValueBool('ModSwitchableCloakAutoEquip', 'AllowAutoEquipWhenCold')) {
			perform_equip = true;
			perform_voiceset = 'WeatherCold';

		// rain weather
		} else if (((rain_strength > 0.5f) ||
					(l_weather == 'WT_Light_Clouds' && (previousRainStrength < rain_strength)) ||
					(l_weather == 'WT_Heavy_Clouds_Dark' && (previousRainStrength < rain_strength))) &&
				   ModGetConfigValueBool('ModSwitchableCloakAutoEquip', 'AllowAutoEquipWhenRain')) {
			perform_equip = true;
			perform_voiceset = 'WeatherLooksLikeRain';

		// storm weather
		// } else if (StringContainsAnySubstring(l_weather, conditions__storm) && ModGetConfigValueBool('ModSwitchableCloakAutoEquip', 'AllowAutoEquipWhenStorm')) {
		} else if ((l_weather == 'WT_Rain_Storm') && ModGetConfigValueBool('ModSwitchableCloakAutoEquip', 'AllowAutoEquipWhenStorm')) {
			perform_equip = true;
			perform_voiceset = 'WeatherStormy';

		// snow weather
		} else if ((l_weather == 'WT_Snow' ||
					(l_weather == 'WT_Mid_Clouds' && (area_is_cold && previousWeather == 'WT_Clear')) ||
				    (l_weather == 'WT_Light_Clouds' && (area_is_cold && previousWeather == 'WT_Clear'))) &&
				   ModGetConfigValueBool('ModSwitchableCloakAutoEquip', 'AllowAutoEquipWhenSnow')) {
			perform_equip = true;
			perform_voiceset = 'WeatherSnowy';
		
		// windy weather
		} else if ((l_weather == 'WT_Mid_Clouds_Dark' ||
				   (l_weather == 'WT_Mid_Clouds_Dark' && (previousWeather != 'WT_Mid_Clouds_Dark' && previousWeather != 'WT_Heavy_Clouds_Dark')) ||
				   (l_weather == 'WT_Heavy_Clouds_Dark' && (!thePlayer.IsOnBoat() && rain_strength < previousRainStrength))) &&
				   ModGetConfigValueBool('ModSwitchableCloakAutoEquip', 'AllowAutoEquipWhenWindy')) {
			perform_equip = true;
			perform_voiceset = 'WeatherWindy';

		}

		// perform equip
		if (perform_equip) {
			if (ModGetConfigValueBool('ModSwitchableCloakAutoEquip', 'AllowCommentingOnAutoEquip')) {
				thePlayer.StopAllVoicesets();
				thePlayer.PlayVoiceset(90, perform_voiceset, true); // break current speech
			}

			ToggleVanityItemOn(ModGetConfigValueBool('ModSwitchableCloakAutoEquip', 'AutoEquipIgnoreAnimation')); // equip
		}

		previousRainStrength 	= rain_strength;
		previousWeather 		= l_weather;
	}


	public function OnBarberSceneOn()
	{
		thePlayer.ArdCloakSwitch.InitVanityItemState();
		thePlayer.ArdCloakSwitch.UnequipVanityItemDuringBarber();
	}


	public function OnBarberSceneOff()
	{
		thePlayer.ArdCloakSwitch.InitVanityItemState();
		thePlayer.ArdCloakSwitch.EquipVanityItemAfterBarber();
	}


	public function GetlastEquippedVanityItem(): SItemUniqueId
	{
		return lastEquippedVanityItem;
	}


	public function InitVanityItemState() {
		if (GetVanityItemState() != VanityItemUnknown)
			return; // already initialized

		// init cloak state
		if(GetEquippedVanityItem() != GetInvalidUniqueId()) {
			if (ModGetConfigValueBool('ModSwitchableCloakOther', 'IsDebugEnabled'))
				theGame.GetGuiManager().ShowNotification("Cloak state is ON");

			SetVanityItemState(VanityItemOn);
		} else {
			if (ModGetConfigValueBool('ModSwitchableCloakOther', 'IsDebugEnabled'))
				theGame.GetGuiManager().ShowNotification("Cloak state is OFF");

			SetVanityItemState(VanityItemOff);
		}
	}


	protected function SetVanityItemState(newState: VanityItemState)
	{
		vanityItemState = newState;
	}


	public function GetVanityItemState(): VanityItemState
	{
		return vanityItemState;
	}


	public function GetVanityItemType(): VanityItemType
	{
		return vanityType;
	}

	public function ValidateEquippedVanityItem(): bool
	{
		var equippedVanityItem: SItemUniqueId;

		if (!IsModEnabled())
			return false;

		// get the cloak
		equippedVanityItem = GetEquippedVanityItem();

		InitFacts();

		if (equippedVanityItem != GetInvalidUniqueId() && ItemToFlashUInt(equippedVanityItem) == ItemToFlashUInt(lastEquippedVanityItem)) {
			if (ModGetConfigValueBool('ModSwitchableCloakOther', 'IsDebugEnabled'))
				theGame.GetGuiManager().ShowNotification("Vanity Validation: GOOD.");

			SetVanityItemState(VanityItemOn);

			return false; // nothing changed, it's the same vanity item
		} else if (equippedVanityItem != GetInvalidUniqueId()) {
			// other vanity item is equipped, re-save

			SetVanityItemState(VanityItemOn);

			lastEquippedVanityItem = equippedVanityItem;
			SaveLastUsedVanityItem(lastEquippedVanityItem);

			if (ModGetConfigValueBool('ModSwitchableCloakOther', 'IsDebugEnabled'))
				theGame.GetGuiManager().ShowNotification("Vanity Validation: CHANGED.");

			return true; // return true when vanity item is changed
		} else {
			// no vanity items equipped
			SetVanityItemState(VanityItemOff);

			if (ModGetConfigValueBool('ModSwitchableCloakOther', 'IsDebugEnabled'))
				theGame.GetGuiManager().ShowNotification("Vanity Validation: UNEQUIPPED.");

			return false;
		}
	}


	function GetEquippedVanityItem(): SItemUniqueId
	{
		var equippedItems: array<SItemUniqueId>;

		if (!GetWitcherPlayer())
			return GetInvalidUniqueId();

		equippedItems = GetWitcherPlayer().GetEquippedItems();
		return SearchForVanityItem(equippedItems);
	}


	public function ToggleVanityItem()
	{
		var result: bool;

		InitVanityItemState();

		if (!IsModEnabled())
			return;

		// cannot toggle cloak durning fist fight minigame
		if (thePlayer.IsFistFightMinigameEnabled())
			return;

		if(GetVanityItemState() == VanityItemOn) {
			// unequip cloak
			result = ToggleVanityItemOff(false);

			if(!result) {
				// for some reason toggle can't be done (no cloak found etc)
				toggleDisabled = false;
			}
		} else {
			// equip cloak
			result = ToggleVanityItemOn(false);

			if(!result) {
				// for some reason toggle can't be done (no cloak found etc)
				toggleDisabled = false;
			}
		}
	}


	public function ToggleVanityItemOff(forceIgnoreAnim: bool): bool
	{
		var equippedVanityItem: SItemUniqueId;
		var stateMachine: SwitchableCloakStateMachine;

		LogChannel('modSwitchableCloak', "ToggleVanityItemOff("+forceIgnoreAnim+")");

		InitFacts();
		InitVanityItemState();

		if (GetVanityItemState() != VanityItemOn) {
			if (ModGetConfigValueBool('ModSwitchableCloakOther', 'IsDebugEnabled'))
				theGame.GetGuiManager().ShowNotification("Cloak is already OFF ...");

			LogChannel('modSwitchableCloak', "already off");

			return false; // already off
		}

		// get the cloak
		equippedVanityItem = GetEquippedVanityItem();

		if (equippedVanityItem == GetInvalidUniqueId()) {
			if (ModGetConfigValueBool('ModSwitchableCloakOther', 'IsDebugEnabled'))
				theGame.GetGuiManager().ShowNotification("No equipped cloak found ...");

			LogChannel('modSwitchableCloak', "no equipped cloak found");

			return false; // no equipped cloak found
		}

		// equipped cloak found
		if (ModGetConfigValueBool('ModSwitchableCloakOther', 'IsDebugEnabled'))
			theGame.GetGuiManager().ShowNotification("Equipped Clock Found! Unequipping ...");

		// store
		lastEquippedVanityItem = equippedVanityItem;
		SaveLastUsedVanityItem(lastEquippedVanityItem);

		stateMachine = GetSwitchableCloakStateMachine();

		if (stateMachine && vanityType == VanityCloak && ModGetConfigValueBool('ModSwitchableCloakGeneral', 'PlayCloakAnimations') && !forceIgnoreAnim) {
			// unequip with cloak animation
			if (!stateMachine.SetCapeOffAnim())
				UnequipVanityItem();
			//thePlayer.SetToggleVanityItemOffTimer();
		} else if (stateMachine && vanityType == VanityHood && ModGetConfigValueBool('ModSwitchableCloakGeneral', 'PlayHoodAnimations') && !forceIgnoreAnim) {
			// unequip with hood animation
			if (!stateMachine.SetHoodOffAnim())
				UnequipVanityItem();
			//thePlayer.SetToggleVanityItemOffTimer();
		} else {
			// unequip without animation
			UnequipVanityItem();
		}

		return true;
	}


	public function ToggleVanityItemOn(forceIgnoreAnim: bool): bool
	{
		var equippedVanityItem: SItemUniqueId;
		var stateMachine: SwitchableCloakStateMachine;

		LogChannel('modSwitchableCloak', "ToggleVanityItemOn("+forceIgnoreAnim+")");

		InitVanityItemState();

		if (GetVanityItemState() != VanityItemOff) {
			if (ModGetConfigValueBool('ModSwitchableCloakOther', 'IsDebugEnabled'))
				theGame.GetGuiManager().ShowNotification("Cloak is already ON ...");

			LogChannel('modSwitchableCloak', "already on");

			return false; // already on
		}

		InitFacts();

		// get the cloak
		equippedVanityItem = GetEquippedVanityItem();

		if (equippedVanityItem != GetInvalidUniqueId() && ItemToFlashUInt(equippedVanityItem) == ItemToFlashUInt(lastEquippedVanityItem)) {
			// already on (the same as memorized)
			LogChannel('modSwitchableCloak', "equippedVanityItem already on!");
			if (ModGetConfigValueBool('ModSwitchableCloakOther', 'IsDebugEnabled'))
				theGame.GetGuiManager().ShowNotification("Already equipped");

			SetVanityItemState(VanityItemOn);
			return ToggleVanityItemOff(false);
		} else if (equippedVanityItem != GetInvalidUniqueId()) {
			// other vanity item is equipped
			LogChannel('modSwitchableCloak', "other vanity item is equipped");

			SetVanityItemState(VanityItemOn);
			return ToggleVanityItemOff(false);
		} else {
			// no vanity items equipped, equip lastUsed if possible
			LogChannel('modSwitchableCloak', "no vanity items equipped, equip lastUsed if possible");
			if (lastEquippedVanityItem != GetInvalidUniqueId()) {
				if (ModGetConfigValueBool('ModSwitchableCloakOther', 'IsDebugEnabled'))
					theGame.GetGuiManager().ShowNotification("Equipped last used cloak!");

				// check if item is in inventory
				if (!thePlayer.GetInventory().HasItemById(lastEquippedVanityItem)) {
					LogChannel('modSwitchableCloak', "Last equipped vanity item NOT FOUND");
					if (ModGetConfigValueBool('ModSwitchableCloakOther', 'IsDebugEnabled'))
						theGame.GetGuiManager().ShowNotification("Last equipped vanity item NOT FOUND");

					return false; // vanity item not found anymore (has been selled/dropped etc)
				}

				LogChannel('modSwitchableCloak', "~~~");
				LogChannel('modSwitchableCloak', "lastVanityType: " + lastVanityType);
				LogChannel('modSwitchableCloak', "config val: " + ModGetConfigValueBool('ModSwitchableCloakGeneral', 'PlayCloakAnimations'));
				LogChannel('modSwitchableCloak', "~~~");
				stateMachine = GetSwitchableCloakStateMachine();

				if (stateMachine && lastVanityType == VanityCloak && ModGetConfigValueBool('ModSwitchableCloakGeneral', 'PlayCloakAnimations') && !forceIgnoreAnim) {
					// equip with cloak animation
					LogChannel('modSwitchableCloak', "equip with cloak animation");
					if (!stateMachine.SetCapeOnAnim())
						EquipVanityItem();
					//thePlayer.SetToggleVanityItemOnTimer();
				} else if (stateMachine && lastVanityType == VanityHood && ModGetConfigValueBool('ModSwitchableCloakGeneral', 'PlayHoodAnimations') && !forceIgnoreAnim) {
					// equip with hood animation
					LogChannel('modSwitchableCloak', "equip with hood animation");
					if (!stateMachine.SetHoodOnAnim())
						EquipVanityItem();
					//thePlayer.SetToggleVanityItemOnTimer();
				} else {
					// equip without animation
					LogChannel('modSwitchableCloak', "equip without animation");
					EquipVanityItem();
				}

				return true;
			} else {
				if (ModGetConfigValueBool('ModSwitchableCloakOther', 'IsDebugEnabled')) {
					theGame.GetGuiManager().ShowNotification("No last equipped cloak found!");
					theSound.SoundEvent("gui_global_denied");
				}

				return false;
			}
		}
	}


	public function InitFacts()
	{
		var equippedVanityItem: SItemUniqueId;

		if (factsLoaded)
			return; // already initialized

		factsLoaded = true;
		lastEquippedVanityItem = RetrieveLastUsedVanityItem();

		previousWeather = GetWeatherConditionName();
		previousRainStrength = GetRainStrength();

		// identify current item equip state
		equippedVanityItem = GetEquippedVanityItem();

		if (equippedVanityItem != GetInvalidUniqueId()) {
			SetVanityItemState(VanityItemOn);
		}
	}


	public function EquipVanityItem()
	{
		// unequip
		thePlayer.EquipItem(lastEquippedVanityItem);

		// change state
		SetVanityItemState(VanityItemOn);

		// enable toggling
		toggleDisabled = false;

		CompatibilityPerformCheckWInvisibilityCloak();
	}


	public function UnequipVanityItem()
	{
			// equip last used cloak
			thePlayer.UnequipItem(lastEquippedVanityItem);

			// change state
			SetVanityItemState(VanityItemOff);

			// enable toggling
			toggleDisabled = false;

			CompatibilityPerformCheckWInvisibilityCloak();
	}


	public function CompatibilityPerformCheckWInvisibilityCloak()
	{
		if (!GetWitcherPlayer())
			return;

		if (thePlayer.GetInventory().GetItemName(lastEquippedVanityItem) != compatibilityWithInvisibilityCloak__CloakName)
			return;

		if (ModGetConfigValueBool('ModSwitchableCloakOther', 'IsDebugEnabled'))
			GetWitcherPlayer().DisplayHudMessage("COMPATIBILITY PATCH: Cloak of Invisibility");

		// comp. patch with Invisibility Cloak
		if (GetVanityItemState() == VanityItemOn) {
			compatibilityWithInvisibilityCloak__Enabled = true;
			GetWitcherPlayer().SwitchableCloakCPWInvisibilityCloak();
		} else if (GetVanityItemState() == VanityItemOff) {
			compatibilityWithInvisibilityCloak__Enabled = false;
			GetWitcherPlayer().SwitchableCloakCPWInvisibilityCloak();
		}
	}


	public function UnequipVanityItemDuringFistFightMinigame()
	{
		if (autoUnequippedDuringFistFightMiniGame)
			return; // skip, if was already auto-unequipped during this event

		if (!ModGetConfigValueBool('ModSwitchableCloakGeneral', 'UnequipDuringFistFightMinigame'))
			return; // disabled by user

		if (ModGetConfigValueBool('ModSwitchableCloakOther', 'IsDebugEnabled'))
			theGame.GetGuiManager().ShowNotification("Unequipping cloak, because fist fight minigame begun ...");

		if (!IsModEnabled())
			return;

		autoUnequippedDuringFistFightMiniGame = true; // remember
		ToggleVanityItemOff(true); // no cloaks durning fist fight minigame
	}


	public function EquipVanityItemAfterFistFightMinigame()
	{
		if (!autoUnequippedDuringFistFightMiniGame)
			return; // skip, if was not auto-unequipped during this event

		if (!ModGetConfigValueBool('ModSwitchableCloakGeneral', 'EquipBackAfterFistFightMinigame'))
			return; // disabled by user

		if (ModGetConfigValueBool('ModSwitchableCloakOther', 'IsDebugEnabled'))
			theGame.GetGuiManager().ShowNotification("Equipping cloak back, because fist fight minigame ended ...");

		if (!IsModEnabled())
			return;

		autoUnequippedDuringFistFightMiniGame = false; // reset memory
		ToggleVanityItemOn(true); //equip cloak back after fist fight minigame
	}


	function UnequipVanityItemDuringBarber()
	{
		if (autoUnequippedDuringBarberVisit)
			return; // skip, if was already auto-unequipped during this event

		if (!ModGetConfigValueBool('ModSwitchableCloakGeneral', 'UnequipDuringBarber'))
			return; // disabled by user

		if (ModGetConfigValueBool('ModSwitchableCloakOther', 'IsDebugEnabled'))
			theGame.GetGuiManager().ShowNotification("Unequipping cloak: Barber on enter ...");

		if (!IsModEnabled())
			return;

		autoUnequippedDuringBarberVisit = true; // remember
		ToggleVanityItemOff(true); // no cloaks durning barber visits
	}


	function EquipVanityItemAfterBarber()
	{
		if (!autoUnequippedDuringBarberVisit)
			return; // skip, if was not auto-unequipped during this event

		autoUnequippedDuringBarberVisit = false; // reset memory

		if (!ModGetConfigValueBool('ModSwitchableCloakGeneral', 'EquipBackAfterBarber'))
			return; // disabled by user

		if (!IsModEnabled())
			return;

		if (ModGetConfigValueBool('ModSwitchableCloakOther', 'IsDebugEnabled'))
			theGame.GetGuiManager().ShowNotification("Equipping cloak: Barber on leave ...");

		// @TODO: Auto lower hoods from Hoods?
		ToggleVanityItemOn(true); // equip cloak back on after barber visit
	}


	function RetrieveLastUsedVanityItem(): SItemUniqueId
	{
		var items : array<SItemUniqueId>;
		var lastEquippedVanityItem_FlashUInt: int;
		var i: int;

		if (FactsDoesExist("SwitchableCloak_lastEquippedVanityItem")) {
			lastEquippedVanityItem_FlashUInt = FactsQuerySum("SwitchableCloak_lastEquippedVanityItem");

			thePlayer.GetInventory().GetAllItems(items);

			for (i = 0; i < items.Size(); i += 1) {
				if (ItemToFlashUInt(items[i]) == lastEquippedVanityItem_FlashUInt) {
					if (ModGetConfigValueBool('ModSwitchableCloakOther', 'IsDebugEnabled'))
						theGame.GetGuiManager().ShowNotification("Previously used CLOAK was FACT restored!");

					// identify last equipped vanity item type
					if( IsItemCloak(items[i]) )
						lastVanityType = VanityCloak;
					else
						lastVanityType = VanityHood;

					// return
					return items[i];
				}
			}

			if (ModGetConfigValueBool('ModSwitchableCloakOther', 'IsDebugEnabled'))
				theGame.GetGuiManager().ShowNotification("Previously used CLOAK was NOT FACT found!");

			return ___RetrieveLastUsedVanityItem();
		} else {
			if (ModGetConfigValueBool('ModSwitchableCloakOther', 'IsDebugEnabled'))
				theGame.GetGuiManager().ShowNotification("FACTS not found.");

			return ___RetrieveLastUsedVanityItem();
		}
	}


	/* OLD KEY (backward compatibility with versions 1.4, 1.3 etc) */
	function ___RetrieveLastUsedVanityItem(): SItemUniqueId
	{
		var items : array<SItemUniqueId>;
		var lastEquippedVanityItem_FlashUInt: int;
		var i: int;

		if (FactsDoesExist("SwitchableCloak_lastEquippedCloak")) {
			lastEquippedVanityItem_FlashUInt = FactsQuerySum("SwitchableCloak_lastEquippedCloak");

			thePlayer.GetInventory().GetAllItems(items);

			for (i = 0; i < items.Size(); i += 1) {
				if (ItemToFlashUInt(items[i]) == lastEquippedVanityItem_FlashUInt) {
					return items[i];
				}
			}

			return GetInvalidUniqueId();
		} else {
			return GetInvalidUniqueId();
		}
	}


	function SaveLastUsedVanityItem(newValue: SItemUniqueId)
	{
		if (FactsDoesExist("SwitchableCloak_lastEquippedVanityItem")) {
			FactsSet("SwitchableCloak_lastEquippedVanityItem", ItemToFlashUInt(newValue));
		} else {
			FactsAdd("SwitchableCloak_lastEquippedVanityItem", ItemToFlashUInt(newValue));
		}
	}


	function SearchForVanityItem(itemsList: array<SItemUniqueId>): SItemUniqueId
	{
		var i: int;
		var _searchForHoods: bool;

		_searchForHoods = ModGetConfigValueBool('ModSwitchableCloakGeneral', 'AllowForHoodsEtc');

		// iterate all given items
		for(i = 10; i < itemsList.Size(); i += 1) {
			// iter
			if( IsItemCloak(itemsList[i]) ) {
				// Cloak recognized, return
				if (ModGetConfigValueBool('ModSwitchableCloakOther', 'IsDebugEnabled'))
					theGame.GetGuiManager().ShowNotification("Vanity type is CLOAK");

				vanityType = VanityCloak;
				lastVanityType = VanityCloak;

				return itemsList[i];
			}

			if (_searchForHoods) {
				// Search for hoods etc too

				if( IsItemHood(itemsList[i])) {
					// Hood recognized, return
					if (ModGetConfigValueBool('ModSwitchableCloakOther', 'IsDebugEnabled'))
						theGame.GetGuiManager().ShowNotification("Vanity type is HOOD");

					vanityType = VanityHood;
					lastVanityType = VanityHood;

					return itemsList[i];
				}
			}
		}

		// nothing found
		if (ModGetConfigValueBool('ModSwitchableCloakOther', 'IsDebugEnabled'))
			theGame.GetGuiManager().ShowNotification("Vanity type is UNKNOWN");

		// lastVanityType = vanityType;
		vanityType = VanityUnknown;
		return GetInvalidUniqueId();
	}


	function IsItemCloak(item: SItemUniqueId): bool
	{
		var tags : array<CName>;
		var substrings : array<string>;

		/*
			CHECK FOR CLOAKS etc.
		*/

		// fill tags
		tags.PushBack('AHW');

		// fill substrings
		substrings.PushBack("Cloak");
		substrings.PushBack("Cape");

		// check for tags (auto-hide-weapons for cloaks etc)
		if (ItemHasAnyTagFromList(item, tags)
		// check for certain substrings
		|| StringContainsAnySubstring(NameToString(thePlayer.inv.GetItemName(item)), substrings))
		{
			// is toggle-able cloak/cape etc item
			return true;
		}

		// Unknown vanity type or none is equipped
		return false;
	}


	function IsItemHood(item: SItemUniqueId): bool
	{
		var tags : array<CName>;
		var substrings : array<string>;

		/*
			CHECK FOR HOODS etc.
		*/

		tags.Clear();
		substrings.Clear();

		// enable for hoods, caps, scarfs etc
		tags.PushBack('ToggleHood');
		substrings.PushBack("Hood");
		// substrings.PushBack("hood");
		substrings.PushBack("Cape");
		substrings.PushBack("Scarf");
		substrings.PushBack("Beanie");
		substrings.PushBack("Hat");
		substrings.PushBack("Mask");

		substrings.PushBack("Crach Fur Alt");
		substrings.PushBack("Crach Fur");

		// check for tags (toggle-able hoods from hoods etc)
		if (ItemHasAnyTagFromList(item, tags)
		// check for certain substrings
		|| StringContainsAnySubstring(NameToString(thePlayer.inv.GetItemName(item)), substrings))
		{
			// is toggle-able hood/scarf etc item
			return true;
		}

		// Unknown vanity type or none is equipped
		return false;
	}


	function ItemHasAnyTagFromList(item: SItemUniqueId, tagsList: array<CName>): bool
	{
		var i: int;

		for(i = 0; i < tagsList.Size(); i += 1)
	    {
	        if (thePlayer.inv.ItemHasTag(item, tagsList[i]))
	        	return true;
	    }
	    return false; // No tags found
	}


	function StringContainsAnySubstring(inputstring: string, substrings: array<string>): bool
	{
		var i: int;

		for(i = 0; i < substrings.Size(); i += 1)
	    {
	        if (StrContains(inputstring, substrings[i]))
	        	return true;
	    }
	    return false; // No substrings matched
	}


	function BackwardCompatibilityRestoreSettings()
	{
		var bVal: bool;

		if (ModGetConfigValueBool('ModSwitchableCloakOther', 'BackwardCompatibilitySettingsRestored_v17'))
			return; // already done

		// GENERAL
		bVal = ModGetConfigValueBool('ModSwitchableCloak', 'ModSwitchableCloakAllowForHoodsEtc');
		if (bVal) ModSetConfigValue('ModSwitchableCloakGeneral', 'AllowForHoodsEtc', "true");
			
		bVal = ModGetConfigValueBool('ModSwitchableCloak', 'ModSwitchableCloakPlayCloakAnimations');
		if (bVal) ModSetConfigValue('ModSwitchableCloakGeneral', 'PlayCloakAnimations', "true");

		bVal = ModGetConfigValueBool('ModSwitchableCloak', 'ModSwitchableCloakPlayHoodAnimations');
		if (bVal) ModSetConfigValue('ModSwitchableCloakGeneral', 'PlayHoodAnimations', "true");

		bVal = ModGetConfigValueBool('ModSwitchableCloak', 'ModSwitchableCloakUnequipDuringFistFightMinigame');
		if (bVal) ModSetConfigValue('ModSwitchableCloakGeneral', 'UnequipDuringFistFightMinigame', "true");

		bVal = ModGetConfigValueBool('ModSwitchableCloak', 'ModSwitchableCloakUnequipDuringBarber');
		if (bVal) ModSetConfigValue('ModSwitchableCloakGeneral', 'UnequipDuringBarber', "true");

		bVal = ModGetConfigValueBool('ModSwitchableCloak', 'ModSwitchableCloakAllowSwitchOnHorse');
		if (bVal) ModSetConfigValue('ModSwitchableCloakGeneral', 'AllowSwitchOnHorse', "true");
		
		// AUTO-EQUIP
		bVal = ModGetConfigValueBool('ModSwitchableCloak', 'ModSwitchableCloakAllowAutoEquipWhenRain');
		if (bVal) ModSetConfigValue('ModSwitchableCloakAutoEquip', 'AllowAutoEquipWhenRain', "true");

		bVal = ModGetConfigValueBool('ModSwitchableCloak', 'ModSwitchableCloakAllowAutoEquipWhenStorm');
		if (bVal) ModSetConfigValue('ModSwitchableCloakAutoEquip', 'AllowAutoEquipWhenStorm', "true");

		bVal = ModGetConfigValueBool('ModSwitchableCloak', 'ModSwitchableCloakAllowAutoEquipWhenSnow');
		if (bVal) ModSetConfigValue('ModSwitchableCloakAutoEquip', 'AllowAutoEquipWhenSnow', "true");

		bVal = ModGetConfigValueBool('ModSwitchableCloak', 'ModSwitchableCloakAllowAutoEquipWhenCold');
		if (bVal) ModSetConfigValue('ModSwitchableCloakAutoEquip', 'AllowAutoEquipWhenCold', "true");

		bVal = ModGetConfigValueBool('ModSwitchableCloak', 'ModSwitchableCloakAllowCommentingOnAutoEquip');
		if (bVal) ModSetConfigValue('ModSwitchableCloakAutoEquip', 'AllowCommentingOnAutoEquip', "true");

		bVal = ModGetConfigValueBool('ModSwitchableCloak', 'ModSwitchableCloakAutoEquipCloaksOnly');
		if (bVal) ModSetConfigValue('ModSwitchableCloakAutoEquip', 'AutoEquipCloaksOnly', "true");

		bVal = ModGetConfigValueBool('ModSwitchableCloak', 'ModSwitchableCloakAutoEquipIgnoreAnimation');
		if (bVal) ModSetConfigValue('ModSwitchableCloakAutoEquip', 'AutoEquipIgnoreAnimation', "true");


		bVal = ModGetConfigValueBool('ModSwitchableCloak', 'ModSwitchableCloakAutoEquipInCombat');
		if (bVal) ModSetConfigValue('ModSwitchableCloakAutoEquip', 'AutoEquipInCombat', "true");

		bVal = ModGetConfigValueBool('ModSwitchableCloak', 'ModSwitchableCloakAutoEquipInInterior');
		if (bVal) ModSetConfigValue('ModSwitchableCloakAutoEquip', 'AutoEquipInInterior', "true");

		bVal = ModGetConfigValueBool('ModSwitchableCloak', 'ModSwitchableCloakAutoEquipInCutscenes');
		if (bVal) ModSetConfigValue('ModSwitchableCloakAutoEquip', 'AutoEquipInCutscenes', "true");

		bVal = ModGetConfigValueBool('ModSwitchableCloak', 'ModSwitchableCloakAutoEquipAnyState');
		if (bVal) ModSetConfigValue('ModSwitchableCloakAutoEquip', 'AutoEquipAnyState', "true");

		// OTHER
		bVal = ModGetConfigValueBool('ModSwitchableCloak', 'ModSwitchableCloakIsDebugEnabled');
		if (bVal) ModSetConfigValue('ModSwitchableCloakOther', 'IsDebugEnabled', "true");

		// memorize
		ModSetConfigValue('ModSwitchableCloakOther', 'BackwardCompatibilitySettingsRestored_v17', "true");
	}


	/**
	* Checks the mod menu for a setting and returns its value as a string
	*
	* @nam the name of the mod menu setting to be checked
	* @return a string with the value of that setting in the mod menu
	*/
	function ModGetConfigValue(group: name, nam : name) : string
	{
		var conf: CInGameConfigWrapper;
		var value: string;
		
		conf = theGame.GetInGameConfigWrapper();
		
		value = conf.GetVarValue(group, nam);
		return value;
	}


	function ModGetConfigValueBool(group: name, nam : name) : bool
	{
		return (bool)ModGetConfigValue(group, nam);
	}


	/**
	* Sets a mod menu setting to the desired value
	*
	* @nam the name of the mod menu setting to be changed
	* @value the value the mod menu setting is to be changed to
	*/
	function ModSetConfigValue(group: name, nam : name, value :string)
	{
		var conf: CInGameConfigWrapper;
		
		
		conf = theGame.GetInGameConfigWrapper();
		
		conf.SetVarValue(group, nam, value);
	}
}
