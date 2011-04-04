//
// This file is part of Lyricus.
// Copyright (c) 2008-2011, Thomas Backman <serenity@exscape.org>
// This software is distributed under the terms of the MIT license. For details, see license.txt.
//

#import "Batch.h"
#import "NSTextView+AppendString.h"
#import "NSProgressIndicator+ThreadSafeUpdating.h"
#import "PlaylistObject.h"
#import "TrackObject.h"
#import "ImageAndTextCell.h"

#define LyricusStartingWorkType 1
#define LyricusFoundType 2
#define LyricusNotFoundType 3

@implementation Batch

@synthesize batchDownloaderIsWorking;

#define kBatchWelcomeScreenText @"This window allows you to batch download lyrics for your iTunes playlists.\n" \
	@"To get started, select a playlist in the list to the left, then click \"Start\"."

#pragma mark -
#pragma mark Init stuff

-(PlaylistObject *)getPlaylistObjectForName:(NSString *)name {
	for (PlaylistObject *plo in playlists) {
		if ([[plo name] isEqualToString:name])
			return plo;
	}
	return nil;
}

#pragma mark -
#pragma mark NSOutlineView methods

- (NSInteger)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item {
	if (playlists == nil)
		return 0;
	
	if (item == nil) {
		return [[playlists filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"isRootItem = TRUE"]] count];
	}
	else {
		// Return the number of children for this folder
		return [[item children] count];
	}
}

- (id)outlineView:(NSOutlineView *)outlineView child:(NSInteger)index ofItem:(id)item {
	if (item == nil) {
		return [[playlists filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"isRootItem = TRUE"]] objectAtIndex:index];
	}
	
	if ([[item children] count] > 0) {
		return [[item children] objectAtIndex:index];
	}
	else
		return nil;
}

