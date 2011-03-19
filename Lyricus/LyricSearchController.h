//
//  LyricSearchController.h
//  Lyricreader
//
//  Created by Thomas Backman on 3/18/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
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
    IBOutlet NSTextField *labelUpdating;
    NSThread *thread;
    iTunesHelper *helper;
    NSMutableArray *trackData;
    NSMutableArray *matches;
@private
    
}

-(void) showLyricSearch:(id) sender;
-(IBAction) updateTracklist:(id) sender;
-(IBAction) updateTrackIndex:(id) sender;
-(IBAction) abortIndexing:(id) sender;

@end
