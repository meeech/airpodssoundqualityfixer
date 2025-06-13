#import "AppDelegate.h"
#import "GBLaunchAtLogin.h"
#import <CoreAudio/CoreAudio.h>


@interface AppDelegate ( )
{
    BOOL paused;
    NSMenu* menu;
    NSStatusItem* statusItem;
    AudioDeviceID forcedInputID; // Effective device ID to be forced
    AudioDeviceID preferredMicID; // User's primary preferred mic
    AudioDeviceID fallbackMicID;  // User's secondary/fallback mic
    NSUserDefaults* defaults;
    // NSMutableDictionary* itemsToIDS; // No longer needed
    NSMenuItem *startupItem;
}

@property (weak) IBOutlet NSWindow *window;

@end


@implementation AppDelegate


OSStatus callbackFunction(  AudioObjectID inObjectID,
                            UInt32 inNumberAddresses,
                            const AudioObjectPropertyAddress inAddresses[],
                            void *inClientData)
{

    printf( "default input device changed" );
    // check default input
    [ ( (__bridge  AppDelegate* ) inClientData ) listDevices ];

    return 0;
}


- ( void ) applicationDidFinishLaunching : ( NSNotification* ) aNotification
{

    defaults = [ NSUserDefaults standardUserDefaults ];
    
    // itemsToIDS = [ NSMutableDictionary dictionary ]; // No longer needed
    
    
    NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
    // Load preferred and fallback microphone IDs
    preferredMicID = (AudioDeviceID)[prefs integerForKey:@"PreferredMicDeviceID"];
    if (preferredMicID == 0) { // If not set or old value, default to UINT32_MAX (no preference)
        preferredMicID = UINT32_MAX;
        [prefs setInteger:preferredMicID forKey:@"PreferredMicDeviceID"];
    }

    fallbackMicID = (AudioDeviceID)[prefs integerForKey:@"FallbackMicDeviceID"];
    if (fallbackMicID == 0) { // If not set or old value, default to UINT32_MAX (no preference)
        fallbackMicID = UINT32_MAX;
        [prefs setInteger:fallbackMicID forKey:@"FallbackMicDeviceID"];
    }
    
    // forcedInputID will be determined in listDevices based on preferred/fallback availability
    forcedInputID = UINT32_MAX; // Initialize, will be set properly in listDevices

    NSLog(@"Loaded PreferredMicDeviceID: %u, FallbackMicDeviceID: %u", preferredMicID, fallbackMicID);
    [prefs synchronize]; // Ensure any defaults set are saved

    NSImage* image = [ NSImage imageNamed : @"airpods-icon" ];
    [ image setTemplate : YES ];

    statusItem = [ [ NSStatusBar systemStatusBar ] statusItemWithLength : NSVariableStatusItemLength ];
    [ statusItem setToolTip : @"AirPods Audio Quality & Battery Life Fixer" ];
    [ statusItem setImage : image ];

    // add listener for detecting when input device is changed

    AudioObjectPropertyAddress inputDeviceAddress = {
        kAudioHardwarePropertyDefaultInputDevice,
        kAudioObjectPropertyScopeGlobal,
        kAudioObjectPropertyElementMaster
    };

    AudioObjectAddPropertyListener(
        kAudioObjectSystemObject,
        &inputDeviceAddress,
        &callbackFunction,
        (__bridge  void* ) self );

   AudioObjectPropertyAddress runLoopAddress = {
        kAudioHardwarePropertyRunLoop,
        kAudioObjectPropertyScopeGlobal,
        kAudioObjectPropertyElementMaster
    };

    CFRunLoopRef runLoop = NULL;
    
    UInt32 size = sizeof(CFRunLoopRef);
    
    AudioObjectSetPropertyData(
        kAudioObjectSystemObject,
        &runLoopAddress,
        0,
        NULL,
        size,
        &runLoop);
    
     [ self listDevices ];
    
}


