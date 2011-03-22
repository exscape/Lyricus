
//
// This file is part of Lyricus.
// Copyright (c) 2008, Thomas Backman <serenity@exscape.org>
// All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "LyricFetcher.h"
#import "iTunesHelper.h"

@interface Bulk : NSWindowController <NSWindowDelegate, NSTableViewDelegate> {
	
	NSMutableArray *playlists;
	LyricFetcher *lyricController;
	iTunesHelper *helper;
	NSThread *thread;
	
	IBOutlet NSTableView *playlistView;
	IBOutlet NSTextView *resultView;
	IBOutlet NSProgressIndicator *progressIndicator;
	IBOutlet NSButton *goButton;
	
	BOOL bulkDownloaderIsWorking;
}

-(IBAction) goButtonClicked:(id)sender;
-(void)showBulkDownloader;

@property BOOL bulkDownloaderIsWorking;

@end


