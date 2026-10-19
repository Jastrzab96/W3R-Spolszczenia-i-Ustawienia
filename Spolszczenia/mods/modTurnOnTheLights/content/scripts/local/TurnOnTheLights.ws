/***********************************************************************/
/** 	TurnOnTheLights.ws
/** 	by Phaz42
/***********************************************************************/

class TurnOnTheLights
{
	
	private var	manualMode : bool;
    private var maxRange : int;
    private var autoModeTarget : bool;
    private var useActionButton : bool;
    private var disableAutoModeInDaytime : bool;

	private var	actionTimerRunning : bool;
		default	actionTimerRunning = false;
	private var	actionCount: int;
		default actionCount = 0;

    public var configWrapper: CInGameConfigWrapper;
    public var hideInteractions : bool;
    // 5.0.0: holds the running toggle, so the engine cannot collect it while it sleeps (on 5.00b it never woke up)
    private var toggleLightsJob : ToggleLights;

    public function Init()
    {
        var tempRange : int;

        Log( "Init Start" );
        configWrapper = theGame.GetInGameConfigWrapper();
        LogConfig();

        // Mode
        if ( configWrapper.GetVarValue( 'modTurnOnTheLights', 'mode') == "0" )
        {
            Log( "Init: mode: manual" );
            manualMode = true;
        }
        else
        {
            Log( "Init: mode: auto" );
            manualMode = false;
            thePlayer.AddTimer('TurnOnTheLightsAutoTimer', 0.1 );
            configWrapper.SetVarValue( 'modTurnOnTheLights', 'mode', 1 );
        }

        // Automatic Mode Target
        if ( configWrapper.GetVarValue( 'modTurnOnTheLights', 'automodetarget' ) == "false" )
        {
            Log( "Init: automodetarget: false" );
            autoModeTarget = false;
        }
        else
        {
            Log( "Init: automodetarget: true" );
            autoModeTarget = true;
            configWrapper.SetVarValue( 'modTurnOnTheLights', 'automodetarget', true );
        }

        // Range
        tempRange = -1;
        tempRange = StringToInt(configWrapper.GetVarValue( 'modTurnOnTheLights', 'range'));
        if ( tempRange >= 10 && tempRange <= 50 )
        {
            Log( "Init: range: defined" );
            maxRange = tempRange;
        }
        else
        {
            Log( "Init: range: undefined" );
            maxRange = 20;
            configWrapper.SetVarValue( 'modTurnOnTheLights', 'range', 20 );
        }

        // Hide Interactions
        if ( configWrapper.GetVarValue( 'modTurnOnTheLights', 'hideinteractions' ) == "false" )
        {
            Log( "Init: hideinteractions: false" );
            hideInteractions = false;
        }
        else
        {
            Log( "Init: hideinteractions: true" );
            hideInteractions = true;
            configWrapper.SetVarValue( 'modTurnOnTheLights', 'hideinteractions', true );
        }

        // Action Button
        if ( configWrapper.GetVarValue( 'modTurnOnTheLights', 'useactionbutton' ) == "false" )
        {
            Log( "Init: useactionbutton: false" );
            useActionButton = false;
        }
        else
        {
            Log( "Init: useactionbutton: true" );
            useActionButton = true;
            configWrapper.SetVarValue( 'modTurnOnTheLights', 'useactionbutton', true );
        }

        // Disable Auto Mode during day
        if ( configWrapper.GetVarValue( 'modTurnOnTheLights', 'disableautomodeindaytime' ) == "true" )
        {
            Log( "Init: disableautomodeindaytime: true" );
            disableAutoModeInDaytime = true;
        }
        else
        {
            Log( "Init: disableautomodeindaytime: false" );
            disableAutoModeInDaytime = false;
            configWrapper.SetVarValue( 'modTurnOnTheLights', 'disableautomodeindaytime', false );
        }

        theGame.SaveUserSettings();
        LogConfig();
        Log( "Init End" );
    }

    public function ReInit()
	{
        Log( "ReInit after closing Menu" );
        thePlayer.RemoveTimer('TurnOnTheLightsAutoTimer');
        Init();
    }

