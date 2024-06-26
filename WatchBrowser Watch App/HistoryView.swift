//
//  HistoryView.swift
//  WatchBrowser Watch App
//
//  Created by WindowsMEMZ on 2023/5/2.
//

import SwiftUI
import AuthenticationServices

struct HistoryView: View {
    var selectionHandler: ((String) -> Void)?
    @AppStorage("isHistoryRecording") var isHistoryRecording = true
    @AppStorage("AllowCookies") var AllowCookies = false
    @AppStorage("LabTabBrowsingEnabled") var labTabBrowsingEnabled = false
    @AppStorage("UserPasscodeEncrypted") var userPasscodeEncrypted = ""
    @AppStorage("UsePasscodeForLockHistories") var usePasscodeForLockHistories = false
    @State var isLocked = true
    @State var passcodeInputCache = ""
    @State var isSettingPresented = false
    @State var isStopRecordingPagePresenting = false
    @State var histories = [String]()
    @State var historyTitles = [String: String]()
    @State var isSharePresented = false
    @State var isNewBookmarkPresented = false
    @State var isClearOptionsPresented = false
    @State var shareLink = ""
    @State var searchText = ""
    @State var newBookmarkName = ""
    @State var newBookmarkLink = ""
    @State var selectedEmptyAction = 0
    @State var isAdditionalCloseAllTabs = false
    var body: some View {
        if isLocked && !userPasscodeEncrypted.isEmpty && usePasscodeForLockHistories {
            PasswordInputView(text: $passcodeInputCache, placeholder: "输入密码", dismissAfterComplete: false) { pwd in
                if pwd.md5 == userPasscodeEncrypted {
                    isLocked = false
                } else {
                    tipWithText("密码错误", symbol: "xmark.circle.fill")
                }
                passcodeInputCache = ""
            }
            .navigationBarBackButtonHidden()
        } else {
            List {
                if selectionHandler == nil {
                    Section {
                        Toggle("History.record", isOn: $isHistoryRecording)
                            .accessibilityIdentifier("RecordHistoryToggle")
                            .onChange(of: isHistoryRecording, perform: { e in
                                if !e {
                                    isStopRecordingPagePresenting = true
                                }
                            })
                            .sheet(isPresented: $isStopRecordingPagePresenting, onDismiss: {
                                histories = UserDefaults.standard.stringArray(forKey: "WebHistory") ?? [String]()
                            }, content: {CloseHistoryTipView()})
                    }
                }
                Section {
                    if isHistoryRecording {
                        if histories.count != 0 {
                            TextField("\(Image(systemName: "magnifyingglass")) 搜索", text: $searchText)
                            ForEach(0...histories.count - 1, id: \.self) { i in
                                if searchText.isEmpty || histories[i].contains(searchText) {
                                    Button(action: {
                                        if let selectionHandler {
                                            selectionHandler(histories[i])
                                        } else {
                                            if histories[i].hasPrefix("file://") {
                                                AdvancedWebViewController.shared.present("", archiveUrl: URL(string: histories[i])!)
                                            } else if histories[i].hasSuffix(".mp4") {
                                                videoLinkLists = [histories[i]]
                                                pShouldPresentVideoList = true
                                            } else {
                                                AdvancedWebViewController.shared.present(histories[i].urlDecoded().urlEncoded())
                                            }
                                        }
                                    }, label: {
                                        if let showName = historyTitles[histories[i]], !showName.isEmpty {
                                            if histories[i].hasPrefix("https://www.bing.com/search?q=")
                                                || histories[i].hasPrefix("https://www.baidu.com/s?wd=")
                                                || histories[i].hasPrefix("https://www.google.com/search?q=")
                                                || histories[i].hasPrefix("https://www.sogou.com/web?query=") {
                                                Label(showName, systemImage: "magnifyingglass")
                                            } else if histories[i].hasPrefix("file://") {
                                                Label(showName, systemImage: "archivebox")
                                            } else {
                                                Label(showName, systemImage: "globe")
                                            }
                                        } else {
                                            if histories[i].hasPrefix("https://www.bing.com/search?q=") {
                                                Label(String(histories[i].urlDecoded().dropFirst(30)), systemImage: "magnifyingglass")
                                            } else if histories[i].hasPrefix("https://www.baidu.com/s?wd=") {
                                                Label(String(histories[i].urlDecoded().dropFirst(27)), systemImage: "magnifyingglass")
                                            } else if histories[i].hasPrefix("https://www.google.com/search?q=") {
                                                Label(String(histories[i].urlDecoded().dropFirst(32)), systemImage: "magnifyingglass")
                                            } else if histories[i].hasPrefix("https://www.sogou.com/web?query=") {
                                                Label(String(histories[i].urlDecoded().dropFirst(32)), systemImage: "magnifyingglass")
                                            } else if histories[i].hasPrefix("file://") {
                                                Label(
                                                    String(histories[i].split(separator: "/").last!.split(separator: ".")[0])
                                                        .replacingOccurrences(of: "{slash}", with: "/")
                                                        .base64Decoded() ?? "[解析失败]",
                                                    systemImage: "archivebox"
                                                )
                                            } else if histories[i].hasSuffix(".mp4") {
                                                Label(histories[i], systemImage: "film")
                                            } else {
                                                Label(histories[i], systemImage: "globe")
                                            }
                                        }
                                    })
                                    .privacySensitive()
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        Button(role: .destructive, action: {
                                            histories.remove(at: i)
                                            UserDefaults.standard.set(histories, forKey: "WebHistory")
                                        }, label: {
                                            Image(systemName: "bin.xmark.fill")
                                        })
                                    }
                                    .swipeActions(edge: .leading) {
                                        Button(action: {
                                            if let showName = historyTitles[histories[i]], !showName.isEmpty {
                                                newBookmarkName = showName
                                            } else {
                                                newBookmarkName = ""
                                            }
                                            newBookmarkLink = histories[i].urlDecoded().urlEncoded()
                                            isNewBookmarkPresented = true
                                        }, label: {
                                            Image(systemName: "bookmark")
                                        })
                                        Button(action: {
                                            shareLink = histories[i].urlDecoded().urlEncoded()
                                            isSharePresented = true
                                        }, label: {
                                            Image(systemName: "square.and.arrow.up.fill")
                                        })
                                    }
                                }
                            }
                        } else {
                            Text("History.nothing")
                                .foregroundColor(.gray)
                        }
                    } else {
                        Text("History.not-recording")
                            .foregroundColor(.gray)
                    }
                }
            }
            .sheet(isPresented: $isSharePresented, content: {ShareView(linkToShare: $shareLink)})
            .sheet(isPresented: $isNewBookmarkPresented, content: {AddBookmarkView(initMarkName: $newBookmarkName, initMarkLink: $newBookmarkLink)})
            .sheet(isPresented: $isClearOptionsPresented) {
                NavigationStack {
                    List {
                        Section {
                            Button(action: {
                                selectedEmptyAction = 0
                            }, label: {
                                HStack {
                                    Text("上一小时")
                                        .foregroundStyle(Color.white)
                                    Spacer()
                                    if selectedEmptyAction == 0 {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(Color.blue)
                                    }
                                }
                            })
                            Button(action: {
                                selectedEmptyAction = 1
                            }, label: {
                                HStack {
                                    Text("今天")
                                        .foregroundStyle(Color.white)
                                    Spacer()
                                    if selectedEmptyAction == 1 {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(Color.blue)
                                    }
                                }
                            })
                            Button(action: {
                                selectedEmptyAction = 2
                            }, label: {
                                HStack {
                                    Text("昨天和今天")
                                        .foregroundStyle(Color.white)
                                    Spacer()
                                    if selectedEmptyAction == 2 {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(Color.blue)
                                    }
                                }
                            })
                            Button(action: {
                                selectedEmptyAction = 3
                            }, label: {
                                HStack {
                                    Text("所有历史记录")
                                        .foregroundStyle(Color.white)
                                    Spacer()
                                    if selectedEmptyAction == 3 {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(Color.blue)
                                    }
                                }
                            })
                        } header: {
                            Text("清除时间段")
                                .textCase(nil)
                        }
                        if labTabBrowsingEnabled && !(UserDefaults.standard.stringArray(forKey: "CurrentTabs") ?? [String]()).isEmpty {
                            Section {
                                Toggle("关闭所有标签页", isOn: $isAdditionalCloseAllTabs)
                            } header: {
                                Text("附加选项")
                                    .textCase(nil)
                            }
                        }
                        Section {
                            Button(role: .destructive, action: {
                                if isAdditionalCloseAllTabs {
                                    UserDefaults.standard.set([String](), forKey: "CurrentTabs")
                                }
                                if selectedEmptyAction == 3 {
                                    histories.removeAll()
                                    historyTitles.removeAll()
                                    UserDefaults.standard.set(histories, forKey: "WebHistory")
                                    UserDefaults.standard.set(historyTitles, forKey: "WebHistoryNames")
                                    isClearOptionsPresented = false
                                    return
                                }
                                if let recordTimePair = UserDefaults.standard.dictionary(forKey: "WebHistoryRecordTimes") as? [String: Double] {
                                    let currentTime = Date.now.timeIntervalSince1970
                                    var maxTimeDiff = 0.0
                                    switch selectedEmptyAction {
                                    case 0:
                                        maxTimeDiff = 3600
                                    case 1:
                                        maxTimeDiff = 86400
                                    case 2:
                                        maxTimeDiff = 172800
                                    default:
                                        break
                                    }
                                    for i in 0..<histories.count {
                                        if let time = recordTimePair[histories[i]], currentTime - time <= maxTimeDiff {
                                            histories[i] = "[History Remove Token]"
                                        }
                                    }
                                    histories.removeAll(where: { element in
                                        if element == "[History Remove Token]" {
                                            return true
                                        }
                                        return false
                                    })
                                }
                                UserDefaults.standard.set(histories, forKey: "WebHistory")
                                isClearOptionsPresented = false
                            }, label: {
                                Text("清除历史记录")
                                    .bold()
                            })
                        }
                    }
                    .navigationTitle("清除历史记录")
                }
            }
            .toolbar {
                if #available(watchOS 10, *), !histories.isEmpty && isHistoryRecording {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(role: .destructive, action: {
                            isClearOptionsPresented = true
                        }, label: {
                            Image(systemName: "arrow.up.trash.fill")
                                .foregroundColor(.red)
                        })
                    }
                }
            }
            .onAppear {
                histories = UserDefaults.standard.stringArray(forKey: "WebHistory") ?? [String]()
                historyTitles = (UserDefaults.standard.dictionary(forKey: "WebHistoryNames") as? [String: String]) ?? [String: String]()
            }
        }
    }
}

