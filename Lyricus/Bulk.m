
//
// This file is part of Lyricus.
// Copyright (c) 2008, Thomas Backman <serenity@exscape.org>
// All rights reserved.
//

#import "Bulk.h"
#import "NSTextView+AppendString.h"
#import "NSProgressIndicator+ThreadSafeUpdating.h"

@implementation Bulk

@synthesize bulkDownloaderIsWorking;

#define ProgressUpdateFound(x) if (bulkDownloaderIsWorking) { [resultView appendImageNamed:@"icon_found.tif"]; [resultView performSelectorOnMainThread:@selector(appendString:) withObject:x waitUntilDone:YES]; }
#define ProgressUpdateNotFound(x) if (bulkDownloaderIsWorking) { [resultView appendImageNamed:@"icon_notfound.tif"]; [resultView performSelectorOnMainThread:@selector(appendString:) withObject:x waitUntilDone:YES]; }


#pragma mark -
#pragma mark Init stuff

-(id) initWithWindowNibName:(NSString *)windowNibName {
    self = [super initWithWindowNibName:windowNibName];
	if (self) {
		playlists = [[NSMutableArray alloc] init];
		lyricController = [[LyricFetcher alloc] init];
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
		//		ProgressUpdate(@"\nBulk download aborted");
		return YES;
	}
	else {
		// No, don't abort
		return NO;
	}
}

-(void) windowDidLoad {
	[self showBulkDownloader];
	[resultView setString:@"Select a playlist from the list on the left and click \"Go\" to fetch lyrics for the playlist."];
}

-(void)showBulkDownloader {
	//
	// Initialize and fetch the list of playlists
	//
	[playlists removeAllObjects];
	[playlists addObject:@"[Selected tracks]"];
	for (iTunesPlaylist *pl in [helper getAllPlaylists]) {
		[playlists addObject:[pl name]];
	}

    [playlistView reloadData];
	
	[self setBulkDownloaderIsWorking:NO];

	[self showWindow:self];
    [self.window makeKeyAndOrderFront:self];
}

#pragma mark -
#pragma mark Worker and main methods

-(void)dirtyWorker:(NSMutableArray *)theTracks {
	NSString *trackTitle;
	int count = 0;
	
	int totalCount = [theTracks count];
	if ([theTracks count] == 0) {
		[[NSAlert alertWithMessageText:@"The selected playlist is empty." defaultButton:@"OK" alternateButton:nil otherButton:nil informativeTextWithFormat:
		  @"If you are using the \"[Selected tracks]\" playlist, make sure the tracks are selected in iTunes."] runModal];
		[goButton setTitle:@"Go"];
		return;
	}

	// Set up the progress indicator
	[progressIndicator performSelectorOnMainThread:@selector(thrSetMaxValue:) withObject:[NSNumber numberWithInt:[theTracks count]] waitUntilDone:YES];
	[progressIndicator performSelectorOnMainThread:@selector(thrSetMinValue:) withObject:[NSNumber numberWithInt:0] waitUntilDone:YES];
	[progressIndicator performSelectorOnMainThread:@selector(thrSetCurrentValue:) withObject:[NSNumber numberWithInt:0] waitUntilDone:YES];
	
	// Used to track some stats
	int set_lyrics = 0;
	int had_lyrics = 0;
	int lyrics_not_found = 0;
	
	for (iTunesTrack *track in theTracks) {
		if ([thread isCancelled]) {
			goto restore_settings; 	// We can't just break as that would display the window with stats, etc. The user *closed* the window,
									// it shouldn't just pop open again.
		}
		
		count++;
		if (count % 10 == 0) { // Print stats every 10 tracks
							   //			trackTitle = [NSString stringWithFormat:@"Working on track %d out of %d (%.2f%%)\n", count, totalCount, ( (float)count / totalCount)*100];
			//			ProgressUpdate(str);
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
			trackTitle = [NSString stringWithFormat:@" %@ - %@\n", [track artist], [track name]];
			
			if ([[track lyrics] length] > 8) { 
				if ([[NSUserDefaults standardUserDefaults] boolForKey:@"Verbose_bulk_downloader"]) {

					ProgressUpdateFound(trackTitle);
				}
				had_lyrics++;
				continue;
			}
		} @catch (NSException *e) { continue; }
		
		NSError *err = nil; // Ignored
		NSString *lyrics = [lyricController fetchLyricsForTrack:[track name] byArtist:[track artist] error:&err];
		if (lyrics) {
			@try { // Scripting bridge seems to be a bit unstable
				set_lyrics++;
				[track setLyrics:lyrics];
	
				ProgressUpdateNotFound(trackTitle);

			} 
			@catch (NSException *e) { set_lyrics--; }
		}
		else if (err == nil) {
			lyrics_not_found++;
			
			ProgressUpdateNotFound(trackTitle);
		}
        else {
			lyrics_not_found++;
			[resultView appendImageNamed:@"icon_notfound.tif"];
			ProgressUpdateNotFound(trackTitle);
		}
		
	}
	
	trackTitle = [NSString stringWithFormat:@"\nFound and set lyrics for %d tracks\n%d tracks already had lyrics\nCouldn't find lyrics for %d tracks\n",
					 set_lyrics, had_lyrics, lyrics_not_found];
	[resultView performSelectorOnMainThread:@selector(appendString:) withObject:trackTitle waitUntilDone:YES];
	//	ProgressUpdate(trackTitle);

	[self showBulkDownloader];
	[[NSAlert alertWithMessageText:@"Bulk download complete" defaultButton:@"OK" alternateButton:nil otherButton:nil informativeTextWithFormat:@"Finished downloading lyrics for %d tracks.", count]
	 runModal];
	
restore_settings:
	[goButton setTitle:@"Go"];

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
		//		ProgressUpdate(@"\nBulk download aborted");
		[self setBulkDownloaderIsWorking:NO];
		
		return;
	}
	[goButton setTitle:@"Stop"];
	
	[lyricController updateSiteList];
	
	NSInteger row = [playlistView selectedRow];
	
	NSString *plName = [playlists objectAtIndex:row];
	NSArray *tracks;	

	if ([plName isEqualToString:@"[Selected tracks]"]) {
		tracks = [helper getSelectedTracks];
	}
	else
		tracks = [helper getTracksForPlaylist:plName];
	
	if (tracks == nil) {
        if ([plName isEqualToString:@"[Selected tracks]"]) {
            [[NSAlert alertWithMessageText:@"No tracks found" defaultButton:@"OK" alternateButton:nil otherButton:nil informativeTextWithFormat:@"No tracks found for the playlist specified."] runModal];
        }
		[self setBulkDownloaderIsWorking:NO];
		[goButton setTitle:@"Go"];
		//		[goButton setEnabled:YES];
		return;
	}
	
	if ([tracks count] > 40) {
		NSInteger choice = [[NSAlert alertWithMessageText:[NSString stringWithFormat:@"There are %d tracks to process. Do you want to continue?", [tracks count]] defaultButton:@"Continue" alternateButton:@"Abort" otherButton:nil informativeTextWithFormat:@"This action may tike some time."] runModal];
		
		if (choice == NSAlertAlternateReturn) {
			[self setBulkDownloaderIsWorking:NO];
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

#pragma mark -
#pragma mark Table view stuff + finalize 

- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView {
	return (playlists != nil) ? [playlists count] : 0;
}

- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex {
	return [playlists objectAtIndex:rowIndex];
}

- (void)tableViewSelectionDidChange:(NSNotification *)aNotification {
	if ([playlistView selectedRow] >= 0)
		[goButton setEnabled:YES];
}

@end
