//
//  TMImageZoom.swift
//
//  Created by Thomas Maw on 21/04/23.
//  Copyright © 2016 Thomas Maw. All rights reserved.
//

import UIKit

public class TMImageZoom {
    static let TMImageZoomStartedZoomNotification = Notification.Name("TMImageZoom_Started_Zoom_Notification")
    static let TMImageZoomEndedZoomNotification = Notification.Name("TMImageZoom_Ended_Zoom_Notification")
    
    private var currentImageView: UIImageView?
    private var hostImageView: UIImageView?
    private var isAnimatingReset = false
    private var firstCenterPoint = CGPoint.zero
    private var startingRect = CGRect.zero
    private var lastPinchCenter = CGPoint.zero
    private var lastTouchPosition = CGPoint.zero
    
    var isHandlingGesture: Bool {
        return hostImageView != nil
    }
    
    static public let shared = TMImageZoom()
    
    public func gestureStateChanged(_ gesture: UIGestureRecognizer, withZoomImageView imageView: UIImageView) {
        // Ensure user is passing correct UIPinchGestureRecognizer class.
        guard let theGesture = gesture as? UIPinchGestureRecognizer else {
            print("(TMImageZoom): Must be using a UIPinchGestureRecognizer, currently you're using a: \(gesture.self)")
            return
        }

        // Prevent animation issues if currently animating reset.
        if isAnimatingReset {
            return
        }

        // Reset zoom if state = .ended
        if theGesture.state == .ended || theGesture.state == .cancelled || theGesture.state == .failed {
            resetImageZoom()
            return
        }

        // Ignore other views trying to start zoom if already zooming with another view
        if isHandlingGesture && hostImageView != imageView {
            print("(TMImageZoom): 'gestureStateChanged:' ignored since this imageView isn't being tracked")
            return
        }

        // Start handling gestures if state = .began and not already handling gestures.
        if !isHandlingGesture && theGesture.state == .began {
            hostImageView = imageView
            imageView.isHidden = true

            // Convert local point to window coordinates
            let point = imageView.convert(imageView.bounds.origin, to: nil)
            startingRect = CGRect(x: point.x, y: point.y, width: imageView.frame.width, height: imageView.frame.height)

            // Post Notification
            NotificationCenter.default.post(name: TMImageZoom.TMImageZoomStartedZoomNotification, object: nil)

            // Get current window and set starting vars
            let currentWindow = UIApplication.shared.keyWindow
            firstCenterPoint = theGesture.location(in: currentWindow)

            // Init zoom ImageView
            currentImageView = UIImageView(image: imageView.image)
            currentImageView?.contentMode = imageView.contentMode
            currentImageView?.bounds = startingRect
            currentWindow?.addSubview(currentImageView!)
        }

        // Update scale & center
        if theGesture.state == .changed {
            // If only one finger is detected, update the lastPinchCenter
            if theGesture.numberOfTouches == 1 {
                let currentTouchPosition = theGesture.location(ofTouch: 0, in: imageView)
                let translation = CGPoint(x: currentTouchPosition.x - lastTouchPosition.x, y: currentTouchPosition.y - lastTouchPosition.y)
                let newCenter = CGPoint(x: lastPinchCenter.x + translation.x, y: lastPinchCenter.y + translation.y)
                currentImageView?.center = newCenter
                lastTouchPosition = currentTouchPosition
            } else {
                // Calculate new image scale.
                let currentScale = currentImageView!.frame.width / startingRect.width
                let newScale = currentScale * theGesture.scale
                currentImageView?.frame = CGRect(x: currentImageView!.frame.origin.x,
                                                 y: currentImageView!.frame.origin.y,
                                                 width: startingRect.width * newScale,
                                                 height: startingRect.height * newScale)

                // Calculate new center
                let currentWindow = UIApplication.shared.keyWindow
                let centerXDif = firstCenterPoint.x - theGesture.location(in: currentWindow).x
                let centerYDif = firstCenterPoint.y - theGesture.location(in: currentWindow).y
                currentImageView?.center = CGPoint(x: (startingRect.origin.x + (startingRect.size.width / 2)) - centerXDif,
                                                   y: (startingRect.origin.y + (startingRect.size.height / 2)) - centerYDif)

                // Reset gesture scale
                theGesture.scale = 1
            }

            // Update lastPinchCenter after handling the gesture
            lastPinchCenter = currentImageView?.center ?? CGPoint.zero
        }
    }
    
    public func resetImageZoom() {
        // If not already animating
        if isAnimatingReset || !isHandlingGesture {
            return
        }
        
        // Prevent further scale/center updates
        isAnimatingReset = true
        
        // Animate image zoom reset and post zoom ended notification
        UIView.animate(withDuration: 0.2, animations: {
            self.currentImageView?.frame = self.startingRect
        }, completion: { finished in
            self.currentImageView?.removeFromSuperview()
            self.currentImageView = nil
            self.hostImageView?.isHidden = false
            self.hostImageView = nil
            self.startingRect = CGRect.zero
            self.firstCenterPoint = CGPoint.zero
            self.isAnimatingReset = false
            NotificationCenter.default.post(name: TMImageZoom.TMImageZoomEndedZoomNotification, object: nil)
        })
    }
}
