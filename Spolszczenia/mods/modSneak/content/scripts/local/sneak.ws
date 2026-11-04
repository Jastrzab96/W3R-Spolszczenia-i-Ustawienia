// Sneak
// Draw a sword and press the sneak key (see README) to sneak: Geralt walks in the
// fighting stance. Drawing the sword for sneaking alerts nobody. Enemies that haven't noticed him only see him in front of them,
// within a range that is shorter at night, with nothing in between. They hear him
// when he moves close behind them. A ? above an enemy shows it is getting suspicious,
// a ! that he has been spotted. Spotted enemies alert others nearby.
// Attack an unaware enemy from behind for a takedown (a finisher on human men, an
// instant kill on everyone else).
//
// How it works: an enemy that hasn't noticed Geralt is made neutral towards him while
// he sneaks, so the game's own senses ignore him; this mod decides when it notices.
// Its own attitude comes back the moment it spots him, he stops sneaking, or he walks
// away. Options: Options > Mods > Sneak (modSneak.xml, group SNSneak).

function SN_Build() : int { return 38; }

// Enemies further away than this are left to the base game (m)
function SN_ManageRange() : float { return MaxF( 45.f, SN_Value( 'SNMarkerRange', 60 ) ); }

// Takedown reach (m)
function SN_TakedownRange() : float { return 2.2f; }

struct SNTrack
{
	var npc : CNewNPC;
	var aware : float;			// 0 = unaware, 1 = spotted
	var custom : bool;			// had its own attitude towards Geralt (quests)
	var orig : EAIAttitude;
	var marker : int;			// oneliner shown above it (0 = none)
	var markerLvl : int;
	var distractId : int;		// forced "go and look" behaviour (0 = none)
	var distractUntil : float;	// distracted by a rock until then: looks towards distractPos
	var distractPos : Vector;
	var distractWalking : bool;	// walking over to the rock (driven like MCM drives NPCs)
};

struct SNFlash
{
	var id : int;
	var endTime : float;
};

@addField(CR4Player) var snOn : bool;
@addField(CR4Player) var snKeyDown : bool;
@addField(CR4Player) var snKeyTestState : int;
@addField(CR4Player) var snPrevWalk : bool;
@addField(CR4Player) var snStanceForced : bool;
@addField(CR4Player) var snStanceResetAt : float;
@addField(CR4Player) var snSpeedId : int;				// animation speed causer + 1 (0 = none)
@addField(CR4Player) var snLastDetect : float;
@addField(CR4Player) var snTracks : array<SNTrack>;
@addField(CR4Player) var snAlerted : array<CActor>;	// noticed Geralt: left to the base game until he stops sneaking
@addField(CR4Player) var snFlashes : array<SNFlash>;
@addField(CR4Player) var snNextMarker : int;
@addField(CR4Player) var snCandidate : CNewNPC;		// enemy a takedown would go to now
@addField(CR4Player) var snTD : CNewNPC;				// takedown in progress on
@addField(CR4Player) var snTDPhase : int;				// 1 drawing the sword, 2 attacking
@addField(CR4Player) var snTDTime : float;
@addField(CR4Player) var snTDWeapon : EPlayerWeapon;
@addField(CR4Player) var snTDTagged : bool;
@addField(CR4Player) var snPostTD : bool;				// takedown done: wait for the finisher, then sheathe
@addField(CR4Player) var snPostTDTime : float;
@addField(CR4Player) var snDebugTime : float;
@addField(CR4Player) var snDrawAt : float;
@addField(CR4Player) var snStatusText : string;		// what the status line above Geralt shows now
@addField(CR4Player) var snSpottedUntil : float;
@addField(CR4Player) var snMoveStart : float;
@addField(CR4Player) var snKeyDownAt : float;
@addField(CR4Player) var snTapAt : float;				// gamepad tap waiting: toggle then, unless a 2nd tap (Roach) comes
@addField(CR4Player) var snKeyHoldUsed : bool;		// this press threw a rock: no toggle on release
@addField(CR4Player) var snRockAt : float;
@addField(CR4Player) var snRockPos : Vector;
@addField(CR4Player) var snRockLandAt : float;			// rock lands (0 = none in the air)
@addField(CR4Player) var snRockAiming : bool;			// C held: wound up, aiming
@addField(CR4Player) var snRockAimPos : Vector;
@addField(CR4Player) var snRockAimOk : bool;			// the camera points at somewhere a rock can land
@addField(CR4Player) var snRockAimStart : float;
@addField(CR4Player) var snRockTurning : bool;
@addField(CR4Player) var snRockSpot : CEntity;
@addField(CR4Player) var snZoomOn : bool;				// the aiming camera is on
@addField(CR4Player) var snPrevRotCtrl : name;
@addField(CR4Player) var snPrevDistCtrl : name;
@addField(CR4Player) var snPrevPosCtrl : name;
@addField(CR4Player) var snRockSpotId : int;			// hidden marker where the last rock landed (walk target)			// when movement input started (0 = standing still)

// ---------- Settings ----------

function SN_Toggle( varName : name ) : bool
{
	return theGame.GetInGameConfigWrapper().GetVarValue( 'SNSneak', varName ) == "true";
}

function SN_Value( varName : name, fallback : float ) : float
{
	var s : string;

	s = theGame.GetInGameConfigWrapper().GetVarValue( 'SNSneak', varName );
	if ( s == "" )
		return fallback;
	return StringToFloat( s );
}

function SN_SetDefault( config : CInGameConfigWrapper, varName : name, value : string ) : bool
{
	if ( config.GetVarValue( 'SNSneak', varName ) != "" )
		return false;
	config.SetVarValue( 'SNSneak', varName, value );
	return true;
}

// An on/off option that is on by default. Settings from before 1.1 (when it was a
// "turn off ..." option) carry over.
function SN_SetSwitchDefault( config : CInGameConfigWrapper, varName : name, oldOffName : name ) : bool
{
	if ( config.GetVarValue( 'SNSneak', varName ) != "" )
		return false;
	if ( config.GetVarValue( 'SNSneak', oldOffName ) == "true" )
		config.SetVarValue( 'SNSneak', varName, "false" );
	else
		config.SetVarValue( 'SNSneak', varName, "true" );
	return true;
}

function SN_Debug( text : string )
{
	if ( SN_Toggle( 'SNDebug' ) )
		theGame.GetGuiManager().ShowNotification( text, 2500 );
}

@wrapMethod(CR4Game)
function OnAfterLoadingScreenGameStart()
{
	var config : CInGameConfigWrapper;
	var changed : bool;

	wrappedMethod();

	config = theGame.GetInGameConfigWrapper();
	changed = SN_SetDefault( config, 'SNSpeedPct', "100" );
	changed = SN_SetDefault( config, 'SNSightDay', "14" ) || changed;
	changed = SN_SetDefault( config, 'SNSightNight', "7" ) || changed;
	changed = SN_SetDefault( config, 'SNHearing', "3" ) || changed;
	changed = SN_SetDefault( config, 'SNNoticePct', "100" ) || changed;
	changed = SN_SetDefault( config, 'SNAlertRadius', "12" ) || changed;
	changed = SN_SetDefault( config, 'SNNoiseRadius', "4" ) || changed;
	changed = SN_SetDefault( config, 'SNMarkerRange', "60" ) || changed;
	changed = SN_SetDefault( config, 'SNMarkerSize', "34" ) || changed;
	changed = SN_SetDefault( config, 'SNBoltPct', "400" ) || changed;
	changed = SN_SetDefault( config, 'SNRockRadius', "8" ) || changed;
	changed = SN_SetDefault( config, 'SNRockTime', "10" ) || changed;
	changed = SN_SetSwitchDefault( config, 'SNEnabled', 'SNOff' ) || changed;
	changed = SN_SetSwitchDefault( config, 'SNCameraTurn', 'SNNoCameraTurn' ) || changed;
	changed = SN_SetSwitchDefault( config, 'SNFoliage', 'SNNoFoliage' ) || changed;
	changed = SN_SetSwitchDefault( config, 'SNMonsters', 'SNHumansOnly' ) || changed;
	changed = SN_SetSwitchDefault( config, 'SNTakedowns', 'SNNoTakedown' ) || changed;
	changed = SN_SetSwitchDefault( config, 'SNFinishers', 'SNNoFinisher' ) || changed;
	changed = SN_SetSwitchDefault( config, 'SNHeadshotKill', 'SNNoHeadshotKill' ) || changed;
	changed = SN_SetSwitchDefault( config, 'SNRocks', 'SNNoRocks' ) || changed;
	changed = SN_SetSwitchDefault( config, 'SNMarkers', 'SNNoMarkers' ) || changed;
	changed = SN_SetSwitchDefault( config, 'SNStatus', 'SNNoStatus' ) || changed;
	if ( changed )
		theGame.SaveUserSettings();

	SN_RestoreTagged();
	thePlayer.UnblockAction( EIAB_RunAndSprint, 'SNSneak' );	// left by build 6 in a save
	thePlayer.RemoveTag( 'SNSneaking' );
	SN_Debug( "Sneak build " + IntToString( SN_Build() ) );
}

// Enemies left neutral in a save made while sneaking get their attitude back
function SN_RestoreTagged()
{
	var actors : array<CActor>;
	var i : int;

	theGame.GetActorsByTag( 'SNNeutral', actors );
	for ( i = 0; i < actors.Size(); i += 1 )
	{
		if ( actors[i].HasTag( 'SNNeutralCustom' ) )
			actors[i].SetAttitude( thePlayer, AIA_Hostile );
		else
			actors[i].ResetAttitude( thePlayer );
		actors[i].RemoveTag( 'SNNeutral' );
		actors[i].RemoveTag( 'SNNeutralCustom' );
	}
}

