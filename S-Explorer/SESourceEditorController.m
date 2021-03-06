
//
//  SEEditorController.m
//  S-Explorer
//
//  Created by Dirk Theisen on 16.08.13.
//  Copyright (c) 2016 Cocoanuts.org. All rights reserved.
//

#import "SESourceEditorController.h"
#import "NoodleLineNumberView.h"
#import "NSTimer-NoodleExtensions.h"
#import "SEApplicationDelegate.h"
#import "NSColor+OPExtensions.h"
#import "SESourceStorage.h"

NSSet* SESingleIndentFunctions() {
    static NSSet* SESingleIndentFunctions = nil;
    if (! SESingleIndentFunctions) {
        SESingleIndentFunctions = [NSSet setWithObjects: @"define", @"lambda", @"module", @"let", @"letrec", @"let*", @"and-let*", nil];
    }
//todo: put into plist?
    return SESingleIndentFunctions;
}




@interface SESourceEditorController ()

@property(readonly) BOOL colorizeSourceItem;
@property (nonatomic) NSRange lastCompletionRange;

@end


@implementation SESourceEditorController {
}

//@synthesize sortedKeywords = _sortedKeywords;

- (void) dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver: self];
}



- (void) setSourceItem: (SESourceItem*) sourceItem {
    if (_sourceItem != sourceItem) {
        _sourceItem = sourceItem;

        [_sourceItem open];
        
        [self.textView.layoutManager replaceTextStorage: _sourceItem.contents];
        [self.textView.lineNumberView updateObservedTextStorage]; // found no better place to put this. :-/
        
        NSTextStorage* textStorage = _sourceItem.contents;
        
        NSString* fileContent = textStorage.string;
        if (! fileContent)
            fileContent = @"";
        NSDictionary* attributes = [NSDictionary dictionaryWithObjectsAndKeys: [NSFont fontWithName: @"Menlo" size: 13.0], NSFontAttributeName, nil, nil];
        [textStorage setAttributes: attributes range: NSMakeRange(0, fileContent.length)];
        
        // Colorize certain files:
        NSString* pathExtension = [sourceItem.name.pathExtension lowercaseString];
        
        
        NSSet* sourceExtensions = [NSSet setWithObjects: @"cljs", @"clj", nil]; // make flexible!
        
        _colorizeSourceItem = [sourceExtensions containsObject: pathExtension];
                
//        // Find enclosing project document:
//        NSDocument* document = [[SEDocumentController sharedDocumentController] documentForWindow: self.textView.window];
//        if (document isKindOfClass: [SEProjectDocument class]) {
//            SEProjectDocument* project = document;
//        }
//
//        self.defaultKeywords = [NSOrderedSet orderedSetWithArray: self.defaultKeywords];
        
        [self.textView.enclosingScrollView flashScrollers];
        
        [self.textView colorize: self];
    
    }
}

- (NSUndoManager *)undoManagerForTextView:(NSTextView *)view {
    return self.sourceItem.undoManager;
}


- (void) awakeFromNib {
    
    if (! self.textView.lineNumberView) {
        self.textView.lineNumberView = [[NoodleLineNumberView alloc] initWithScrollView: self.textView.enclosingScrollView];
        self.textView.lineNumberView.backgroundColor = self.textView.backgroundColor;
    }
}

// TODO: Turn into category on NSTextStorage, extract actual range finding.

- (NSUInteger) columnForLocation: (NSUInteger) location {
    NSString* text = self.textView.textStorage.string;
    NSUInteger column = 0;
    while (location>=column && [text characterAtIndex: location-column] != '\n') {
        column += 1;
    }
    return column;
}

- (NSUInteger) indentationAtLocation: (NSUInteger) lineStart {
    NSString* text = self.textView.textStorage.string;
    NSUInteger length = text.length;
    NSUInteger location = lineStart;
    NSUInteger indentation = 0;
    
    unichar locationChar;
    while (location < length) {
        locationChar = [text characterAtIndex: location];
        //NSLog(@"Testing '%c'", locationChar);
        if (locationChar == '\n' || (locationChar != ' ' && locationChar != '\t')) {
            break;
        }
        location += 1;
        indentation += 1;
    };
    return indentation;
}

