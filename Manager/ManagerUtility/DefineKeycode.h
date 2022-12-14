//Communication With DC


#define SOCKET_PORT     3013
#define AUTO_SOCKET_PORT    2013



#define RESOURCE_PORT   3100
#define WDA_LOCAL_PORT  8100

#define RM_SOCKET_PORT          2014
#define DEFAULT_APPIUM_PORT     4724
#define DEFAULT_WEBKIT_PORT     27755

#define CMD_START_MAN   1
#define CMD_START_AUTO  101
#define CMD_STOP        2
#define CMD_WAKEUP      8
#define CMD_TAP         51
#define CMD_TOUCH_DOWN  52
#define CMD_TOUCH_UP    53


#define CMD_TOUCH_MOVE  54
#define CMD_SWIPE       55
#define CMD_MULTI_TOUCH_DOWN    56
#define CMD_MULTI_TOUCH_UP      57
#define CMD_MULTI_TOUCH_MOVE    58
#define CMD_HARDKEY     10
#define CMD_INSTALL     6
#define CMD_OPENURL     12
#define CMD_RES_START   14
#define CMD_RES_STOP    15
#define CMD_RES_ONCE    22
#define CMD_SETTING     20
#define CMD_KEYBOARD    19
#define CMD_LOG_START   5
#define CMD_LOG_STOP    7
#define CMD_CLEAR       13
#define CMD_INPUT_TEXT  4
#define CMD_LOCK_UNLOCK 24
#define CMD_UNINSTALL   30

#define CMD_REQ_APPLIST 306
#define CMD_REQ_DUMP    305
#define CMD_AUTO_INPUT  307
#define CMD_AUTO_SELECT 303
#define CMD_AUTO_SEARCH 304
#define CMD_AUTO_RUNAPP 316
//신한 기능 요청으로 기능 추가 앱종료
#define CMD_TERMINATE_APP 336


////////////////////////////////
#define CMD_STATUS      334
#define CMD_LIKE_SELECT 335
////////////////////////////////
#define CMD_SND_DEVICE_CHANGE   403


#define CMD_PORTRAIT        1003
#define CMD_LANDSCAPE       1004

//Communication Command For Response
#define CMD_RESPONSE            10001
#define CMD_RES_CNNT            10002
#define CMD_LOG                 10003
#define CMD_DEVICE_DISCONNECTED 22003

#define CMD_RES_NETWORK     16
#define CMD_RES_CPU         17
#define CMD_RES_MEMORY      18

#define CMD_AUTO_NETWORK     26
#define CMD_AUTO_CPU         27
#define CMD_AUTO_MEMORY      28

#define CMD_SEND_APPLIST    311

#define CMD_WHO_ARE_YOU         @"WhoAreYou"
#define CMD_CPU_ON              @"CMD_CPU_ON "          // 끝에 공백문자가 한개 있어야 함.
#define CMD_CPU_OFF             @"CMD_CPU_OFF "         // 끝에 공백문자가 한개 있어야 함.
#define CMD_MEMORY_ON           @"CMD_MEMORY_ON "       // 끝에 공백문자가 한개 있어야 함.
#define CMD_MEMORY_OFF          @"CMD_MEMORY_OFF "      // 끝에 공백문자가 한개 있어야 함.
#define CMD_NETWORK_ON          @"CMD_NETWORK_ON "      // 끝에 공백문자가 한개 있어야 함.
#define CMD_NETWORK_OFF         @"CMD_NETWORK_OFF "     // 끝에 공백문자가 한개 있어야 함.
#define CMD_CPU_ONCE            @"CMD_CPU_ONCE "     // 끝에 공백문자가 한개 있어야 함.
#define CMD_MEMORY_ONCE         @"CMD_MEMORY_ONCE "     // 끝에 공백문자가 한개 있어야 함.
#define CMD_CLOSE_APP           @"CMD_CLOSE_APP"        // App 이 종료되는 명령을 전달.
#define CMD_SAFARI              @"CMD_SAFARI"
#define CMD_RESET               @"CMD_RESET"

#define DC_PORT                 @"DC_PORT"
#define DC_PORTNO                 @"DC_PORT_NO"


#define TIMEOUT_INSTRUMENTS_CNT 30.0f
#define TIMEOUT_SEND_COMMAND    20.0f


typedef NS_ENUM(NSInteger, CONNECT_TYPE) {
    CNNT_TYPE_NONE,
    CNNT_TYPE_MAN,
    CNNT_TYPE_AUTO
};

typedef NS_ENUM(NSInteger, RESOURCE_TYPE) {
    TYPE_NETWORK = 1,
    TYPE_CPU =2,
    TYPE_MEMORY =3,
    TYPE_CPU_ONCE = 4,
    TYPE_MEMORY_ONCE = 5
};


#define HARDKEY_HOME        3
#define HARDKEY_VOL_UP      24
#define HARDKEY_VOL_DOWN    25
#define HARDKEY_POWER       26