// ---------- Every frame ----------

@wrapMethod(W3PlayerWitcher)
function OnPlayerTickTimer( deltaTime : float )
{
	var res : bool;

	res = wrappedMethod( deltaTime );
	SN_Tick( this );
	return res;
}

function SN_Tick( player : CR4Player )
{
	var now, dt : float;

	now = theGame.GetEngineTimeAsSeconds();

	if ( player.snStanceResetAt > 0.f && now >= player.snStanceResetAt )
	{
		// forced for one frame to switch at once, then blend as usual
		player.SetBehaviorVariable( 'forceCombatStance', 0.f );
		player.snStanceResetAt = 0.f;
	}

	SN_KeyTick( player );
	SN_FlashTick( player, now );
	SN_RockTick( player, now );		// a throw in progress finishes even if sneaking stops

	if ( !player.snOn )
	{
		if ( player.snTracks.Size() > 0 )
			SN_ReleaseAll( player );
		return;
	}

	if ( SN_ShouldStop( player ) )
	{
		SN_Stop( player );
		return;
	}

	SN_TakedownTick( player, now );
	SN_PostTakedownTick( player, now );
	SN_PostureTick( player, now );
	SN_CameraTurn( player, now );

	if ( now - player.snLastDetect >= 0.1f )
	{
		dt = MinF( now - player.snLastDetect, 0.5f );
		player.snLastDetect = now;
		SN_Detect( player, dt );
	}

	SN_StatusTick( player, now );
	SN_DebugTick( player, now );
}

// ---------- Key ----------

function SN_KeyTick( player : CR4Player )
{
	var down : bool;

	// our own action, or C's dive action if the land controls have it as well
	// (sneaking never starts in water, so diving is unaffected)
	down = theInput.IsActionPressed( 'SNSneak' ) || theInput.IsActionPressed( 'DiveDown' ) || SN_ComboHeld();
	SN_KeyTest( player );

	if ( !SN_Toggle( 'SNEnabled' ) )
	{
		player.snKeyDown = down;
		return;
	}

	if ( SN_Toggle( 'SNHold' ) )
	{
		if ( down && !player.snOn )
			SN_Start( player );
		else if ( !down && player.snOn && player.snTDPhase == 0 && !player.snPostTD )
			SN_Stop( player );
	}
	else
	{
		// tap: sneak on / off (on release). Hold while sneaking: throw a rock.
		if ( down && !player.snKeyDown )
		{
			// a second tap soon after the first: that's the game's L3 double-tap
			// to call Roach, not sneaking
			if ( player.snTapAt > 0.f )
			{
				player.snTapAt = 0.f;
				player.snKeyHoldUsed = true;
			}
			else
				player.snKeyHoldUsed = false;
			player.snKeyDownAt = theGame.GetEngineTimeAsSeconds();
		}
		else if ( down && player.snOn && !player.snKeyHoldUsed
			&& theGame.GetEngineTimeAsSeconds() - player.snKeyDownAt >= SN_HoldTime() )
		{
			player.snKeyHoldUsed = true;
			SN_RockAimStart( player );		// hold: wind up and aim
		}
		else if ( !down && player.snKeyDown && player.snRockAiming )
			SN_RockRelease( player );		// let go: throw
		else if ( !down && player.snKeyDown && !player.snKeyHoldUsed )
		{
			if ( theInput.LastUsedGamepad() )
				player.snTapAt = theGame.GetEngineTimeAsSeconds() + 0.4f;	// wait: maybe a Roach double-tap
			else
				SN_ToggleSneak( player );
		}

		if ( player.snTapAt > 0.f && theGame.GetEngineTimeAsSeconds() >= player.snTapAt )
		{
			player.snTapAt = 0.f;
			SN_ToggleSneak( player );
		}
	}

	player.snKeyDown = down;
}

function SN_YesNo( b : bool ) : string
{
	if ( b )
		return "yes";
	return "no";
}

function SN_ToggleSneak( player : CR4Player )
{
	if ( player.snOn )
	{
		if ( player.snTDPhase == 0 )
			SN_Stop( player );
	}
	else
		SN_Start( player );
}

// Holding the sneak key this long throws a rock (s)
function SN_HoldTime() : float { return 0.35f; }

// A combo sneak key (set by Install keybinds.bat): a modifier such as Ctrl
// bound to SNSneakMod, held with the key bound to SNSneakCombo
// Test messages: what the game sees of the sneak key lines, whenever it changes
function SN_KeyTest( player : CR4Player )
{
	var st : int;

	if ( !SN_Toggle( 'SNDebug' ) )
		return;
	st = 0;
	if ( theInput.IsActionPressed( 'SNSneak' ) )		st += 1;
	if ( theInput.IsActionPressed( 'DiveDown' ) )		st += 2;
	if ( theInput.IsActionPressed( 'SNSneakMod' ) )		st += 4;
	if ( theInput.IsActionPressed( 'SNSneakCombo' ) )	st += 8;
	if ( st == player.snKeyTestState )
		return;
	player.snKeyTestState = st;
	if ( st == 0 )
		return;
	theGame.GetGuiManager().ShowNotification( "Sneak keys held: key " + SN_YesNo( ( st & 1 ) != 0 )
		+ ", C " + SN_YesNo( ( st & 2 ) != 0 ) + ", combo modifier " + SN_YesNo( ( st & 4 ) != 0 )
		+ ", combo key " + SN_YesNo( ( st & 8 ) != 0 ) + " (input " + NameToString( theInput.GetContext() ) + ")", 2500 );
}

function SN_ComboHeld() : bool
{
	return theInput.IsActionPressed( 'SNSneakCombo' ) && theInput.IsActionPressed( 'SNSneakMod' );
}

function SN_SwordHeld( player : CR4Player ) : bool
{
	return player.IsWeaponHeld( 'steelsword' ) || player.IsWeaponHeld( 'silversword' );
}

// A real fight: an enemy is after Geralt (one that noticed him, or any other)
function SN_Fighting( player : CR4Player ) : bool
{
	var enemies : array<CActor>;
	var npc : CActor;
	var i : int;

	for ( i = 0; i < player.snAlerted.Size(); i += 1 )
	{
		npc = player.snAlerted[i];
		if ( npc && npc.IsAlive() && npc.IsInCombat() && npc.GetTarget() == player )
			return true;
	}
	enemies = player.GetHostileEnemies();
	for ( i = 0; i < enemies.Size(); i += 1 )
	{
		npc = enemies[i];
		if ( npc && npc.IsAlive() && npc.IsInCombat() && npc.GetTarget() == player )
			return true;
	}
	return false;
}

// Out of a fight with a sword out: exploring, or the sword-fighting state with
// nobody to fight (Free Aim's "fighting stance whenever the sword is drawn")
function SN_SneakState( player : CR4Player ) : bool
{
	var stateName : name;

	stateName = player.GetCurrentStateName();
	return stateName == 'Exploration' || stateName == 'CombatSteel' || stateName == 'CombatSilver';
}

function SN_CanStart( player : CR4Player ) : bool
{
	if ( player.IsCiri() || !SN_SneakState( player ) )
		return false;
	if ( SN_Fighting( player ) || player.IsUsingVehicle() || player.IsSwimming() || player.IsInNonGameplayCutscene() )
		return false;
	return true;
}

function SN_Start( player : CR4Player )
{
	if ( !SN_CanStart( player ) )
	{
		SN_Debug( "Sneak: can't start here (" + NameToString( player.GetCurrentStateName() ) + ", fighting " + SN_YesNo( SN_Fighting( player ) ) + ")" );
		return;
	}

	player.snOn = true;
	player.snPrevWalk = player.GetIsWalkToggled();
	player.snLastDetect = theGame.GetEngineTimeAsSeconds();
	player.snAlerted.Clear();
	player.snPostTD = false;
	player.snTDPhase = 0;

	player.snDrawAt = 0.f;
	player.AddTag( 'SNSneaking' );		// Free Aim (private) leaves Geralt alone while this is on

	// sneaking is done with a sword out: drawn now if it isn't (alerting nobody)
	SN_DrawTick( player, theGame.GetEngineTimeAsSeconds() );

	SN_Debug( "Sneaking" );
}

function SN_Stop( player : CR4Player )
{
	SN_ReleaseAll( player );
	player.snAlerted.Clear();

	if ( player.snTD && player.snTDTagged && player.snTD.IsAlive() )
		player.snTD.RemoveTag( 'ForceFinisher' );
	player.snTD = NULL;
	player.snTDPhase = 0;
	player.snTDTagged = false;
	player.snPostTD = false;
	player.snCandidate = NULL;

	player.SetWalkToggle( player.snPrevWalk );

	if ( player.snStanceForced )
	{
		player.snStanceForced = false;
		if ( player.GetCurrentStateName() == 'Exploration' )
		{
			player.SetPlayerCombatStance( PCS_Normal, true );
			player.SetBehaviorVariable( 'forceCombatStance', 0.f );	// blend into the stance, no snap
		}
	}

	player.RemoveTag( 'SNSneaking' );

	SN_SpeedOff( player );
	SN_SetStatus( player, "" );
	player.snOn = false;

	SN_Debug( "Stopped sneaking" );
}

