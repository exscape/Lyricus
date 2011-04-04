//
//  AboutController.h
//  Lyricus
//
//  Created by Thomas Backman on 4/4/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface AboutController : NSWindowController {
	IBOutlet NSImageView *iconView;
	IBOutlet NSTextField *aboutVersion;
	IBOutlet NSTextView *aboutTextView;
}

@end
