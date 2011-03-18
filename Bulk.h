
//
// This file is part of Lyricus.
// Copyright (c) 2008, Thomas Backman <serenity@exscape.org>
// All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "LyricController.h"
#import "iTunesHelper.h"

@interface Bulk : NSObject <NSWindowDelegate, NSTableViewDelegate> {
	
	NSMutableArray *playlists;
	LyricController *lyricController;
	iTunesHelper *helper;
	NSThread *thread;
	
	IBOutlet NSTableView *playlistView;
	IBOutlet NSTextView *resultView;
	IBOutlet NSWindow *bulkWindow;
	IBOutlet NSProgressIndicator *progressIndicator;
	IBOutlet NSButton *goButton;
	BOOL bulkDownloaderOpened;	
}

@property BOOL bulkDownloaderOpened;

-(void)focusWindow;
-(IBAction) goButtonClicked:(id)sender;
-(void)openBulkDownloader;

@end