function SN_ShouldStop( player : CR4Player ) : bool
{
	var stateName : name;

	if ( !SN_Toggle( 'SNEnabled' ) || !player.IsAlive() )
		return true;

	stateName = player.GetCurrentStateName();

	// a takedown draws the sword and goes to the fighting state for a moment
	if ( player.snTDPhase > 0 || player.snPostTD )
		return stateName != 'Exploration' && stateName != 'CombatSteel' && stateName != 'CombatSilver' && stateName != 'CombatFists';

	if ( !SN_SneakState( player ) && stateName != 'AimThrow' )
		return true;
	// Shift as part of the sneak key isn't a sprint
	if ( player.GetIsSprinting() || SN_Fighting( player )
		|| ( theInput.IsActionPressed( 'Sprint' ) && !theInput.IsActionPressed( 'SNSneakMod' ) && !theInput.IsActionPressed( 'SNSneak' ) ) )
		return true;
	if ( player.IsUsingVehicle() || player.IsSwimming() || player.IsInNonGameplayCutscene() )
		return true;

	return false;
}

// ---------- Posture ----------

function SN_PostureTick( player : CR4Player, now : float )
{
	if ( player.snTDPhase > 0 || player.snPostTD || player.snRockAiming || !SN_SneakState( player ) )
	{
		SN_SpeedOff( player );
		return;
	}

	if ( !player.GetIsWalkToggled() )
		player.SetWalkToggle( true );

	SN_DrawTick( player, now );

	if ( !SN_Toggle( 'SNNormalWalk' ) && SN_SwordHeld( player ) )
	{
		if ( player.GetPlayerCombatStance() != PCS_AlertNear )
		{
			player.SetPlayerCombatStance( PCS_AlertNear, true );
			player.snStanceForced = true;
			player.SetBehaviorVariable( 'forceCombatStance', 0.f );	// blend into the stance, no snap
		}
	}
	else if ( player.snStanceForced )
	{
		player.snStanceForced = false;
		player.SetPlayerCombatStance( PCS_Normal, true );
		player.SetBehaviorVariable( 'forceCombatStance', 0.f );	// blend into the stance, no snap
	}

	if ( SN_Value( 'SNSpeedPct', 100 ) < 99.f )
	{
		if ( player.snSpeedId == 0 )
			player.snSpeedId = player.SetAnimationSpeedMultiplier( SN_Value( 'SNSpeedPct', 100 ) / 100.f, -1 ) + 1;
	}
	else
		SN_SpeedOff( player );
}

// Keeps a sword out while sneaking (put away, it comes back out)
function SN_DrawTick( player : CR4Player, now : float )
{
	if ( SN_SwordHeld( player ) || now - player.snDrawAt < 1.5f )
		return;
	player.OnEquipMeleeWeapon( SN_StanceWeapon( player ), true );
	player.snDrawAt = now;
}

// Steel sword stance (silver if Geralt only carries a silver sword)
function SN_StanceWeapon( player : CR4Player ) : EPlayerWeapon
{
	var witcher : W3PlayerWitcher;
	var item : SItemUniqueId;

	witcher = (W3PlayerWitcher)player;
	if ( witcher && !witcher.GetItemEquippedOnSlot( EES_SteelSword, item )
		&& witcher.GetItemEquippedOnSlot( EES_SilverSword, item ) )
		return PW_Silver;
	return PW_Steel;
}

function SN_SpeedOff( player : CR4Player )
{
	if ( player.snSpeedId > 0 )
	{
		player.ResetAnimationSpeedMultiplier( player.snSpeedId - 1 );
		player.snSpeedId = 0;
	}
}

// ---------- Camera control ----------
// As in Free Aim (but on its own): while sneaking Geralt faces where the camera looks
// and strafes - A / D sideways, S backwards - instead of turning to where he walks.
// With W (and W + A / W + D) he walks where you go. Standing still the camera orbits
// him, or (option) he turns with it.

function SN_CameraTurnSpeed() : float { return 720.f; }
function SN_TurnStartSpeed() : float { return 200.f; }		// eased in from this...
function SN_TurnEaseTime() : float { return 0.4f; }			// ...over this long after starting to move

function SN_CameraHeading( player : CR4Player ) : float
{
	return VecHeading( theCamera.GetCameraDirection() ) - player.oTCameraOffset;
}

// W held: a normal walk forward or diagonally
function SN_ForwardInput( player : CR4Player ) : bool
{
	return !player.bLAxisReleased && theInput.GetActionValue( 'GI_AxisLeftY' ) >= 0.3f;
}

function SN_Idle( player : CR4Player ) : bool
{
	return player.bLAxisReleased && !player.IsInCombatAction() && !player.IsCurrentlyDodging();
}

// Geralt faces the camera now
function SN_CameraFacing( player : CR4Player ) : bool
{
	if ( !player.snOn || player.snTDPhase > 0 || player.snPostTD || !SN_Toggle( 'SNCameraTurn' ) )
		return false;
	if ( !SN_SwordHeld( player ) || !SN_SneakState( player ) )
		return false;
	return !( player.IsHardLockEnabled() && player.IsActorLockedToTarget() );
}

function SN_CameraTurn( player : CR4Player, now : float )
{
	var adjustor : CMovementAdjustor;
	var ticket : SMovementAdjustmentRequestTicket;
	var speed, k : float;

	if ( player.bLAxisReleased )
		player.snMoveStart = 0.f;
	else if ( player.snMoveStart == 0.f )
		player.snMoveStart = now;

	if ( !SN_CameraFacing( player ) || player.snRockAiming || player.IsInCombatAction() || player.IsCurrentlyDodging() || player.GetIsSprinting() )
		return;
	if ( SN_ForwardInput( player ) )
		return;					// walking forward: he faces where he goes
	if ( SN_Idle( player ) && !SN_Toggle( 'SNIdleTurn' ) )
		return;					// standing still: the camera orbits him

	// eased in just after starting to move, so starting to strafe doesn't snap
	speed = SN_CameraTurnSpeed();
	if ( player.snMoveStart > 0.f )
	{
		k = ClampF( ( now - player.snMoveStart ) / SN_TurnEaseTime(), 0.f, 1.f );
		speed = SN_TurnStartSpeed() + ( SN_CameraTurnSpeed() - SN_TurnStartSpeed() ) * k;
	}

	adjustor = player.GetMovingAgentComponent().GetMovementAdjustor();
	ticket = adjustor.GetRequest( 'SNCameraTurn' );
	if ( !adjustor.IsRequestActive( ticket ) )
	{
		ticket = adjustor.CreateNewRequest( 'SNCameraTurn' );
		adjustor.ReplaceRotation( ticket );
	}
	adjustor.RotateTo( ticket, SN_CameraHeading( player ) );
	adjustor.MaxRotationAdjustmentSpeed( ticket, speed );
	adjustor.KeepActiveFor( ticket, 0.1f );
}

// The game would turn Geralt to an enemy or to where he walks: he keeps the facing
// he's turned to (above) while sneaking. Bombs and usable items keep aiming.
@wrapMethod(CR4Player)
function GetOrientationTarget() : EOrientationTarget
{
	var res : EOrientationTarget;
	var info : SCustomOrientationInfo;

	res = wrappedMethod();

	if ( !SN_CameraFacing( this ) )
		return res;
	if ( GetCustomOrientationTarget( info ) && info.orientationTarget == OT_Actor )
		return res;
	if ( SN_ForwardInput( this ) )
		return res;
	if ( res == OT_Actor || SN_Idle( this ) || !bLAxisReleased )
		return OT_Player;
	return res;
}

// ---------- Senses ----------

function SN_IsNight() : bool
{
	var hours : int;

	hours = GameTimeHours( theGame.GetGameTime() );
	return hours >= 22 || hours < 5;
}

function SN_IsDusk() : bool
{
	var hours : int;

	hours = GameTimeHours( theGame.GetGameTime() );
	return ( hours >= 20 && hours < 22 ) || ( hours >= 5 && hours < 6 );
}

// How far an enemy looking straight at Geralt sees him
function SN_SightRange( player : CR4Player ) : float
{
	var day, night, range : float;

	day = SN_Value( 'SNSightDay', 14 );
	night = SN_Value( 'SNSightNight', 7 );

	if ( SN_IsNight() )
		range = night;
	else if ( SN_IsDusk() || player.IsInInterior() )
		range = ( day + night ) / 2.f;
	else
		range = day;

	// standing still is harder to make out
	if ( !SN_Moving( player ) )
		range *= 0.7f;
	return range;
}

function SN_Moving( player : CR4Player ) : bool
{
	var v : Vector;

	v = player.GetMovingAgentComponent().GetVelocity();
	return VecLength2D( v ) > 0.3f;
}

// Nothing solid between the enemy's eyes and Geralt
function SN_HasLOS( npc : CActor, player : CR4Player ) : bool
{
	var eye, chest, knees, hitPos, hitNormal : Vector;
	var groups : array<name>;

	eye = npc.GetWorldPosition();
	eye.Z += 1.6f;
	chest = player.GetWorldPosition();
	knees = chest;
	chest.Z += 1.1f;
	knees.Z += 0.5f;

	groups.PushBack( 'Terrain' );
	groups.PushBack( 'Static' );
	groups.PushBack( 'Destructible' );
	if ( SN_Toggle( 'SNFoliage' ) )
		groups.PushBack( 'Foliage' );

	if ( !theGame.GetWorld().StaticTrace( eye, chest, hitPos, hitNormal, groups ) )
		return true;
	return !theGame.GetWorld().StaticTrace( eye, knees, hitPos, hitNormal, groups );
}

// Where the enemy is looking: at the rock while distracted, else where it faces
function SN_LookHeading( player : CR4Player, npc : CActor ) : float
{
	var idx : int;

	idx = SN_TrackIndex( player, npc );
	if ( idx >= 0 && theGame.GetEngineTimeAsSeconds() < player.snTracks[idx].distractUntil )
		return VecHeading( player.snTracks[idx].distractPos - npc.GetWorldPosition() );
	return npc.GetHeading();
}

