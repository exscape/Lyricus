//
// This file is part of Lyricus.
// Copyright (c) 2008-2011, Thomas Backman <serenity@exscape.org>
// This software is distributed under the terms of the MIT license. For details, see license.txt.
//

#import "Bulk.h"
#import "NSTextView+AppendString.h"
#import "NSProgressIndicator+ThreadSafeUpdating.h"
#import "PlaylistObject.h"
#import "TrackObject.h"
#import "ImageAndTextCell.h"

#define LyricusStartingWorkType 1
#define LyricusFoundType 2
#define LyricusNotFoundType 3

@implementation Bulk

@synthesize bulkDownloaderIsWorking;

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
		// Return the number of root objects
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
		[(ImageAndTextCell*)cell setImage:image];
	}
	
	[cell setWraps:NO];
	[cell setLineBreakMode:NSLineBreakByTruncatingTail];
	
}

-(void)outlineViewSelectionDidChange:(NSNotification *)notification {
	if ([playlistView selectedRow] >= 0) {
		[goButton setEnabled:YES];
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
		[lyricController setBulk:YES];
		helper = [iTunesHelper sharediTunesHelper];
		[self setBulkDownloaderIsWorking:NO];
		firstLoad = YES;
		
		return self;
	}
	return nil;
} 

- (BOOL)windowShouldClose:(id)sender {
	// No need to confirm if nothing is running
	if (![thread isExecuting]) {
		return YES;
	}
	
	if ([[NSAlert alertWithMessageText:@"Do you want to abort the bulk download and close the window?" defaultButton:@"Yes, abort" alternateButton:@"No, keep going" otherButton:nil informativeTextWithFormat:@"Lyrics downloaded so far will be saved."] runModal] == NSAlertDefaultReturn) {
		// Yes, abort:
		[thread cancel];
		[self setBulkDownloaderIsWorking:NO];
		[goButton setTitle:@"Go"];
		[statusLabel setStringValue:@"Idle"];
		return YES;
	}
	else {
		// No, don't abort
		return NO;
	}
}

-(void)repopulatePlaylistView {	
	[playlists removeAllObjects];
	for (iTunesPlaylist* currentPlaylist in [helper getAllPlaylistsAndFolders]) {
		PlaylistObject *o = [[PlaylistObject alloc] initWithPlaylist: currentPlaylist];
		
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
	
	[self showBulkDownloader];
	[playlistView setIndentationPerLevel:16.0];
	[playlistView setIndentationMarkerFollowsCell:YES];
	
	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"Auto-expand playlist view"])
		[playlistView expandItem:nil expandChildren:YES];
}

-(void) showWindow:(id)sender {
	if (firstLoad == NO) {
		[self repopulatePlaylistView];
	}
	firstLoad = NO;
	[super showWindow:sender];
}

