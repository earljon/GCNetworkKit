//
//  TwitterTableViewController.m
//
/* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */
//
//  Copyright 2012 Giulio Petek
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//
/* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */

#import "TwitterTableViewController.h"
#import "GCNetworkKit.h"

/* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */
// TwitterTableViewController
/* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */

@implementation TwitterTableViewController
@synthesize requestHash = _requestHash;
@synthesize tweets = _tweets;

#pragma mark - Twitter

- (void)proceedTweets:(NSData *)data {
    
#if __IPHONE_OS_VERSION_MAX_ALLOWED < 50000
    __unsafe_unretained TwitterTableViewController *weakReference = self;
#else
    __weak TwitterTableViewController *weakReference = self;
#endif
    // Transform JSON response to something useful
    TransformJSONDataToNSObject(data, ^(id object, NSError *error){
        NSDictionary *results = (NSDictionary *)object;
        
        // We are not loading anymore
        weakReference.requestHash = nil; 

        // Error
        if (error && error.code != GCNetworkRequestUserDidCancelErrorCode) {
            NSLog(@"An error occured: %@", error);
            return;
        }
        
        weakReference.tweets = [[results objectForKey:@"results"] mutableCopy];
        [weakReference.tableView reloadData];
    });
}

- (void)loadTweets {   
    
#if __IPHONE_OS_VERSION_MAX_ALLOWED < 50000
    __unsafe_unretained TwitterTableViewController *weakReference = self;
#else
    __weak TwitterTableViewController *weakReference = self;
#endif    

    // Build GCNetworkRequest
    GCNetworkRequest *request = [GCNetworkRequest requestWithURL:[NSURL URLWithString:@"http://search.twitter.com/search.json"]];
    
    // Add a query value to the request (q = Search Term)
    [request setQueryValue:@"apple" forKey:@"q"];
    
    // Set completion Handler
    request.completionHandler = ^(NSData *responseData){ 
        [weakReference proceedTweets:responseData];
    };
        
    // Add request to the queue and return its hash
    self.requestHash = [[GCNetworkRequestQueue sharedQueue] addRequest:request];
}

- (void)cancelLoadingTweets {
    
    // Check if we have something to cancel
    if (!self.requestHash)
        return;
    
    // Cancel the request with our hash
    [[GCNetworkRequestQueue sharedQueue] cancelRequestWithHash:self.requestHash];
}


#pragma mark - View

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Non concurrent => Serialized
    [[GCNetworkRequestQueue sharedQueue] setMaxConcurrentOperations:1];


// Various tests
// --------------------------------------------------------------------------------------------------

    BOOL tinygrabTest = NO;
    BOOL imageTest = NO;
    BOOL podcastTest = NO;
    BOOL shortenTest = NO;
    
    // Tinygrab test
    if (tinygrabTest)
        [TwitterTableViewController uploadImage:[UIImage imageNamed:@"desk.png"] 
                                       username:@"" // Your E-Mail here 
                                    andPassword:@""]; // Your PW here

    // Load Image test
    if (imageTest) {
        NSURL *imageURL = [NSURL URLWithString:@"https://twimg0-a.akamaihd.net/profile_images/1255560250/eightbit-29a8fc2e-8e30-4320-a42f-50173babdef0.png"];
        [TwitterTableViewController loadImageAtURL:imageURL];
    }
    
    // Load podcast test
    if (podcastTest) {
        NSURL *podcastURL = [NSURL URLWithString:@"http://cl.ly/0F1x3q3y0X3m0d0G1Y31"];
        [TwitterTableViewController downloadPodcastAtURL:podcastURL];
    }

    // Shorten URL
    if (shortenTest) {
         NSURL *longURL = [NSURL URLWithString:@"https://github.com/Gi-lo/CCWebViewController"];
        [TwitterTableViewController shortenURL:longURL];
    }
    
// --------------------------------------------------------------------------------------------------
    
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    [self cancelLoadingTweets];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    [self loadTweets];
}

#pragma mark - Tests

+ (void)downloadPodcastAtURL:(NSURL *)url {
    GCNetworkDownloadRequest *request = [GCNetworkDownloadRequest requestWithURL:url];
    request.autoDeleteTMPFile = NO;
    request.loadWhileScrolling = YES;
    request.continueInBackground = YES;
    request.progressHandler = ^(CGFloat progress){
        NSLog(@"Progress on downloading podcast: %f.", progress);
    };
    request.downloadCompletionHandler = ^(NSString *filePath){
        NSLog(@"Downlaoded Podcast and saved at: %@.", filePath);
    };
    [request start]; 
}

+ (void)loadImageAtURL:(NSURL *)url {    
    GCNetworkImageRequest *request = [GCNetworkImageRequest requestWithURL:url];
    request.imageCompletionHandler = ^(UIImage *image){
        NSLog(@"Downlaoded Image: %@.", image);
    };
    [request start]; 
}

+ (void)uploadImage:(UIImage *)image username:(NSString *)username andPassword:(NSString *)password {
    NSData *imageData = UIImageJPEGRepresentation(image, 0.8f);
    
    // Tinygrab
    NSURL *url = [NSURL URLWithString:@"http://tinygrab.com/api/v3.php?m=grab/upload"];
    NSString *usernameKey = @"email";
    NSString *passwordwKey = @"passwordhash";
    
    GCNetworkFormRequest *request = [GCNetworkFormRequest requestWithURL:url];
    [request addPostString:username forKey:usernameKey];
    [request addPostString:[password md5Hash] forKey:passwordwKey];
    [request addData:imageData forKey:@"upload" contentType:@"image/jpeg"];
    request.responseHandler = ^(NSHTTPURLResponse *response){
        NSLog(@"Uplaoded grab to URL: %@", [[response allHeaderFields] objectForKey:@"X-Grab-URL"]);
    };
    request.uploadProgressHandler = ^(CGFloat progress){
        NSLog(@"Progress on uploading grab: %f.", progress);
    };
    
    [request start];
}

+ (void)shortenURL:(NSURL *)url {
    NSURL *apiURL = [NSURL URLWithString:@"http://tinyurl.com/api-create.php"];

    GCNetworkRequest *request = [GCNetworkRequest requestWithURL:apiURL];
    [request setQueryValue:[url absoluteString] forKey:@"url"];
    request.completionHandler = ^(NSData *responseData){
        TransformNSDataToNSString(responseData, NSUTF8StringEncoding, ^(NSString *string){
            NSLog(@"Shortened URL: %@ to: %@.", url, string); 
        });
    };
    [request start];
}

#pragma mark - Datasource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.tweets.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {    
    
    static NSString *CellIdentifier = @"Cell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIdentifier];        
        cell.detailTextLabel.numberOfLines = 4;
    }
    
    NSDictionary *tweet = [self.tweets objectAtIndex:indexPath.row];
    cell.textLabel.text = [tweet objectForKey:@"from_user"];
    cell.detailTextLabel.text = [tweet objectForKey:@"text"];
    
    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 100.0f;
}

#pragma mark Memory

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];

    [self cancelLoadingTweets];
}

- (void)dealloc {
    [self cancelLoadingTweets];
}

@end
