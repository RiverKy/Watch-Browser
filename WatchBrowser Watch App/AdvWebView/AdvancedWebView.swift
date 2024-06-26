//
//  AdvancedWebView.swift
//  WatchBrowser Watch App
//
//  Created by memz233 on 2024/4/20.
//

import UIKit
import SwiftUI
import Dynamic
import SwiftSoup
import AuthenticationServices

fileprivate var webViewController = AdvancedWebViewController()
var videoLinkLists = [String]()
var imageLinkLists = [String]()

struct AdvancedWebView: View {
    var body: some View {
        TabView {
            ZStack {
                Text("T")
                    .zIndex(999)
            }
            .tag(1)
            List {
                
            }
            .tag(2)
        }
    }
}

class AdvancedWebViewController {
    public static let shared = AdvancedWebViewController()
    
    var currentTabIndex: Int?
    
    var webViewHolder = Dynamic.UIView()
    var menuController = Dynamic.UIViewController()
    var menuView = Dynamic.UIScrollView()
    var vc = Dynamic.UIViewController()
    var loadProgressView = Dynamic.UIProgressView()
    
    @AppStorage("AllowCookies") var allowCookies = true
    @AppStorage("RequestDesktopWeb") var requestDesktopWeb = false
    @AppStorage("UseBackforwardGesture") var useBackforwardGesture = true
    @AppStorage("KeepDigitalTime") var keepDigitalTime = false
    @AppStorage("ShowFastExitButton") var showFastExitButton = false
    @AppStorage("WebSearch") var webSearch = "必应"
    @AppStorage("isHistoryRecording") var isHistoryRecording = true
    @AppStorage("isUseOldWebView") var isUseOldWebView = false
    @AppStorage("CustomUserAgent") var customUserAgent = ""
    
    var currentUrl = ""
    var isVideoChecking = false
    
