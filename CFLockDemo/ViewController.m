//
//  ViewController.m
//  CFLockDemo
//
//  Created by wjc on 2017/4/18.
//  Copyright © 2017年 CityFire. All rights reserved.
//

#import "ViewController.h"
#import <pthread.h>
#import <libkern/OSAtomic.h>
#import <os/lock.h>

@interface ViewController ()
{
    dispatch_semaphore_t _semaphore; // 信号量
    pthread_mutex_t _mutex;   // pthread锁
}

/** 原子锁 */
@property (atomic, assign) int atomicFlag;

@property (strong) NSString *info;

@end

@implementation ViewController

__weak NSString *string_weak_ = nil;

- (void)viewDidLoad {
    [super viewDidLoad];
    
//    NSString *string = [NSString stringWithFormat:@"wangjiucheng,hello"];
//    string_weak_ = string;
    
    // 场景 2
//    @autoreleasepool {
//        NSString *string = [NSString stringWithFormat:@"wangjiucheng"];
//        string_weak_ = string;
//    }
    
    // 场景 3
    NSString *string = nil; // __strong
    @autoreleasepool {
        string = [NSString stringWithFormat:@"wangjiucheng"];
        string_weak_ = string;
    }
    
    NSLog(@"string: %@", string_weak_);
    // watchpoint set v string_weak_
    // Do any additional setup after loading the view, typically from a nib.
    /*
    NSLock *lock = [[NSLock alloc] init];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        //[lock lock];
        [lock lockBeforeDate:[NSDate date]];
        NSLog(@"需要线程同步的操作1 开始");
        sleep(2);
        NSLog(@"需要线程同步的操作1 结束");
        [lock unlock];
    });
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSLog(@"线程2");
        sleep(1);
        if ([lock tryLock]) {//尝试获取锁，如果获取不到返回NO，不会阻塞该线程
            NSLog(@"锁可用的操作");
            [lock unlock];
        }
        else {
            NSLog(@"锁不可用的操作");
        }
        NSDate *date = [[NSDate alloc] initWithTimeIntervalSinceNow:3];
        if ([lock lockBeforeDate:date]) {//尝试在未来的3s内获取锁，并阻塞该线程，如果3s内获取不到恢复线程, 返回NO,不会阻塞该线程
            NSLog(@"没有超时，获得锁");
            [lock unlock];
        }
        else {
            NSLog(@"超时，没有获得锁");
        }
    });
    
    
    // 递归锁 NSRecursiveLock实际上定义的是一个递归锁，这个锁可以被同一线程多次请求，而不会引起死锁。这主要是用在循环或递归操作中。
//    NSLock *rlock = [[NSLock alloc] init]; // 死锁 *** -[NSLock lock]: deadlock (<NSLock: 0x6000000c5780> '(null)')
    NSRecursiveLock *rlock = [[NSRecursiveLock alloc] init];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        static void (^RecursiveMethod)(int);
        RecursiveMethod = ^(int value) {
            [rlock lock];
            if (value > 0) {
                NSLog(@"value = %d", value);
                sleep(1);
                RecursiveMethod(value - 1);
            }
            [rlock unlock];
        };
        RecursiveMethod(5);
    });
    
    
    
    // NSConditionLock 条件锁
    NSConditionLock *cLock = [[NSConditionLock alloc] init];
    NSMutableArray *products = [NSMutableArray array];
    NSInteger HAS_DATA = 1;
    NSInteger NO_DATA = 0;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        while (1) {
            [cLock lockWhenCondition:NO_DATA];
            [products addObject:[[NSObject alloc] init]];
            NSLog(@"produce a product, 总量:%zi", products.count);
            [cLock unlockWithCondition:HAS_DATA];
            sleep(1);
        }
    });
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        while (1) {
            NSLog(@"wait for product");
            [cLock lockWhenCondition:HAS_DATA];
            [products removeObjectAtIndex:0];
            NSLog(@"custome a product");
            [cLock unlockWithCondition:NO_DATA];
        }
    });

     
    
    // 一种最基本的条件锁。手动控制线程wait和signal。
    NSCondition *condition = [[NSCondition alloc] init];
    NSMutableArray *products = [NSMutableArray array];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        while (1) {
            [condition lock];
            if ([products count] == 0) {
                NSLog(@"wait for product");
                [condition wait]; // 让当前线程处于等待状态
            }
            [products removeObjectAtIndex:0];
            NSLog(@"custome a product");
            [condition unlock];
        }
    });
    // [condition lock];一般用于多线程同时访问、修改同一个数据源，保证在同一时间内数据源只被访问、修改一次，其他线程的命令需要在lock 外等待，只到unlock ，才可访问
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        while (1) {
            [condition lock];
            [products addObject:[[NSObject alloc] init]];
            NSLog(@"produce a product,总量:%zi",products.count);
            [condition signal]; // CPU发信号告诉线程不用在等待，可以继续执行
            [condition unlock];
            sleep(1);
        }
    });
    
     
    
    __block pthread_mutex_t theLock;
    pthread_mutex_init(&theLock, NULL);
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        pthread_mutex_lock(&theLock);
        NSLog(@"需要线程同步的操作1 开始");
        sleep(3);
        NSLog(@"需要线程同步的操作1 结束");
        pthread_mutex_unlock(&theLock);
    });
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSLog(@"线程2");
        sleep(1);
        pthread_mutex_lock(&theLock);
//        pthread_mutex_trylock(&theLock); // 当锁已经在使用的时候，返回为EBUSY，而不是挂起等待。
//        2017-04-18 17:59:46.785 CFLockDemo[5714:824572] 需要线程同步的操作1 开始
//        2017-04-18 17:59:46.785 CFLockDemo[5714:824588] 线程2
//        2017-04-18 17:59:47.790 CFLockDemo[5714:824588] 需要线程同步的操作2
//        2017-04-18 17:59:49.788 CFLockDemo[5714:824572] 需要线程同步的操作1 结束
        NSLog(@"需要线程同步的操作2");
        pthread_mutex_unlock(&theLock);
    });
    
    */
    
    // 这是pthread_mutex为了防止在递归的情况下出现死锁而出现的递归锁。作用和NSRecursiveLock递归锁类似。
    
    __block pthread_mutex_t theLock;
    // pthread_mutex_init(&theLock, NULL); // 死锁
    pthread_mutexattr_t attr;
    pthread_mutexattr_init(&attr);
    pthread_mutexattr_settype(&attr, PTHREAD_MUTEX_RECURSIVE);
    pthread_mutex_init(&theLock, &attr);
    pthread_mutexattr_destroy(&attr);
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        static void (^RecursiveMethod)(int);
        RecursiveMethod = ^(int value) {
            pthread_mutex_lock(&theLock);
            if (value > 0) {
                NSLog(@"value = %d", value);
                sleep(1);
                RecursiveMethod(value - 1);
            }
            pthread_mutex_unlock(&theLock);
        };
        RecursiveMethod(5);
    });
    
    // OSSpinLock 自旋锁 性能最高的锁。 但是苹果工程师说已经不再安全了 google protobuf 它的缺点是当等待时会消耗大量 CPU 资源，所以它不适用于较长时间的任务。 不进入内核 所以不挂起 空转
    __block OSSpinLock tLock = OS_SPINLOCK_INIT;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        OSSpinLockLock(&tLock);
        NSLog(@"需要线程同步的操作1 开始");
        sleep(3);
        NSLog(@"需要线程同步的操作1 结束");
        OSSpinLockUnlock(&tLock);
    });
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        OSSpinLockLock(&tLock);
        sleep(1);
        NSLog(@"需要线程同步的操作2");
        OSSpinLockUnlock(&tLock);
    });
    
    // os_unfair_lock_s os_unfair_lock iOS 10.0新推出的锁，用于解决OSSpinLock优先级反转问题
    // 初始化
    os_unfair_lock_t unfairLock = &(OS_UNFAIR_LOCK_INIT);
    // 加锁
    os_unfair_lock_lock(unfairLock);
    NSLog(@"加锁1成功");
    sleep(2);
    // 解锁
    os_unfair_lock_unlock(unfairLock);
    // 尝试加锁
    BOOL b = os_unfair_lock_trylock(unfairLock);
    sleep(1);
    if (b) {
        NSLog(@"加锁2成功");
        // 解锁
        os_unfair_lock_unlock(unfairLock);
    }
    else {
        NSLog(@"加锁失败");
    }
    
    // Thread Sanitizer实现原理
    
    // Thread Sanitizer核心是 使用了Vector Clock算法
    
    // 计算机操作系统
    
