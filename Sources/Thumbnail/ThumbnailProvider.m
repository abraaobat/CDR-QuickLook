#import <CoreGraphics/CoreGraphics.h>
#import <Foundation/Foundation.h>
#import <ImageIO/ImageIO.h>
#import <QuickLookThumbnailing/QuickLookThumbnailing.h>

#import "CDRArchive.h"

static CGSize CDRAspectFit(CGSize imageSize, CGSize maximumSize) {
    if (imageSize.width <= 0 || imageSize.height <= 0
        || maximumSize.width <= 0 || maximumSize.height <= 0) {
        return CGSizeMake(MAX(1, maximumSize.width), MAX(1, maximumSize.height));
    }
    CGFloat scale = MIN(maximumSize.width / imageSize.width,
                        maximumSize.height / imageSize.height);
    return CGSizeMake(MAX(1, floor(imageSize.width * scale)),
                      MAX(1, floor(imageSize.height * scale)));
}

@interface ThumbnailProvider : QLThumbnailProvider
@end

@implementation ThumbnailProvider

- (void)provideThumbnailForFileRequest:(QLFileThumbnailRequest *)request
                     completionHandler:(void (^)(QLThumbnailReply * _Nullable reply,
                                                  NSError * _Nullable error))handler {
    NSError *archiveError = nil;
    CDRArchive *archive = [CDRArchive archiveWithURL:request.fileURL error:&archiveError];
    NSData *data = [archive thumbnailDataWithError:&archiveError];
    if (archive == nil || data == nil) {
        handler(nil, archiveError);
        return;
    }

    CGImageSourceRef source = CGImageSourceCreateWithData((__bridge CFDataRef)data, NULL);
    CGImageRef createdImage = source == NULL ? NULL : CGImageSourceCreateImageAtIndex(source, 0, NULL);
    if (source != NULL) {
        CFRelease(source);
    }
    if (createdImage == NULL) {
        handler(nil, [NSError errorWithDomain:CDRQuickLookErrorDomain
                                         code:21
                                     userInfo:@{NSLocalizedDescriptionKey:
                                         @"A miniatura incorporada não pôde ser decodificada."}]);
        return;
    }

    id imageObject = CFBridgingRelease(createdImage);
    CGSize imageSize = CGSizeMake(CGImageGetWidth((__bridge CGImageRef)imageObject),
                                  CGImageGetHeight((__bridge CGImageRef)imageObject));
    CGSize contextSize = CDRAspectFit(imageSize, request.maximumSize);

    QLThumbnailReply *reply = [QLThumbnailReply
        replyWithContextSize:contextSize
        drawingBlock:^BOOL(CGContextRef context) {
            CGImageRef image = (__bridge CGImageRef)imageObject;
            CGContextSetInterpolationQuality(context, kCGInterpolationHigh);
            CGContextDrawImage(context, CGRectMake(0, 0, contextSize.width, contextSize.height), image);
            return YES;
        }];
    reply.extensionBadge = @"CDR";
    handler(reply, nil);
}

@end