    private function LogConfig()
    {
        Log( "LogConfig: GetVarValue(mode): " + configWrapper.GetVarValue( 'modTurnOnTheLights', 'mode') );
        Log( "LogConfig: GetVarValue(automodetarget): " + configWrapper.GetVarValue( 'modTurnOnTheLights', 'automodetarget') );
        Log( "LogConfig: GetVarValue(range): " + configWrapper.GetVarValue( 'modTurnOnTheLights', 'range') );
        Log( "LogConfig: GetVarValue(automodetarget): " + configWrapper.GetVarValue( 'modTurnOnTheLights', 'hideinteractions') );
        Log( "LogConfig: GetVarValue(automodetarget): " + configWrapper.GetVarValue( 'modTurnOnTheLights', 'useactionbutton') );
        Log( "LogConfig: GetVarValue(automodetarget): " + configWrapper.GetVarValue( 'modTurnOnTheLights', 'disableautomodeindaytime') );
    }
    
    public function GetEntities() : array<CGameplayEntity>
	{
		var entities	: array<CGameplayEntity>;
		var maxResults	: int;
		
		maxResults 	= 10000;

		Log( "GetEntities: maxRange: " + maxRange );
        FindGameplayEntitiesInRange( entities, thePlayer, (float)maxRange, maxResults );
        Log( "GetEntities: found " + IntToString(entities.Size()) + " entities" );

		return entities;
	}

	public function GetGameLightComps( entity : CGameplayEntity ) : CGameplayLightComponent
	{
		return (CGameplayLightComponent)entity.GetComponentByClassName('CGameplayLightComponent');
	}

    private function HudMsg ( msg : string )
    {
        Log( "HudMsg: " + msg );
        GetWitcherPlayer().DisplayHudMessage( msg );
    }

    private function ConsoleMsg ( msg : string )
    {
        Log( "ConsoleMsg: " + msg );
        ((CR4ScriptedHud)theGame.GetHud()).HudConsoleMsg( msg );
    }

    private function ShowNotification ( msg : string )
    {
        Log( "ShowNotification: " + msg );
        theGame.GetGuiManager().ShowNotification( msg );
    }

    public function Log( msg : string )
    {
        LogChannel( 'modTurnOnTheLights', msg );
    }
	
	public function ToggleMode()
	{
        if ( manualMode )
		{
			// goto auto
			Log( "ToggleMode: Auto" );           
            ShowNotification( GetLocStringByKey("panel_totl_mod_name") + ": " + GetLocStringByKey("option_totl_notification_auto") );
            //ShowNotification( "Turn On The Lights: Automatic Mode" );
            manualMode = false;
            configWrapper.SetVarValue('modTurnOnTheLights', 'mode', 1);
            theGame.SaveUserSettings();
			thePlayer.AddTimer('TurnOnTheLightsAutoTimer', 0.1 );
		}
		else
		{
			// goto manual
			Log( "ToggleMode: Manual" );
            ShowNotification( GetLocStringByKey("panel_totl_mod_name") + ": " + GetLocStringByKey("option_totl_notification_manual") );
            //ShowNotification( "Turn On The Lights: Manual Mode" );
			thePlayer.RemoveTimer('TurnOnTheLightsAutoTimer');
			manualMode = true;
            configWrapper.SetVarValue('modTurnOnTheLights', 'mode', 0);
            theGame.SaveUserSettings();
		}
	}
	
	public function LightsSwitch( entities : array<CGameplayEntity>, switchOn : bool )
	{
		var i: int;
		var gameLightComp	: CGameplayLightComponent;

		Log( "LightsSwitch: " + switchOn );
		
		for ( i = 0; i < entities.Size(); i += 1 )
		{
			gameLightComp = GetGameLightComps( entities[i] );
			if ( gameLightComp && gameLightComp.IsInteractive() && ( gameLightComp.IsLightOn() != switchOn ) )
			{
				gameLightComp.SetLight(switchOn);
			}
		}
	}

