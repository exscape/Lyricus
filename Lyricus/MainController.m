
//
// This file is part of Lyricus.
// Copyright (c) 2008, Thomas Backman <serenity@exscape.org>
// All rights reserved.
//

#import "MainController.h"
#define kProgressIndicatorIdentifier @"ProgressIndicatorIdentifier"
#define kSearchIdentifier @"SearchIdentifier"
#define kBulkIdentifier @"BulkIdentifier"

@implementation MainController


//#define DISABLE_CACHE 1
#ifdef DISABLE_CACHE
#warning DISABLE_CACHE ENABLED
#endif


#pragma mark -
#pragma mark Init stuff

@synthesize currentNotification;
@synthesize notificationTimer;

-(void) awakeFromNib {
	//
	// Set up the default settings
	//
	
	// TODO: NSNUmber isn't necessary ([NSUserDefaults setBool:forKey], etc.).
	// However, it will have to be removed both here and in the rest of the application,
	// and will likely break backwards compatibilty with old settings.
	[[NSUserDefaults standardUserDefaults] registerDefaults: 
	 [NSDictionary dictionaryWithObjectsAndKeys:
	  [NSNumber numberWithInt:0], 	@"Always on top",			// Off
	  [NSNumber numberWithInt:0], 	@"Hit count",				// 0
	  [NSNumber numberWithInt:0], 	@"Miss count",			// 0
	  [NSNumber numberWithInt:1], 	@"Save lyrics to iTunes",	// On
	  [NSNumber numberWithInt:1], 	@"Follow iTunes",			// On
	  [NSNumber numberWithInt:1],	@"Verbose_bulk_downloader", 	// On
	  [NSNumber numberWithInt:1],	@"SUCheckAtStartup", // On
	  @"Helvetica",					@"FontName",
	  [NSNumber numberWithFloat:13.0], @"FontSize",
	  [NSArchiver archivedDataWithRootObject:[NSColor whiteColor]], @"BackgroundColor",
	  [NSArchiver archivedDataWithRootObject:[NSColor blackColor]], @"TextColor",
	  [NSArchiver archivedDataWithRootObject:[NSColor colorWithDeviceRed:1.0 green:1.0 blue:0.8 alpha:1.0]], @"EditBackgroundColor",
	  
	  nil]];
	
	[lyricView setFont:[NSFont fontWithName:[[NSUserDefaults standardUserDefaults] stringForKey:@"FontName"]
									   size:[[NSUserDefaults standardUserDefaults] floatForKey:@"FontSize"]]];

	[lyricView bind:@"backgroundColor" toObject:[NSUserDefaultsController sharedUserDefaultsController]
 withKeyPath:@"values.BackgroundColor" options:[NSDictionary dictionaryWithObject:NSUnarchiveFromDataTransformerName forKey:@"NSValueTransformerName"]];
	
	lyricController = [[LyricFetcher alloc] init];
	helper = [iTunesHelper sharediTunesHelper];
	
	[searchWindow setDelegate:self];
	
	[[NSFontManager sharedFontManager] setDelegate:self];
	[[NSFontPanel sharedFontPanel] setDelegate:self];
	[lyricView setUsesFontPanel:YES];
	[lyricView setDelegate:self];
	
	[mainWindow makeFirstResponder:lyricView];
	
	textURL = nil;
	displayedArtist = nil;
	displayedTitle = nil;
	lyricsDisplayed = NO;
	loadingLyrics = NO;
	manualSearch = NO;
	documentEdited = NO;
	receivedFirstNotification = NO;
	
	notificationTimer = nil;
	currentNotification = nil;
	
	
	// Change the lorem ipsum text to something more useful (or at least something less weird)
	[lyricView setString:@"Lyricus v" MY_VERSION " ready.\nPress \u2318N or turn on \"Follow iTunes\" (and start playing a track!) in the preferences window to get started."];
	// Restore settings
	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"Always on top"])
		[mainWindow setLevel:NSFloatingWindowLevel];
	
	// Sign up to receive notifications about the download progress (i.e. which site is being tried)
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateStatus:) name:@"UpdateStatusNotification" object:nil];
	
	// Remember the window position
	[mainWindow setFrameAutosaveName:@"mainWindow"];	
	
	// Register for iTunes notifications (for when the track changes, etc.)
	[[NSDistributedNotificationCenter defaultCenter]
	 addObserver:self
	 selector:@selector(handleiTunesNotification:)
	 name:@"com.apple.iTunes.playerInfo"
	 object:nil];
	
	// Sign up for the SetLyric message, sent from another thread later on
	[[NSNotificationCenter defaultCenter]
	 addObserver:self selector:@selector(setLyric:) name:kSetLyric object:nil];
		
	// Create a progress indicator
	NSRect spinnerFrame = NSMakeRect([lyricView frame].size.width - 16, 0, 16, 16);
	spinner = [[NSProgressIndicator alloc] initWithFrame:spinnerFrame];
	[spinner setStyle:NSProgressIndicatorSpinningStyle];
	[spinner setControlSize:NSSmallControlSize];
	[spinner setHidden:YES];
	[lyricView addSubview:spinner positioned:NSWindowAbove relativeTo:nil];
	[lyricView setAutoresizesSubviews:YES];
	[spinner setAutoresizingMask:NSViewMinXMargin];
	
	// If we're following iTunes, check if something's playing and if so, grab the lyric right away!
	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"Follow iTunes"]) {
		[self updateTextFieldsFromiTunes];
		[self fetchAndDisplayLyrics:NO];
	}
		    
	// Update the site list
	// Is this really needed? [LyricController init] does this already.
	[lyricController updateSiteList];
	// NO CODE goes after this!
}

