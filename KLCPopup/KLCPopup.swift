// KLCPopup.swift
//
// Created by Jeff Mascia
// Copyright (c) 2013-2014 Kullect Inc. (http://kullect.com)
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

import UIKit

// KLCPopupShowType: Controls how the popup will be presented.
enum KLCPopupShowType {
	case None
	case FadeIn
	case GrowIn
	case ShrinkIn
	case SlideInFromTop
	case SlideInFromBottom
	case SlideInFromLeft
	case SlideInFromRight
	case BounceIn
	case BounceInFromTop
	case BounceInFromBottom
	case BounceInFromLeft
	case BounceInFromRight
}

// KLCPopupDismissType: Controls how the popup will be dismissed.
enum KLCPopupDismissType {
	case None
	case FadeOut
	case GrowOut
	case ShrinkOut
	case SlideOutToTop
	case SlideOutToBottom
	case SlideOutToLeft
	case SlideOutToRight
	case BounceOut
	case BounceOutToTop
	case BounceOutToBottom
	case BounceOutToLeft
	case BounceOutToRight
}

// KLCPopupHorizontalLayout: Controls where the popup will come to rest horizontally.
enum KLCPopupHorizontalLayout {
	case Custom
	case Left
	case LeftOfCenter
	case Center
	case RightOfCenter
	case Right
}

// KLCPopupVerticalLayout: Controls where the popup will come to rest vertically.
enum KLCPopupVerticalLayout {
	case Custom
	case Top
	case AboveCenter
	case Center
	case BelowCenter
	case Bottom
}

// KLCPopupMaskType
enum KLCPopupMaskType {
	case None // Allow interaction with underlying views.
	case Clear // Don't allow interaction with underlying views.
	case Dimmed // Don't allow interaction with underlying views, dim background.
}

struct KLCPopupLayout {
	var horizontal:KLCPopupHorizontalLayout
	var vertical:KLCPopupVerticalLayout

	init(horizontal:KLCPopupHorizontalLayout, vertical:KLCPopupVerticalLayout) {
		self.horizontal = horizontal
		self.vertical = vertical
	}
}

let kAnimationOptionCurveIOS7 = (7 << 16)

let KLCPopupLayoutCenter = KLCPopupLayout(horizontal: .Center, vertical: .Center)
//const KLCPopupLayout KLCPopupLayoutCenter = { KLCPopupHorizontalLayoutCenter, KLCPopupVerticalLayoutCenter }


class KLCPopup:UIView {

	// This is the view that you want to appear in Popup.
	// - Must provide contentView before or in willStartShowing.
	// - Must set desired size of contentView before or in willStartShowing.
	var contentView:UIView

	// Animation transition for presenting contentView. default = shrink in
	var showType:KLCPopupShowType

	// Animation transition for dismissing contentView. default = shrink out
	var dismissType:KLCPopupDismissType

	// Mask prevents background touches from passing to underlying views. default = dimmed.
	var maskType:KLCPopupMaskType

	// Overrides alpha value for dimmed background mask. default = 0.5
	var dimmedMaskAlpha:CGFloat

	// If YES, then popup will get dismissed when background is touched. default = YES.
	var shouldDismissOnBackgroundTouch:Bool

	// If YES, then popup will get dismissed when content view is touched. default = NO.
	var shouldDismissOnContentTouch:Bool

	// Block gets called after show animation finishes. Be sure to use weak reference for popup within the block to avoid retain cycle.
	var didFinishShowingCompletion:(Void -> Void)

	// Block gets called when dismiss animation starts. Be sure to use weak reference for popup within the block to avoid retain cycle.
	var willStartDismissingCompletion:(Void -> Void)

	// Block gets called after dismiss animation finishes. Be sure to use weak reference for popup within the block to avoid retain cycle.
	var didFinishDismissingCompletion:(Void -> Void)

	var backgroundView:UIView
	var containerView:UIView

	// state flags
	var isBeingShown:Bool
	var isShowing:Bool
	var isBeingDismissed:Bool
	
