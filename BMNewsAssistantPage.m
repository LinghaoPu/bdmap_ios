//
//  BMNewsAssistantPage.m
//  basicmap
//
//  Created by Yonkie on 16/3/11.
//  Copyright © 2016年 baidu. All rights reserved.
//  出行早知道主页面

#import "BMNewsAssistantPage.h"
#import "BMToModuleWebPageData.h"
#import "BMOpenApiManager.h"
#import "BMNewsAssistantHeaderView.h"
#import "BMNewsAssistantFooterView.h"
#import "BMNewsAssistantWeatherCell.h"
#import "BMNewsAssistantTravelCell.h"
#import "BMNewsAssistantTravelCellHeaderView.h"
#import "BMNewsAssistantTravelCellFooterView.h"
#import "NetworkModel.h"
#import "BMTravelEntity.h"
#import "BMNewsAssistantTableViewCell.h"
#import "BMNewsAssistantRequest.h"
#import "BMCustomShowMessage.h"
#import "BMMapStatusModel.h"
#import "BMNewsSnapShotMapManager.h"
#import "BMUtilMacro.h"

#define kNavigationBackBtnTag 300

#define WEATHER @"BMNewsAssistantWeatherCell"
#define ROUTE @"BMNewsAssistantTrafficCell"
#define INFO @"BMNewsAssistantTravelCell"
#define TRAVELHEADER @"BMNewsAssistantTravelHeaderCell"
#define TRAVELFOOTER @"BMNewsAssistantTravelFooterCell"
#define kSnapMapImageId @"SnapMapImageId"   //截图的任务id


static const CGFloat kHeaderViewHeight = 127.5;

static const CGFloat kBMAssistantFooterViewHeight = 82.5f;

@interface BMNewsAssistantPage () < BMNewsAssistantDelegate,
                                    UITableViewDataSource,
                                    UITableViewDelegate,
                                    UIAlertViewDelegate,
                                    BMNewsSnapShotMapManagerDelegate>

{
    NSArray* _dataArray;
    BMTravelEntity* _entity;
    TaskResult* _result;
    
}
@property (nonatomic, strong) BMNewsAssistantHeaderView* headView;

@property (nonatomic, strong) UITableView* tableView;

@property (nonatomic, strong) BMNewsAssistantRequest *requestNewsAssistant;

@property (nonatomic, strong) NSString *cityID;



@end
 

@implementation BMNewsAssistantPage

#pragma mark - LifeCycle
- (id)init
{
    if (self = [super init]) {
        [self setAnimateType:UINavigatorAnimateState_Enter animateType:UINavigatorAnimateType_Slide_From_Right];
        self.pageName = @"BMNewsAssistantPage";
    }
    return self;
}

