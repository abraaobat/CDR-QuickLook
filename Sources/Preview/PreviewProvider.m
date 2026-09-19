#import <AppKit/AppKit.h>
#import <PDFKit/PDFKit.h>
#import <QuickLookUI/QuickLookUI.h>

#import "CDRArchive.h"

@interface PreviewViewController : NSViewController <QLPreviewingController>
@property(nonatomic, strong) PDFView *pdfView;
@end

@implementation PreviewViewController

- (void)loadView {
    // Match the generous initial footprint used by PDF previews instead of
    // letting Quick Look infer a tiny window from CorelDRAW's 256 px proxy.
    NSSize initialSize = NSMakeSize(1000, 760);
    NSView *container = [[NSView alloc] initWithFrame:NSMakeRect(0, 0,
                                                                 initialSize.width,
                                                                 initialSize.height)];
    PDFView *pdfView = [[PDFView alloc] initWithFrame:container.bounds];
    pdfView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    pdfView.autoScales = YES;
    pdfView.displayMode = kPDFDisplaySinglePageContinuous;
    pdfView.displayDirection = kPDFDisplayDirectionVertical;
    pdfView.displaysPageBreaks = YES;
    [container addSubview:pdfView];
    self.pdfView = pdfView;
    self.view = container;
    self.preferredContentSize = initialSize;
}

- (void)preparePreviewOfFileAtURL:(NSURL *)url
                completionHandler:(void (^)(NSError * _Nullable error))handler {
    // Decode away from the main thread so opening a large multipage CDR never
    // stalls Quick Look's UI.
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSError *archiveError = nil;
        CDRArchive *archive = [CDRArchive archiveWithURL:url error:&archiveError];
        if (archive == nil) {
            dispatch_async(dispatch_get_main_queue(), ^{ handler(archiveError); });
            return;
        }

        PDFDocument *document = [[PDFDocument alloc] init];
        NSUInteger pageLimit = MIN(archive.pageCount, 512);
        for (NSUInteger index = 0; index < pageLimit; index++) {
            @autoreleasepool {
                NSData *imageData = [archive pageDataAtIndex:index error:&archiveError];
                NSImage *image = imageData == nil ? nil : [[NSImage alloc] initWithData:imageData];
                PDFPage *page = image == nil ? nil : [[PDFPage alloc] initWithImage:image];
                if (page != nil) {
                    [document insertPage:page atIndex:document.pageCount];
                }
            }
        }

        if (document.pageCount == 0) {
            NSError *renderError = archiveError ?: [NSError errorWithDomain:CDRQuickLookErrorDomain
                                                                         code:20
                                                                     userInfo:@{NSLocalizedDescriptionKey:
                                                                         @"Nenhuma página de prévia pôde ser decodificada."}];
            dispatch_async(dispatch_get_main_queue(), ^{ handler(renderError); });
            return;
        }

        NSSize preferredSize = NSMakeSize(1000, 760);
        dispatch_async(dispatch_get_main_queue(), ^{
            self.preferredContentSize = preferredSize;
            self.pdfView.document = document;
            handler(nil);
        });
    });
}

@end