    public function IsAutoModeAllowed() : bool
    {
        var currentHour : int;
        var currentWeather : name;

        Log( "IsAutoModeAllowed" );
		
        // Check Interior
        if ( thePlayer.IsInInterior() )
        {
            Log( "return true, we're inside" );
            return true;
        }

        // Check Weather
        currentWeather = GetWeatherConditionName();
        Log( "currentWeather: " + NameToString( currentWeather ) );
        if ( currentWeather == 'WT_Heavy_Clouds_Dark' || currentWeather == 'WT_Rain_Storm')
        {
            Log( "return true, it's bad weather" );
            return true;
        }

        currentHour = GameTimeHours(theGame.GetGameTime());
        Log( "currentHour: " + currentHour );
        if ( disableAutoModeInDaytime && currentHour >= 7 && currentHour <= 16 )
        {
            Log( "return false, its daytime" );
            return false;
        }

        Log( "return true" );
        return true;
    }

	public function AutoTimer()
	{       
        Log( 'TurnOnTheLightsAutoTimer' );
		if (IsAutoModeAllowed())
        {
            LightsSwitch( GetEntities(), autoModeTarget );
        }
        thePlayer.AddTimer('TurnOnTheLightsAutoTimer', 2.0);
	}

	public function StartActionTimer()
	{
		Log( 'StartActionTimer' );
		actionTimerRunning = true;
		actionCount = 1;
		thePlayer.AddTimer( 'TurnOnTheLightsActionTimer', 0.7, false );
	}
	
	public function StopActionTimer()
	{
		Log( 'StopActionTimer' );
		thePlayer.RemoveTimer( 'TurnOnTheLightsActionTimer' );
		actionCount = 0;
		actionTimerRunning = false;
	}
	
	public function IsActionTimerRunning() : bool
	{
		return actionTimerRunning;
	}

    public function ToggleLights()
	{
		var toggleLights : ToggleLights;
        
        Log( 'ToggleLights' );
        thePlayer.RemoveTimer('TurnOnTheLightsAutoTimer');
        toggleLights = new ToggleLights in theGame;
        toggleLightsJob = toggleLights;
        toggleLights.Init();
        if (!manualMode)
        {
            thePlayer.AddTimer('TurnOnTheLightsAutoTimer', 2.0 );
        }
	}

	public function ActionTimer()
	{
		var toggleLights : ToggleLights;

        Log( "TurnOnTheLightsActionTimer, actionCount: " + actionCount );
       
       if ( actionCount == 2 && ( manualMode || !IsAutoModeAllowed() ))
		{ 
            Log( "TurnOnTheLightsActionTimer, start action for count 2" );
            StopActionTimer();
            ToggleLights();
		}

        if ( actionCount == 3 )
        {
            Log( "TurnOnTheLightsActionTimer, start action for count 3" );
            if( thePlayer.IsActionAllowed(EIAB_Signs) )
            {
                ToggleMode();
                StopActionTimer();
            }
            else
            {				
                thePlayer.DisplayActionDisallowedHudMessage(EIAB_Signs);
            }
        }

        if ( actionCount == 4 )
		{ 
            Log( "TurnOnTheLightsActionTimer, start action for count 4" );
            Log( "ActionTimer maxRange before: " + maxRange );
            switch( maxRange )
            {
                case 50 :
                {
                    Log( "ActionTimer case: 50" );
                    maxRange = 10;
                    configWrapper.SetVarValue( 'modTurnOnTheLights', 'range', 10 );
                    ShowNotification( GetLocStringByKey("panel_totl_mod_name") + ": " + GetLocStringByKey("option_totl_notification_range") + " 10m" );
                    //ShowNotification( "Turn On The Lights: Range 10m" );
                    break;
                }
                case 10 :
                {
                    Log( "ActionTimer case: 10" );
                    maxRange = 20;
                    configWrapper.SetVarValue( 'modTurnOnTheLights', 'range', 20 );
                    ShowNotification( GetLocStringByKey("panel_totl_mod_name") + ": " + GetLocStringByKey("option_totl_notification_range") + " 20m" );
                    //ShowNotification( "Turn On The Lights: Range 20m" );
                    break;
                }
                case 20 :
                {
                    Log( "ActionTimer case: 20" );
                    maxRange = 50;
                    configWrapper.SetVarValue( 'modTurnOnTheLights', 'range', 50 );
                    ShowNotification( GetLocStringByKey("panel_totl_mod_name") + ": " + GetLocStringByKey("option_totl_notification_range") + " 50m" );
                    //ShowNotification( "Turn On The Lights: Range 50m" );
                    break;
                }
                default :
                {
                    Log( "ActionTimer case: default" );
                    maxRange = 20;
                    configWrapper.SetVarValue( 'modTurnOnTheLights', 'range', 20 );
                    ShowNotification( GetLocStringByKey("panel_totl_mod_name") + ": " + GetLocStringByKey("option_totl_notification_range") + " 20m" );
                    //ShowNotification( "Turn On The Lights: Range 20m" );
                    break;
                }
                Log( "ActionTimer maxRange after: " + maxRange );
            }
            theGame.SaveUserSettings();
		}

		StopActionTimer();
	}

