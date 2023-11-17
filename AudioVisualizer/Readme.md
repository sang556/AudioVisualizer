#  <#Title#>

- (void)applicationWillTerminate:(NSNotification*)notification{
   // store your data here
   NSLog(@"--------------ViewController applicationWillTerminate");
}

//程序退出时执行
[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationWillTerminate:) name:UIApplicationWillTerminateNotification object:nil];
