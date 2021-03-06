import UIKit
import Photos
import AVKit

class SelectionViewController: UIViewController {
  var photoAlbum = PhotoAlbum.sharedInstance
  var allPhotos: PHFetchResult<PHAsset>!
  var smartAlbumsArr = [PHAssetCollection]()
  var userAlbumsArr = [PHAssetCollection]()
  let imageManager = PHCachingImageManager()
  var videoPlayerView: VideoPlayerView?

  let tileCellSpacing = CGFloat(1)
  var zoomMode: Bool = false
  var photoViewMode: Bool = true
  var multiSelectMode: Bool = false
  let photosLimit: Int = 500

  var fetchResult: PHFetchResult<PHAsset> = PHFetchResult<PHAsset>() {
    didSet {
      updateFirstImageView()
      self.collectionView.reloadData()
      self.collectionView.setNeedsDisplay()
      print("selec", fetchResult.count)
    }
  }

  let initialRequestOptions = PHImageRequestOptions().then {
    $0.isSynchronous = true
    $0.resizeMode = .fast
    $0.deliveryMode = .fastFormat
  }
  fileprivate var tableWrapperVC: TableViewWrapperController?
  fileprivate let libraryButton = UIButton().then {
    $0.backgroundColor = UIColor(red: 249, green: 249, blue: 249)
    $0.setTitle("Library v", for: .normal)
    $0.setTitleColor(UIColor.black, for: .normal)
  }

  fileprivate let multiSelectButton = MultiSelectButton()

  fileprivate let baseScrollView = UIScrollView().then {
    $0.showsHorizontalScrollIndicator = false
    $0.showsVerticalScrollIndicator = false
    $0.bounces = false
    $0.isPagingEnabled = true
  }
  fileprivate let scrollView = UIScrollView().then {
    $0.showsHorizontalScrollIndicator = false
    $0.showsVerticalScrollIndicator = false
    $0.maximumZoomScale = 3.0
    $0.minimumZoomScale = 0.8
    $0.zoomScale = 1.0
    //$0.alwaysBounceVertical = false
    //$0.alwaysBounceHorizontal = false
    $0.isUserInteractionEnabled = true
    //$0.clipsToBounds = false
  }
  fileprivate let imageView = UIImageView()
  fileprivate let collectionView = UICollectionView(frame: .zero, collectionViewLayout: UICollectionViewFlowLayout()).then {
    $0.showsHorizontalScrollIndicator = false
    $0.showsVerticalScrollIndicator = false
    $0.backgroundColor = .white
    $0.alwaysBounceVertical = true
    $0.register(TileCell.self, forCellWithReuseIdentifier: "tileCell")
    $0.allowsMultipleSelection = false
    $0.showsVerticalScrollIndicator = true
  }

  fileprivate let cropAreaView = UIView().then {
    $0.isUserInteractionEnabled = false
    $0.layer.borderColor = UIColor.lightGray.cgColor
    $0.layer.borderWidth = 1 / UIScreen.main.scale
  }
  fileprivate let buttonBarView = PassThroughView().then {
    $0.backgroundColor = UIColor.clear
  }
  fileprivate let scrollViewZoomButton = ZoomButton()
  override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
    super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    self.navigationItem.leftBarButtonItem = UIBarButtonItem(
      barButtonSystemItem: .cancel,
      target: self,
      action: #selector(cancelButtonDidTap)
    )

