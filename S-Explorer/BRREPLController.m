
//
//  BRTerminalController.m
//  S-Explorer
//
//  Created by Dirk Theisen on 09.05.13.
//  Copyright (c) 2013 Cocoanuts. All rights reserved.
//

#import "BRREPLController.h"
#import "BRREPLView.h"
#import "PseudoTTY.h"
#import "SESchemeParser.h"

@implementation BRREPLController {

    PseudoTTY* tty;
    NSMutableArray* previousCommands;
    NSMutableArray* nextCommands;
    
    NSUInteger currentOutputStart;
}

static NSData* lineFeedData = nil;

+ (void) load {
    lineFeedData = [NSData dataWithBytes: "\n" length: 1];
}

- (id) init {
    if (self = [super init]) {
        previousCommands = [[NSMutableArray alloc] init];
        nextCommands = [[NSMutableArray alloc] init];
    }
    return self;
}

//- (id) initWithCoder:(NSCoder *)aDecoder {
//    
//    
//    return self;
//}
//
//- (void) encodeWithCoder:(NSCoder *)aCoder {
//    
//}

- (void) awakeFromNib {
}



- (void) taskOutputReceived: (NSNotification*) n {
    
    NSFileHandle* filehandle = n.object;
    //NSData* data = filehandle.availableData;
    NSData* data = n.userInfo[NSFileHandleNotificationDataItem];
    NSString* string = [[NSString alloc] initWithData: data encoding: NSISOLatin1StringEncoding];
    
    
    [self.replView appendInterpreterString: string];
    
    NSString* outputString = self.replView.string;
    NSRange outputRange = NSMakeRange(currentOutputStart, outputString.length-currentOutputStart);
    
    NSLog(@"Colorizing '%@' ", [outputString substringWithRange: outputRange]);
    
    SESchemeParser* parser = [[SESchemeParser alloc] initWithString: outputString
                                                              range: outputRange
                                                           delegate: self.replView];
    [parser parseAll];
    [self.replView moveToEndOfDocument: self];

    
    [filehandle readInBackgroundAndNotify];
}

- (void) sendCommand: (NSString*) commandString {
    
    NSData* stringData = [commandString dataUsingEncoding: NSISOLatin1StringEncoding];
    [tty.masterFileHandle writeData: stringData];
    [tty.masterFileHandle writeData: lineFeedData];
}

- (NSArray*) nextCommands {
    return  nextCommands;
}

- (NSArray*) previousCommands {
    return  previousCommands;
}


- (NSString*) currentCommand {
    return [self.replView.string substringWithRange: self.replView.commandRange];
}

- (void) setCurrentCommand:(NSString *)currentCommand {
    
    NSTextStorage* textStorage = self.replView.textStorage;
    NSRange commandRange = self.replView.commandRange;
    [textStorage beginEditing];
    [textStorage replaceCharactersInRange: commandRange withString: currentCommand];
    commandRange.length = currentCommand.length;
    [textStorage setAttributes: self.replView.typingAttributes range: commandRange];
    [textStorage endEditing];
    
    // Place cursor behind new command:
    self.replView.selectedRange = NSMakeRange(commandRange.location+currentCommand.length, 0);
}

- (void) saveHistory {
    
    NSUserDefaults* ud = [NSUserDefaults standardUserDefaults];
    
    [ud setObject: self.previousCommands
           forKey: [NSString stringWithFormat: @"REPL-History-%@", @"1"]];
}

- (BOOL) sendCurrentCommand {
    
    NSRange commandRange = self.replView.commandRange;
    if (commandRange.length) {
        NSString* command = [self.replView.string substringWithRange: commandRange];
        NSLog(@"Sending command '%@'", command);
        
        
        while (nextCommands.count) {
            [self moveDown: self];
        }
        [previousCommands insertObject: command atIndex: 0];

        self.currentCommand = @"";
        [self sendCommand: command];
        
        currentOutputStart = self.replView.string.length;
        
        [self saveHistory];
        
        return YES;
        
    } else if (self.replView.isCommandMode) {
        NSString* log = self.replView.string;
        NSRange promptRange = [log lineRangeForRange: self.replView.selectedRange];
        NSString* prompt = [log substringWithRange: promptRange];
        [self.replView appendInterpreterString: @"\n"];
        [self.replView appendInterpreterString: prompt];
    }
    
    return NO;
}