// Awareness gained per second from seeing Geralt
function SN_SightGain( player : CR4Player, npc : CActor, dist, sight : float ) : float
{
	var npcPos, playerPos : Vector;
	var ang, range : float;

	npcPos = npc.GetWorldPosition();
	playerPos = player.GetWorldPosition();
	ang = AbsF( AngleDistance( SN_LookHeading( player, npc ), VecHeading( playerPos - npcPos ) ) );

	if ( ang <= 60.f )
		range = sight;					// in front
	else if ( ang <= 100.f )
		range = sight * 0.4f;			// corner of the eye
	else
		return 0.f;						// behind

	if ( dist > range || range <= 0.f )
		return 0.f;
	if ( !SN_HasLOS( npc, player ) )
		return 0.f;

	// about 1.7 s at the edge of sight, a third of a second up close
	return 0.6f + 2.4f * ( 1.f - dist / range );
}

// Awareness gained per second from hearing Geralt
function SN_HearGain( player : CR4Player, dist : float, moving : bool ) : float
{
	var hearing : float;

	hearing = SN_Value( 'SNHearing', 3 );
	if ( hearing <= 0.f )
		return 0.f;

	if ( moving && dist <= hearing )
		return 0.35f * ( 2.f - dist / hearing );
	if ( !moving && dist <= hearing * 0.35f )
		return 0.25f;
	return 0.f;
}

// ---------- Tracking ----------

function SN_TrackIndex( player : CR4Player, npc : CActor ) : int
{
	var i : int;

	for ( i = 0; i < player.snTracks.Size(); i += 1 )
	{
		if ( player.snTracks[i].npc == npc )
			return i;
	}
	return -1;
}

function SN_Manageable( player : CR4Player, npc : CNewNPC ) : bool
{
	if ( !npc || npc == player || !npc.IsAlive() )
		return false;
	if ( npc.GetAttitude( player ) != AIA_Hostile )
		return false;
	if ( npc.HasAbility( 'Boss' ) || npc.HasTag( 'boss' ) || npc.IsHorse() )
		return false;
	if ( !SN_Toggle( 'SNQuestNPCs' ) && npc.GetNPCType() == ENGT_Quest )
		return false;
	if ( !SN_Toggle( 'SNMonsters' ) && !npc.IsHuman() )
		return false;
	if ( player.snAlerted.Contains( npc ) )
		return false;
	return true;
}

function SN_Gather( player : CR4Player )
{
	var actors : array<CActor>;
	var npc : CNewNPC;
	var tr : SNTrack;
	var i : int;

	actors = player.GetNPCsAndPlayersInRange( SN_ManageRange(), 100, '', FLAG_Attitude_Hostile + FLAG_OnlyAliveActors );

	for ( i = 0; i < actors.Size(); i += 1 )
	{
		npc = (CNewNPC)actors[i];
		if ( !SN_Manageable( player, npc ) || SN_TrackIndex( player, npc ) >= 0 )
			continue;

		// already after Geralt: the base game carries on
		if ( npc.IsInCombat() && npc.GetTarget() == player )
		{
			player.snAlerted.PushBack( npc );
			continue;
		}

		tr.npc = npc;
		tr.aware = 0.f;
		tr.custom = npc.HasAttitudeTowards( player );
		tr.orig = npc.GetAttitude( player );
		tr.marker = 0;
		tr.markerLvl = 0;
		tr.distractId = 0;
		tr.distractUntil = 0.f;
		tr.distractWalking = false;

		npc.SetAttitude( player, AIA_Neutral );
		npc.ForgetActor( player );
		npc.AddTag( 'SNNeutral' );
		if ( tr.custom )
			npc.AddTag( 'SNNeutralCustom' );

		player.snTracks.PushBack( tr );
	}
}

// Gives the enemy its own attitude back and stops tracking it
function SN_Release( player : CR4Player, idx : int )
{
	var npc : CNewNPC;

	npc = player.snTracks[idx].npc;
	SN_SetMarker( player, idx, 0 );
	SN_EndDistract( player, idx );
	if ( player.snTracks[idx].distractWalking )
		SN_StopWalk( player, idx );

	if ( npc )
	{
		if ( npc.IsAlive() && npc.GetAttitude( player ) == AIA_Neutral )
		{
			if ( player.snTracks[idx].custom )
				npc.SetAttitude( player, player.snTracks[idx].orig );
			else
				npc.ResetAttitude( player );
		}
		npc.RemoveTag( 'SNNeutral' );
		npc.RemoveTag( 'SNNeutralCustom' );
	}

	player.snTracks.Erase( idx );
}

function SN_ReleaseAll( player : CR4Player )
{
	var i : int;

	for ( i = player.snTracks.Size() - 1; i >= 0; i -= 1 )
		SN_Release( player, i );
}

// The enemy has spotted Geralt. Others close to it are alerted too.
function SN_Spot( player : CR4Player, npc : CNewNPC, alertOthers : bool )
{
	var idx : int;
	var pos : Vector;

	idx = SN_TrackIndex( player, npc );
	if ( idx < 0 )
		return;

	pos = npc.GetWorldPosition();
	SN_Release( player, idx );
	npc.NoticeActor( player );
	player.snAlerted.PushBack( npc );
	SN_Flash( player, npc );

	// a takedown in progress can't hide this any more
	player.snPostTD = false;
	player.snSpottedUntil = theGame.GetEngineTimeAsSeconds() + 3.f;

	if ( alertOthers )
		SN_AlertAround( player, pos );
}

// Enemies close to a spotted (or shot) one are alerted too
function SN_AlertAround( player : CR4Player, pos : Vector )
{
	var i : int;
	var radius : float;
	var others : array<CNewNPC>;

	radius = SN_Value( 'SNAlertRadius', 12 );
	for ( i = 0; i < player.snTracks.Size(); i += 1 )
	{
		if ( player.snTracks[i].npc && player.snTracks[i].npc != player.snTD
			&& VecDistance( player.snTracks[i].npc.GetWorldPosition(), pos ) <= radius )
			others.PushBack( player.snTracks[i].npc );
	}
	for ( i = 0; i < others.Size(); i += 1 )
		SN_Spot( player, others[i], false );
}

function SN_Detect( player : CR4Player, dt : float )
{
	var spotted : array<CNewNPC>;
	var npc : CNewNPC;
	var sight, dist, gain, notice : float;
	var moving : bool;
	var i, lvl : int;

	SN_Gather( player );

	sight = SN_SightRange( player );
	moving = SN_Moving( player );
	notice = SN_Value( 'SNNoticePct', 100 ) / 100.f;

	if ( player.snTDPhase == 0 )
		player.snCandidate = SN_FindTakedown( player );

	for ( i = player.snTracks.Size() - 1; i >= 0; i -= 1 )
	{
		npc = player.snTracks[i].npc;
		if ( !npc || !npc.IsAlive() )
		{
			SN_Release( player, i );
			continue;
		}
		if ( npc == player.snTD )
		{
			SN_SetMarker( player, i, 0 );
			continue;
		}

		// something else (a quest) changed how it feels about Geralt
		if ( npc.GetAttitude( player ) != AIA_Neutral )
		{
			SN_SetMarker( player, i, 0 );
			npc.RemoveTag( 'SNNeutral' );
			npc.RemoveTag( 'SNNeutralCustom' );
			player.snTracks.Erase( i );
			player.snAlerted.PushBack( npc );
			continue;
		}

		dist = VecDistance( npc.GetWorldPosition(), player.GetWorldPosition() );
		if ( dist > SN_ManageRange() + 5.f )
		{
			SN_Release( player, i );
			continue;
		}


		// distraction over (or it got too suspicious): stop walking
		if ( player.snTracks[i].distractWalking
			&& ( theGame.GetEngineTimeAsSeconds() >= player.snTracks[i].distractUntil || player.snTracks[i].aware >= 0.5f ) )
			SN_StopWalk( player, i );
		if ( player.snTracks[i].distractId != 0 && theGame.GetEngineTimeAsSeconds() >= player.snTracks[i].distractUntil )
			SN_EndDistract( player, i );

		gain = ( SN_SightGain( player, npc, dist, sight ) + SN_HearGain( player, dist, moving ) ) * notice;
		if ( gain > 0.f )
			player.snTracks[i].aware += gain * dt;
		else
			player.snTracks[i].aware = MaxF( 0.f, player.snTracks[i].aware - 0.2f * dt );

		if ( player.snTracks[i].aware >= 1.f )
		{
			spotted.PushBack( npc );
			continue;
		}

		if ( npc == player.snCandidate )
			lvl = 30;
		else if ( theGame.GetEngineTimeAsSeconds() < player.snTracks[i].distractUntil && player.snTracks[i].aware < 0.5f )
		{
			lvl = 40;		// distracted by a rock: walks over, then looks around there
			SN_DistractTick( player, i );
		}
		else if ( player.snRockAiming && player.snRockAimOk && player.snTracks[i].aware < 0.08f
			&& VecDistance( npc.GetWorldPosition(), player.snRockAimPos ) <= SN_Value( 'SNRockRadius', 8 ) )
			lvl = 40;		// would hear the rock land
		else if ( player.snTracks[i].aware >= 0.08f )
			lvl = 1 + Clamp( FloorF( player.snTracks[i].aware * 8.f ), 0, 7 );	// 1-8: green to red
		else
			lvl = 0;
		SN_SetMarker( player, i, lvl );
	}

	for ( i = 0; i < spotted.Size(); i += 1 )
		SN_Spot( player, spotted[i], true );
}

// ---------- Markers ----------

