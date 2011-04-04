//
// This file is part of Lyricus.
// Copyright (c) 2008-2011, Thomas Backman <serenity@exscape.org>
// This software is distributed under the terms of the MIT license. For details, see license.txt.
//

#import "LyricSearchController.h"
#import "NSProgressIndicator+ThreadSafeUpdating.h"

@implementation LyricSearchController

//#define kReverseWelcomeText @"text text text text text text text text snart text end"
#define kReverseWelcomeText @"This window allows you to search for words in a song text, and find a list of songs that contain them.\n\n" \
	@"There are three parts to this window.\n" \
	@"The top field is the search field, where you enter lyrics to search for. Results appear as you type.\n" \
	@"The middle control is the results list; song titles that match the lyric in the above field will show up here.\n" \
	@"The large text area displays the entire lyrics to the song selected in the above list, and automatically highlights your search terms."

- (id)initWithWindow:(NSWindow *)inWindow {
    self = [super initWithWindow:inWindow];
    if (self) {
        helper = [iTunesHelper sharediTunesHelper];
        matches = [[NSMutableArray alloc] init];
        trackData = [NSMutableArray arrayWithContentsOfFile:[@"~/Library/Caches/org.exscape.Lyricus/lyricsearch.cache" stringByExpandingTildeInPath]];
		
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(trackSelected:) name:@"NSTableViewSelectionDidChangeNotification" object:nil];
		
		[[NSNotificationCenter defaultCenter] addObserver: self selector: @selector(didChangeScreenParameters:)
													 name: NSApplicationDidChangeScreenParametersNotification object: nil];
    }
    return self;
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

-(void) windowDidLoad {
    [super windowDidLoad];
	
	NSButton *zoomButton = [self.window standardWindowButton: NSWindowZoomButton];
	[zoomButton setEnabled: YES];
	[zoomButton setTarget: self];
	[zoomButton setAction: @selector(zoomButtonClicked:)];

	if (! [[NSUserDefaults standardUserDefaults] boolForKey:@"Hide reverse lyric search welcome screen"]) {
		welcomeScreen = [[WelcomeScreen alloc] initWithText:kReverseWelcomeText owningWindow:self.window delegate:self];
		[welcomeScreen showWindow:self];
	}
    
    if (!trackData) {
		[self updateTrackIndex:self];
		if (welcomeScreen != nil && ! [[NSUserDefaults standardUserDefaults] boolForKey:@"Hide reverse lyric search welcome screen"])
		{
			[welcomeScreen showWindow:self];
		}
    }
    else {
        // Check index age
        
        NSInteger currentTimestamp = [[NSDate date] timeIntervalSince1970];
        NSInteger indexTimestamp = [[NSUserDefaults standardUserDefaults] integerForKey:@"Lyricus index update time"];
        int diff = (currentTimestamp - indexTimestamp);
        
		/* Warn if older than one week */
        if (diff > 86400*7 && ! [[NSUserDefaults standardUserDefaults] boolForKey:@"Disable cache warning"]) {
            if (
                [[NSAlert alertWithMessageText:@"The lyric index is out-of-date." defaultButton:@"Update Index Now" alternateButton:@"Ignore" otherButton:nil informativeTextWithFormat:@"Your lyric index is more than one week old. If you have added, removed or changed tracks or lyrics since then, the results will be out-of date. Please update your index."] runModal]
                == NSAlertDefaultReturn) {
                [self updateTrackIndex:self];
            }
        }
    }
	
	[trackTableView setTarget:self];
	[trackTableView setDoubleAction:@selector(doubleClick:)];
	
	// Dragging source
	[trackTableView registerForDraggedTypes:[NSArray arrayWithObject:kLyricusTrackDragType]];
	
	// Dragging destination
	[lyricTextView registerForDraggedTypes:[NSArray arrayWithObject:kLyricusTrackDragType]];
}

-(void) zoomButtonClicked:(id)sender {
#warning FIXME
}

// LyricTextView delegate method
-(BOOL)dragReceivedWithTrack:(NSDictionary *)track {
	NSString *artist = [track objectForKey:@"artist"];
	NSString *name = [track objectForKey:@"name"];
	
	iTunesTrack *matchedTrack = [helper getTrackForTitle:name byArtist:artist];
	if (matchedTrack != nil) {
		NSString *lyrics = nil;
		@try {
			 lyrics = [helper getLyricsForTrack:matchedTrack];
			[lyricTextView setString:lyrics];
		}
		@catch (NSException *e) { return NO; }
		
		// Clear the display and show the track in the results box
		[searchTextField setStringValue:@""];
		[matches removeAllObjects];
		[matches addObject:[NSDictionary dictionaryWithObjectsAndKeys:artist, @"artist", name, @"name", lyrics, @"lyrics", nil]];
		[trackTableView reloadData];
	}
	else
		return NO;
		
	return YES;
}


