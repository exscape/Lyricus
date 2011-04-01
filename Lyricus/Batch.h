//
// This file is part of Lyricus.
// Copyright (c) 2008-2011, Thomas Backman <serenity@exscape.org>
// This software is distributed under the terms of the MIT license. For details, see license.txt.
//

#import <Cocoa/Cocoa.h>
#import "LyricFetcher.h"
#import "iTunesHelper.h"
#import "WelcomeScreen.h"

@interface Batch : NSWindowController <NSWindowDelegate, NSOutlineViewDelegate, NSOutlineViewDataSource, NSTableViewDelegate, NSTableViewDataSource> {
	NSMutableArray *playlists;
	NSMutableArray *tracks;
	LyricFetcher *lyricController;
	iTunesHelper *helper;
	NSThread *thread;
	
	IBOutlet NSProgressIndicator *progressIndicator;
	IBOutlet NSButton *startButton;
	IBOutlet NSTextField *statusLabel;
	
	BOOL batchDownloaderIsWorking;
	
	IBOutlet NSOutlineView *playlistView;
	
	IBOutlet NSTableView *trackView;

	BOOL firstLoad;
	
	WelcomeScreen *welcomeScreen;
}

-(IBAction) goButtonClicked:(id)sender;
-(void)showBatchDownloader;
-(void)loadTracks;

@property BOOL batchDownloaderIsWorking;

@end