//    所谓死锁： 是指两个或两个以上的进程在执行过程中，由于竞争资源或者由于彼此通信而造成的一种阻塞的现象，若无外力作用，它们都将无法推进下去。此时称系统处于死锁状态或系统产生了死锁，这些永远在互相等待的进程称为死锁进程。
//    \
//    虽然进程在运行过程中，可能发生死锁，但死锁的发生也必须具备一定的条件，死锁的发生必须具备以下四个必要条件。
//    1）互斥条件：指进程对所分配到的资源进行排它性使用，即在一段时间内某资源只由一个进程占用。如果此时还有其它进程请求资源，则请求者只能等待，直至占有资源的进程用毕释放。
//    2）请求和保持条件：指进程已经保持至少一个资源，但又提出了新的资源请求，而该资源已被其它进程占有，此时请求进程阻塞，但又对自己已获得的其它资源保持不放。
//    3）不剥夺条件：指进程已获得的资源，在未使用完之前，不能被剥夺，只能在使用完时由自己释放。
//    4）环路等待条件：指在发生死锁时，必然存在一个进程——资源的环形链，即进程集合{P0，P1，P2，···，Pn}中的P0正在等待一个P1占用的资源；P1正在等待P2占用的资源，……，Pn正在等待已被P0占用的资源。
    