#pragma mark -
#pragma mark UI stuff 

-(IBAction)openFontPanel:(id)sender {
	[[NSFontPanel sharedFontPanel] makeKeyAndOrderFront:nil];
}

-(IBAction) showPreferencesHelp:(id) sender {
	[TBUtil showAlert:@"Drag and drop to select the order in which the lyric sites will be queried, and enable/disable them using the checkbox next to their name. \nFor some extra hints, "
	 @"hover the mouse pointer over the options and a tooltip should appear (for most options)." withCaption:@"Help"];
}

-(IBAction) showAboutWindow:(id) sender {
	[iconView setImage:[NSApp applicationIconImage]];
	[aboutVersion setStringValue:@"v" MY_VERSION];
	[aboutWindow makeKeyAndOrderFront:self];
	[aboutTextView setString:
	 @"Everything Lyricus:\n"
	 @"  Thomas Backman <serenity@exscape.org>\n"
	 @"  http://lyricus.exscape.org\n"
	 @"\n"
	 @"Thanks to:\n"
	 @"John Engelhart\n"
	 @"  http://regexkit.sourceforge.net\n"
	 @"\n"
	 @"Tom Harrington, Andy Matuschak and Sparkle contributors\n"
	 @"  http://code.google.com/p/sparkleplus"
	 ];
}

-(IBAction) followiTunesCheckboxClicked:(id) sender {
	if ([followiTunesCheckbox state] == NSOnState) {
		if ([helper isiTunesRunning]) {
			[self updateTextFieldsFromiTunes];
			[self fetchAndDisplayLyrics:NO];
		}
	}
}

-(IBAction) openSearchWindow:(id) sender {
	[NSApp beginSheet:searchWindow modalForWindow:mainWindow modalDelegate:self 
	   didEndSelector:@selector(didEndSheet:returnCode:contextInfo:) contextInfo:nil];
	
	[self updateTextFieldsFromiTunes];
	
	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"Follow iTunes"]) {
		// Warn the user that follow iTunes + search isn't a good idea
		NSRect cur = [searchWindow frame];
		[searchWindow setFrame:NSMakeRect(cur.origin.x, cur.origin.y, cur.size.width, 115) display:YES animate:NO];
		[warningLabel setHidden:NO];
	}
	else {
		NSRect cur = [searchWindow frame];
		[searchWindow setFrame:NSMakeRect(cur.origin.x, cur.origin.y, cur.size.width, 90) display:YES animate:NO];
		[warningLabel setHidden:YES];
	}	
}

-(IBAction) openPreferencesWindow:(id) sender {
	[NSApp beginSheet:preferencesWindow modalForWindow:mainWindow modalDelegate:self 
	   didEndSelector:@selector(didEndSheet:returnCode:contextInfo:) contextInfo:nil];
}

- (void)didEndSheet:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo {
	if (sheet == searchWindow)
		[searchWindow orderOut:nil];
	else if (sheet == preferencesWindow) {
		[preferencesWindow orderOut:nil];
	}
}

-(void) setTitle:(NSString *)theTitle {
	[mainWindow setTitle: theTitle];
}