- (void) indentInRange: (NSRange) range {
    
    NSUInteger indentation;
    NSRange previouslySelectedRange = self.textView.selectedRange;
    NSTextStorage* textStorage = self.textView.textStorage;
    NSString* text = textStorage.string;
    NSRange initialRange = range = [text lineRangeForRange: range];
    NSUInteger lineNo = 0;
    
    //[textStorage beginEditing];
    
    do {
        lineNo++;
        NSLog(@"Should indent in %@", NSStringFromRange(range));
        //NSLog(@"line is %@", NSStringFromRange(lineRange));
        NSRange currentExpressionRange = NSMakeRange(range.location, 0);
        indentation = 0;
        
        unichar openingPar = [self.textView.textStorage expandToAnyPar: &currentExpressionRange];
        if (openingPar != 0) {
            NSLog(@"Next opening par is %@", NSStringFromRange(currentExpressionRange));
            
            NSUInteger parColumn = [self columnForLocation: currentExpressionRange.location];
            NSLog(@"Parent par is at column %lu", parColumn);
            indentation = parColumn;
            
            // Read beginning of outer expression:
            NSUInteger location = currentExpressionRange.location+1;
            unichar locationChar;
            NSRange wordRange;
            BOOL isSingleItem = YES;
            while (location < NSMaxRange(range)) {
                locationChar = [text characterAtIndex: location];
                if (locationChar == ' ' || isPar(locationChar) || locationChar == '\n') {
                    wordRange = NSMakeRange(currentExpressionRange.location+1, location - currentExpressionRange.location-1); // wordRange now contains the first word
                
                    // Skip more spaces after first word:
                    do {
                        if (locationChar == ' ') {
                            locationChar = [text characterAtIndex: ++location];
                        } else {
                            break;
                        }
                    } while (location < NSMaxRange(range));
                    // Check, if something follows:
                    do {
                        if (locationChar == '\n' || [text characterAtIndex: wordRange.location] == ':' || openingPar == '[') break;
                        if (locationChar != ' ') {
                            isSingleItem = NO; // more elements coming
                            break;
                        }
                        locationChar = [text characterAtIndex: ++location];
                    } while (location < NSMaxRange(range));
                    break;
                }
                location += 1;
            }
            
            if (wordRange.length) {
                if (! isSingleItem) {
                    indentation += wordRange.length+1;
                }
            }
        }
        
        // Range contains one or more complete lines:
        NSUInteger previousIndentation = [self indentationAtLocation: range.location];
        if (indentation != previousIndentation) {
            // Create an NSString with indentation number of spaces:
            unsigned char indentChars[indentation];
            memset(&indentChars, ' ', indentation);
            NSString* spaces = [[NSString alloc] initWithBytesNoCopy: indentChars
                                                              length: indentation
                                                            encoding: NSASCIIStringEncoding
                                                        freeWhenDone: NO];
            
            // Insert spaces, replacing the old indenting ones:
            //self.textEditorView.selectedRange = NSMakeRange(range.location, previousIndentation);
            [self.textView insertText: spaces
                           replacementRange: NSMakeRange(range.location, previousIndentation)];
            //[textStorage replaceCharactersInRange: NSMakeRange(range.location, previousIndentation) withString: spaces];
            NSInteger indentationChange = indentation-previousIndentation;
            initialRange.length += indentationChange;
            range.length += indentationChange;
        }
//        if (previouslySelectedRange.length > 0) {
//            previouslySelectedRange.length += indentationChange;
//        }
        
        NSRange lineRange = [text lineRangeForRange: NSMakeRange(range.location, 0)];
        NSLog(@"Next line is %@", NSStringFromRange(lineRange));
        if (range.length > lineRange.length) {
            range.location += lineRange.length;
            range.length -= lineRange.length;
        } else break;
    } while (YES);
    
    //[textStorage endEditing];
    
    NSLog(@"Indented %lu lines.", lineNo);
    
    if (previouslySelectedRange.length > 0) {
        self.textView.selectedRange = initialRange;
    } else {
        if (previouslySelectedRange.location > range.location+indentation) {
            self.textView.selectedRange = previouslySelectedRange;
        }
    }
    
}