- (UIStatusBarStyle)preferredStatusBarStyle
{
    return UIStatusBarStyleDefault;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view.
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(void)pageCreate:(Intent *)intent
{
    [super pageCreate:intent];

    [self initData:intent];
    [[BMNewsSnapShotMapManager shareInstance] setDelegate:self];
    //TODO: 清空页面栈回到主图区
    
    //对服务端的数据预处理
   // [self preProcessData];
    
   // [self initTestData];

    [self configUI];
}

-(void)pageStart
{
    [super pageStart];
    //-->离线用户行为统计   
    [BMStatisticsTool addActionLog:@"UserMsgCenterPG.firstPageShow"];
    //-->离线用户行为统计
    [_tableView reloadData];
    //初始化一些数据,测试用
}

- (void)initData:(Intent *)intent
{
    _cityID =  @"0";
    //测试
    //NSDictionary* tempdictuser = @{@"from":@"key"};
    //intent.userinfo = tempdictuser;
   // [intent.userinfo setValue:@"OpenApi" forKey:@"from"];
   // [intent.userinfo setValue:@"111" forKey:@"cityid"];
    //
    _entity = [BMTravelEntity defaultInstance];
    if (intent.userinfo[@"from"]&&[intent.userinfo[@"from"] isEqualToString:@"OpenApi"]){//from OpenApi
        if (intent.userinfo[@"cityid"]){
            //弹出dialog,等待用户确认
            NSInteger ctid = [[BMMapStatusModel getShareInstance] getLocalCityId];
            _cityID = intent.userinfo[@"cityid"];
            if (ctid == intent.userinfo[@"cityid"]) {
               
            } else {
                NSString* cityName = [[NSString alloc] init];
                [self showAlert:cityName];
            }
            
        }
    }
    else
    {
        NSInteger ctid = [[BMMapStatusModel getShareInstance] getLocalCityId];
        if (ctid <= 0) {
            return ;
        }
        _cityID = [NSString stringWithFormat:@"%ld", (long)ctid];
    }

    
    if ([[NetworkModel getNetworkModelInstance] isCurrentNetworkReachable]){
        if (!_requestNewsAssistant) {
            self.requestNewsAssistant = [[BMNewsAssistantRequest alloc] init];
            _requestNewsAssistant.delegate = self;
        }
        
        __weak BMNewsAssistantRequest *weakRequest = _requestNewsAssistant;
        [[CustomShowMessage getInstance] showWaitingIndicator:DEALING_WITH_IMAGES_WAITING_INDICATOR
                                             withCancelMethod:^{
                                                 [weakRequest cancleRequest];
                                             }];

        [_requestNewsAssistant requestNewsAssistant:_cityID];
    }else{
        //网络错误
        [[CustomShowMessage getInstance] showNotificationMessage:@"网络不可用，请检查网络"];
    }
}

#pragma mark BMNewsAssistantDelegate

- (void)requestNewsAssistantInfo:(BMTravelEntity *)infos isSuccess:(BOOL)isSuccess errorCode:(NSInteger)errorCode{
    [[CustomShowMessage getInstance] hideWaitingIndicator];
    if (isSuccess) {
        _entity = infos;
        [self preProcessData];
        //[self initTestData];
    }else{
        //服务端 更新失败
        [[CustomShowMessage getInstance] showNotificationMessage:@"数据获取失败"];
    }
}

- (TaskParam*)prepareSnapShot:(BMTravelEntity*)entity
{
    TaskParam* task = [[TaskParam alloc] init];
    task.identity = kSnapMapImageId;
    task.cityId = (int)[[BMMapStatusModel getShareInstance] getLocalCityId];
    task.imageSize = CGSizeMake(296, 200);
    task.type = entity.route.tag;
    //homeInfo;    // 示例: @{@"name":@"家", @"lat":@"纬度", @"lng":@"经度"}
    task.homeInfo = @{@"name":kindOfString(entity.route.location.home.name), @"lat":@(entity.route.location.home.lat),
                      @"lng":@(entity.route.location.home.lng)};
    task.companyInfo = @{@"name":kindOfString(entity.route.location.company.name), @"lat":@(entity.route.location.company.lat),
                         @"lng":@(entity.route.location.company.lng)};
    return task;
}


- (void)preProcessData
{
    _dataArray = [[NSArray alloc] init];
    //对获取的数据进行预处理
    //_entity = [BMTravelEntity defaultInstance];
    
//构造这样的数据结构  构成一个9元数组，数组内每个元素都是一个字典
//天气cell cellModel:cell类型 title:卡片名称（天气、空气、预警） value:对应的数值   detail:描述   actionUrl:
//路况cell cellModel:cell类型 title:路况  value:拥堵情况      home:家地址  company:公司地址  actionUrl:
//咨询cell  cellModel:cell类型    title:主标题    subtitle:副标题   time:时间
    NSMutableArray* tempArray = [[NSMutableArray alloc] init];
    
    //天气卡片
    if (_entity.weather.weatherInfo) {
        NSDictionary* dict1 = @{
                                @"cellModel":WEATHER,
                                @"title"    :@"天气",
                                @"value"    :_entity.weather.weatherInfo.temp,
                                @"detail"   :_entity.weather.weatherInfo.desc,
                                @"actionUrl":_entity.weather.weatherInfo.link
                                };
        [tempArray addObject:dict1];
    }
    
    if (_entity.weather.warnInfo) {
        NSDictionary* dict2 = @{
                                @"cellModel":WEATHER,
                                @"title"    :@"预警",
                                @"value"    :_entity.weather.warnInfo.type,
                                @"detail"   :_entity.weather.warnInfo.desc,
                                @"actionUrl":_entity.weather.warnInfo.link
                                };
        [tempArray addObject:dict2];
    }

    if (_entity.weather.aqiInfo) {
        NSDictionary* dict3 = @{
                                @"cellModel":WEATHER,
                                @"title"    :@"空气",
                                @"value"    :[NSString stringWithFormat:@"%d",_entity.weather.aqiInfo.pm25],
                                @"detail"   :_entity.weather.aqiInfo.desc,
                                @"actionUrl":_entity.weather.aqiInfo.link
                                };
        [tempArray addObject:dict3];
    }
    
    //路况卡片
    if (_entity.route) {
        NSDictionary* dict4 = @{
                                @"cellModel":ROUTE,
                                @"title"    :@"路况",
                                @"entity"   :_entity.route,
                                @"nonLocal" :_entity.nonlocal
                                };
        [tempArray addObject:dict4];
    }
    

    
    NSDictionary* dict5 = @{
                           @"cellModel":TRAVELHEADER,
                           @"title"    :@"咨询头部",
                           @"value"    :@"",
                           };
    [tempArray addObject:dict5];
    
    if (_entity.info) {
        for (NSInteger i = 0; i < _entity.info.infos.count; i++) {
            NSString* isLast = @"NO";
            BMTravelInfomationInfoEntity* en  = [_entity.info infosAtIndex:i];
            if (i == _entity.info.infos.count - 1) {
                isLast = @"YES";
            }
            NSDictionary* tempDict = @{@"cellModel" :INFO,
                                       @"title"     :en.title, //en.title
                                       @"subtitle"  :en.detail,//en.detail
                                       @"time"      :en.update, //en.update
                                       @"isLast"    :isLast
                                       };
            [tempArray addObject:tempDict];
        }        
    }
    
    NSDictionary* dictLast = @{
                               @"cellModel":TRAVELFOOTER,
                               @"title"    :@"咨询尾部",
                               @"value"    :@"",
                               };
    [tempArray addObject:dictLast];
    
    _dataArray = tempArray;
    
    [_tableView reloadData];
    
    TaskParam* task = [self prepareSnapShot:_entity];
    [[BMNewsSnapShotMapManager shareInstance] appendSnapShotTask:task];
    [[BMNewsSnapShotMapManager shareInstance] startSnapShotMapImage];
}


- (NSArray *)getInfoArray:(BMTravelInfomationEntity *)info{
    NSArray* tempArray = [[NSArray alloc] init];
    NSMutableArray* dataArray = [[NSMutableArray alloc] init];
    for (NSInteger i = 0; i < info.infos.count; i++) {
        NSString* isLast = @"NO";
        BMTravelInfomationInfoEntity* en  = [info infosAtIndex:i];
        if (i == info.infos.count - 1) {
            isLast = @"YES";
        }
        NSDictionary* tempDict = @{@"cellModel" :INFO,
                                   @"title"     :en.title,
                                   @"subtitle"  :en.detail,
                                   @"time"      :en.update,
                                   @"isLast"    :isLast
                                   };
        [dataArray addObject:tempDict];
    }
    
    tempArray = dataArray;
    return tempArray;
}

- (void)initTestData
{
    //天气+路况数据是一个四元素数组
    
        NSDictionary* tempAndWeatherDic = @{
                                @"cellModel":WEATHER,
                                @"title"    :@"天气",
                                @"value"    :_entity.weather.weatherInfo.temp,
                                @"detail"   :_entity.weather.weatherInfo.desc
                                };
    

    //每个row，对应一个字典，row名：title ； 值：value ; 描述：detail
   // NSDictionary* tempAndWeatherDic = @{@"cellModel":WEATHER,@"title":@"天气",@"value":@"25℃",@"detail":@"阴有阵雨"};
    NSDictionary* airAndLimit = @{@"cellModel":WEATHER,@"title":@"空气",@"value":@"54",@"detail":@"今日限行"};
    NSDictionary* warning = @{@"cellModel":WEATHER,@"title":@"预警",@"value":@"大雾",@"detail":@"黄色预警，能见度低"};
//    NSArray* array1 = @[tempAndWeatherDic,airAndLimit,warning];
//    NSDictionary* dict1 = @{
//                            @"cellModel":WEATHER,
//                            @"data":     array1
//                            };
    //路况的字典不一样
    NSDictionary* trafficState = @{@"cellModel":ROUTE,@"title":@"路况",@"value":@"非常拥堵",@"home":@"奎科大厦1楼",@"company":@"奎科大厦3楼"};
//    NSArray* array2 = @[trafficState];
//    NSDictionary* dict2 = @{
//                            @"cellModel":ROUTE,
//                            @"data":    array2
//                            };
    
    NSDictionary* dictBefore3 = @{
                                  @"cellModel":TRAVELHEADER,
                                  @"data":    @"travelHead"
                                  };

    NSDictionary* msg1 = @{@"cellModel":INFO,@"title":@"高速公路好",@"subtitle":@"为什么高速公路叫高速公路呢我也真是醉了呵呵呵呵呵",@"time":@"X小时",@"isLast":@"NO"};
    NSDictionary* msg2 = @{@"cellModel":INFO,@"title":@"高速公路好",@"subtitle":@"为什么高速公路叫高速公路呢我也我也我也我也我也我也我也我也我也我也我也我也我也真是醉了",@"time":@"Y小时",@"isLast":@"NO"};
    NSDictionary* msg3 = @{@"cellModel":INFO,@"title":@"高速公路好",@"subtitle":@"为什么高速公路叫高速公路呢",@"time":@"Z小时",@"isLast":@"YES"};
    
    NSDictionary* dictAfter3 = @{
                                 @"cellModel":TRAVELFOOTER,
                                 @"data"     :@"travelFoot"
                                 };
    
    _dataArray = [[NSArray alloc] initWithObjects:tempAndWeatherDic, airAndLimit, warning, trafficState,dictBefore3 ,msg1,msg2,msg3,dictAfter3 ,nil];
    //_dataArray = @[dict1,dict2,dict3];

    [_tableView reloadData];

}

-(void)pageStop
{
    [super pageStop];
}

-(void)pageDestroy
{
    [super pageDestroy];

}

- (void)dealloc
{
    _tableView.delegate = nil;
    _tableView.dataSource = nil;
    [BMNewsSnapShotMapManager shareInstance].delegate = nil;
}

#pragma mark - 界面配置
- (void)configUI
{
    
    self.view.backgroundColor = DEFAULT_PAGE_BACKGROUND;
    CGRect rect = [[UIApplication sharedApplication] statusBarFrame];
    CGRect rc = self.view.bounds;
    rc.origin.y = rect.size.height;
    self.tableView = [[UITableView alloc] initWithFrame:rc style:UITableViewStylePlain];
    _tableView.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
    _tableView.backgroundColor = DEFAULT_PAGE_BACKGROUND;
    _tableView.delegate = self;
    _tableView.dataSource = self;
    _tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.showsVerticalScrollIndicator = YES;
    self.tableView.indicatorStyle = UIScrollViewIndicatorStyleBlack;
    
    _headView = [[BMNewsAssistantHeaderView alloc] initWithFrame:[self CGRectMakeAutoSize:CGRectMake(0, 0, 320, kHeaderViewHeight)]];
    [_headView setHeadViewData:_entity.header];
    _tableView.tableHeaderView = _headView;
    
    _tableView.tableFooterView = [[BMNewsAssistantFooterView alloc] initWithFrame:CGRectMake(0, _tableView.frame.origin.y - kBMAssistantFooterViewHeight, IPHONE_SCREEN_WIDTH, kBMAssistantFooterViewHeight)];
    
   // _tableView.tableHeaderView.backgroundColor = [UIColor redColor];
    
    [self.view addSubview:_tableView];
    
    [self configNaviBar];
    self.animateViews = [NSArray arrayWithObjects:[self getNavigationBar], _tableView, nil];
    
}

- (void)configNaviBar
{
    [self setNavigationBarHidden: NO];
    [self setNavigationBarStyle: NavigationStyleTransparent];
    [self addBackButtonWithType: NavigationBackTypeWhiteArrow];
   // [self setNavigationBarTitle:@"出行早知道" position:NavigationCenterPosition];
    [self bringNavigationViewInFront];
}

- (void)showAlert:(NSString *)cityName{
    
    BaseAlertView* alert = [[BaseAlertView alloc] initWithTitle:@""
                                                        message:@"定位到您在XX市，需要切换至XX市吗？"
                                                       delegate:self
                                              cancelButtonTitle:@"取消"
                                              otherButtonTitles:@"确定",nil];
    alert.tag = 1234;
    [alert show];
}

#pragma mark - 事件交互
- (void)onNavigationBackButton
{
    [self finish];
}


# pragma mark - AlertView按键响应
- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex{
    if (alertView.tag == 1234) {
        if (0 == buttonIndex) {
            
        } else if(1 == buttonIndex){
            NSInteger ctid = [[BMMapStatusModel getShareInstance] getLocalCityId];
            if (ctid <= 0) {
                return ;
            }
            _cityID = [NSString stringWithFormat:@"%ld", (long)ctid];
        }
    }
}

#pragma mark - 详情页跳转
- (void)gotoDetailPage:(NSString*)acturl
{
    if (acturl.length <= 0) return;
    
    NSURL* actionUrl = [NSURL URLWithString:acturl];
    if (nil == actionUrl) { //没有URL编码
        
        NSArray *array = [acturl componentsSeparatedByString:@"?"];
        if (array.count >= 1) {
            
            NSString *hostUrl = [array objectAtIndex:0];
            NSMutableString* str = [NSMutableString stringWithFormat:@"%@?", hostUrl];
            if (array.count > 1) {
                
                NSString *query = [array objectAtIndex:1];
                NSArray *queryArray = [query componentsSeparatedByString:@"&"];
                BOOL isfirst = YES;
                for (NSString *item in queryArray) {
                    NSString *encodeValue = (NSString *)
                    CFBridgingRelease(CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault,
                                                                              (CFStringRef)item,
                                                                              NULL,
                                                                              (CFStringRef)@"!*'();:@&+$,/?%#[]",
                                                                              kCFStringEncodingUTF8));;
                    if (isfirst) {
                        isfirst = NO;
                        [str appendString:encodeValue];
                    }else {
                        [str appendFormat:@"&%@", encodeValue];
                    }
                }
            }
            actionUrl = [NSURL URLWithString:str];
        }
    }
    
    if (nil == actionUrl) return;
    
    if ([actionUrl.scheme isEqualToString:@"http"]) { //进入壳浏览器
        
        //        NSString *url=[actionUrl.query stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        BMToModuleWebPageData* param = [[BMToModuleWebPageData alloc]init];
        param.moduleURL = actionUrl.absoluteString;//[BMUtilUrl encodeRequestUrl:[url substringFromIndex:5] phoneInfo:YES];
        param.moduleType = 0;
        Intent *it = [Intent intentWithPageClassName:@"ModuleWebViewPage"];
        NSDictionary *userInfo = [[NSDictionary alloc]initWithObjectsAndKeys:param,@"BMToModuleWebPageData", nil];
        it.userinfo = userInfo;
        [[UIPageNavigator getInstance] pushPage:it];
        
    } else if ([actionUrl.scheme isEqualToString:@"baidumap"]) { //调起组件或基线
        if ([actionUrl.host hasPrefix:@"map"]) {
            // 7.8版本添加的容错，之前的版本，若url里面没有“？”，会导致协议解析失败
            NSString *urlString = nil;
            NSString *oldUrlStr = actionUrl.absoluteString;
            NSString *noPop = [NSString stringWithFormat:@"%@=%@", BMOPENAPI_POP_ROOT_KEY, BMOPENAPI_NOT_POP_ROOT_VALUE];
            if ([oldUrlStr rangeOfString:@"?"].location != NSNotFound) {
                urlString = [NSString stringWithFormat:@"%@&%@", oldUrlStr, noPop];
            }else {
                urlString = [NSString stringWithFormat:@"%@?%@", oldUrlStr, noPop];
            }
            
            NSURL *newURL = [NSURL URLWithString:urlString];
            
            [[BMOpenApiManager shareInstance] openURL:newURL];
        }
    }
}

