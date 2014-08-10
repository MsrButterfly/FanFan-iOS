//
//  User.swift
//  WeCenterMobile
//
//  Created by Darren Liu on 14/8/1.
//  Copyright (c) 2014年 ifLab. All rights reserved.
//

import Foundation
import CoreData

let UserModel = Model(module: "User", bundle: NSBundle.mainBundle())
let UserStrings = Msr.Data.LocalizedStrings(module: "User", bundle: NSBundle.mainBundle())

class User: NSManagedObject {
    
    @NSManaged var gender: NSNumber?
    @NSManaged var birthday: NSNumber?
    @NSManaged var jobID: NSNumber?
    @NSManaged var signature: String?
    @NSManaged var agreementCount: NSNumber?
    @NSManaged var answerFavoriteCount: NSNumber?
    @NSManaged var answerCount: NSNumber?
    @NSManaged var avatarURL: String?
    @NSManaged var followerCount: NSNumber?
    @NSManaged var followingCount: NSNumber?
    @NSManaged var friendCount: NSNumber?
    @NSManaged var id: NSNumber
    @NSManaged var markCount: NSNumber?
    @NSManaged var name: String?
    @NSManaged var questionCount: NSNumber?
    @NSManaged var thankCount: NSNumber?
    @NSManaged var topicFocusCount: NSNumber?
    
    class func clearCookies() {
        let storage = NSHTTPCookieStorage.sharedHTTPCookieStorage()
        for cookie in storage.cookies as [NSHTTPCookie] {
            storage.deleteCookie(cookie)
        }
        NSUserDefaults.standardUserDefaults().removeObjectForKey("Cookies")
        NSUserDefaults.standardUserDefaults().synchronize()
        NSURLCache.sharedURLCache().removeAllCachedResponses()
    }
    
    class func fetchUserByID(id: NSNumber, strategy: Model.Strategy, success: ((User) -> Void)?, failure: ((NSError) -> Void)?) {
        switch strategy {
        case .CacheOnly:
            fetchUserUsingCacheByID(id, success: success, failure: failure)
            break
        case .NetworkOnly:
            fetchUserUsingNetworkByID(id, success: success, failure: failure)
            break
        case .CacheFirst:
            fetchUserUsingCacheByID(id, success: success, failure: {
                error in
                self.fetchUserUsingNetworkByID(id, success: success, failure: failure)
            })
            break
        case .NetworkFirst:
            fetchUserUsingNetworkByID(id, success: success, failure: {
                error in
                self.fetchUserUsingCacheByID(id, success: success, failure: failure)
            })
            break
        default:
            break
        }
    }
    
    private class func fetchUserUsingCacheByID(id: NSNumber, success: ((User) -> Void)?, failure: ((NSError) -> Void)?) {
        let request = appDelegate.managedObjectModel.fetchRequestFromTemplateWithName("User_By_ID",
            substitutionVariables: [
                "ID": id
            ])
        var error: NSError? = nil
        let results = appDelegate.managedObjectContext.executeFetchRequest(request, error: &error) as? [User]
        if error == nil && results!.count != 0 {
            success?(results![0])
        } else {
            failure?(error != nil ? error! : NSError()) // Needs specification
        }
    }
    
    private class func fetchUserUsingNetworkByID(id: NSNumber, success: ((User) -> Void)?, failure: ((NSError) -> Void)?) {
        UserModel.GET(UserModel.URLStrings["Information"]!,
            parameters: [
                "uid": id
            ],
            success: {
                property in
                self.fetchUserUsingCacheByID(id,
                    success: {
                        user in
                        user.updateMainInformationWithProperty(property)
                        user.id = id
                        appDelegate.saveContext()
                        success?(user)
                    }, failure: {
                        error in
                        let user = Model.createManagedObjectOfClass(User.self, entityName: "User") as User
                        user.updateMainInformationWithProperty(property)
                        user.id = id
                        appDelegate.saveContext()
                        success?(user)
                })
            }, failure: failure)
    }
    
    class func loginWithCookieAndCacheInStorage(
        #success: ((User) -> Void)?,
        failure: ((NSError) -> Void)?) {
            let data = NSUserDefaults.standardUserDefaults().objectForKey("Cookies") as? NSData
            if data == nil {
                failure?(NSError()) // Needs specification
            } else {
                let cookies = NSKeyedUnarchiver.unarchiveObjectWithData(data) as [NSHTTPCookie]
                let storage = NSHTTPCookieStorage.sharedHTTPCookieStorage()
                for cookie in cookies {
                    storage.setCookie(cookie)
                }
                UserModel.GET(UserModel.URLStrings["Get UID"]!,
                    parameters: nil,
                    success: {
                        property in
                        self.fetchUserByID(
                            property["uid"].asInt(),
                            strategy: .CacheFirst,
                            success: success, failure: failure)
                    }, failure: failure)
            }
    }
    
    class func loginWithName(
        name: String,
        password: String,
        success: ((User) -> Void)?,
        failure: ((NSError) -> Void)?) {
            UserModel.POST(UserModel.URLStrings["Login"]!,
                parameters: [
                    "user_name": name.stringByReplacingPercentEscapesUsingEncoding(NSUTF8StringEncoding),
                    "password": password.stringByReplacingPercentEscapesUsingEncoding(NSUTF8StringEncoding)
                ],
                success: {
                    property in
                    let cookies = NSHTTPCookieStorage.sharedHTTPCookieStorage().cookies as [NSHTTPCookie]
                    let data = NSKeyedArchiver.archivedDataWithRootObject(cookies)
                    let defaults = NSUserDefaults.standardUserDefaults()
                    defaults.setObject(data, forKey: "Cookies")
                    defaults.synchronize()
                    self.loginWithCookieAndCacheInStorage(success: success, failure: failure)
                },
                failure: failure)
    }
    
    func fetchProfileUsingNetwork(#success: (() -> Void)?, failure: ((NSError) -> Void)?) {
        UserModel.GET(UserModel.URLStrings["profile"]!,
            parameters: [
                "uid": id
            ],
            success: {
                property in
                self.updateAdditionalInformationWithProperty(property[0])
                success?()
            },
            failure: failure)
    }
    
    class func avatarURLWithURI(URI: String) -> String {
        return UserModel.URLStrings["Base"]! + UserModel.URLStrings["Avatar Base"]! + URI
    }
    
    private func updateMainInformationWithProperty(property: Msr.Data.Property) {
        let data = property
        name = data["user_name"].asString()
        avatarURL = User.avatarURLWithURI(data["avatar_file"].asString())
        followerCount = data["fans_count"].asInt()
        friendCount = data["friend_count"].asInt()
        questionCount = data["question_count"].asInt()
        answerCount = data["answer_count"].asInt()
        topicFocusCount = data["topic_focus_count"].asInt()
        agreementCount = data["agree_count"].asInt()
        thankCount = data["thanks_count"].asInt()
        answerFavoriteCount = data["answer_favorite_count"].asInt()
        appDelegate.saveContext()
    }
    
    private func updateAdditionalInformationWithProperty(property: Msr.Data.Property) {
        let data = property
        name = data["user_name"].asString()
        gender = data["sex"].isNull() ? 3 : data["sex"].asInt()
        birthday = data["birthday"].isNull() ? 0 : data["birthday"].asInt()
        jobID = data["job_id"].asInt()
        signature = data["signature"].asString()
        appDelegate.saveContext()
    }
    
}