-(BOOL)outlineView:(NSOutlineView *)outlineView shouldSelectItem:(id)item {
	if ([self batchDownloaderIsWorking])
		return NO;
	
	return ([item specialKind] != iTunesESpKFolder);
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item {
	return ([[item children] count] != 0);
}

- (void)outlineView:(NSOutlineView *)olv willDisplayCell:(NSCell *)cell forTableColumn:(NSTableColumn *)tableColumn item:(id)item 
{    
	NSImage *image;
    if ([[tableColumn identifier] isEqualToString: @"PlaylistName"]) 
	{
		if ([[item name] isEqualToString:@"iTunes Selection"]) {
			// Special case
			image = [NSImage imageNamed:@"iTunes-selection.png"];
		}
		else {
			iTunesESpK kind = [item specialKind];
			if (kind == iTunesESpKFolder)
				image = [NSImage imageNamed:@"iTunes-folder.png"];
			else if (kind == iTunesESpKPartyShuffle)
				image = [NSImage imageNamed:@"iTunes-DJ.png"];
			else if (kind == iTunesESpKLibrary)
				image = [NSImage imageNamed:@"iTunes-library.png"];
			else {
				// This a playlist, smart or regular
				if ([item smart]) {
					image = [NSImage imageNamed:@"iTunes-smart.png"];
				}
				else
					image = [NSImage imageNamed:@"iTunes-playlist.png"];
			}
		}
		[(ImageAndTextCell*)cell setImage:image];
	}
	
	[cell setWraps:NO];
	[cell setLineBreakMode:NSLineBreakByTruncatingTail];
	
}

-(void)outlineViewSelectionDidChange:(NSNotification *)notification {
	if ([playlistView selectedRow] >= 0) {
		[startButton setEnabled:YES];
		[self loadTracks];
	}
}

- (id)outlineView:(NSOutlineView *)outlineView objectValueForTableColumn:(NSTableColumn *)tableColumn byItem:(id)item {
	if ([[tableColumn identifier] isEqualToString:@"PlaylistName"]) {
		return [item name];
	}
	
	return nil;
}

#pragma mark -
#pragma Misc.

-(id) initWithWindowNibName:(NSString *)windowNibName {
    self = [super initWithWindowNibName:windowNibName];
	if (self) {
		playlists = [[NSMutableArray alloc] init];
		tracks = [[NSMutableArray alloc] init];
		lyricController = [[LyricFetcher alloc] init];
		[lyricController setBatch:YES];
		helper = [iTunesHelper sharediTunesHelper];
		[self setBatchDownloaderIsWorking:NO];
		firstLoad = YES;
		
		[[NSNotificationCenter defaultCenter] addObserver: self selector: @selector(didChangeScreenParameters:)
													 name: NSApplicationDidChangeScreenParametersNotification object: nil];
		return self;
	}
	return nil;
} 

-(void)didChangeScreenParameters: (NSNotification *)note {
	// Make sure the window is still on the screen
	NSRect screenRect = [[NSScreen mainScreen] visibleFrame];
	NSRect windowFrame = [self.window frame];
	
	if (windowFrame.origin.x + windowFrame.size.width > screenRect.size.width)
		windowFrame.origin.x = screenRect.size.width - windowFrame.size.width;
	if (windowFrame.origin.y < 0)
		windowFrame.origin.y = 0;
	
	[self.window setFrame:windowFrame display:NO animate:NO];
}

- (void) doubleClick:(id) sender {
	if (tracks == nil || [trackView clickedRow] >= [tracks count])
		return;
	TrackObject *track = [tracks objectAtIndex:[trackView clickedRow]];
	[[track track] playOnce:NO];
}

- (BOOL)windowShouldClose:(id)sender {
	// No need to confirm if nothing is running
	if (![thread isExecuting]) {
		return YES;
	}
	
	if ([[NSAlert alertWithMessageText:@"Do you want to abort the batch download and close the window?" defaultButton:@"Yes, abort" alternateButton:@"No, keep going" otherButton:nil informativeTextWithFormat:@"Lyrics downloaded so far will be saved."] runModal] == NSAlertDefaultReturn) {
		// Yes, abort:
		[thread cancel];
		[self setBatchDownloaderIsWorking:NO];
		[startButton setTitle:@"Start"];
		[statusLabel setStringValue:@"Idle"];
		[startButton setKeyEquivalent:@"\r"];
		return YES;
	}
	else {
		// No, don't abort
		return NO;
	}
}

-(void)repopulatePlaylistView {	
	[playlists removeAllObjects];
	
	int i=0;
	for (iTunesPlaylist* currentPlaylist in [helper getAllPlaylistsAndFolders]) {
		i++;
		PlaylistObject *o = [[PlaylistObject alloc] initWithPlaylist: currentPlaylist];
		
		if (i == 2) {
			// Squeeze in the "iTunes Selection" playlist here
			[playlists addObject:[[PlaylistObject alloc] initWithName:@"iTunes Selection"]];
		}
				
		// Calling "get" here is crucial - if we don't, the value will NEVER be nil!
		if ([[currentPlaylist parent] get] != nil) {
			// Note that since playlists are returned in order,
			// a folder will always be added BEFORE its children.
			// Thus we don't have to re-check this array after we're done.
			PlaylistObject *parentPlaylistObject = [self getPlaylistObjectForName:[[currentPlaylist parent] name]];
			if (parentPlaylistObject != nil) {
				[parentPlaylistObject addChild:o];
			}
		}	
		
		[playlists addObject:o];
	}
	
	[playlistView reloadData];
}

-(void) windowDidLoad {
	NSTableColumn *tableColumn = nil;
	ImageAndTextCell *imageAndTextCell = nil;
	
	tableColumn = [playlistView tableColumnWithIdentifier: @"PlaylistName"];
	imageAndTextCell = [[[ImageAndTextCell alloc] init] autorelease];
	[imageAndTextCell setEditable:YES];
	[tableColumn setDataCell:imageAndTextCell];
	
	[playlistView setSelectionHighlightStyle:NSTableViewSelectionHighlightStyleSourceList];
	helper = [iTunesHelper sharediTunesHelper];

	[self repopulatePlaylistView];
	
	[self showBatchDownloader];
	[playlistView setIndentationPerLevel:16.0];
	[playlistView setIndentationMarkerFollowsCell:YES];
	
	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"Auto-expand playlist view"])
		[playlistView expandItem:nil expandChildren:YES];
	
	[trackView setTarget:self];
	[trackView setDoubleAction:@selector(doubleClick:)];
	
	if ( ! [[NSUserDefaults standardUserDefaults] boolForKey:@"Hide batch welcome screen"] ) {
		welcomeScreen = [[WelcomeScreen alloc] initWithText:kBatchWelcomeScreenText owningWindow:self.window delegate:self];
		[welcomeScreen showWindow:self];
	}
	
	[startButton setKeyEquivalent:@"\r"];
	
	[trackView registerForDraggedTypes:[NSArray arrayWithObject:kLyricusTrackDragType]];
	
	splitViewDelegate = [[PrioritySplitViewDelegate alloc] init];
	[splitView setDelegate:splitViewDelegate];
	[splitViewDelegate setPriority:1 forViewAtIndex:0];
	[splitViewDelegate setPriority:0 forViewAtIndex:1];
	[splitViewDelegate setMinimumLength:125 forViewAtIndex:0];
	[splitViewDelegate setMinimumLength:200 forViewAtIndex:1];
}