    self.navigationItem.rightBarButtonItem = UIBarButtonItem(
      barButtonSystemItem: .done,
      target: self,
      action: #selector(doneButtonDidTap)
    )
    self.automaticallyAdjustsScrollViewInsets = false
  }
  required init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    let scrollViewDoubleTap = UITapGestureRecognizer(target: self, action: #selector(doubleTapped))
    scrollViewDoubleTap.numberOfTapsRequired = 2
    scrollView.addGestureRecognizer(scrollViewDoubleTap)

    NotificationCenter.default.addObserver(self, selector: #selector(fetchSmartUserAlbums), name: NSNotification.Name(rawValue: "fetchSmartUserAlbums"), object: nil)
    NotificationCenter.default.addObserver(self, selector: #selector(fetchAllPhotoAlbum), name: NSNotification.Name(rawValue: "fetchAllPhotoAlbum"), object: nil)
    NotificationCenter.default.addObserver(self, selector: #selector(tableViewOffMode), name: NSNotification.Name(rawValue: "tableViewOffMode"), object: nil)

    self.collectionView.dataSource = self
    self.collectionView.delegate = self
    self.baseScrollView.delegate = self
    self.scrollView.delegate = self

    self.configureView()
    photoAlbum.getLimitedPhotos()
    self.allPhotos = photoAlbum.allPhotos
    self.fetchResult = allPhotos
  }
  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    self.navigationItem.rightBarButtonItem?.isEnabled = true
    let bounds = self.navigationController!.navigationBar.bounds
    self.navigationController?.navigationBar.frame = CGRect(x: 0, y: 0, width: bounds.width, height: 44)
  }
  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    self.baseScrollView.snp.makeConstraints { make in
      make.top.equalTo((self.navigationController?.navigationBar.snp.bottom)!)
    }
    self.navigationController?.navigationBar.addSubview(self.libraryButton)
    self.libraryButton.snp.makeConstraints { make in
      make.height.equalTo(40)
      make.width.equalTo(100)
      make.center.equalTo((self.navigationController?.navigationBar)!)
    }
  }

  func centerScrollView(animated: Bool) {
    let targetContentOffset = CGPoint(
      x: (self.scrollView.contentSize.width - self.scrollView.bounds.width) / 2,
      y: (self.scrollView.contentSize.height - self.scrollView.bounds.height) / 2
    )
    self.scrollView.setContentOffset(targetContentOffset, animated: animated)
  }

  func cancelButtonDidTap() {
    NotificationCenter.default.post(name: Notification.Name("dismissWrapperVC"), object: nil)
  }

  func doneButtonDidTap() {
    if self.collectionView.indexPathsForSelectedItems?.count != 0 {
      getMultipartArr { multipartArr in

        self.navigationItem.rightBarButtonItem?.isEnabled = false
        let croppedImage = Cropper().cropImage(image: self.imageView.image!, scrollView: self.scrollView, imageView: self.imageView, cropAreaView: self.cropAreaView)
        let postEditorViewController = PostEditorViewController(image: croppedImage!)

        postEditorViewController.multipartArr = multipartArr
        self.navigationController?.pushViewController(postEditorViewController, animated: true)
      }
    }
  }

  func getMultipartArr(completion: @escaping (_ multipartArr: [Any]) -> Void) {
    var multipartArr = [Any]()
    var counter = 0
    for index in self.collectionView.indexPathsForSelectedItems! {
      let asset = self.fetchResult.object(at: index.item)
      //사진
      if asset.mediaType == .image {

        let targetSize = CGSize(width: 600 * UIScreen.main.scale, height: 600 * UIScreen.main.scale)
        self.imageManager.requestImage(for: asset, targetSize: targetSize, contentMode: .aspectFit, options: self.initialRequestOptions, resultHandler: { image, _ in
          let croppedImage = Cropper().cropImage(image: image!, scrollView: self.scrollView, imageView: self.imageView, cropAreaView: self.cropAreaView)
          multipartArr.append(croppedImage!)
          counter += 1
          if counter == self.collectionView.indexPathsForSelectedItems?.count {
            completion(multipartArr)
          }
        })
      } else {
        //비디오
        imageManager.requestAVAsset(forVideo: asset, options: nil, resultHandler: {(asset: AVAsset?, _: AVAudioMix?, _: [AnyHashable : Any]?) -> Void in
          if let urlAsset = asset as? AVURLAsset {
            let localVideoUrl: URL = urlAsset.url as URL
            Cropper().cropVideo(localVideoUrl) { newUrl in
              var movieData: Data?
              do {
                movieData = try Data(contentsOf: newUrl)
              } catch _ {
                movieData = nil
                return
              }
              multipartArr.append(movieData!)
              counter += 1
              if counter == self.collectionView.indexPathsForSelectedItems?.count {
                completion(multipartArr)
              }
            }
          }
        })
      }
    }
  }

  func doubleTapped() {
    if scrollView.zoomScale == 1.0 {
      scrollView.setZoomScale(0.8, animated: true)
      zoomMode = true
    } else {
      scrollView.setZoomScale(1.0, animated: true)
      zoomMode = false
    }
  }

  func updateFirstImageView() {

    let targetSize = CGSize(width:  600 * UIScreen.main.scale, height: 600 * UIScreen.main.scale)
    scrollView.frame.size = CGSize(width: self.view.bounds.width, height: self.view.bounds.height * 2 / 3)

    let asset = self.fetchResult.object(at: 0)
    self.imageManager.requestImage(for: asset, targetSize: targetSize, contentMode: .aspectFit, options: self.initialRequestOptions, resultHandler: { image, _ in

      if image != nil {
        self.scrollView.zoomScale = 1.0
        self.scaleAspectFillSize(image: image!, imageView: self.imageView)
        self.scrollView.contentSize = self.imageView.frame.size
        self.imageView.image = image
        self.centerScrollView(animated: false)
      }
    })
  }

  func libraryButtonDidTap() {
    if libraryButton.currentTitle == "Library v" {
      if allPhotos.count == photosLimit {
        photoAlbum.getAllPhotos()
      }
      if photoAlbum.smartAlbumsArr.count == 0 || photoAlbum.userAlbumsArr.count == 0 {
        photoAlbum.getSmartUserAlbums()
      }
      tableViewOnMode()
    } else if libraryButton.currentTitle == "Library ^" {
      tableViewOffMode()
    }
  }

  func fetchSmartUserAlbums() {
    self.smartAlbumsArr = photoAlbum.smartAlbumsArr
    self.userAlbumsArr = photoAlbum.userAlbumsArr
  }

  func fetchAllPhotoAlbum() {
    self.allPhotos = photoAlbum.allPhotos
    self.fetchResult = self.allPhotos
  }

  func scaleAspectFillSize(image: UIImage, imageView: UIImageView) {

    var imageWidth = image.size.width
    var imageHeight = image.size.height

    imageView.frame.size = scrollView.frame.size
    let imageViewWidth = imageView.frame.size.width
    let imageViewHeight = imageView.frame.size.height

    if imageWidth > imageHeight {
      imageWidth *= imageViewHeight / imageHeight
      imageHeight = imageViewHeight
    } else if imageWidth < imageHeight {
      imageHeight *= imageViewWidth / imageWidth
      imageWidth = imageViewWidth
    } else {
      imageWidth *= imageViewHeight / imageHeight
      imageHeight *= imageViewWidth / imageWidth
    }
    self.imageView.frame.size = CGSize(width: imageWidth, height: imageHeight)
  }

  func configureView() {
    let screenWidth = self.view.bounds.width
    let screenHeight = self.view.bounds.height

    let navigationBarHeight = self.navigationController?.navigationBar.frame.height
    let bounds = self.navigationController!.navigationBar.bounds
    self.navigationController?.navigationBar.frame = CGRect(x: 0, y: 0, width: bounds.width, height: 44)
    self.title = "Library"

    self.baseScrollView.contentSize = CGSize(width: screenWidth, height: screenHeight + screenHeight * 2/3 - navigationBarHeight!)

    self.buttonBarView.addSubview(scrollViewZoomButton)
    self.buttonBarView.addSubview(multiSelectButton)
    self.baseScrollView.addSubview(self.collectionView)
    self.baseScrollView.addSubview(self.scrollView)
    self.baseScrollView.addSubview(self.cropAreaView)
    self.baseScrollView.addSubview(self.buttonBarView)
    self.scrollView.addSubview(self.imageView)
    self.view.addSubview(baseScrollView)

    self.baseScrollView.snp.makeConstraints { make in
      make.bottom.left.right.equalTo(self.view)
    }

    self.scrollView.snp.makeConstraints { make in
      make.left.right.top.equalTo(self.baseScrollView)
      make.height.equalTo(screenHeight * 2 / 3 - screenWidth/8 )
      make.width.equalTo(screenWidth)
    }
    self.collectionView.snp.makeConstraints { make in
      make.left.bottom.right.equalTo(self.baseScrollView)
      make.top.equalTo(self.scrollView.snp.bottom)
      make.height.equalTo(screenHeight - screenWidth/8 - navigationBarHeight!)
      make.width.equalTo(screenWidth)
    }
    self.cropAreaView.snp.makeConstraints { make in
      make.edges.equalTo(self.scrollView)
    }
    self.buttonBarView.snp.makeConstraints { make in
      make.left.right.equalTo(self.baseScrollView)
      make.bottom.equalTo(self.collectionView.snp.top)
      make.height.equalTo(screenWidth/8)
      make.width.equalTo(screenWidth)
    }
    self.scrollViewZoomButton.snp.makeConstraints { make in
      make.width.equalTo(screenWidth/12)
      make.height.equalTo(screenWidth/12)
      make.centerY.equalTo(self.buttonBarView)
      make.left.equalTo(self.buttonBarView).offset(10)
    }
    self.multiSelectButton.snp.makeConstraints { make in
      make.width.equalTo(screenWidth/12)
      make.height.equalTo(screenWidth/12)
      make.centerY.equalTo(self.buttonBarView)
      make.right.equalTo(self.buttonBarView).offset(-10)
    }

    self.scrollViewZoomButton.addTarget(self, action: #selector(scrollViewZoom), for: .touchUpInside)
    self.multiSelectButton.addTarget(self, action: #selector(multiSelectButtonDidTap), for: .touchUpInside)
    self.libraryButton.addTarget(self, action: #selector(libraryButtonDidTap), for: .touchUpInside)
    let panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(buttonBarViewGesture(_:)))
    buttonBarView.addGestureRecognizer(panGestureRecognizer)
  }

  func buttonBarViewGesture(_ recognizer: UIPanGestureRecognizer) {
    if recognizer.state == .began {
      NotificationCenter.default.post(name: Notification.Name("changeIsScrollEnabled"), object: nil)
    }

    if recognizer.state == .ended {
      NotificationCenter.default.post(name: Notification.Name("changeIsScrollEnabled"), object: nil)
      buttonBarView.isUserInteractionEnabled = true
    }
  }

  func scrollViewZoom() {

    if scrollView.zoomScale >= 1.0 {
      scrollView.setZoomScale(0.8, animated: true)
      zoomMode = true
    } else {
      scrollView.setZoomScale(1.0, animated: true)
      zoomMode = false
    }
  }

  func multiSelectButtonDidTap() {
    if multiSelectMode {
      collectionView.allowsMultipleSelection = false
      multiSelectMode = false
      scrollViewZoomButton.isHidden = false
      zoomMode = true
      scrollView.isUserInteractionEnabled = true
    } else {
      collectionView.allowsMultipleSelection = true
      multiSelectMode = true
      scrollViewZoomButton.isHidden = true
      if scrollView.zoomScale != 1.0 {
        scrollView.setZoomScale(1.0, animated: true)
      }
      zoomMode = false
      scrollView.isUserInteractionEnabled = false
    }
  }

  func tableViewOffMode() {
    self.libraryButton.setTitle("Library v", for: .normal)
    self.fetchResult = photoAlbum.fetchResult!
    self.tableWrapperVC?.view.removeFromSuperview()
    self.tableWrapperVC?.removeFromParentViewController()
    NotificationCenter.default.post(name: Notification.Name("showCustomTabBar"), object: nil)
    self.navigationItem.leftBarButtonItem = UIBarButtonItem(
      barButtonSystemItem: .cancel,
      target: self,
      action: #selector(cancelButtonDidTap)
    )

    self.navigationItem.rightBarButtonItem = UIBarButtonItem(
      barButtonSystemItem: .done,
      target: self,
      action: #selector(doneButtonDidTap)
    )
  }

  func tableViewOnMode() {
    self.libraryButton.setTitle("Library ^", for: .normal)
    tableWrapperVC = TableViewWrapperController()
    self.view.addSubview((tableWrapperVC?.view)!)
    self.addChildViewController(tableWrapperVC!)
    self.navigationItem.leftBarButtonItem = nil
    self.navigationItem.rightBarButtonItem = nil
  }

  func getThumbnailImage(videoUrl: URL) -> UIImage? {
    let asset = AVAsset(url: videoUrl)
    let imageGenerator = AVAssetImageGenerator(asset: asset)
    imageGenerator.appliesPreferredTrackTransform = true
    var time = asset.duration
    time.value = min(time.value, 2)
    do {
      let imageRef = try imageGenerator.copyCGImage(at: time, actualTime: nil)
      return UIImage(cgImage: imageRef)
    } catch {
      return nil
    }
  }

  func videoMode() {
    self.photoViewMode = false
    self.imageView.isUserInteractionEnabled = true
    self.scrollView.setZoomScale(1.0, animated: true)
    self.scrollView.maximumZoomScale = 1.0
    self.scrollView.minimumZoomScale = 1.0
    self.scrollView.bounces = false
    self.scrollView.isScrollEnabled = false
  }

  func photoMode() {
    self.photoViewMode = true
    self.scrollView.maximumZoomScale = 3.0
    self.scrollView.minimumZoomScale = 0.8
    self.scrollView.bounces = true
    self.scrollView.isScrollEnabled = true
  }

  func getMediaDuration(url: URL) -> Float {
    let asset: AVURLAsset = AVURLAsset(url: url)
    let duration: CMTime = asset.duration
    return Float(CMTimeGetSeconds(duration))
  }

}

extension SelectionViewController: UICollectionViewDelegate {

  func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
    if let selectedItems = collectionView.indexPathsForSelectedItems {
      if selectedItems.contains(indexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)

        return false
      }
    }
    return true
  }
}

