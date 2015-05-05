//
//  CommetListViewController.swift
//  WeCenterMobile
//
//  Created by Darren Liu on 14/10/4.
//  Copyright (c) 2014年 ifLab. All rights reserved.
//

import MJRefresh
import SVProgressHUD
import UIKit

enum AnswerOrArticle {
    case Answer_(Answer)
    case Article_(Article)
}

class CommentListViewController: UITableViewController {
    private var answerOrArticle: AnswerOrArticle
    var comments = [Comment]()
    let cellReuseIdentifier = "CommentCell"
    let cellNibName = "CommentCell"
    let keyboardBar = KeyboardBar()
    init(answer: Answer) {
        self.answerOrArticle = .Answer_(answer)
        super.init(nibName: nil, bundle: nil)
    }
    init(article: Article) {
        self.answerOrArticle = .Article_(article)
        super.init(nibName: nil, bundle: nil)
    }
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    override func loadView() {
        super.loadView()
        title = "评论"
        refreshControl = UIRefreshControl()
        refreshControl!.tintColor = UIColor.whiteColor()
        refreshControl!.addTarget(self, action: "refresh", forControlEvents: .ValueChanged)
        tableView = ButtonTouchesCancelableTableView()
        tableView.delegate = self
        tableView.dataSource = self
        tableView.registerNib(UINib(nibName: cellNibName, bundle: NSBundle.mainBundle()), forCellReuseIdentifier: cellReuseIdentifier)
        tableView.separatorStyle = .None
        tableView.contentInset.bottom = 50
        tableView.estimatedRowHeight = 50
        tableView.rowHeight = UITableViewAutomaticDimension
        tableView.keyboardDismissMode = .OnDrag
        tableView.backgroundColor = UIColor.msr_materialBlueGray800()
        tableView.panGestureRecognizer.requireGestureRecognizerToFail(msr_navigationController!.interactivePopGestureRecognizer)
        tableView.indicatorStyle = .White
        msr_navigationBar!.barStyle = .Black
        msr_navigationBar!.tintColor = UIColor.whiteColor()
        keyboardBar.userAtView.removeButton.addTarget(self, action: "removeAtUser", forControlEvents: .TouchUpInside)
        keyboardBar.publishButton.addTarget(self, action: "publishComment", forControlEvents: .TouchUpInside)
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        refreshControl!.beginRefreshing()
        refresh()
    }
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        msr_navigationWrapperController!.view.addSubview(keyboardBar)
    }
    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return comments.count
    }
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let comment = comments[indexPath.row]
        var cell = tableView.dequeueReusableCellWithIdentifier(cellReuseIdentifier, forIndexPath: indexPath) as! CommentCell
        cell.update(comment: comment, updateImage: true)
        return cell
    }
    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        let comment = comments[indexPath.row]
        let alertController = UIAlertController(title: nil, message: nil, preferredStyle: .ActionSheet)
        alertController.addAction(UIAlertAction(
            title: "回复",
            style: .Default) {
                [weak self] action in
                if comment.user != nil {
                    let user = DataManager.temporaryManager!.create("User") as! User
                    user.id = comment.user!.id
                    user.name = comment.user!.name
                    self?.keyboardBar.userAtView.userNameLabel.text = user.name
                    self?.keyboardBar.userAtView.msr_userInfo = user
                    self?.keyboardBar.userAtView.hidden = false
                }
                tableView.deselectRowAtIndexPath(indexPath, animated: true)
            })
        alertController.addAction(UIAlertAction(
            title: "复制",
            style: .Default) {
                action in
                UIPasteboard.generalPasteboard().string = comment.body
                tableView.deselectRowAtIndexPath(indexPath, animated: true)
            })
        alertController.addAction(UIAlertAction(
            title: "取消",
            style: .Cancel) {
                action in
                tableView.deselectRowAtIndexPath(indexPath, animated: true)
            })
        presentViewController(alertController, animated: true, completion: nil)
    }
    internal func publishComment() {
        if !(refreshControl?.refreshing ?? true) {
            keyboardBar.textField.resignFirstResponder()
            let manager = DataManager.temporaryManager!
            let comment: Comment!
            switch answerOrArticle {
            case .Answer_(let answer):
                let comment_ = manager.create("AnswerComment") as! AnswerComment
                comment_.answer = (manager.create("Answer") as! Answer)
                comment_.answer!.id = answer.id
                comment = comment_
                break
            case .Article_(let article):
                let comment_ = manager.create("ArticleComment") as! ArticleComment
                comment_.article = (manager.create("Article") as! Article)
                comment_.article!.id = article.id
                comment = comment_
                break
            default:
                break
            }
            comment.body = keyboardBar.textField.text
            comment.atUser = keyboardBar.userAtView.msr_userInfo as? User
            SVProgressHUD.showWithMaskType(.Gradient)
            comment.post(
                success: {
                    [weak self] in
                    SVProgressHUD.dismiss()
                    SVProgressHUD.showSuccessWithStatus("已发布", maskType: .Gradient)
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(NSEC_PER_SEC / 2)), dispatch_get_main_queue()) {
                        SVProgressHUD.dismiss()
                    }
                    self?.keyboardBar.textField.text = ""
                    self?.removeAtUser()
                    self?.refreshControl?.beginRefreshing()
                    self?.refresh()
                },
                failure: {
                    [weak self] error in
                    SVProgressHUD.dismiss()
                    let ac = UIAlertController(title: (error.userInfo?[NSLocalizedDescriptionKey] as? String) ?? "",
                        message: nil,
                        preferredStyle: .Alert)
                    ac.addAction(UIAlertAction(title: "好", style: .Default, handler: nil))
                    self?.presentViewController(ac, animated: true, completion: nil)
                })
        }
    }
    func refresh() {
        let success: ([Comment]) -> Void = {
            [weak self] comments in
            self?.comments = comments
            self?.tableView.reloadData()
            self?.refreshControl!.endRefreshing()
        }
        let failure: (NSError) -> Void = {
            [weak self] error in
            self?.tableView.reloadData()
            self?.refreshControl!.endRefreshing()
        }
        switch answerOrArticle {
        case .Answer_(let answer):
            answer.fetchComments(
                success: { success($0) },
                failure: failure)
            break
        case .Article_(let article):
            article.fetchComments(
                success: { success($0) },
                failure: failure)
            break
        default:
            break
        }
    }
    func removeAtUser() {
        keyboardBar.userAtView.msr_userInfo = nil
        keyboardBar.userAtView.hidden = true
        keyboardBar.userAtView.userNameLabel.text = ""
    }
    override func preferredStatusBarStyle() -> UIStatusBarStyle {
        return .LightContent
    }
}