function SN_Oneliners() : CR4HudModuleOneliners
{
	var hud : CR4ScriptedHud;

	hud = (CR4ScriptedHud)theGame.GetHud();
	if ( !hud )
		return NULL;
	return (CR4HudModuleOneliners)hud.GetHudModule( "OnelinersModule" );
}

// Two hex digits
function SN_Hex( v : int ) : string
{
	var digits : string;

	digits = "0123456789ABCDEF";
	v = Clamp( v, 0, 255 );
	return StrMid( digits, v / 16, 1 ) + StrMid( digits, v % 16, 1 );
}

// Green when an enemy has barely noticed something, through yellow, to red just
// before it spots Geralt
function SN_SuspicionColor( step : int ) : string
{
	var t : float;
	var r, g, b : int;

	t = (float)( Clamp( step, 1, 8 ) - 1 ) / 7.f;
	if ( t < 0.5f )
	{
		r = RoundF( 95.f + ( 235.f - 95.f ) * t * 2.f );
		g = 215;
	}
	else
	{
		r = 235;
		g = RoundF( 215.f - ( 215.f - 55.f ) * ( t - 0.5f ) * 2.f );
	}
	b = RoundF( 85.f - 40.f * t );
	return "#" + SN_Hex( r ) + SN_Hex( g ) + SN_Hex( b );
}

function SN_MarkerSize() : string
{
	return IntToString( RoundF( SN_Value( 'SNMarkerSize', 34 ) ) );
}

function SN_MarkerText( lvl : int ) : string
{
	if ( lvl >= 1 && lvl <= 8 )
		return "<font size='" + SN_MarkerSize() + "' color='" + SN_SuspicionColor( lvl ) + "'>?</font>";
	if ( lvl == 20 )
		return "<font size='" + SN_MarkerSize() + "' color='#E0302A'>!</font>";
	if ( lvl == 30 )
		return "<font color='#EDEDED'>Takedown</font>";
	if ( lvl == 40 )
		return "<font size='" + SN_MarkerSize() + "' color='#8EC8F0'>~</font>";
	return "";
}

function SN_NewMarkerId( player : CR4Player ) : int
{
	player.snNextMarker = ( player.snNextMarker + 1 ) % 900;
	return 7470100 + player.snNextMarker;
}

function SN_SetMarker( player : CR4Player, idx : int, lvl : int )
{
	var module : CR4HudModuleOneliners;
	var id : int;

	if ( !SN_Toggle( 'SNMarkers' ) )
		lvl = 0;
	if ( player.snTracks[idx].markerLvl == lvl )
		return;

	module = SN_Oneliners();
	if ( !module )
		return;

	if ( player.snTracks[idx].marker != 0 )
		module.OnRemoveOneliner( player.snTracks[idx].marker );
	player.snTracks[idx].marker = 0;
	player.snTracks[idx].markerLvl = lvl;

	if ( lvl > 0 )
	{
		id = SN_NewMarkerId( player );
		module.OnCreateOneliner( player.snTracks[idx].npc, SN_MarkerText( lvl ), id );
		player.snTracks[idx].marker = id;
	}
}

// "!" over an enemy that spotted Geralt, for two seconds
function SN_Flash( player : CR4Player, npc : CActor )
{
	var module : CR4HudModuleOneliners;
	var flash : SNFlash;

	if ( !SN_Toggle( 'SNMarkers' ) )
		return;
	module = SN_Oneliners();
	if ( !module )
		return;

	flash.id = SN_NewMarkerId( player );
	flash.endTime = theGame.GetEngineTimeAsSeconds() + 2.f;
	module.OnCreateOneliner( npc, SN_MarkerText( 20 ), flash.id );
	player.snFlashes.PushBack( flash );
}

function SN_FlashTick( player : CR4Player, now : float )
{
	var module : CR4HudModuleOneliners;
	var i : int;

	for ( i = player.snFlashes.Size() - 1; i >= 0; i -= 1 )
	{
		if ( now < player.snFlashes[i].endTime )
			continue;
		module = SN_Oneliners();
		if ( module )
			module.OnRemoveOneliner( player.snFlashes[i].id );
		player.snFlashes.Erase( i );
	}
}

// ---------- Status above Geralt ----------
// Hidden (green), Noticed (green to red with the most suspicious enemy), Spotted (red)

function SN_StatusId() : int { return 7471050; }

function SN_SetStatus( player : CR4Player, text : string )
{
	var module : CR4HudModuleOneliners;

	if ( text == player.snStatusText )
		return;
	module = SN_Oneliners();
	if ( !module )
		return;
	if ( player.snStatusText != "" )
		module.OnRemoveOneliner( SN_StatusId() );
	player.snStatusText = text;
	if ( text != "" )
		module.OnCreateOneliner( player, text, SN_StatusId() );
}

function SN_StatusTick( player : CR4Player, now : float )
{
	var top : float;
	var i, step : int;

	if ( !SN_Toggle( 'SNStatus' ) )
	{
		SN_SetStatus( player, "" );
		return;
	}

	for ( i = 0; i < player.snTracks.Size(); i += 1 )
		top = MaxF( top, player.snTracks[i].aware );

	if ( now < player.snSpottedUntil )
		SN_SetStatus( player, "<font size='20' color='#E0302A'>Wykryty</font>" );
	else if ( top >= 0.08f )
	{
		step = 1 + Clamp( FloorF( top * 8.f ), 0, 7 );
		SN_SetStatus( player, "<font size='20' color='" + SN_SuspicionColor( step ) + "'>Zauważony</font>" );
	}
	else
		SN_SetStatus( player, "<font size='20' color='#8FBF8A'>Ukryty</font>" );
}

// ---------- Marker range ----------
// The game shows these markers up to 45 m; ours show up to the range in the options.

function SN_IsOurMarker( id : int ) : bool
{
	return id >= 7470100 && id < 7471100;
}

@wrapMethod(CR4HudModuleOneliners)
function OnTick( timeDelta : float )
{
	var res : bool;
	var i : int;
	var mc : CScriptedFlashSprite;
	var target : CActor;
	var screenPos, targetPos, playerPos : Vector;
	var range, dist : float;

	res = wrappedMethod( timeDelta );

	range = SN_Value( 'SNMarkerRange', 60 );
	playerPos = thePlayer.GetWorldPosition();
	for ( i = 0; i < m_oneliners.Size(); i += 1 )
	{
		if ( !SN_IsOurMarker( m_oneliners[i].m_ID ) )
			continue;
		target = m_oneliners[i].m_Target;
		if ( !target )
			continue;
		targetPos = target.GetWorldPosition();
		dist = VecDistance( targetPos, playerPos );
		if ( dist < 44.f )
			continue;		// the game's own range: already placed
		mc = m_flashModule.GetChildFlashSprite( "mcOneliner" + m_oneliners[i].m_ID );
		if ( !mc )
			continue;
		if ( dist <= range && GetBaseScreenPosition( screenPos, target, NULL, 0, true ) )
		{
			screenPos.Y -= 90;
			mc.SetPosition( screenPos.X, screenPos.Y );
			mc.SetVisible( true );
		}
		else
			mc.SetVisible( false );
	}
	return res;
}

// ---------- Takedowns ----------

// The unaware enemy Geralt is close behind and looking at
function SN_FindTakedown( player : CR4Player ) : CNewNPC
{
	var best, npc : CNewNPC;
	var bestScore, score, dist, facing, dz : float;
	var npcPos, playerPos : Vector;
	var camHeading : float;
	var i : int;

	if ( !SN_Toggle( 'SNTakedowns' ) || player.snPostTD || !SN_SneakState( player ) )
		return NULL;

	playerPos = player.GetWorldPosition();
	camHeading = VecHeading( theCamera.GetCameraDirection() );
	bestScore = 1000.f;

	for ( i = 0; i < player.snTracks.Size(); i += 1 )
	{
		npc = player.snTracks[i].npc;
		if ( !npc || !npc.IsAlive() || player.snTracks[i].aware >= 0.75f || npc.IsKnockedUnconscious() || !SN_SmallPrey( npc ) )
			continue;

		npcPos = npc.GetWorldPosition();
		dist = VecDistance( npcPos, playerPos );
		dz = npcPos.Z - playerPos.Z;
		if ( dist > SN_TakedownRange() || AbsF( dz ) > 0.7f )
			continue;

		if ( !SN_Toggle( 'SNTakedownAnySide' )
			&& AbsF( AngleDistance( npc.GetHeading(), VecHeading( playerPos - npcPos ) ) ) < 100.f )
			continue;

		facing = AbsF( AngleDistance( camHeading, VecHeading( npcPos - playerPos ) ) );
		if ( facing > 90.f )
			continue;

		score = dist + facing / 45.f;
		if ( score < bestScore )
		{
			bestScore = score;
			best = npc;
		}
	}
	return best;
}

function SN_TakedownWeapon( player : CR4Player, target : CActor ) : EPlayerWeapon
{
	var witcher : W3PlayerWitcher;
	var item : SItemUniqueId;
	var hasSteel, hasSilver : bool;

	witcher = (W3PlayerWitcher)player;
	if ( !witcher )
		return PW_Steel;

	hasSteel = witcher.GetItemEquippedOnSlot( EES_SteelSword, item );
	hasSilver = witcher.GetItemEquippedOnSlot( EES_SilverSword, item );

	if ( target.IsMonster() && hasSilver )
		return PW_Silver;
	if ( hasSteel )
		return PW_Steel;
	if ( hasSilver )
		return PW_Silver;
	return PW_Fists;
}

