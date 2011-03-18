
//
// This file is part of Lyricus.
// Copyright (c) 2008, Thomas Backman <serenity@exscape.org>
// All rights reserved.
//

#import "LyricreaderController.h"
#define kProgressIndicatorIdentifier @"ProgressIndicatorIdentifier"
#define kSearchIdentifier @"SearchIdentifier"
#define kBulkIdentifier @"BulkIdentifier"

@implementation LyricreaderController


//#define DISABLE_CACHE 1
#ifdef DISABLE_CACHE
#warning DISABLE_CACHE ENABLED
#endif


#pragma mark -
#pragma mark Init stuff

-(void) awakeFromNib {
	//
	// Set up the default settings
	//
	[[NSUserDefaults standardUserDefaults] registerDefaults: 
	 [NSDictionary dictionaryWithObjectsAndKeys:
	  [NSNumber numberWithInt:0], 	@"Always on top",			// Off
	  [NSNumber numberWithInt:0], 	@"Hit count",				// 0
	  [NSNumber numberWithInt:0], 	@"Miss count",			// 0
	  [NSNumber numberWithInt:1], 	@"Show loading messages",	// On
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
	
	[self setupToolbar];
	
	lyricController = [[LyricController alloc] init];
	helper = [[iTunesHelper alloc] init];
	
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
	
	// Change the lorem ipsum text to something more useful (or at least something less weird)
	[lyricView setString:@"Lyricus v" MY_VERSION " ready.\nPress \u2318N or turn on \"Follow iTunes\" (and start playing a track!) in the preferences window to get started."];
	// Restore settings
	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"Always on top"])
		[mainWindow setLevel:NSFloatingWindowLevel];
	
	// Sign up to receive notifications about the download progress (i.e. which site is being tried)
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateStatus:) name:@"UpdateStatusNotification" object:nil];
	
	// Remember the window position
	[mainWindow setFrameAutosaveName:@"mainWindow"];	
	
	// Sign up for iTunes notifications when the track changes etc., way more efficient (and way faster, experience wise) than polling
	[[NSDistributedNotificationCenter defaultCenter]
	 addObserver:self
	 selector:@selector(handleiTunesNotification:)
	 name:@"com.apple.iTunes.playerInfo"
	 object:nil];
	
	// Sign up for the SetLyric message, sent from another thread later on
	[[NSNotificationCenter defaultCenter]
	 addObserver:self selector:@selector(setLyric:) name:kSetLyric object:nil];
	
	// If we're following iTunes, check if something's playing and if so, grab the lyric right away!
	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"Follow iTunes"]) {
		[self getFromiTunesButton:nil];
		[self goButton:nil];
	}
    
	// Update the site list
	[lyricController updateSiteList];
	// NO CODE goes after this!
}

#pragma mark -
#pragma mark UI stuff 

-(IBAction)openBulkDownloader:(id)sender {
	if (bulkDownloader == nil) {
		bulkDownloader = [[Bulk alloc] init];
	}
		
	if ([bulkDownloader bulkDownloaderOpened] == NO) {
//		NSLog(@"bulkDownlader %@ not opened", bulkDownloader);
		[NSBundle loadNibNamed:@"Bulk" owner:bulkDownloader];
	//	[bulkDownloader openBulkDownloader];
	}
	else {
		[bulkDownloader focusWindow];
	}
}

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
}

-(BOOL)windowShouldClose:(id)sender {
	if (sender == mainWindow)
		[NSApp terminate:nil];
	/* else ;) */ return YES;
}

-(IBAction) followiTunesCheckboxClicked:(id) sender {
	if ([followiTunesCheckbox state] == NSOnState) {
		if ([helper isiTunesRunning]) {
			[self getFromiTunesButton:nil];
			[self goButton:nil];
		}
	}
/*	else if ([followiTunesCheckbox state] == NSOffState) {
	}
 */
}