    @discardableResult
    func present(_ iurl: String = "", archiveUrl: URL? = nil, presentController: Bool = true) -> Dynamic {
        if iurl.isEmpty && archiveUrl == nil {
            Dynamic.UIApplication.sharedApplication.keyWindow.rootViewController.presentViewController(vc, animated: true, completion: nil)
            registerVideoCheckTimer()
            return Dynamic(webViewObject)
        }
        
        let url = URL(string: iurl) ?? archiveUrl!

        if isUseOldWebView {
            // rdar://FB268002071845
            if presentController {
                let session = ASWebAuthenticationSession(url: url, callbackURLScheme: nil) { _, _ in
                    return
                }
                session.prefersEphemeralWebBrowserSession = !allowCookies
                session.start()
                
                if isHistoryRecording {
                    RecordHistory(iurl, webSearch: webSearch)
                }
            }
            
            return Dynamic.WKWebView()
        }
        
        let moreButton = makeUIButton(title: .Image(UIImage(systemName: "ellipsis.circle")!),
                                      frame: CGRect(x: 10, y: 10, width: 30, height: 30),
                                      selector: "menuButtonClicked",
                                      accessibilityIdentifier: "WebMenuButton")
        
        let sb = WKInterfaceDevice.current().screenBounds
        
        let wkWebView = Dynamic.WKWebView()
        wkWebView.setFrame(sb)
        if customUserAgent.isEmpty {
            if requestDesktopWeb {
                wkWebView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) DarockBrowser/\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as! String).\(Bundle.main.infoDictionary?["CFBundleVersion"] as! String)"
            } else {
                wkWebView.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 10_2 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) DarockBrowser/\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as! String).\(Bundle.main.infoDictionary?["CFBundleVersion"] as! String)"
            }
        } else {
            wkWebView.customUserAgent = customUserAgent
        }
        wkWebView.allowsBackForwardNavigationGestures = useBackforwardGesture
        wkWebView.configuration.websiteDataStore.httpCookieStore.setCookiePolicy(
            allowCookies
            ? Dynamic.WKCookiePolicyAllow
            : Dynamic.WKCookiePolicyDisllow,
            completionHandler: {} as @convention(block) () -> Void
        )

        // Load Progress Bar
        loadProgressView.frame = CGRect(x: 0, y: 0, width: sb.width, height: 20)
        loadProgressView.progressTintColor = UIColor.blue
        
        webViewHolder = Dynamic.UIView()
        webViewHolder.addSubview(wkWebView)
        
        if keepDigitalTime {
            let timeBackground = Dynamic.UIView()
            timeBackground.setBackgroundColor(UIColor.black)
            timeBackground.setFrame(CGRect(x: sb.width - 50, y: 0, width: 70, height: 30))
            webViewHolder.addSubview(timeBackground)
        }
        
        if showFastExitButton {
            let fastExitButton = makeUIButton(title: .Image(UIImage(systemName: "escape")!),
                                              frame: CGRect(x: 40, y: 10, width: 30, height: 30),
                                              tintColor: .red,
                                              selector: "DismissWebView")
            webViewHolder.addSubview(fastExitButton)
        }
        webViewHolder.addSubview(moreButton)
        webViewHolder.addSubview(loadProgressView)
        
        vc = Dynamic.UIViewController()
        vc.view = webViewHolder

        if presentController {
            Dynamic.UIApplication.sharedApplication.keyWindow.rootViewController.presentViewController(vc, animated: true, completion: nil)
        }
        webViewParentController = vc.asObject!
        
        if let archiveUrl {
            wkWebView.loadData(NSData(contentsOf: archiveUrl), MIMEType: "application/x-webarchive", characterEncodingName: "utf-8", baseURL: archiveUrl)
        } else {
            wkWebView.loadRequest(URLRequest(url: url))
        }
        
        updateMenuController()
        
        Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [self] _ in
            if pIsMenuButtonDown {
                pIsMenuButtonDown = false
                vc.presentViewController(menuController, animated: true, completion: nil)
                CheckWebContent()
            }
            if pMenuShouldDismiss {
                pMenuShouldDismiss = false
                dismissControllersOnWebView()
            }
            if wkWebView.isLoading.asBool ?? false {
                loadProgressView.setProgress(Float(wkWebView.estimatedProgress.asDouble ?? 0.0), animated: true)
            }
        }
        if presentController {
            registerVideoCheckTimer()
        }
        
        webViewObject = wkWebView.asObject!
        WebExtension.setWebViewDelegate()
        
        return wkWebView
    }
    func recover(from ref: TabWebKitReference) {
        webViewHolder = ref.webViewHolder
        menuController = ref.menuController
        menuView = ref.menuView
        vc = ref.vc
        loadProgressView = ref.loadProgressView
        webViewObject = ref.webViewObject
        webViewParentController = ref.webViewParentController
        
        Dynamic.UIApplication.sharedApplication.keyWindow.rootViewController.presentViewController(vc, animated: true, completion: nil)
    }
    func storeTab(in allTabs: [String], at index: Int? = nil) {
        let recoverReference = TabWebKitReference(webViewHolder: webViewHolder,
                                                  menuController: menuController,
                                                  menuView: menuView,
                                                  vc: vc,
                                                  loadProgressView: loadProgressView,
                                                  webViewObject: webViewObject,
                                                  webViewParentController: webViewParentController)
        var updateUrl = currentUrl
        if let index {
            updateUrl = allTabs[index]
        }
        tabCurrentReferences.updateValue(recoverReference, forKey: updateUrl)
        var tabsCopy = allTabs
        if let index {
            tabsCopy[index] = updateUrl
        } else {
            tabsCopy.append(updateUrl)
        }
        UserDefaults.standard.set(tabsCopy, forKey: "CurrentTabs")
        currentTabIndex = nil
    }
    
    func updateMenuController(rebindController: Bool = true) {
        // Action Menu
        for subview in menuView.subviews.asArray! {
            Dynamic(subview).removeFromSuperview()
        }
        let sb = WKInterfaceDevice.current().screenBounds
        menuView.contentSize = CGSizeMake(sb.width, sb.height + 200)
        
        // Buttons in Menu
        var menuButtonYOffset: CGFloat = 30
        
        // Close Button
        let closeButton = makeUIButton(title: .Image(UIImage(systemName: "xmark")!),
                                       frame: .init(x: 20, y: 20, width: 25, height: 25),
                                       backgroundColor: .gray.opacity(0.5),
                                       tintColor: .white,
                                       selector: "DismissMenu")
        menuView.addSubview(closeButton)
        
        let urlText = Dynamic.UILabel()
        if let url = Dynamic(webViewObject).URL.asObject {
            urlText.text = (url as! NSURL).absoluteString!
            urlText.setFrame(getMiddleRect(y: menuButtonYOffset, height: 60))
            urlText.setFont(UIFont(name: "Helvetica", size: 10))
            urlText.setNumberOfLines(4)
            menuView.addSubview(urlText)
            menuButtonYOffset += 45
        }

        if !videoLinkLists.isEmpty {
            let playButton = makeUIButton(title: .text(String(localized: "播放网页视频")),
                                          frame: getMiddleRect(y: menuButtonYOffset, height: 40),
                                          backgroundColor: .gray.opacity(0.5),
                                          tintColor: .white,
                                          selector: "PresentVideoList")
            menuView.addSubview(playButton)
            menuButtonYOffset += 60
        } else if isVideoChecking {
            let checkIndicator = Dynamic.UIActivityIndicatorView()
            checkIndicator.frame = getMiddleRect(y: menuButtonYOffset, height: 40)
            menuView.addSubview(checkIndicator)
            checkIndicator.startAnimating()
            menuButtonYOffset += 60
        } else {
            let tipText = Dynamic.UILabel()
            tipText.text = "无可播放的视频"
            tipText.setFrame(getMiddleRect(y: menuButtonYOffset, height: 60))
            tipText.setFont(UIFont(name: "Helvetica", size: 12))
            menuView.addSubview(tipText)
            menuButtonYOffset += 60
        }
        if !imageLinkLists.isEmpty {
            if menuButtonYOffset > 100 {
                menuButtonYOffset -= 15
            }
            let imageButton = makeUIButton(title: .text(String(localized: "查看网页图片")),
                                           frame: getMiddleRect(y: menuButtonYOffset, height: 40),
                                           backgroundColor: .gray.opacity(0.5),
                                           tintColor: .white,
                                           selector: "PresentImageList")
            menuView.addSubview(imageButton)
            menuButtonYOffset += 60
        }
        
        let reloadButton = makeUIButton(title: .text(String(localized: "重新载入")),
                                        frame: getMiddleRect(y: menuButtonYOffset, height: 40),
                                        backgroundColor: .gray.opacity(0.5),
                                        tintColor: .white,
                                        selector: "WKReload")
        menuView.addSubview(reloadButton)
        menuButtonYOffset += 60
        
        if Dynamic(webViewObject).canGoBack.asBool ?? false {
            let previousButton = makeUIButton(title: .text(String(localized: "上一页")),
                                              frame: getMiddleRect(y: menuButtonYOffset, height: 40),
                                              backgroundColor: .gray.opacity(0.5),
                                              tintColor: .white,
                                              selector: "WKGoBack")
            menuView.addSubview(previousButton)
            menuButtonYOffset += 50
        }
        if Dynamic(webViewObject).canGoForward.asBool ?? false {
            let forwardButton = makeUIButton(title: .text(String(localized: "下一页")),
                                             frame: getMiddleRect(y: menuButtonYOffset, height: 40),
                                             backgroundColor: .gray.opacity(0.5),
                                             tintColor: .white,
                                             selector: "WKGoForward")
            menuView.addSubview(forwardButton)
            menuButtonYOffset += 50
        }
        
        let exitButton = makeUIButton(title: .text(String(localized: "退出")),
                                      frame: getMiddleRect(y: menuButtonYOffset, height: 40),
                                      backgroundColor: .gray.opacity(0.5),
                                      tintColor: .red,
                                      selector: "DismissWebView",
                                      accessibilityIdentifier: "WebViewDismissButton")
        menuView.addSubview(exitButton)
        menuButtonYOffset += 70
        
        if !currentUrl.isEmpty && !currentUrl.hasPrefix("file://") {
            let archiveButton = makeUIButton(title: .text(String(localized: "存储本页离线归档")),
                                             frame: getMiddleRect(y: menuButtonYOffset, height: 40),
                                             backgroundColor: .gray.opacity(0.5),
                                             tintColor: .white,
                                             selector: "ArchiveCurrentPage")
            menuView.addSubview(archiveButton)
            menuButtonYOffset += 50
        }

        if rebindController {
            menuController.view = menuView
        }
    }
    
    func makeUIButton(
        title: TextOrImage,
        frame: CGRect,
        backgroundColor: Color? = nil,
        tintColor: Color? = nil,
        cornerRadius: CGFloat = 8,
        selector: String? = nil,
        accessibilityIdentifier: String? = nil
    ) -> Dynamic {
        var resultButton = Dynamic.UIButton.buttonWithType(1)
        switch title {
        case .text(let text):
            resultButton.setTitle(text, forState: 0)
        case .Image(let image):
            resultButton.setImage(image, forState: 0)
        }
        resultButton.setFrame(frame)
        if let backgroundColor {
            resultButton.setBackgroundColor(UIColor(backgroundColor))
        }
        if let tintColor {
            resultButton.setTintColor(UIColor(tintColor))
        }
        resultButton.layer.cornerRadius = cornerRadius
        if let selector {
            resultButton = Dynamic(WebExtension.getBindedButton(withSelector: selector, button: resultButton.asObject!))
        }
        if let accessibilityIdentifier {
            resultButton.accessibilityIdentifier = accessibilityIdentifier
        }
        return resultButton
    }
    func dismissController(_ controller: Dynamic, animated: Bool = true) {
        controller.dismissModalViewController(animated: animated)
    }
    func dismissControllersOnWebView(animated: Bool = true) {
        vc.dismissViewControllerAnimated(animated, completion: nil)
    }
    func registerVideoCheckTimer() {
        videoCheckTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [self] _ in
            if let url = Dynamic(webViewObject).URL.asObject {
                let curl = (url as! NSURL).absoluteString!
                if curl != currentUrl {
                    currentUrl = curl
                    if isHistoryRecording {
                        RecordHistory(curl, webSearch: webSearch, showName: Dynamic(webViewObject).title.asString)
                    }
                }
            }
        }
    }
    
    func CheckWebContent() {
        if isVideoChecking {
            return
        }
        isVideoChecking = true
        updateMenuController()
        Dynamic(webViewObject).evaluateJavaScript("document.documentElement.outerHTML", completionHandler: { [self] obj, error in
            DispatchQueue(label: "com.darock.WatchBrowser.wt.video-check", qos: .userInitiated).async { [self] in
                if let htmlStr = obj as? String {
                    do {
                        let doc = try SwiftSoup.parse(htmlStr)
                        let videos = try doc.body()?.select("video")
                        if let videos {
                            var srcs = [String]()
                            for video in videos {
                                var src = try video.attr("src")
                                if src != "" {
                                    if src.hasPrefix("/") {
                                        if currentUrl.split(separator: "/").count < 2 {
                                            continue
                                        }
                                        src = "http://" + currentUrl.split(separator: "/")[1] + src
                                    }
                                    srcs.append(src)
                                }
                            }
                            videoLinkLists = srcs
                        }
                        let images = try doc.body()?.select("img")
                        if let images {
                            var srcs = [String]()
                            for image in images {
                                var src = try image.attr("src")
                                if src != "" {
                                    if src.hasPrefix("/") {
                                        if currentUrl.split(separator: "/").count < 2 {
                                            continue
                                        }
                                        src = "http://" + currentUrl.split(separator: "/")[1] + src
                                    }
                                    srcs.append(src)
                                }
                            }
                            imageLinkLists = srcs
                        }
                    } catch {
                        globalErrorHandler(error, at: "\(#file)-\(#function)-\(#line)")
                    }
                }
                DispatchQueue.main.async { [self] in
                    isVideoChecking = false
                    updateMenuController(rebindController: false)
                }
            }
        } as @convention(block) (Any?, (any Error)?) -> Void)
    }
    
    enum TextOrImage {
        case text(String)
        case Image(UIImage)
    }
}

func getMiddleRect(y: CGFloat, height: CGFloat) -> CGRect {
    let sb = WKInterfaceDevice.current().screenBounds
    return CGRect(x: (sb.width - (sb.width - 40)) / 2, y: y, width: sb.width - 40, height: height)
}