-(IBAction) getFromiTunesButton:(id) sender {
    [self updateTextFieldsFromiTunes];
}

-(void) updateTextFieldsFromiTunes {
    iTunesTrack *track = [helper getCurrentTrack];
	//	if (track == nil)
	//	return;
	@try {
		//		NSString *artist = [track artist];
		//		NSString *title = [track name];
		if (track != nil && [track artist] != nil && [track name] != nil) {
			// Both or neither!
			[artistField setStringValue: [track artist]];
			[titleField setStringValue: [track name]];
		}
		else {
			NSString *streamTitle = [[helper iTunesReference] currentStreamTitle];
			if (streamTitle != nil && [streamTitle length] > 5) { // length("a - b" == 5)
				NSArray *tmp = [streamTitle arrayOfDictionariesByMatchingRegex:@"([\\s\\S]+) - ([\\s\\S]+)" withKeysAndCaptures:@"artist", 1, @"title", 2, nil];
				if ([tmp count] != 1)
					return;
				
				NSString *artist = [[tmp objectAtIndex:0] objectForKey:@"artist"];
				NSString *title = [[tmp objectAtIndex:0]  objectForKey:@"title"];
				
				if (artist != nil && title != nil) {
					// Again, both or neither
					[artistField setStringValue:artist];
					[titleField setStringValue:title];
				}
			}
		}
	}
	@catch (NSException *e) {}
}

-(IBAction) alwaysOnTopClicked:(id) sender {
	// The always on top option was checked/unchecked
	// It's boring to restart apps, so let's make it work right away:
	if ([alwaysOnTop state] == NSOnState) {
		[mainWindow setLevel:NSFloatingWindowLevel];	
	}
	else {
		[mainWindow setLevel:NSNormalWindowLevel];
	}
}

-(IBAction) goButton:(id) sender {
    [self fetchAndDisplayLyrics:/*manual=*/YES];
}

- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender {
	if (bulkDownloader != nil && [bulkDownloader bulkDownloaderIsWorking]) {
		// The bulk downloader is downloading tracks. Ask the user whether we still should quit.
		if ([[NSAlert alertWithMessageText:@"The bulk downloader is currently working. Do you still want to quit?" defaultButton:@"Don't quit" alternateButton:@"Quit" otherButton:nil informativeTextWithFormat:@"Lyrics that have been downloaded until now will be saved."] runModal]
			==
			NSAlertDefaultReturn) {
			// Don't quit
			return NSTerminateCancel;
		}
		// else fall through to the checks below...
	}
	
	
	// Make sure unsaved changes are saved by the user
	
	// If there are no unsaved changes, simply quit
	if (![self documentEdited]) {
			return NSTerminateNow;
	}
	
	// There are unsaved changes. Ask the user what to do.
	
	switch ([[NSAlert alertWithMessageText:@"Do you want to save lyric edits before exiting?" defaultButton:@"Save" alternateButton:@"Don't save" otherButton:@"Cancel" informativeTextWithFormat:@"If you don't save now, your changes will be lost. You can cancel to review your changes."] runModal]) {
			
		case NSAlertAlternateReturn:
			// "Don't save"
			return NSTerminateNow;
			break;
			
		case NSAlertDefaultReturn:
			// "Save"
			if ([self saveLyricsToNamedTrack])
				return NSTerminateNow;
			else {
				// Save failed
				if (
				[[NSAlert alertWithMessageText:@"Unable to save lyrics." defaultButton:@"Abort shutdown" alternateButton:@"Exit without saving" otherButton:nil informativeTextWithFormat:@"If  you still quit, any changes you have made to the lyric text will be lost."] runModal]
				 ==
					NSAlertAlternateReturn) {
					// "Exit without saving"
					// Save failed but user still wants to exit
					return NSTerminateNow;
				}
				else {
					// "Abort shutdown"
					// Save failed and used din't want to exit
					return NSTerminateCancel;
				}
			}
			break;
		case NSAlertOtherReturn:
			// "Cancel"
			// User wants to cancel the shutdown
			return NSTerminateCancel;
			break;
	}

	// Shouldn't be reached
	return YES;
}

-(BOOL) windowShouldClose:(id)sender {
	if (sender == mainWindow) {
		[NSApp terminate:nil];
		// If the above call returned, the user cancelled the shutdown; let's keep the main window open
		return NO; 
	}
	
	return YES;
}			

