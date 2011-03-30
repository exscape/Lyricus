//
// This file is part of Lyricus.
// Copyright (c) 2008-2011, Thomas Backman <serenity@exscape.org>
// This software is distributed under the terms of the MIT license. For details, see license.txt.
//


#import "LyricSearchController.h"
#import "NSProgressIndicator+ThreadSafeUpdating.h"

@implementation LyricSearchController

- (id)initWithWindow:(NSWindow *)inWindow {
    self = [super initWithWindow:inWindow];
    if (self) {
        helper = [iTunesHelper sharediTunesHelper];
        matches = [[NSMutableArray alloc] init];
        trackData = [NSMutableArray arrayWithContentsOfFile:[@"~/Library/Caches/org.exscape.Lyricus/lyricsearch.cache" stringByExpandingTildeInPath]];
		
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(trackSelected:) name:@"NSTableViewSelectionDidChangeNotification" object:nil];
    }
    return self;
}

-(void) windowDidLoad {
    [super windowDidLoad];
    
    if (!trackData) {
        [[NSAlert alertWithMessageText:@"You need to create a track index to continue." defaultButton:@"Create index now" alternateButton:nil otherButton:nil informativeTextWithFormat:@"This function needs a track index to work. Click \"Create index now\" to start."] runModal];
        [self updateTrackIndex:self];
    }
    else {
        // Check index age
        
        NSInteger currentTimestamp = [[NSDate date] timeIntervalSince1970];
        NSInteger indexTimestamp = [[NSUserDefaults standardUserDefaults] integerForKey:@"Lyricus index update time"];
        int diff = (currentTimestamp - indexTimestamp);
        
		/* Warn if older than one week */
        if (diff > 86400*7 && ! [[NSUserDefaults standardUserDefaults] boolForKey:@"Disable cache warning"]) {
            if (
                [[NSAlert alertWithMessageText:@"The lyric index is out-of-date." defaultButton:@"Update index now" alternateButton:@"Ignore" otherButton:nil informativeTextWithFormat:@"Your lyric index is more than one week old. If you have added, removed or changed tracks or lyrics since then, the results will be out-of date. Please update your index."] runModal]
                == NSAlertDefaultReturn) {
                [self updateTrackIndex:self];
            }
        }
    }
    
}

- (void)trackSelected:(NSNotification *)note { 
    NSInteger index = [trackTableView selectedRow];
    if (index >= [matches count]) {
        return;
    }
    
    NSDictionary *track = [matches objectAtIndex:index];
    
    NSString *lyrics = [track objectForKey:@"lyrics"];
    [lyricTextView setString:lyrics];

    // Highlight and select the search string
    NSRange range = [lyrics rangeOfString:[searchTextField stringValue] options:NSCaseInsensitiveSearch | NSDiacriticInsensitiveSearch];
    [lyricTextView scrollRangeToVisible:range];
	[self.window makeFirstResponder:lyricTextView];
	[lyricTextView setSelectedRange:range];
    [lyricTextView showFindIndicatorForRange:range];

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
    [self.window makeKeyAndOrderFront:sender];
}

- (void)dealloc {
    [super dealloc];
}

@end