- ( void ) deviceSelected : ( NSMenuItem* ) item
{
    if ( item.representedObject != nil && [item.representedObject isKindOfClass:[NSNumber class]] )
    {
        AudioDeviceID selectedDeviceID = [(NSNumber*)item.representedObject unsignedIntValue];
        NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
        
        // Check if Option key is pressed
        BOOL optionKeyPressed = ([[[NSApplication sharedApplication] currentEvent] modifierFlags] & NSEventModifierFlagOption) != 0;

        if (optionKeyPressed) {
            if (selectedDeviceID == fallbackMicID) {
                NSLog( @"Deselecting fallback device: %u" , selectedDeviceID );
                fallbackMicID = UINT32_MAX; // Clear the fallback
            } else {
                NSLog( @"Setting fallback device: %u" , selectedDeviceID );
                fallbackMicID = selectedDeviceID;
            }
            [prefs setInteger:fallbackMicID forKey:@"FallbackMicDeviceID"];
        } else {
            NSLog( @"Setting preferred device: %u" , selectedDeviceID );
            preferredMicID = selectedDeviceID;
            [prefs setInteger:preferredMicID forKey:@"PreferredMicDeviceID"];
        }
        
        [prefs synchronize];
        NSLog(@"Saved PreferredMicDeviceID: %u, FallbackMicDeviceID: %u", preferredMicID, fallbackMicID);

        // No longer directly set forcedInputID or system default here.
        // Call listDevices to re-evaluate and apply the correct device.
        [ self listDevices ];
    }
}