-(IBAction) openSearchWindow:(id) sender {
	[NSApp beginSheet:searchWindow modalForWindow:mainWindow modalDelegate:self 
	   didEndSelector:@selector(didEndSheet:returnCode:contextInfo:) contextInfo:nil];
	
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

-(void) setTitle:(NSString *)theTitle {
	[mainWindow setTitle: theTitle];
}

-(IBAction) getFromiTunesButton:(id) sender {
	iTunesTrack *track = [helper getCurrentTrack];
	if (track == nil)
		return;
	@try {
		[artistField setStringValue: [track artist]];
		[titleField setStringValue: [track name]];
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

- (void)didEndSheet:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo {
	if (sheet == searchWindow)
		[searchWindow orderOut:nil];
	else if (sheet == preferencesWindow) {
		[preferencesWindow orderOut:nil];
	}
}

-(IBAction) goButton:(id) sender {
	if (loadingLyrics) {
			return;
	}
	
	if (sender == nil)
		manualSearch = NO;
	else
		manualSearch = YES;
	
	NSString *artist, *title;
	artist = [artistField stringValue];
	title  = [titleField stringValue];
	
	if ([artist length] == 0 || [title length] == 0)
	{
		if (sender != nil) { // Don't show if it was called programmatically
			[[NSAlert alertWithMessageText:@"No artist/title pair specificed" defaultButton:@"OK" alternateButton:nil otherButton:nil
				 informativeTextWithFormat:@"Hey, you need to give me an artist and song title to search for!"] runModal];
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
	
	NSArray *data = [NSArray arrayWithObjects:title, artist, nil];
	NSThread *thread = [[NSThread alloc] initWithTarget:self selector:@selector(runThread:) object:data];
	// We have all the info we need, so start working:	
	[thread start];
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
	// FIXME: The name! Ugh, lol
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

- (void)runThread:(NSArray *)inData {
	NSString *title = [inData objectAtIndex:0];
	NSString *artist = [inData objectAtIndex:1];
	if (title == nil || artist == nil) {
		loadingLyrics = NO;
		return;
	}
	
	NSString *lyricStr;
	NSMutableArray *lyricData;
	SendNote(@"Trying iTunes...\n");
	
	// First, lets check if iTunes has an entry for this track already
	iTunesTrack *currentTrack = [helper getTrackForTitle:title byArtist:artist];
	NSString *iTunesLyrics = [helper getLyricsForTrack:currentTrack];
#ifndef DISABLE_CACHE
	if (iTunesLyrics != nil && [iTunesLyrics length] > 5) {
		lyricData = [NSMutableArray arrayWithObjects:@"No URL", iTunesLyrics, nil];
	}
	else 
#endif 
	{
		// Not in iTunes, lets fetch it
		lyricData = [lyricController fetchDataForTrack:title byArtist:artist];
		
		// Beautiful code:
		// (Basically, it checks if the data we got is OK, ond if it should save it to iTunes)
		if (lyricData != nil && [lyricData objectAtIndex:LYRIC] != nil) {
			if ([[currentTrack artist] isEqualToString:artist] && [[currentTrack name] isEqualToString:title]) {
				// The above line is to make sure we don't save into the wrong track, in case the currently displayed track isn't the one playing
				
				// This needs to be done when the track isn't playing. Otherwise, there will be a (very) noticable pause in the playback
				// when iTunes writes the data to disk.
				NSDictionary *data = [NSDictionary dictionaryWithObjectsAndKeys:
									  currentTrack, @"currentTrack",
									  [NSString stringWithString:[lyricData objectAtIndex:LYRIC]], @"lyric",
									  nil];
				
				NSThread *thread = [[NSThread alloc] initWithTarget:self selector:@selector(updateLyriciniTunes:) object:data];
				[thread start];
			}
		}
	}
	
	if (lyricData == nil || [lyricData objectAtIndex:LYRIC] == nil) {
		lyricStr = [NSString stringWithFormat:@"Nothing found, or an error occured somewhere! If you're online, the former is more likely, I'd say.\n"
					@"For the record, I searched for:\n%@ - %@",
					artist, title];
		[self performSelectorOnMainThread:@selector(setTitle:) withObject:@"Lyricus" waitUntilDone:YES];
		lyricsDisplayed = NO;
	}
	else {
		// We found some lyrics!
		lyricStr = [lyricData objectAtIndex:LYRIC];
		NSString *fullTitle = [NSString stringWithFormat:@"%@ - %@", artist, title];
		[self performSelectorOnMainThread:@selector(setTitle:) withObject:fullTitle waitUntilDone:YES];
		lyricsDisplayed = YES;
	}
	
	// Display lyrics + set font
	SetLyric(lyricStr);
	displayedArtist = [artist copy];
	displayedTitle = [title copy];
	
	// Scroll to the top (I don't think this is neccesary (anymore), but it doesn't hurt)
	[lyricView scrollRangeToVisible:NSMakeRange(0,0)];
	
	loadingLyrics = NO;
		
	[spinner stopAnimation:nil];
	[spinner setHidden:YES];
	[goButton setEnabled:YES];
	
	// If the track changed while loading, go get the NEW lyrics instead. Do NOT do this with manual searches, or the current track
	// would be displayed no matter what.
	if (!manualSearch && ! ([displayedArtist isEqualToString:[[helper getCurrentTrack] artist]] && [displayedTitle isEqualToString:[[helper getCurrentTrack] name]]) ) {
		[self getFromiTunesButton:nil];
		[self goButton:nil];
	}
	/*
	 // Doh. We do NOT want this: if a manual search is done, and the track changes during that time, we WANT it to show 
	 // "no lyrics found" if that is the case.
	else if ((manualSearch && !lyricsDisplayed) && ! ([displayedArtist isEqualToString:[[helper getCurrentTrack] artist]] && [displayedTitle isEqualToString:[[helper getCurrentTrack] name]]) ) {
		[self getFromiTunesButton:nil];
		[self goButton:nil];
	}
	*/

}	

-(BOOL) haveLyricsLocallyForCurrentTrack {
	//
	// Returns YES if lyric is in iTunes or cached, NO otherwise
	//
	iTunesTrack *currentTrack = [helper getCurrentTrack];
	if (currentTrack == nil)
		return NO;
	
	if ([helper getLyricsForTrack:[helper getCurrentTrack]] != nil)
		return YES;
	else
		return NO;
}

-(void)trackUpdated:(NSDictionary *)note {
	//
	// Checks if a new track has started playing, and if so, fetches the lyrics for that track
	//
	NSString *track = [NSString stringWithFormat:@"%@ - %@", [note objectForKey:@"Artist"], [note objectForKey:@"Name"]];

	@try { 
		if ([track isEqualToString:lastTrack]) {
			return;
		}
	}
	@catch (NSException *e) {} // Ignore, will most likely only happen on the first track, which means nothing really
	
	if ( ! [self haveLyricsLocallyForCurrentTrack]) {
		sleep (3); 	// To make sure the user didn't just skip a bunch of tracks;
					// We want to be sure that this is *the* new track.
	}
	@try {
		iTunesTrack *currentTrack = [helper getCurrentTrack];
		if (currentTrack == nil)
			return;
		
		NSString *newTrack = [NSString stringWithFormat:@"%@ - %@", [currentTrack artist], [currentTrack name]];
		if ([track isEqualToString:newTrack] && ![track isEqualToString:lastTrack]) {
			// Track DID change,so lets get the lyrics and stuff.
			lastTrack = [NSString stringWithString:newTrack];
			[self getFromiTunesButton:nil];
			[self goButton:nil];
		}
	}
	@catch (NSException *e) {}
}

-(void)handleiTunesNotification:(NSNotification *)note {
	//
	// Receives notifications from iTunes, and forwards them to trackUpdated: if a track started playing
	//
	//	if ([followiTunesCheckbox state] == NSOffState)
	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"Follow iTunes"] == NO)
		return;
	
	NSString *location = [[note userInfo] objectForKey:@"Location"];
	if (location == nil)
		return;
	
	if ([[location substringToIndex:4] isEqualToString:@"file"]) { // Not a HTTP stream or such
		if ([[[note userInfo] objectForKey:@"Player State"] isEqualToString:@"Playing"]) {
			// We have a playing track!
			[self trackUpdated:[note userInfo]];
			
		}
	}
}

#pragma mark -
#pragma mark Toolbar stuff

- (NSArray *)toolbarAllowedItemIdentifiers:(NSToolbar *)toolbar
{
	return [NSArray arrayWithObjects:NSToolbarSeparatorItemIdentifier,
			NSToolbarSpaceItemIdentifier,
			NSToolbarFlexibleSpaceItemIdentifier,
			kProgressIndicatorIdentifier,
			kSearchIdentifier,
			kBulkIdentifier,
			NSToolbarShowFontsItemIdentifier,
			NSToolbarCustomizeToolbarItemIdentifier,
			nil];
}

- (NSArray *)toolbarDefaultItemIdentifiers:(NSToolbar*)toolbar
{
    return [NSArray arrayWithObjects:kSearchIdentifier,
			kBulkIdentifier,
			NSToolbarFlexibleSpaceItemIdentifier,
			kProgressIndicatorIdentifier, nil];
}

- (NSToolbarItem *)toolbar:(NSToolbar *)toolbar
	 itemForItemIdentifier:(NSString *)itemIdentifier
 willBeInsertedIntoToolbar:(BOOL)flag
{
    NSToolbarItem *item = [[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier];
	if ([[item itemIdentifier] isEqualToString:kProgressIndicatorIdentifier]) {
		NSRect fRect = [spinnerView frame];
		[item setLabel:@"Progress"];
		[item setPaletteLabel:@"Progress indicator"];
		[item setView:spinnerView];
		[item setMinSize:fRect.size];
		[item setMaxSize:fRect.size];
	}
	else if ([[item itemIdentifier] isEqualToString:kSearchIdentifier]) {
		[item setLabel:@"Search"];
		[item setPaletteLabel:@"Search for lyric"];
		[item setImage:[NSImage imageNamed:@"search"]];
		[item setTarget:self];
		[item setAction:@selector(openSearchWindow:)];
	}
	else if ([[item itemIdentifier] isEqualToString:kBulkIdentifier]) {
		[item setLabel:@"Bulk"];
		[item setPaletteLabel:@"Open bulk downloader"];
		[item setImage:[NSImage imageNamed:@"bulk"]];
		[item setTarget:self];
		[item setAction:@selector(openBulkDownloader:)];
	}
	
	return item;
}

-(void)setupToolbar {
	NSToolbar *toolbar = [[NSToolbar alloc] initWithIdentifier:@"mainToolbar"];
    [toolbar setDelegate:self];
    [toolbar setAllowsUserCustomization:YES];
    [toolbar setAutosavesConfiguration:YES];
	[toolbar setSizeMode:NSToolbarSizeModeSmall];
	[toolbar setDisplayMode:NSToolbarDisplayModeIconOnly];
    [mainWindow setToolbar:toolbar];
}

#pragma mark -
#pragma mark Misc.

-(void)disableEditMode {
	[editModeMenuItem setState:0];
	[lyricView setEditable:NO];
	[mainWindow setTitle:[NSString stringWithFormat:@"%@ - %@", displayedArtist, displayedTitle, nil]];
/*	[lyricView setBackgroundColor: [NSColor colorWithDeviceRed:1.0 green:1.0 blue:1.0 alpha:1.0]]; */
	[lyricView setBackgroundColor:(NSColor *)[NSUnarchiver unarchiveObjectWithData:[[NSUserDefaults standardUserDefaults] valueForKey:@"BackgroundColor"]]];
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
	if (!displayedArtist || !displayedTitle) {
		[TBUtil showAlert:@"You tried to save without having a track's lyrics displayed!" withCaption:@"Unable to save"];
		goto end_return;
	}
	
	NSArray *theTracks = [helper getAllTracksForTitle:displayedTitle byArtist:displayedArtist];
	if (theTracks == nil) {
		[TBUtil showAlert:@"You tried to save the lyrics to a track I can't find in your iTunes library!" withCaption:@"Unable to save"];
		goto end_return;
	}

	// Ugh, setLyrics returns void, so we can't check for errors.
	NSString *newLyric = [lyricView string];
	
	for (iTunesTrack *theTrack in theTracks) {
		[theTrack setLyrics:newLyric];
	}
	
end_return:
	lyricsDisplayed = YES; // To make sure edit mode isn't bugged when adding new lyrics to a track
	[self disableEditMode];
	return;
}

-(IBAction)saveDisplayedLyricsToCurrentlyPlayingTrack:(id) sender  {
	NSString *newLyric = [lyricView string];

	if (newLyric == nil || [newLyric length] <= 1) {
		[TBUtil showAlert:@"You tried to save without having any lyrics displayed!" withCaption:@"Unable to save"];
		goto end_return;
	}
	
	[[helper getCurrentTrack] setLyrics: newLyric];
	
end_return:
	[self disableEditMode];
	
	// Refresh the lyric display and fix the title, etc.
	[self goButton:nil];
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
	
	NSString *artistURL = [songmeanings getURLForArtist:displayedArtist];
	if (!artistURL) {
		[TBUtil showAlert:@"Artist not found on songmeanings!" withCaption:@"Unable to open songmeanings page"];
		goto end_func;
	}
	
	NSString *myTitle = displayedTitle;
	
	if ([displayedTitle containsString:@"(live" ignoringCaseAndDiacritics:YES]) {
		myTitle = [NSString stringWithString:[displayedTitle stringByReplacingOccurrencesOfRegex:@"(?i)(.*?)\\s*\\(live.*" withString:@"$1"]];
	}
	
	NSString *lyricURL = [songmeanings getLyricURLForTrack:myTitle fromArtistURL:artistURL];
	if (!lyricURL) {
		[TBUtil showAlert:@"Lyric not found on songmeanings!" withCaption:@"Unable to open songmeanings page"];
		goto end_func;
	}
	
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:lyricURL]];
end_func:
	[spinner stopAnimation:nil];
	[spinner setHidden:YES];
	return;
}

-(IBAction)openLyricSearch:(id)sender {
    if (lyricSearch == nil) {
        lyricSearch = [[LyricSearchController alloc] initWithWindowNibName:@"LyricSearch"];
    }
    [lyricSearch showWindow:self];
    [lyricSearch.window makeKeyAndOrderFront:self];
    [lyricSearch showLyricSearch:self];
}

-(void)finalize {
	// This doesn't seem to be called, but what the heck.
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[[NSDistributedNotificationCenter defaultCenter] removeObserver:self];
	[super finalize];
}

@end