	deinit {
		NSObject.cancelPreviousPerformRequestsWithTarget(self)
		NSNotificationCenter.defaultCenter().removeObserver(self)
	}
	
	convenience init() {
		self.init(frame:UIScreen.mainScreen().bounds)
	}
	
	override init(frame:CGRect) {
		super.init(frame:frame)
		
		self.userInteractionEnabled = true
		self.backgroundColor = UIColor.clearColor()
		self.alpha = 0
		self.autoresizingMask = [.FlexibleWidth, .FlexibleHeight]
		
		self.shouldDismissOnBackgroundTouch = true
		self.shouldDismissOnContentTouch = false
		
		self.showType = .ShrinkIn
		self.dismissType = .ShrinkOut
		self.maskType = .Dimmed
		self.dimmedMaskAlpha = 0.5
		
		self.isBeingShown = false
		self.isShowing = false
		self.isBeingDismissed = false
		
		self.backgroundView = UIView()
		self.backgroundView.backgroundColor = UIColor.clearColor()
		self.backgroundView.userInteractionEnabled = false
		self.backgroundView.autoresizingMask = [ .FlexibleWidth, .FlexibleHeight]
		self.backgroundView.frame = self.bounds
		
		self.containerView = UIView()
		self.containerView.autoresizesSubviews = false
		self.containerView.userInteractionEnabled = true
		self.containerView.backgroundColor = UIColor.clearColor()
    
		self.addSubview(self.backgroundView)
		self.addSubview(self.containerView)
		
		// register for notifications
		NSNotificationCenter.defaultCenter().addObserver(
			self,
			selector: "didChangeStatusBarOrientation:",
			name: UIApplicationDidChangeStatusBarFrameNotification,
			object: nil)
	}

	required init?(coder aDecoder: NSCoder) {
	    fatalError("init(coder:) has not been implemented")
	}
	
	// MARK: - UIView
	
	override func hitTest(point:CGPoint, withEvent event:UIEvent?) -> UIView? {

        let hitView = super.hitTest(point, withEvent:event)
		
		if hitView == self {
			// Try to dismiss if backgroundTouch flag set
			if self.shouldDismissOnBackgroundTouch {
				self.dismiss(true)
			}
			
			// If no mask, then return nil so touch passes through to underlying views.
			if self.maskType == .None {
				return nil
			} else {
				return hitView
			}
		} else {
			// If view is within containerView and contentTouch flag set, then try to hide.
			if hitView!.isDescendantOfView(self.containerView) {
				if self.shouldDismissOnContentTouch {
					self.dismiss(true)
				}
			}
			return hitView
		}
	}
	
	// MARK: - Class Public
	
	class func popup(contentView contentView:UIView) -> KLCPopup {
		let popup = KLCPopup()
		popup.contentView = contentView
		return popup
	}
	
	class func popup(contentView contentView:UIView,
		showType:KLCPopupShowType,
		dismissType:KLCPopupDismissType,
		maskType:KLCPopupMaskType,
		dismissOnBackgroundTouch shouldDismissOnBackgroundTouch:Bool,
		dismissOnContentTouch shouldDismissOnContentTouch:Bool) -> KLCPopup {
		
		let popup = KLCPopup()
		popup.contentView = contentView
		popup.showType = showType
		popup.dismissType = dismissType
		popup.maskType = maskType
		popup.shouldDismissOnBackgroundTouch = shouldDismissOnBackgroundTouch
		popup.shouldDismissOnContentTouch = shouldDismissOnContentTouch
		return popup
	}
	
	class func dismissAllPopups() {
		let windows = UIApplication.sharedApplication().windows
		for window in windows {
			window.forEachPopupPerformClosure() {
				popup in
				popup.dismiss(false)
			}
		}
	}
	
	// MARK: - Public
	func show() {
		self.showWithLayout(KLCPopupLayoutCenter)
	}
	
	func showWithLayout(layout:KLCPopupLayout) {
		self.showWithLayout(layout, duration: 0.0)
	}
	
