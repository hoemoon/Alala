//
//  WrapperViewController.swift
//  Alala
//
//  Created by junwoo on 2017. 6. 18..
//  Copyright © 2017년 team-meteor. All rights reserved.
//

import UIKit
import AVFoundation

class WrapperViewController: UIViewController {

	let libraryButton = UIButton().then {
		$0.setTitle("Library", for: .normal)
		$0.addTarget(self, action: #selector(libraryButtonDidTap), for: .touchUpInside)
		$0.setTitleColor(UIColor.blue, for: .normal)
	}
	let photoButton = UIButton().then {
		$0.setTitle("Photo", for: .normal)
		$0.addTarget(self, action: #selector(photoButtonDidTap), for: .touchUpInside)
		$0.setTitleColor(UIColor.lightGray, for: .normal)
	}

	let videoButton = UIButton().then {
		$0.setTitle("Video", for: .normal)
		$0.addTarget(self, action: #selector(videoButtonDidTap), for: .touchUpInside)
		$0.setTitleColor(UIColor.lightGray, for: .normal)
	}

	fileprivate let scrollView = UIScrollView().then {
		$0.showsHorizontalScrollIndicator = false
		$0.showsVerticalScrollIndicator = false
		$0.isPagingEnabled = true
		$0.bounces = false
	}

	fileprivate let customTabBar = UIView().then {
		$0.backgroundColor = UIColor(red: 249, green: 249, blue: 249)
	}

	fileprivate let libraryViewController = LibraryViewController()
	fileprivate let cameraViewController = UINavigationController(rootViewController: CameraViewController())

	override func viewDidLoad() {
		super.viewDidLoad()

		NotificationCenter.default.addObserver(self, selector: #selector(photoModeOnTabBar), name: Notification.Name("photoModeOnTabBar"), object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(videoButtonDidTap), name: Notification.Name("videoModeOnTabBar"), object: nil)
    NotificationCenter.default.addObserver(self, selector: #selector(showCustomTabBar), name: Notification.Name("showCustomTabBar"), object: nil)
    NotificationCenter.default.addObserver(self, selector: #selector(hideCustomTabBar), name: Notification.Name("hideCustomTabBar"), object: nil)
    NotificationCenter.default.addObserver(self, selector: #selector(dismissWrapperVC), name: Notification.Name("dismissWrapperVC"), object: nil)
    NotificationCenter.default.addObserver(self, selector: #selector(changeIsScrollEnabled), name: Notification.Name("changeIsScrollEnabled"), object: nil)

    self.addChildViewController(self.cameraViewController)
    self.scrollView.addSubview(self.cameraViewController.view)
    self.scrollView.delegate = self
    self.addChildViewController(libraryViewController)
    self.scrollView.addSubview(libraryViewController.view)
    self.view.addSubview(scrollView)
    self.customTabBar.addSubview(libraryButton)
    self.customTabBar.addSubview(photoButton)
    self.customTabBar.addSubview(videoButton)
    self.view.addSubview(customTabBar)

		self.customTabBar.snp.makeConstraints { make in
			make.left.bottom.right.equalTo(self.view)
			make.height.equalTo(50)
		}

		self.scrollView.snp.makeConstraints { make in
			make.top.left.right.equalTo(self.view)
			make.bottom.equalTo(self.customTabBar.snp.top)
		}

		self.libraryViewController.view.snp.makeConstraints { make in
			make.edges.equalTo(self.scrollView)
			make.width.equalTo(self.scrollView.snp.width)
			make.height.equalTo(self.scrollView.snp.height)
		}

		self.cameraViewController.view.snp.makeConstraints { make in
			make.left.equalTo(self.libraryViewController.view.snp.right)
			make.width.equalTo(self.libraryViewController.view.snp.width)
			make.height.equalTo(self.libraryViewController.view.snp.height)
			make.centerY.equalTo(self.libraryViewController.view.snp.centerY)
		}

		self.libraryButton.snp.makeConstraints { make in
			make.width.equalTo(self.view.frame.width/3)
			make.height.equalTo(50)
			make.top.left.bottom.equalTo(self.customTabBar)
		}

		self.photoButton.snp.makeConstraints { make in
			make.width.equalTo(self.view.frame.width/3)
			make.height.equalTo(50)
			make.top.bottom.equalTo(self.customTabBar)
			make.left.equalTo(self.libraryButton.snp.right)
			make.right.equalTo(self.videoButton.snp.left)
		}
		self.videoButton.snp.makeConstraints { make in
			make.width.equalTo(self.view.frame.width/3)
			make.height.equalTo(50)
			make.top.right.bottom.equalTo(self.customTabBar)
		}
	}

	override func viewDidLayoutSubviews() {
		super.viewDidLayoutSubviews()
		DispatchQueue.main.async {
			self.scrollView.contentSize = CGSize(width: self.libraryViewController.view.frame.size.width * 2, height: self.libraryViewController.view.frame.size.height)
		}
	}

  func dismissWrapperVC() {
    self.dismiss(animated: true, completion: nil)
  }

  func changeIsScrollEnabled() {
    if scrollView.isScrollEnabled {
      scrollView.isScrollEnabled = false
    } else {
      scrollView.isScrollEnabled = true
    }
  }

  deinit {
    NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: "photoModeOnTabBar"), object: nil)
    NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: "videoModeOnTabBar"), object: nil)
    NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: "showCustomTabBar"), object: nil)
    NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: "hideCustomTabBar"), object: nil)
    NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: "dismissWrapperVC"), object: nil)
    print("wrapper deinit")
  }

  func showCustomTabBar() {
    UIView.animate(withDuration: 0.2, animations: {self.customTabBar.transform = CGAffineTransform.identity})
    self.customTabBar.snp.remakeConstraints { make in
      make.left.bottom.right.equalTo(self.view)
      make.height.equalTo(50)
    }
  }

  func hideCustomTabBar() {
    UIView.animate(withDuration: 0.2, animations: {self.customTabBar.transform = CGAffineTransform(translationX: 0, y: 50)})
    self.customTabBar.snp.remakeConstraints { make in
      make.top.equalTo(self.view.snp.bottom)
      make.width.equalTo(self.view.frame.width)
      make.height.equalTo(50)
    }
  }

  override var prefersStatusBarHidden: Bool {
    return true
  }

	func libraryButtonDidTap() {
		UIView.animate(withDuration: 0.5, delay: 0, options: UIViewAnimationOptions.curveLinear, animations: {
			self.scrollView.contentOffset.x = 0}, completion: nil)
		self.libraryButton.setTitleColor(UIColor.blue, for: .normal)
		self.photoButton.setTitleColor(UIColor.lightGray, for: .normal)
		self.videoButton.setTitleColor(UIColor.lightGray, for: .normal)
    NotificationCenter.default.post(name: Notification.Name("cameraStop"), object: nil)
	}

	func photoButtonDidTap() {
		UIView.animate(withDuration: 0.5, delay: 0, options: UIViewAnimationOptions.curveLinear, animations: {
			self.scrollView.contentOffset.x = self.scrollView.bounds.size.width}, completion: nil)
		NotificationCenter.default.post(name: Notification.Name("photoMode"), object: nil)
    NotificationCenter.default.post(name: Notification.Name("cameraStart"), object: nil)
		photoModeOnTabBar()
	}

	func videoButtonDidTap() {
		UIView.animate(withDuration: 0.5, delay: 0, options: UIViewAnimationOptions.curveLinear, animations: {
			self.scrollView.contentOffset.x = self.scrollView.bounds.size.width}, completion: nil)
		NotificationCenter.default.post(name: Notification.Name("videoMode"), object: nil)
    NotificationCenter.default.post(name: Notification.Name("cameraStart"), object: nil)
		videoModeOnTabBar()
	}

	func photoModeOnTabBar() {
		self.photoButton.setTitleColor(UIColor.blue, for: .normal)
		self.libraryButton.setTitleColor(UIColor.lightGray, for: .normal)
		self.videoButton.setTitleColor(UIColor.lightGray, for: .normal)
	}

	func videoModeOnTabBar() {
		self.videoButton.setTitleColor(UIColor.blue, for: .normal)
		self.libraryButton.setTitleColor(UIColor.lightGray, for: .normal)
		self.photoButton.setTitleColor(UIColor.lightGray, for: .normal)
	}
}

extension WrapperViewController: UIScrollViewDelegate {
	func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
		let page = Int(scrollView.contentOffset.x / scrollView.bounds.size.width)
		if page == 0 {
			self.libraryButton.setTitleColor(UIColor.blue, for: .normal)
			self.photoButton.setTitleColor(UIColor.lightGray, for: .normal)
			self.videoButton.setTitleColor(UIColor.lightGray, for: .normal)
      NotificationCenter.default.post(name: Notification.Name("cameraStop"), object: nil)

		} else if page == 1 {
			photoModeOnTabBar()
			NotificationCenter.default.post(name: Notification.Name("photoMode"), object: nil)
      NotificationCenter.default.post(name: Notification.Name("cameraStart"), object: nil)
		}
	}
}