- (IBAction) insertNewline: (id) sender {
    [self.textView.undoManager beginUndoGrouping];
    [self.textView insertNewline: sender];
    [self indentInRange: self.textView.selectedRange];
    [self.textView.undoManager endUndoGrouping];
}


//- (void) setSortedKeywords:(NSArray *)keywords {
//    if (_sortedKeywords != keywords) {
//        _sortedKeywords = keywords;
//        if (self.colorizeSourceItem) {
//            self.textView.keywords = [[NSSet alloc] initWithArray: self.sortedKeywords];
//        }
//    }
//}


+ (void) recolorTextNotification: (NSNotification*) notification {
    NSLog(@"recolorTextNotification.");
    SESourceEditorController* editorController = notification.object;
    if (editorController.colorizeSourceItem) {
        [editorController.textView colorize: nil];
    }
}

- (void) textDidChange: (NSNotification*) notification {
    
    NSLog(@"Editor changed text.");
    NSNotification* textChangedNotification = [NSNotification notificationWithName: @"SETextNeedsRecoloring" object: self];
    [[NSNotificationQueue defaultQueue] enqueueNotification: textChangedNotification
                                                 postingStyle: NSPostWhenIdle
                                                 coalesceMask: NSNotificationCoalescingOnName | NSNotificationCoalescingOnSender
                                                     forModes: nil];
}

+ (void) load {
    
    static BOOL loaded = NO;
    if (! loaded) {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(recolorTextNotification:) name: @"SETextNeedsRecoloring" object: nil];
        
        loaded = YES;
    }
}


void OPRunBlockAfterDelay(NSTimeInterval delay, void (^block)(void)) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC*delay),
                   dispatch_get_current_queue(), block);
}


- (NSOrderedSet*) sortedKeywords {
    return self.textView.sortedKeywords;
}

- (void) setSortedKeywords: (NSOrderedSet*) keywords {
    self.textView.sortedKeywords = keywords;
}

- (NSSet*) defaultKeywords {
    return self.textView.defaultKeywords;
}

- (void) setDefaultKeywords: (NSSet*) keywords {
    self.textView.defaultKeywords = keywords;
}

- (NSArray<NSString*>*) textView: (NSTextView*) textView
                     completions: (NSArray<NSString*>*) words
             forPartialWordRange: (NSRange) charRange
             indexOfSelectedItem: (NSInteger*) index {
    
    if (! self.sortedKeywords) {
        return words;
    }
    
    //*indexPtr = -1;

    NSString* prefix = [textView.string substringWithRange: charRange];
    
    if (! prefix.length) return nil;
    
    NSLog(@"Completing '%@' (suggested %@)", prefix, words);
    
    //NSRange fullRange = NSMakeRange(0, self.sortedKeywords.count);
    NSComparator prefixComparator = ^NSComparisonResult(NSString* obj1, NSString* obj2) {
        if (obj1.length <= obj2.length) {
            if ([obj2 hasPrefix: obj1]) {
                return NSOrderedSame;
            }
        } else {
            if ([obj1 hasPrefix: obj2]) {
                return NSOrderedSame;
            }
        }
        NSRange compareRange = NSMakeRange(0, MIN(obj2.length, obj2.length));
        NSComparisonResult result = [obj1 compare: obj2 options: NSLiteralSearch range: compareRange];
        return result;
    };
    
    // Do binary search to find first and last keyword prefixed with 'prefix':
    NSInteger firstIndex = [self.sortedKeywords indexOfObject: prefix
                                                inSortedRange: NSMakeRange(0, self.sortedKeywords.count)
                                                      options: NSBinarySearchingFirstEqual
                                              usingComparator: prefixComparator];
    
    // Do not complete, if nothing found:
    if (firstIndex == NSNotFound) {
        self.lastCompletionRange = NSMakeRange(NSNotFound, 0);
        return nil;
    }
    if ([self.sortedKeywords[firstIndex] isEqualToString: prefix]) {
        firstIndex += 1;
    }

    NSInteger lastIndex = [self.sortedKeywords indexOfObject: prefix
                                         inSortedRange: NSMakeRange(firstIndex, self.sortedKeywords.count-firstIndex)
                                               options: NSBinarySearchingLastEqual
                                       usingComparator: prefixComparator];
    
    self.lastCompletionRange = charRange;
    
    NSArray* completions = [self.sortedKeywords.array subarrayWithRange: NSMakeRange(firstIndex, lastIndex-firstIndex+1)];
//    if (words.count) {
//        completions = [completions arrayByAddingObjectsFromArray: words];
//    }
    
    return completions;
}