// Turns Geralt to the enemy and starts the attack (drawing the sword on the way)
@addMethod(CR4Player)
function SN_DrawAndAttack( target : CActor, weapon : EPlayerWeapon )
{
	var stateName : name;

	SN_FaceTarget( target );

	stateName = GetCurrentStateName();
	if ( stateName == 'CombatSteel' || stateName == 'CombatSilver' )
		SetupCombatAction( EBAT_LightAttack, BS_Pressed );
	else
		GoToCombat( weapon, IA_AttackLight );
}

@addMethod(CR4Player)
function SN_FaceTarget( target : CActor )
{
	var adjustor : CMovementAdjustor;
	var ticket : SMovementAdjustmentRequestTicket;

	adjustor = GetMovingAgentComponent().GetMovementAdjustor();
	adjustor.CancelByName( 'SNTakedown' );
	ticket = adjustor.CreateNewRequest( 'SNTakedown' );
	adjustor.RotateTowards( ticket, target );
	adjustor.MaxRotationAdjustmentSpeed( ticket, 1440.f );
	if ( VecDistance( target.GetWorldPosition(), GetWorldPosition() ) > 1.5f )
	{
		adjustor.SlideTowards( ticket, target, 1.1f, 1.4f );
		adjustor.MaxLocationAdjustmentSpeed( ticket, 3.f );
	}
	adjustor.KeepActiveFor( ticket, 0.5f );

	SetTarget( target, true );
	SetSlideTarget( target );
}

function SN_TryTakedown( player : CR4Player ) : bool
{
	var target : CNewNPC;
	var idx : int;

	if ( !player.snOn || player.snTDPhase > 0 || player.snPostTD || !SN_Toggle( 'SNTakedowns' ) )
		return false;

	target = player.snCandidate;
	if ( !target || !target.IsAlive() )
		return false;
	idx = SN_TrackIndex( player, target );
	if ( idx < 0 )
		return false;

	SN_SetMarker( player, idx, 0 );
	SN_SpeedOff( player );

	player.snTD = target;
	player.snTDPhase = 1;
	player.snTDTime = theGame.GetEngineTimeAsSeconds();
	player.snTDTagged = false;
	player.snTDWeapon = SN_TakedownWeapon( player, target );
	player.snCandidate = NULL;

	SN_Debug( "Takedown: " + target.GetDisplayName() );
	player.SN_DrawAndAttack( target, player.snTDWeapon );
	return true;
}

// The enemy stays unaware while the sword comes out. Then it gets its attitude back
// (the hit and the finisher need an enemy) just before the swing lands.
function SN_TakedownTick( player : CR4Player, now : float )
{
	var target : CNewNPC;
	var idx : int;

	if ( player.snTDPhase == 0 )
		return;

	target = player.snTD;
	if ( !target || !target.IsAlive() )
	{
		SN_EndTakedown( player, true );
		return;
	}

	if ( player.snTDPhase == 1 )
	{
		if ( ( SN_SwordHeld( player ) && player.GetCurrentMeleeWeaponType() == player.snTDWeapon )
			|| player.snTDWeapon == PW_Fists || now - player.snTDTime > 1.5f )
		{
			idx = SN_TrackIndex( player, target );
			if ( idx >= 0 )
				SN_Release( player, idx );
			player.snAlerted.PushBack( target );

			if ( target.IsHuman() && !target.IsWoman() && SN_Toggle( 'SNFinishers' ) && !target.HasTag( 'ForceFinisher' ) )
			{
				target.AddTag( 'ForceFinisher' );
				player.snTDTagged = true;
			}

			player.SN_FaceTarget( target );
			player.snTDPhase = 2;
			player.snTDTime = now;
		}
	}
	else if ( now - player.snTDTime > 2.f )
	{
		// the swing missed: it's a fight now
		SN_Debug( "Takedown missed" );
		SN_Flash( player, target );
		SN_EndTakedown( player, false );
	}
}

function SN_EndTakedown( player : CR4Player, killed : bool )
{
	if ( player.snTD && player.snTDTagged && player.snTD.IsAlive() )
		player.snTD.RemoveTag( 'ForceFinisher' );

	player.snTD = NULL;
	player.snTDPhase = 0;
	player.snTDTagged = false;

	if ( killed )
	{
		player.snPostTD = true;
		player.snPostTDTime = theGame.GetEngineTimeAsSeconds();
	}
}

// Enemies close by hear the kill; those looking see it
function SN_KillNoise( player : CR4Player )
{
	var noise, dist, sight : float;
	var i : int;

	noise = SN_Value( 'SNNoiseRadius', 4 );
	sight = SN_SightRange( player );

	for ( i = 0; i < player.snTracks.Size(); i += 1 )
	{
		if ( !player.snTracks[i].npc )
			continue;
		dist = VecDistance( player.snTracks[i].npc.GetWorldPosition(), player.GetWorldPosition() );
		if ( dist <= noise )
			player.snTracks[i].aware += 0.6f;
		if ( SN_SightGain( player, player.snTracks[i].npc, dist, sight ) > 0.f )
			player.snTracks[i].aware += 0.9f;
	}
}

// After a takedown: wait for the finisher to end, put the sword away, sneak on
function SN_PostTakedownTick( player : CR4Player, now : float )
{
	if ( !player.snPostTD )
		return;

	if ( player.IsPerformingFinisher() )
	{
		player.snPostTDTime = now;
		return;
	}

	// sneaking carries on once the finisher is over
	if ( now - player.snPostTDTime > 0.6f )
		player.snPostTD = false;
}

// Attack button: a takedown when one is possible
@wrapMethod(CPlayerInput)
function OnCbtAttackLight( action : SInputAction )
{
	var res : bool;

	if ( IsPressed( action ) && SN_TryTakedown( thePlayer ) )
		return true;
	res = wrappedMethod( action );
	return res;
}

// Hits on enemies that haven't noticed Geralt: the takedown kills, anything else
// gives Geralt away
@wrapMethod(W3DamageManager)
function ProcessAction( act : W3DamageAction )
{
	var player : CR4Player;
	var victim : CNewNPC;
	var idx : int;
	var takedown, sneakBolt : bool;
	var victimPos : Vector;

	if ( act )
	{
		player = (CR4Player)act.attacker;
		victim = (CNewNPC)act.victim;
	}

	if ( player && victim && player.snOn )
	{
		if ( victim == player.snTD && act.IsActionMelee() )
		{
			idx = SN_TrackIndex( player, victim );
			if ( idx >= 0 )
				SN_Release( player, idx );
			act.SetInstantKill();
			act.SetIgnoreInstantKillCooldown();
			takedown = true;
		}
		else if ( SN_TrackIndex( player, victim ) >= 0 && SN_IsBolt( act ) )
		{
			// a bolt from hiding: much harder, and the hit decides whether it gives
			// Geralt away (below)
			idx = SN_TrackIndex( player, victim );
			SN_Release( player, idx );
			SN_BoostBolt( act );
			sneakBolt = true;
			victimPos = victim.GetWorldPosition();
		}
		else if ( SN_TrackIndex( player, victim ) >= 0 )
			SN_Spot( player, victim, true );
	}

	wrappedMethod( act );

	if ( sneakBolt )
	{
		if ( victim.IsAlive() )
		{
			// survived: it knows where that came from, and so do those around it
			victim.NoticeActor( player );
			player.snAlerted.PushBack( victim );
			SN_Flash( player, victim );
			player.snSpottedUntil = theGame.GetEngineTimeAsSeconds() + 3.f;
			SN_AlertAround( player, victimPos );
			SN_Debug( "Sneak bolt: survived" );
		}
		else
		{
			player.snAlerted.PushBack( victim );
			SN_BodyNoise( player, victimPos );
			SN_Debug( "Sneak bolt: kill" );
		}
	}

	if ( takedown && !victim.IsAlive() )
	{
		SN_Debug( "Takedown done" );
		SN_EndTakedown( player, true );
		SN_KillNoise( player );
	}
}

// ---------- What can be killed in one go ----------
// People, and creatures about their size: nekkers, drowners, ghouls, wolves,
// harpies... Not trolls, giants, griffins, fiends, bears and the like, nor bosses.

function SN_SmallRadius() : float { return 0.6f; }

function SN_SmallPrey( actor : CActor ) : bool
{
	if ( !actor )
		return false;
	if ( actor.IsHuman() )
		return true;
	if ( actor.IsHuge() || actor.HasAbility( 'Boss' ) || actor.HasTag( 'boss' ) )
		return false;
	return actor.GetRadius() <= SN_SmallRadius();
}

// ---------- Rocks ----------
// Hold the sneak key: a rock lands where the camera looks (up to 25 m). Unaware
// enemies within earshot of it walk over to look; those that were looking that way
// get a little suspicious. Geralt himself isn't seen any more easily.

// Where a rock would land: where the camera looks, up to 25 m
function SN_RockAimPoint( out hitPos : Vector ) : bool
{
	var camPos, endPos, hitNormal : Vector;
	var groups : array<name>;

	camPos = theCamera.GetCameraPosition();
	endPos = camPos + VecNormalize( theCamera.GetCameraDirection() ) * 25.f;

	groups.PushBack( 'Terrain' );
	groups.PushBack( 'Static' );
	groups.PushBack( 'Destructible' );
	groups.PushBack( 'Foliage' );
	return theGame.GetWorld().StaticTrace( camPos, endPos, hitPos, hitNormal, groups );
}