extension SelectionViewController: UICollectionViewDataSource {
  func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
    let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "tileCell", for: indexPath) as! TileCell
    let asset = self.fetchResult.object(at: indexPath.item)
    cell.representedAssetIdentifier = asset.localIdentifier

    let targetSize = CGSize(width:  150 * UIScreen.main.scale, height: 150 * UIScreen.main.scale)
    if asset.mediaType == .video {
      imageManager.requestAVAsset(forVideo: asset, options: nil, resultHandler: {(asset: AVAsset?, _: AVAudioMix?, _: [AnyHashable : Any]?) -> Void in
        if let urlAsset = asset as? AVURLAsset {
          let localVideoUrl: URL = urlAsset.url as URL
          DispatchQueue.main.async {
            cell.setVideoLabel(duration: self.getMediaDuration(url: localVideoUrl))
          }

        }
      })
    }
    imageManager.requestImage(for: asset, targetSize: targetSize, contentMode: .aspectFit, options: initialRequestOptions, resultHandler: { image, _ in
      if cell.representedAssetIdentifier == asset.localIdentifier && image != nil {
        cell.configure(photo: image!)
      }

      if asset == self.fetchResult.object(at: 0) && self.imageView.image == nil {

        self.scrollView.zoomScale = 1.0
        self.scaleAspectFillSize(image: image!, imageView: self.imageView)
        self.scrollView.contentSize = self.imageView.frame.size
        self.imageView.image = image
        self.centerScrollView(animated: false)
      }
    })

    return cell
  }
  func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
    return fetchResult.count
  }

}