- (IBAction) insertNewline: (id) sender {
    //NSLog(@"Return key action.");
    [self sendCurrentCommand];
    [self.replView moveToEndOfDocument: sender];
    //[self.replView scrollRangeToVisible: self.replView.selectedRange];
}


/**
 *
 */
- (IBAction) moveDown: (id) sender {
    
    if (self.replView.isCommandMode) {
        NSLog(@"History next action.");
        if (! nextCommands.count) {
            return;
        }
        [previousCommands insertObject: self.currentCommand atIndex: 0];
        self.currentCommand = [nextCommands lastObject];
        [nextCommands removeLastObject];
        
        return;
    }
    [self.replView moveDown: sender];
}

/**
 *
 */
- (IBAction) moveUp: (id) sender {
    
    if (self.replView.isCommandMode) {
        NSLog(@"History prev action.");
        
        if (! previousCommands.count) {
            return;
        }
        [nextCommands addObject: self.currentCommand];
        self.currentCommand = previousCommands[0];
        [previousCommands removeObjectAtIndex: 0];
        
        return;
    }
    [self.replView moveUp: sender];
}






- (IBAction) stop: (id) sender {
    
    if (self.task) {
        
         [_task terminate];
        [[NSNotificationCenter defaultCenter] removeObserver: self
                                                        name: NSFileHandleReadCompletionNotification
                                                      object: tty.masterFileHandle];
        _task = nil;
    }
}

- (IBAction) run: (id) sender {
    

    [self stop: sender];
    //NSAssert(! _task.isRunning, @"There is already a task (%@) running! Terminate it, prior to starting a new one.", _task);

    [self.replView clear: sender];
    
    if (self.greeting) {
        [self.replView appendInterpreterString: self.greeting];
        [self.replView appendInterpreterString: @"\n\n"];
    }
    [self.replView moveToEndOfDocument: self];
    
    _task = [[NSTask alloc] init];
    
    if (! tty) {
        tty = [[PseudoTTY alloc] init];
    }
    
    [_task setStandardInput: tty.slaveFileHandle];
    [_task setStandardOutput: tty.slaveFileHandle];
    [_task setStandardError: tty.slaveFileHandle];
    _task.arguments = self.commandArguments;
    _task.launchPath = self.commandString;
    
    NSDictionary *defaultEnvironment = [[NSProcessInfo processInfo] environment];
    NSMutableDictionary *environment = [[NSMutableDictionary alloc] initWithDictionary:defaultEnvironment];
    [environment setObject: @"YES" forKey: @"NSUnbufferedIO"];
    [environment setObject: @"en_US-iso8859-1" forKey: @"LANG"];
    
    [_task setEnvironment: environment];
    
    [[NSNotificationCenter defaultCenter] addObserver: self
                                             selector: @selector(taskOutputReceived:)
                                                 name:  NSFileHandleReadCompletionNotification
                                               object: tty.masterFileHandle];
    
    
    [tty.masterFileHandle readInBackgroundAndNotify];
    //[_task.standardError readInBackgroundAndNotify];
    
    //    _task.terminationHandler =  ^void (NSTask* task) {
    //        if (task == _task) {
    //            _task = nil;
    //        }
    //    };
    
    [_task launch];
}

- (void) setCommand: (NSString*) command
      withArguments: (NSArray*) arguments
           greeting: (NSString*) greeting
              error: (NSError**) errorPtr {

    _commandString = [command stringByResolvingSymlinksInPath];
    _commandArguments = arguments;
    _greeting = greeting;
    
    if (! [[NSFileManager defaultManager] isExecutableFileAtPath: command]) {
        if (errorPtr) {
            *errorPtr = [NSError errorWithDomain: @"org.cocoanuts.bracket" code: 404
                                        userInfo: @{NSLocalizedFailureReasonErrorKey: [NSString stringWithFormat: @"No Executable file at '%@'", command]}];
        }
        return;
    }
}



@end
