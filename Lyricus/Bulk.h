
//
// This file is part of Lyricus.
// Copyright (c) 2008, Thomas Backman <serenity@exscape.org>
// All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "LyricController.h"
#import "iTunesHelper.h"

@interface Bulk : NSWindowController <NSWindowDelegate, NSTableViewDelegate> {
	
	NSMutableArray *playlists;
	LyricController *lyricController;
	iTunesHelper *helper;
	NSThread *thread;
	
	IBOutlet NSTableView *playlistView;
	IBOutlet NSTextView *resultView;
	IBOutlet NSProgressIndicator *progressIndicator;
	IBOutlet NSButton *goButton;
}

-(IBAction) goButtonClicked:(id)sender;
-(void)showBulkDownloader;

@end