    public function ProcessInput()
    {
		if (useActionButton)
        {
            Log( "ProcessInput: actionCount: " + actionCount );
            if ( IsActionTimerRunning() )
            {
                Log( "ProcessInput: actionCount++" );
                actionCount += 1;
                
            }
            else
            {
                StartActionTimer();
            }
        }
        else
        {
            Log( "ProcessInput: Input ignored, action button is disabled" );
        }
    }
}

statemachine class ToggleLights
{
    function Init()
	{
		LogChannel( 'modTurnOnTheLights', 'ToggleLights Init' );
        this.PushState('Active');
	}
}

state Active in ToggleLights
{
    var entities		: array<CGameplayEntity>;
    var i				: int;
    var gameLightComp	: CGameplayLightComponent;
    var lightsOff		: bool;
    var turnOnTheLights : TurnOnTheLights;
    saved var restoreItemLAtEnd	: bool;

    event OnEnterState(prevStateName : name)
	{
		LogChannel( 'modTurnOnTheLights', 'ToggleLights EnterState' );
        turnOnTheLights = ((W3PlayerWitcher)thePlayer).turnOnTheLights;
        Toggle();
	}

    entry function Toggle()
    {
        LogChannel( 'modTurnOnTheLights', 'ToggleLights Toggle' );
    
        lightsOff	= false;
        entities	= turnOnTheLights.GetEntities();

        for ( i = 0; i < entities.Size(); i += 1 )
        {
            gameLightComp = turnOnTheLights.GetGameLightComps( entities[i] );
            if ( gameLightComp && gameLightComp.IsInteractive() && !gameLightComp.IsLightOn() )
            {
                lightsOff = true;
            }
        }

        if ( thePlayer.IsHoldingItemInLHand() )
        {
            thePlayer.OnUseSelectedItem( true );
            restoreItemLAtEnd = true;
        }

        if ( lightsOff )
        {
            LogChannel( 'modTurnOnTheLights', 'ToggleLights Toggle On' );
            thePlayer.PlayerStartAction( PEA_IgniLight );
            LogChannel( 'modTurnOnTheLights', 'ToggleLights Start Sleep' );
            Sleep( 0.9 );
            LogChannel( 'modTurnOnTheLights', 'ToggleLights Stop Sleep' );
            turnOnTheLights.LightsSwitch( entities, true );
        }
        else
        {
            LogChannel( 'modTurnOnTheLights', 'ToggleLights Toggle Off' );
            thePlayer.PlayerStartAction( PEA_AardLight );
            LogChannel( 'modTurnOnTheLights', 'ToggleLights Start Sleep' );
            Sleep( 0.9 );
            LogChannel( 'modTurnOnTheLights', 'ToggleLights Stop Sleep' );
            turnOnTheLights.LightsSwitch( entities, false );
        }

        if ( restoreItemLAtEnd )
        {
            thePlayer.OnUseSelectedItem( );
            restoreItemLAtEnd = false;
        }
    }
}