- ( void ) listDevices
{

    NSDictionary *bundleInfo = [ [ NSBundle mainBundle] infoDictionary];
    NSString *versionString = [ NSString stringWithFormat : @"Version %@ (build %@)",
                               bundleInfo[ @"CFBundleShortVersionString" ],
                               bundleInfo[ @"CFBundleVersion"] ];

    menu = [ [ NSMenu alloc ] init ];
    menu.delegate = self;
    [ menu addItemWithTitle : versionString action : nil keyEquivalent : @"" ];
    [ menu addItem : [ NSMenuItem separatorItem ] ]; // A thin grey line
    [ menu addItemWithTitle : @"Option-Click to Toggle fallback" action : nil keyEquivalent : @"" ];
    [ menu addItem : [ NSMenuItem separatorItem ] ]; // A thin grey line
    
    NSMenuItem* item =  [ menu
            addItemWithTitle : NSLocalizedString(@"Pause", @"Pause")
            action : @selector(manualPause:)
            keyEquivalent : @"" ];

    if ( paused ) [ item setState : NSControlStateValueOn ];

    [ menu addItem : [ NSMenuItem separatorItem ] ]; // A thin grey line
    [ menu addItemWithTitle : @"Forced input:" action : nil keyEquivalent : @"" ];
    
    UInt32 propertySize;
    
    AudioDeviceID dev_array[64];
    int numberOfDevices = 0;
    char deviceName[256];
    
    AudioHardwareGetPropertyInfo(
        kAudioHardwarePropertyDevices,
        &propertySize,
        NULL );
    
    AudioHardwareGetProperty(
        kAudioHardwarePropertyDevices,
        &propertySize,
        dev_array);
    
    numberOfDevices = ( propertySize / sizeof( AudioDeviceID ) );
    
    NSLog( @"devices found : %i" , numberOfDevices );
    
    // Determine the targetDeviceID based on preferred, fallback, and availability
    AudioDeviceID targetDeviceID = UINT32_MAX;
    BOOL preferredIsAvailable = NO;
    BOOL fallbackIsAvailable = NO;

    // Check availability of preferred and fallback mics
    for (int i = 0; i < numberOfDevices; i++) {
        if (dev_array[i] == preferredMicID) preferredIsAvailable = YES;
        if (dev_array[i] == fallbackMicID) fallbackIsAvailable = YES;
    }

    if (preferredMicID != UINT32_MAX && preferredIsAvailable) {
        targetDeviceID = preferredMicID;
        NSLog(@"Using preferred mic: %u", targetDeviceID);
    } else if (fallbackMicID != UINT32_MAX && fallbackIsAvailable) {
        targetDeviceID = fallbackMicID;
        NSLog(@"Preferred mic not available or not set. Using fallback mic: %u", targetDeviceID);
    } else {
        // If neither preferred nor fallback is available/set, try to find a 'built-in' as a last resort
        // This part of the logic is moved down to where devices are iterated for menu building
        NSLog(@"Neither preferred nor fallback mic is available/set. Will look for default.");
    }

    forcedInputID = targetDeviceID; // This is the device we will attempt to force

    // If forcedInputID is still UINT32_MAX after checking preferred/fallback,
    // the original logic for finding a 'built-in' mic will run later in this function.
    // If a specific device (preferred or fallback) was selected and is NOT available,
    // forcedInputID might be UINT32_MAX here, and the app will try to find a 'built-in' or other default.
    // This ensures we don't try to force a non-existent device from old saved preferences.
    BOOL currentForcedDeviceStillExists = NO;
    if (forcedInputID != UINT32_MAX) {
        for (int i = 0; i < numberOfDevices; i++) {
            if (dev_array[i] == forcedInputID) {
                currentForcedDeviceStillExists = YES;
                break;
            }
        }
        if (!currentForcedDeviceStillExists) {
            NSLog(@"Previously selected target device (%u) no longer exists. Resetting.", forcedInputID);
            forcedInputID = UINT32_MAX; // Reset if the chosen device is gone
        }
    }

    for( int index = 0 ;
             index < numberOfDevices ;
             index++ )
    {
    
        AudioDeviceID oneDeviceID = dev_array[ index ];

        propertySize = 256;
        
        AudioDeviceGetPropertyInfo(
            oneDeviceID ,
            0 ,
            true ,
            kAudioDevicePropertyStreams ,
            &propertySize ,
            NULL );

        // if there are any input streams, then it is an input

        if ( propertySize > 0 )
        {
        
            // get name

            propertySize = 256;
            
            AudioDeviceGetProperty(
                oneDeviceID ,
                0 ,
                false ,
                kAudioDevicePropertyDeviceName ,
                &propertySize ,
                deviceName );

            NSLog( @"found input device : %s  %u\n" , deviceName , (unsigned int)oneDeviceID );
            
            NSString* nameStr = [ NSString stringWithUTF8String : deviceName ];
            NSString* displayDeviceName = [NSString stringWithString:nameStr];

            if (oneDeviceID == preferredMicID && preferredMicID != UINT32_MAX) {
                displayDeviceName = [NSString stringWithFormat:@"%@ (Primary)", nameStr];
            } else if (oneDeviceID == fallbackMicID && fallbackMicID != UINT32_MAX) {
                displayDeviceName = [NSString stringWithFormat:@"%@ (Fallback)", nameStr];
            }

            // Defaulting logic: if no preferred/fallback is set or available, and forcedInputID is still UINT32_MAX,
            // try to select a 'built-in' mic as a last resort.
            if ( forcedInputID == UINT32_MAX && [ [ nameStr lowercaseString ] containsString : @"built" ] ) {
                NSLog( @"No preferred/fallback. Setting default forced device to built-in: %s  %u\n" , deviceName , (unsigned int)oneDeviceID );
                forcedInputID = oneDeviceID; // This becomes the effective device to force
            }

            NSMenuItem* item = [ menu
                addItemWithTitle : displayDeviceName
                action : @selector(deviceSelected:)
                keyEquivalent : @"" ];
            item.representedObject = [NSNumber numberWithUnsignedInt:oneDeviceID]; // Store ID directly
            
            // Checkmark the currently active (forced) device
            if ( oneDeviceID == forcedInputID && forcedInputID != UINT32_MAX )
            {
                [ item setState : NSControlStateValueOn ];
                NSLog( @"Menu: Marking active device: %s  %u\n" , deviceName , (unsigned int)oneDeviceID );
            }
            
            // itemsToIDS[ nameStr ] = [ NSNumber numberWithUnsignedInt : oneDeviceID]; // No longer needed

        }

        [ statusItem setMenu : menu ];

    }

    // get current input device
    
    AudioDeviceID deviceID = kAudioDeviceUnknown;

    // get the default output device
    // if it is not the built in, change
    
    propertySize = sizeof( deviceID );
    
    AudioHardwareGetProperty(
        kAudioHardwarePropertyDefaultInputDevice,
        &propertySize,
        &deviceID);
    
    NSLog( @"default input device is %u" , deviceID );
    
    // If forcedInputID is valid (not UINT32_MAX) and different from current system default, then set it.
    if ( !paused && forcedInputID != UINT32_MAX && deviceID != forcedInputID )
    {
        NSLog( @"Forcing system default input device to: %u" , forcedInputID );

        UInt32 propertySize = sizeof(UInt32);
        OSStatus err = AudioHardwareSetProperty(
            kAudioHardwarePropertyDefaultInputDevice ,
            propertySize ,
            &forcedInputID );
        
        if (err == noErr) {
            // Optionally, briefly show 'forcing...' message, or remove if too quick/flickery
            // For simplicity, we can rely on the checkmark and (Primary)/(Fallback) indicators.
            /*
            [ menu
                insertItemWithTitle : @"forcing..."
                action : NULL
                keyEquivalent : @""
                atIndex : 2 ];
            // Consider removing this temporary item after a short delay or on next menu open
            */
        } else {
            NSLog( @"Error forcing input device: %d", err);
        }
    } else if (forcedInputID == UINT32_MAX && !paused) {
        NSLog(@"No specific device to force. System default will be used or OS will choose.");
    }
    
    [ menu addItem : [ NSMenuItem separatorItem ] ]; // A thin grey line

    startupItem = [ menu
        addItemWithTitle : @"Open at login"
        action : @selector(toggleStartupItem)
        keyEquivalent : @"" ];
    
    [ menu addItem : [ NSMenuItem separatorItem ] ]; // A thin grey line

    [ menu addItem : [ NSMenuItem separatorItem ] ]; // A thin grey line
    [ menu addItemWithTitle : @"Donate if you like the app"
           action : @selector(support)
           keyEquivalent : @"" ];

    [ menu addItemWithTitle : @"Check for updates"
           action : @selector(update)
           keyEquivalent : @"" ];
    
    [ menu addItemWithTitle : @"Hide"
           action : @selector(hide)
           keyEquivalent : @"" ];
    
    [ menu addItemWithTitle : @"Quit"
           action : @selector(terminate)
           keyEquivalent : @"" ];

}

- ( void ) manualPause : ( NSMenuItem* ) item
{
    paused = !paused;
    [ self listDevices ];
}

- ( void ) terminate
{
    [ NSApp terminate : nil ];
}

- ( void ) support
{
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString: @"https://paypal.me/milgra"]];
}

- ( void ) update
{
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString: @"http://milgra.com/airpods-sound-quality-fixer.html"]];
}

- ( void ) hide
{
    [statusItem setVisible:false];
}

- (void)toggleStartupItem
{
    if ( [GBLaunchAtLogin isLoginItem] )
    {
        [GBLaunchAtLogin removeAppFromLoginItems];
    }
    else
    {
        [GBLaunchAtLogin addAppAsLoginItem];
    }
    
    [self updateStartupItemState];
}

- (void)updateStartupItemState
{
    [startupItem setState: [GBLaunchAtLogin isLoginItem] ? NSControlStateValueOn : NSControlStateValueOff];
}

- (void)menuWillOpen:(NSMenu *)menu
{
    [self updateStartupItemState];
}

@end