// Hold C: Geralt winds up the throw and holds it while you aim with the camera
function SN_RockAimStart( player : CR4Player )
{
	var now : float;
	var aimPos : Vector;

	now = theGame.GetEngineTimeAsSeconds();
	if ( !SN_Toggle( 'SNRocks' ) || now - player.snRockAt < 1.5f || player.snTDPhase > 0
		|| player.snRockLandAt > 0.f || player.IsInCombatAction() || player.GetCurrentStateName() == 'AimThrow' )
		return;

	player.snRockAiming = true;
	player.snRockAimStart = now;
	player.snRockTurning = true;
	SN_Crosshair( true );
	player.snRockAimOk = SN_RockAimPoint( aimPos );
	player.snRockAimPos = aimPos;
	player.SN_RockThrowStart( VecHeading( theCamera.GetCameraDirection() ) - 45.f );
}

// While aiming Geralt stands side-on, about 45 degrees off the camera, as when aiming
// a bomb; he's only turned when the camera has swung well past that (no constant
// re-turning, which made him jitter)
function SN_RockAimTurn( player : CR4Player )
{
	var heading, dist : float;

	heading = VecHeading( theCamera.GetCameraDirection() );
	dist = AngleDistance( heading, VecHeading( player.GetHeadingVector() ) );
	if ( player.snRockTurning || dist < 30.f || dist > 60.f )
	{
		player.snRockTurning = true;
		player.SetCustomRotation( 'SNRock', heading - 45.f, 0.f, 0.4f, false );
	}
	if ( dist > 40.f && dist < 50.f )
		player.snRockTurning = false;
	player.SetBehaviorVariable( 'enableAimingLookAt', 1.f );
}

// The aiming crosshair (the crossbow's), in the middle of the screen where the rock goes
function SN_Crosshair( show : bool )
{
	var hud : CR4ScriptedHud;
	var module : CR4HudModuleCrosshair;

	hud = (CR4ScriptedHud)theGame.GetHud();
	if ( !hud )
		return;
	module = (CR4HudModuleCrosshair)hud.GetHudModule( "CrosshairModule" );
	if ( module )
		module.ShowElement( show, false );
}

// Let go of C: the rock flies to where the camera looks now (no spot: no throw)
function SN_RockRelease( player : CR4Player )
{
	var now : float;
	var hitPos : Vector;

	player.snRockAiming = false;
	SN_Crosshair( false );
	player.SetBehaviorVariable( 'enableAimingLookAt', 0.f );
	now = theGame.GetEngineTimeAsSeconds();

	if ( !SN_RockAimPoint( hitPos ) )
	{
		player.SetBehaviorVariable( 'throwStage', (int)TS_Stop );
		player.RaiseEvent( 'actionStop' );
		SN_Debug( "Rock: nothing to hit there" );
		return;
	}

	player.snRockAt = now;
	player.snRockPos = hitPos;
	player.SetCustomRotation( 'SNRock', VecHeading( hitPos - player.GetWorldPosition() ), 0.f, 0.3f, false );
	player.SetBehaviorVariable( 'throwStage', (int)TS_End );
	player.snRockLandAt = now + 0.4f + VecDistance( hitPos, player.GetWorldPosition() ) / 18.f;
}
function SN_RockTick( player : CR4Player, now : float )
{
	var aimPos : Vector;

	if ( player.snRockAiming )
	{
		// stopped sneaking, or held for ages: throw now
		if ( !player.snOn || now - player.snRockAimStart > 8.f )
			SN_RockRelease( player );
		else
		{
			player.snRockAimOk = SN_RockAimPoint( aimPos );
			player.snRockAimPos = aimPos;
			SN_RockAimTurn( player );
		}
	}
	if ( player.snRockLandAt > 0.f && now >= player.snRockLandAt )
	{
		player.snRockLandAt = 0.f;
		SN_RockLand( player, player.snRockPos );
	}
}

// Geralt's bomb throw, with nothing in his hand
@addMethod(CR4Player)
function SN_RockThrowStart( heading : float )
{
	SetCustomRotation( 'SNRock', heading, 0.f, 0.3f, false );
	SetBehaviorVariable( 'throwStage', (int)TS_Start );
	SetBehaviorVariable( 'combatActionType', (int)CAT_ItemThrow );
	SetBehaviorVariable( 'itemType', (int)IT_Petard );
	if ( RaiseForceEvent( 'CombatAction' ) )
		OnCombatActionStart();
}

// Aiming a rock: the bomb-aiming camera. The game's own aiming switches the camera
// to its 'AimThrow' controllers and keeps it close over Geralt's shoulder; the same
// here, and the previous controllers come back afterwards.
function SN_AimCamera( player : CR4Player, out moveData : SCameraMovementData, dt : float ) : bool
{
	var cam : CCustomCamera;

	cam = theGame.GetGameCamera();
	if ( !cam )
		return false;

	if ( true )		// zoom removed (didn't work); controllers restored if a save had it on
	{
		if ( player.snZoomOn )
		{
			player.snZoomOn = false;
			cam.ChangePivotRotationController( player.snPrevRotCtrl );
			cam.ChangePivotDistanceController( player.snPrevDistCtrl );
			cam.ChangePivotPositionController( player.snPrevPosCtrl );
		}
		return false;
	}

	if ( !player.snZoomOn )
	{
		player.snZoomOn = true;
		player.snPrevRotCtrl = cam.GetActivePivotRotationController().controllerName;
		player.snPrevDistCtrl = cam.GetActivePivotDistanceController().controllerName;
		player.snPrevPosCtrl = cam.GetActivePivotPositionController().controllerName;
	}

	cam.ChangePivotRotationController( 'AimThrow' );
	cam.ChangePivotPositionController( 'Default' );
	cam.ChangePivotDistanceController( 'AimThrow' );
	moveData.pivotRotationController = cam.GetActivePivotRotationController();
	moveData.pivotDistanceController = cam.GetActivePivotDistanceController();
	moveData.pivotPositionController = cam.GetActivePivotPositionController();

	moveData.pivotPositionController.SetDesiredPosition( player.GetWorldPosition(), 100.f );
	moveData.pivotRotationController.SetDesiredPitch( moveData.pivotRotationValue.Pitch, 3.f );
	moveData.pivotRotationController.SetDesiredHeading( moveData.pivotRotationValue.Yaw, 1.f );
	moveData.pivotDistanceController.SetDesiredDistance( 1.f );
	moveData.pivotPositionController.offsetZ = 1.5f;
	DampVectorSpring( moveData.cameraLocalSpaceOffset, moveData.cameraLocalSpaceOffsetVel, Vector( 0.75f, 0.7f, 0.2f ), 0.2f, dt );
	return true;
}

@wrapMethod(CR4PlayerStateExploration)
function OnGameCameraTick( out moveData : SCameraMovementData, dt : float )
{
	var res : bool;

	if ( SN_AimCamera( parent, moveData, dt ) )
		return true;
	res = wrappedMethod( moveData, dt );
	return res;
}

@wrapMethod(CR4PlayerStateCombat)
function OnGameCameraTick( out moveData : SCameraMovementData, dt : float )
{
	var res : bool;

	if ( SN_AimCamera( parent, moveData, dt ) )
		return true;
	res = wrappedMethod( moveData, dt );
	return res;
}
// The wind-up reaches the point where the game decides between throwing and holding
// to aim: held while C is
@wrapMethod(CR4Player)
function OnAnimEvent_ThrowHoldTest( animEventName : name, animEventType : EAnimationEventType, animInfo : SAnimationEventAnimInfo )
{
	var res : bool;

	if ( snRockAiming )
	{
		SetBehaviorVariable( 'throwStage', (int)TS_Loop );
		return true;
	}
	res = wrappedMethod( animEventName, animEventType, animInfo );
	return res;
}

// The rock hits the ground: enemies in earshot come to look (no sound yet)
function SN_RockLand( player : CR4Player, pos : Vector )
{
	var radius : float;
	var i, n : int;
	var npc : CNewNPC;
	var spot : CEntity;
	var hasSpot : bool;

	if ( !player.snOn )
		return;

	radius = SN_Value( 'SNRockRadius', 8 );

	// The game's own reactions, sent from a hidden object where the rock landed:
	// "danger" there (what landing projectiles send - monsters go and search), and
	// a "taunt" (people stop and look over)
	spot = SN_PlaceRockSpot( player, pos );
	if ( spot )
	{
		theGame.GetBehTreeReactionManager().CreateReactionEventCustomCenter( spot, 'Danger', 10.f, radius, 2.f, -1, true, true, pos );
		theGame.GetBehTreeReactionManager().CreateReactionEventIfPossible( spot, 'TauntAction', 5.f, radius, 2.f, 9999, true, true, pos );
		hasSpot = true;
	}

	for ( i = 0; i < player.snTracks.Size(); i += 1 )
	{
		npc = player.snTracks[i].npc;
		if ( !npc || npc == player.snTD || VecDistance( npc.GetWorldPosition(), pos ) > radius )
			continue;
		SN_Distract( player, i, pos );
		n += 1;
	}
	SN_Debug( "Rock: " + IntToString( n ) + " distracted, noise object " + SN_YesNo( hasSpot ) );
}// A hidden object where the rock landed, tagged so the game's "walk to" order can
// find it (the order the game's own debug commands use to move NPCs)
function SN_PlaceRockSpot( player : CR4Player, spot : Vector ) : CEntity
{
	var tmpl : CEntityTemplate;
	var tags : array<name>;
	var rot : EulerAngles;

	if ( player.snRockSpot )
		player.snRockSpot.Destroy();
	player.snRockSpot = NULL;

	tmpl = (CEntityTemplate)LoadResource( "items\weapons\projectiles\arrows\arrow_01.w2ent", true );
	if ( !tmpl )
		return NULL;
	tags.PushBack( 'SNRockSpot' );
	player.snRockSpot = theGame.CreateEntity( tmpl, spot, rot, true, false, true, PM_DontPersist, tags );
	if ( player.snRockSpot )
	{
		player.snRockSpot.SetHideInGame( true );
		player.snRockSpot.DestroyAfter( 20.f );
	}
	return player.snRockSpot;
}

