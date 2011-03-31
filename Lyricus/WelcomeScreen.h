#import <Foundation/Foundation.h>


@interface WelcomeScreen : NSWindowController {
	IBOutlet NSButton *dontShowAgain;
	IBOutlet NSButton *closeButton;
	IBOutlet NSTextField *textLabel;
	
	NSString *text;
	id delegate;
	NSWindow *owner;
}

-(void)setText:(NSString *)inText;
-(void)setDelegate:(id)inDelegate;
-(void)setOwningWindow:(NSWindow *)inOwner;
-(void)show;

@end

//
// Informal protocol for the delegate
//

@interface NSObject (WelcomeScreen)
-(void)userDidCloseWindowWithDontShowAgain:(BOOL)state;
@end