func RecordHistory(_ inp: String, webSearch: String, showName: String? = nil) {
    var fullHistory = UserDefaults.standard.stringArray(forKey: "WebHistory") ?? [String]()
    if let lstf = fullHistory.first {
        guard lstf != inp && lstf != GetWebSearchedURL(inp, webSearch: webSearch, isSearchEngineShortcutEnabled: false) else {
            return
        }
    }
    if inp.isURL() || inp.hasPrefix("file://") {
        fullHistory = [inp] + fullHistory
        if let showName {
            var tmpDic = (UserDefaults.standard.dictionary(forKey: "WebHistoryNames") as? [String: String]) ?? [String: String]()
            tmpDic.updateValue(showName, forKey: inp)
            UserDefaults.standard.set(tmpDic, forKey: "WebHistoryNames")
        }
        var tmpDic = (UserDefaults.standard.dictionary(forKey: "WebHistoryRecordTimes") as? [String: Double]) ?? [String: Double]()
        tmpDic.updateValue(Date.now.timeIntervalSince1970, forKey: inp)
        UserDefaults.standard.set(tmpDic, forKey: "WebHistoryRecordTimes")
    } else {
        let rurl = GetWebSearchedURL(inp, webSearch: webSearch, isSearchEngineShortcutEnabled: false)
        fullHistory = [rurl] + fullHistory
        if let showName {
            var tmpDic = (UserDefaults.standard.dictionary(forKey: "WebHistoryNames") as? [String: String]) ?? [String: String]()
            tmpDic.updateValue(showName, forKey: rurl)
            UserDefaults.standard.set(tmpDic, forKey: "WebHistoryNames")
        }
        var tmpDic = (UserDefaults.standard.dictionary(forKey: "WebHistoryRecordTimes") as? [String: Double]) ?? [String: Double]()
        tmpDic.updateValue(Date.now.timeIntervalSince1970, forKey: inp)
        UserDefaults.standard.set(tmpDic, forKey: "WebHistoryRecordTimes")
    }
    UserDefaults.standard.set(fullHistory, forKey: "WebHistory")
}

