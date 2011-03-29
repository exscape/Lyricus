//
// This file is part of Lyricus.
// Copyright (c) 2008-2011, Thomas Backman <serenity@exscape.org>
// This software is distributed under the terms of the MIT license. For details, see license.txt.
//

#import "Bulk.h"
#import "NSTextView+AppendString.h"
#import "NSProgressIndicator+ThreadSafeUpdating.h"
#import "PlaylistObject.h"
#import "ImageAndTextCell.h"

#define LyricusStartingWorkType 1
#define LyricusFoundType 2
#define LyricusNotFoundType 3

@implementation Bulk

@synthesize bulkDownloaderIsWorking;

-(NSString *)stringByTruncatingToMaxWidth:(NSString *)string {
	// Truncate the string, if necessary, to fit on a single line
	NSSize size = [string sizeWithAttributes: [NSDictionary dictionaryWithObject: [resultView font] forKey: NSFontAttributeName]];
	NSString *outString = [string copy];
	while (size.width > 340) {
		outString = [outString substringWithRange:NSMakeRange(0, [outString length]-6)];
		outString = [outString stringByAppendingString:@"..."];
		size = [outString sizeWithAttributes: [NSDictionary dictionaryWithObject: [resultView font] forKey: NSFontAttributeName]];
	}
	
	return [outString stringByAppendingString:@"\n"];
}

-(void)doReplace:(NSDictionary *)dict {
	NSImage *image = [NSImage imageNamed:[dict objectForKey:@"imageName"]];
	NSTextAttachmentCell *attachmentCell = [[NSTextAttachmentCell alloc] initImageCell:image];
	NSTextAttachment *attachment = [[NSTextAttachment alloc] init];
	[attachment setAttachmentCell:attachmentCell];
	NSAttributedString *attributedString = [NSAttributedString attributedStringWithAttachment:attachment];
	
	int position = [[dict objectForKey:@"position"] intValue];
	[[resultView textStorage] replaceCharactersInRange:NSMakeRange([[resultView textStorage] length] - position - 1, 1) withAttributedString:attributedString];
}

-(void)progressUpdateWithType:(int) type andString: (NSString *)string {
	
	string = [self stringByTruncatingToMaxWidth:string];
	
	if (type == LyricusStartingWorkType) {
		if (bulkDownloaderIsWorking) {
			[resultView performSelectorOnMainThread:@selector(appendImageNamed:) withObject:@"icon_working.png" waitUntilDone:YES];
			[resultView performSelectorOnMainThread:@selector(appendString:) withObject:string waitUntilDone:YES];
		}
	}
	
	else if (type == LyricusFoundType) {		
		if (bulkDownloaderIsWorking) {
			NSDictionary *data = [NSDictionary dictionaryWithObjectsAndKeys: [NSNumber numberWithInt:[string length]], @"position", @"icon_found.png", @"imageName", nil];
			[self performSelectorOnMainThread:@selector(doReplace:) withObject:data waitUntilDone:YES];
		}
	}
	else if (type == LyricusNotFoundType) {
		if (bulkDownloaderIsWorking) {
			NSDictionary *data = [NSDictionary dictionaryWithObjectsAndKeys: [NSNumber numberWithInt:[string length]], @"position", @"icon_notfound.png", @"imageName", nil];
			[self performSelectorOnMainThread:@selector(doReplace:) withObject:data waitUntilDone:YES];
		}
	}
}

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
/*
- (CGFloat)outlineView:(NSOutlineView *)outlineView heightOfRowByItem:(id)item
{
	return 30;
}
*/

- (NSInteger)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item {
	if (item == nil) {
		// Return the number of root objects
		return [rootObjects count];
	}
	else {
		// Return the number of children for this folder
		return [[item children] count];
	}
}