#pragma mark - UITableViewDelegate
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    //实际应该根据data的数量来，但是此时暂时设置为只有
    return [_dataArray count];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return 1;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    
    NSDictionary* tempdic = [_dataArray objectAtIndex:indexPath.section];
    NSString* cellId = [tempdic objectForKey:@"cellModel"];
    
    BMNewsAssistantTableViewCell* cell = [tableView dequeueReusableCellWithIdentifier:cellId];
    
    if (!cell) {
        cell = [[NSClassFromString(cellId) alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellId];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
    }
    //NSDictionary* data = [[NSDictionary alloc] init];
    [cell setData:tempdic];
    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSDictionary* temp = [_dataArray objectAtIndex:indexPath.section];
    NSString* cellModel = [[NSString alloc] initWithString:[temp objectForKey:@"cellModel"]];
    
    if ([cellModel isEqualToString:INFO]) {
        NSString* text = [temp objectForKey:@"subtitle"];
        if (text.length != 0) {
            return [BMNewsAssistantTravelCell heightOfCellByText:text isLast:[temp objectForKey:@"isLast"]];
        } else {
            return 0;
        }
    } else {
        return [NSClassFromString(cellModel) heightOfCell];
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    return 0;
    
    
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section
{
    return 0;
}

- (nullable UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    UIView *sHeadView = [[UIView alloc] initWithFrame: CGRectMake(0.0f, 0.0f, IPHONE_SCREEN_WIDTH, 0)];
    sHeadView.backgroundColor = [UIColor redColor];
    sHeadView.userInteractionEnabled = NO;
    return sHeadView;
}

- (nullable UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section
{
    UIView *sFootView = [[UIView alloc] initWithFrame: CGRectMake(0.0f, 0.0f, IPHONE_SCREEN_WIDTH, 0)];
    sFootView.backgroundColor = [UIColor clearColor];
    sFootView.userInteractionEnabled = NO;
    return sFootView;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSDictionary* temp = [_dataArray objectAtIndex:indexPath.section];
    NSString* acturl =[temp valueForKey:@"actionUrl"];
    [self gotoDetailPage:acturl];
    
}



# pragma mark - UIScrollViewDelegate
- (void)scrollViewDidZoom:(UIScrollView *)scrollView{
    BaseNavigationView* naviView = [self getNavigationBar];
    BaiDubutton* leftBtn = (BaiDubutton *)[naviView viewWithTag:kNavigationLabelTag];
    if (scrollView.contentOffset.y > kHeaderViewHeight) {
        
    }
}




# pragma mark - ImageAutoSize
- (CGRect)CGRectMakeAutoSize:(CGRect)frame{
    //frame的宽度和高度都是以UE给的为准，宽度为320
    CGRect rect;
    rect.origin.x = frame.origin.x;
    rect.origin.y = frame.origin.y;
    rect.size.width = frame.size.width * (IPHONE_SCREEN_WIDTH / 320);
    rect.size.height = frame.size.height * (IPHONE_SCREEN_WIDTH / 320);
    return rect;
}

#pragma mark -  BMNewsSnapShotMapManagerDelegate
//驾车路线请求成功后回调
- (void)onLayerDataLoadFinished:(TaskParam*)param result:(TaskResult*)resultObj
{
    _result = [[BMNewsSnapShotMapManager shareInstance] getTaskResult:kSnapMapImageId];
    NSMutableArray* tempArray = [[NSMutableArray alloc] init];
    for (int i = 0 ; i < _dataArray.count; i++) {
        NSDictionary* dict = [_dataArray objectAtIndex:i];
        if ([dict[@"cellModel"] isEqualToString:ROUTE]) {
            NSDictionary* dictt = @{
                                    @"cellModel":ROUTE,
                                    @"title"    :@"路况",
                                    @"entity"   :_entity.route,
                                    @"nonLocal" :_entity.nonlocal,
                                    @"result"   :_result
                                    };
            [tempArray addObject:dictt];
        } else {
            [tempArray addObject:dict];
        }
    }
    
    _dataArray = tempArray;
    [_tableView reloadData];

    
    
}

//截图回调
- (void)onSnapShotResult:(TaskParam*)param result:(TaskResult*)resultObj
{

}

//截图失败回调
- (void)onSnapShotFailed:(TaskParam*)param reason:(NSError*)error
{

}

@end