// Ends the enemy's "go and look" order (spotted, released, or it's been long enough)
function SN_EndDistract( player : CR4Player, idx : int )
{
	var npc : CNewNPC;

	if ( player.snTracks[idx].distractId == 0 )
		return;
	npc = player.snTracks[idx].npc;
	if ( npc )
	{
		npc.CancelAIBehavior( player.snTracks[idx].distractId );
		npc.ForceAIUpdate();
	}
	player.snTracks[idx].distractId = 0;
}

// The enemy heard the rock: for a while it looks over there (Sneak's own senses
// use that, so it doesn't see Geralt behind or beside it), and it turns to look.
function SN_Distract( player : CR4Player, idx : int, pos : Vector ) : int
{
	var npc : CNewNPC;
	var order : CAIMoveToAction;

	npc = player.snTracks[idx].npc;
	SN_EndDistract( player, idx );
	player.snTracks[idx].distractPos = pos;
	player.snTracks[idx].distractUntil = theGame.GetEngineTimeAsSeconds() + SN_Value( 'SNRockTime', 10 );
	player.snTracks[idx].distractWalking = false;

	// A forced AI order interrupts what it's doing (work, idling, patrol); when the
	// distraction ends it's cancelled and its AI goes back to its activity
	if ( player.snRockSpot )
	{
		order = new CAIMoveToAction in npc;
		order.OnCreated();
		order.params.targetTag = 'SNRockSpot';
		order.params.moveType = MT_Walk;
		order.params.moveSpeed = 1.f;
		order.params.maxDistance = 1.5f;
		order.params.rotateAfterwards = true;
		order.params.tolerance = 1.f;
		player.snTracks[idx].distractId = npc.ForceAIBehavior( order, BTAP_AboveCombat );
		npc.ForceAIUpdate();
	}

	SN_NpcFace( npc, VecHeading( pos - npc.GetWorldPosition() ) );
	return 1;
}
// Every check (0.1 s) while distracted: walk towards the rock - the NPC's own
// walking, steered the way Multi Companion Mod walks NPCs (move type, speed and
// direction on its movement, every 0.1 s) - then stand there looking at it
function SN_DistractTick( player : CR4Player, idx : int )
{
	var npc : CNewNPC;

	npc = player.snTracks[idx].npc;
	SN_NpcFace( npc, VecHeading( player.snTracks[idx].distractPos - npc.GetWorldPosition() ) );
}
function SN_StopWalk( player : CR4Player, idx : int )
{
	var npc : CNewNPC;

	player.snTracks[idx].distractWalking = false;
	npc = player.snTracks[idx].npc;
	if ( npc )
		npc.GetMovingAgentComponent().SetGameplayRelativeMoveSpeed( 0.f );
}

// Turns the enemy's body to face a heading - the same way Geralt is turned with the
// camera while sneaking; its AI can't override it. Renewed every check (0.1 s)
// while it's distracted, then it lets go.
function SN_NpcFace( npc : CActor, heading : float )
{
	var adjustor : CMovementAdjustor;
	var ticket : SMovementAdjustmentRequestTicket;

	adjustor = npc.GetMovingAgentComponent().GetMovementAdjustor();
	if ( !adjustor )
		return;
	ticket = adjustor.GetRequest( 'SNRockLook' );
	if ( !adjustor.IsRequestActive( ticket ) )
	{
		ticket = adjustor.CreateNewRequest( 'SNRockLook' );
		adjustor.ReplaceRotation( ticket );
	}
	adjustor.RotateTo( ticket, heading );
	adjustor.MaxRotationAdjustmentSpeed( ticket, 240.f );
	adjustor.KeepActiveFor( ticket, 0.25f );
}// ---------- Crossbow from hiding ----------

function SN_IsBolt( act : W3DamageAction ) : bool
{
	var attack : W3Action_Attack;

	attack = (W3Action_Attack)act;
	return attack && act.IsActionRanged() && attack.GetAttackName() == 'bolt';
}

function SN_IsTrackedEnt( player : CR4Player, ent : CGameplayEntity ) : bool
{
	var actor : CActor;

	actor = (CActor)ent;
	return actor && SN_TrackIndex( player, actor ) >= 0;
}

// While sneaking, enemies that haven't noticed Geralt are neutral to him, and the
// game won't let him shoot at "friendly" people out of a fight ("can't do that
// now"). They're still enemies: the crossbow may fire at them.
@wrapMethod(RangedWeapon)
function CanAttackWhenNotInCombat() : bool
{
	var res : bool;
	var player : CR4Player;

	res = wrappedMethod();
	if ( res )
		return true;

	player = thePlayer;
	if ( !player || !player.snOn )
		return false;
	if ( SN_IsTrackedEnt( player, player.GetDisplayTarget() ) || SN_IsTrackedEnt( player, player.slideTarget )
		|| SN_IsTrackedEnt( player, (CGameplayEntity)player.playerAiming.GetSweptFriendly() ) )
		return true;
	return false;
}

@wrapMethod(CR4Player)
function CanAttackWhenNotInCombat( actionType : EBufferActionType, altCast : bool, out newTarget : CActor, optional target : CGameplayEntity ) : bool
{
	var res : bool;

	res = wrappedMethod( actionType, altCast, newTarget, target );
	if ( res || !snOn || actionType != EBAT_ItemUse )
		return res;
	// shooting or throwing at an enemy that hasn't noticed Geralt
	if ( SN_IsTrackedEnt( this, target ) || SN_IsTrackedEnt( this, GetDisplayTarget() ) || SN_IsTrackedEnt( this, slideTarget ) )
		return true;
	return res;
}

// Bolt damage times the option (400 % by default); a head shot kills outright
function SN_BoostBolt( act : W3DamageAction )
{
	var dts : array<SRawDamage>;
	var mult : float;
	var i : int;
	var small : bool;

	small = SN_SmallPrey( (CActor)act.victim );
	mult = SN_Value( 'SNBoltPct', 400 ) / 100.f;
	if ( !small )
		mult = MinF( mult, 1.5f );		// big monsters: a surprise, not a kill
	act.GetDTs( dts );
	for ( i = 0; i < dts.Size(); i += 1 )
		act.AddDamage( dts[i].dmgType, dts[i].dmgVal * ( mult - 1.f ) );	// adds to what's there

	if ( small && act.GetIsHeadShot() && SN_Toggle( 'SNHeadshotKill' ) )
	{
		act.SetInstantKill();
		act.SetIgnoreInstantKillCooldown();
	}
}

// A body dropping: enemies near it hear it, those looking at it see it
function SN_BodyNoise( player : CR4Player, pos : Vector )
{
	var noise, dist : float;
	var i : int;
	var npc : CNewNPC;
	var npcPos : Vector;

	noise = SN_Value( 'SNNoiseRadius', 4 );
	for ( i = 0; i < player.snTracks.Size(); i += 1 )
	{
		npc = player.snTracks[i].npc;
		if ( !npc )
			continue;
		npcPos = npc.GetWorldPosition();
		dist = VecDistance( npcPos, pos );
		if ( dist <= noise )
			player.snTracks[i].aware += 0.6f;
		if ( dist <= SN_SightRange( player )
			&& AbsF( AngleDistance( npc.GetHeading(), VecHeading( pos - npcPos ) ) ) <= 60.f )
			player.snTracks[i].aware += 0.5f;
	}
}

// ---------- Test messages ----------

function SN_DebugTick( player : CR4Player, now : float )
{
	var i : int;
	var top : float;
	var text : string;

	if ( !SN_Toggle( 'SNDebug' ) || now - player.snDebugTime < 1.5f )
		return;
	player.snDebugTime = now;

	for ( i = 0; i < player.snTracks.Size(); i += 1 )
		top = MaxF( top, player.snTracks[i].aware );

	text = "Sneak: " + IntToString( player.snTracks.Size() ) + " unaware, top " + IntToString( RoundF( top * 100.f ) ) + "%";
	text += ", sight " + IntToString( RoundF( SN_SightRange( player ) ) ) + " m";
	text += ", stance " + IntToString( (int)player.GetPlayerCombatStance() );
	if ( SN_SwordHeld( player ) )
		text += ", sword in hand";
	if ( player.snCandidate )
		text += ", takedown ready";
	if ( player.snTDPhase > 0 )
		text += ", takedown phase " + IntToString( player.snTDPhase );
	theGame.GetGuiManager().ShowNotification( text, 1400 );
}

// Drawing the sword while sneaking alerts nobody: the base game tells everyone within
// 8 m that Geralt drew (guards and townsfolk react to that). Same as the base game
// otherwise.
@wrapMethod(WeaponHolsterStateSelectingWeapon)
function OnWeaponDrawReady()
{
	var res : bool;

	if ( thePlayer && thePlayer.snOn )
	{
		Unlock();
		thePlayer.SetBehaviorVariable( 'holsterReadyToSkip', 1.0f, true );
		thePlayer.SetBehaviorVariable( 'playerWeaponLatent', thePlayer.GetBehaviorVariable( 'playerWeapon' ) );
		return true;
	}
	res = wrappedMethod();
	return res;
}

// Geralt keeps quiet while sneaking: no battle cries or taunts ("What? Lost your
// nerve?") that would give him away
@wrapMethod(CR4Player)
function PlayBattleCry( _BattleCry : name, _Chance : float, optional _IgnoreDelay, ignoreRepeatCheck : bool )
{
	if ( snOn )
		return;
	wrappedMethod( _BattleCry, _Chance, _IgnoreDelay, ignoreRepeatCheck );
}