-(void) loadTracks {
	[tracks removeAllObjects];
	
	PlaylistObject *playlist = [playlistView itemAtRow:[playlistView selectedRow]];
	
	SBElementArray *tmpTracks = [[playlist playlist] tracks]; // no [get]
	NSArray *tmpArtists = [tmpTracks arrayByApplyingSelector:@selector(artist)];
	NSArray *tmpNames = [tmpTracks arrayByApplyingSelector:@selector(name)];
	for (int i=0; i < [tmpArtists count]; i++) {
		[tracks addObject:
		 [[TrackObject alloc] initWithTrack: [tmpTracks objectAtIndex: i] Artist:[tmpArtists objectAtIndex: i] Name: [tmpNames objectAtIndex: i]]
		 ];
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

-(void)showBulkDownloader {	
	[statusLabel setStringValue:@"Idle"];	
	[self setBulkDownloaderIsWorking:NO];
	[self showWindow:self];
    [self.window makeKeyAndOrderFront:self];
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
		[goButton setTitle:@"Go"];
		[statusLabel setStringValue:@"Idle"];
		[self setBulkDownloaderIsWorking:NO];
		
		return;
	}
	[goButton setTitle:@"Stop"];
	[statusLabel setStringValue:@"Working..."];
	
	[lyricController updateSiteList];
	
	if (tracks == nil || [tracks count] == 0) {
		// Appears to happen only when iTunes is not running, or when the selected playlist has been deleted
		[[NSAlert alertWithMessageText:@"The bulk downloader cannot start because no tracks were found." defaultButton:@"OK" alternateButton:nil otherButton:nil informativeTextWithFormat:@"Make sure that iTunes is running and that there are tracks in the chosen playlist."] runModal];
		[self setBulkDownloaderIsWorking:NO];
		[goButton setTitle:@"Go"];
		[statusLabel setStringValue:@"Idle"];
		
		return;
	}
	
	if ([tracks count] > 40) {
		if ([[NSAlert alertWithMessageText:[NSString stringWithFormat:@"There are %d tracks to process. Do you want to continue?", [tracks count]] defaultButton:@"Continue" alternateButton:@"Abort" otherButton:nil informativeTextWithFormat:@"This action may tike some time."] runModal] 
			== NSAlertAlternateReturn) {
			[self setBulkDownloaderIsWorking:NO];
			[statusLabel setStringValue:@"Idle"];
			[goButton setTitle:@"Go"];
			return;
		}
	}
	
	[self setBulkDownloaderIsWorking:YES];
	
	thread = [[NSThread alloc] initWithTarget:self selector:@selector(workerThread:) object:nil];
	[thread start];
	
}
-(void)workerThread:(id)unused {
	int count = 0;
	
	if ([tracks count] == 0) {
		[[NSAlert alertWithMessageText:@"The bulk downloader cannot start because the selected playlist is empty." defaultButton:@"OK" alternateButton:nil otherButton:nil informativeTextWithFormat:
		  @"If you are using the \"[Selected tracks]\" playlist, make sure the tracks are selected in iTunes."] runModal];
		[statusLabel setStringValue:@"Idle"];
		[goButton setTitle:@"Go"];
		[self setBulkDownloaderIsWorking:NO];
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
	
	for (TrackObject *track in tracks) {
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
		@try { 
			if (![[track track] get] || ![[[track track] get] exists])
				continue;
			
			lyrics = [[track track] lyrics];
		} 
		@catch (NSException *e) { continue; }
		
		@try {
			
			// Set mixed state when we start working
			[self performSelectorOnMainThread:@selector(setCheckMarkForTrack:) withObject:
			 [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInteger:NSMixedState], @"state", track, @"track", nil]
								waitUntilDone:YES];
			
			if ([[[track track] lyrics] length] > 8) { 
				
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
				[[track track] setLyrics:lyrics];
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
			[[NSAlert alertWithMessageText:@"The bulk downloader aborted due to encountering too many errors." defaultButton:@"OK" alternateButton:nil otherButton:nil informativeTextWithFormat:@"Make sure that your internet connection is active. If possible, try enabling multiple sites in the Lyricus preferences."] runModal];
			goto restore_settings;
		}
		
	}
	
	[self showBulkDownloader];
	[[NSAlert alertWithMessageText:@"Bulk download complete" defaultButton:@"OK" alternateButton:nil otherButton:nil informativeTextWithFormat:@"Finished downloading lyrics for %d tracks.\n\nStatistics:\n"
	  @"Downloaded lyrics for %d tracks\n"
	  @"%d tracks already had lyrics set\n"
	  @"Couldn't find lyrics for %d tracks",
	  count, set_lyrics, had_lyrics, lyrics_not_found]
	 runModal];
	
restore_settings:
	[goButton setTitle:@"Go"];
	[statusLabel setStringValue:@"Idle"];
	[self setBulkDownloaderIsWorking:NO];
	
	[progressIndicator performSelectorOnMainThread:@selector(thrSetCurrentValue:) withObject:[NSNumber numberWithInt:0] waitUntilDone:YES];
	
	// NO more code after this!
}


@end
