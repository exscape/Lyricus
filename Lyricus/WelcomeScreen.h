#import <Foundation/Foundation.h>


@interface WelcomeScreen : NSWindowController {
	IBOutlet NSButton *dontShowAgain;
	IBOutlet NSButton *closeButton;
	IBOutlet NSTextField *textLabel;
	
	NSString *text;
	id delegate;
	NSWindow *owner;
}

-(id)initWithText:(NSString *)inText owningWindow:(NSWindow *)inOwner delegate:(id)inDelegate;

@end

//
// Informal protocol for the delegate
//

@interface NSObject (WelcomeScreen)
-(void)userDidCloseWelcomeScreenWithDontShowAgain:(BOOL)state;
@end