- (id)outlineView:(NSOutlineView *)outlineView child:(NSInteger)index ofItem:(id)item {
	if (item == nil) {
		return [rootObjects objectAtIndex:index];
		//		[[[playlists filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"isRootItem = TRUE"]]
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
	if ([playlistView selectedRow] >= 0)
		[goButton setEnabled:YES];
}


- (id)outlineView:(NSOutlineView *)outlineView objectValueForTableColumn:(NSTableColumn *)tableColumn byItem:(id)item {
	if ([[tableColumn identifier] isEqualToString:@"PlaylistName"]) {
		return [item name];
	}
	
	return nil;
}

-(id) initWithWindowNibName:(NSString *)windowNibName {
    self = [super initWithWindowNibName:windowNibName];
	if (self) {
		playlists = [[NSMutableArray alloc] init];
		rootObjects = [[NSMutableArray alloc] init];
		lyricController = [[LyricFetcher alloc] init];
		[lyricController setBulk:YES];
		helper = [iTunesHelper sharediTunesHelper];
		[self setBulkDownloaderIsWorking:NO];
		
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
	[rootObjects removeAllObjects];
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
		else {
			// parent == nil, so this is a root object
			[rootObjects addObject:o];
		}
		
		[playlists addObject:o];
	}
	
	[playlistView reloadData];
}

-(void) windowDidLoad {
	[resultView setString:@"Select a playlist from the list on the left and click \"Go\" to fetch lyrics for the playlist."];
	
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
}

-(void)windowDidBecomeMain:(NSNotification *)notification {
	[self repopulatePlaylistView];
	[playlistView reloadData];
	
	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"Auto-expand playlist view"])
		[playlistView expandItem:nil expandChildren:YES];
}

-(void)showBulkDownloader {
	//
	// Initialize and fetch the list of playlists
	//
	/*	[playlists removeAllObjects];
	 */
	// [playlists addObject:@"[Selected tracks]"];
	//[self repopulatePlaylistView];
	
	[statusLabel setStringValue:@"Idle"];	
	[self setBulkDownloaderIsWorking:NO];
	[self showWindow:self];
    [self.window makeKeyAndOrderFront:self];
}

#pragma mark -
#pragma mark Worker and main methods

