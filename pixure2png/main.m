//
//  main.m
//  pixure2png
//
//  Created by Steven Troughton-Smith on 12/12/2016.
//  Copyright © 2016 High Caffeine Content. All rights reserved.
//

@import Foundation;
@import AppKit;

@implementation NSColor (HexColor)
/* From http://stackoverflow.com/a/8697241 */

+ (NSColor*)colorWithHexColorString:(NSString*)inColorString
{
	NSColor* result = nil;
	unsigned colorCode = 0;
	unsigned char redByte, greenByte, blueByte;
	
	if (nil != inColorString)
	{
		NSScanner* scanner = [NSScanner scannerWithString:inColorString];
		(void) [scanner scanHexInt:&colorCode]; // ignore error
	}
	redByte = (unsigned char)(colorCode >> 16);
	greenByte = (unsigned char)(colorCode >> 8);
	blueByte = (unsigned char)(colorCode); // masks off high bits
	
	result = [NSColor
			  colorWithCalibratedRed:(CGFloat)redByte / 0xff
			  green:(CGFloat)greenByte / 0xff
			  blue:(CGFloat)blueByte / 0xff
			  alpha:1.0];
	return result;
}
@end

void print_usage()
{
	printf("Usage: pixure2png input.svg output.png\n");
}

int main(int argc, const char * argv[])
{
	@autoreleasepool
	{
		
		if (argc < 3 || strlen(argv[1]) == 0 || strlen(argv[2]) == 0)
		{
			print_usage();
			exit(-1);
		}
		
		NSString *inputFilename = [NSString stringWithUTF8String:argv[1]];
		NSString *outputFilename = [NSString stringWithUTF8String:argv[2]];
		
		if (![[inputFilename pathExtension] isEqualToString:@"svg"] || ![[outputFilename pathExtension] isEqualToString:@"png"])
		{
			print_usage();
			exit(-1);
		}
		
		NSError *error = nil;
		NSXMLDocument *doc = [[NSXMLDocument alloc] initWithContentsOfURL:[NSURL fileURLWithPath:inputFilename] options:NSXMLNodePrettyPrint error:&error];
		
		if (error)
		{
			NSLog(@"%@", error);
			exit(-1);
		}
		
		
		NSArray *viewBox = [[[[doc rootElement] attributeForName:@"viewBox"] stringValue] componentsSeparatedByString:@" "];
		CGSize viewBoxSize = CGSizeMake([viewBox[2] floatValue], [viewBox[3] floatValue]);
		
		NSImage *image = [[NSImage alloc] initWithSize:viewBoxSize];
		[image setFlipped:YES];
		
		[image lockFocus];
		
		for (NSXMLElement *layer in [doc rootElement].children)
		{
			
			NSString *display = [[layer attributeForName:@"display"] stringValue];
			
			if ([display isEqualToString:@"none"])
			{
				// Skip hidden layers
				continue;
			}
			
			CGFloat opacity = 1.0;
			NSString *opacityString = [[layer attributeForName:@"opacity"] stringValue];
			
			if (opacityString)
			{
				opacity = [opacityString floatValue];
			}
			
			for (NSXMLElement *child in layer.children)
			{
				CGFloat x = [[[child attributeForName:@"x"] stringValue] floatValue];
				CGFloat y = [[[child attributeForName:@"y"] stringValue] floatValue];
				CGFloat w = [[[child attributeForName:@"width"] stringValue] floatValue];
				CGFloat h = [[[child attributeForName:@"height"] stringValue] floatValue];
				NSString *fill = [[[child attributeForName:@"fill"] stringValue] substringFromIndex:1];
				
				NSColor *fillColor = [[NSColor colorWithHexColorString:fill] colorWithAlphaComponent:opacity];
				
				
				[fillColor set];
				[NSBezierPath fillRect:CGRectMake(x, y, w, h)];
				
			}
		}
		
		[image unlockFocus];
		
		NSBitmapImageRep *rep = [[NSBitmapImageRep alloc]
								 initWithBitmapDataPlanes:NULL
								 pixelsWide:viewBoxSize.width
								 pixelsHigh:viewBoxSize.height
								 bitsPerSample:8
								 samplesPerPixel:4
								 hasAlpha:YES
								 isPlanar:NO
								 colorSpaceName:NSCalibratedRGBColorSpace
								 bytesPerRow:0
								 bitsPerPixel:0];
		[rep setSize:viewBoxSize];
		
		NSGraphicsContext *ctx = [NSGraphicsContext graphicsContextWithBitmapImageRep:rep];
		
		[NSGraphicsContext saveGraphicsState];
		[NSGraphicsContext setCurrentContext:ctx];
		
		CGContextSetInterpolationQuality(ctx.CGContext, kCGInterpolationNone);
		[image drawInRect:NSMakeRect(0, 0, viewBoxSize.width, viewBoxSize.height) fromRect:NSZeroRect operation:NSCompositingOperationSourceOver fraction:1.0];
		[NSGraphicsContext restoreGraphicsState];
		
		NSData *imageData = [rep representationUsingType:NSPNGFileType properties:@{}];
		if (![imageData writeToFile:outputFilename atomically:YES])
		{
			printf("Unable to write output file.\n");
			exit(-1);
		}
	}
	return 0;
}
