//
//  LyricSearchController.m
//  Lyricreader
//
//  Created by Thomas Backman on 3/18/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "LyricSearchController.h"

@implementation LyricSearchController

- (id)initWithWindow:(NSWindow *)inWindow
{
    self = [super initWithWindow:inWindow];
    if (self) {
        helper = [iTunesHelper sharediTunesHelper];
        matches = [[NSMutableArray alloc] init];
        trackData = [NSArray arrayWithContentsOfFile:[@"~/Library/Application Support/Lyricus/lyricsearch.cache" stringByExpandingTildeInPath]];
        if (!trackData) {
            [[NSAlert alertWithMessageText:@"You need to create a track index." defaultButton:@"OK" alternateButton:nil otherButton:nil informativeTextWithFormat:@"To start using the lyric search window, update your index."] runModal];
        }
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(trackSelected:) name:@"NSTableViewSelectionDidChangeNotification" object:nil];
    }
    
    return self;
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
  //  NSLog(@"%@", NSStringFromRect(cur));
    

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
}

- (id)tableView:(NSTableView *)aTableView
objectValueForTableColumn:(NSTableColumn *)aTableColumn
            row:(NSInteger)rowIndex {
    if (rowIndex < [matches count]) {
        NSDictionary *match = [matches objectAtIndex:rowIndex];
        return [NSString stringWithFormat:@"%@ - %@", [match objectForKey:@"artist"], [match objectForKey:@"name"]];
    }

    else
        return nil;
}
- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView {
    return [matches count];
}

-(IBAction) updateTrackIndex:(id) sender {
    [[NSAlert alertWithMessageText:@"Starting index update" defaultButton:@"OK" alternateButton:nil otherButton:nil informativeTextWithFormat:@"This may take a few minutes."] runModal];
    
    NSMutableArray *dataArray = [[NSMutableArray alloc] init];

	if (![helper initiTunes])
		return;
	
	@try {
		SBElementArray *pls = [[[[helper iTunesReference] sources] objectAtIndex:0] playlists];
		
        int tmp = 0;
		for (iTunesPlaylist *pl in pls) {
            if ([[pl name] isEqualToString:@"Music"]) {
                for (iTunesTrack *t in [pl tracks]) {
                    [dataArray addObject:[NSDictionary dictionaryWithObjectsAndKeys:[t artist], @"artist", [t name], @"name", [t lyrics], @"lyrics", nil]];
                    if (tmp++ % 50) 
                        NSLog(@".");
                    if (tmp % 500)
                        NSLog(@"\n");
                }
            }
        }
    }
	@catch (NSException *e) { return; }
	
    NSFileManager *fm = [NSFileManager defaultManager];
    [fm createDirectoryAtPath:[@"~/Library/Application Support/Lyricus" stringByExpandingTildeInPath] withIntermediateDirectories:YES attributes:nil error:nil];
    [dataArray writeToFile:[@"~/Library/Application Support/Lyricus/lyricsearch.cache" stringByExpandingTildeInPath] atomically:YES];    
}

-(void) showLyricSearch:(id) sender {
    [window makeKeyAndOrderFront:sender];
}

-(IBAction) updateTracklist:(id) sender {
    [[NSAlert alertWithMessageText:@"Test message" defaultButton:@"OK" alternateButton:nil otherButton:nil informativeTextWithFormat:@"Test"] runModal];
}

- (void)dealloc
{
    [super dealloc];
}

- (void)windowDidLoad
{
    [super windowDidLoad];
    
    // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
}

@end