-(void)dirtyWorker:(NSMutableArray *)theTracks {
	NSString *trackTitle;
	int count = 0;
	
	if ([theTracks count] == 0) {
		[[NSAlert alertWithMessageText:@"The bulk downloader cannot start because the selected playlist is empty." defaultButton:@"OK" alternateButton:nil otherButton:nil informativeTextWithFormat:
		  @"If you are using the \"[Selected tracks]\" playlist, make sure the tracks are selected in iTunes."] runModal];
		[statusLabel setStringValue:@"Idle"];
		[goButton setTitle:@"Go"];
		return;
	}
	NSUInteger numberOfTracks = [theTracks count];
	
	// Set up the progress indicator
	[progressIndicator performSelectorOnMainThread:@selector(thrSetMaxValue:) withObject:[NSNumber numberWithInt:[theTracks count]] waitUntilDone:YES];
	[progressIndicator performSelectorOnMainThread:@selector(thrSetMinValue:) withObject:[NSNumber numberWithInt:0] waitUntilDone:YES];
	[progressIndicator performSelectorOnMainThread:@selector(thrSetCurrentValue:) withObject:[NSNumber numberWithInt:0] waitUntilDone:YES];
	
	// Used to track some stats
	int set_lyrics = 0;
	int had_lyrics = 0;
	int lyrics_not_found = 0;
	int errors_in_a_row = 0; // Used to abort when things appear to be going wrong
	
	for (iTunesTrack *track in theTracks) {
		count++;
		[statusLabel setStringValue:[NSString stringWithFormat:@"Processing... %d/%u", count, numberOfTracks]];
		
		if ([thread isCancelled]) {
			goto restore_settings; 	// We can't just break as that would display the window with stats, etc. The user *closed* the window,
									// it shouldn't just pop open again.
		}
		
		[progressIndicator performSelectorOnMainThread:@selector(thrIncrementBy:) withObject:[NSNumber numberWithDouble:1.0] waitUntilDone:YES];
		
		// Ugly check to make sure things won't crash soon...
		@try { 
			if (!track || ![track exists])
				continue;
			
			[track lyrics]; [track name]; [track artist];
		} 
		@catch (NSException *e) { continue; }
		
		@try {
			trackTitle = [NSString stringWithFormat:@" %@ - %@", [track artist], [track name]];
			
			[self progressUpdateWithType:LyricusStartingWorkType andString:trackTitle];
			
			if ([[track lyrics] length] > 8) { 
				[self progressUpdateWithType:LyricusFoundType andString:trackTitle];
				had_lyrics++;
				// DON'T update errors_in_a_row since we don't know if searching would have worked or not
				continue;
			}
		} @catch (NSException *e) { continue; }
		
		NSError *err = nil; // Ignored
		NSString *lyrics = [lyricController fetchLyricsForTrack:[track name] byArtist:[track artist] error:&err];
		if (lyrics) {
			@try { // Scripting bridge seems to be a bit unstable
				[track setLyrics:lyrics];
				
				[self progressUpdateWithType:LyricusFoundType andString:trackTitle];
				
			} 
			@catch (NSException *e) { continue; }
			
			set_lyrics++;
			errors_in_a_row = 0;
		}
		else if (err == nil) {
			lyrics_not_found++;
			errors_in_a_row = 0;
			
			[self progressUpdateWithType:LyricusNotFoundType andString:trackTitle];
		}
        else {
			errors_in_a_row++;
			lyrics_not_found++;
			[self progressUpdateWithType:LyricusNotFoundType andString:trackTitle];
			
		}
		
		if (errors_in_a_row >= 10) {
			[thread cancel];
			[[NSAlert alertWithMessageText:@"The bulk downloader aborted due to encountering too many errors." defaultButton:@"OK" alternateButton:nil otherButton:nil informativeTextWithFormat:@"Make sure that your internet connection is active. If possible, try enabling multiple sites in the Lyricus preferences."] runModal];
			goto restore_settings;
		}
		
	}
	
	trackTitle = [NSString stringWithFormat:@"\nFound and set lyrics for %d tracks\n%d tracks already had lyrics\nCouldn't find lyrics for %d tracks\n",
				  set_lyrics, had_lyrics, lyrics_not_found];
	[resultView performSelectorOnMainThread:@selector(appendString:) withObject:trackTitle waitUntilDone:YES];
	
	[self showBulkDownloader];
	[[NSAlert alertWithMessageText:@"Bulk download complete" defaultButton:@"OK" alternateButton:nil otherButton:nil informativeTextWithFormat:@"Finished downloading lyrics for %d tracks.", count]
	 runModal];
	
restore_settings:
	[goButton setTitle:@"Go"];
	[statusLabel setStringValue:@"Idle"];
	
	//	[goButton setEnabled:YES];
	[progressIndicator performSelectorOnMainThread:@selector(thrSetCurrentValue:) withObject:[NSNumber numberWithInt:0] waitUntilDone:YES];
	
	// NO more code goes here!
}

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
	
	NSString *plName = [[playlistView itemAtRow:[playlistView selectedRow]] name];

	NSArray *tracks;	
	
	if ([plName isEqualToString:@"[Selected tracks]"]) {
		tracks = [helper getSelectedTracks];
	}
	else
		tracks = [helper getTracksForPlaylist:plName];
	
	if (tracks == nil) {
		// Appears to happen only when iTunes is not running
		[[NSAlert alertWithMessageText:@"The bulk downloader cannot start because no tracks were found." defaultButton:@"OK" alternateButton:nil otherButton:nil informativeTextWithFormat:@"Make sure that iTunes is running and that there are tracks in the chosen playlist."] runModal];
		[self setBulkDownloaderIsWorking:NO];
		[goButton setTitle:@"Go"];
		[statusLabel setStringValue:@"Idle"];
		
		//		[goButton setEnabled:YES];
		return;
	}
	
	if ([tracks count] > 40) {
		NSInteger choice = [[NSAlert alertWithMessageText:[NSString stringWithFormat:@"There are %d tracks to process. Do you want to continue?", [tracks count]] defaultButton:@"Continue" alternateButton:@"Abort" otherButton:nil informativeTextWithFormat:@"This action may tike some time."] runModal];
		
		if (choice == NSAlertAlternateReturn) {
			[self setBulkDownloaderIsWorking:NO];
			[statusLabel setStringValue:@"Idle"];
			[goButton setTitle:@"Go"];
			return;
		}
	}
	
	// Clear the view, in case this isn't the first run
	[resultView setString:@""];
	[resultView appendString:[NSString stringWithFormat:@"Starting lyric download for %d tracks\n\n", [tracks count]]];	
	
	[self setBulkDownloaderIsWorking:YES];
	// Start the worker thread
	thread = [[NSThread alloc] initWithTarget:self selector:@selector(dirtyWorker:) object:tracks];
	[thread start];
}

@end