//    // A
//    dispatch_async(dispatch_get_global_queue(0, 0), ^{
//        while (1) {
//            self.info = @"a";
//            NSLog(@"A--info:%@", self.info);
//        }
//    });
//    
//    // B
//    dispatch_async(dispatch_get_global_queue(0, 0), ^{
//        while (1) {
//            self.info = @"b";
//            NSLog(@"B--info:%@", self.info);
//        }
//    });
}

// autorelease 对象是被添加到了当前最近的 autoreleasepool 中的，只有当这个 autoreleasepool 自身 drain 的时候，autoreleasepool 中的 autoreleased 对象才会被 release 。
- (void)viewWillAppear:(BOOL)animated {
    // weak_clear_no_lock
    // objc_object::sidetable_clearDeallocation()
    // objc_destructInstance
    // _CFRelease
    // (anonymous namespace)::AutoreleasePoolPage::pop(void *)
    // __FBSSERIALQUEUE_IS_CALLING_OUT_TO_A_BLOCK__
    // -[FBSSerialQueue _performNext]
    // -[FBSSerialQueue _performNextFromRunLoopSource]
    
//    "__weak variable at %p holds %p instead of %p. This is probably incorrect use of objc_storeWeak() and objc_loadWeak(). Break on objc_weak_error to debug.\n"

    [super viewWillAppear:animated];
    NSLog(@"string: %@", string_weak_);
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    // Watchpoint 1 hit:
//    old value: 0x0000618000059110
//    new value: 0x0000000000000000
    NSLog(@"string: %@", string_weak_);
}

- (IBAction)didPressTestButtonAction:(id)sender {
    UIButton *btn = (UIButton *)sender;
    switch (btn.tag) {
        case 0:
            [self testLockList];
            break;
        case 1:
            [self test_dispatch_semaphore];
            break;
        case 2:
            [self testOSSpinLock];
            break;
            
        default:
            break;
    }
}

#pragma mark -