-(void)windowDidBecomeMain:(NSNotification *)notification {
	[self loadTracks];
}

-(BOOL)tableView:(NSTableView *)tableView writeRowsWithIndexes:(NSIndexSet *)rowIndexes toPasteboard:(NSPasteboard *)pboard {
	// Since only a single row can be selected, and there is
	// little reason to change that in the future, only copy one row.
	TrackObject *track = [tracks objectAtIndex:[rowIndexes firstIndex]];
	NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:[track artist], @"artist", [track name], @"name", nil];
	
	NSData *data = [NSKeyedArchiver archivedDataWithRootObject:dict];
	[pboard declareTypes:[NSArray arrayWithObject:kLyricusTrackDragType] owner:self];
	[pboard setData:data forType:kLyricusTrackDragType];
	
	return YES;
}

-(void) userDidCloseWelcomeScreenWithDontShowAgain:(BOOL)state {
	if (state == YES) {
		[[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"Hide batch welcome screen"];
	}
}

-(void) showWindow:(id)sender {
	if (firstLoad == NO) {
		[self repopulatePlaylistView];
	}
	firstLoad = NO;
	[super showWindow:sender];
}

-(void) loadTracks {
	if ([self batchDownloaderIsWorking])
		return;
	
	[tracks removeAllObjects];
	
	PlaylistObject *playlist = [playlistView itemAtRow:[playlistView selectedRow]];
	
	if ([[playlist name] isEqualToString:@"iTunes Selection"]) {
		NSArray *tmpTracks = [helper getSelectedTracks];		
		for (iTunesTrack *track in tmpTracks) {
			// Damnit, TrackObject was *designed* to *not* do this.
			// However, [iTunes selection] simply won't return us an SBElementArray, yet this works.
			// It would appear that [iTunes selection] returns an SBObject with nothing more than a description, until
			// "get" is called, and the new result is an NSCFArray - that doesn't
			// have the capability of arrayByApplyingSelector:.
			[tracks addObject:
			 [[TrackObject alloc] initWithTrack: track Artist:[track artist] Name: [track name]]
			 ];
		}
	}
	else {
		SBElementArray *tmpTracks = [[playlist playlist] tracks]; // no [get]
	
		NSArray *tmpArtists = [tmpTracks arrayByApplyingSelector:@selector(artist)];
		NSArray *tmpNames = [tmpTracks arrayByApplyingSelector:@selector(name)];
		for (int i=0; i < [tmpArtists count]; i++) {
			[tracks addObject:
			 [[TrackObject alloc] initWithTrack: [tmpTracks objectAtIndex: i] Artist:[tmpArtists objectAtIndex: i] Name: [tmpNames objectAtIndex: i]]
			 ];
		}
	}
	
	[trackView reloadData];
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView {
	return [tracks count];
}

- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex
{
	if ([[aTableColumn identifier] isEqualToString:@"Checkbox"]) {
		return [NSNumber numberWithInteger:[[tracks objectAtIndex:rowIndex] state]];
	}
	else if ([[aTableColumn identifier] isEqualToString:@"Artist"]) {
		return [[tracks objectAtIndex:rowIndex] artist];
	}
	else if ([[aTableColumn identifier] isEqualToString:@"Name"]) {
		return [[tracks objectAtIndex:rowIndex] name];
	}
	else
		return nil;
}

-(void)showBatchDownloader {	
	[[NSApplication sharedApplication] activateIgnoringOtherApps:YES];
	[self showWindow:self];
    [self.window makeKeyAndOrderFront:self];
	if (welcomeScreen != nil && ! [[NSUserDefaults standardUserDefaults] boolForKey:@"Hide batch welcome screen"]) {
		[welcomeScreen showWindow:self];
	}
}

-(void)setCheckMarkForTrack:(NSDictionary *)data {
	NSInteger state = [[data objectForKey:@"state"] integerValue];
	TrackObject *track = [data objectForKey:@"track"];
	
	[track setState:state];
	[trackView setNeedsDisplayInRect:[trackView rectOfRow:[tracks indexOfObject:track]]];
	[trackView scrollRowToVisible:[tracks indexOfObject:track]];
}

#pragma mark -
#pragma mark Misc

-(IBAction)goButtonClicked:(id)sender {
	//
	// The user clicked "go"
	//
	
	// The thread is already running; abort
	if ([thread isExecuting]) {
		[thread cancel];
		[startButton setTitle:@"Start"];
		[statusLabel setStringValue:@"Idle"];
		[self setBatchDownloaderIsWorking:NO];
		[startButton setKeyEquivalent:@"\r"];
		
		return;
	}
	[startButton setTitle:@"Stop"];
	[statusLabel setStringValue:@"Working..."];
	[startButton setKeyEquivalent:@"\033"]; // Escape
	
	if ([[[playlistView itemAtRow:[playlistView selectedRow]] name] isEqualToString:@"iTunes Selection"]) {
		// Reload tracks, in case the selection changed.
		// In the case of regular playlists, don't reload for performance reasons.
		[self loadTracks];
	}
	
	[lyricController updateSiteList];
	
	if (tracks == nil || [tracks count] == 0) {
		// Appears to happen only when iTunes is not running, or when the selected playlist has been deleted
		[[NSAlert alertWithMessageText:@"The batch downloader cannot start because no tracks were found." defaultButton:@"OK" alternateButton:nil otherButton:nil informativeTextWithFormat:@"Make sure that iTunes is running and that there are tracks in the chosen playlist."] runModal];
		[self setBatchDownloaderIsWorking:NO];
		[startButton setTitle:@"Start"];
		[statusLabel setStringValue:@"Idle"];
		[startButton setKeyEquivalent:@"\r"];
		
		return;
	}
	
	if ([tracks count] > 40) {
		if ([[NSAlert alertWithMessageText:[NSString stringWithFormat:@"There are %d tracks to process. Do you want to continue?", [tracks count]] defaultButton:@"Continue" alternateButton:@"Abort" otherButton:nil informativeTextWithFormat:@"This action may take some time."] runModal] 
			== NSAlertAlternateReturn) {
			[self setBatchDownloaderIsWorking:NO];
			[statusLabel setStringValue:@"Idle"];
			[startButton setTitle:@"Start"];
			[startButton setKeyEquivalent:@"\r"];
			
			return;
		}
	}
	
	[self setBatchDownloaderIsWorking:YES];
	
	thread = [[NSThread alloc] initWithTarget:self selector:@selector(workerThread:) object:nil];
	[thread start];
	
}
-(void)workerThread:(id)unused {
	int count = 0;
		
	if ([tracks count] == 0) {
		[[NSAlert alertWithMessageText:@"The batch downloader cannot start because the selected playlist is empty." defaultButton:@"OK" alternateButton:nil otherButton:nil informativeTextWithFormat:
		  @"If you are using the \"[Selected tracks]\" playlist, make sure the tracks are selected in iTunes."] runModal];
		[statusLabel setStringValue:@"Idle"];
		[startButton setTitle:@"Start"];
		[self setBatchDownloaderIsWorking:NO];
		[startButton setKeyEquivalent:@"\r"];

		return;
	}
	
	NSUInteger numberOfTracks = [tracks count];
	
	// Set up the progress indicator
	[progressIndicator performSelectorOnMainThread:@selector(thrSetMaxValue:) withObject:[NSNumber numberWithInt:numberOfTracks] waitUntilDone:YES];
	[progressIndicator performSelectorOnMainThread:@selector(thrSetMinValue:) withObject:[NSNumber numberWithInt:0] waitUntilDone:YES];
	[progressIndicator performSelectorOnMainThread:@selector(thrSetCurrentValue:) withObject:[NSNumber numberWithInt:0] waitUntilDone:YES];
	
	// Used to track some stats
	int set_lyrics = 0;
	int had_lyrics = 0;
	int lyrics_not_found = 0;
	int errors_in_a_row = 0; // Used to abort when things appear to be going wrong
	
	for (TrackObject *track in [tracks copy]) {
		count++;
		[statusLabel setStringValue:[NSString stringWithFormat:@"Processing... %d/%u", count, numberOfTracks]];
		
		if ([thread isCancelled]) {
			goto restore_settings; 	// We can't just break as that would display the window with stats, etc. The user *closed* the window,
									// it shouldn't just pop open again.
		}
		
		[progressIndicator performSelectorOnMainThread:@selector(thrIncrementBy:) withObject:[NSNumber numberWithDouble:1.0] waitUntilDone:YES];

		// Skip all tracks that have already been processed since loading
		// Note that progress is NOT saved, which is probably closer to a feature than a bug.
		// (How would the user reset and re-allow a track to be re-downloaded?)
		if ([track processed])
			continue;
		
		NSString *lyrics = nil;
		iTunesTrack *realTrack;
		@try {
			realTrack = [[track track] get];
			if (![realTrack exists]) {
				// Can happen if the user deletes the item from iTunes
				continue;
			}
			
			lyrics = [realTrack lyrics];
		} 
		@catch (NSException *e) { continue; }
		
			// Set mixed state when we start working
			[self performSelectorOnMainThread:@selector(setCheckMarkForTrack:) withObject:
			 [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInteger:NSMixedState], @"state", track, @"track", nil]
								waitUntilDone:YES];
		@try {
			if ([[realTrack lyrics] length] > 8) { 
				
				had_lyrics++;
				// DON'T update errors_in_a_row since we don't know if searching would have worked or not
				
				// Success
				[self performSelectorOnMainThread:@selector(setCheckMarkForTrack:) withObject:
				 [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInteger:NSOnState], @"state", track, @"track", nil]
									waitUntilDone:YES];
				
				continue;
			}
		} @catch (NSException *e) { continue; }
		
		NSError *err = nil; // Ignored
		lyrics = [lyricController fetchLyricsForTrack:[track name] byArtist:[track artist] error:&err];
		if (lyrics) {
			@try { // Scripting bridge seems to be a bit unstable
				[realTrack setLyrics:lyrics];
			} 
			@catch (NSException *e) { continue; }
			
			set_lyrics++;
			errors_in_a_row = 0;
			
			// Success
			[self performSelectorOnMainThread:@selector(setCheckMarkForTrack:) withObject:
			 [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInteger:NSOnState], @"state", track, @"track", nil]
								waitUntilDone:YES];
			
		}
		else if (err == nil) {
			lyrics_not_found++;
			errors_in_a_row = 0;
			
			// Nothing found
			[self performSelectorOnMainThread:@selector(setCheckMarkForTrack:) withObject:
			 [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInteger:NSOffState], @"state", track, @"track", nil]
								waitUntilDone:YES];
		}
		else {
			errors_in_a_row++;
			lyrics_not_found++;
			
			// Error = no checkmark
			[self performSelectorOnMainThread:@selector(setCheckMarkForTrack:) withObject:
			 [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInteger:NSOffState], @"state", track, @"track", nil]
								waitUntilDone:YES];
			
		}
		
		if (errors_in_a_row >= 10) {
			[thread cancel];
			[[NSAlert alertWithMessageText:@"The batch downloader aborted due to encountering too many errors." defaultButton:@"OK" alternateButton:nil otherButton:nil informativeTextWithFormat:@"Make sure that your internet connection is active. If possible, try enabling multiple sites in the Lyricus preferences."] runModal];
			goto restore_settings;
		}
		
	}
	
	[self showBatchDownloader];
	[[NSAlert alertWithMessageText:@"Batch download complete" defaultButton:@"OK" alternateButton:nil otherButton:nil informativeTextWithFormat:@"Finished downloading lyrics for %d tracks.\n\nStatistics:\n"
	  @"Downloaded lyrics for %d tracks\n"
	  @"%d tracks already had lyrics set\n"
	  @"Couldn't find lyrics for %d tracks",
	  count, set_lyrics, had_lyrics, lyrics_not_found]
	 runModal];
	
restore_settings:
	[startButton setTitle:@"Start"];
	[statusLabel setStringValue:@"Idle"];
	[self setBatchDownloaderIsWorking:NO];
	[startButton setKeyEquivalent:@"\r"];
	
	[progressIndicator performSelectorOnMainThread:@selector(thrSetCurrentValue:) withObject:[NSNumber numberWithInt:0] waitUntilDone:YES];
	
	// NO more code after this!
}


@end