struct historiesettingView: View {
    @AppStorage("isHistoryRecording") var isHistoryRecording = true
    @State var isClosePagePresented = false
    var body: some View {
        List {
            Text("History.settings")
                .fontWeight(.bold)
                .font(.system(size: 20))
            Section {
                Toggle("History.record", isOn: $isHistoryRecording)
                    .onChange(of: isHistoryRecording, perform: { e in
                        if !e {
                            isClosePagePresented = true
                        }
                    })
                    .sheet(isPresented: $isClosePagePresented, content: {CloseHistoryTipView()})
            }
            Section {
                Button(role: .destructive, action: {
                    UserDefaults.standard.set([String](), forKey: "WebHistory")
                }, label: {
                    Text("History.clear")
                })
            }
        }
    }
}

struct CloseHistoryTipView: View {
    @Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>
    var body: some View {
        ScrollView {
            Text("History.turn-off")
                .fontWeight(.bold)
                .font(.system(size: 20))
            Text("History.clear-history-at-the-same-time")
            Button(role: .destructive, action: {
                UserDefaults.standard.set([String](), forKey: "WebHistory")
                self.presentationMode.wrappedValue.dismiss()
            }, label: {
                Label("History.clear", systemImage: "trash.fill")
            })
            Button(role: .cancel, action: {
                self.presentationMode.wrappedValue.dismiss()
            }, label: {
                Label("History.save", systemImage: "arrow.down.doc.fill")
            })
        }
    }
}

struct HistoryView_Previews: PreviewProvider {
    static var previews: some View {
        HistoryView()
    }
}
