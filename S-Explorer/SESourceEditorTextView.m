//
//  SEEditorTextView.m
//  S-Explorer
//
//  Created by Dirk Theisen on 20.08.13.
//  Copyright (c) 2016 Cocoanuts.org. All rights reserved.
//

#import "SESourceEditorTextView.h"
#import "SESourceEditorController.h"
#import "OPCharFilterFormatter.h"
#import "SESyntaxParser.h"
#import "NSColor+OPExtensions.h"
#import "SESourceStorage.h"
#import <MPEDN/MPEdn.h>


//@interface NSAlert (TextValidation) <NSTextFieldDelegate>
//
//@end
//
//@implementation NSAlert (TextValidation)
//
//- (void)control:(NSControl *)control didFailToValidatePartialString:(NSString *)string errorDescription:(NSString *)error {
//    NSLog(@"Wrong line number: %@", error);
//    NSButton* okButton = [self.buttons objectAtIndex: 0];
//    okButton.enabled = NO;
//}
//
//- (BOOL)control:(NSControl *)control didFailToFormatString:(NSString *)string errorDescription:(NSString *)error {
//    NSButton* okButton = [self.buttons objectAtIndex: 0];
//    okButton.enabled = NO;
//    return NO;
//}
//
//- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string {
//    
//    if (string.length && ! [string rangeOfCharacterFromSet: [NSCharacterSet decimalDigitCharacterSet] options: 0]) {
//        return NO;
//    }
//
//    return YES;
//}
//
//@end

@implementation SESourceEditorTextView {
    NSMutableArray* selectionStack;
}

- (id)initWithFrame:(NSRect)frame {
    if (self = [super initWithFrame:frame]) {
        // Initialization code here.
    }
    
    return self;
}

- (void)awakeFromNib {
    [self setAutomaticQuoteSubstitutionEnabled: NO];
}

static NSCharacterSet* SEWordCharacters() {
    static NSCharacterSet* SEWordCharacters = nil;
    if (! SEWordCharacters) {
        NSMutableCharacterSet* c = [[NSCharacterSet alphanumericCharacterSet] mutableCopy];
        [c addCharactersInString: @"-_!*"];
        SEWordCharacters = [c copy];
    }
    return SEWordCharacters;
}

///* Change word selection behaviour to include hythens and other characters common in function names. */
//- (NSRange) selectionRangeForProposedRange: (NSRange) proposedSelRange
//                               granularity: (NSSelectionGranularity)granularity {
//    if (granularity == NSSelectByWord) {
//        NSString* text = self.textStorage.string;
//        NSCharacterSet* wordCharSet = SEWordCharacters();
//        NSRange resultRange = proposedSelRange;
//        if ([wordCharSet characterIsMember: [text characterAtIndex: resultRange.location]]) {
//            // Search backward:
//            while (resultRange.location && ([wordCharSet characterIsMember: [text characterAtIndex: resultRange.location-1]])) {
//                resultRange.location -= 1;
//                resultRange.length += 1;
//            }
//            // Search forward:
//            while (NSMaxRange(resultRange)<text.length && ([wordCharSet characterIsMember: [text characterAtIndex: NSMaxRange(resultRange)]])) {
//                resultRange.length += 1;
//            }
//            
//            NSLog(@"proposed: %@, result: %@\n%@", NSStringFromRange(proposedSelRange), NSStringFromRange(resultRange), [text substringWithRange: resultRange]);
//            return resultRange;
//        }
//    }
//    return [super selectionRangeForProposedRange: proposedSelRange granularity:granularity];
//}

- (NSMutableArray*) selectionStack {
    if (! selectionStack) {
        selectionStack = [[NSMutableArray alloc] initWithCapacity: 10];
    }
    return selectionStack;
}

- (BOOL) validateMenuItem: (NSMenuItem*) item {
    
    
    NSLog(@"Validating Item '%@'", NSStringFromSelector(item.action));
    if ([item action] == @selector(contractSelection:)) {
        return self.selectionStack.count > 0;
    }

    return [super validateMenuItem: item];
}

- (NSString*) selectedString {
    NSRange selectedRange = self.selectedRange;
    if (selectedRange.length > 0) {
        return [self.string substringWithRange: selectedRange];
    }
    return nil;
}


- (IBAction) indentSelectedLines: (id)sender {
    NSLog(@"Should indent currently selected lines.");
    [(SESourceEditorController*)self.delegate indentInRange: self.selectedRange];
}

- (IBAction) insertTab: (id) sender {
    [self indentSelectedLines: sender];
}

- (void) didChangeText {
    [super didChangeText];
    [self.selectionStack removeAllObjects];
}

- (void)moveToEndOfDocumentAndModifySelection: (id) sender {
    // NOP
}

- (void)moveToBeginningOfDocumentAndModifySelection: (id) sender {
    // NOP
}

//- (NSRange) selectionRangeForProposedRange: (NSRange) proposedSelRange
//                               granularity: (NSSelectionGranularity) granularity {
//    NSRange result = [super selectionRangeForProposedRange: proposedSelRange granularity: granularity];
//    
//    if (granularity == NSSelectByWord) {
//        NSLog(@"Extended proposedSelRange %@ to %@ (%@).", NSStringFromRange(proposedSelRange), NSStringFromRange(result), [self.string substringWithRange: result]);
//    }
//    return result;
//}