-(void) fetchAndDisplayLyrics:(BOOL)manual {
    if (loadingLyrics) {
        return;
	}
	
	if ([editModeMenuItem state] == 1) {
		// Edit mode is active
		trackChangedWhileInEditMode = YES;
		// Don't change the displayed lyrics while editing
		return; 
	}

	if ([self documentEdited]) {
		
		switch ([[NSAlert alertWithMessageText:@"The lyrics currently displayed have been modified, but not saved. Do you want to save your changes?" defaultButton:@"Save" alternateButton:@"Don't save" otherButton:@"Cancel" informativeTextWithFormat:@"If you don't save, your changes will be lost."] runModal]) {
				
			case NSAlertAlternateReturn:
				// "Don't save"
				[self setDocumentEdited:NO];
				break;
				
			case NSAlertDefaultReturn:
				// "Save"
				if ([self saveLyricsToNamedTrack]) {
					// We've saved; simply break and let the code below switch to the new track.
					break;
				}
				else {
					// Save failed
					if (
						[[NSAlert alertWithMessageText:@"Unable to save lyrics. Do you want to switch the lyric display anyway? Your changes will be lost." defaultButton:@"Don't switch" alternateButton:@"Switch and discard changes" otherButton:nil informativeTextWithFormat:@"If  you still switch the lyric display, any changes you have made to the lyric text will be lost."] runModal]
						==
						NSAlertAlternateReturn) {
						// Simply break and let the code below switch to the new track.
						break;
					}
					else {
						// "Abort shutdown"
						// Save failed and used din't want to exit
						return;
					}
				}
				break;
			case NSAlertOtherReturn:
				// "Cancel"
				// User wants to cancel the track switch
				return;
		}
	}
	
    manualSearch = manual;
	
	NSString *artist, *title;
	artist = [artistField stringValue];
	title  = [titleField stringValue];
	
	if ([artist length] == 0 || [title length] == 0)
	{
		if (manualSearch == YES) { // Don't show if it was called programmatically
			[[NSAlert alertWithMessageText:@"No artist/title pair specificed" defaultButton:@"OK" alternateButton:nil otherButton:nil
				 informativeTextWithFormat:@"You need to type in both an artist and a track title to search."] runModal];
		}
		return;
	}
	[self disableEditMode];
	[goButton setEnabled:NO];
	[spinner setHidden:NO];
	[spinner setUsesThreadedAnimation:YES];
	[spinner startAnimation:nil];
	
	[NSApp endSheet:searchWindow];
	loadingLyrics = YES;
	[lyricView setString:@"Loading lyrics, please wait...\n"];
	[mainWindow setTitle:@"Lyricus - loading..."];
	
    NSDictionary *data = [NSDictionary dictionaryWithObjectsAndKeys:title, @"title", artist, @"artist", nil];
	NSThread *thread = [[NSThread alloc] initWithTarget:self selector:@selector(runThread:) object:data];
	[thread start];
}

