//
// This file is part of Lyricus.
// Copyright (c) 2008-2011, Thomas Backman <serenity@exscape.org>
// All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "iTunesHelper.h"

@interface LyricSearchController : NSWindowController {
    IBOutlet NSTextField *searchTextField;
    IBOutlet NSTableView *trackTableView;
    IBOutlet NSTextView *lyricTextView;
    IBOutlet NSWindow *indexProgressWindow;
    IBOutlet NSProgressIndicator *indexProgressIndicator;
    IBOutlet NSButton *abortButton;
    NSThread *thread;
    iTunesHelper *helper;
    NSMutableArray *trackData;
    NSMutableArray *matches;
}

-(void) showLyricSearch:(id) sender;
-(IBAction) updateTrackIndex:(id) sender;
-(IBAction) abortIndexing:(id) sender;

@end
