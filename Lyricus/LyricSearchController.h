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
@private
    
}

-(void) showLyricSearch:(id) sender;
-(IBAction) updateTrackIndex:(id) sender;
-(IBAction) abortIndexing:(id) sender;

@end