- (BOOL) textView:(NSTextView*) textView shouldChangeTextInRange: (NSRange) affectedCharRange replacementString: (NSString*) replacementString {
    
    BOOL result = [super textView: textView shouldChangeTextInRange: affectedCharRange replacementString:replacementString];
    
    if (replacementString.length == 1 && NSMaxRange(self.lastCompletionRange) == affectedCharRange.location) {
        [self.textView performSelector: @selector(complete:) withObject: self afterDelay: 0.0];
        return YES;
    }
    if (replacementString.length == 0 && self.lastCompletionRange.length > 0) {
        self.lastCompletionRange = NSMakeRange(NSNotFound, 0);
    }
    
    return result;
}


- (BOOL) validateMenuItem: (NSMenuItem*) item {
    
    
    NSLog(@"Validating Item '%@'", NSStringFromSelector(item.action));
    return YES;
}

- (NSRange) topLevelExpressionContainingLocation: (NSUInteger) location {
    
    __block NSRange result = NSMakeRange(location, 0);
    [[[SESyntaxParser alloc] initWithString: self.textView.string
                                      range: NSMakeRange(0, self.textView.string.length)
                                      block: ^(SESyntaxParser *parser, SEParserResult pResult, BOOL *stopRef) {
                                          if (pResult.depth == 1) {
                                              switch (pResult.occurrence.token) {
                                                  case LEFT_PAR: {
                                                      result.location = pResult.occurrence.range.location;
                                                  }
                                                  case RIGHT_PAR: {
                                                      if (NSMaxRange(pResult.occurrence.range) > location) {
                                                          result.length = NSMaxRange(pResult.occurrence.range)-result.location;
                                                          *stopRef = YES; // stop parsing
                                                      }
                                                  }
                                                  default:;
                                              }
                                          }
                                          
                                      }] parseAll];
    return result;
}

- (IBAction) expandSelection: (id) sender {
    
    NSRange oldRange = self.textView.selectedRange;
    NSRange newRange = oldRange;

    NSString* text = self.textView.textStorage.string;
    
    // Check, if expansion is possible at all:
    if (oldRange.location < 1 || NSMaxRange(oldRange) >= text.length) {
        NSBeep();
        return;
    }
    
    unichar leftChar = [text characterAtIndex: oldRange.location-1];
    unichar rightChar = [text characterAtIndex: NSMaxRange(oldRange)];
    if (rightChar == matchingPar(leftChar)) {
        // Extend to pars:
        newRange.location -= 1;
        newRange.length += 2;
    } else {
        [self.textView.textStorage expandRange: &newRange toParMatchingPar: ')'];
        [self.textView.textStorage expandRange: &newRange toParMatchingPar: '('];
        // Exclude pars:
        if (newRange.length >= 2) {
            newRange.location += 1;
            newRange.length -= 2;
        }
    }
    
    
    NSLog(@"Expanding selection from %@ to %@", NSStringFromRange(oldRange), NSStringFromRange(newRange));
    
    self.textView.selectedRange = newRange;
}

