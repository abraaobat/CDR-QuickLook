#import <AppKit/AppKit.h>
#import <Foundation/Foundation.h>

static int RunTask(NSString *executable, NSArray<NSString *> *arguments, NSString **capturedOutput) {
    NSTask *task = [[NSTask alloc] init];
    task.executableURL = [NSURL fileURLWithPath:executable];
    task.arguments = arguments;
    NSPipe *pipe = [NSPipe pipe];
    task.standardOutput = pipe;
    task.standardError = pipe;

    NSError *launchError = nil;
    if (![task launchAndReturnError:&launchError]) {
        if (capturedOutput != NULL) {
            *capturedOutput = launchError.localizedDescription;
        }
        return -1;
    }
    [task waitUntilExit];
    NSData *data = [[pipe fileHandleForReading] readDataToEndOfFile];
    if (capturedOutput != NULL) {
        *capturedOutput = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] ?: @"";
    }
    return task.terminationStatus;
}

static BOOL RegisterExtension(NSString *path, NSString *identifier, NSMutableArray<NSString *> *problems) {
    NSString *output = nil;
    int addStatus = RunTask(@"/usr/bin/pluginkit", @[@"-a", path], &output);
    if (addStatus != 0) {
        [problems addObject:[NSString stringWithFormat:@"%@ (registro: %@)", identifier, output ?: @""]];
        return NO;
    }
    int enableStatus = RunTask(@"/usr/bin/pluginkit", @[@"-e", @"use", @"-i", identifier], &output);
    if (enableStatus != 0) {
        [problems addObject:[NSString stringWithFormat:@"%@ (ativação: %@)", identifier, output ?: @""]];
        return NO;
    }
    return YES;
}

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        BOOL headless = NO;
        for (int index = 1; index < argc; index++) {
            if (strcmp(argv[index], "--headless-install") == 0) {
                headless = YES;
            }
        }

        NSString *plugins = [NSBundle.mainBundle.bundlePath stringByAppendingPathComponent:@"Contents/PlugIns"];
        NSString *preview = [plugins stringByAppendingPathComponent:@"CDRPreview.appex"];
        NSString *thumbnail = [plugins stringByAppendingPathComponent:@"CDRThumbnail.appex"];
        NSMutableArray<NSString *> *problems = [NSMutableArray array];

        BOOL previewOK = RegisterExtension(preview, @"com.abraaobat.cdrquicklook.preview", problems);
        BOOL thumbnailOK = RegisterExtension(thumbnail, @"com.abraaobat.cdrquicklook.thumbnail", problems);
        RunTask(@"/usr/bin/qlmanage", @[@"-r", @"cache"], NULL);
        RunTask(@"/usr/bin/killall", @[@"Finder"], NULL);

        BOOL success = previewOK && thumbnailOK;
        if (headless) {
            fprintf(stdout, "%s\n", success
                    ? "CDR QuickLook extensions registered and enabled."
                    : problems.description.UTF8String);
            return success ? 0 : 1;
        }

        [NSApplication sharedApplication];
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = success ? @"CDR QuickLook instalado" : @"CDR QuickLook precisa de atenção";
        alert.informativeText = success
            ? @"As extensões de miniatura e preview CDR foram registradas e ativadas. O Finder foi atualizado. Selecione um arquivo .cdr e pressione a barra de espaço."
            : [NSString stringWithFormat:@"A instalação foi concluída, mas houve falha ao registrar uma extensão:\n\n%@",
                                                [problems componentsJoinedByString:@"\n"]];
        alert.alertStyle = success ? NSAlertStyleInformational : NSAlertStyleWarning;
        [alert addButtonWithTitle:@"OK"];
        [alert runModal];
        return success ? 0 : 1;
    }
}
