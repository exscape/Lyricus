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
    IBOutlet NSWindow *window;
    IBOutlet NSTextField *searchTextField;
    IBOutlet NSTableView *trackTableView;
    iTunesHelper *helper;
    NSArray *trackData;
    NSMutableArray *matches;
@private
    
}

-(void) showLyricSearch:(id) sender;
-(IBAction) updateTracklist:(id) sender;
-(IBAction) updateTrackIndex:(id) sender;

@end
