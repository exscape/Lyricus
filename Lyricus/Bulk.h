//
// This file is part of Lyricus.
// Copyright (c) 2008-2011, Thomas Backman <serenity@exscape.org>
// This software is distributed under the terms of the MIT license. For details, see license.txt.
//

#import <Cocoa/Cocoa.h>
#import "LyricFetcher.h"
#import "iTunesHelper.h"

@interface Bulk : NSWindowController <NSWindowDelegate, NSOutlineViewDelegate, NSOutlineViewDataSource, NSTableViewDelegate, NSTableViewDataSource> {
	NSMutableArray *playlists;
	NSMutableArray *tracks;
	LyricFetcher *lyricController;
	iTunesHelper *helper;
	NSThread *thread;
	
	IBOutlet NSProgressIndicator *progressIndicator;
	IBOutlet NSButton *goButton;
	IBOutlet NSTextField *statusLabel;
	
	BOOL bulkDownloaderIsWorking;
	
	IBOutlet NSOutlineView *playlistView;
	NSMutableArray *rootObjects;
	
	IBOutlet NSTableView *trackView;
}

-(IBAction) goButtonClicked:(id)sender;
-(void)showBulkDownloader;
-(void)loadTracks;
//-(void)progressUpdateWithType:(int) type andString: (NSString *)string;

@property BOOL bulkDownloaderIsWorking;

@end


