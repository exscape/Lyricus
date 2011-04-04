//
//  AboutController.m
//  Lyricus
//
//  Created by Thomas Backman on 4/4/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "AboutController.h"


@implementation AboutController

-(id)initWithWindowNibName:(NSString *)windowNibName {
	self = [super initWithWindowNibName:windowNibName];
	if (self) {
	}
	
	return self;
}

-(void)awakeFromNib {
	[iconView setImage:[NSApp applicationIconImage]];
	NSString *version = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"];
	[aboutVersion setStringValue:[@"v" stringByAppendingString:version]];
	
	/* Center the version text */
	[aboutVersion sizeToFit];
	NSRect superFrame = [[aboutVersion superview] frame];
	NSRect versionFrame = [aboutVersion frame];
	versionFrame.origin.x = (superFrame.size.width - versionFrame.size.width) / 2;
	[aboutVersion setFrame:versionFrame];
	
	[aboutTextView setString:
	 @"Everything Lyricus:\n"
	 @"  Thomas Backman <serenity@exscape.org>\n"
	 @"  http://lyricus.exscape.org\n"
	 @"\n"
	 @"Thanks to:\n"
	 @"John Engelhart\n"
	 @"  http://regexkit.sourceforge.net"];
}

-(IBAction)showRegexKitLicense:(id)sender {
	NSString *licenseString = 
	@"Copyright © 2007-2008, John Engelhart\n"
	@"\n"
	@"All rights reserved.\n"
	@"\n"
	@"Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:\n"
	@"\n"
	@"* Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.\n"
	@"* Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.\n"
	@"* Neither the name of the Zang Industries nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.\n"
	@"THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS \"AS IS\" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.";
	
	[[NSAlert alertWithMessageText:@"Lyricus uses the RegexKitLite library by John Engelhart." defaultButton:@"OK" alternateButton:nil otherButton:nil informativeTextWithFormat:licenseString] runModal];
}


- (void)dealloc
{
    [super dealloc];
}

- (void)windowDidLoad
{
    [super windowDidLoad];
    
    // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
}

@end
