//
// This file is part of Lyricus.
// Copyright (c) 2008-2011, Thomas Backman <serenity@exscape.org>
// This software is distributed under the terms of the MIT license. For details, see license.txt.
//

#import <Cocoa/Cocoa.h>
#import "iTunesHelper.h"
#import "WelcomeScreen.h"

@interface LyricSearchController : NSWindowController {
    IBOutlet NSTextField *searchTextField;
    IBOutlet NSTableView *trackTableView;
    IBOutlet NSTextView *lyricTextView;
    IBOutlet NSWindow *indexProgressWindow;
    IBOutlet NSProgressIndicator *indexProgressIndicator;
    IBOutlet NSButton *abortIndexingButton;
    NSThread *thread;
    iTunesHelper *helper;
    NSMutableArray *trackData;
    NSMutableArray *matches;
	
	WelcomeScreen *welcomeScreen;
	
	NSRect userStateFrame;
	BOOL zoomButtonReturnToUserState;
	BOOL zoomButtonUsedFirstTime;
}

-(void) showLyricSearch:(id) sender;
-(IBAction) updateTrackIndex:(id) sender;
-(IBAction) abortIndexing:(id) sender;

@end
