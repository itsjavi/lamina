#import <AppKit/AppKit.h>

// The tests were written to run hosted in Lamina.app: AppKit's event loop (NSApplication.run) and the
// editor window were there throughout. swift test runs them in a plain tool instead, where a nested loop
// (an alert, a button click, a modal session) stopping the run loop ends Swift's main loop, and with it the
// test process, and where panels docking to "the document window" find none. So this starts the same
// environment as the bundle loads: an accessory app (no Dock icon) running its event loop, with one window
// in the editor's place. Main-actor work still runs: the event loop drains the main queue. It starts from a
// run loop block rather than the main queue, which is serial: a loop running inside one of its blocks would
// hold every later main-actor job.
__attribute__((constructor)) static void LaminaStartTestHost(void) {
    // Only in swift test's Swift Testing runner, whose main thread runs the main run loop for good. xctest (which
    // swift test also starts, for XCTest cases; there are none) drives its main thread itself and would never get
    // it back.
    if (![NSProcessInfo.processInfo.processName isEqualToString:@"swiftpm-testing-helper"]) return;
    CFRunLoopPerformBlock(CFRunLoopGetMain(), kCFRunLoopDefaultMode, ^{
        NSApplication *app = NSApplication.sharedApplication;
        [app setActivationPolicy:NSApplicationActivationPolicyAccessory];
        NSWindow *window = [[NSWindow alloc] initWithContentRect:NSMakeRect(160, 160, 1200, 800)
                                                       styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable |
                                                                 NSWindowStyleMaskResizable
                                                         backing:NSBackingStoreBuffered
                                                           defer:NO];
        window.releasedWhenClosed = NO;
        window.title = @"Lamina Test Host";
        [window orderFront:nil];
        [app run];
    });
}