	func showWithDuration(duration:NSTimeInterval) {
		self.showWithLayout(KLCPopupLayoutCenter, duration:duration)
	}
	
	func showWithLayout(layout:KLCPopupLayout, duration:NSTimeInterval) {
		let parameters = ["layout" : NSValue.valueWithKLCPopupLayout(layout), "duration" : duration]
		self.showWithParameters(parameters)
	}
	
	func showAtCenter(center:CGPoint, inView view:UIView) {
		self.showAtCenter(center, inView:view, withDuration:0.0)
	}
	
	func showAtCenter(center:CGPoint, inView view:UIView, withDuration duration:NSTimeInterval) {
		let parameters = ["center" : NSValue.valueWithCGPoint(center),"duration" : duration, "view" : view ]
		self.showWithParameters(parameters)
	}
	
	func backgroundAnimationClosure() {
		self.backgroundView.alpha = 0
	}
	
	func dismiss(animated:Bool) {
		if self.isShowing && !self.isBeingDismissed {
			self.isBeingShown = false
			self.isShowing = false
			self.isBeingDismissed = false
			
			NSObject.cancelPreviousPerformRequests(target: self, Selector("dismiss"), object:nil)
			
			self.willStartDismissing()
			
			if self.willStartDismissingCompletion != nil {
				self.willStartDismissingCompletion()
			}
			
			dispatch_async(dispatch_get_main_queue()) {
				
				if animated && self.showType != .None {
					// Make fade happen faster than motion. Use linear for fades.
                    UIView.animateWithDuration(0.15, delay: 0, options: .CurveLinear, animations: self.backgroundAnimationClosure, completion: nil)
				} else {
					self.backgroundAnimationClosure()
				}
				
				// Setup completion closure
                var completion:(Bool -> Void) = {
                    finished in
					self.removeFromSuperview()
					self.isBeingShown = false
					self.isShowing = false
					self.isBeingDismissed = false
					
					self.didFinishDismissing()
					if self.didFinishDismissingCompletion != nil {
						self.didFinishDismissingCompletion()
					}
				}
				
				let bounce1Duration:NSTimeInterval = 0.13
				let bounce2Duration:NSTimeInterval = (bounce1Duration * 2.0)
				
				// Animate content if needed
				if animated {
					switch self.dismissType {
					case .FadeOut: 
						UIView.animateWithDuration(0.15, delay: 0, options: .CurveLinear, animations:{
							self.containerView.alpha = 0
						}, completion:completion)
						
					case .GrowOut:
						UIView.animateWithDuration(0.15, delay: 0, options: kAnimationOptionCurveIOS7, animations: {
							self.containerView.alpha = 0
							self.containerView.transform = CGAffineTransformMakeScale(1.1, 1.1)
						}, completion:completion)
						
					case .ShrinkOut: 
						UIView.animateWithDuration(0.15, delay: 0, options: kAnimationOptionCurveIOS7, animations: {
							self.containerView.alpha = 0
							self.containerView.transform = CGAffineTransformMakeScale(0.8, 0.8)
						}, completion: completion)
						
					case .SlideOutToTop: 
						UIView.animateWithDuration(0.30, delay: 0, options: kAnimationOptionCurveIOS7, animations: {
							var finalFrame = self.containerView.frame
							finalFrame.origin.y = -CGRectGetHeight(finalFrame)
							self.containerView.frame = finalFrame
						}, completion: completion)
						
					case .SlideOutToBottom: 
						UIView.animateWithDuration(0.30, delay: 0, options: kAnimationOptionCurveIOS7, animations: {
							var finalFrame = self.containerView.frame
							finalFrame.origin.y = CGRectGetHeight(self.bounds)
							self.containerView.frame = finalFrame
						}, completion: completion)         
					case .SlideOutToLeft: 
						UIView.animateWithDuration(0.30, delay: 0, options: kAnimationOptionCurveIOS7, animations: {
							var finalFrame = self.containerView.frame
							finalFrame.origin.x = -CGRectGetWidth(finalFrame)
							self.containerView.frame = finalFrame
						}, completion: completion)           
					case .SlideOutToRight: 
						UIView.animateWithDuration(0.30, delay: 0, options: kAnimationOptionCurveIOS7, animations: {
							var finalFrame = self.containerView.frame
							finalFrame.origin.x = CGRectGetWidth(self.bounds)
							self.containerView.frame = finalFrame
						}, completion: completion)
					case .BounceOut:
						UIView.animateWithDuration(bounce1Duration, delay: 0, options: .CurveEaseOut, animations: {
							self.containerView.transform = CGAffineTransformMakeScale(1.1, 1.1)
						}, completion: {
							finished in
								UIView.animateWithDuration(bounce2Duration, delay: 0, options: .CurveEaseIn, animations: {
									self.containerView.alpha = 0/255
									self.containerView.transform = CGAffineTransformMakeScale(0.1, 0.1)
								}, completion: completion)
						})
					case .BounceOutToTop:
						UIView.animateWithDuration(bounce1Duration, delay: 0, options: .CurveEaseOut, animations: {
							var finalFrame = self.containerView.frame
							finalFrame.origin.y += 40
							self.containerView.frame = finalFrame
						}, completion: {
							finished in
								UIView.animateWithDuration(bounce2Duration, delay: 0, options: .CurveEaseIn, animations: {
									var finalFrame = self.containerView.frame
									finalFrame.origin.y = -CGRectGetHeight(finalFrame)
									self.containerView.frame = finalFrame
								}, completion: completion)
						})
					case .BounceOutToBottom:
						UIView.animateWithDuration(bounce1Duration, delay: 0, options: .CurveEaseOut, animations: {
							var finalFrame = self.containerView.frame
							finalFrame.origin.y -= 40
							self.containerView.frame = finalFrame
						}, completion: {
							finished in
								UIView.animateWithDuration(bounce2Duration, delay: 0, options: .CurveEaseIn, animations: {
									var finalFrame = self.containerView.frame
									finalFrame.origin.y = CGRectGetHeight(self.bounds)
									self.containerView.frame = finalFrame
								}, completion: completion)
						})
					case .BounceOutToLeft:
						UIView.animateWithDuration(bounce1Duration, delay: 0, options: .CurveEaseOut, animations: {
							var finalFrame = self.containerView.frame
							finalFrame.origin.x += 40
							self.containerView.frame = finalFrame
						}, completion: {
							finished in
								UIView.animateWithDuration(bounce2Duration, delay: 0, options: .CurveEaseIn, animations: {
									var finalFrame = self.containerView.frame
									finalFrame.origin.x = -CGRectGetWidth(finalFrame) // self.bounds?
									self.containerView.frame = finalFrame
								}, completion: completion)
						})          
					case .BounceOutToRight:
						UIView.animateWithDuration(bounce1Duration, delay: 0, options: .CurveEaseOut, animations: {
							var finalFrame = self.containerView.frame
							finalFrame.origin.x -= 40
							self.containerView.frame = finalFrame
						}, completion: {
							finished in
								UIView.animateWithDuration(bounce2Duration, delay: 0, options: .CurveEaseIn, animations: {
									var finalFrame = self.containerView.frame
									finalFrame.origin.x = -CGRectGetWidth(self.bounds) // finalFrame?
									self.containerView.frame = finalFrame
								}, completion: completion)
						})
					default:
						self.containerView.alpha = 0.0
						completion(true)
					}
				} else {
					self.containerView.alpha = 0.0
					completion(true)
				}
			}
		}
	}
	
