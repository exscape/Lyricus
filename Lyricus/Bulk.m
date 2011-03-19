
//
// This file is part of Lyricus.
// Copyright (c) 2008, Thomas Backman <serenity@exscape.org>
// All rights reserved.
//

#import "Bulk.h"
#import "NSTextView+AppendString.h"
#import "NSProgressIndicator+ThreadSafeUpdating.h"

@implementation Bulk

#pragma mark -
#pragma mark Init stuff

-(id) initWithWindowNibName:(NSString *)windowNibName {
    self = [super initWithWindowNibName:windowNibName];
	if (self) {
		playlists = [[NSMutableArray alloc] init];
		lyricController = [[LyricFetcher alloc] init];
		helper = [iTunesHelper sharediTunesHelper];
        
		return self;
	}
	return nil;
}

- (BOOL)windowShouldClose:(id)sender {
	// No need to confirm if nothing is running
	if (![thread isExecuting]) {
		return YES;
	}
	
	if ([[NSAlert alertWithMessageText:@"Do you want to abort the current operation??" defaultButton:@"Yes, abort" alternateButton:@"No, keep going" otherButton:nil informativeTextWithFormat:@"Lyrics downloaded so far will be saved."] runModal] == NSAlertDefaultReturn) {
		// Yes, abort:
		[thread cancel];
		return YES;
	}
	else {
		// No, don't abort
		return NO;
	}
}

-(void) windowDidLoad {
		[self showBulkDownloader];
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

    [self.window makeKeyAndOrderFront:self];
}

#pragma mark -
#pragma mark Helpers

#define ProgressUpdate(x) [resultView performSelectorOnMainThread:@selector(appendString:) withObject:x waitUntilDone:YES];

#pragma mark -
#pragma mark Worker and main methods

-(void)dirtyWorker:(NSMutableArray *)theTracks {
	// Turn off loading messages, since they'll show up in the lyric window otherwise... Ugh, ugly.
	BOOL oldSetting = [[NSUserDefaults standardUserDefaults] boolForKey:@"Show loading messages"];
	[[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"Show loading messages"];
	NSString *str;
	int count = 0;
	
	int totalCount = [theTracks count];
	if ([theTracks count] == 0) {
		[[NSAlert alertWithMessageText:@"The selected playlist is empty." defaultButton:@"OK" alternateButton:nil otherButton:nil informativeTextWithFormat:
		  @"If you are using the \"[Selected tracks]\" playlist, make sure the tracks are selected in iTunes."] runModal];
		[goButton setEnabled:YES];
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
			str = [NSString stringWithFormat:@"Working on track %d out of %d (%.2f%%)\n", count, totalCount, ( (float)count / totalCount)*100];
			ProgressUpdate(str);
		}		
		
		[progressIndicator performSelectorOnMainThread:@selector(thrIncrementBy:) withObject:[NSNumber numberWithDouble:1.0] waitUntilDone:YES];
		
		// Ugly check to make sure things won't crash soon...
		@try { 
			if (!track || ![track exists])
				continue;
	
			[track lyrics]; [track name]; [track artist];
		} 
		@catch (NSException *e) { continue; }

		if ([[NSUserDefaults standardUserDefaults] boolForKey:@"Verbose_bulk_downloader"]) {
			NSString *tmp = [NSString stringWithFormat:@">> %@ - %@\n", [track artist], [track name]];
			ProgressUpdate(tmp);
		}		
		
		@try {
			if ([[track lyrics] length] > 8) { 
				if ([[NSUserDefaults standardUserDefaults] boolForKey:@"Verbose_bulk_downloader"]) {
					str = [NSString stringWithString:@"\talready had lyrics, skipping\n"];
					ProgressUpdate(str);
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
			} 
			@catch (NSException *e) { set_lyrics--; }
		}
		else if (err == nil) {
			lyrics_not_found++;
			str = [NSString stringWithFormat:@"No lyrics found for track %@ - %@\n", [track artist], [track name]];
			ProgressUpdate(str);
		}
        else {
			lyrics_not_found++;
			str = [NSString stringWithFormat:@"An error occured when trying to download lyrics for %@ - %@\n", [track artist], [track name]];
			ProgressUpdate(str);
		}
		
	}
	ProgressUpdate(@"\nAll done!\n");
	
	str = [NSString stringWithFormat:@"Found and set lyrics for %d tracks\n%d tracks already had lyrics\nCouldn't find lyrics for %d tracks\n",
					 set_lyrics, had_lyrics, lyrics_not_found];
	ProgressUpdate(str);

	[self showBulkDownloader];
	[[NSAlert alertWithMessageText:@"Bulk download complete" defaultButton:@"OK" alternateButton:nil otherButton:nil informativeTextWithFormat:@"Finished downloading lyrics for %d tracks.", count]
	 runModal];
	
restore_settings:
	[[NSUserDefaults standardUserDefaults] setBool:oldSetting forKey:@"Show loading messages"];
	[goButton setEnabled:YES];
	[progressIndicator performSelectorOnMainThread:@selector(thrSetCurrentValue:) withObject:[NSNumber numberWithInt:0] waitUntilDone:YES];

	// NO more code goes here!
}

-(IBAction)goButtonClicked:(id)sender {
	//
	// The user clicked "go", hopefully with a playlist to work on selected!
	//
	[lyricController updateSiteList];
	[goButton setEnabled:NO];
	NSInteger row;
	if ( (row = [playlistView selectedRow]) == -1) {
		// Mmm nope, no playlist selected.
		[[NSAlert alertWithMessageText:@"No playlist selected" defaultButton:@"OK" alternateButton:nil otherButton:nil informativeTextWithFormat:
		  @"You need to select a playlist containing the tracks to fetch lyrics for."] runModal];
		[goButton setEnabled:YES];
		return;
	}
	
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
		[goButton setEnabled:YES];
		return;
	}
	if ([tracks count] > 40) {
		NSInteger choice = [[NSAlert alertWithMessageText:[NSString stringWithFormat:@"There are %d tracks to process. Do you want to continue?", [tracks count]] defaultButton:@"Yes" alternateButton:@"No" otherButton:nil informativeTextWithFormat:@"This action may tike some time."] runModal];
		
		if (choice == 0) {
			[goButton setEnabled:YES];
			return;
		}
	}

	// Clear the view, in case this isn't the first run
	[resultView setString:@""];

	[resultView appendString:[NSString stringWithFormat:@"Starting lyric download for %d tracks\n\n", [tracks count]]];	
		
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

-(void)finalize {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[super finalize];
}

@end