extension SelectionViewController: UICollectionViewDelegateFlowLayout {
  func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {

    let cellWidth: CGFloat?
    if collectionView.frame.width >= 375 {
      cellWidth = round((collectionView.frame.width - 5 * tileCellSpacing) / 4)
    } else {
      cellWidth = round((collectionView.frame.width - 4 * tileCellSpacing) / 3)
    }
    return TileCell.size(width: cellWidth!)
  }
  func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
    return tileCellSpacing
  }
  func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
    return tileCellSpacing
  }
  func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {

    let asset = fetchResult.object(at: indexPath.item)

    if asset.mediaType == .video {
      self.videoPlayerView?.removeFromSuperview()
      videoMode()
      imageManager.requestAVAsset(forVideo: asset, options: nil, resultHandler: {(asset: AVAsset?, _: AVAudioMix?, _: [AnyHashable : Any]?) -> Void in
        if let urlAsset = asset as? AVURLAsset {
          DispatchQueue.main.async {
            let localVideoUrl: URL = urlAsset.url as URL
            let thumbnailImage = self.getThumbnailImage(videoUrl: localVideoUrl)
            self.imageView.image = thumbnailImage
            self.scaleAspectFillSize(image: thumbnailImage!, imageView: self.imageView)
            self.scrollView.contentSize = self.imageView.frame.size
            self.centerScrollView(animated: false)

            self.videoPlayerView = VideoPlayerView(videoURL: localVideoUrl)
            self.videoPlayerView?.delegate = self
            self.videoPlayerView?.frame = self.imageView.frame
            self.videoPlayerView?.addPlayerLayer()
            self.imageView.addSubview(self.videoPlayerView!)
            self.videoPlayerView?.playPlayer()
          }
        }
      })
    } else {
      self.videoPlayerView?.removeFromSuperview()
      photoMode()
      self.baseScrollView.setContentOffset(CGPoint(x:0, y:0), animated: true)
      let targetSize = CGSize(width: 600 * UIScreen.main.scale, height: 600 * UIScreen.main.scale)
      imageManager.requestImage(for: asset, targetSize: targetSize, contentMode: .aspectFit, options: initialRequestOptions, resultHandler: { image, _ in

        self.scrollView.zoomScale = 1.0
        self.scaleAspectFillSize(image: image!, imageView: self.imageView)
        self.scrollView.contentSize = self.imageView.frame.size
        self.imageView.image = image
        self.centerScrollView(animated: false)

        if self.zoomMode {
          self.scrollView.zoomScale = 0.8
        } else {
          self.scrollView.zoomScale = 1.0
        }
      })
    }

  }
}