	// Mark: - Private
	func showWithParameters(parameters:NSDictionary) {
		// If popup can be shown
		guard !isBeingShown && !isShowing && !isBeingDismissed else {
			return
		}
		self.isBeingShown = true
		self.isShowing = false
		self.isBeingDismissed = false
		
		self.willStartShowing()
		
		dispatch_async(dispatch_get_main_queue()) {
			// Prepare by adding to the top window
			if self.superview == nil {
				let frontToBackWindows = UIApplication.sharedApplication().windows.reverse()
				
				for window in frontToBackWindows {
					if window.windowLevel == UIWindowLevelNormal {
						window.addSubview(self)
						break
					}
				}
			}
			
			// Before we calculate layout for containerView, make sure we are transformed for current orientation
			self.updateForInterfaceOrientation()
			
			// Make sure we're not hidden
			self.hidden = false
			self.alpha = 1.0
			
			// Setup background view
			self.backgroundView.alpha = 0
			if self.maskType == .Dimmed {
				self.backgroundView.backgroundColor = UIColor.blackColor().colorWithAlphaComponent(self.dimmedMaskAlpha)
			} else {
				self.backgroundView.backgroundColor = UIColor.clearColor()
			}
			
			// Animate background if needed
			var backgroundAnimationClosure = {
				self.backgroundView.alpha = 1.0
			}
			
			if self.showType != .None {
				// Make fade happen faster than motion. Use linear for fades.
				UIView.animateWithDuration(0.15, delay: 0, options: .CurveLinear, animations: {
					backgroundAnimationClosure()
				}, completion: nil)
			} else {
				backgroundAnimationClosure()
			}

			// Determine duration. Default to 0 if none provided.
			var duration:NSTimeInterval
			let durationNumber = parameters.valueForKey("duration")
			if durationNumber != nil {
				duration = durationNumber as! Double
			} else {
				duration = 0
			}

			// Setup completion closure
            var completion:(Bool -> Void) = {
				finished in
					self.isBeingShown = false
					self.isShowing = true
					self.isBeingDismissed = false
					
					self.didFinishShowing()
					
					if self.didFinishShowingCompletion() != nil {
						self.didFinishShowingCompletion()
					}
					
					// Set to hide after duration if greater than zero
					if duration > 0.0 {
						self.performSelector(Selector("dismiss"), withObject: nil, afterDelay:duration)
					}
			}

			// Add contentView to container
			if self.contentView.superview != self.containerView {
				self.containerView.addSubview(self.contentView)
			}

			// Re-layout (this is needed if the contentView is using autoLayout)
			self.contentView.layoutIfNeeded()

			// Size container to match contentView
			var containerFrame = self.containerView.frame
			containerFrame.size = self.contentView.frame.size
			self.containerView.frame = containerFrame
			// Position contentView to fill it
			var contentViewFrame = self.contentView.frame
			contentViewFrame.origin = CGPointZero
			self.contentView.frame = contentViewFrame

			// Reset _containerView's constraints in case contentView is uaing autolayout
			let contentView = self.contentView
			let views = NSDictionaryOfVariableBindings(contentView) // TODO: Rewrite ObjC macro as Swift

			self.containerView.removeConstraints(self.containerView.constraints)
			self.containerView.addConstraints(
				NSLayoutConstraint.constraintsWithVisualFormat("V:|[contentView]|",
				options: NSLayoutFormatOptions(rawValue: 0),
				metrics: nil,
				views:views)
											)

			self.containerView.addConstraints(
				NSLayoutConstraint.constraintsWithVisualFormat("H:|[contentView]|",
				options:NSLayoutFormatOptions(rawValue: 0),
				metrics:nil,
				views:views)
											)

			// Determine final position and necessary autoresizingMask for container.
			var finalContainerFrame = containerFrame
            var containerAutoresizingMask:[UIViewAutoresizing] = UIViewAutoresizing.None

			// Use explicit center coordinates if provided.
			let centerValue = parameters.valueForKey("center")
			if centerValue != nil {
				var centerInView = centerValue as! CGPoint
				var centerInSelf:CGPoint

				// Convert coordinates from provided view to self. Otherwise use as-is.
				let fromView = parameters.valueForKey("view") as? UIView
				if let view = fromView {
					centerInSelf = self.convertPoint(centerInView, fromView:view)
				} else {
					centerInSelf = centerInView
				}

				finalContainerFrame.origin.x = (centerInSelf.x - CGRectGetWidth(finalContainerFrame)/2.0)
				finalContainerFrame.origin.y = (centerInSelf.y - CGRectGetHeight(finalContainerFrame)/2.0)
				containerAutoresizingMask = [ .FlexibleLeftMargin, .FlexibleRightMargin, .FlexibleBottomMargin, .FlexibleTopMargin]
			}
			// Otherwise use relative layout. Default to center if none provided.
			else {
				let layoutValue = parameters.valueForKey("layout")
				var layout:KLCPopupLayout
				if layoutValue != nil {
					layout = layoutValue.KLCPopupLayoutValue()
				} else {
					layout = .Center
				}

				switch layout.horizontal {
				case .Left:
					finalContainerFrame.origin.x = 0.0
					containerAutoresizingMask.append(.FlexibleRightMargin)

				case .LeftOfCenter:
					finalContainerFrame.origin.x = floor(CGRectGetWidth(self.bounds)/3.0 - CGRectGetWidth(containerFrame)/2.0)
					containerAutoresizingMask.append(.FlexibleLeftMargin)
					containerAutoresizingMask.append(.FlexibleRightMargin)

				case .Center:
					finalContainerFrame.origin.x = floor((CGRectGetWidth(self.bounds) - CGRectGetWidth(containerFrame))/2.0)
					containerAutoresizingMask.append(.FlexibleLeftMargin)
					containerAutoresizingMask.append(.FlexibleRightMargin)

				case .RightOfCenter:
					finalContainerFrame.origin.x = floor(CGRectGetWidth(self.bounds)*2.0/3.0 - CGRectGetWidth(containerFrame)/2.0)
					containerAutoresizingMask.append(.FlexibleLeftMargin)
					containerAutoresizingMask.append(.FlexibleRightMargin)

				case .Right:
					finalContainerFrame.origin.x = CGRectGetWidth(self.bounds) - CGRectGetWidth(containerFrame)
					containerAutoresizingMask.append(.FlexibleLeftMargin)

				default:
					break
				}

				// Vertical
				switch layout.vertical {
				case .Top:
					finalContainerFrame.origin.y = 0
					containerAutoresizingMask.append(.FlexibleBottomMargin)

				case .AboveCenter:
					finalContainerFrame.origin.y = floor(CGRectGetHeight(self.bounds)/3.0 - CGRectGetHeight(containerFrame)/2.0)
					containerAutoresizingMask.append(.FlexibleTopMargin)
					containerAutoresizingMask.append(.FlexibleBottomMargin)

				case .Center:
					finalContainerFrame.origin.y = floor((CGRectGetHeight(self.bounds) - CGRectGetHeight(containerFrame))/2.0)
					containerAutoresizingMask.append(.FlexibleTopMargin)
					containerAutoresizingMask.append(.FlexibleBottomMargin)

				case .BelowCenter:
					finalContainerFrame.origin.y = floor(CGRectGetHeight(self.bounds)*2.0/3.0 - CGRectGetHeight(containerFrame)/2.0)
					containerAutoresizingMask.append(.FlexibleTopMargin)
					containerAutoresizingMask.append(.FlexibleBottomMargin)

				case .Bottom:
					finalContainerFrame.origin.y = CGRectGetHeight(self.bounds) - CGRectGetHeight(containerFrame)
					containerAutoresizingMask.append(.FlexibleTopMargin)

				default:
					break
				}
			}
			
			self.containerView.autoresizingMask = containerAutoresizingMask

			// Animate content if needed
			switch self.showType {
			case .FadeIn:
				self.containerView.alpha = 0.0
				self.containerView.transform = CGAffineTransformIdentity
				let startFrame = finalContainerFrame
				self.containerView.frame = startFrame

				UIView.animateWithDuration(0.15, delay: 0, options: .CurveLinear, animations: {
					self.containerView.alpha = 1
				}, completion: completion)

			case .GrowIn:
				self.containerView.alpha = 0.0
				// set frame before transform here...
				let startFrame = finalContainerFrame
				self.containerView.frame = startFrame
				self.containerView.transform = CGAffineTransformMakeScale(0.85, 0.85)

				UIView.animateWithDuration(0.15, delay: 0, options: kAnimationOptionCurveIOS7, animations: {
					self.containerView.alpha = 1.0
					// set transform before frame here...
					self.containerView.transform = CGAffineTransformIdentity
					self.containerView.frame = finalContainerFrame
				}, completion: completion)

			case .ShrinkIn:
				self.containerView.alpha = 0.0
				// set frame before transform here...
				let startFrame = finalContainerFrame
				self.containerView.frame = startFrame
				self.containerView.transform = CGAffineTransformMakeScale(1.25, 1.25)

				UIView.animateWithDuration(0.15, delay: 0, options: kAnimationOptionCurveIOS7, animations: {
					self.containerView.alpha = 1.0
					// set transform before frame here...
					self.containerView.transform = CGAffineTransformIdentity()
					self.containerView.frame = finalContainerFrame
				}, completion: completion)

			case .SlideInFromTop:
				self.containerView.alpha = 1.0
				self.containerView.transform = CGAffineTransformIdentity
				var startFrame = finalContainerFrame
				startFrame.origin.y = -CGRectGetHeight(finalContainerFrame)
				self.containerView.frame = startFrame

				UIView.animateWithDuration(0.30, delay:0, options:kAnimationOptionCurveIOS7, animations: {
					self.containerView.frame = finalContainerFrame
				}, completion: completion)

			case .SlideInFromBottom:
				self.containerView.alpha = 1.0
				self.containerView.transform = CGAffineTransformIdentity
				var startFrame = finalContainerFrame
				startFrame.origin.y = CGRectGetHeight(self.bounds)
				self.containerView.frame = startFrame

				UIView.animateWithDuration(0.30, delay: 0, options: kAnimationOptionCurveIOS7, animations: {
					self.containerView.frame = finalContainerFrame
				}, completion: completion)

			case .SlideInFromLeft:
				self.containerView.alpha = 1.0
				self.containerView.transform = CGAffineTransformIdentity
				var startFrame = finalContainerFrame
				startFrame.origin.x = -CGRectGetWidth(finalContainerFrame)
				self.containerView.frame = startFrame

				UIView.animateWithDuration(0.30, delay: 0, options: kAnimationOptionCurveIOS7, animations: {
					self.containerView.frame = finalContainerFrame
				}, completion: completion)

			case .SlideInFromRight:
				self.containerView.alpha = 1.0
				self.containerView.transform = CGAffineTransformIdentity
				var startFrame = finalContainerFrame
				startFrame.origin.x = CGRectGetWidth(self.bounds)
				self.containerView.frame = startFrame

				UIView.animateWithDuration(0.30, delay: 0, options:kAnimationOptionCurveIOS7, animations: {
					self.containerView.frame = finalContainerFrame
				}, completion: completion)

			case .BounceIn:
				self.containerView.alpha = 0.0
				// set frame before transform here...
				var startFrame = finalContainerFrame
				self.containerView.frame = startFrame
				self.containerView.transform = CGAffineTransformMakeScale(0.1, 0.1)

				UIView.animateWithDuration(0.6, delay:0, usingSpringWithDamping:0.8, initialSpringVelocity:15.0, options: nil, animations: {
					self.containerView.alpha = 1.0
					self.containerView.transform = CGAffineTransformIdentity
				}, completion: completion)

			case .BounceInFromTop: 
				self.containerView.alpha = 1.0
				self.containerView.transform = CGAffineTransformIdentity
				var startFrame = finalContainerFrame
				startFrame.origin.y = -CGRectGetHeight(finalContainerFrame)
				self.containerView.frame = startFrame

				UIView.animateWithDuration(0.6, delay:0, usingSpringWithDamping:0.8, initialSpringVelocity:10.0, options: 0, animations: {
					self.containerView.frame = finalContainerFrame
				}, completion: completion)

			case .BounceInFromBottom: 
				self.containerView.alpha = 1.0
				self.containerView.transform = CGAffineTransformIdentity
				var startFrame = finalContainerFrame
				startFrame.origin.y = CGRectGetHeight(self.bounds)
				self.containerView.frame = startFrame

				UIView.animateWithDuration(0.6, delay:0.0, usingSpringWithDamping:0.8, initialSpringVelocity:10.0, options:0, animations: {
					self.containerView.frame = finalContainerFrame
				}, completion: completion)

			case .BounceInFromLeft:
				self.containerView.alpha = 1.0
				self.containerView.transform = CGAffineTransformIdentity
				var startFrame = finalContainerFrame
				startFrame.origin.x = -CGRectGetWidth(finalContainerFrame)
				self.containerView.frame = startFrame

				UIView.animateWithDuration(0.6, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 10, options: 0, animations: {
					self.containerView.frame = finalContainerFrame
				}, completion: completion)

			case .BounceInFromRight:
				self.containerView.alpha = 1.0
				self.containerView.transform = CGAffineTransformIdentity
				var startFrame = finalContainerFrame
				startFrame.origin.x = CGRectGetWidth(self.bounds)
				self.containerView.frame = startFrame

				UIView.animateWithDuration(0.6, delay: 0, usingSpringWithDamping:0.8, initialSpringVelocity:10.0, options: 0, animations: {
					self.containerView.frame = finalContainerFrame
				}, completion: completion)

			default:
				self.containerView.alpha = 1.0
				self.containerView.transform = CGAffineTransformIdentity
				self.containerView.frame = finalContainerFrame
				completion(true)
			}
		}
	}
	