- (void)testLockList {
    CFTimeInterval timeBefore;
    CFTimeInterval timeCurrent;
    NSUInteger i;
    // 一千万次的锁操作执行
    NSUInteger count = 1000*10000;
    
    // @synchronized
    id obj = [[NSObject alloc] init];;
    timeBefore = CFAbsoluteTimeGetCurrent();
    for (i=0; i < count; i++) {
        @synchronized(obj) {
        }
    }
    timeCurrent = CFAbsoluteTimeGetCurrent();
    printf("@synchronized used : %f\n", timeCurrent-timeBefore);
    
    // NSLock
    NSLock *lock = [[NSLock alloc] init];
    timeBefore = CFAbsoluteTimeGetCurrent();
    for (i = 0; i < count; i++) {
        [lock lock];
        [lock unlock];
    }
    timeCurrent = CFAbsoluteTimeGetCurrent();
    printf("NSLock used : %f\n", timeCurrent-timeBefore);
    
    // NSRecursiveLock
    NSRecursiveLock *recursiveLock = [[NSRecursiveLock alloc] init];
    timeBefore = CFAbsoluteTimeGetCurrent();
    for(i = 0; i < count; i++){
        [recursiveLock lock];
        [recursiveLock unlock];
    }
    timeCurrent = CFAbsoluteTimeGetCurrent();
    printf("NSRecursiveLock used : %f\n", timeCurrent-timeBefore);
    
    // NSCondition
    NSCondition *condition = [[NSCondition alloc] init];
    timeBefore = CFAbsoluteTimeGetCurrent();
    for(i = 0; i < count; i++) {
        [condition lock];
        [condition unlock];
    }
    timeCurrent = CFAbsoluteTimeGetCurrent();
    printf("NSCondition used : %f\n", timeCurrent-timeBefore);
    
    // NSConditionLock
    NSConditionLock *conditionLock = [[NSConditionLock alloc]init];
    timeBefore = CFAbsoluteTimeGetCurrent();
    for(i = 0; i < count; i++) {
        [conditionLock lock];
        [conditionLock unlock];
    }
    timeCurrent = CFAbsoluteTimeGetCurrent();
    printf("NSConditionLock used : %f\n", timeCurrent-timeBefore);
    
    // pthread_mutex
    pthread_mutex_t mutex = PTHREAD_MUTEX_INITIALIZER;
    /*
     pthread_mutex_t mutex = PTHREAD_MUTEX_INITIALIZER;
     pthread_mutexattr_t attr;
     pthread_mutexattr_init(&attr);
     // 设置锁的属性为可递归
     pthread_mutexattr_settype(&attr, PTHREAD_MUTEX_RECURSIVE);
     pthread_mutex_init(&mutex, &attr);
     pthread_mutexattr_destroy(&attr);
     */
    timeBefore = CFAbsoluteTimeGetCurrent();
    for(i = 0; i < count; i++) {
        pthread_mutex_lock(&mutex);
        pthread_mutex_unlock(&mutex);
    }
    timeCurrent = CFAbsoluteTimeGetCurrent();
    printf("pthread_mutex used : %f\n", timeCurrent-timeBefore);
    
    // dispatch_semaphore
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(1);
    timeBefore = CFAbsoluteTimeGetCurrent();
    for(i = 0; i < count; i++) {
        dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
        dispatch_semaphore_signal(semaphore);
    }
    timeCurrent = CFAbsoluteTimeGetCurrent();
    printf("dispatch_semaphore used : %f\n", timeCurrent-timeBefore);
    
    // OSSpinLockLock
    OSSpinLock spinlock = OS_SPINLOCK_INIT;
    timeBefore = CFAbsoluteTimeGetCurrent();
    for(i = 0; i < count; i++) {
        OSSpinLockLock(&spinlock);
        OSSpinLockUnlock(&spinlock);
    }
    timeCurrent = CFAbsoluteTimeGetCurrent();
    printf("OSSpinLock used : %f\n", timeCurrent-timeBefore);
    
    // Atomic Flag
    timeBefore = CFAbsoluteTimeGetCurrent();
    for(i = 0; i < count; i++){
        self.atomicFlag = 1;
    }
    timeCurrent = CFAbsoluteTimeGetCurrent();
    printf("Atomic Set/Get used : %f\n", timeCurrent-timeBefore);
}

#pragma mark -

- (void)test_dispatch_semaphore {
    //主线程中
    _semaphore = dispatch_semaphore_create(1);
    
    //线程1
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        dispatch_semaphore_wait(_semaphore, DISPATCH_TIME_FOREVER);
        [self threadMethod1];
        sleep(3);
        dispatch_semaphore_signal(_semaphore);
    });
    
    //线程2
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        sleep(1);
        dispatch_semaphore_wait(_semaphore, DISPATCH_TIME_FOREVER);
        [self threadMethod2];
        dispatch_semaphore_signal(_semaphore);
    });
}

- (void)testOSSpinLock {
    //主线程中
    __block OSSpinLock spinlock = OS_SPINLOCK_INIT;
    
    //线程1
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        OSSpinLockLock(&spinlock);
        [self threadMethod1];
        sleep(3);
        OSSpinLockUnlock(&spinlock);
    });
    
    for (int i = 0; i < 10; i++) {
        //线程2
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            sleep(1);
            OSSpinLockLock(&spinlock);
            [self threadMethod2];
            OSSpinLockUnlock(&spinlock);
        });
    }
}

- (void)threadMethod1 {
    // 测试可重入性
    /*
     dispatch_semaphore_wait(_semaphore, DISPATCH_TIME_FOREVER);
     NSLog(@"%@",NSStringFromSelector(_cmd));
     dispatch_semaphore_signal(_semaphore);
     */
    NSLog(@"%@",NSStringFromSelector(_cmd));
}

- (void)threadMethod2 {
    NSLog(@"%@",NSStringFromSelector(_cmd));
}

#pragma mark -

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