- (void)runThread:(NSDictionary *)data {
	NSString *title = [data objectForKey:@"title"];
	NSString *artist = [data objectForKey:@"artist"];

	if (title == nil || artist == nil) {
		loadingLyrics = NO;
	}
	
	NSString *lyricStr;
	SendNote(@"Trying iTunes...\n");
	
    NSError *err = nil;
    
    // First, lets check if iTunes has an entry for this track already
	iTunesTrack *currentTrack = [helper getTrackForTitle:title byArtist:artist];
	NSString *iTunesLyrics = [helper getLyricsForTrack:currentTrack];
#ifndef DISABLE_CACHE
	if (iTunesLyrics != nil && [iTunesLyrics length] > 5) {
		lyricStr = iTunesLyrics;
	}
	else 
#endif 
	{
		// Not in iTunes, lets fetch it
		lyricStr = [lyricController fetchLyricsForTrack:title byArtist:artist error:&err];
		
		// Beautiful code:
		// (Basically, it checks if the data we got is OK, ond if it should save it to iTunes)
		if (lyricStr != nil) {
			if ([[currentTrack artist] isEqualToString:artist] && [[currentTrack name] isEqualToString:title]) {
				// The above line is to make sure we don't save into the wrong track, in case the currently displayed track isn't the one playing
				
				// This needs to be done when the track isn't playing. Otherwise, there will be a (very) noticable pause in the playback when iTunes writes the data to disk.
				NSDictionary *data = [NSDictionary dictionaryWithObjectsAndKeys:
									  currentTrack, @"currentTrack",
									  [NSString stringWithString:lyricStr], @"lyric",
									  nil];
				
				NSThread *thread = [[NSThread alloc] initWithTarget:self selector:@selector(updateLyriciniTunes:) object:data];
				[thread start];
			}
		}
	}
	
	if (lyricStr == nil) {
        if (err == nil) {
            lyricStr = [NSString stringWithFormat:@"No lyrics found!\n"
                        @"For the record, I searched for:\n%@ - %@",
                        artist, title];
        }
        else { // error
            lyricStr = [NSString stringWithFormat: @"An error occured:\n%@", [err localizedDescription]];
        }
		[self performSelectorOnMainThread:@selector(setTitle:) withObject:@"Lyricus" waitUntilDone:YES];
		lyricsDisplayed = NO;
	}
	else if (lyricStr != nil){
		// We found some lyrics!
		NSString *fullTitle = [NSString stringWithFormat:@"%@ - %@", artist, title];
		[self performSelectorOnMainThread:@selector(setTitle:) withObject:fullTitle waitUntilDone:YES];
		lyricsDisplayed = YES;
	}
	
	// Display lyrics + set font
	SetLyric(lyricStr);
	displayedArtist = [artist copy];
	displayedTitle = [title copy];
	
	// Scroll to the top (I don't think this is neccesary (anymore), but it doesn't hurt)
	//	[lyricView scrollRangeToVisible:NSMakeRange(0,0)];
	
	loadingLyrics = NO;
    
	[spinner stopAnimation:nil];
	[spinner setHidden:YES];
	[goButton setEnabled:YES];
	
	// If the track changed while loading, go get the NEW lyrics instead. Do NOT do this with manual searches, or the current track
	// would be displayed no matter what.
	
	if (!manualSearch) {
		NSString *currentArtist;
		NSString *currentTitle;
		if ([helper currentTrackIsStream]) {
			NSString *streamTitle = [[helper iTunesReference] currentStreamTitle];
			if (streamTitle != nil && [streamTitle length] > 5) { // length("a - b" == 5)
				NSArray *tmp = [streamTitle arrayOfDictionariesByMatchingRegex:@"([\\s\\S]+) - ([\\s\\S]+)" withKeysAndCaptures:@"artist", 1, @"title", 2, nil];
				if ([tmp count] != 1)
					return;
				
				currentArtist = [[tmp objectAtIndex:0] objectForKey:@"artist"];
				currentTitle = [[tmp objectAtIndex:0]  objectForKey:@"title"];
			}
			else {
				currentArtist = @"";
				currentTitle = @"";
			}
		}
		else {
			currentArtist = [[helper getCurrentTrack] artist];
			currentTitle = [[helper getCurrentTrack] name];							
		}

		// Check whether the track has changed or not
		if ( ! ([displayedArtist isEqualToString:currentArtist] && [displayedTitle isEqualToString:currentTitle]) ) {
				[self updateTextFieldsFromiTunes];
				[self fetchAndDisplayLyrics:NO];
			}
	}
}	

- (IBAction) closeSearchWindow:(id) sender {
	[NSApp endSheet:searchWindow];
}

- (IBAction) closePreferencesButton:(id) sender {
	[lyricController updateSiteList];
	if ([[lyricController sitesByPriority] count] == 0) {
		// Make sure the user selects at least one site
		[TBUtil showAlert:@"You need to select at least one site to use!" withCaption:@"No site selected"];
		return;
	}
	
	[NSApp endSheet:preferencesWindow];
}

-(void) updateStatus:(NSNotification *)note {
	//
	// Called when we receive a notification about the download progress.
	// The checking whether the user wants these or not are on the *sending* site:
	// In other words: if we get here, the user has requested them, so just display them:
	//
	
	NSDictionary *info = [note userInfo];
	if (info == nil)
		return;
	SetLyric([[lyricView string] stringByAppendingString: [info objectForKey:@"Text"]]);
}

-(void)doSetLyric:(NSString *)str {
	[lyricView setString:str];
}

-(void)setLyric:(NSNotification *)note {
	[self performSelectorOnMainThread:@selector(doSetLyric:) withObject:[[note userInfo] objectForKey:@"Text"] waitUntilDone:YES];
}

#pragma mark -
#pragma mark Util/misc stuff 

