//
//  LyricSearchController.m
//  Lyricreader
//
//  Created by Thomas Backman on 3/18/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "LyricSearchController.h"
#import "NSProgressIndicator+ThreadSafeUpdating.h"

@implementation LyricSearchController

- (id)initWithWindow:(NSWindow *)inWindow
{
    self = [super initWithWindow:inWindow];
    if (self) {
        helper = [iTunesHelper sharediTunesHelper];
        matches = [[NSMutableArray alloc] init];
        trackData = [NSArray arrayWithContentsOfFile:[@"~/Library/Application Support/Lyricus/lyricsearch.cache" stringByExpandingTildeInPath]];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(trackSelected:) name:@"NSTableViewSelectionDidChangeNotification" object:nil];
    }
    return self;
}

-(void) windowDidLoad {
    [super windowDidLoad];
    
    if (!trackData) {
        [[NSAlert alertWithMessageText:@"You need to create a track index." defaultButton:@"Create index now" alternateButton:nil otherButton:nil informativeTextWithFormat:@"This function needs a track index to work. Click \"Create index now\" to start."] runModal];
        [self updateTrackIndex:self];
    }
    else {
        // Check index age
        
        NSNumber *currentTimestamp = [NSNumber numberWithInt:(int)[[NSDate date] timeIntervalSince1970]];
        NSNumber *indexTimestamp = [[NSUserDefaults standardUserDefaults] valueForKey:@"Lyricus index update time"];
        int diff = ([currentTimestamp intValue] - [indexTimestamp intValue]);
        
        if (diff > 86400*7) { // 1 week
            if (
                [[NSAlert alertWithMessageText:@"Your index is old" defaultButton:@"Update index now" alternateButton:@"Ignore" otherButton:nil informativeTextWithFormat:@"Your lyric index is more than one week old. If you have added, removed or changed tracks or lyrics since then, the results will be out-of date. Please update your index."] runModal]
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
//    [lyricTextView setHidden:NO];
    
//    NSRect cur = [window frame];
    

    //[window setFrame:NSMakeRect(cur.origin.x, cur.origin.y, cur.size.width, 538) display:YES animate:NO];
}

- (void)controlTextDidChange:(NSNotification *)nd {
    NSString *searchString = [searchTextField stringValue];
    [matches removeAllObjects];
    
    if ([searchString length] >= 2) {
        for (NSDictionary *track in trackData) {
            // Case insensitive search
            if ([[[track objectForKey:@"lyrics"] lowercaseString] containsString:[searchString lowercaseString]]) {
                [matches addObject:track];
            }
            [trackTableView reloadData];
        }
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
	
	if ([[NSAlert alertWithMessageText:@"Abort indexing?" defaultButton:@"Yes, abort" alternateButton:@"No, keep going" otherButton:nil informativeTextWithFormat:@"Do you want to abort the indexing operation?"] runModal] 
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

    if (trackData == nil) {
        trackData = [[NSMutableArray alloc] init];
    }
    else {
        [trackData removeAllObjects];
    }

	@try {
		SBElementArray *pls = [[[[helper iTunesReference] sources] objectAtIndex:0] playlists];
        
        for (iTunesPlaylist *pl in pls) {
            if ([[pl name] isEqualToString:@"Music"]) {
                
                float start = (float)[[NSDate date] timeIntervalSince1970];
                long totalTracks = [[pl tracks] count];
                long currentTrack = 0;
                
                // Set up the progress indicator
                [indexProgressIndicator performSelectorOnMainThread:@selector(thrSetMaxValue:) withObject:[NSNumber numberWithInt:[[pl tracks] count]] waitUntilDone:YES];
                [indexProgressIndicator performSelectorOnMainThread:@selector(thrSetMinValue:) withObject:[NSNumber numberWithInt:0] waitUntilDone:YES];
                [indexProgressIndicator performSelectorOnMainThread:@selector(thrSetCurrentValue:) withObject:[NSNumber numberWithInt:0] waitUntilDone:YES];
                
                for (iTunesTrack *t in [pl tracks]) {
                    currentTrack++;
                    [trackData addObject:[NSDictionary dictionaryWithObjectsAndKeys:[t artist], @"artist", [t name], @"name", [t lyrics], @"lyrics", nil]];
                    
                    if (currentTrack % 25 == 0) {
                        // Update ETA
                        float now = (float)[[NSDate date] timeIntervalSince1970];
                        if (now - start > 3) { // Don't calculate progress too early
                            float totalTime = (now - start) / ((float)currentTrack / (float)totalTracks);
                            float timeRemaining = totalTime - (now - start);
                            [labelUpdating setStringValue:[NSString stringWithFormat:@"Updating lyric index... ETA: %.0f seconds", timeRemaining]];
                            
                        }
                    }
                    
                    [indexProgressIndicator performSelectorOnMainThread:@selector(thrIncrementBy:) withObject:[NSNumber numberWithDouble:1.0] waitUntilDone:YES];
                        
                    if ([thread isCancelled]) {
                        goto indexing_cancelled;
                    }
                }
            }
        }
    }
	@catch (NSException *e) { return; }
	
    NSFileManager *fm = [NSFileManager defaultManager];
    
    [fm createDirectoryAtPath:[@"~/Library/Application Support/Lyricus" stringByExpandingTildeInPath] withIntermediateDirectories:YES attributes:nil error:nil];
    [fm removeItemAtPath:[@"~/Library/Application Support/Lyricus/lyricsearch.cache" stringByExpandingTildeInPath] error:nil];
    
    if ([trackData writeToFile:[@"~/Library/Application Support/Lyricus/lyricsearch.cache" stringByExpandingTildeInPath] atomically:YES]) {
        
    NSNumber *timestamp = [NSNumber numberWithInt:(int)[[NSDate date] timeIntervalSince1970]];
    [[NSUserDefaults standardUserDefaults] setValue:timestamp forKey:@"Lyricus index update time"];
        
    }
    else {
        [[NSAlert alertWithMessageText:@"Unable to create index!" defaultButton:@"OK" alternateButton:nil otherButton:nil informativeTextWithFormat:@" Make sure that /Users/<your username>/Library/Application Support/Lyricus is writable."] runModal];
    }
    
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
    if (![fm fileExistsAtPath:[@"~/Library/Application Support/Lyricus/lyricsearch.cache" stringByExpandingTildeInPath]]) {
        [abortButton setEnabled:NO];
    }
    else
        [abortButton setEnabled:YES];
}



- (void)didEndSheet:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo {
	if (sheet == indexProgressWindow) {
		[indexProgressWindow orderOut:nil];
    }
}

-(void) showLyricSearch:(id) sender {
    [self.window makeKeyAndOrderFront:sender];
}

-(IBAction) updateTracklist:(id) sender {
    [[NSAlert alertWithMessageText:@"Test message" defaultButton:@"OK" alternateButton:nil otherButton:nil informativeTextWithFormat:@"Test"] runModal];
}

- (void)dealloc
{
    [super dealloc];
}

@end