-(BOOL)tableView:(NSTableView *)tableView writeRowsWithIndexes:(NSIndexSet *)rowIndexes toPasteboard:(NSPasteboard *)pboard {
	// Since only a single row can be selected, and there is
	// little reason to change that in the future, only copy one row.
	NSDictionary *dict = [matches objectAtIndex:[rowIndexes firstIndex]];
	
	NSData *data = [NSKeyedArchiver archivedDataWithRootObject:dict];
	[pboard declareTypes:[NSArray arrayWithObject:kLyricusTrackDragType] owner:self];
	[pboard setData:data forType:kLyricusTrackDragType];
	
	return YES;
}


-(void) userDidCloseWelcomeScreenWithDontShowAgain:(BOOL)state {
	if (state == YES) {
		[[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"Hide reverse lyric search welcome screen"];
	}
}

-(void) doubleClick:(id)sender {
	if (matches == nil || [trackTableView clickedRow] >= [matches count])
		return;

	NSString *artist = [[matches objectAtIndex:[trackTableView clickedRow]] objectForKey:@"artist"];
	NSString *name = [[matches objectAtIndex:[trackTableView clickedRow]] objectForKey:@"name"];

	iTunesTrack *track = [helper getTrackForTitle:name byArtist:artist];
	[track playOnce:NO];
}

- (void)trackSelected:(NSNotification *)note { 	
	// This is needed to prevent selection in the batch downloader from affecting us!
	if ([note object] != trackTableView)
		return;
	
    NSInteger index = [trackTableView selectedRow];
    if (index >= [matches count]) {
        return;
    }
    
    NSDictionary *track = [matches objectAtIndex:index];
    
    NSString *lyrics = [track objectForKey:@"lyrics"];
    [lyricTextView setString:lyrics];

    // Highlight and select the search string
	NSString *searchString = [searchTextField stringValue];
	if (searchString && ![searchString isEqualToString:@""]) {
		// We need this check to make sure that we don't set the track programatically, then try to fetch the search terms
		NSRange range = [lyrics rangeOfString:[searchTextField stringValue] options:NSCaseInsensitiveSearch | NSDiacriticInsensitiveSearch];
		[lyricTextView scrollRangeToVisible:range];
		[self.window makeFirstResponder:lyricTextView];
		[lyricTextView setSelectedRange:range];
		[lyricTextView showFindIndicatorForRange:range];
	}
}

- (void)controlTextDidChange:(NSNotification *)nd {
    NSString *searchString = [searchTextField stringValue];
    [matches removeAllObjects];
    
    if ([searchString length] >= 2) {
		NSPredicate *predicate = [NSPredicate predicateWithFormat:@"lyrics CONTAINS[cd] %@", searchString];
		matches = [trackData mutableCopy];
		[matches filterUsingPredicate:predicate];
		[trackTableView reloadData];
    }
    else {
        // Clear the track list if the search string is too short (or nonexistent)
        [matches removeAllObjects];
        [trackTableView reloadData];
    }
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView {
    return [matches count];
}

- (id)tableView:(NSTableView *)aTableView
objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex {
    if (rowIndex < [matches count]) {
        NSDictionary *match = [matches objectAtIndex:rowIndex];
        return [NSString stringWithFormat:@"%@ - %@", [match objectForKey:@"artist"], [match objectForKey:@"name"]];
    }

    else
        return nil;
}

- (BOOL)windowShouldClose:(id)sender {
	// No need to confirm if nothing is running
	if (![thread isExecuting]) {
		[[self window] orderOut:self];
		return YES;
	}
	
	// This is probably never reached, due to the close button being disabled when
	// the indexing process is running.
	
	if ([[NSAlert alertWithMessageText:@"Do you want to abort the indexing process?" defaultButton:@"Yes, abort" alternateButton:@"No, keep going" otherButton:nil informativeTextWithFormat:@"This process needs to finish before this window is usable."] runModal] 
        == NSAlertDefaultReturn) {
		// Yes, abort:
		[thread cancel];
		[[self window] orderOut:self];
		return YES;
	}
	else {
		// No, don't abort
		return NO;
	}
}

-(void)threadWorker:(id)unused {
	if (![helper initiTunes])
		return;

	NSMutableArray *tmpArray = [[NSMutableArray alloc] init];
    
	@try {        
		NSArray *tracks = [helper getTracksForLibraryPlaylist];

		// Set up the progress indicator
		[indexProgressIndicator performSelectorOnMainThread:@selector(thrSetMaxValue:) withObject:[NSNumber numberWithInt:[tracks count]] waitUntilDone:YES];
		[indexProgressIndicator performSelectorOnMainThread:@selector(thrSetMinValue:) withObject:[NSNumber numberWithInt:0] waitUntilDone:YES];
		[indexProgressIndicator performSelectorOnMainThread:@selector(thrSetCurrentValue:) withObject:[NSNumber numberWithInt:0] waitUntilDone:YES];
		
		for (iTunesTrack *t in tracks) {
			[tmpArray addObject:[NSDictionary dictionaryWithObjectsAndKeys:[t artist], @"artist", [t name], @"name", [t lyrics], @"lyrics", nil]];
			
			[indexProgressIndicator performSelectorOnMainThread:@selector(thrIncrementBy:) withObject:[NSNumber numberWithDouble:1.0] waitUntilDone:YES];
			
			if ([thread isCancelled]) {
				goto indexing_cancelled;
			}
        }
    }
	@catch (NSException *e) { return; }
	
    NSFileManager *fm = [NSFileManager defaultManager];
    
    [fm createDirectoryAtPath:[@"~/Library/Caches/org.exscape.Lyricus" stringByExpandingTildeInPath] withIntermediateDirectories:YES attributes:nil error:nil];
    [fm removeItemAtPath:[@"~/Library/Caches/org.exscape.Lyricus/lyricsearch.cache" stringByExpandingTildeInPath] error:nil];
    
    if ([tmpArray writeToFile:[@"~/Library/Caches/org.exscape.Lyricus/lyricsearch.cache" stringByExpandingTildeInPath] atomically:YES]) {
		NSInteger timestamp = [[NSDate date] timeIntervalSince1970];
		[[NSUserDefaults standardUserDefaults] setInteger:timestamp forKey:@"Lyricus index update time"];        
    }
    else {
        [[NSAlert alertWithMessageText:@"Unable to create index!" defaultButton:@"OK" alternateButton:nil otherButton:nil informativeTextWithFormat:@" Make sure that the %@ directory is writable.", [@"~/Library/Caches/org.exscape.Lyricus" stringByExpandingTildeInPath]] runModal];
    }
	
	// If successful, replace the current index.
	trackData = [tmpArray copy];
    
indexing_cancelled:
    
    [NSApp endSheet:indexProgressWindow];
}

-(IBAction) abortIndexing:(id) sender {
    if (thread != nil) {
        if ([thread isExecuting]) {
            [thread cancel];
        }
    }
}

-(IBAction) updateTrackIndex:(id) sender {
    [NSApp beginSheet:indexProgressWindow modalForWindow:self.window modalDelegate:self 
       didEndSelector:@selector(didEndSheet:returnCode:contextInfo:) contextInfo:nil];
    
    thread = [[NSThread alloc] initWithTarget:self selector:@selector(threadWorker:) object:nil];
	[thread start];
    
    // Don't allow abort if no previous index exists
    NSFileManager *fm = [NSFileManager defaultManager];
    if (![fm fileExistsAtPath:[@"~/Library/Caches/org.exscape.Lyricus/lyricsearch.cache" stringByExpandingTildeInPath]]) {
        [abortIndexingButton setEnabled:NO];
    }
    else
        [abortIndexingButton setEnabled:YES];
}

- (void)didEndSheet:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo {
	if (sheet == indexProgressWindow) {
		[indexProgressWindow orderOut:nil];
    }
}

-(void) showLyricSearch:(id) sender {
	[[NSApplication sharedApplication] activateIgnoringOtherApps:YES];
    [self.window makeKeyAndOrderFront:sender];
	if (! [[NSUserDefaults standardUserDefaults] boolForKey:@"Hide reverse lyric search welcome screen"]) {
		[welcomeScreen showWindow:self];
	}

}

- (void)dealloc {
    [super dealloc];
}

@end
