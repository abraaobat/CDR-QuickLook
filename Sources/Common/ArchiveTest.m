#import <Foundation/Foundation.h>
#import "CDRArchive.h"

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        if (argc != 2) {
            fprintf(stderr, "usage: cdrarchive-test file.cdr\n");
            return 64;
        }
        NSURL *url = [NSURL fileURLWithPath:[NSString stringWithUTF8String:argv[1]]];
        NSError *error = nil;
        CDRArchive *archive = [CDRArchive archiveWithURL:url error:&error];
        if (archive == nil) {
            fprintf(stderr, "%s\n", error.localizedDescription.UTF8String);
            return 1;
        }
        NSData *thumbnail = [archive thumbnailDataWithError:&error];
        printf("pages=%lu thumbnail=%lu", (unsigned long)archive.pageCount,
               (unsigned long)thumbnail.length);
        for (NSUInteger index = 0; index < archive.pageCount; index++) {
            NSData *page = [archive pageDataAtIndex:index error:&error];
            if (page == nil) {
                fprintf(stderr, " page%lu-error=%s\n", (unsigned long)(index + 1),
                        error.localizedDescription.UTF8String);
                return 1;
            }
            printf(" page%lu=%lu", (unsigned long)(index + 1), (unsigned long)page.length);
        }
        printf("\n");
        return thumbnail == nil ? 1 : 0;
    }
}
