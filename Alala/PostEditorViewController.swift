//
//  PostEditorViewController.swift
//  Alala
//
//  Created by junwoo on 2017. 6. 16..
//  Copyright © 2017년 team-meteor. All rights reserved.
//

import UIKit
import Photos

class PostEditorViewController: UIViewController {

  fileprivate let image: UIImage
  fileprivate var message: String?
  var fetchResult = PHFetchResult<PHAsset>()
  var videoDataArr = [Data]()
  var videoIndexArr = [IndexPath]()
  var cropImageArr = [UIImage]()
  var multipartsIdArr = [String]()
  fileprivate let progressView = UIProgressView()

  fileprivate let tableView = UITableView().then {
    $0.isScrollEnabled = false
    $0.register(PostEditingCell.self, forCellReuseIdentifier: "postEditingCell")
  }

  init(image: UIImage) {
    self.image = image
    super.init(nibName: nil, bundle: nil)
    self.view.backgroundColor = UIColor.yellow
    self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Share", style: .plain, target: self, action: #selector(shareButtonDidTap))
  }

  required init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func viewDidLoad() {
    super.viewDidLoad()

    self.tableView.dataSource = self
    self.tableView.delegate = self

    self.view.addSubview(self.tableView)
    self.view.addSubview(self.progressView)
    self.progressView.progress = 0.0
    self.progressView.isHidden = false
  }

  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    self.tableView.snp.makeConstraints { make in
      make.left.top.right.equalTo(self.view)
      make.width.equalTo(self.view)
      make.height.equalTo(300)
    }

    self.progressView.snp.makeConstraints { make in
      make.top.equalTo(self.tableView.snp.bottom)
      make.width.equalTo(self.view)
      make.height.equalTo(100)
    }
  }

  override func didMove(toParentViewController parent: UIViewController?) {
    if parent == nil {
      NotificationCenter.default.post(name: Notification.Name("cameraStart"), object: nil)
    }
  }

  func transformAssetToVideoData(completion: @escaping (_ success: Bool) -> Void) {
    let imageManager = PHCachingImageManager()

    for index in videoIndexArr {
      let asset = self.fetchResult.object(at: index.item)

      imageManager.requestAVAsset(forVideo: asset, options: nil, resultHandler: {(asset: AVAsset?, _: AVAudioMix?, _: [AnyHashable : Any]?) -> Void in
        if let urlAsset = asset as? AVURLAsset {
          let localVideoUrl: URL = urlAsset.url as URL
          var movieData: Data?
          do {
            movieData = try Data(contentsOf: localVideoUrl)
          } catch _ {
            movieData = nil
            return
          }
          self.videoDataArr.append(movieData!)
          if self.videoDataArr.count == self.videoIndexArr.count {
            completion(true)
          }
        }
      })
    }
  }

  func getMultipartsIdArr(completion: @escaping (_ idArr: [String]) -> Void) {

    if cropImageArr.count != 0 {

      for image in cropImageArr {
        MultipartService.uploadMultipart(multiPartData: image, progressCompletion: { [unowned self] percent in
          self.progressView.setProgress(percent, animated: true)
        }) { imageId in
          self.multipartsIdArr.append(imageId)
            self.progressView.isHidden = true
            if self.multipartsIdArr.count == self.cropImageArr.count + self.videoDataArr.count {
            completion(self.multipartsIdArr)
          }
        }
      }
    }
    if videoDataArr.count != 0 {

      for movieData in videoDataArr {
        MultipartService.uploadMultipart(multiPartData: movieData, progressCompletion: { [unowned self] percent in
          self.progressView.setProgress(percent, animated: true)
        }) { movieId in
          self.multipartsIdArr.append(movieId)
          self.progressView.isHidden = true
          if self.multipartsIdArr.count == self.cropImageArr.count + self.videoDataArr.count {
            completion(self.multipartsIdArr)
          }
        }

      }
    }

  }

  func shareButtonDidTap() {
    self.navigationItem.rightBarButtonItem?.isEnabled = false
    if videoIndexArr.count != 0 {
      transformAssetToVideoData { success in
        self.getMultipartsIdArr { idArr in

          PostService.postWithSingleMultipart(idArr: idArr, message: self.message, progress: nil, completion: { [weak self] response in
              guard self != nil else { return }
              switch response.result {
              case .success(let post):

                self?.dismiss(animated: true) { _ in
                  NotificationCenter.default.post(
                    name: NSNotification.Name(rawValue: "postDidCreate"),
                    object: self,
                    userInfo: ["post": post]
                  )
                }
              case .failure(let error):
                print(error)

              }
            }

          )
        }
      }
    } else {
      self.getMultipartsIdArr { idArr in

        PostService.postWithSingleMultipart(idArr: idArr, message: self.message, progress: nil, completion: { [weak self] response in
            guard self != nil else { return }
            switch response.result {
            case .success(let post):

              self?.dismiss(animated: true) { _ in
                NotificationCenter.default.post(
                  name: NSNotification.Name(rawValue: "postDidCreate"),
                  object: self,
                  userInfo: ["post": post]
                )
              }
            case .failure(let error):
              print(error)

            }
          }

        )}
    }

  }

  deinit {
    NotificationCenter.default.removeObserver(self)
  }

}

extension PostEditorViewController: UITableViewDataSource {

  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return 1
  }

  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell = tableView.dequeueReusableCell(withIdentifier: "postEditingCell", for: indexPath) as! PostEditingCell
    cell.imageConfigure(image: self.image)
    cell.textDidChange = { [weak self] message in
      guard let `self` = self else { return }
      self.message = message
      self.tableView.beginUpdates()
      self.tableView.endUpdates()
      self.tableView.scrollToRow(at: indexPath, at: .none, animated: false)
    }
    return cell
  }
}

extension PostEditorViewController: UITableViewDelegate {

  func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
    if indexPath.row == 0 { return 100 }
    return 0
  }

}