-(BOOL) track:(iTunesTrack *) theTrack isEqualToTrack:(iTunesTrack *)otherTrack {
	@try {
	if (theTrack == otherTrack)
		return YES;
	if (theTrack != nil && [theTrack exists] && otherTrack != nil && [otherTrack exists]) {
		if (
			[[theTrack artist] isEqualToString:[otherTrack artist]] &&
			[[theTrack name] isEqualToString:[otherTrack name]]
			) { return YES; }
		else return NO;
	}
	else
		return NO;
	}
	@catch (NSException *e) { return NO; }
	
	return NO;
}

-(void) updateLyriciniTunes:(NSDictionary *)data {
	iTunesApplication *iTunes = [helper iTunesReference];
	if (iTunes == nil)
		return;
	
	iTunesTrack *theTrack = [data objectForKey:@"currentTrack"];
	NSString *theLyric = [data objectForKey:@"lyric"];
	
	@try {
		if (theTrack == nil || ![theTrack exists] || theLyric == nil)
			return;
	}
	@catch (NSException *e) { return; }
	
	iTunesTrack *nextTrack;
	@try {
		while (1) {
			// Wait until track stops playing, to avoid the skip when iTunes writes the lyrics to disk
			if (iTunes == nil || ![iTunes isRunning])
			{
				NSLog(@"iTunes not running anymore, can't save data");
				break;
			}
			
			@try {
				nextTrack = [iTunes currentTrack];
				if (![self track:nextTrack isEqualToTrack:theTrack] && [iTunes playerState] == iTunesEPlSPlaying ) {
					[helper setLyrics:theLyric ForTrack:theTrack];
					break;
				}
			}
			@catch (NSException *e) { return; }
			@finally  { 
				sleep(10); // There's no rush! It'll work even if it's a bit late.
			}
		}
	}
	@catch (NSException *e) { NSLog(@"Unable to save lyrics to iTunes: some exception occured."); }
}

-(BOOL) haveLyricsLocallyForCurrentTrack {
	//
	// Returns YES if lyric is in iTunes, NO otherwise
	//
	iTunesTrack *currentTrack = [helper getCurrentTrack];
	if (currentTrack == nil)
		return NO;
	
	if ([helper getLyricsForTrack:[helper getCurrentTrack]] != nil)
		return YES;
	else
		return NO;
}

-(void)trackUpdated {
	//
    // This is called whenever iTunes starts playing a track. We need to check whether if it's a new track or not.
	//
	
	// Reset notification handling
	receivedFirstNotification = NO;
	NSLog(@"trackupdated");
	
	NSString *track;
	if (![helper currentTrackIsStream])
		track = [NSString stringWithFormat:@"%@ - %@", [[currentNotification userInfo] objectForKey:@"Artist"], [[currentNotification userInfo] objectForKey:@"Title"]];
	else
		track = [[helper iTunesReference] currentStreamTitle];

	@try { 
		if ([track isEqualToString:lastTrack]) {
			return;
		}
	}
	@catch (NSException *e) {} // Ignore, will most likely only happen on the first track, which means nothing really
	/*
	if (![self haveLyricsLocallyForCurrentTrack]) {
		sleep (3); 	// To make sure the user didn't just skip a bunch of tracks;
					// We want to be sure that this is *the* new track.
	}
	*/
	@try {
		iTunesTrack *currentTrack = [helper getCurrentTrack];
		NSString *newTrack;
		if (currentTrack == nil && ![helper currentTrackIsStream])
			return;
		
		if (![helper currentTrackIsStream]) {
			newTrack = [NSString stringWithFormat:@"%@ - %@", [currentTrack artist], [currentTrack name]];
		}
		else {
			newTrack = [[helper iTunesReference] currentStreamTitle];
		}
		
		if ([track isEqualToString:newTrack] && ![track isEqualToString:lastTrack]) {
			// Track DID change,so lets get the lyrics and stuff.
			lastTrack = [NSString stringWithString:newTrack];
			[self updateTextFieldsFromiTunes];
			[self fetchAndDisplayLyrics:NO];
		}
	}
	@catch (NSException *e) {}
}