extension SelectionViewController: UIScrollViewDelegate {

  func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {

    if self.allPhotos.count == photosLimit && self.fetchResult == self.allPhotos {

      photoAlbum.getAllPhotos()
    }
  }

  func viewForZooming(in scrollView: UIScrollView) -> UIView? {
    return imageView
  }
  func scrollViewDidScroll(_ scrollView: UIScrollView) {

    let page = self.baseScrollView.contentOffset.y
    if page >= 44 {
      self.navigationController?.navigationBar.frame.origin.y = -44
    } else if page < 44 {
      self.navigationController?.navigationBar.frame.origin.y = -(page)
    }
    self.cropAreaView.backgroundColor = UIColor.black.withAlphaComponent(page / 600)

  }

  func scrollViewDidZoom(_ scrollView: UIScrollView) {

    let imageViewSize = imageView.frame.size
    let scrollViewSize = scrollView.bounds.size

    let verticalPadding = imageViewSize.height < scrollViewSize.height ? (scrollViewSize.height - imageViewSize.height) / 2 : 0
    let horizontalPadding = imageViewSize.width < scrollViewSize.width ? (scrollViewSize.width - imageViewSize.width) / 2 : 0

    scrollView.contentInset = UIEdgeInsets(top: verticalPadding, left: horizontalPadding, bottom: verticalPadding, right: horizontalPadding)
  }
}

extension SelectionViewController: VideoPlayButtonDelegate {

  func playButtonDidTap(sender: UIButton, player: AVPlayer) {
    if player.rate == 0 {
      player.play()
      sender.setImage(nil, for: .normal)
    } else {
      player.pause()
      sender.setImage(UIImage(named: "play"), for: .normal)
    }
  }
}

/**
 * superView에서의 터치는 무효화하는 커스텀 뷰
 *
 * - Note : SelectionViewController의 buttonBarView영역을 스크롤하면 다른 페이지로 이동하는 것을 방지하면서 subView 버튼들의 액션을 유지하기 위해 사용
 */
class PassThroughView: UIView {
  override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
    let result = super.hitTest(point, with: event)
    if result == self { return nil }
    return result
  }
}
