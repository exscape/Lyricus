#import "WelcomeScreen.h"

@implementation WelcomeScreen

-(id)init {
	return [self initWithWindowNibName:@"WelcomeScreen"];
}

-(id)initWithWindowNibName:(NSString *)windowNibName {
	self = [super initWithWindowNibName:windowNibName];
	if (self) {
		text = nil;
		delegate = nil;
		owner = nil;
	}
	return self;
}

-(void)setText:(NSString *)inText {
	text = [inText copy];
	[textLabel setStringValue:text];
}

-(void)setDelegate:(id)inDelegate {
	delegate = inDelegate;
}

-(void)showWindow:(id)sender {
	[super showWindow:sender];
	[self.window makeKeyAndOrderFront:sender];
}
-(void)setOwningWindow:(NSWindow *)inOwner {
	owner = inOwner;
}

-(void)show {
	// Attempt to center the window on the owner
	if (owner != nil) {
		NSRect frame = [self.window frame];
		NSRect ownerFrame = [owner frame];
		NSRect screenFrame = [[NSScreen mainScreen] frame];
		
		frame.origin.x = (ownerFrame.origin.x + (ownerFrame.size.width / 2)) - (frame.size.width / 2);
		frame.origin.y = (ownerFrame.origin.y + (ownerFrame.size.height / 2)) - (frame.size.height / 2);
		
		// If the above position has part of the window off screen, move it back.
		if (frame.origin.x + frame.size.width > screenFrame.size.width)
			frame.origin.x = screenFrame.size.width - frame.size.width;
		if (frame.origin.y + frame.size.height > screenFrame.size.height)
			frame.origin.y = screenFrame.size.height - frame.size.height;
		
		[self.window setFrame:frame display:NO animate:NO];		
	}
	
	[self showWindow:self];
}

-(IBAction)closeButtonClicked:(id)sender {
	if ([delegate respondsToSelector:@selector(userDidCloseWindowWithDontShowAgain:)]) {
		[delegate userDidCloseWindowWithDontShowAgain:(BOOL)[dontShowAgain state]];
	}
	
	[self.window close];
}

- (void)dealloc{
    [super dealloc];
}

@end