-(void)handleiTunesNotification:(NSNotification *)note {
	//
	// Receives notifications from iTunes, and forwards them to trackUpdated: if a track started playing
	//
	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"Follow iTunes"] == NO)
		return;
	
	NSString *location = [[note userInfo] objectForKey:@"Location"];
	if (location == nil)
		return;
	
	BOOL isStream = ([[note userInfo] objectForKey:@"Stream Title"] != nil);
	
	if ([[location substringToIndex:4] isEqualToString:@"file"] || isStream) {
		if ([[[note userInfo] objectForKey:@"Player State"] isEqualToString:@"Playing"]) {
			if (!isStream) {
				self.currentNotification = note;
				[self trackUpdated];
			}
			else {
				// Wait for the FIRST of two conditions to occur:
				// a) We receive another notification and uses that
				// b) Two seconds pass without another notification
				// The reason for this is simple (but annoying): there are no specific artist/title tags when the metadata
				// comes from a stream - only a stream title, which often LOOKS like a title to a program, yet is useless.
				// The real "artist - title" string usually arrives in a SECOND notification a second or two later.

				if (!receivedFirstNotification) {
					NSLog(@"Waiting for second notification...");
					// This is the first notification - let's wait and see
					receivedFirstNotification = YES;
					self.currentNotification = note;
					notificationTimer = [NSTimer timerWithTimeInterval:5.0 target:self selector:@selector(trackUpdated) userInfo:nil repeats:NO];
				}
				else {
					// Yay, we received the second notification
					NSLog(@"Received second notification in time! Aborting timer and calling manually.");
					self.currentNotification = note;
					if (notificationTimer != nil) {
						[notificationTimer invalidate];
					}
					notificationTimer = nil;
					[self trackUpdated];
				}
			}
		}
	}
}

#pragma mark -
#pragma mark Misc.

-(void)disableEditMode {
	[editModeMenuItem setState:0];
	[lyricView setEditable:NO];
	[mainWindow setTitle:[NSString stringWithFormat:@"%@ - %@", displayedArtist, displayedTitle, nil]];
	[lyricView setBackgroundColor:(NSColor *)[NSUnarchiver unarchiveObjectWithData:[[NSUserDefaults standardUserDefaults] valueForKey:@"BackgroundColor"]]];
	
	if (trackChangedWhileInEditMode) {
		trackChangedWhileInEditMode = NO;
		[self fetchAndDisplayLyrics:NO];
	}
}
	
-(IBAction)toggleEditMode:(id) sender {
	if (!displayedArtist || !displayedTitle)
		return;
	
	if ([editModeMenuItem state] == 1) {
		[self disableEditMode];
	}
	else {
		// Enable edit mode
		
		if ([helper getTrackForTitle:displayedTitle byArtist:displayedArtist] == nil) {
			[TBUtil showAlert:@"You're trying to edit the lyrics to a track I can't find in your iTunes library!" withCaption:@"Track not found in iTunes"];
			return;
		}
		
		if (lyricsDisplayed == NO) {
			// We're trying to ADD lyrics to a track that doesn't have them: remove the "nothing found" text
			// from the window:
			[lyricView setString:@""];
		}

		[editModeMenuItem setState:1];
		[lyricView setEditable:YES];		

		[lyricView setBackgroundColor: (NSColor *)[NSUnarchiver unarchiveObjectWithData:[[NSUserDefaults standardUserDefaults] objectForKey:@"EditBackgroundColor"]]];
		
		[mainWindow setTitle:[NSString stringWithFormat:@"EDITING: %@ - %@", displayedArtist, displayedTitle, nil]];		
	}
}

-(IBAction)saveLyrics:(id) sender {
	[self saveLyricsToNamedTrack];
}

-(BOOL)saveLyricsToNamedTrack {
	BOOL ret = FALSE; // What we return
	if (!displayedArtist || !displayedTitle) {
		[TBUtil showAlert:@"You tried to save without having a track's lyrics displayed!" withCaption:@"Unable to save"];
		ret = FALSE;
		goto end_return;
	}
	
	NSArray *theTracks = [helper getAllTracksForTitle:displayedTitle byArtist:displayedArtist];
	if (theTracks == nil) {
		[TBUtil showAlert:@"The currently displayed track is not in your iTunes library. Lyricus saves its lyrics in the audio file metadata and as such cannot save." withCaption:@"Unable to save lyrics"];
		ret = FALSE;
		goto end_return;
	}
	else
		ret = TRUE;
	
	// Ugh, setLyrics returns void, so we can't check for errors.
	// We'll have to assume it worked if the track was found above.
	NSString *newLyric = [lyricView string];
	
	for (iTunesTrack *theTrack in theTracks) {
		[theTrack setLyrics:newLyric];
	}
	
end_return:
	lyricsDisplayed = YES; // To make sure edit mode isn't bugged when adding new lyrics to a track
	
	// This line must be fixed BEFORE disabling edit mode, to not ask the user if the changes are already saved
	// 
	[self setDocumentEdited:NO];
	[self disableEditMode];

	return ret;
}