- (IBAction) contractSelection: (id) sender {
    if (self.selectionStack.count == 0) {
        NSBeep();
        return;
    }
    NSRange oldSelectionRange = [[self.selectionStack lastObject] rangeValue];
    [self.selectionStack removeLastObject];
    self.selectedRange = oldSelectionRange;
}


- (IBAction) expandSelection: (id) sender {
    if ([self.delegate respondsToSelector: _cmd]) {
        NSRange oldSelectionRange = self.selectedRange;
        [self.delegate performSelector: @selector(expandSelection:) withObject: sender];
        if (! NSEqualRanges(oldSelectionRange, self.selectedRange)) {
            [self.selectionStack addObject: [NSValue valueWithRange: oldSelectionRange]];
        }
    }
}





- (IBAction) colorize: (id) sender {
    
    NSRange fullRange = NSMakeRange(0, self.string.length);
    [self.textStorage colorizeRange: fullRange symbols: self.sortedKeywords.set defaultSymbols: self.defaultKeywords];
}

- (NSRange) rangeForUserCompletion {
    NSRange selectedRange = self.selectedRange;
    NSRange searchRange = NSMakeRange(0, selectedRange.location);
    NSRange stopRange = [self.string rangeOfCharacterFromSet: MPEdnNonSymbolChars
                                                  options: NSBackwardsSearch
                                                    range: searchRange];
    
    if (stopRange.location == NSNotFound) {
        return selectedRange;
    }
    
    NSRange result = NSMakeRange(stopRange.location+1, selectedRange.location-(stopRange.location+1));
    
    // NSLog(@"Will complete text '%@'", [self.string substringWithRange: result]);
    
    return result;
}

- (void) setSortedKeywords: (NSOrderedSet*) keywords {
    if (_sortedKeywords != keywords) {
        _sortedKeywords = keywords;
        [self colorize: self];
    }
}

- (void) setDefaultKeywords: (NSSet*) keywords {
    if (_defaultKeywords != keywords) {
        _defaultKeywords = keywords;
        [self colorize: self];
    }
}


/**
  * selects the given line number. Must be >=1. Does nothing but beep, if given line number is too high.
  */

- (NSRange) selectLineNumber: (NSUInteger) line {
    
    NoodleLineNumberView* lineNumberView = [self lineNumberView];
    line = MIN(lineNumberView.numberOfLines, MAX(1, line));
    
    NSRange lineRange = [lineNumberView characterRangeForLineNumber: line-1];
    self.selectedRange = lineRange;
    return lineRange;
}


/**
 * Make sure, all actions can also be implemented by the delegate.
 */
- (void) doCommandBySelector: (SEL) aSelector {
    if ([self.delegate respondsToSelector: aSelector]) {
        [[NSApplication sharedApplication] sendAction: aSelector to:self.delegate from:self];
        return;
    }
    return [super doCommandBySelector: aSelector];
}

- (NoodleLineNumberView*) lineNumberView {
    NoodleLineNumberView* lineNumberView = (NoodleLineNumberView*)self.enclosingScrollView.verticalRulerView;
    if (! [lineNumberView isKindOfClass:[NoodleLineNumberView class]]) {
        return nil;
    }
    return lineNumberView;
}

- (void) setLineNumberView: (NoodleLineNumberView*) lineNumberView {
    NSScrollView* scrollView = self.enclosingScrollView;
    scrollView.verticalRulerView = lineNumberView;
    [scrollView setHasHorizontalRuler: NO];
    [scrollView setHasVerticalRuler: lineNumberView != nil];
    [scrollView setRulersVisible: lineNumberView != nil];
}

- (IBAction) toggleComments: (id) sender {
    if ([self.delegate respondsToSelector:_cmd]) {
        [[NSApplication sharedApplication] sendAction:_cmd to:self.delegate from:sender];
    }
}

- (IBAction) selectSpecificLine: (id) sender {
    
    
    NSUserDefaults* ud = [NSUserDefaults standardUserDefaults];
    NSAlert *alert = [NSAlert alertWithMessageText: @"Select Line Number …"
                                     defaultButton: @"OK"
                                   alternateButton: @"Cancel"
                                       otherButton: nil
                         informativeTextWithFormat: @""];
    
    NSTextField *lineNumberField = [[NSTextField alloc] initWithFrame: NSMakeRect(0, 0, 50, 22)];
    [lineNumberField setAlignment: NSCenterTextAlignment];
    [lineNumberField setIntegerValue: [ud integerForKey: @"GotoPanelLineNumber"]];
    
    NSNumberFormatter* formatter = [[NSNumberFormatter alloc] init];
    formatter.usesGroupingSeparator = NO;
    formatter.minimum = @(1);
    formatter.allowsFloats = NO;
    
    lineNumberField.formatter = [[OPDigitFormatter alloc] init];
    //lineNumberField.delegate = alert;
    
    [alert setAccessoryView: lineNumberField];
    NSInteger button = [alert runModal];
    if (button == NSAlertDefaultReturn) {
        [lineNumberField validateEditing];
        NSUInteger line = [lineNumberField integerValue];
        NSRange lineRange = [self selectLineNumber: line];
        [self scrollRangeToVisible: lineRange];
        [ud setInteger: line forKey: @"GotoPanelLineNumber"];
    } 
}


@end