	// Mark: - Private
	private func dismiss() {
		self.dismiss(true)
	}
	
	private func updateForInterfaceOrientation() {
		// We must manually fix orientation prior to iOS 8
		// Swift only available on iOS 8+
		//if (([[[UIDevice currentDevice] systemVersion] compare:@"8.0" options:NSNumericSearch] == NSOrderedAscending)) {
		//	UIInterfaceOrientation orientation = [[UIApplication sharedApplication] statusBarOrientation]
		//	var angle:CGFloat
		//	switch orientation {
		//	case .PortraitUpsideDown:
		//		angle = M_PI
		//	case .LandscapeLeft:
		//		angle = -M_PI/2.0
		//	case .LandscapeRight:
		//		angle = M_PI/2.0
		//	default: // as .Portrait
		//		angle = 0.0
		//	}
		//	self.transform = CGAffineTransformMakeRotation(angle)
		//}
		self.frame = self.window!.bounds
	}
	
	// Mark: - Notification Handlers
	func didChangeStatusBarOrientation(notification:NSNotification) {
		self.updateForInterfaceOrientation()
	}
	
	// Mark: - Subclassing
	func willStartShowing() {
	}
	
	func didFinishShowing() {
	}
	
	func willStartDismissing() {
	}
	
	func didFinishDismissing() {
	}
}

// Mark: - Extensions
extension UIView {
	func forEachPopupPerformClosure(f:(KLCPopup -> Void)) {
		for subview in self.subviews {
			if subview.isKindOfClass(KLCPopup) {
				f(subview as! KLCPopup)
			} else {
				subview.forEachPopupPerformClosure(f)
			}
		}
	}
	
	func dismissPresentingPopup() {
		// Iterate over superviews until you find a KLCPopup and dismiss it
		var aView = self
		while aView != nil {
			if aView.isKindOfClass(KLCPopup) {
				aView.dismiss(true)
				return
			}
			aView = aView.superview
		}
	}
}

extension NSValue {
	func valueWithKLCPopupLayout(layout:KLCPopupLayout) -> NSValue {
		return NSValue(bytes:&layout, objCType:String.fromCString(KLCPopupLayout.objCType))
	}
	
	func KLCPopupLayoutValue() -> KLCPopupLayout {
		var layout = KLCPopupLayout
		self.getValue(&layout)
		return layout
	}
}