-(IBAction)saveDisplayedLyricsToCurrentlyPlayingTrack:(id) sender  {
	NSString *newLyric = [lyricView string];

	if (newLyric == nil || [newLyric length] < 1) {
		[TBUtil showAlert:@"You tried to save without having any lyrics displayed!" withCaption:@"Unable to save"];
		return;
	}
	
	[[helper getCurrentTrack] setLyrics: newLyric];
	
	[self disableEditMode];
	
	// Refresh the lyric display and fix the title, etc.
	[self setDocumentEdited:NO];
	
	return;
}

-(IBAction)openSongMeaningsPage:(id)sender {
	if (!displayedArtist || !displayedTitle) {
		[TBUtil showAlert:@"You need to have a song displayed to use this feature." withCaption:@"Unable to open songmeanings page"];
		return;
	}
	[spinner setHidden:NO];
	[spinner startAnimation:nil];
		
	// This is done in a separate thread to not stall the UI while the network is loading
	NSThread *thread = [[NSThread alloc] initWithTarget:self selector:@selector(openSongmeaningsThread:) object:nil];
	[thread start];
}

-(void)openSongmeaningsThread:(NSArray *)data {
	if (!songmeanings) {
		songmeanings = [[TBSongmeanings alloc] init];
	}
    NSError *err = nil;
	
	NSString *artistURL = [songmeanings getURLForArtist:displayedArtist error:&err];
	if (!artistURL && err == nil) {
		[TBUtil showAlert:@"Artist not found on songmeanings!" withCaption:@"Unable to open songmeanings page"];
		goto end_func;
	}
    else if (!artistURL && err != nil) {
        [TBUtil showAlert:@"An error occured when trying to open requested page." withCaption:@"Unable to open songmeanings page"];
		goto end_func;
    }
	
	NSString *myTitle = displayedTitle;
	
	if ([displayedTitle containsString:@"(live" ignoringCaseAndDiacritics:YES]) {
		myTitle = [NSString stringWithString:[displayedTitle stringByReplacingOccurrencesOfRegex:@"(?i)(.*?)\\s*\\(live.*" withString:@"$1"]];
	}
	
	NSString *lyricURL = [songmeanings getLyricURLForTrack:myTitle fromArtistURL:artistURL error:&err];
	if (!lyricURL && err == nil) {
		[TBUtil showAlert:@"Lyric not found on songmeanings!" withCaption:@"Unable to open songmeanings page"];
		goto end_func;
	}
    else if (!lyricURL && err != nil) {
        [TBUtil showAlert:@"An error occured when trying to open requested page." withCaption:@"Unable to open songmeanings page"];
        goto end_func;

    }
	
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:lyricURL]];
end_func:
	[spinner stopAnimation:nil];
	[spinner setHidden:YES];
	return;
}

-(void) textDidChange:(NSNotification *)notification {
	[self setDocumentEdited: YES];
}

-(IBAction)lyricSearchUpdateIndex:(id) sender {
    [self openLyricSearch:sender];
    [lyricSearch updateTrackIndex:sender];
}

-(IBAction)openBulkDownloader:(id)sender {
    if (bulkDownloader == nil) {
        bulkDownloader = [[Bulk alloc] initWithWindowNibName:@"Bulk"];
    }
    [bulkDownloader showWindow:self];
    [bulkDownloader.window makeKeyAndOrderFront:self];
    [bulkDownloader showBulkDownloader];
}

-(IBAction)openLyricSearch:(id)sender {
    if (lyricSearch == nil) {
        lyricSearch = [[LyricSearchController alloc] initWithWindowNibName:@"LyricSearch"];
    }
    [lyricSearch showWindow:self];
    [lyricSearch.window makeKeyAndOrderFront:self];
    [lyricSearch showLyricSearch:self];
}

-(BOOL) documentEdited {
	return documentEdited;
}

-(void) setDocumentEdited:(BOOL) value {
	documentEdited = value;
	[mainWindow setDocumentEdited:value];
}

-(void)finalize {
	// This doesn't seem to be called, but what the heck.
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[[NSDistributedNotificationCenter defaultCenter] removeObserver:self];
	[super finalize];
}

@end