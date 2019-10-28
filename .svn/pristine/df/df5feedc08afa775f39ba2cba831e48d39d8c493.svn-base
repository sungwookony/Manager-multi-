//
//  LogToFile.hpp
//  CrashReport
//
//  Created by WooSeok on 12. 4. 9..
//  Copyright (c) 2012년 INVERSE Studio. All rights reserved.
//

#ifndef CrashReport_LogToFile_hpp
#define CrashReport_LogToFile_hpp

#import <Foundation/Foundation.h>
//#import <UIKit/UIDevice.h>

#import <execinfo.h>
#import <iostream>
#import <fstream>
#import <time.h>

#define LOG_BUFFER_SIZE (1024*128)

namespace INVERSE_STUDIO
{
	namespace LOG
	{
		inline std::string NSStringToString(NSString* str)
		{
			char szLog[LOG_BUFFER_SIZE] = { 0, };
			@try
			{
				[str getCString:szLog maxLength:sizeof(szLog)-1 encoding:NSUTF8StringEncoding];
			}
			@catch (NSException *exception)
			{
				NSLog(@"%@", exception.description);
			}
			return szLog;
		}
		
		inline void LogToFile(const char* log)
		{
			try
			{
				time_t rawtime;
				struct tm * ptm;			
				time ( &rawtime );
				ptm = gmtime ( &rawtime );
				
				char szTime[64] = {0,};
				sprintf(szTime, "%d-%02d-%02dT%02d-%02d-%02d", 1900+ptm->tm_year, 1+ptm->tm_mon, ptm->tm_mday, ptm->tm_hour, ptm->tm_min, ptm->tm_sec);
				std::string strTime(szTime);
				
				static std::ofstream output;
				if ( false == output.is_open() )
				{
					NSString* pathDoc = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
					char szDoc[512] = { 0, };
					[pathDoc getCString:szDoc maxLength:512 encoding:NSUTF8StringEncoding];
					std::string pathLog = std::string(szDoc) + std::string("/log-") + strTime + std::string(".LOG");
					output.open(pathLog.c_str());
					if ( true == output.good() )
					{
						output << std::endl;					
//						output << INVERSE_STUDIO::LOG::NSStringToString( [UIDevice currentDevice].systemName ) << std::endl;
//						output << INVERSE_STUDIO::LOG::NSStringToString( [UIDevice currentDevice].systemVersion ) << std::endl;
//						output << INVERSE_STUDIO::LOG::NSStringToString( [UIDevice currentDevice].model ) << std::endl;					
						output << INVERSE_STUDIO::LOG::NSStringToString( [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleDisplayName"] ) << std::endl;
						output << INVERSE_STUDIO::LOG::NSStringToString( [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"] ) << std::endl;
						output << std::endl;
					}
					NSLog(@"%s log file open: %s", __FUNCTION__, pathLog.c_str());
				}
				
				if ( true == output.good() )
				{
					output << std::endl;				
					output << strTime;
					output << std::endl;
					output << log;
					output << std::endl;
				}
			}
			catch(...)
			{
				NSLog(@"%s excepted", __FUNCTION__);
			}
		}
		
		inline void LogToFile(NSString* log)
		{
			INVERSE_STUDIO::LOG::LogToFile(INVERSE_STUDIO::LOG::NSStringToString(log).c_str());
		}
	}
}
#endif