BOOL SEToggleLineComments(NSMutableString* replacement, unichar commentChar) {
    
    NSCharacterSet* whitespaces = [NSCharacterSet whitespaceCharacterSet];
    NSString* commentStringToAdd = nil;
    NSUInteger commonWhiteSpaceCount = NSUIntegerMax;
    // First, check, if all lines have line comments:
    NSUInteger currentLineStart = 0;
    do {
        NSRange currentLineRange = [replacement lineRangeForRange: NSMakeRange(currentLineStart, 0)];
        
        NSString* currentLine = [replacement substringWithRange:currentLineRange];
        NSLog(@"Checking line at %@: '%@'", NSStringFromRange(currentLineRange), currentLine);
        for (NSUInteger pos=currentLineRange.location; pos<NSMaxRange(currentLineRange); pos++) {
            unichar prefixChar = [replacement characterAtIndex: pos];
            NSLog(@"Checking char '%c'", prefixChar);
            
            if (! [whitespaces characterIsMember: prefixChar]) {
                if (prefixChar != commentChar && ! commentStringToAdd) {
                    commentStringToAdd = [NSString stringWithFormat: @"%C", commentChar];
                }
                if (prefixChar != '\n') {
                    commonWhiteSpaceCount = MIN(commonWhiteSpaceCount, pos-currentLineRange.location);
                }
                break;
            }
        }
        if (commentStringToAdd) break;
        
        currentLineStart = currentLineRange.location + currentLineRange.length;
    } while (currentLineStart < replacement.length);
    
    NSLog(@"%@ comments...", commentStringToAdd ? @"Adding" : @"Removing");
    if (commonWhiteSpaceCount == NSUIntegerMax) {
        commonWhiteSpaceCount = 0;
    }
    
    NSUInteger commonCommentPosition = (commonWhiteSpaceCount>0) ? commonWhiteSpaceCount-1 : 0;
    
    if (commentStringToAdd) {
        NSLog(@"Inserting comments at position %lu", commonWhiteSpaceCount);
    }
    
    // Start second pass that actually does the conversion:
    
    currentLineStart = 0;
    do {
        NSRange currentLineRange = [replacement lineRangeForRange: NSMakeRange(currentLineStart, 0)];
        
        NSString* currentLine = [replacement substringWithRange:currentLineRange];
        NSLog(@"Changing line at %@: '%@'", NSStringFromRange(currentLineRange), currentLine);
        
        if (commentStringToAdd) {
            // Add Comments:
            // Make sure, the line is long enough to insert a comment char at commonCommentPosition:
            while (currentLineRange.length <= commonCommentPosition) {
                [replacement replaceCharactersInRange:NSMakeRange(currentLineRange.location, 0) withString: @" "];
                currentLineRange.length += 1;
            }
            [replacement replaceCharactersInRange:NSMakeRange(currentLineRange.location+commonCommentPosition, 0) withString: @";"];
            currentLineRange.length += 1;
            
        } else {
            // Remove Comments:
            for (NSUInteger pos=currentLineRange.location; pos<NSMaxRange(currentLineRange); pos++) {
                unichar prefixChar = [replacement characterAtIndex: pos];
                //NSLog(@"Checking char '%c'", prefixChar);
                if (prefixChar == commentChar) {
                    if (pos+2<NSMaxRange(currentLineRange)) {
                        [replacement replaceCharactersInRange:NSMakeRange(pos, 1) withString: @""];
                        currentLineRange.length -= 1;
                    } else {
                        // Also delete leading spaces:
                        [replacement replaceCharactersInRange:NSMakeRange(pos-commonWhiteSpaceCount, commonWhiteSpaceCount+1) withString: @""];
                        currentLineRange.length -= commonWhiteSpaceCount+1;
                        
                    }
                    break;
                }
            }
        }
        
        currentLineStart = currentLineRange.location + currentLineRange.length;
    } while (currentLineStart < replacement.length);

    return commentStringToAdd != nil;
}


- (IBAction) toggleComments: (id) sender {
    
    NSString* text = self.textView.textStorage.string;
    NSRange selectedRange = self.textView.selectedRange;
    NSRange lineRange = [text lineRangeForRange: selectedRange];
    [self.textView setSelectedRange:lineRange];
    
    NSMutableString* replacement = [[text substringWithRange: lineRange] mutableCopy];
    
    BOOL isAddingComments = SEToggleLineComments(replacement, ';');
    
    [self.textView insertText: replacement];
    
    if (selectedRange.length) {
        selectedRange = NSMakeRange(lineRange.location, replacement.length);
    } else {
        selectedRange.location += isAddingComments ? 1 : -1;
    }
    [self.textView setSelectedRange: selectedRange];
}

- (NSString*) description {
    return [NSString stringWithFormat: @"%@ editing %@", [super description], self.sourceItem];
}

@end

